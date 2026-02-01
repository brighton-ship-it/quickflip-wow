--[[
    QuickFlip - UI.lua
    Modern, clean interface - Premium feel
]]

local addonName, QF = ...

-- UI Constants
local FRAME_WIDTH = 450
local FRAME_HEIGHT = 550
local TAB_HEIGHT = 28

-- Modern dark theme
local COLORS = {
    bg = {0.08, 0.08, 0.10, 0.97},
    bgLight = {0.12, 0.12, 0.14, 1},
    border = {0.25, 0.25, 0.28, 1},
    accent = {1, 0.82, 0, 1},
    text = {0.9, 0.9, 0.9, 1},
    textDim = {0.6, 0.6, 0.6, 1},
    positive = {0.2, 1, 0.4, 1},
    negative = {1, 0.3, 0.3, 1},
    tab = {0.15, 0.15, 0.17, 1},
    tabActive = {0.22, 0.22, 0.25, 1},
    tabHover = {0.18, 0.18, 0.20, 1},
}

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

function QF:CreateContentFrame(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetAllPoints()
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    frame:SetBackdropColor(unpack(COLORS.bg))
    return frame
end

function QF:CreateScrollFrame(parent, topOffset)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -(topOffset or 50))
    scroll:SetPoint("BOTTOMRIGHT", -28, 45)
    
    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(400, 500)
    scroll:SetScrollChild(scrollChild)
    
    return scroll, scrollChild
end

function QF:CreateButton(parent, text, width)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 80, 24)
    btn:SetText(text)
    return btn
end

-------------------------------------------------------------------------------
-- Main Frame
-------------------------------------------------------------------------------

