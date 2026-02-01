--[[
    QuickFlip - Utils.lua
    Helper functions and formatting utilities
    Classic Era (Interface 11503)
]]

local addonName, QF = ...

-------------------------------------------------------------------------------
-- Gold Formatting
-------------------------------------------------------------------------------

-- Format copper to readable gold string
function QF:FormatGold(copper)
    if not copper or copper == 0 then return "0g" end
    
    local negative = copper < 0
    copper = math.abs(copper)
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = copper % 100
    
    local str
    if gold > 0 then
        str = string.format("%d|cffFFD700g|r %d|cffc0c0c0s|r %d|cffeda55fc|r", gold, silver, copperRem)
    elseif silver > 0 then
        str = string.format("%d|cffc0c0c0s|r %d|cffeda55fc|r", silver, copperRem)
    else
        str = string.format("%d|cffeda55fc|r", copperRem)
    end
    
    return negative and ("-" .. str) or str
end

-- Short gold format (for compact display)
function QF:FormatGoldShort(copper)
    if not copper or copper == 0 then return "0g" end
    
    local negative = copper < 0
    copper = math.abs(copper)
    local gold = copper / 10000
    
    local str
    if gold >= 1000 then
        str = string.format("%.1fk|cffFFD700g|r", gold / 1000)
    elseif gold >= 1 then
        str = string.format("%d|cffFFD700g|r", math.floor(gold))
    else
        local silver = math.floor((copper % 10000) / 100)
        if silver > 0 then
            str = string.format("%d|cffc0c0c0s|r", silver)
        else
            str = string.format("%d|cffeda55fc|r", copper % 100)
        end
    end
    
    return negative and ("-" .. str) or str
end

-- Parse per-unit price from stack
function QF:GetUnitPrice(totalPrice, count)
    if not totalPrice or totalPrice == 0 or not count or count == 0 then
        return 0
    end
    return math.floor(totalPrice / count)
end

-------------------------------------------------------------------------------
-- Color Functions
-------------------------------------------------------------------------------

-- Get color based on percentage of market value
function QF:GetPriceColor(percent)
    if not percent then return 0.5, 0.5, 0.5 end
    if percent < 80 then
        return 0, 1, 0  -- Green (good deal)
    elseif percent <= 100 then
        return 1, 1, 0  -- Yellow (fair)
    else
        return 1, 0.3, 0.3 -- Red (overpriced)
    end
end

-- Get color hex for text
function QF:GetPriceColorHex(percent)
    if not percent then return "|cff888888" end
    if percent < 80 then
        return "|cff00ff00"  -- Green
    elseif percent <= 100 then
        return "|cffffff00"  -- Yellow
    else
        return "|cffff4c4c"  -- Red
    end
end

-------------------------------------------------------------------------------
-- Item Functions
-------------------------------------------------------------------------------

-- Get itemID from item link
function QF:GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local itemID = itemLink:match("item:(%d+)")
    return itemID and tonumber(itemID)
end

-- Get item info (Classic Era compatible)
function QF:GetItemInfo(itemLink)
    if not itemLink then return nil end
    local name, link, quality, itemLevel, reqLevel, class, subclass, 
          maxStack, equipSlot, texture, sellPrice = GetItemInfo(itemLink)
    return {
        name = name,
        link = link,
        quality = quality,
        texture = texture,
        sellPrice = sellPrice
    }
end

-------------------------------------------------------------------------------
-- Time Functions
-------------------------------------------------------------------------------

function QF:TimeAgo(timestamp)
    if not timestamp then return "never" end
    local diff = time() - timestamp
    
    if diff < 60 then return "just now"
    elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
    else return math.floor(diff / 86400) .. "d ago"
    end
end

-------------------------------------------------------------------------------
-- Table Utilities
-------------------------------------------------------------------------------

function QF:TableCount(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

function QF:CopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = QF:CopyTable(v)
    end
    return copy
end

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------

QF.debug = false

function QF:Debug(...)
    if self.debug then
        print("|cff00ff00[QF Debug]|r", ...)
    end
end

function QF:Print(...)
    print("|cffFFD700[QuickFlip]|r", ...)
end
