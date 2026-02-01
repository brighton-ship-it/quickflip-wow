--[[
    QuickFlip - Selling.lua
    Smart posting with competition analysis and optimal pricing
]]

local addonName, QF = ...

-- Bag items cache
QF.bagItems = {}
QF.pendingPosts = {}

-- Durations
local DURATIONS = {
    {hours = 12, text = "12h", enum = 1},
    {hours = 24, text = "24h", enum = 2},
    {hours = 48, text = "48h", enum = 3},
}

-------------------------------------------------------------------------------
-- Event Registration
-------------------------------------------------------------------------------

local sellFrame = CreateFrame("Frame")
sellFrame:RegisterEvent("BAG_UPDATE")
sellFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
-- sellFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
-- sellFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
-- sellFrame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
-- sellFrame:RegisterEvent("AUCTION_HOUSE_POST_ERROR")

sellFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" and QF.isAHOpen then
        QF:ScanBags()
    elseif event == "AUCTION_HOUSE_SHOW" then
        QF:ScanBags()
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        QF:OnSellPriceUpdate(...)
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        QF:OnAuctionPosted(...)
    elseif event == "AUCTION_HOUSE_POST_ERROR" then
        QF:OnPostError(...)
    end
end)

-------------------------------------------------------------------------------
-- Bag Scanning
-------------------------------------------------------------------------------

function QF:ScanBags()
    self.bagItems = {}
    
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            
            if itemInfo and itemInfo.itemID then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount or 1
                
                if self:IsAuctionable(itemID, bag, slot) then
                    if self.bagItems[itemID] then
                        self.bagItems[itemID].count = self.bagItems[itemID].count + stackCount
                        table.insert(self.bagItems[itemID].locations, {
                            bag = bag, slot = slot, count = stackCount
                        })
                    else
                        local itemName, itemLink, quality, _, _, itemType, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
                        local priceData = self:GetPriceData(itemID)
                        local costBasis = self:GetCostBasis(itemID)
                        
                        self.bagItems[itemID] = {
                            itemID = itemID,
                            itemName = itemName,
                            itemLink = itemLink,
                            itemIcon = itemIcon,
                            quality = quality or 1,
                            itemType = itemType,
                            count = stackCount,
                            marketPrice = priceData and priceData.marketPrice,
                            velocity = priceData and priceData.velocity or 0,
                            competitorCount = priceData and priceData.competitorCount or 0,
                            costBasis = costBasis,
                            locations = {{bag = bag, slot = slot, count = stackCount}},
                        }
                    end
                end
            end
        end
    end
    
    -- Update sell UI
    if self.sellFrame and self.sellFrame:IsVisible() then
        self:UpdateSellDisplay()
    end
end

function QF:IsAuctionable(itemID, bag, slot)
    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
    if not itemInfo then return false end
    
    -- Skip bound items
    if itemInfo.isBound then return false end
    
    -- Skip quest items
    local _, _, _, _, _, itemType = C_Item.GetItemInfo(itemID)
    if itemType == "Quest" then return false end
    
    return true
end

-------------------------------------------------------------------------------
-- Smart Pricing (Better than Auctionator!)
-------------------------------------------------------------------------------

function QF:CalculateSmartPrice(itemID)
    local priceData = self:GetPriceData(itemID)
    if not priceData or not priceData.marketPrice then
        return nil, nil, "No market data"
    end
    
    local marketPrice = priceData.marketPrice
    local competitors = priceData.competitorCount or 0
    local velocity = priceData.velocity or 0
    
    local undercut = self.config and self.config.undercutPercent or 5
    local basePrice = marketPrice
    local strategy = "standard"
    
    -- Smart undercut based on competition
    if competitors == 0 then
        -- We're the only seller - price higher!
        basePrice = floor(marketPrice * 1.10)  -- 10% above market
        undercut = 0
        strategy = "monopoly"
    elseif competitors <= 3 then
        -- Low competition - small undercut
        undercut = 1
        strategy = "light"
    elseif competitors <= 10 then
        -- Moderate competition - standard undercut
        undercut = self.config and self.config.undercutPercent or 5
        strategy = "standard"
    else
        -- High competition - aggressive undercut
        undercut = min((self.config and self.config.undercutPercent or 5) + 5, 15)
        strategy = "aggressive"
    end
    
    -- Adjust for velocity
    if velocity < 5 then
        -- Slow seller - be more aggressive
        undercut = undercut + 3
        strategy = strategy .. "+slow"
    elseif velocity > 50 then
        -- Fast seller - can afford less undercut
        undercut = max(undercut - 2, 1)
        strategy = strategy .. "+fast"
    end
    
    local postPrice = floor(basePrice * (1 - undercut / 100))
    postPrice = max(postPrice, 1)  -- Minimum 1 copper
    
    return postPrice, undercut, strategy
