--[[
    QuickFlip - Buying.lua
    Smart buying with deal detection and instant purchase
]]

local addonName, QF = ...

-- Search results cache
QF.searchResults = {}
QF.lastSearchItemID = nil

-------------------------------------------------------------------------------
-- Event Registration
-------------------------------------------------------------------------------

local buyFrame = CreateFrame("Frame")
-- buyFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
-- buyFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
-- buyFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
-- buyFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
-- buyFrame:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED")

buyFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        QF:OnBuySearchResults(...)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        QF:OnBuyItemResults(...)
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        QF:OnPurchaseSucceeded(...)
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        QF:OnPurchaseFailed(...)
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        QF:OnItemPurchaseCompleted(...)
    end
end)

-------------------------------------------------------------------------------
-- Search Results Processing
-------------------------------------------------------------------------------

function QF:OnBuySearchResults(itemID)
    if not itemID then return end
    
    self.lastSearchItemID = itemID
    local numResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    if numResults == 0 then return end
    
    self.searchResults = {}
    
    local marketPrice = self:GetMarketPrice(itemID)
    
    for i = 1, min(numResults, 200) do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if result then
            local marketPercent = marketPrice and floor((result.unitPrice / marketPrice) * 100) or nil
            
            table.insert(self.searchResults, {
                index = i,
                itemID = itemID,
                unitPrice = result.unitPrice,
                quantity = result.quantity,
                numOwnerItems = result.numOwnerItems,
                containsOwnerItem = result.containsOwnerItem,
                isCommodity = true,
                marketPrice = marketPrice,
                marketPercent = marketPercent,
                dealRating = self:GetDealRating(marketPercent),
            })
        end
    end
    
    -- Store price data
    if self.searchResults[1] then
        self:StorePrice(itemID, self.searchResults[1].unitPrice, numResults)
    end
    
    -- Update UI
    if self.buyFrame and self.buyFrame:IsVisible() then
        self:UpdateBuyingDisplay()
    end
end

function QF:OnBuyItemResults(itemKey)
    if not itemKey then return end
    
    self.lastSearchItemID = itemKey.itemID
    local numResults = C_AuctionHouse.GetNumItemSearchResults(itemKey)
    if numResults == 0 then return end
    
    self.searchResults = {}
    
    local marketPrice = self:GetMarketPrice(itemKey.itemID)
    
    for i = 1, min(numResults, 200) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if result and result.buyoutAmount then
            local marketPercent = marketPrice and floor((result.buyoutAmount / marketPrice) * 100) or nil
            
            table.insert(self.searchResults, {
                index = i,
                itemID = itemKey.itemID,
                itemKey = itemKey,
                auctionID = result.auctionID,
                unitPrice = result.buyoutAmount,
                quantity = result.quantity or 1,
                itemLink = result.itemLink,
                timeLeft = result.timeLeft,
                isCommodity = false,
                marketPrice = marketPrice,
                marketPercent = marketPercent,
                dealRating = self:GetDealRating(marketPercent),
            })
        end
    end
    
    -- Store price data
    if self.searchResults[1] then
        self:StorePrice(itemKey.itemID, self.searchResults[1].unitPrice, numResults)
    end
    
    if self.buyFrame and self.buyFrame:IsVisible() then
        self:UpdateBuyingDisplay()
    end
end

-------------------------------------------------------------------------------
-- Purchase Functions
-------------------------------------------------------------------------------

function QF:ConfirmBuy(resultData, quantity)
    if not resultData then return end
    
    quantity = quantity or (resultData.isCommodity and resultData.quantity or 1)
    
    local itemName, itemLink = C_Item.GetItemInfo(resultData.itemID)
    local totalPrice = resultData.unitPrice * quantity
    local marketPrice = resultData.marketPrice or resultData.unitPrice
    
    local dialog = StaticPopup_Show("QUICKFLIP_CONFIRM_BUY", 
        itemLink or itemName or "Item",
        self:FormatGold(totalPrice),
        self:FormatGold(marketPrice * quantity),
        self:FormatPercent(resultData.marketPercent))
    
    if dialog then
        dialog.data = {
            resultData = resultData,
            quantity = quantity,
            itemName = itemName,
            totalPrice = totalPrice,
        }
    end
end

function QF:ExecuteBuy(data)
    if not data then return end
    
    local result = data.resultData or data
    local quantity = data.quantity or 1
    
    if result.isCommodity then
        -- Commodity purchase
        C_AuctionHouse.StartCommoditiesPurchase(result.itemID, quantity)
    else
        -- Item purchase
        if result.auctionID then
            C_AuctionHouse.PlaceBid(result.auctionID, result.unitPrice)
        end
    end
    
    self:Debug("Executing purchase:", data.itemName or result.itemID, "x", quantity)
end

