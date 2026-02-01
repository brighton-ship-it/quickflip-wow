--[[
    QuickFlip - Database.lua
    Price data storage and management (WoW Classic)
]]

local addonName, QF = ...

-- Database defaults
local DB_DEFAULTS = {
    prices = {},           -- Item price data
    watchlist = {},        -- Sniper watchlist
    history = {},          -- Transaction history
    stats = {
        totalBought = 0,
        totalSold = 0,
        totalProfit = 0,
        flips = {},
    },
}

-- Moving average window size
local MA_WINDOW = 10

-------------------------------------------------------------------------------
-- Database Initialization
-------------------------------------------------------------------------------

function QF:InitDB()
    -- Initialize SavedVariables if needed
    if not QuickFlipDB then
        QuickFlipDB = CopyTable(DB_DEFAULTS)
        self:Debug("Created new database")
    else
        -- Migrate/validate existing data
        for key, value in pairs(DB_DEFAULTS) do
            if QuickFlipDB[key] == nil then
                QuickFlipDB[key] = CopyTable(value)
            end
        end
        self:Debug("Loaded existing database")
    end
    
    self.db = QuickFlipDB
    
    -- Clean old data (older than 30 days)
    self:CleanOldData()
end

function QF:SaveDB()
    -- Data is automatically saved through SavedVariables
    self:Debug("Database saved")
end

function QF:ResetDB()
    QuickFlipDB = CopyTable(DB_DEFAULTS)
    self.db = QuickFlipDB
    self:Debug("Database reset")
end

-------------------------------------------------------------------------------
-- Price Data Management
-------------------------------------------------------------------------------

-- Store price data for an item
function QF:StorePrice(itemID, price, quantity)
    if not itemID or not price or price <= 0 then return end
    
    local now = time()
    local entry = self.db.prices[itemID]
    
    if not entry then
        -- New item
        self.db.prices[itemID] = {
            itemID = itemID,
            marketPrice = price,
            lastSeen = now,
            minPrice = price,
            maxPrice = price,
            scanCount = 1,
            priceHistory = {price},
            movingAvg = price,
        }
    else
        -- Update existing
        entry.lastSeen = now
        entry.scanCount = (entry.scanCount or 0) + 1
        entry.minPrice = min(entry.minPrice or price, price)
        entry.maxPrice = max(entry.maxPrice or price, price)
        
        -- Update price history for moving average
        entry.priceHistory = entry.priceHistory or {}
        table.insert(entry.priceHistory, price)
        
        -- Keep only last N prices
        while #entry.priceHistory > MA_WINDOW do
            table.remove(entry.priceHistory, 1)
        end
        
        -- Calculate moving average
        local sum = 0
        for _, p in ipairs(entry.priceHistory) do
            sum = sum + p
        end
        entry.movingAvg = sum / #entry.priceHistory
        
        -- Market price is weighted: 70% moving avg, 30% current
        entry.marketPrice = floor((entry.movingAvg * 0.7) + (price * 0.3))
    end
    
    self:Debug("Stored price for item", itemID, ":", self:FormatGoldShort(price))
end

-- Get market price for an item
function QF:GetMarketPrice(itemID)
    if not itemID then return nil end
    
    local entry = self.db.prices[itemID]
    if entry then
        return entry.marketPrice, entry
    end
    
    return nil
end

-- Get price data for an item
function QF:GetPriceData(itemID)
    if not itemID then return nil end
    return self.db.prices[itemID]
end

-- Calculate percentage of market value
function QF:GetMarketPercent(itemID, currentPrice)
    local marketPrice = self:GetMarketPrice(itemID)
    if not marketPrice or marketPrice <= 0 then
        return nil
    end
    
    return floor((currentPrice / marketPrice) * 100)
end

-------------------------------------------------------------------------------
-- Watchlist Management (Sniper)
-------------------------------------------------------------------------------

-- Add item to watchlist
function QF:AddToWatchlist(itemID, maxPercent)
    if not itemID then return false end
    
    maxPercent = maxPercent or self.config.sniperThreshold
    
    -- GetItemInfo returns: name, link, quality, level, minLevel, type, subType, stackCount, equipLoc, texture, sellPrice
    local itemName, itemLink = GetItemInfo(itemID)
    
    self.db.watchlist[itemID] = {
        itemID = itemID,
        itemName = itemName or "Unknown",
        maxPercent = maxPercent,
        addedAt = time(),
    }
    
    self:Print("Added to watchlist:", itemLink or itemName or itemID)
    return true
end

