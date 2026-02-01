--[[
    QuickFlip - Core.lua
    Main initialization and event handling
    Classic Era (Interface 11503)
]]

local addonName, QF = ...
QuickFlip = QF  -- Global reference

-- Version info
QF.version = "2.0.0"
QF.name = "QuickFlip"

-- State tracking
QF.isAHOpen = false
QF.sessionStart = nil
QF.sessionGoldStart = 0
QF.sessionGold = 0
QF.sessionPurchases = {}
QF.sessionSales = {}

-------------------------------------------------------------------------------
-- Event Frame
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
eventFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BAG_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            QF:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        QF:OnPlayerLogin()
    elseif event == "PLAYER_LOGOUT" then
        QF:OnPlayerLogout()
    elseif event == "AUCTION_HOUSE_SHOW" then
        QF:OnAuctionHouseShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        QF:OnAuctionHouseClosed()
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        QF:OnAuctionItemListUpdate()
    elseif event == "AUCTION_OWNED_LIST_UPDATE" then
        QF:OnAuctionOwnedListUpdate()
    elseif event == "PLAYER_MONEY" then
        QF:OnPlayerMoney()
    elseif event == "BAG_UPDATE" then
        QF:OnBagUpdate(...)
    end
end)

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

function QF:OnAddonLoaded()
    self:InitDB()
    self:Debug("Addon loaded")
end

function QF:OnPlayerLogin()
    -- Initialize session
    self.sessionStart = time()
    self.sessionGoldStart = GetMoney()
    self.sessionGold = 0
    
    -- Slash commands
    SLASH_QUICKFLIP1 = "/quickflip"
    SLASH_QUICKFLIP2 = "/qf"
    SlashCmdList["QUICKFLIP"] = function(msg)
        QF:HandleSlashCommand(msg)
    end
    
    self:Print("v" .. self.version .. " loaded. Type /qf for help.")
end

function QF:OnPlayerLogout()
    self:SaveDB()
end

function QF:OnAuctionHouseShow()
    self.isAHOpen = true
    
    if not self.mainFrame then
        self:CreateUI()
    end
    
    if self.mainFrame then
        self.mainFrame:Show()
    end
    
    -- Scan bags for sell tab
    self:ScanBags()
    
    self:Debug("Auction house opened")
end

function QF:OnAuctionHouseClosed()
    self.isAHOpen = false
    
    if self.mainFrame then
        self.mainFrame:Hide()
    end
    
    -- Stop any ongoing scan
    self:StopScan()
    
    self:Debug("Auction house closed")
end

function QF:OnAuctionItemListUpdate()
    -- Process scan results when they arrive
    if self.scanner and self.scanner.isScanning then
        self:ProcessAuctionResults()
    else
        -- Not scanning, but search results updated - update UI
        self:UpdateSearchResults()
    end
end

function QF:OnAuctionOwnedListUpdate()
    -- Your auctions updated
    self:Debug("Your auctions updated")
end

function QF:OnPlayerMoney()
    if self.sessionGoldStart then
        local currentGold = GetMoney()
        self.sessionGold = currentGold - self.sessionGoldStart
        
        if self.statsFrame and self.statsFrame:IsVisible() then
            self:UpdateStatsDisplay()
        end
    end
end

function QF:OnBagUpdate(bagID)
    -- Only refresh if sell tab is visible
    if self.activeTab == "sell" then
        self:ScanBags()
    end
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------

function QF:HandleSlashCommand(msg)
    local cmd = msg:lower():match("^%s*(%S*)") or ""
    
    if cmd == "" or cmd == "help" then
        self:Print("Commands:")
        print("  /qf - Show this help")
        print("  /qf scan - Start full AH scan (at AH)")
        print("  /qf stats - Show session stats")
        print("  /qf reset - Reset price database")
        print("  /qf debug - Toggle debug mode")
    elseif cmd == "scan" then
        if self.isAHOpen then
            self:StartFullScan()
        else
            self:Print("Open the Auction House first!")
        end
    elseif cmd == "stats" then
        self:ShowStats()
    elseif cmd == "reset" then
        StaticPopup_Show("QUICKFLIP_RESET_DB")
    elseif cmd == "debug" then
        self.debug = not self.debug
        self:Print("Debug mode: " .. (self.debug and "ON" or "OFF"))
    else
        self:Print("Unknown command: " .. cmd)
    end
end

function QF:ShowStats()
    local sessionGold = self.sessionGold or 0
    local color = sessionGold >= 0 and "|cff00ff00" or "|cffff0000"
    
    self:Print("Session Stats:")
    print("  Gold change: " .. color .. self:FormatGold(sessionGold) .. "|r")
    print("  Purchases: " .. (#self.sessionPurchases or 0))
    print("  Sales: " .. (#self.sessionSales or 0))
    print("  Items in DB: " .. self:TableCount(self.db and self.db.prices or {}))
end

-------------------------------------------------------------------------------
-- Static Popups
-------------------------------------------------------------------------------

StaticPopupDialogs["QUICKFLIP_RESET_DB"] = {
    text = "Reset QuickFlip price database?\n\nThis cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        QuickFlip:ResetDB()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-------------------------------------------------------------------------------

QF:Debug("Core.lua loaded")