end

function QF:GetPostPrice(itemID)
    local price, _, _ = self:CalculateSmartPrice(itemID)
    return price
end

function QF:GetPotentialProfit(itemID, quantity)
    local postPrice = self:GetPostPrice(itemID)
    if not postPrice then return nil end
    
    quantity = quantity or 1
    
    -- After 5% AH cut
    local revenue = postPrice * 0.95 * quantity
    
    -- Subtract cost basis if we have it
    local costBasis = self:GetCostBasis(itemID)
    if costBasis then
        return floor(revenue - (costBasis * quantity))
    end
    
    return floor(revenue)
end

-------------------------------------------------------------------------------
-- Posting Functions
-------------------------------------------------------------------------------

function QF:PostItem(itemData, quantity, duration, priceOverride)
    if not self.isAHOpen then
        self:Print("Auction House must be open!")
        return false
    end
    
    if not itemData then return false end
    
    quantity = quantity or 1
    duration = duration or 2
    
    local postPrice = priceOverride or self:GetPostPrice(itemData.itemID)
    if not postPrice then
        self:Print("No price for", itemData.itemLink or itemData.itemName)
        return false
    end
    
    -- Find item location
    local location = itemData.locations and itemData.locations[1]
    if not location then
        self:Print("Cannot find item in bags!")
        return false
    end
    
    local itemLocation = ItemLocation:CreateFromBagAndSlot(location.bag, location.slot)
    if not itemLocation:IsValid() then
        self:Print("Invalid item location!")
        return false
    end
    
    -- Check if commodity
    local isCommodity = C_AuctionHouse.GetItemCommodityStatus(itemLocation) == Enum.ItemCommodityStatus.Commodity
    
    -- Track pending post
    self.pendingPosts[itemData.itemID] = {
        itemData = itemData,
        price = postPrice,
        quantity = quantity,
        timestamp = time(),
    }
    
    if isCommodity then
        C_AuctionHouse.PostCommodity(itemLocation, duration, quantity, postPrice)
    else
        C_AuctionHouse.PostItem(itemLocation, duration, quantity, nil, postPrice)
    end
    
    self:Debug("Posting:", itemData.itemName, "x", quantity, "@", self:FormatGoldShort(postPrice))
    return true
end