-- Instant buy (skip confirmation for great deals)
function QF:InstantBuy(resultData, quantity)
    if not resultData then return end
    
    -- Safety check - only instant buy if it's really a deal
    if resultData.marketPercent and resultData.marketPercent < 70 then
        local data = {
            resultData = resultData,
            quantity = quantity or 1,
            itemName = C_Item.GetItemInfo(resultData.itemID) or "Item",
            totalPrice = resultData.unitPrice * (quantity or 1),
        }
        self:ExecuteBuy(data)
        return true
    end
    
    return false
end

-- Buy all deals below threshold
function QF:BuyAllDeals(maxPercent)
    maxPercent = maxPercent or 70
    local bought = 0
    
    for _, result in ipairs(self.searchResults) do
        if result.marketPercent and result.marketPercent <= maxPercent then
            if self:InstantBuy(result, result.quantity) then
                bought = bought + 1
            end
        end
    end
    
    if bought > 0 then
        self:Print("Bought", bought, "deals!")
    else
        self:Print("No deals below", maxPercent .. "% found")
    end
end

-------------------------------------------------------------------------------
-- Purchase Event Handlers
-------------------------------------------------------------------------------

function QF:OnPurchaseSucceeded(itemID)
    local itemName, itemLink = C_Item.GetItemInfo(itemID)
    self:Print("|cff00ff00Purchased:|r", itemLink or itemName or "Item")
    
    -- Record transaction with cost basis
    local result = self.searchResults[1]
    if result and result.itemID == itemID then
        self:RecordPurchase(itemID, result.unitPrice, 1, itemName)
    end
    
    -- Play success sound
    if self.config and self.config.soundAlerts then
        PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE)
    end
end

function QF:OnPurchaseFailed(itemID)
    local itemName, itemLink = C_Item.GetItemInfo(itemID)
    self:Print("|cffff0000Purchase failed:|r", itemLink or itemName or "Item", "- sold out or error")
end

function QF:OnItemPurchaseCompleted(auctionID)
    -- Find the auction in our results
    for _, result in ipairs(self.searchResults) do
        if result.auctionID == auctionID then
            local itemName, itemLink = C_Item.GetItemInfo(result.itemID)
            self:Print("|cff00ff00Purchased:|r", itemLink or itemName or "Item")
            self:RecordPurchase(result.itemID, result.unitPrice, result.quantity, itemName)
            break
        end
    end
end

-------------------------------------------------------------------------------
-- Deal Helpers
-------------------------------------------------------------------------------

function QF:GetBestDeals(maxPercent)
    maxPercent = maxPercent or 80
    local deals = {}
    
    for _, result in ipairs(self.searchResults) do
        if result.marketPercent and result.marketPercent <= maxPercent then
            table.insert(deals, result)
        end
    end
    
    table.sort(deals, function(a, b)
        return (a.marketPercent or 100) < (b.marketPercent or 100)
    end)
    
    return deals
end

function QF:HasDeals(maxPercent)
    return #self:GetBestDeals(maxPercent or 80) > 0
end

-------------------------------------------------------------------------------
-- Search Functions
-------------------------------------------------------------------------------

function QF:SearchItem(itemID)
    if not self.isAHOpen then
        self:Print("Auction House must be open!")
        return
    end
    
    local itemKey = C_AuctionHouse.MakeItemKey(itemID)
    if itemKey then
        C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
    end
end

function QF:SearchByName(searchString)
    if not self.isAHOpen then
        self:Print("Auction House must be open!")
        return
    end
    
    local query = {
        searchString = searchString,
        sorts = {
            {sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false},
        },
    }
    
    C_AuctionHouse.SendBrowseQuery(query)
end

-------------------------------------------------------------------------------
-- UI Update
-------------------------------------------------------------------------------

