--[[
    QuickFlip - Database.lua
    Price storage and persistence
    Classic Era (Interface 11503)
]]

local addonName, QF = ...

-------------------------------------------------------------------------------
-- Database Initialization
-------------------------------------------------------------------------------

function QF:InitDB()
    -- Initialize saved variables
    if not QuickFlipDB then
        QuickFlipDB = {}
    end
    
    -- Ensure structure exists
    QuickFlipDB.prices = QuickFlipDB.prices or {}
    QuickFlipDB.stats = QuickFlipDB.stats or {
        totalPurchases = 0,
        totalSales = 0,
        totalProfit = 0
    }
    QuickFlipDB.config = QuickFlipDB.config or {
        dealThreshold = 80,  -- % of market to consider a deal
        scanDelay = 0.5      -- seconds between scan pages
    }
    QuickFlipDB.lastFullScan = QuickFlipDB.lastFullScan or 0
    
    self.db = QuickFlipDB
    self:Debug("Database initialized with", self:TableCount(self.db.prices), "items")
end

function QF:SaveDB()
    -- Saved automatically by WoW on logout
    self:Debug("Database saved")
end

function QF:ResetDB()
    QuickFlipDB = {
        prices = {},
        stats = {
            totalPurchases = 0,
            totalSales = 0,
            totalProfit = 0
        },
        config = {
            dealThreshold = 80,
            scanDelay = 0.5
        },
        lastFullScan = 0
    }
    self.db = QuickFlipDB
    self:Print("Database reset.")
end

-------------------------------------------------------------------------------
-- Price Data Management
-------------------------------------------------------------------------------

-- Update price for an item
function QF:UpdatePrice(itemID, unitPrice, count)
    if not itemID or not unitPrice or unitPrice == 0 then return end
    
    count = count or 1
    local prices = self.db.prices
    
    if not prices[itemID] then
        prices[itemID] = {
            minPrice = unitPrice,
            marketPrice = unitPrice,
            lastSeen = time(),
            numSeen = count
        }
    else
        local data = prices[itemID]
        
        -- Update min price
        if unitPrice < data.minPrice then
            data.minPrice = unitPrice
        end
        
        -- Update market price (weighted average)
        local totalSeen = data.numSeen + count
        data.marketPrice = math.floor(
            (data.marketPrice * data.numSeen + unitPrice * count) / totalSeen
        )
        data.numSeen = totalSeen
        data.lastSeen = time()
    end
end

-- Get price data for an item
function QF:GetPriceData(itemID)
    if not itemID or not self.db then return nil end
    return self.db.prices[itemID]
end

-- Get market price for an item
function QF:GetMarketPrice(itemID)
    local data = self:GetPriceData(itemID)
    if data then
        return data.marketPrice
    end
    return nil
end

-- Get percentage of market price
function QF:GetPercentOfMarket(itemID, price)
    local marketPrice = self:GetMarketPrice(itemID)
    if not marketPrice or marketPrice == 0 then return nil end
    return math.floor((price / marketPrice) * 100)
end

-- Check if price is a deal
function QF:IsDeal(itemID, price)
    local percent = self:GetPercentOfMarket(itemID, price)
    if not percent then return false end
    return percent < (self.db.config.dealThreshold or 80)
end

-------------------------------------------------------------------------------
-- Stats Tracking
-------------------------------------------------------------------------------

function QF:RecordPurchase(itemID, price, count)
    if not self.db then return end
    
    self.db.stats.totalPurchases = self.db.stats.totalPurchases + price
    
    -- Track in session
    if not self.sessionPurchases then
        self.sessionPurchases = {}
    end
    
    table.insert(self.sessionPurchases, {
        itemID = itemID,
        price = price,
        count = count,
        time = time()
    })
    
    self:Debug("Recorded purchase:", itemID, self:FormatGold(price))
end

function QF:RecordSale(itemID, price, count)
    if not self.db then return end
    
    self.db.stats.totalSales = self.db.stats.totalSales + price
    
    -- Track in session
    if not self.sessionSales then
        self.sessionSales = {}
    end
    
    table.insert(self.sessionSales, {
        itemID = itemID,
        price = price,
        count = count,
        time = time()
    })
    
    self:Debug("Recorded sale:", itemID, self:FormatGold(price))
end

-------------------------------------------------------------------------------
-- Database Cleanup
-------------------------------------------------------------------------------

-- Remove old price data (older than days)
function QF:CleanOldPrices(days)
    days = days or 30
    local cutoff = time() - (days * 86400)
    local removed = 0
    
    for itemID, data in pairs(self.db.prices) do
        if data.lastSeen < cutoff then
            self.db.prices[itemID] = nil
            removed = removed + 1
        end
    end
    
    if removed > 0 then
        self:Print("Cleaned", removed, "old price entries")
    end
end

QF:Debug("Database.lua loaded")
