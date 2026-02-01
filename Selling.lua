--[[
    QuickFlip - Selling.lua
    Bag scanning, auction posting
    Classic Era (Interface 11503)
]]

local addonName, QF = ...

-------------------------------------------------------------------------------
-- Bag Scanning
-------------------------------------------------------------------------------

QF.bagItems = {}
QF.selectedBagItem = nil

-- Duration options (Classic: 1=12h, 2=24h, 3=48h)
QF.durations = {
    { value = 1, text = "12 hours" },
    { value = 2, text = "24 hours" },
    { value = 3, text = "48 hours" }
}
QF.selectedDuration = 2  -- Default to 24h

function QF:ScanBags()
    self.bagItems = {}
    
    -- Scan bags 0-4
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
            
            if itemID and count and count > 0 then
                -- Check if item is tradeable (has sell price and not soulbound)
                local itemName, itemLink, itemQuality, itemLevel, reqLevel, class, subclass, 
                      maxStack, equipSlot, itemTexture, sellPrice = GetItemInfo(link or itemID)
                
                -- Get tooltip to check soulbound status
                local isSoulbound = false
                local tooltipFrame = CreateFrame("GameTooltip", "QFScanTooltip", nil, "GameTooltipTemplate")
                tooltipFrame:SetOwner(WorldFrame, "ANCHOR_NONE")
                tooltipFrame:SetBagItem(bag, slot)
                
                for i = 1, tooltipFrame:NumLines() do
                    local text = _G["QFScanTooltipTextLeft" .. i]
                    if text then
                        local lineText = text:GetText()
                        if lineText and (lineText == ITEM_SOULBOUND or lineText == ITEM_BIND_ON_PICKUP) then
                            isSoulbound = true
                            break
                        end
                    end
                end
                tooltipFrame:Hide()
                
                if not isSoulbound and itemName then
                    -- Check if we already have this item in our list
                    local found = false
                    for _, item in ipairs(self.bagItems) do
                        if item.itemID == itemID then
                            item.count = item.count + count
                            item.stacks = item.stacks + 1
                            found = true
                            break
                        end
                    end
                    
                    if not found then
                        table.insert(self.bagItems, {
                            bag = bag,
                            slot = slot,
                            itemID = itemID,
                            name = itemName,
                            link = link or itemLink,
                            texture = texture or itemTexture,
                            count = count,
                            stacks = 1,
                            quality = quality or itemQuality,
                            maxStack = maxStack or 1
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by name
    table.sort(self.bagItems, function(a, b)
        return a.name < b.name
    end)
    
    self:Debug("Scanned bags:", #self.bagItems, "unique items")
    self:UpdateSellList()
end

-------------------------------------------------------------------------------
-- Sell List UI
-------------------------------------------------------------------------------

function QF:UpdateSellList()
    if not self.sellFrame or not self.sellFrame.scrollContent then return end
    
    local scrollContent = self.sellFrame.scrollContent
    
    -- Clear existing buttons
    if self.sellButtons then
        for _, btn in ipairs(self.sellButtons) do
            btn:Hide()
        end
    end
    self.sellButtons = {}
    
    local yOffset = 0
    
    for i, item in ipairs(self.bagItems) do
        local btn = self:CreateSellItemButton(scrollContent, item, i)
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn:Show()
        table.insert(self.sellButtons, btn)
        yOffset = yOffset + 32
    end
    
    -- Update scroll content height
    scrollContent:SetHeight(math.max(1, yOffset))
    
    -- Update item count
    if self.sellFrame.itemCount then
        self.sellFrame.itemCount:SetText(#self.bagItems .. " items")
    end
end

function QF:CreateSellItemButton(parent, item, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(parent:GetWidth() - 20, 30)
    
    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    btn.bg = bg
    
    -- Highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    
    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexture(item.texture)
    
    -- Item name
    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameText:SetWidth(120)
    nameText:SetJustifyH("LEFT")
    
    local qualityColor = ITEM_QUALITY_COLORS[item.quality or 1]
    if qualityColor then
        nameText:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
    end
    nameText:SetText(item.name)
    
    -- Count
    local countText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
    countText:SetWidth(40)
    countText:SetJustifyH("RIGHT")
    countText:SetText("x" .. item.count)
    countText:SetTextColor(0.7, 0.7, 0.7)
    
    -- Market price
    local priceText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceText:SetPoint("LEFT", countText, "RIGHT", 10, 0)
    priceText:SetWidth(80)
    priceText:SetJustifyH("RIGHT")
    
    local marketPrice = self:GetMarketPrice(item.itemID)
    if marketPrice then
        priceText:SetText(self:FormatGoldShort(marketPrice))
        priceText:SetTextColor(1, 0.82, 0)
    else
        priceText:SetText("No data")
        priceText:SetTextColor(0.5, 0.5, 0.5)
    end
    
    -- Store item data
    btn.item = item
    
    -- Click handler - put in sell slot
    btn:SetScript("OnClick", function(self)
        QF:SelectBagItem(self.item)
    end)
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        if self.item.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.item.link)
            GameTooltip:Show()
        end
    end)
    
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return btn
end

-------------------------------------------------------------------------------
-- Item Selection & Posting
-------------------------------------------------------------------------------

function QF:SelectBagItem(item)
    self.selectedBagItem = item
    
    -- Find the first stack of this item and put it in the sell slot
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
            if itemID == item.itemID then
                -- Clear any existing item
                ClearCursor()
                
                -- Pick up the item
                PickupContainerItem(bag, slot)
                
                -- Put it in the auction sell slot
                ClickAuctionSellItemButton()
                
                -- Update the sell info
                self:UpdateSellInfo()
                return
            end
        end
    end
    
    self:Print("Could not find item in bags!")
end

function QF:UpdateSellInfo()
    if not self.sellFrame then return end
    
    -- Get info about item in sell slot
    local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo()
    
    if not name then
        -- No item in sell slot
        if self.sellFrame.sellItemName then
            self.sellFrame.sellItemName:SetText("Drop item here")
        end
        if self.sellFrame.postButton then
            self.sellFrame.postButton:Disable()
        end
        return
    end
    
    -- Update display
    if self.sellFrame.sellItemName then
        self.sellFrame.sellItemName:SetText(name .. " x" .. (count or 1))
    end
    
    if self.sellFrame.sellItemIcon then
        self.sellFrame.sellItemIcon:SetTexture(texture)
    end
    
    -- Get suggested price from database
    local itemID = self.selectedBagItem and self.selectedBagItem.itemID
    local marketPrice = itemID and self:GetMarketPrice(itemID)
    
    if marketPrice then
        -- Suggest slightly below market
        local suggestedPrice = math.floor(marketPrice * 0.95)
        
        if self.sellFrame.priceBox then
            -- Set price in the editbox (as copper)
            local gold = math.floor(suggestedPrice / 10000)
            local silver = math.floor((suggestedPrice % 10000) / 100)
            self.sellFrame.priceBox:SetText(gold .. "g " .. silver .. "s")
        end
        
        if self.sellFrame.marketPriceText then
            self.sellFrame.marketPriceText:SetText("Market: " .. self:FormatGold(marketPrice))
        end
    end
    
    -- Calculate deposit
    local deposit = CalculateAuctionDeposit(self.selectedDuration)
    if self.sellFrame.depositText then
        self.sellFrame.depositText:SetText("Deposit: " .. self:FormatGold(deposit))
    end
    
    -- Enable post button
    if self.sellFrame.postButton then
        self.sellFrame.postButton:Enable()
    end
end

function QF:ParsePriceInput(text)
    if not text or text == "" then return 0 end
    
    local copper = 0
    
    -- Parse gold
    local gold = text:match("(%d+)%s*g")
    if gold then copper = copper + tonumber(gold) * 10000 end
    
    -- Parse silver
    local silver = text:match("(%d+)%s*s")
    if silver then copper = copper + tonumber(silver) * 100 end
    
    -- Parse copper
    local cop = text:match("(%d+)%s*c")
    if cop then copper = copper + tonumber(cop) end
    
    -- If no units specified, assume it's just a number (gold)
    if copper == 0 then
        local num = tonumber(text)
        if num then copper = num * 10000 end
    end
    
    return copper
end

function QF:PostAuction()
    -- Check if item is in sell slot
    local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo()
    if not name then
        self:Print("No item in sell slot!")
        return
    end
    
    -- Get price from input
    local priceText = self.sellFrame.priceBox and self.sellFrame.priceBox:GetText() or ""
    local buyoutPrice = self:ParsePriceInput(priceText)
    
    if buyoutPrice <= 0 then
        self:Print("Invalid price!")
        return
    end
    
    -- Start price slightly lower than buyout
    local startPrice = math.floor(buyoutPrice * 0.95)
    
    -- Duration
    local duration = self.selectedDuration
    
    -- Post the auction
    StartAuction(startPrice, buyoutPrice, duration)
    
    -- Record the sale attempt
    local itemID = self.selectedBagItem and self.selectedBagItem.itemID
    if itemID then
        self:RecordSale(itemID, buyoutPrice, count)
    end
    
    local durationText = self.durations[duration] and self.durations[duration].text or "?"
    self:Print("Posted " .. name .. " for " .. self:FormatGold(buyoutPrice) .. " (" .. durationText .. ")")
    
    -- Clear selection and refresh
    self.selectedBagItem = nil
    
    -- Delay to let AH update
    local delay = CreateFrame("Frame")
    delay.elapsed = 0
    delay:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.5 then
            self:SetScript("OnUpdate", nil)
            QF:ScanBags()
            QF:UpdateSellInfo()
        end
    end)
end

-------------------------------------------------------------------------------
-- Your Auctions
-------------------------------------------------------------------------------

function QF:GetMyAuctions()
    local auctions = {}
    local numAuctions = GetNumAuctionItems("owner")
    
    for i = 1, numAuctions do
        local name, texture, count, quality, canUse, level, levelColHeader,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemId, 
              hasAllInfo = GetAuctionItemInfo("owner", i)
        
        if name then
            table.insert(auctions, {
                index = i,
                name = name,
                texture = texture,
                count = count,
                quality = quality,
                minBid = minBid,
                buyoutPrice = buyoutPrice,
                bidAmount = bidAmount,
                highBidder = highBidder,
                saleStatus = saleStatus,
                itemId = itemId
            })
        end
    end
    
    return auctions
end

function QF:CancelAuction(index)
    CancelAuction(index)
    self:Print("Cancelled auction #" .. index)
end

QF:Debug("Selling.lua loaded")
