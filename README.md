# QuickFlip

A simple auction house addon for **WoW Classic Era** (Interface 11503).

## Features

### Scan Tab
- **Full Scan** - Scans entire AH (15 minute cooldown)
- Builds price database from scan results
- Shows scan progress and database info

### Buy Tab
- Search for items by name
- Results show: item, quantity, unit price, % of market value
- Color-coded prices:
  - **Green** (<80% market) - Good deal
  - **Yellow** (80-100%) - Fair price
  - **Red** (>100%) - Overpriced
- Click to select, then buy

### Sell Tab
- Shows all sellable items in your bags
- Displays market price for each item
- Click item to put in sell slot
- Set price and post auction

### Stats Tab
- Session gold change
- Purchase/sale counts
- All-time totals
- Database item count

## Installation

1. Copy the `QuickFlip` folder to your WoW Classic addons directory:
   - Windows: `World of Warcraft\_classic_era_\Interface\AddOns\`
   - Mac: `/Applications/World of Warcraft/_classic_era_/Interface/AddOns/`
2. Restart WoW or `/reload`

## Usage

1. Open any Auction House
2. QuickFlip window appears automatically
3. Use tabs to navigate features
4. `/qf` - Show help
5. `/qf scan` - Start full scan
6. `/qf stats` - Show session stats
7. `/qf reset` - Reset price database
8. `/qf debug` - Toggle debug mode

## Files

```
QuickFlip/
├── QuickFlip.toc    # Addon manifest
├── Utils.lua        # Helper functions, formatting
├── Database.lua     # Price storage, persistence
├── Scanner.lua      # AH scanning (page-based)
├── Buying.lua       # Search, deal detection, purchasing
├── Selling.lua      # Bag scan, auction posting
├── UI.lua           # Main frame, tabs, visual elements
└── Core.lua         # Init, events, slash commands
```

## Classic Era API Notes

This addon uses only Classic Era APIs:
- `QueryAuctionItems()` with page-based results
- `GetAuctionItemInfo()` for item details
- `PlaceAuctionBid()` for buying
- `StartAuction()` for selling
- `GetContainerItemInfo()` for bag scanning

No retail APIs are used.

## Version

2.0.0 - Complete rewrite for Classic Era

## Author

SCWS
