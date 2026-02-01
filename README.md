# QuickFlip - Better Than Auctionator

A fast, smart World of Warcraft auction house addon focused on **actually making gold**, not just displaying data.

## Why QuickFlip > Auctionator

| Feature | Auctionator | QuickFlip |
|---------|-------------|-----------|
| Deal Detection | ❌ Just shows prices | ✅ Color-coded % of market, "STEAL" ratings |
| Auto Deals Tab | ❌ Manual searching | ✅ Auto-populated live deals |
| Profit Tracking | ❌ Basic | ✅ Session/Daily/Weekly with cost basis |
| Flip Suggestions | ❌ None | ✅ Algorithm-based recommendations |
| Smart Pricing | ❌ Simple undercut | ✅ Competition analysis, velocity-based |
| Sniper | ❌ Clunky shopping lists | ✅ Real-time alerts, instant buy popup |
| Tooltips | ❌ Basic | ✅ Market price, your cost, profit margin |
| UI | ❌ Dated 2010 look | ✅ Modern dark theme |
| Speed | ❌ Click heavy | ✅ Keyboard shortcuts, double-click buy |

## Features

### ★ Live Deals Tab
- Auto-populated with items below market value
- Color-coded deal ratings (STEAL → GREAT → GOOD → FAIR)
- Score-based sorting (price + profit + velocity)
- One click to search and buy

### 💰 Flip Suggestions
- Algorithm finds high-margin, fast-selling items
- Shows buy target, sell target, and margin %
- One click to add to sniper watchlist
- Sorted by profit potential × velocity

### 📊 Profit Tracking
- **Session**: Gold change since login
- **Today**: Spent, earned, profit
- **This Week**: 7-day rolling stats
- **All Time**: Total profit tracked
- **Cost Basis**: Tracks what you paid for items

### 🎯 Smart Sniper
- Watchlist with custom thresholds per item
- Continuous scanning (10-second intervals)
- Sound alerts on deals
- Instant buy popup for great deals (<60%)
- Drag & drop items to add

### 💵 Smart Selling
- **Competition Analysis**: Adjusts undercut based on seller count
  - Monopoly (0 competitors): Price 10% ABOVE market
  - Low competition (1-3): 1% undercut
  - Moderate (4-10): Standard undercut
  - High (10+): Aggressive undercut
- **Velocity Adjustment**: Fast sellers = less undercut needed
- Profit indicator per item
- "Post All" for bulk listing

### 🛒 Smart Buying
- Color-coded price indicators
- Deal ratings in results
- Keyboard shortcuts (1-5 for quick buy)
- Double-click for instant buy on deals
- Savings calculation in tooltip

### 📝 Tooltip Integration
Shows on ALL item tooltips:
- Market price
- Price range (min/max seen)
- Sales velocity
- Your cost basis (if you bought it)
- Profit margin

## Installation

1. Download the `quickflip` folder
2. Copy to your WoW AddOns directory:
   - **Windows**: `C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\`
   - **Mac**: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or `/reload`
4. Enable "QuickFlip" in AddOns menu

## Usage

### Slash Commands
```
/qf         - Toggle window (at AH)
/qf config  - Open settings
/qf scan    - Full AH scan
/qf deals   - Show deals tab
/qf sniper  - Toggle sniper mode
/qf stats   - Show profit stats
/qf flips   - Show flip suggestions
/qf reset   - Reset database
/qf help    - Command list
```

### Keyboard Shortcuts (Buy Tab)
- `1-5` - Quick buy top 5 results
- `Double-click` - Instant buy deals under 60%
- `Enter` - Search in search box

### Quick Workflow
1. Open Auction House → QuickFlip opens automatically
2. Check **★ Deals** tab for instant opportunities
3. Check **Flips** tab for items to watch
4. Add promising items to **Sniper** watchlist
5. When sniper alerts, buy immediately
6. Use **Sell** tab to post at smart prices
7. Track profits in **Stats** tab

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Default Undercut % | 5% | Base undercut (adjusted by competition) |
| Sniper Threshold | 70% | Alert when item ≤ this % of market |
| Deal Threshold | 80% | Show in Deals tab when ≤ this % |
| Sound Alerts | On | Play sound on sniper deals |
| Instant Buy Popup | On | Show popup for deals <60% |
| Auto-Scan | On | Scan when AH opens |
| Tooltip Prices | On | Show prices in all tooltips |

## How Pricing Works

### Market Price Calculation
- Weighted moving average (recent prices weighted more)
- 15-scan rolling window
- Blends historical (60%) with current (40%)

### Smart Undercut Logic
```
Competitors = 0  → Price at 110% of market (monopoly!)
Competitors 1-3  → 1% undercut
Competitors 4-10 → Default undercut (5%)
Competitors 10+  → Aggressive undercut (+5%)

Fast seller (50+/day) → Reduce undercut by 2%
Slow seller (<5/day)  → Increase undercut by 3%
```

### Deal Score Formula
```
Score = (100 - percent) × 10  // Lower % = better
      + min(profit / 10000, 100)  // More profit = better
      + min(velocity, 100)  // Faster seller = better
```

## Requirements

- World of Warcraft Retail (Dragonflight / The War Within)
- Interface version: 110002+

## Version History

### 1.1.0
- ★ Deals tab with auto-population
- Flip suggestions algorithm
- Smart pricing with competition analysis
- Market velocity tracking
- Full profit tracking (session/daily/weekly)
- Cost basis tracking
- Tooltip integration everywhere
- Keyboard shortcuts
- Modern UI overhaul
- Instant buy popups

### 1.0.0
- Initial release

## Author

SCWS

## License

Free to use and modify. Make gold!
