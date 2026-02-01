--[[
    QuickFlip - Buying.lua
    Search display, deal detection, and purchasing
    Classic Era (Interface 11503)
]]

local addonName, QF = ...

-------------------------------------------------------------------------------
-- Search Results
-------------------------------------------------------------------------------

QF.lastSearchResults = {}
QF.selectedAuction = nil

-------------------------------------------------------------------------------
-- Search Function
-------------------------------------------------------------------------------

function QF:DoSearch(searchText)
    if not searchText or searchText == "" then
        self.lastSearchResults = {}
        self:UpdateBuyList()
        return
    end
    
    self:StartSearch(searchText, function(results)
        self.lastSearchResults = results or {}
        self:SortResults()
        self:UpdateBuyList()
    end)
end

function QF:SortResults()
    -- Sort by unit price (lowest first)
    table.sort(self.lastSearchResults, function(a, b)
        return (a.unitPrice or 0) < (b.unitPrice or 0)
    end)
end

-------------------------------------------------------------------------------
-- Buy List UI Update
-------------------------------------------------------------------------------

function QF:UpdateBuyList()
    if not self.buyFrame or not self.buyFrame.scrollFrame then return end
    
    local scrollContent = self.buyFrame.scrollContent
    
    -- Clear existing buttons
    if self.buyButtons then
        for _, btn in ipairs(self.buyButtons) do
            btn:Hide()
        end
    end
    self.buyButtons = {}
    
    local results = self.lastSearchResults or {}
    local yOffset = 0
    
    for i, auction in ipairs(results) do
        local btn = self:CreateAuctionButton(scrollContent, auction, i)
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn:Show()
        table.insert(self.buyButtons, btn)
        yOffset = yOffset + 32
    end
    
    -- Update scroll content height
    scrollContent:SetHeight(math.max(1, yOffset))
    
    -- Update result count
    if self.buyFrame.resultCount then
        self.buyFrame.resultCount:SetText(#results .. " results")
    end
end

function QF:CreateAuctionButton(parent, auction, index)
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
    icon:SetTexture(auction.texture)
    
    -- Item name with quality color
    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameText:SetWidth(150)
    nameText:SetJustifyH("LEFT")
    
    local qualityColor = ITEM_QUALITY_COLORS[auction.quality or 1]
    if qualityColor then
        nameText:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
    end
    
    local displayName = auction.name
    if auction.count > 1 then
        displayName = displayName .. " x" .. auction.count
    end
    nameText:SetText(displayName)
    
    -- Unit price
    local priceText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceText:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
    priceText:SetWidth(80)
    priceText:SetJustifyH("RIGHT")
    priceText:SetText(self:FormatGoldShort(auction.unitPrice))
    
    -- Percent of market
    local pctText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctText:SetPoint("LEFT", priceText, "RIGHT", 10, 0)
    pctText:SetWidth(50)
    pctText:SetJustifyH("RIGHT")
    
    local percent = self:GetPercentOfMarket(auction.itemId, auction.unitPrice)
    if percent then
        local r, g, b = self:GetPriceColor(percent)
        pctText:SetText(percent .. "%")
        pctText:SetTextColor(r, g, b)
        
        -- Color row background for deals
        if percent < 80 then
            bg:SetColorTexture(0, 0.2, 0, 0.5)
        elseif percent > 100 then
            bg:SetColorTexture(0.2, 0, 0, 0.3)
        end
    else
        pctText:SetText("--")
        pctText:SetTextColor(0.5, 0.5, 0.5)
    end
    
    -- Store auction data
    btn.auction = auction
    
    -- Click handler
    btn:SetScript("OnClick", function(self)
        QF:SelectAuction(self.auction)
    end)
    
    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        if self.auction.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.auction.link)
            GameTooltip:Show()
        end
    end)
    
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return btn
end

-------------------------------------------------------------------------------
-- Auction Selection
-------------------------------------------------------------------------------

function QF:SelectAuction(auction)
    self.selectedAuction = auction
    
    -- Update selection highlight
    if self.buyButtons then
        for _, btn in ipairs(self.buyButtons) do
            if btn.auction == auction then
                btn.bg:SetColorTexture(0.2, 0.3, 0.5, 0.8)
            else
                local percent = self:GetPercentOfMarket(btn.auction.itemId, btn.auction.unitPrice)
                if percent and percent < 80 then
                    btn.bg:SetColorTexture(0, 0.2, 0, 0.5)
                elseif percent and percent > 100 then
                    btn.bg:SetColorTexture(0.2, 0, 0, 0.3)
                else
                    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
                end
            end
        end
    end
    
    -- Update buy button
    self:UpdateBuyButton()
end

function QF:UpdateBuyButton()
    if not self.buyFrame or not self.buyFrame.buyButton then return end
    
    local btn = self.buyFrame.buyButton
    
    if self.selectedAuction then
        local price = self.selectedAuction.buyoutPrice
        btn:SetText("Buy: " .. self:FormatGoldShort(price))
        btn:Enable()
    else
        btn:SetText("Select an auction")
        btn:Disable()
    end
end

-------------------------------------------------------------------------------
-- Purchase Execution
-------------------------------------------------------------------------------

function QF:BuySelectedAuction()
    if not self.selectedAuction then
        self:Print("No auction selected!")
        return
    end
    
    local auction = self.selectedAuction
    
    -- Verify auction still exists at the expected index
    local name = GetAuctionItemInfo("list", auction.index)
    if not name or name ~= auction.name then
        self:Print("Auction no longer available!")
        self:DoSearch(self.buyFrame.searchBox:GetText())
        return
    end
    
    -- Check if we have enough gold
    local playerGold = GetMoney()
    if playerGold < auction.buyoutPrice then
        self:Print("Not enough gold!")
        return
    end
    
    -- Execute purchase (buyout)
    PlaceAuctionBid("list", auction.index, auction.buyoutPrice)
    
    -- Record the purchase
    self:RecordPurchase(auction.itemId, auction.buyoutPrice, auction.count)
    
    self:Print("Bought " .. auction.name .. " x" .. auction.count .. " for " .. self:FormatGold(auction.buyoutPrice))
    
    -- Clear selection and refresh
    self.selectedAuction = nil
    
    -- Delay refresh to let AH update
    local delay = CreateFrame("Frame")
    delay.elapsed = 0
    delay:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.5 then
            self:SetScript("OnUpdate", nil)
            if QF.buyFrame and QF.buyFrame.searchBox then
                QF:DoSearch(QF.buyFrame.searchBox:GetText())
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Quick Buy (for deals)
-------------------------------------------------------------------------------

function QF:QuickBuyDeal(index)
    local name, texture, count, quality, canUse, level, levelColHeader,
          minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
          bidderFullName, owner, ownerFullName, saleStatus, itemId, 
          hasAllInfo = GetAuctionItemInfo("list", index)
    
    if not name or not buyoutPrice or buyoutPrice == 0 then
        return false
    end
    
    local playerGold = GetMoney()
    if playerGold < buyoutPrice then
        return false
    end
    
    PlaceAuctionBid("list", index, buyoutPrice)
    self:RecordPurchase(itemId, buyoutPrice, count)
    self:Print("Quick bought " .. name .. " for " .. self:FormatGold(buyoutPrice))
    
    return true
end

QF:Debug("Buying.lua loaded")
