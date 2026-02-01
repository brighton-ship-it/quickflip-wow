--[[
    QuickFlip - Scanner.lua
    Fast, intelligent AH scanning with deal detection
]]

local addonName, QF = ...

-- Scanner state
QF.scanner = {
    isScanning = false,
    scanType = nil,
    progress = 0,
    total = 0,
    startTime = nil,
    results = {},
    pendingSearches = {},
}

-- Deals scanner
local dealsScanner = nil
local DEALS_SCAN_INTERVAL = 15  -- seconds between scans

-- Scan throttling
local SCAN_THROTTLE = 0.15  -- seconds between API calls
local scanQueue = {}
local processingQueue = false

-------------------------------------------------------------------------------
-- Event Registration
-------------------------------------------------------------------------------

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
scanFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
scanFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
scanFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
scanFrame:RegisterEvent("AUCTION_HOUSE_NEW_RESULTS_RECEIVED")
scanFrame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")

scanFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        QF:OnCommodityResultsUpdated(...)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        QF:OnItemResultsUpdated(...)
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or 
           event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        QF:OnBrowseResultsUpdated(...)
    elseif event == "AUCTION_HOUSE_NEW_RESULTS_RECEIVED" then
        QF:OnNewResultsReceived(...)
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        QF:OnReplicateListUpdate(...)
    end
end)

-------------------------------------------------------------------------------
-- Scanning Control
-------------------------------------------------------------------------------

function QF:StartScan(scanType)
    if not self.isAHOpen then
        self:Print("Auction House must be open!")
        return
    end
    
    if self.scanner.isScanning then
        self:Print("Scan in progress...")
        return
    end
    
    scanType = scanType or "browse"
    
    self.scanner.isScanning = true
    self.scanner.scanType = scanType
    self.scanner.startTime = time()
    self.scanner.progress = 0
    self.scanner.results = {}
    
    self:Print("Starting " .. scanType .. " scan...")
    
    if scanType == "full" or scanType == "replicate" then
        self:StartReplicateScan()
    elseif scanType == "browse" then
        self:StartBrowseScan()
    elseif scanType == "fast" then
        self:StartFastScan()
    elseif scanType == "sniper" then
        self:StartSniperScan()
    elseif scanType == "deals" then
        self:StartDealsScan()
    end
end

function QF:StopScan()
    if self.scanner.isScanning then
        self.scanner.isScanning = false
        processingQueue = false
        scanQueue = {}
        self:Print("Scan stopped.")
    end
end

-------------------------------------------------------------------------------
-- Replicate Scan (Full Database)
-------------------------------------------------------------------------------

function QF:StartReplicateScan()
    C_AuctionHouse.ReplicateItems()
end

function QF:OnReplicateListUpdate()
    local numItems = C_AuctionHouse.GetNumReplicateItems()
    self:Debug("Replicate scan:", numItems, "items")
    
    local processed = 0
    for i = 0, numItems - 1 do
        local name, texture, count, qualityID, usable, level, levelType, 
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder, 
              bidderFullName, owner, ownerFullName, saleStatus, itemID = 
              C_AuctionHouse.GetReplicateItemInfo(i)
        
        if itemID and buyoutPrice and buyoutPrice > 0 then
            local unitPrice = buyoutPrice / (count or 1)
            self:StorePrice(itemID, unitPrice, count, numItems)
            processed = processed + 1
        end
    end
    
    self.scanner.progress = processed
    self:OnScanComplete()
end

-------------------------------------------------------------------------------
-- Browse Scan
-------------------------------------------------------------------------------

function QF:StartBrowseScan()
    local query = {
        searchString = "",
        minLevel = 1,
        maxLevel = 0,
        filters = {},
        itemClassFilters = {},
        sorts = {
            {sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false},
        },
    }
    
    C_AuctionHouse.SendBrowseQuery(query)
end

function QF:OnBrowseResultsUpdated()
    local results = C_AuctionHouse.GetBrowseResults()
    if not results then return end
    
    for _, result in ipairs(results) do
        if result.itemKey and result.minPrice then
            local itemID = result.itemKey.itemID
            self:StorePrice(itemID, result.minPrice, result.totalQuantity)
            
            table.insert(self.scanner.results, {
                itemID = itemID,
                price = result.minPrice,
                quantity = result.totalQuantity or 1,
            })
        end
    end
    
    self.scanner.progress = #self.scanner.results
    
    if not C_AuctionHouse.HasFullBrowseResults() then
        C_AuctionHouse.RequestMoreBrowseResults()
    else
        self:OnScanComplete()
    end
end

-------------------------------------------------------------------------------
-- Fast Scan (Priority Items Only)
-------------------------------------------------------------------------------

