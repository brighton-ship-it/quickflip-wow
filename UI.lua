--[[
    QuickFlip - UI.lua
    Main frame, tabs, and all visual elements
    Classic Era (Interface 11503)
]]

local addonName, QF = ...

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local FRAME_WIDTH = 350
local FRAME_HEIGHT = 400
local TAB_HEIGHT = 24
local HEADER_HEIGHT = 30

-------------------------------------------------------------------------------
-- Main Frame Creation
-------------------------------------------------------------------------------

function QF:CreateUI()
    if self.mainFrame then return end
    
    -- Main frame
    local frame = CreateFrame("Frame", "QuickFlipFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("LEFT", AuctionFrame, "RIGHT", 10, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    
    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(FRAME_WIDTH - 16, HEADER_HEIGHT)
    titleBar:SetPoint("TOP", 0, -8)
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cffFFD700QuickFlip|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Tab container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetSize(FRAME_WIDTH - 16, TAB_HEIGHT)
    tabContainer:SetPoint("TOP", titleBar, "BOTTOM", 0, -4)
    
    -- Content container
    local contentContainer = CreateFrame("Frame", nil, frame)
    contentContainer:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, -4)
    contentContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    
    frame.contentContainer = contentContainer
    self.mainFrame = frame
    
    -- Create tabs
    self:CreateTabs(tabContainer)
    
    -- Create tab content frames
    self:CreateScanTab(contentContainer)
    self:CreateBuyTab(contentContainer)
    self:CreateSellTab(contentContainer)
    self:CreateStatsTab(contentContainer)
    
    -- Show scan tab by default
    self:ShowTab("scan")
    
    self:Debug("UI created")
end

-------------------------------------------------------------------------------
-- Tab System
-------------------------------------------------------------------------------

function QF:CreateTabs(parent)
    local tabs = {
        { name = "scan", text = "Scan" },
        { name = "buy", text = "Buy" },
        { name = "sell", text = "Sell" },
        { name = "stats", text = "Stats" }
    }
    
    self.tabs = {}
    local tabWidth = (FRAME_WIDTH - 20) / #tabs
    
    for i, tabInfo in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
        tab:SetSize(tabWidth - 2, TAB_HEIGHT - 2)
        tab:SetPoint("LEFT", (i - 1) * tabWidth + 1, 0)
        
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tab:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(tabInfo.text)
        tab.text = text
        
        tab.name = tabInfo.name
        
        tab:SetScript("OnClick", function(self)
            QF:ShowTab(self.name)
        end)
        
        tab:SetScript("OnEnter", function(self)
            if self.name ~= QF.activeTab then
                self:SetBackdropColor(0.3, 0.3, 0.3, 0.8)
            end
        end)
        
        tab:SetScript("OnLeave", function(self)
            if self.name ~= QF.activeTab then
                self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.tabs[tabInfo.name] = tab
    end
end

function QF:ShowTab(tabName)
    self.activeTab = tabName
    
    -- Update tab appearance
    for name, tab in pairs(self.tabs) do
        if name == tabName then
            tab:SetBackdropColor(0.3, 0.4, 0.5, 1)
            tab.text:SetTextColor(1, 0.82, 0)
        else
            tab:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            tab.text:SetTextColor(1, 1, 1)
        end
    end
    
    -- Show/hide content frames
    if self.scanFrame then self.scanFrame:SetShown(tabName == "scan") end
    if self.buyFrame then self.buyFrame:SetShown(tabName == "buy") end
    if self.sellFrame then self.sellFrame:SetShown(tabName == "sell") end
    if self.statsFrame then self.statsFrame:SetShown(tabName == "stats") end
    
    -- Refresh content when shown
    if tabName == "sell" then
        self:ScanBags()
    elseif tabName == "stats" then
        self:UpdateStatsDisplay()
    end
end

-------------------------------------------------------------------------------
-- Scan Tab
-------------------------------------------------------------------------------

function QF:CreateScanTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.scanFrame = frame
    
    -- Full scan button
    local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanBtn:SetSize(120, 28)
    scanBtn:SetPoint("TOP", 0, -10)
    scanBtn:SetText("Full Scan")
    scanBtn:SetScript("OnClick", function()
        QF:StartFullScan()
    end)
    frame.scanButton = scanBtn
    
    -- Progress text
    local progressText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("TOP", scanBtn, "BOTTOM", 0, -10)
    progressText:SetText("")
    frame.progressText = progressText
    
    -- Progress bar
    local progressBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    progressBg:SetSize(200, 16)
    progressBg:SetPoint("TOP", progressText, "BOTTOM", 0, -5)
    progressBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    progressBg:SetBackdropColor(0.1, 0.1, 0.1, 1)
    progressBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local progressBar = CreateFrame("Frame", nil, progressBg)
    progressBar:SetPoint("LEFT", 2, 0)
    progressBar:SetSize(0, 12)
    
    local progressFill = progressBar:CreateTexture(nil, "ARTWORK")
    progressFill:SetAllPoints()
    progressFill:SetColorTexture(0.2, 0.6, 0.2, 1)
    
    progressBar.SetValue = function(self, value)
        self:SetWidth(math.max(1, 196 * value))
    end
    progressBar:SetValue(0)
    frame.progressBar = progressBar
    
    -- Database info
    local dbInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbInfo:SetPoint("TOP", progressBg, "BOTTOM", 0, -20)
    dbInfo:SetText("")
    frame.dbInfo = dbInfo
    
    -- Update info
    self:UpdateScanInfo()
    
    -- Timer for cooldown display
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 1 then
            self.elapsed = 0
            QF:UpdateScanButton()
            QF:UpdateScanInfo()
        end
    end)