function QF:CreateUI()
    if self.mainFrame then return end
    
    local frame = CreateFrame("Frame", "QuickFlipFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", 200, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    frame:SetBackdropColor(unpack(COLORS.bg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    
    -- Header
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetHeight(40)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
    header:SetBackdropColor(unpack(COLORS.bgLight))
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 15, 0)
    title:SetText("|cffFFD700Quick|r|cffffffffFlip|r")
    
    local version = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText("|cff888888v" .. QF.version .. "|r")
    
    local scanProgress = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scanProgress:SetPoint("CENTER", header, "CENTER", 0, 0)
    frame.scanProgress = scanProgress
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", -10, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetPoint("CENTER", 0, 1)
    closeX:SetText("×")
    closeX:SetTextColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(0.6, 0.6, 0.6) end)
    
    -- Tabs
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetHeight(TAB_HEIGHT)
    tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    
    self:CreateTabs(tabBar)
    
    -- Content
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.content = content
    
    self:CreateDealsFrame(content)
    self:CreateBuyFrame(content)
    self:CreateSellFrame(content)
    self:CreateSniperFrame(content)
    self:CreateFlipsFrame(content)
    self:CreateStatsFrame(content)
    
    self:ShowTab("sell")
    
    self.mainFrame = frame
    frame:Hide()
end

-------------------------------------------------------------------------------
-- Tab System
-------------------------------------------------------------------------------

function QF:CreateTabs(parent)
    local tabs = {
        {name = "deals", label = "★ Deals", width = 65},
        {name = "buy", label = "Buy", width = 45},
        {name = "sell", label = "Sell", width = 45},
        {name = "sniper", label = "Sniper", width = 55},
        {name = "flips", label = "Flips", width = 50},
        {name = "stats", label = "Stats", width = 50},
    }
    
    parent.tabs = {}
    local xOffset = 5
    
    for _, tabInfo in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
        tab:SetSize(tabInfo.width, TAB_HEIGHT - 4)
        tab:SetPoint("LEFT", xOffset, -2)
        tab:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
        tab:SetBackdropColor(unpack(COLORS.tab))
        
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(tabInfo.label)
        text:SetTextColor(0.8, 0.8, 0.8)
        tab.text = text
        tab.name = tabInfo.name
        
        tab:SetScript("OnClick", function() QF:ShowTab(tab.name) end)
        tab:SetScript("OnEnter", function(self)
            if self.name ~= QF.activeTab then self:SetBackdropColor(unpack(COLORS.tabHover)) end
        end)
        tab:SetScript("OnLeave", function(self)
            if self.name ~= QF.activeTab then self:SetBackdropColor(unpack(COLORS.tab)) end
        end)
        
        parent.tabs[tab.name] = tab
        xOffset = xOffset + tabInfo.width + 2
    end
    
    self.tabs = parent.tabs
end

function QF:ShowTab(tabName)
    self.activeTab = tabName
    
    for name, tab in pairs(self.tabs) do
        if name == tabName then
            tab:SetBackdropColor(unpack(COLORS.tabActive))
            tab.text:SetTextColor(1, 0.82, 0)
        else
            tab:SetBackdropColor(unpack(COLORS.tab))
            tab.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end
    
    if self.dealsFrame then self.dealsFrame:SetShown(tabName == "deals") end
    if self.buyFrame then self.buyFrame:SetShown(tabName == "buy") end
    if self.sellFrame then self.sellFrame:SetShown(tabName == "sell") end
    if self.sniperFrame then self.sniperFrame:SetShown(tabName == "sniper") end
    if self.flipsFrame then self.flipsFrame:SetShown(tabName == "flips") end
    if self.statsFrame then self.statsFrame:SetShown(tabName == "stats") end
    
    if tabName == "deals" then self:UpdateDealsDisplay()
    elseif tabName == "buy" then self:UpdateBuyingDisplay(); self:SetupBuyKeyBindings()
    elseif tabName == "sell" then self:ScanBags(); self:UpdateSellDisplay()
    elseif tabName == "sniper" then self:UpdateSniperDisplay()
    elseif tabName == "flips" then self:UpdateFlipsDisplay()
    elseif tabName == "stats" then self:UpdateStatsDisplay()
    end
end

function QF:ShowDealsTab()
    if not self.mainFrame then self:CreateUI() end
    self.mainFrame:Show()
    self:ShowTab("deals")
end

function QF:ShowFlipsTab()
    if not self.mainFrame then self:CreateUI() end
    self.mainFrame:Show()
    self:ShowTab("flips")
end

-------------------------------------------------------------------------------
-- Deals Frame
-------------------------------------------------------------------------------

function QF:CreateDealsFrame(parent)
    local frame = self:CreateContentFrame(parent)
    
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, -10)
    header:SetText("|cff00ff00★ Live Deals|r")
    
    local subheader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subheader:SetPoint("TOP", header, "BOTTOM", 0, -3)
    subheader:SetText("|cff888888Items below market value|r")
    
    local scroll, scrollChild = self:CreateScrollFrame(frame, 50)
    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.rows = {}
    
    local dealCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dealCount:SetPoint("BOTTOMLEFT", 15, 12)
    frame.dealCount = dealCount
    
    local refreshBtn = self:CreateButton(frame, "Scan Now", 90)
    refreshBtn:SetPoint("BOTTOMRIGHT", -15, 8)
    refreshBtn:SetScript("OnClick", function() QF:StartScan("fast") end)
    
    self.dealsFrame = frame
    frame:Hide()
end