-- Remove item from watchlist
function QF:RemoveFromWatchlist(itemID)
    if self.db.watchlist[itemID] then
        local name = self.db.watchlist[itemID].itemName
        self.db.watchlist[itemID] = nil
        self:Print("Removed from watchlist:", name)
        return true
    end
    return false
end

-- Get watchlist
function QF:GetWatchlist()
    return self.db.watchlist
end

-- Check if item is a deal based on watchlist
function QF:IsSniperDeal(itemID, currentPrice)
    local watchEntry = self.db.watchlist[itemID]
    if not watchEntry then return false end
    
    local marketPercent = self:GetMarketPercent(itemID, currentPrice)
    if not marketPercent then return false end
    
    return marketPercent <= watchEntry.maxPercent
end

-------------------------------------------------------------------------------
-- Transaction History
-------------------------------------------------------------------------------

-- Record a purchase
function QF:RecordPurchase(itemID, price, quantity, itemName)
    local entry = {
        type = "buy",
        itemID = itemID,
        itemName = itemName or "Unknown",
        price = price,
        quantity = quantity or 1,
        timestamp = time(),
        date = date("%Y-%m-%d"),
    }
    
    table.insert(self.db.history, entry)
    self.db.stats.totalBought = self.db.stats.totalBought + price
    
    -- Track for flip calculation
    self.db.stats.flips[itemID] = self.db.stats.flips[itemID] or {}
    table.insert(self.db.stats.flips[itemID], {
        type = "buy",
        price = price,
        quantity = quantity or 1,
        timestamp = time(),
    })
    
    self:Debug("Recorded purchase:", itemName, self:FormatGoldShort(price))
end

-- Record a sale
function QF:RecordSale(itemID, price, quantity, itemName)
    local entry = {
        type = "sell",
        itemID = itemID,
        itemName = itemName or "Unknown",
        price = price,
        quantity = quantity or 1,
        timestamp = time(),
        date = date("%Y-%m-%d"),
    }
    
    table.insert(self.db.history, entry)
    self.db.stats.totalSold = self.db.stats.totalSold + price
    
    -- Calculate profit if we have buy data
    if self.db.stats.flips[itemID] then
        for i, flip in ipairs(self.db.stats.flips[itemID]) do
            if flip.type == "buy" and flip.quantity > 0 then
                local soldQty = min(quantity, flip.quantity)
                local profit = (price / (quantity or 1)) * soldQty - (flip.price / flip.quantity) * soldQty
                self.db.stats.totalProfit = self.db.stats.totalProfit + profit
                flip.quantity = flip.quantity - soldQty
                quantity = quantity - soldQty
                if quantity <= 0 then break end
            end
        end
    end
    
    self:Debug("Recorded sale:", itemName, self:FormatGoldShort(price))
end

-- Get today's transactions
function QF:GetTodayTransactions()
    local today = date("%Y-%m-%d")
    local transactions = {}
    
    for _, entry in ipairs(self.db.history) do
        if entry.date == today then
            table.insert(transactions, entry)
        end
    end
    
    return transactions
end

-- Get session stats
function QF:GetSessionStats()
    return {
        sessionGold = self.sessionGold,
        totalBought = self.db.stats.totalBought,
        totalSold = self.db.stats.totalSold,
        totalProfit = self.db.stats.totalProfit,
    }
end

-------------------------------------------------------------------------------
-- Data Maintenance
-------------------------------------------------------------------------------

-- Clean old price data (older than 30 days)
function QF:CleanOldData()
    local cutoff = time() - (30 * 24 * 60 * 60)  -- 30 days ago
    local cleaned = 0
    
    for itemID, data in pairs(self.db.prices) do
        if data.lastSeen and data.lastSeen < cutoff then
            self.db.prices[itemID] = nil
            cleaned = cleaned + 1
        end
    end
    
    -- Clean old history (keep last 1000 entries)
    while #self.db.history > 1000 do
        table.remove(self.db.history, 1)
    end
    
    if cleaned > 0 then
        self:Debug("Cleaned", cleaned, "old price entries")
    end
end

-- Get database stats
function QF:GetDBStats()
    local priceCount = 0
    for _ in pairs(self.db.prices) do
        priceCount = priceCount + 1
    end
    
    local watchCount = 0
    for _ in pairs(self.db.watchlist) do
        watchCount = watchCount + 1
    end
    
    return {
        priceEntries = priceCount,
        watchlistItems = watchCount,
        historyEntries = #self.db.history,
    }
end

-------------------------------------------------------------------------------

QF:Debug("Database.lua loaded")
