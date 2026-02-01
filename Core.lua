--[[
    QuickFlip - Core.lua
    Main initialization and event handling
    Better than Auctionator - Fast, Smart, Profitable
]]

local addonName, QF = ...
QuickFlip = QF

-- Version info
QF.version = "1.1.0"
QF.name = "QuickFlip"
QF.debug = false

-- State tracking
QF.isAHOpen = false
QF.sessionStart = nil
QF.sessionGoldStart = 0
QF.sessionGold = 0

-- Performance: throttle updates
QF.lastUIUpdate = 0
QF.UI_UPDATE_THROTTLE = 0.1

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function QF:Debug(...)
    if self.debug then
        print("|cff00ff00[QF Debug]|r", ...)
    end
end

function QF:Print(...)
    print("|cffFFD700[QuickFlip]|r", ...)
end

-- Format gold value (copper to readable)
function QF:FormatGold(copper)
    if not copper or copper == 0 then return "0g" end
    
    local negative = copper < 0
    copper = math.abs(copper)
    
    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    local copperRem = copper % 100
    
    local str
    if gold > 0 then
        str = format("%d|cffFFD700g|r %d|cffc0c0c0s|r %d|cffeda55fc|r", gold, silver, copperRem)
    elseif silver > 0 then
        str = format("%d|cffc0c0c0s|r %d|cffeda55fc|r", silver, copperRem)
    else
        str = format("%d|cffeda55fc|r", copperRem)
    end
    
    return negative and ("-" .. str) or str
end

-- Short gold format
function QF:FormatGoldShort(copper)
    if not copper or copper == 0 then return "0g" end
    
    local negative = copper < 0
    copper = math.abs(copper)
    local gold = copper / 10000
    
    local str
    if gold >= 1000000 then
        str = format("%.1fm|cffFFD700g|r", gold / 1000000)
    elseif gold >= 1000 then
        str = format("%.1fk|cffFFD700g|r", gold / 1000)
    elseif gold >= 1 then
        str = format("%d|cffFFD700g|r", floor(gold))
    else
        local silver = floor((copper % 10000) / 100)
        str = format("%d|cffc0c0c0s|r", silver)
    end
    
    return negative and ("-" .. str) or str
end

-- Format percentage with color
function QF:FormatPercent(percent)
    if not percent then return "|cff888888--|r" end
    local color = self:GetPriceColorHex(percent)
    return color .. percent .. "%|r"
end

-- Get color based on percentage of market value
function QF:GetPriceColor(percent)
    if not percent then return 0.5, 0.5, 0.5 end
    if percent < 50 then
        return 0, 1, 0.5  -- Cyan-green (incredible deal)
    elseif percent < 70 then
        return 0, 1, 0    -- Green (great deal)
    elseif percent < 85 then
        return 0.5, 1, 0  -- Yellow-green (good deal)
    elseif percent <= 100 then
        return 1, 1, 0    -- Yellow (fair)
    elseif percent <= 120 then
        return 1, 0.6, 0  -- Orange (overpriced)
    else
        return 1, 0.3, 0.3 -- Red (avoid)
    end
end

-- Get color hex based on percentage
function QF:GetPriceColorHex(percent)
    if not percent then return "|cff888888" end
    if percent < 50 then
        return "|cff00ffaa"  -- Cyan-green
    elseif percent < 70 then
        return "|cff00ff00"  -- Green
    elseif percent < 85 then
        return "|cff80ff00"  -- Yellow-green
    elseif percent <= 100 then
        return "|cffffff00"  -- Yellow
    elseif percent <= 120 then
        return "|cffff9900"  -- Orange
    else
        return "|cffff4c4c"  -- Red
    end
end

-- Get deal rating text
function QF:GetDealRating(percent)
    if not percent then return "" end
    if percent < 50 then
        return "|cff00ffaa★★★ STEAL|r"
    elseif percent < 70 then
        return "|cff00ff00★★ GREAT|r"
    elseif percent < 85 then
        return "|cff80ff00★ GOOD|r"
    elseif percent <= 100 then
        return "|cffffff00FAIR|r"
    else
        return "|cffff4c4cAVOID|r"
    end
end

-- Time ago formatter
function QF:TimeAgo(timestamp)
    if not timestamp then return "never" end
    local diff = time() - timestamp
    
    if diff < 60 then return "just now"
    elseif diff < 3600 then return floor(diff / 60) .. "m ago"
    elseif diff < 86400 then return floor(diff / 3600) .. "h ago"
    else return floor(diff / 86400) .. "d ago"
    end
end

-- Table count helper
function QF:TableCount(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-------------------------------------------------------------------------------
-- Event Frame
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("PLAYER_MONEY")
-- eventFrame:RegisterEvent("AUCTION_HOUSE_PURCHASE_COMPLETED")
-- eventFrame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")

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
    elseif event == "PLAYER_MONEY" then
        QF:OnPlayerMoney()
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        QF:OnPurchaseCompleted(...)
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        QF:OnAuctionCreated(...)
    end
end)

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

function QF:OnAddonLoaded()
    self:InitDB()
    self:LoadConfig()
    self:HookTooltips()
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
    
    self:Print("v" .. self.version .. " loaded. |cff00ff00Better than Auctionator.|r Type /qf")
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
    
    -- Auto-scan if enabled
    if self.config.autoScan then
        C_Timer.After(0.5, function()
            self:StartScan("fast")
        end)
    end
    
    -- Start deals scanner
    self:StartDealsScanner()
end

function QF:OnAuctionHouseClosed()
    self.isAHOpen = false
    
    if self.mainFrame then
        self.mainFrame:Hide()
    end
    
    self:StopDealsScanner()
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