function QF:UpdateBuyingDisplay()
    if not self.buyFrame then return end
    
    -- Clear rows
    for _, row in ipairs(self.buyFrame.rows or {}) do
        row:Hide()
    end
    
    self.buyFrame.rows = self.buyFrame.rows or {}
    
    -- Show search item info
    if self.lastSearchItemID then
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(self.lastSearchItemID)
        if self.buyFrame.searchIcon then
            self.buyFrame.searchIcon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        if self.buyFrame.searchName then
            self.buyFrame.searchName:SetText(itemName or "Searching...")
        end
        if self.buyFrame.resultCount then
            self.buyFrame.resultCount:SetText(#self.searchResults .. " listings")
        end
    end
    
    -- Build rows
    local yOffset = -5
    local dealCount = 0
    
    for i, result in ipairs(self.searchResults) do
        if i > 25 then break end
        
        local row = self.buyFrame.rows[i]
        if not row then
            row = self:CreateBuyRow(self.buyFrame.scrollChild, i)
            self.buyFrame.rows[i] = row
        end
        
        self:UpdateBuyRow(row, result)
        row:SetPoint("TOPLEFT", self.buyFrame.scrollChild, "TOPLEFT", 0, yOffset)
        row:Show()
        
        yOffset = yOffset - 32
        
        if result.marketPercent and result.marketPercent < 80 then
            dealCount = dealCount + 1
        end
    end
    
    self.buyFrame.scrollChild:SetHeight(math.abs(yOffset) + 20)
    
    -- Update deal count
    if self.buyFrame.dealCount then
        if dealCount > 0 then
            self.buyFrame.dealCount:SetText("|cff00ff00" .. dealCount .. " deals!|r")
        else
            self.buyFrame.dealCount:SetText("")
        end
    end
end

function QF:CreateBuyRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(385, 30)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    
    -- Deal indicator bar (left edge)
    row.dealBar = row:CreateTexture(nil, "BACKGROUND")
    row.dealBar:SetSize(4, 28)
    row.dealBar:SetPoint("LEFT", 0, 0)
    
    -- Icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", 8, 0)
    
    -- Quantity
    row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.qty:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.qty:SetWidth(45)
    row.qty:SetJustifyH("LEFT")
    
    -- Price
    row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.price:SetPoint("LEFT", row.qty, "RIGHT", 5, 0)
    row.price:SetWidth(85)
    row.price:SetJustifyH("LEFT")
    
    -- Market %
    row.percent = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.percent:SetPoint("LEFT", row.price, "RIGHT", 5, 0)
    row.percent:SetWidth(55)
    
    -- Deal rating
    row.rating = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rating:SetPoint("LEFT", row.percent, "RIGHT", 5, 0)
    row.rating:SetWidth(60)
    
    -- Buy button
    row.buyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.buyBtn:SetSize(50, 24)
    row.buyBtn:SetPoint("RIGHT", -5, 0)
    row.buyBtn:SetText("Buy")
    
    -- Keyboard hint
    row.hint = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.hint:SetPoint("RIGHT", row.buyBtn, "LEFT", -5, 0)
    row.hint:SetTextColor(0.5, 0.5, 0.5)
    
    return row
end

function QF:UpdateBuyRow(row, data)
    local _, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(data.itemID)
    
    row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.qty:SetText("x" .. (data.quantity or 1))
    row.price:SetText(self:FormatGoldShort(data.unitPrice))
    
    -- Deal indicator bar color
    local r, g, b = self:GetPriceColor(data.marketPercent)
    row.dealBar:SetColorTexture(r, g, b, 0.8)
    
    -- Market percent
    row.percent:SetText(self:FormatPercent(data.marketPercent))
    
    -- Deal rating
    row.rating:SetText(data.dealRating or "")
    
    -- Keyboard hint for top rows
    if data.index and data.index <= 5 then
        row.hint:SetText("[" .. data.index .. "]")
    else
        row.hint:SetText("")
    end
    
    row.data = data
    
    -- Buy button styling based on deal quality
    if data.marketPercent and data.marketPercent < 70 then
        row.buyBtn:SetText("BUY!")
        -- Could add glow effect here
    else
        row.buyBtn:SetText("Buy")
    end
    
    row.buyBtn:SetScript("OnClick", function()
        QF:ConfirmBuy(data, data.isCommodity and 1 or data.quantity)
    end)
    
    -- Double-click for instant buy on great deals
    row:SetScript("OnDoubleClick", function()
        if data.marketPercent and data.marketPercent < 60 then
            QF:InstantBuy(data, 1)
        else
            QF:ConfirmBuy(data, 1)
        end
    end)
    
    -- Tooltip
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(data.itemID)
        GameTooltip:AddLine(" ")
        
        if data.marketPrice then
            GameTooltip:AddDoubleLine("Market Price:", QF:FormatGold(data.marketPrice), 1, 1, 1, 1, 1, 1)
        end
        if data.marketPercent then
            local cr, cg, cb = QF:GetPriceColor(data.marketPercent)
            GameTooltip:AddDoubleLine("This listing:", data.marketPercent .. "% of market", 1, 1, 1, cr, cg, cb)
        end
        
        local savings = data.marketPrice and (data.marketPrice - data.unitPrice) or 0
        if savings > 0 then
            GameTooltip:AddDoubleLine("You save:", QF:FormatGold(savings), 1, 1, 1, 0, 1, 0)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Double-click to instant buy deals|r")
        GameTooltip:AddLine("|cff888888Press 1-5 for quick buy|r")
        
        GameTooltip:Show()
    end)
    
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-------------------------------------------------------------------------------
-- Keyboard Shortcuts
-------------------------------------------------------------------------------

function QF:SetupBuyKeyBindings()
    if not self.buyFrame then return end
    
    self.buyFrame:EnableKeyboard(true)
    self.buyFrame:SetPropagateKeyboardInput(true)
    
    self.buyFrame:SetScript("OnKeyDown", function(self, key)
        local num = tonumber(key)
        if num and num >= 1 and num <= 5 then
            local result = QF.searchResults[num]
            if result then
                QF.buyFrame:SetPropagateKeyboardInput(false)
                QF:ConfirmBuy(result, 1)
                C_Timer.After(0.1, function()
                    QF.buyFrame:SetPropagateKeyboardInput(true)
                end)
                return
            end
        end
        self:SetPropagateKeyboardInput(true)
    end)
end

-------------------------------------------------------------------------------

QF:Debug("Buying.lua loaded")