-- Post all profitable items
function QF:BulkPost(minProfitPercent)
    if not self.isAHOpen then
        self:Print("Auction House must be open!")
        return
    end
    
    minProfitPercent = minProfitPercent or 10
    
    local toPost = {}
    local totalValue = 0
    
    for itemID, data in pairs(self.bagItems) do
        if data.marketPrice and data.marketPrice > 0 then
            local postPrice = self:GetPostPrice(itemID)
            if postPrice then
                -- Check profitability if we have cost basis
                local shouldPost = true
                if data.costBasis then
                    local profitPercent = ((postPrice * 0.95) - data.costBasis) / data.costBasis * 100
                    if profitPercent < minProfitPercent then
                        shouldPost = false
                    end
                end
                
                if shouldPost then
                    table.insert(toPost, data)
                    totalValue = totalValue + (postPrice * data.count)
                end
            end
        end
    end
    
    if #toPost == 0 then
        self:Print("No profitable items to post!")
        return
    end
    
    -- Sort by value (highest first)
    table.sort(toPost, function(a, b)
        return (a.marketPrice or 0) * a.count > (b.marketPrice or 0) * b.count
    end)
    
    self:Print("Posting", #toPost, "items worth ~", self:FormatGoldShort(totalValue))
    
    -- Post with throttling
    local postIndex = 1
    local function PostNext()
        if postIndex > #toPost then
            self:Print("|cff00ff00Bulk post complete!|r")
            self:ScanBags()
            return
        end
        
        local data = toPost[postIndex]
        self:PostItem(data, data.count, 2)
        postIndex = postIndex + 1
        
        C_Timer.After(0.4, PostNext)
    end
    
    PostNext()
end

-- Post selected items
function QF:PostSelected(selectedItems)
    if not selectedItems or #selectedItems == 0 then
        self:Print("No items selected!")
        return
    end
    
    for _, itemID in ipairs(selectedItems) do
        local data = self.bagItems[itemID]
        if data then
            self:PostItem(data, data.count, 2)
        end
    end
end

-------------------------------------------------------------------------------
-- Post Event Handlers
-------------------------------------------------------------------------------

function QF:OnAuctionPosted(auctionID)
    -- Find pending post
    for itemID, pending in pairs(self.pendingPosts) do
        if time() - pending.timestamp < 10 then
            self:Print("|cff00ff00Posted:|r", pending.itemData.itemLink or pending.itemData.itemName,
                "x", pending.quantity, "for", self:FormatGoldShort(pending.price * pending.quantity))
            
            -- Record sale
            self:RecordSale(itemID, pending.price * pending.quantity, pending.quantity, pending.itemData.itemName)
            
            self.pendingPosts[itemID] = nil
            break
        end
    end
    
    -- Refresh bags
    C_Timer.After(0.5, function()
        self:ScanBags()
    end)
end

function QF:OnPostError(auctionID)
    self:Print("|cffff0000Post failed!|r Check the item and try again.")
    self.pendingPosts = {}
end

function QF:OnSellPriceUpdate(itemID)
    -- Update item price when we get new data
    if self.bagItems[itemID] then
        local priceData = self:GetPriceData(itemID)
        if priceData then
            self.bagItems[itemID].marketPrice = priceData.marketPrice
            self.bagItems[itemID].velocity = priceData.velocity
            self.bagItems[itemID].competitorCount = priceData.competitorCount
        end
        
        if self.sellFrame and self.sellFrame:IsVisible() then
            self:UpdateSellDisplay()
        end
    end
end

-------------------------------------------------------------------------------
-- Refresh Sell Prices (Scan all bag items)
-------------------------------------------------------------------------------

function QF:RefreshSellPrices()
    if not self.isAHOpen then return end
    
    local toScan = {}
    for itemID, data in pairs(self.bagItems) do
        if not data.marketPrice then
            table.insert(toScan, itemID)
        end
    end
    
    if #toScan == 0 then
        self:Print("All items have prices")
        return
    end
    
    self:Print("Scanning", #toScan, "items...")
    
    local scanIndex = 1
    local function ScanNext()
        if scanIndex > #toScan then
            self:Print("Price refresh complete")
            return
        end
        
        self:ScanItem(toScan[scanIndex])
        scanIndex = scanIndex + 1
        
        C_Timer.After(0.2, ScanNext)
    end
    
    ScanNext()
end

-------------------------------------------------------------------------------
-- UI Update
-------------------------------------------------------------------------------

function QF:UpdateSellDisplay()
    if not self.sellFrame then return end
    
    -- Clear rows
    for _, row in ipairs(self.sellFrame.rows or {}) do
        row:Hide()
    end
    
    self.sellFrame.rows = self.sellFrame.rows or {}
    
    -- Sort items by potential profit
    local sortedItems = {}
    for _, data in pairs(self.bagItems) do
        local profit = self:GetPotentialProfit(data.itemID, data.count)
        data.potentialProfit = profit
        table.insert(sortedItems, data)
    end
    
    table.sort(sortedItems, function(a, b)
        return (a.potentialProfit or 0) > (b.potentialProfit or 0)
    end)
    
    -- Calculate totals
    local totalValue = 0
    local totalProfit = 0
    local itemsWithPrice = 0
    
    -- Build rows
    local yOffset = -5
    for i, data in ipairs(sortedItems) do
        if i > 40 then break end
        
        local row = self.sellFrame.rows[i]
        if not row then
            row = self:CreateSellRow(self.sellFrame.scrollChild, i)
            self.sellFrame.rows[i] = row
        end
        
        self:UpdateSellRow(row, data)
        row:SetPoint("TOPLEFT", self.sellFrame.scrollChild, "TOPLEFT", 0, yOffset)
        row:Show()
        
        yOffset = yOffset - 32
        
        if data.marketPrice then
            totalValue = totalValue + (data.marketPrice * data.count)
            itemsWithPrice = itemsWithPrice + 1
            if data.potentialProfit then
                totalProfit = totalProfit + data.potentialProfit
            end
        end
    end
    
    self.sellFrame.scrollChild:SetHeight(math.abs(yOffset) + 20)
    
    -- Update totals
    if self.sellFrame.totalText then
        self.sellFrame.totalText:SetText("Bag Value: " .. self:FormatGold(totalValue))
    end
    if self.sellFrame.profitText then
        local profitColor = totalProfit >= 0 and "|cff00ff00" or "|cffff0000"
        self.sellFrame.profitText:SetText("Est. Profit: " .. profitColor .. self:FormatGold(totalProfit) .. "|r")
    end
    if self.sellFrame.countText then
        self.sellFrame.countText:SetText(itemsWithPrice .. "/" .. #sortedItems .. " priced")
    end
end

function QF:CreateSellRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(385, 30)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    
    -- Profit indicator bar
    row.profitBar = row:CreateTexture(nil, "BACKGROUND")
    row.profitBar:SetSize(4, 28)
    row.profitBar:SetPoint("LEFT", 0, 0)
    
    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", 8, 0)
    
    -- Name
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetWidth(100)
    row.name:SetJustifyH("LEFT")
    
    -- Quantity
    row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.qty:SetPoint("LEFT", row.name, "RIGHT", 3, 0)
    row.qty:SetWidth(35)
    
    -- Post Price
    row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.price:SetPoint("LEFT", row.qty, "RIGHT", 3, 0)
    row.price:SetWidth(65)
    
    -- Profit
    row.profit = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.profit:SetPoint("LEFT", row.price, "RIGHT", 3, 0)
    row.profit:SetWidth(55)
    
    -- Velocity indicator
    row.velocity = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.velocity:SetPoint("LEFT", row.profit, "RIGHT", 3, 0)
    row.velocity:SetWidth(30)
    
    -- Sell button
    row.sellBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.sellBtn:SetSize(45, 24)
    row.sellBtn:SetPoint("RIGHT", -5, 0)
    row.sellBtn:SetText("Sell")
    
    -- Checkbox for bulk select
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(20, 20)
    row.check:SetPoint("RIGHT", row.sellBtn, "LEFT", -2, 0)
    
    return row
end

function QF:UpdateSellRow(row, data)
    row.icon:SetTexture(data.itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Name colored by quality
    local color = ITEM_QUALITY_COLORS[data.quality or 1] or ITEM_QUALITY_COLORS[1]
    row.name:SetText(data.itemName or "Loading...")
    row.name:SetTextColor(color.r, color.g, color.b)
    
    row.qty:SetText("x" .. data.count)
    
    -- Post price with strategy hint
    local postPrice, undercut, strategy = self:CalculateSmartPrice(data.itemID)
    if postPrice then
        row.price:SetText(self:FormatGoldShort(postPrice))
        
        -- Profit bar color
        local profit = self:GetPotentialProfit(data.itemID, data.count)
        if profit then
            if profit > 0 then
                row.profitBar:SetColorTexture(0, 1, 0, 0.8)
                row.profit:SetText("|cff00ff00+" .. self:FormatGoldShort(profit) .. "|r")
            else
                row.profitBar:SetColorTexture(1, 0, 0, 0.8)
                row.profit:SetText("|cffff0000" .. self:FormatGoldShort(profit) .. "|r")
            end
        else
            row.profitBar:SetColorTexture(0.5, 0.5, 0.5, 0.8)
            row.profit:SetText(self:FormatGoldShort(postPrice * data.count * 0.95))
        end
    else
        row.price:SetText("|cff888888Scan|r")
        row.profit:SetText("--")
        row.profitBar:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    end
    
    -- Velocity indicator
    if data.velocity and data.velocity > 0 then
        if data.velocity >= 50 then
            row.velocity:SetText("|cff00ff00⚡|r")  -- Fast
        elseif data.velocity >= 10 then
            row.velocity:SetText("|cffffff00●|r")  -- Medium
        else
            row.velocity:SetText("|cffff0000○|r")  -- Slow
        end
    else
        row.velocity:SetText("")
    end
    
    row.data = data
    
    -- Sell button
    row.sellBtn:SetScript("OnClick", function()
        if postPrice then
            QF:PostItem(data, data.count, 2)
        else
            QF:Print("Scan prices first!")
            QF:ScanItem(data.itemID)
        end
    end)
    
    -- Right-click to sell 1
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and postPrice then
            QF:PostItem(data, 1, 2)
        end
    end)
    
    -- Tooltip
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.itemLink then
            GameTooltip:SetHyperlink(data.itemLink)
        else
            GameTooltip:SetItemByID(data.itemID)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffFFD700QuickFlip Pricing|r")
        
        if data.marketPrice then
            GameTooltip:AddDoubleLine("Market:", QF:FormatGold(data.marketPrice), 1, 1, 1, 1, 1, 1)
        end
        
        if postPrice then
            GameTooltip:AddDoubleLine("Post at:", QF:FormatGold(postPrice), 1, 1, 1, 0.5, 1, 0.5)
            if strategy then
                GameTooltip:AddDoubleLine("Strategy:", strategy, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end
            if undercut then
                GameTooltip:AddDoubleLine("Undercut:", undercut .. "%", 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end
        end
        
        if data.costBasis then
            GameTooltip:AddDoubleLine("You paid:", QF:FormatGold(data.costBasis), 1, 1, 1, 1, 0.5, 0.5)
        end
        
        if data.competitorCount and data.competitorCount > 0 then
            GameTooltip:AddDoubleLine("Competition:", data.competitorCount .. " sellers", 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
        
        if data.velocity then
            local velText = data.velocity >= 50 and "Fast" or data.velocity >= 10 and "Medium" or "Slow"
            GameTooltip:AddDoubleLine("Sells:", velText .. " (" .. floor(data.velocity) .. "/day)", 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Right-click to sell 1|r")
        
        GameTooltip:Show()
    end)
    
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-------------------------------------------------------------------------------

QF:Debug("Selling.lua loaded")