function QF:UpdateDealsDisplay()
    if not self.dealsFrame then return end
    
    local deals = self:GetDeals(100, "score")
    
    for _, row in ipairs(self.dealsFrame.rows or {}) do row:Hide() end
    self.dealsFrame.rows = self.dealsFrame.rows or {}
    
    local yOffset = -5
    for i, deal in ipairs(deals) do
        if i > 30 then break end
        
        local row = self.dealsFrame.rows[i] or self:CreateDealRow(self.dealsFrame.scrollChild, i)
        self.dealsFrame.rows[i] = row
        
        self:UpdateDealRow(row, deal)
        row:SetPoint("TOPLEFT", self.dealsFrame.scrollChild, "TOPLEFT", 0, yOffset)
        row:Show()
        yOffset = yOffset - 36
    end
    
    self.dealsFrame.scrollChild:SetHeight(math.abs(yOffset) + 20)
    self.dealsFrame.dealCount:SetText("|cff00ff00" .. #deals .. "|r deals found")
end

function QF:CreateDealRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(400, 34)
    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    row:SetBackdropColor(0.1, 0.15, 0.1, 0.8)
    row:SetBackdropBorderColor(0, 0.5, 0, 0.5)
    
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 10, 0)
    
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 6)
    row.name:SetWidth(130)
    row.name:SetJustifyH("LEFT")
    
    row.priceInfo = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.priceInfo:SetPoint("LEFT", row.icon, "RIGHT", 8, -8)
    row.priceInfo:SetWidth(130)
    row.priceInfo:SetJustifyH("LEFT")
    
    row.savings = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.savings:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.savings:SetWidth(70)
    
    row.rating = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rating:SetPoint("LEFT", row.savings, "RIGHT", 5, 0)
    row.rating:SetWidth(60)
    
    row.buyBtn = self:CreateButton(row, "BUY", 50)
    row.buyBtn:SetPoint("RIGHT", -8, 0)
    
    return row
end

function QF:UpdateDealRow(row, deal)
    local itemName, _, quality, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(deal.itemID)
    
    row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
    row.name:SetText(itemName or "Item")
    row.name:SetTextColor(color.r, color.g, color.b)
    
    row.priceInfo:SetText(self:FormatGoldShort(deal.currentPrice) .. " |cff888888(mkt: " .. self:FormatGoldShort(deal.marketPrice) .. ")|r")
    row.savings:SetText("|cff00ff00-" .. self:FormatGoldShort(deal.marketPrice - deal.currentPrice) .. "|r")
    row.rating:SetText(self:GetDealRating(deal.percent))
    
    row.deal = deal
    row.buyBtn:SetScript("OnClick", function()
        QF:SearchItem(deal.itemID)
        QF:ShowTab("buy")
    end)
    
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(deal.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- Buy Frame
-------------------------------------------------------------------------------

function QF:CreateBuyFrame(parent)
    local frame = self:CreateContentFrame(parent)
    
    -- Search header
    local searchIcon = frame:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(32, 32)
    searchIcon:SetPoint("TOPLEFT", 15, -12)
    searchIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    frame.searchIcon = searchIcon
    
    local searchName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    searchName:SetPoint("LEFT", searchIcon, "RIGHT", 10, 5)
    searchName:SetText("Search for items...")
    frame.searchName = searchName
    
    local resultCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultCount:SetPoint("LEFT", searchIcon, "RIGHT", 10, -10)
    resultCount:SetTextColor(0.6, 0.6, 0.6)
    frame.resultCount = resultCount
    
    local dealCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dealCount:SetPoint("RIGHT", -15, 0)
    dealCount:SetPoint("TOP", 0, -25)
    frame.dealCount = dealCount
    
    -- Column headers
    local cols = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cols:SetPoint("TOPLEFT", 15, -55)
    cols:SetText("|cff888888     Qty        Price         %Mkt    Rating|r")
    
    local scroll, scrollChild = self:CreateScrollFrame(frame, 70)
    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.rows = {}
    
    -- Search box
    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(200, 22)
    searchBox:SetPoint("BOTTOMLEFT", 15, 10)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text ~= "" then QF:SearchByName(text) end
        self:ClearFocus()
    end)
    
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("BOTTOM", searchBox, "TOP", 0, 2)
    searchLabel:SetText("|cff888888Search (Enter to search)|r")
    
    -- Scan button
    local scanBtn = self:CreateButton(frame, "Scan AH", 80)
    scanBtn:SetPoint("BOTTOMRIGHT", -15, 8)
    scanBtn:SetScript("OnClick", function() QF:StartScan("browse") end)
    
    self.buyFrame = frame
    frame:Hide()
end

-------------------------------------------------------------------------------
-- Sell Frame
-------------------------------------------------------------------------------