function QF:OnPurchaseCompleted(itemID)
    self:Debug("Purchase completed:", itemID)
    -- Tracked in Buying.lua
end

function QF:OnAuctionCreated(auctionID)
    self:Debug("Auction created:", auctionID)
    -- Tracked in Selling.lua
end

-------------------------------------------------------------------------------
-- Tooltip Hook - Show prices EVERYWHERE
-------------------------------------------------------------------------------

function QF:HookTooltips()
    -- Hook all tooltip types
    local function AddPriceToTooltip(tooltip, itemID, itemLink)
        if not itemID then return end
        
        local priceData = QF:GetPriceData(itemID)
        if not priceData then return end
        
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffFFD700QuickFlip|r", 1, 0.82, 0)
        
        -- Market price
        tooltip:AddDoubleLine("Market Price:", QF:FormatGold(priceData.marketPrice), 1, 1, 1, 1, 1, 1)
        
        -- Min/Max seen
        if priceData.minPrice and priceData.maxPrice then
            tooltip:AddDoubleLine("Range:", 
                QF:FormatGoldShort(priceData.minPrice) .. " - " .. QF:FormatGoldShort(priceData.maxPrice),
                0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
        
        -- Velocity
        if priceData.velocity then
            local velText = priceData.velocity >= 100 and "Fast seller" or
                           priceData.velocity >= 20 and "Moderate" or "Slow seller"
            tooltip:AddDoubleLine("Sales:", velText .. " (" .. floor(priceData.velocity) .. "/day)", 
                0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
        
        -- Cost basis (if we bought this)
        local costBasis = QF:GetCostBasis(itemID)
        if costBasis then
            local profit = priceData.marketPrice - costBasis
            local profitColor = profit >= 0 and "|cff00ff00" or "|cffff0000"
            tooltip:AddDoubleLine("You paid:", QF:FormatGold(costBasis), 0.7, 0.7, 0.7, 1, 1, 1)
            tooltip:AddDoubleLine("Profit margin:", profitColor .. QF:FormatGold(profit) .. "|r", 0.7, 0.7, 0.7, 1, 1, 1)
        end
        
        -- Last seen
        if priceData.lastSeen then
            tooltip:AddDoubleLine("Updated:", QF:TimeAgo(priceData.lastSeen), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        end
        
        tooltip:Show()
    end
    
    -- Hook GameTooltip
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        local _, itemLink = self:GetItem()
        if itemLink then
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            AddPriceToTooltip(self, itemID, itemLink)
        end
    end)
    
    -- Hook ItemRefTooltip (shift-clicked links)
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
        local _, itemLink = self:GetItem()
        if itemLink then
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            AddPriceToTooltip(self, itemID, itemLink)
        end
    end)
    
    self:Debug("Tooltips hooked")
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------

function QF:HandleSlashCommand(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "" then
        -- Toggle main window
        if self.isAHOpen then
            if self.mainFrame then
                self.mainFrame:SetShown(not self.mainFrame:IsShown())
            end
        else
            self:Print("Open the Auction House to use QuickFlip!")
        end
    elseif cmd == "help" then
        self:Print("Commands:")
        print("  /qf - Toggle window (at AH)")
        print("  /qf config - Settings")
        print("  /qf scan - Full AH scan")
        print("  /qf deals - Show current deals")
        print("  /qf sniper - Toggle sniper mode")
        print("  /qf stats - Session stats")
        print("  /qf flips - Suggested flips")
        print("  /qf reset - Reset database")
    elseif cmd == "config" or cmd == "options" then
        self:ShowConfig()
    elseif cmd == "scan" then
        if self.isAHOpen then
            self:StartScan("full")
        else
            self:Print("Open the Auction House first!")
        end
    elseif cmd == "deals" then
        if self.isAHOpen then
            self:ShowDealsTab()
        else
            self:Print("Open the Auction House first!")
        end
    elseif cmd == "sniper" then
        self:ToggleSniper()
    elseif cmd == "stats" then
        self:ShowStats()
    elseif cmd == "flips" then
        if self.isAHOpen then
            self:ShowFlipsTab()
        else
            self:Print("Open the Auction House first!")
        end
    elseif cmd == "reset" then
        StaticPopup_Show("QUICKFLIP_RESET_DB")
    elseif cmd == "debug" then
        self.debug = not self.debug
        self:Print("Debug mode: " .. (self.debug and "ON" or "OFF"))
    else
        self:Print("Unknown command. Type /qf help")
    end
end

-------------------------------------------------------------------------------
-- Static Popups
-------------------------------------------------------------------------------

StaticPopupDialogs["QUICKFLIP_RESET_DB"] = {
    text = "Reset QuickFlip database? This cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        QuickFlip:ResetDB()
        QuickFlip:Print("Database reset complete.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["QUICKFLIP_CONFIRM_BUY"] = {
    text = "Buy %s for %s?\n\nMarket: %s\nThis is %s of market value",
    button1 = "Buy",
    button2 = "Cancel",
    OnAccept = function(self, data)
        QuickFlip:ExecuteBuy(data)
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
}

StaticPopupDialogs["QUICKFLIP_INSTANT_BUY"] = {
    text = "|cff00ff00DEAL FOUND!|r\n\nBuy %s for %s?\n(%s of market - save %s)",
    button1 = "BUY NOW",
    button2 = "Skip",
    OnAccept = function(self, data)
        QuickFlip:ExecuteBuy(data)
    end,
    timeout = 10,
    whileDead = false,
    hideOnEscape = true,
}

-------------------------------------------------------------------------------

QF:Debug("Core.lua loaded")