end

function QF:UpdateScanInfo()
    if not self.scanFrame or not self.scanFrame.dbInfo then return end
    
    local itemCount = self:TableCount(self.db and self.db.prices or {})
    local lastScan = self.db and self.db.lastFullScan or 0
    local lastScanText = lastScan > 0 and self:TimeAgo(lastScan) or "never"
    
    self.scanFrame.dbInfo:SetText(
        "|cffFFD700Database:|r " .. itemCount .. " items\n" ..
        "|cffFFD700Last scan:|r " .. lastScanText
    )
end

-------------------------------------------------------------------------------
-- Buy Tab
-------------------------------------------------------------------------------

function QF:CreateBuyTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.buyFrame = frame
    
    -- Search box
    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(200, 22)
    searchBox:SetPoint("TOPLEFT", 10, -10)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnEnterPressed", function(self)
        QF:DoSearch(self:GetText())
        self:ClearFocus()
    end)
    frame.searchBox = searchBox
    
    -- Search button
    local searchBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    searchBtn:SetSize(60, 22)
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    searchBtn:SetText("Search")
    searchBtn:SetScript("OnClick", function()
        QF:DoSearch(searchBox:GetText())
    end)
    
    -- Result count
    local resultCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultCount:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    resultCount:SetText("0 results")
    resultCount:SetTextColor(0.7, 0.7, 0.7)
    frame.resultCount = resultCount
    
    -- Scroll frame for results
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", resultCount, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)
    frame.scrollFrame = scrollFrame
    
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollContent)
    frame.scrollContent = scrollContent
    
    -- Buy button
    local buyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    buyBtn:SetSize(150, 26)
    buyBtn:SetPoint("BOTTOM", 0, 10)
    buyBtn:SetText("Select an auction")
    buyBtn:Disable()
    buyBtn:SetScript("OnClick", function()
        QF:BuySelectedAuction()
    end)
    frame.buyButton = buyBtn
end

-------------------------------------------------------------------------------
-- Sell Tab
-------------------------------------------------------------------------------

function QF:CreateSellTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.sellFrame = frame
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("TOPRIGHT", -10, -10)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        QF:ScanBags()
    end)
    
    -- Item count
    local itemCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemCount:SetPoint("TOPLEFT", 10, -15)
    itemCount:SetText("0 items")
    itemCount:SetTextColor(0.7, 0.7, 0.7)
    frame.itemCount = itemCount
    
    -- Scroll frame for bag items
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", itemCount, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetPoint("RIGHT", frame, "RIGHT", -30, 0)
    scrollFrame:SetHeight(150)
    frame.scrollFrame = scrollFrame
    
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollContent)
    frame.scrollContent = scrollContent
    
    -- Sell section separator
    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetSize(FRAME_WIDTH - 40, 1)
    separator:SetPoint("TOP", scrollFrame, "BOTTOM", 0, -5)
    separator:SetColorTexture(0.4, 0.4, 0.4, 1)
    
    -- Sell item display
    local sellSection = CreateFrame("Frame", nil, frame)
    sellSection:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -10)
    sellSection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    
    -- Item icon
    local sellItemIcon = sellSection:CreateTexture(nil, "ARTWORK")
    sellItemIcon:SetSize(32, 32)
    sellItemIcon:SetPoint("TOPLEFT", 5, 0)
    sellItemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    frame.sellItemIcon = sellItemIcon
    
    -- Item name
    local sellItemName = sellSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sellItemName:SetPoint("LEFT", sellItemIcon, "RIGHT", 8, 0)
    sellItemName:SetText("Drop item here")
    sellItemName:SetTextColor(0.7, 0.7, 0.7)
    frame.sellItemName = sellItemName
    
    -- Market price display
    local marketPriceText = sellSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marketPriceText:SetPoint("TOPLEFT", sellItemIcon, "BOTTOMLEFT", 0, -8)
    marketPriceText:SetText("")
    marketPriceText:SetTextColor(1, 0.82, 0)
    frame.marketPriceText = marketPriceText
    
    -- Price input
    local priceLabel = sellSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceLabel:SetPoint("TOPLEFT", marketPriceText, "BOTTOMLEFT", 0, -8)
    priceLabel:SetText("Price:")
    priceLabel:SetTextColor(1, 1, 1)
    
    local priceBox = CreateFrame("EditBox", nil, sellSection, "InputBoxTemplate")
    priceBox:SetSize(100, 20)
    priceBox:SetPoint("LEFT", priceLabel, "RIGHT", 5, 0)
    priceBox:SetAutoFocus(false)
    frame.priceBox = priceBox
    
    -- Duration dropdown
    local durationLabel = sellSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationLabel:SetPoint("LEFT", priceBox, "RIGHT", 10, 0)
    durationLabel:SetText("24h")
    durationLabel:SetTextColor(0.7, 0.7, 0.7)
    frame.durationLabel = durationLabel
    
    -- Deposit display
    local depositText = sellSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    depositText:SetPoint("TOPLEFT", priceLabel, "BOTTOMLEFT", 0, -8)
    depositText:SetText("")
    depositText:SetTextColor(0.7, 0.7, 0.7)
    frame.depositText = depositText
    
    -- Post button
    local postBtn = CreateFrame("Button", nil, sellSection, "UIPanelButtonTemplate")
    postBtn:SetSize(100, 26)
    postBtn:SetPoint("BOTTOMRIGHT", sellSection, "BOTTOMRIGHT", 0, 0)
    postBtn:SetText("Post Auction")
    postBtn:Disable()
    postBtn:SetScript("OnClick", function()
        QF:PostAuction()
    end)
    frame.postButton = postBtn