function QF:CreateSellFrame(parent)
    local frame = self:CreateContentFrame(parent)
    
    -- Header
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 15, -10)
    header:SetText("|cff888888Item              Qty    Price      Profit    Spd|r")
    
    local scroll, scrollChild = self:CreateScrollFrame(frame, 30)
    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.rows = {}
    
    -- Bottom stats
    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalText:SetPoint("BOTTOMLEFT", 15, 35)
    frame.totalText = totalText
    
    local profitText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profitText:SetPoint("BOTTOMLEFT", 15, 18)
    frame.profitText = profitText
    
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMLEFT", 200, 27)
    countText:SetTextColor(0.6, 0.6, 0.6)
    frame.countText = countText
    
    -- Duration
    local durLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durLabel:SetPoint("BOTTOMRIGHT", -130, 12)
    durLabel:SetText("Duration:")
    
    local durBtn = self:CreateButton(frame, "24h", 45)
    durBtn:SetPoint("LEFT", durLabel, "RIGHT", 5, 0)
    durBtn.duration = 2
    durBtn:SetScript("OnClick", function(self)
        self.duration = (self.duration % 3) + 1
        local texts = {"12h", "24h", "48h"}
        self:SetText(texts[self.duration])
    end)
    frame.durationBtn = durBtn
    
    -- Post All button
    local postAllBtn = self:CreateButton(frame, "Post All", 70)
    postAllBtn:SetPoint("BOTTOMRIGHT", -15, 8)
    postAllBtn:SetScript("OnClick", function() QF:BulkPost() end)
    
    -- Refresh
    local refreshBtn = self:CreateButton(frame, "↻", 30)
    refreshBtn:SetPoint("RIGHT", postAllBtn, "LEFT", -5, 0)
    refreshBtn:SetScript("OnClick", function()
        QF:ScanBags()
        QF:RefreshSellPrices()
    end)
    
    self.sellFrame = frame
    frame:Hide()
end

-------------------------------------------------------------------------------
-- Sniper Frame
-------------------------------------------------------------------------------

function QF:CreateSniperFrame(parent)
    local frame = self:CreateContentFrame(parent)
    
    -- Status
    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    status:SetPoint("TOP", 0, -15)
    status:SetText("Sniper: |cffff0000OFF|r")
    frame.status = status
    
    -- Toggle
    local toggleBtn = self:CreateButton(frame, "Start Sniper", 120)
    toggleBtn:SetPoint("TOP", status, "BOTTOM", 0, -10)
    toggleBtn:SetScript("OnClick", function()
        QF:ToggleSniper()
    end)
    frame.toggleBtn = toggleBtn
    
    -- Watchlist header
    local watchHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    watchHeader:SetPoint("TOPLEFT", 15, -80)
    watchHeader:SetText("|cffFFD700Watchlist|r |cff888888(items to snipe)|r")
    
    local scroll, scrollChild = self:CreateScrollFrame(frame, 100)
    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.rows = {}
    
    -- Add item
    local addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", 15, 50)
    addLabel:SetText("Add item (ID or drag):")
    
    local addBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    addBox:SetSize(80, 20)
    addBox:SetPoint("LEFT", addLabel, "RIGHT", 5, 0)
    addBox:SetAutoFocus(false)
    addBox:SetScript("OnEnterPressed", function(self)
        local id = tonumber(self:GetText())
        if id then
            QF:AddToWatchlist(id)
            QF:UpdateSniperDisplay()
        end
        self:SetText("")
        self:ClearFocus()
    end)
    addBox:SetScript("OnReceiveDrag", function()
        local type, id = GetCursorInfo()
        if type == "item" then
            QF:AddToWatchlist(id)
            QF:UpdateSniperDisplay()
            ClearCursor()
        end
    end)
    
    -- Threshold
    local threshLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    threshLabel:SetPoint("BOTTOMLEFT", 15, 25)
    threshLabel:SetText("Alert at ≤")
    
    local threshBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    threshBox:SetSize(40, 20)
    threshBox:SetPoint("LEFT", threshLabel, "RIGHT", 3, 0)
    threshBox:SetAutoFocus(false)
    threshBox:SetText(tostring(QF.config and QF.config.sniperThreshold or 70))
    threshBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 and val <= 100 then
            QF.config.sniperThreshold = val
        end
        self:ClearFocus()
    end)
    
    local pctLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctLabel:SetPoint("LEFT", threshBox, "RIGHT", 2, 0)
    pctLabel:SetText("% of market")
    
    self.sniperFrame = frame
    frame:Hide()
