--[[
    QuickFlip - Scanner.lua
    Auction House scanning for Classic Era
    Uses page-based queries (50 items per page)
]]

local addonName, QF = ...

-------------------------------------------------------------------------------
-- Scanner State
-------------------------------------------------------------------------------

QF.scanner = {
    isScanning = false,
    scanType = nil,        -- "full" or "search"
    currentPage = 0,
    totalPages = 0,
    totalAuctions = 0,
    scannedCount = 0,
    searchName = nil,
    onComplete = nil
}

-- Full scan cooldown (15 minutes)
local FULL_SCAN_COOLDOWN = 15 * 60

-------------------------------------------------------------------------------
-- Scan Control
-------------------------------------------------------------------------------

function QF:CanFullScan()
    local lastScan = self.db and self.db.lastFullScan or 0
    local elapsed = time() - lastScan
    return elapsed >= FULL_SCAN_COOLDOWN
end

function QF:GetFullScanCooldown()
    if not self.db then return 0 end
    local elapsed = time() - (self.db.lastFullScan or 0)
    local remaining = FULL_SCAN_COOLDOWN - elapsed
    return remaining > 0 and remaining or 0
end

function QF:StartFullScan()
    if not self.isAHOpen then
        self:Print("Open the Auction House first!")
        return false
    end
    
    if self.scanner.isScanning then
        self:Print("Scan already in progress!")
        return false
    end
    
    if not self:CanFullScan() then
        local cd = self:GetFullScanCooldown()
        self:Print("Full scan on cooldown: " .. math.floor(cd / 60) .. "m " .. (cd % 60) .. "s")
        return false
    end
    
    if not CanSendAuctionQuery() then
        self:Print("Auction House busy, try again.")
        return false
    end
    
    self.scanner.isScanning = true
    self.scanner.scanType = "full"
    self.scanner.currentPage = 0
    self.scanner.totalPages = 0
    self.scanner.scannedCount = 0
    self.scanner.searchName = ""
    
    self:Print("Starting full scan...")
    
    -- Use getAll for full scan
    QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
    
    return true
end

function QF:StartSearch(searchName, onComplete)
    if not self.isAHOpen then
        self:Print("Open the Auction House first!")
        return false
    end
    
    if self.scanner.isScanning then
        self:Print("Scan already in progress!")
        return false
    end
    
    if not searchName or searchName == "" then
        return false
    end
    
    if not CanSendAuctionQuery() then
        self:Print("Auction House busy, try again.")
        return false
    end
    
    self.scanner.isScanning = true
    self.scanner.scanType = "search"
    self.scanner.currentPage = 0
    self.scanner.totalPages = 0
    self.scanner.scannedCount = 0
    self.scanner.searchName = searchName
    self.scanner.onComplete = onComplete
    
    self:Debug("Searching for:", searchName)
    
    -- Start search (page 0, not getAll)
    QueryAuctionItems(searchName, nil, nil, 0, nil, nil, false, false, nil)
    
    return true
end

function QF:StopScan()
    self.scanner.isScanning = false
    self.scanner.scanType = nil
    self.scanner.onComplete = nil
    self:UpdateScanButton()
end

-------------------------------------------------------------------------------
-- Process Scan Results
-------------------------------------------------------------------------------

function QF:ProcessAuctionResults()
    if not self.scanner.isScanning then return end
    
    local numBatch, numTotal = GetNumAuctionItems("list")
    
    if numTotal == 0 then
        self:Debug("No results found")
        self:OnScanComplete()
        return
    end
    
    self.scanner.totalAuctions = numTotal
    self.scanner.totalPages = math.ceil(numTotal / 50)
    
    self:Debug("Processing page", self.scanner.currentPage + 1, "of", self.scanner.totalPages, "(" .. numBatch .. " items)")
    
    -- Process all items in this batch
    local results = {}
    for i = 1, numBatch do
        local name, texture, count, quality, canUse, level, levelColHeader,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemId, 
              hasAllInfo = GetAuctionItemInfo("list", i)
        
        local link = GetAuctionItemLink("list", i)
        
        if name and itemId and buyoutPrice and buyoutPrice > 0 then
            local unitPrice = self:GetUnitPrice(buyoutPrice, count)
            
            -- Update database with this price
            self:UpdatePrice(itemId, unitPrice, count)
            
            -- Store for display
            table.insert(results, {
                index = i,
                name = name,
                texture = texture,
                count = count,
                quality = quality,
                minBid = minBid,
                buyoutPrice = buyoutPrice,
                unitPrice = unitPrice,
                bidAmount = bidAmount,
                owner = owner,
                itemId = itemId,
                link = link
            })
            
            self.scanner.scannedCount = self.scanner.scannedCount + 1
        end
    end
    
    -- Store results for display
    self.lastSearchResults = results
    
    -- Update progress
    self:UpdateScanProgress()
    
    -- Check if we need more pages (for search only, getAll returns everything)
    if self.scanner.scanType == "search" then
        local nextPage = self.scanner.currentPage + 1
        if nextPage < self.scanner.totalPages then
            -- Wait then query next page
            self.scanner.currentPage = nextPage
            
            -- Use a simple frame-based delay
            local delay = CreateFrame("Frame")
            delay.elapsed = 0
            delay:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 0.5 then
                    self:SetScript("OnUpdate", nil)
                    if QF.scanner.isScanning and CanSendAuctionQuery() then
                        QueryAuctionItems(QF.scanner.searchName, nil, nil, nextPage, nil, nil, false, false, nil)
                    end
                end
            end)
        else
            self:OnScanComplete()
        end
    else
        -- Full scan completes in one query
        self:OnScanComplete()
    end
end

function QF:OnScanComplete()
    local scanType = self.scanner.scanType
    local scannedCount = self.scanner.scannedCount
    
    if scanType == "full" then
        self.db.lastFullScan = time()
        self:Print("Full scan complete! Scanned " .. scannedCount .. " auctions.")
    else
        self:Debug("Search complete:", scannedCount, "results")
    end
    
    -- Call completion callback if set
    if self.scanner.onComplete then
        self.scanner.onComplete(self.lastSearchResults)
    end
    
    self:StopScan()
    self:UpdateSearchResults()
end

-------------------------------------------------------------------------------
-- UI Updates
-------------------------------------------------------------------------------

function QF:UpdateScanProgress()
    if not self.scanFrame then return end
    
    local progress = self.scanner.currentPage / math.max(1, self.scanner.totalPages)
    local text = string.format("Scanning... %d/%d pages", 
        self.scanner.currentPage + 1, self.scanner.totalPages)
    
    if self.scanFrame.progressText then
        self.scanFrame.progressText:SetText(text)
    end
    if self.scanFrame.progressBar then
        self.scanFrame.progressBar:SetValue(progress)
    end
end

function QF:UpdateScanButton()
    if not self.scanFrame or not self.scanFrame.scanButton then return end
    
    local btn = self.scanFrame.scanButton
    
    if self.scanner.isScanning then
        btn:SetText("Scanning...")
        btn:Disable()
    elseif not self:CanFullScan() then
        local cd = self:GetFullScanCooldown()
        btn:SetText("Cooldown: " .. math.floor(cd / 60) .. "m")
        btn:Disable()
    else
        btn:SetText("Full Scan")
        btn:Enable()
    end
end

function QF:UpdateSearchResults()
    -- Implemented in Buying.lua
    if self.UpdateBuyList then
        self:UpdateBuyList()
    end
end

QF:Debug("Scanner.lua loaded")