end

-------------------------------------------------------------------------------
-- Stats Tab
-------------------------------------------------------------------------------

function QF:CreateStatsTab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.statsFrame = frame
    
    -- Session header
    local sessionHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sessionHeader:SetPoint("TOP", 0, -10)
    sessionHeader:SetText("|cffFFD700Session Stats|r")
    
    -- Gold change
    local goldText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldText:SetPoint("TOP", sessionHeader, "BOTTOM", 0, -20)
    goldText:SetText("Gold Change: 0g")
    frame.goldText = goldText
    
    -- Purchases
    local purchasesText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    purchasesText:SetPoint("TOP", goldText, "BOTTOM", 0, -15)
    purchasesText:SetText("Purchases: 0")
    frame.purchasesText = purchasesText
    
    -- Sales
    local salesText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    salesText:SetPoint("TOP", purchasesText, "BOTTOM", 0, -10)
    salesText:SetText("Sales: 0")
    frame.salesText = salesText
    
    -- All-time header
    local allTimeHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    allTimeHeader:SetPoint("TOP", salesText, "BOTTOM", 0, -30)
    allTimeHeader:SetText("|cffFFD700All-Time Stats|r")
    
    -- Total purchases
    local totalPurchasesText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalPurchasesText:SetPoint("TOP", allTimeHeader, "BOTTOM", 0, -15)
    totalPurchasesText:SetText("Total Purchases: 0g")
    frame.totalPurchasesText = totalPurchasesText
    
    -- Total sales
    local totalSalesText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalSalesText:SetPoint("TOP", totalPurchasesText, "BOTTOM", 0, -10)
    totalSalesText:SetText("Total Sales: 0g")
    frame.totalSalesText = totalSalesText
    
    -- Items in DB
    local dbCountText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbCountText:SetPoint("TOP", totalSalesText, "BOTTOM", 0, -10)
    dbCountText:SetText("Items in Database: 0")
    frame.dbCountText = dbCountText
end

function QF:UpdateStatsDisplay()
    if not self.statsFrame then return end
    
    -- Session stats
    local sessionGold = self.sessionGold or 0
    local color = sessionGold >= 0 and "|cff00ff00" or "|cffff0000"
    self.statsFrame.goldText:SetText("Gold Change: " .. color .. self:FormatGold(sessionGold) .. "|r")
    
    local purchases = self.sessionPurchases and #self.sessionPurchases or 0
    local sales = self.sessionSales and #self.sessionSales or 0
    self.statsFrame.purchasesText:SetText("Purchases: " .. purchases)
    self.statsFrame.salesText:SetText("Sales: " .. sales)
    
    -- All-time stats
    if self.db and self.db.stats then
        self.statsFrame.totalPurchasesText:SetText("Total Purchases: " .. self:FormatGold(self.db.stats.totalPurchases or 0))
        self.statsFrame.totalSalesText:SetText("Total Sales: " .. self:FormatGold(self.db.stats.totalSales or 0))
    end
    
    -- DB count
    local dbCount = self:TableCount(self.db and self.db.prices or {})
    self.statsFrame.dbCountText:SetText("Items in Database: " .. dbCount)
end

QF:Debug("UI.lua loaded")