end

function QF:UpdateSniperDisplay()
    if not self.sniperFrame then return end
    
    for _, row in ipairs(self.sniperFrame.rows or {}) do row:Hide() end
    self.sniperFrame.rows = self.sniperFrame.rows or {}
    
    local watchlist = self:GetWatchlist()
    local yOffset = -5
    local i = 0
    
    for itemID, data in pairs(watchlist) do
        i = i + 1
        
        local row = self.sniperFrame.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.sniperFrame.scrollChild)
            row:SetSize(380, 28)
            
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 5, 0)
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.name:SetWidth(140)
            row.name:SetJustifyH("LEFT")
            
            row.threshold = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.threshold:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
            row.threshold:SetWidth(50)
            
            row.market = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.market:SetPoint("LEFT", row.threshold, "RIGHT", 10, 0)
            row.market:SetWidth(80)
            
            row.removeBtn = CreateFrame("Button", nil, row)
            row.removeBtn:SetSize(20, 20)
            row.removeBtn:SetPoint("RIGHT", -5, 0)
            local x = row.removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            x:SetPoint("CENTER")
            x:SetText("×")
            x:SetTextColor(0.8, 0.3, 0.3)
            row.removeBtn:SetScript("OnEnter", function() x:SetTextColor(1, 0.3, 0.3) end)
            row.removeBtn:SetScript("OnLeave", function() x:SetTextColor(0.8, 0.3, 0.3) end)
            
            self.sniperFrame.rows[i] = row
        end
        
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        local marketPrice = self:GetMarketPrice(itemID)
        
        row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(itemName or "Item " .. itemID)
        row.threshold:SetText("|cff00ff00≤" .. data.maxPercent .. "%|r")
        row.market:SetText(marketPrice and self:FormatGoldShort(marketPrice) or "|cff888888No data|r")
        
        row.removeBtn:SetScript("OnClick", function()
            QF:RemoveFromWatchlist(itemID)
            QF:UpdateSniperDisplay()
        end)
        
        row:SetPoint("TOPLEFT", self.sniperFrame.scrollChild, "TOPLEFT", 0, yOffset)
        row:Show()
        yOffset = yOffset - 30
    end
    
    self.sniperFrame.scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-------------------------------------------------------------------------------
-- Flips Frame
-------------------------------------------------------------------------------

function QF:CreateFlipsFrame(parent)
    local frame = self:CreateContentFrame(parent)
    
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, -10)
    header:SetText("|cffFFD700💰 Flip Suggestions|r")
    
    local subheader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subheader:SetPoint("TOP", header, "BOTTOM", 0, -3)
    subheader:SetText("|cff888888High margin + high volume items|r")
    
    local colHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colHeader:SetPoint("TOPLEFT", 15, -50)
    colHeader:SetText("|cff888888Item               Buy At    Sell At   Margin  Vol|r")
    
    local scroll, scrollChild = self:CreateScrollFrame(frame, 70)
    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.rows = {}
    
    local refreshBtn = self:CreateButton(frame, "Recalculate", 100)
    refreshBtn:SetPoint("BOTTOMRIGHT", -15, 8)
    refreshBtn:SetScript("OnClick", function()
        QF:CalculateFlipSuggestions()
        QF:UpdateFlipsDisplay()
    end)
    
    self.flipsFrame = frame
    frame:Hide()
end

