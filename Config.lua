--[[
    QuickFlip - Config.lua
    Settings and configuration
]]

local addonName, QF = ...

local CONFIG_DEFAULTS = {
    undercutPercent = 5,
    sniperThreshold = 70,
    dealThreshold = 80,
    soundAlerts = true,
    instantBuyPopup = true,
    autoScan = true,
    tooltipPrices = true,
}

-------------------------------------------------------------------------------
-- Config Management
-------------------------------------------------------------------------------

function QF:LoadConfig()
    if not self.db then
        self.config = CopyTable(CONFIG_DEFAULTS)
        return
    end
    
    if not self.db.config then
        self.db.config = CopyTable(CONFIG_DEFAULTS)
    else
        for key, value in pairs(CONFIG_DEFAULTS) do
            if self.db.config[key] == nil then
                self.db.config[key] = value
            end
        end
    end
    
    self.config = self.db.config
end

function QF:SaveConfig()
    if self.db then
        self.db.config = self.config
    end
end

function QF:GetConfig(key)
    return self.config and self.config[key] or CONFIG_DEFAULTS[key]
end

function QF:SetConfig(key, value)
    if self.config then
        self.config[key] = value
        self:SaveConfig()
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Config UI
-------------------------------------------------------------------------------

function QF:ShowConfig()
    if self.configFrame then
        self.configFrame:Show()
        return
    end
    
    local frame = CreateFrame("Frame", "QuickFlipConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(320, 320)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.10, 0.97)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cffFFD700QuickFlip Settings|r")
    
    -- Close
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetPoint("CENTER")
    closeX:SetText("×")
    closeX:SetTextColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(0.6, 0.6, 0.6) end)
    
    local yOffset = -50
    
    -- Undercut %
    local undercutLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    undercutLabel:SetPoint("TOPLEFT", 20, yOffset)
    undercutLabel:SetText("Default Undercut %:")
    
    local undercutBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    undercutBox:SetSize(50, 22)
    undercutBox:SetPoint("TOPRIGHT", -20, yOffset + 5)
    undercutBox:SetAutoFocus(false)
    undercutBox:SetText(tostring(self:GetConfig("undercutPercent")))
    undercutBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 and val <= 50 then
            QF:SetConfig("undercutPercent", val)
            QF:Print("Undercut set to " .. val .. "%")
        end
        self:ClearFocus()
    end)
    yOffset = yOffset - 30
    
    -- Sniper threshold
    local threshLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    threshLabel:SetPoint("TOPLEFT", 20, yOffset)
    threshLabel:SetText("Sniper Alert Threshold %:")
    
    local threshBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    threshBox:SetSize(50, 22)
    threshBox:SetPoint("TOPRIGHT", -20, yOffset + 5)
    threshBox:SetAutoFocus(false)
    threshBox:SetText(tostring(self:GetConfig("sniperThreshold")))
    threshBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 and val <= 100 then
            QF:SetConfig("sniperThreshold", val)
            QF:Print("Sniper threshold set to " .. val .. "%")
        end
        self:ClearFocus()
    end)
    yOffset = yOffset - 30
    
    -- Deal threshold
    local dealLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dealLabel:SetPoint("TOPLEFT", 20, yOffset)
    dealLabel:SetText("Deal Detection Threshold %:")
    
    local dealBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    dealBox:SetSize(50, 22)
    dealBox:SetPoint("TOPRIGHT", -20, yOffset + 5)
    dealBox:SetAutoFocus(false)
    dealBox:SetText(tostring(self:GetConfig("dealThreshold")))
    dealBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 and val <= 100 then
            QF:SetConfig("dealThreshold", val)
            QF:Print("Deal threshold set to " .. val .. "%")
        end
        self:ClearFocus()
    end)
    yOffset = yOffset - 40
    
    -- Checkboxes
    local function CreateCheckbox(label, configKey, y)
        local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 15, y)
        check:SetChecked(QF:GetConfig(configKey))
        check:SetScript("OnClick", function(self)
            QF:SetConfig(configKey, self:GetChecked())
        end)
        
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        text:SetText(label)
        
        return check
    end
    
    CreateCheckbox("Sound alerts on deals", "soundAlerts", yOffset)
    yOffset = yOffset - 28
    
    CreateCheckbox("Instant buy popup for great deals", "instantBuyPopup", yOffset)
    yOffset = yOffset - 28
    
    CreateCheckbox("Auto-scan when AH opens", "autoScan", yOffset)
    yOffset = yOffset - 28
    
    CreateCheckbox("Show prices in tooltips", "tooltipPrices", yOffset)
    yOffset = yOffset - 45
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("BOTTOM", 0, 15)
    resetBtn:SetText("Reset Database")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("QUICKFLIP_RESET_DB")
    end)
    
    self.configFrame = frame
end

-------------------------------------------------------------------------------
-- Interface Options Panel
-------------------------------------------------------------------------------

local function CreateBlizzardOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "QuickFlip"
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffFFD700QuickFlip|r - Better than Auctionator")
    
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Fast, smart auction house buying and selling.")
    
    local features = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    features:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    features:SetText([[
|cffFFD700Features:|r
• Live deal detection with auto-populated deals tab
• Smart pricing with competition analysis
• Profit tracking (session/daily/weekly)
• Flip suggestions based on margins & velocity
• Sniper mode with instant buy alerts
• Tooltip integration everywhere
• Keyboard shortcuts for fast buying

|cff00ff00Type /qf to get started!|r
    ]])
    
    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(150, 28)
    openBtn:SetPoint("TOPLEFT", features, "BOTTOMLEFT", 0, -20)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        QF:ShowConfig()
    end)
    
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(1, CreateBlizzardOptionsPanel)
end)

-------------------------------------------------------------------------------

QF:Debug("Config.lua loaded")