function QF:StartFastScan()
    -- Scan watchlist + high-velocity items + recent deals
    scanQueue = {}
    
    -- Add watchlist items
    for itemID in pairs(self:GetWatchlist()) do
        table.insert(scanQueue, itemID)
    end
    
    -- Add high-velocity items from database
    local velocityItems = {}
    for itemID, data in pairs(self.db.prices) do
        if data.velocity and data.velocity > 20 then
            table.insert(velocityItems, {itemID = itemID, velocity = data.velocity})
        end
    end
    table.sort(velocityItems, function(a, b) return a.velocity > b.velocity end)
    
    for i = 1, min(50, #velocityItems) do
        table.insert(scanQueue, velocityItems[i].itemID)
    end
    
    -- Add items from recent flip suggestions
    for _, flip in ipairs(self.db.flips or {}) do
        table.insert(scanQueue, flip.itemID)
    end
    
    -- Remove duplicates
    local seen = {}
    local unique = {}
    for _, itemID in ipairs(scanQueue) do
        if not seen[itemID] then
            seen[itemID] = true
            table.insert(unique, itemID)
        end
    end
    scanQueue = unique
    
    self.scanner.total = #scanQueue
    self:Debug("Fast scan queued:", #scanQueue, "items")
    
    processingQueue = true
    self:ProcessScanQueue()
end

-------------------------------------------------------------------------------
-- Sniper Scan
-------------------------------------------------------------------------------

function QF:StartSniperScan()
    local watchlist = self:GetWatchlist()
    scanQueue = {}
    
    for itemID in pairs(watchlist) do
        table.insert(scanQueue, itemID)
    end
    
    if #scanQueue == 0 then
        self:Print("Watchlist empty! Add items to snipe.")
        self.scanner.isScanning = false
        return
    end
    
    self.scanner.total = #scanQueue
    processingQueue = true
    self:ProcessScanQueue()
end

-------------------------------------------------------------------------------
-- Deals Scan (Continuous)
-------------------------------------------------------------------------------

function QF:StartDealsScanner()
    if dealsScanner then return end
    
    self:Debug("Deals scanner started")
    
    dealsScanner = C_Timer.NewTicker(DEALS_SCAN_INTERVAL, function()
        if self.isAHOpen and not self.scanner.isScanning then
            self:StartScan("fast")
        end
    end)
end

function QF:StopDealsScanner()
    if dealsScanner then
        dealsScanner:Cancel()
        dealsScanner = nil
        self:Debug("Deals scanner stopped")
    end
end

function QF:StartDealsScan()
    -- Look for deals in browse results
    local query = {
        searchString = "",
        sorts = {
            {sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false},
        },
    }
    C_AuctionHouse.SendBrowseQuery(query)
end

-------------------------------------------------------------------------------
-- Scan Queue Processing
-------------------------------------------------------------------------------

function QF:ProcessScanQueue()
    if not processingQueue or #scanQueue == 0 then
        processingQueue = false
        if self.scanner.isScanning then
            self:OnScanComplete()
        end
        return
    end
    
    local itemID = table.remove(scanQueue, 1)
    self:ScanItem(itemID)
    self.scanner.progress = self.scanner.total - #scanQueue
    
    -- Update progress display
    if self.mainFrame and self.mainFrame.scanProgress then
        local pct = (self.scanner.progress / max(self.scanner.total, 1)) * 100
        self.mainFrame.scanProgress:SetText(format("Scanning: %d%%", pct))
    end
    
    C_Timer.After(SCAN_THROTTLE, function()
        self:ProcessScanQueue()
    end)
end

function QF:ScanItem(itemID)
    if not itemID then return end
    
    local itemKey = C_AuctionHouse.MakeItemKey(itemID)
    if itemKey then
        self.scanner.pendingSearches[itemID] = true
        C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
    end
end

-------------------------------------------------------------------------------
-- Search Results Handlers
-------------------------------------------------------------------------------

function QF:OnCommodityResultsUpdated(itemID)
    if not itemID then return end
    
    self.scanner.pendingSearches[itemID] = nil
    
    local numResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    if numResults == 0 then return end
    
    -- Get all listings for competitor analysis
    local listings = {}
    local lowestPrice = nil
    local totalQuantity = 0
    
    for i = 1, min(numResults, 100) do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if result then
            table.insert(listings, {
                price = result.unitPrice,
                quantity = result.quantity,
                numOwnerItems = result.numOwnerItems,
            })
            
            if not lowestPrice or result.unitPrice < lowestPrice then
                lowestPrice = result.unitPrice
            end
            totalQuantity = totalQuantity + result.quantity
        end
    end
    
    if lowestPrice then
        self:StorePrice(itemID, lowestPrice, totalQuantity, numResults)
        self:StoreCompetitorData(itemID, listings)
        
        -- Check for sniper alert
        if self:IsSniperDeal(itemID, lowestPrice) then
            self:AlertDeal(itemID, lowestPrice, listings[1])
        end
        
        table.insert(self.scanner.results, {
            itemID = itemID,
            price = lowestPrice,
            quantity = totalQuantity,
            listings = listings,
            isCommodity = true,
        })
    end
end

function QF:OnItemResultsUpdated(itemKey)
    if not itemKey then return end
    
    local itemID = itemKey.itemID
    self.scanner.pendingSearches[itemID] = nil
    
    local numResults = C_AuctionHouse.GetNumItemSearchResults(itemKey)
    if numResults == 0 then return end
    
    local listings = {}
    local lowestPrice = nil
    
    for i = 1, min(numResults, 100) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if result and result.buyoutAmount then
            table.insert(listings, {
                auctionID = result.auctionID,
                price = result.buyoutAmount,
                quantity = result.quantity or 1,
                itemLink = result.itemLink,
                timeLeft = result.timeLeft,
            })
            
            if not lowestPrice or result.buyoutAmount < lowestPrice then
                lowestPrice = result.buyoutAmount
            end
        end
    end
    
    if lowestPrice then
        self:StorePrice(itemID, lowestPrice, numResults, numResults)
        self:StoreCompetitorData(itemID, listings)
        
        if self:IsSniperDeal(itemID, lowestPrice) then
            self:AlertDeal(itemID, lowestPrice, listings[1])
        end
        
        table.insert(self.scanner.results, {
            itemID = itemID,
            itemKey = itemKey,
            price = lowestPrice,
            quantity = numResults,
            listings = listings,
            isCommodity = false,
        })
    end
end

function QF:OnNewResultsReceived(itemID)
    -- Handle incremental results
    self:Debug("New results for:", itemID)
end

-------------------------------------------------------------------------------
-- Scan Completion
-------------------------------------------------------------------------------

function QF:OnScanComplete()
    if not self.scanner.isScanning then return end
    
    self.scanner.isScanning = false
    local duration = time() - (self.scanner.startTime or time())
    local count = #self.scanner.results
    
    self:Print(format("Scan complete: %d items in %ds", count, duration))
    
    -- Recalculate flip suggestions
    self:CalculateFlipSuggestions()
    
    -- Update UI
    self:RefreshUI()
    
    -- Clear progress
    if self.mainFrame and self.mainFrame.scanProgress then
        self.mainFrame.scanProgress:SetText("")
    end
end

-------------------------------------------------------------------------------
-- Deal Alerts
-------------------------------------------------------------------------------

function QF:AlertDeal(itemID, currentPrice, listingData)
    local watchEntry = self.db.watchlist[itemID]
    local now = time()
    
    -- Don't spam alerts (30 second cooldown per item)
    if watchEntry and watchEntry.lastAlert and (now - watchEntry.lastAlert) < 30 then
        return
    end
    
    if watchEntry then
        watchEntry.lastAlert = now
    end
    
    local itemName, itemLink = C_Item.GetItemInfo(itemID)
    local marketPrice = self:GetMarketPrice(itemID)
    local percent = self:GetMarketPercent(itemID, currentPrice)
    local savings = marketPrice and (marketPrice - currentPrice) or 0
    
    -- Print alert
    self:Print(format("|cff00ff00★ DEAL:|r %s at %s (%s)", 
        itemLink or itemName or "Item", 
        self:FormatGoldShort(currentPrice),
        self:FormatPercent(percent)))
    
    -- Play sound
    if self.config and self.config.soundAlerts then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
    
    -- Show instant buy popup for great deals
    if percent and percent < 60 and self.config and self.config.instantBuyPopup then
        local dialog = StaticPopup_Show("QUICKFLIP_INSTANT_BUY",
            itemLink or itemName,
            self:FormatGold(currentPrice),
            self:FormatPercent(percent),
            self:FormatGold(savings))
        
        if dialog then
            dialog.data = {
                itemID = itemID,
                price = currentPrice,
                listingData = listingData,
                isCommodity = listingData and not listingData.auctionID,
            }
        end
    end
    
    -- Update deals display
    if self.dealsFrame and self.dealsFrame:IsVisible() then
        self:UpdateDealsDisplay()
    end
end

-------------------------------------------------------------------------------
-- Sniper Mode
-------------------------------------------------------------------------------

local sniperTicker = nil

function QF:ToggleSniper()
    if sniperTicker then
        sniperTicker:Cancel()
        sniperTicker = nil
        self:Print("Sniper: |cffff0000OFF|r")
        
        if self.sniperFrame then
            self.sniperFrame.status:SetText("Sniper: |cffff0000OFF|r")
            self.sniperFrame.toggleBtn:SetText("Start Sniper")
        end
    else
        if not self.isAHOpen then
            self:Print("Open the Auction House first!")
            return
        end
        
        local watchCount = self:TableCount(self:GetWatchlist())
        if watchCount == 0 then
            self:Print("Add items to watchlist first!")
            return
        end
        
        self:Print("Sniper: |cff00ff00ON|r - Scanning " .. watchCount .. " items every 10s")
        
        -- Initial scan
        self:StartScan("sniper")
        
        -- Recurring scans
        sniperTicker = C_Timer.NewTicker(10, function()
            if self.isAHOpen then
                self:StartScan("sniper")
            else
                self:ToggleSniper()  -- Stop if AH closed
            end
        end)
        
        if self.sniperFrame then
            self.sniperFrame.status:SetText("Sniper: |cff00ff00ON|r")
            self.sniperFrame.toggleBtn:SetText("Stop Sniper")
        end
    end
end

function QF:IsSniperActive()
    return sniperTicker ~= nil
end

-------------------------------------------------------------------------------

QF:Debug("Scanner.lua loaded")