function QF:UpdateFlipsDisplay()
    if not self.flipsFrame then return end
    
    local flips = self:GetFlipSuggestions()
    
    for _, row in ipairs(self.flipsFrame.rows or {}) do row:Hide() end
    self.flipsFrame.rows = self.flipsFrame.rows or {}
    
    local yOffset = -5
    for i, flip in ipairs(flips) do
        if i > 30 then break end
        
        local row = self.flipsFrame.rows[i]
        if not row then
            row = CreateFrame("Button", nil, self.flipsFrame.scrollChild)
            row:SetSize(400, 28)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 5, 0)
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.name:SetWidth(90)
            row.name:SetJustifyH("LEFT")
            
            row.buyAt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.buyAt:SetPoint("LEFT", row.name, "RIGHT", 5, 0)
            row.buyAt:SetWidth(55)
            
            row.sellAt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.sellAt:SetPoint("LEFT", row.buyAt, "RIGHT", 5, 0)
            row.sellAt:SetWidth(55)
            
            row.margin = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.margin:SetPoint("LEFT", row.sellAt, "RIGHT", 5, 0)
            row.margin:SetWidth(45)
            
            row.velocity = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.velocity:SetPoint("LEFT", row.margin, "RIGHT", 5, 0)
            row.velocity:SetWidth(35)
            
            row.watchBtn = self:CreateButton(row, "+", 25)
            row.watchBtn:SetPoint("RIGHT", -5, 0)
            
            self.flipsFrame.rows[i] = row
        end
        
        local itemName, _, quality, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(flip.itemID)
        
        row.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
        row.name:SetText(itemName or "Item")
        row.name:SetTextColor(color.r, color.g, color.b)
        
        row.buyAt:SetText("|cff00ff00" .. self:FormatGoldShort(flip.buyTarget) .. "|r")
        row.sellAt:SetText(self:FormatGoldShort(flip.sellTarget))
        row.margin:SetText("|cffFFD700+" .. floor(flip.marginPercent) .. "%|r")
        row.velocity:SetText(floor(flip.velocity) .. "/d")
        
        row.flip = flip
        row.watchBtn:SetScript("OnClick", function()
            local maxPct = floor((flip.buyTarget / flip.marketPrice) * 100)
            QF:AddToWatchlist(flip.itemID, maxPct)
        end)
        
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(flip.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        row:SetPoint("TOPLEFT", self.flipsFrame.scrollChild, "TOPLEFT", 0, yOffset)
        row:Show()
        yOffset = yOffset - 30
    end
    
    self.flipsFrame.scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-------------------------------------------------------------------------------
-- Stats Frame
-------------------------------------------------------------------------------

function QF:CreateStatsFrame(parent)
    local frame = self:CreateContentFrame(parent)
    
    -- Session stats
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cffFFD700📊 Profit Tracking|r")
    
    local yPos = -50
    
    -- Session Gold
    local sessionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionLabel:SetPoint("TOPLEFT", 20, yPos)
    sessionLabel:SetText("Session Gold:")
    
    local sessionValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sessionValue:SetPoint("TOPRIGHT", -20, yPos)
    frame.sessionValue = sessionValue
    
    yPos = yPos - 30
    
    -- Today
    local todayHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    todayHeader:SetPoint("TOPLEFT", 20, yPos)
    todayHeader:SetText("|cffFFD700Today|r")
    yPos = yPos - 20
    
    local todayBought = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todayBought:SetPoint("TOPLEFT", 30, yPos)
    todayBought:SetText("Spent:")
    local todayBoughtVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todayBoughtVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.todayBoughtVal = todayBoughtVal
    yPos = yPos - 18
    
    local todaySold = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todaySold:SetPoint("TOPLEFT", 30, yPos)
    todaySold:SetText("Earned:")
    local todaySoldVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todaySoldVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.todaySoldVal = todaySoldVal
    yPos = yPos - 18
    
    local todayProfit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    todayProfit:SetPoint("TOPLEFT", 30, yPos)
    todayProfit:SetText("Profit:")
    local todayProfitVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    todayProfitVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.todayProfitVal = todayProfitVal
    yPos = yPos - 35
    
    -- Week
    local weekHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weekHeader:SetPoint("TOPLEFT", 20, yPos)
    weekHeader:SetText("|cffFFD700This Week|r")
    yPos = yPos - 20
    
    local weekBought = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weekBought:SetPoint("TOPLEFT", 30, yPos)
    weekBought:SetText("Spent:")
    local weekBoughtVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weekBoughtVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.weekBoughtVal = weekBoughtVal
    yPos = yPos - 18
    
    local weekSold = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weekSold:SetPoint("TOPLEFT", 30, yPos)
    weekSold:SetText("Earned:")
    local weekSoldVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    weekSoldVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.weekSoldVal = weekSoldVal
    yPos = yPos - 18
    
    local weekProfit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weekProfit:SetPoint("TOPLEFT", 30, yPos)
    weekProfit:SetText("Profit:")
    local weekProfitVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weekProfitVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.weekProfitVal = weekProfitVal
    yPos = yPos - 35
    
    -- All Time
    local allHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    allHeader:SetPoint("TOPLEFT", 20, yPos)
    allHeader:SetText("|cffFFD700All Time|r")
    yPos = yPos - 20
    
    local allProfit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    allProfit:SetPoint("TOPLEFT", 30, yPos)
    allProfit:SetText("Total Profit:")
    local allProfitVal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    allProfitVal:SetPoint("TOPRIGHT", -20, yPos)
    frame.allProfitVal = allProfitVal
    yPos = yPos - 35
    
    -- Database stats
    local dbHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbHeader:SetPoint("TOPLEFT", 20, yPos)
    dbHeader:SetText("|cff888888Database|r")
    yPos = yPos - 18
    
    local dbStats = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dbStats:SetPoint("TOPLEFT", 30, yPos)
    dbStats:SetTextColor(0.6, 0.6, 0.6)
    frame.dbStats = dbStats
    
    self.statsFrame = frame
    frame:Hide()
end

function QF:UpdateStatsDisplay()
    if not self.statsFrame then return end
    
    local stats = self:GetSessionStats()
    local dbStats = self:GetDBStats()
    
    -- Session
    local color = stats.sessionGold >= 0 and "|cff00ff00" or "|cffff0000"
    self.statsFrame.sessionValue:SetText(color .. self:FormatGold(stats.sessionGold) .. "|r")
    
    -- Today
    self.statsFrame.todayBoughtVal:SetText(self:FormatGold(stats.today.bought))
    self.statsFrame.todaySoldVal:SetText(self:FormatGold(stats.today.sold))
    local tColor = stats.today.profit >= 0 and "|cff00ff00" or "|cffff0000"
    self.statsFrame.todayProfitVal:SetText(tColor .. self:FormatGold(stats.today.profit) .. "|r")
    
    -- Week
    self.statsFrame.weekBoughtVal:SetText(self:FormatGold(stats.week.bought))
    self.statsFrame.weekSoldVal:SetText(self:FormatGold(stats.week.sold))
    local wColor = stats.week.profit >= 0 and "|cff00ff00" or "|cffff0000"
    self.statsFrame.weekProfitVal:SetText(wColor .. self:FormatGold(stats.week.profit) .. "|r")
    
    -- All time
    local aColor = stats.totalProfit >= 0 and "|cff00ff00" or "|cffff0000"
    self.statsFrame.allProfitVal:SetText(aColor .. self:FormatGold(stats.totalProfit) .. "|r")
    
    -- DB
    self.statsFrame.dbStats:SetText(format("%d prices | %d watchlist | %d deals | %d flips",
        dbStats.priceEntries, dbStats.watchlistItems, dbStats.activeDeals, dbStats.flipSuggestions))
end

function QF:ShowStats()
    if not self.mainFrame then self:CreateUI() end
    self.mainFrame:Show()
    self:ShowTab("stats")
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function QF:RefreshUI()
    if self.activeTab == "deals" then self:UpdateDealsDisplay()
    elseif self.activeTab == "buy" then self:UpdateBuyingDisplay()
    elseif self.activeTab == "sell" then self:UpdateSellDisplay()
    elseif self.activeTab == "sniper" then self:UpdateSniperDisplay()
    elseif self.activeTab == "flips" then self:UpdateFlipsDisplay()
    elseif self.activeTab == "stats" then self:UpdateStatsDisplay()
    end
end

-------------------------------------------------------------------------------

QF:Debug("UI.lua loaded")
