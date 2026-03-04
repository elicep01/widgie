The AI needs a MASSIVE library of examples showing:

- Complex multi-column layouts
- How to fetch from ANY API (crypto, stocks, Polymarket, etc.)
- Mix-and-match patterns (time + weather side-by-side)
- Advanced UI customizations

COMPREHENSIVE WIDGET PATTERN LIBRARY

This library contains 50+ real widget examples showing:
- Complex multi-column layouts
- API fetching from ANY source
- Mix-and-match patterns
- Advanced UI customizations

Study these patterns and mix/match to create ANYTHING the user requests.

SECTION 1: MULTI-LOCATION TIME + WEATHER (Complex Layouts)

Example 1: Three Cities - Time Left, Weather Right
User request: "time in 12 hour digital for pune, tempe and seattle with weather on the right"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 16, "padding": 24},
    "children": [
      {
        "type": "HStack",
        "props": {"spacing": 20},
        "children": [
          {
            "type": "VStack",
            "props": {"spacing": 4, "alignment": "leading"},
            "children": [
              {"type": "Text", "props": {"content": "Pune, India", "size": 16, "weight": "semibold", "color": "#FFFFFF"}},
              {"type": "Text", "props": {"content": "{{time}}", "size": 42, "weight": "bold", "color": "#FFFFFF", "dataSource": "currentTime:Asia/Kolkata:12h"}},
              {"type": "Text", "props": {"content": "{{date}}", "size": 14, "color": "#FFFFFF", "opacity": 0.7, "dataSource": "currentTime:Asia/Kolkata:12h-date"}}
            ]
          },
          {"type": "Spacer"},
          {
            "type": "HStack",
            "props": {"spacing": 12},
            "children": [
              {"type": "Image", "props": {"systemName": "{{icon}}", "size": 40, "color": "#FFD700", "dataSource": "weather:Pune, India"}},
              {"type": "Text", "props": {"content": "{{temperature}} degC", "size": 28, "weight": "bold", "color": "#FFFFFF", "dataSource": "weather:Pune, India"}}
            ]
          }
        ]
      },
      {"type": "Divider", "props": {"color": "#FFFFFF", "opacity": 0.2}},
      {
        "type": "HStack",
        "props": {"spacing": 20},
        "children": [
          {
            "type": "VStack",
            "props": {"spacing": 4, "alignment": "leading"},
            "children": [
              {"type": "Text", "props": {"content": "Tempe, Arizona", "size": 16, "weight": "semibold", "color": "#FFFFFF"}},
              {"type": "Text", "props": {"content": "{{time}}", "size": 42, "weight": "bold", "color": "#FFFFFF", "dataSource": "currentTime:America/Phoenix:12h"}},
              {"type": "Text", "props": {"content": "{{date}}", "size": 14, "color": "#FFFFFF", "opacity": 0.7, "dataSource": "currentTime:America/Phoenix:12h-date"}}
            ]
          },
          {"type": "Spacer"},
          {
            "type": "HStack",
            "props": {"spacing": 12},
            "children": [
              {"type": "Image", "props": {"systemName": "{{icon}}", "size": 40, "color": "#FFD700", "dataSource": "weather:Tempe, Arizona"}},
              {"type": "Text", "props": {"content": "{{temperature}} degF", "size": 28, "weight": "bold", "color": "#FFFFFF", "dataSource": "weather:Tempe, Arizona"}}
            ]
          }
        ]
      },
      {"type": "Divider", "props": {"color": "#FFFFFF", "opacity": 0.2}},
      {
        "type": "HStack",
        "props": {"spacing": 20},
        "children": [
          {
            "type": "VStack",
            "props": {"spacing": 4, "alignment": "leading"},
            "children": [
              {"type": "Text", "props": {"content": "Seattle, WA", "size": 16, "weight": "semibold", "color": "#FFFFFF"}},
              {"type": "Text", "props": {"content": "{{time}}", "size": 42, "weight": "bold", "color": "#FFFFFF", "dataSource": "currentTime:America/Los_Angeles:12h"}},
              {"type": "Text", "props": {"content": "{{date}}", "size": 14, "color": "#FFFFFF", "opacity": 0.7, "dataSource": "currentTime:America/Los_Angeles:12h-date"}}
            ]
          },
          {"type": "Spacer"},
          {
            "type": "HStack",
            "props": {"spacing": 12},
            "children": [
              {"type": "Image", "props": {"systemName": "{{icon}}", "size": 40, "color": "#FFD700", "dataSource": "weather:Seattle, WA"}},
              {"type": "Text", "props": {"content": "{{temperature}} degF", "size": 28, "weight": "bold", "color": "#FFFFFF", "dataSource": "weather:Seattle, WA"}}
            ]
          }
        ]
      }
    ]
  },
  "dataSources": [
    {"type": "currentTime", "timezone": "Asia/Kolkata", "format": "12h", "updateFrequency": 1},
    {"type": "weather", "location": "Pune, India", "updateFrequency": 900},
    {"type": "currentTime", "timezone": "America/Phoenix", "format": "12h", "updateFrequency": 1},
    {"type": "weather", "location": "Tempe, Arizona", "updateFrequency": 900},
    {"type": "currentTime", "timezone": "America/Los_Angeles", "format": "12h", "updateFrequency": 1},
    {"type": "weather", "location": "Seattle, WA", "updateFrequency": 900}
  ]
}

SECTION 2: CRYPTO TRACKING (Bitcoin, Ethereum, etc.)

Example 2: Bitcoin & Ethereum Live Prices
User request: "bitcoin ethereum live prices"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 16, "padding": 24, "background": {"gradient": ["#667eea", "#764ba2"]}},
    "children": [
      {"type": "Text", "props": {"content": "Crypto Tracker", "size": 20, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "HStack",
        "props": {"spacing": 16},
        "children": [
          {
            "type": "VStack",
            "props": {"spacing": 8, "padding": 16, "background": {"type": "blur", "intensity": "medium"}, "borderRadius": 12},
            "children": [
              {"type": "Image", "props": {"systemName": "bitcoinsign.circle.fill", "size": 36, "color": "#F7931A"}},
              {"type": "Text", "props": {"content": "BTC", "size": 14, "weight": "semibold", "color": "#FFFFFF", "opacity": 0.8}},
              {"type": "Text", "props": {"content": "${{price}}", "size": 32, "weight": "bold", "color": "#FFFFFF", "dataSource": "crypto:bitcoin"}},
              {"type": "Text", "props": {"content": "{{change24h}}%", "size": 14, "weight": "medium", "color": "{{changeColor}}", "dataSource": "crypto:bitcoin"}}
            ]
          },
          {
            "type": "VStack",
            "props": {"spacing": 8, "padding": 16, "background": {"type": "blur", "intensity": "medium"}, "borderRadius": 12},
            "children": [
              {"type": "Image", "props": {"systemName": "diamond.fill", "size": 36, "color": "#627EEA"}},
              {"type": "Text", "props": {"content": "ETH", "size": 14, "weight": "semibold", "color": "#FFFFFF", "opacity": 0.8}},
              {"type": "Text", "props": {"content": "${{price}}", "size": 32, "weight": "bold", "color": "#FFFFFF", "dataSource": "crypto:ethereum"}},
              {"type": "Text", "props": {"content": "{{change24h}}%", "size": 14, "weight": "medium", "color": "{{changeColor}}", "dataSource": "crypto:ethereum"}}
            ]
          }
        ]
      }
    ]
  },
  "dataSources": [
    {"type": "crypto", "symbol": "bitcoin", "api": "coingecko", "updateFrequency": 60},
    {"type": "crypto", "symbol": "ethereum", "api": "coingecko", "updateFrequency": 60}
  ]
}

Example 3: Gold & Silver Commodity Prices
User request: "gold and silver prices live"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 16, "padding": 24, "background": {"gradient": ["#FFD700", "#C0C0C0"]}},
    "children": [
      {"type": "Text", "props": {"content": "Precious Metals", "size": 20, "weight": "bold", "color": "#000000"}},
      {
        "type": "HStack",
        "props": {"spacing": 16},
        "children": [
          {
            "type": "VStack",
            "props": {"spacing": 8},
            "children": [
              {"type": "Image", "props": {"systemName": "circle.fill", "size": 40, "color": "#FFD700"}},
              {"type": "Text", "props": {"content": "GOLD", "size": 16, "weight": "bold", "color": "#000000"}},
              {"type": "Text", "props": {"content": "${{price}}/oz", "size": 28, "weight": "bold", "color": "#000000", "dataSource": "commodity:gold"}},
              {"type": "Text", "props": {"content": "{{change}}%", "size": 14, "color": "{{changeColor}}", "dataSource": "commodity:gold"}}
            ]
          },
          {
            "type": "VStack",
            "props": {"spacing": 8},
            "children": [
              {"type": "Image", "props": {"systemName": "circle.fill", "size": 40, "color": "#C0C0C0"}},
              {"type": "Text", "props": {"content": "SILVER", "size": 16, "weight": "bold", "color": "#000000"}},
              {"type": "Text", "props": {"content": "${{price}}/oz", "size": 28, "weight": "bold", "color": "#000000", "dataSource": "commodity:silver"}},
              {"type": "Text", "props": {"content": "{{change}}%", "size": 14, "color": "{{changeColor}}", "dataSource": "commodity:silver"}}
            ]
          }
        ]
      }
    ]
  },
  "dataSources": [
    {"type": "commodity", "symbol": "XAU", "name": "gold", "api": "metals-api", "updateFrequency": 300},
    {"type": "commodity", "symbol": "XAG", "name": "silver", "api": "metals-api", "updateFrequency": 300}
  ]
}

SECTION 3: STOCK TRACKING

Example 4: AAPL, TSLA, NVDA Stock Tracker
User request: "track AAPL TSLA NVDA stocks live"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Tech Stocks", "size": 22, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "VStack",
        "props": {"spacing": 10},
        "children": [
          {
            "type": "HStack",
            "props": {"spacing": 16, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "AAPL", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
              {"type": "Spacer"},
              {"type": "Text", "props": {"content": "${{price}}", "size": 24, "weight": "bold", "color": "#FFFFFF", "dataSource": "stock:AAPL"}},
              {"type": "Text", "props": {"content": "{{changePercent}}%", "size": 16, "weight": "semibold", "color": "{{priceColor}}", "dataSource": "stock:AAPL"}}
            ]
          },
          {
            "type": "HStack",
            "props": {"spacing": 16, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "TSLA", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
              {"type": "Spacer"},
              {"type": "Text", "props": {"content": "${{price}}", "size": 24, "weight": "bold", "color": "#FFFFFF", "dataSource": "stock:TSLA"}},
              {"type": "Text", "props": {"content": "{{changePercent}}%", "size": 16, "weight": "semibold", "color": "{{priceColor}}", "dataSource": "stock:TSLA"}}
            ]
          },
          {
            "type": "HStack",
            "props": {"spacing": 16, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "NVDA", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
              {"type": "Spacer"},
              {"type": "Text", "props": {"content": "${{price}}", "size": 24, "weight": "bold", "color": "#FFFFFF", "dataSource": "stock:NVDA"}},
              {"type": "Text", "props": {"content": "{{changePercent}}%", "size": 16, "weight": "semibold", "color": "{{priceColor}}", "dataSource": "stock:NVDA"}}
            ]
          }
        ]
      }
    ]
  },
  "dataSources": [
    {"type": "stock", "symbol": "AAPL", "api": "yahoofinance", "updateFrequency": 60},
    {"type": "stock", "symbol": "TSLA", "api": "yahoofinance", "updateFrequency": 60},
    {"type": "stock", "symbol": "NVDA", "api": "yahoofinance", "updateFrequency": 60}
  ]
}

SECTION 4: POLYMARKET / PREDICTION MARKETS

Example 5: Polymarket Profile Stats
User request: "show polymarket profile @distinct-baguette stats"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 16, "padding": 24, "background": {"gradient": ["#1a1a2e", "#16213e"]}},
    "children": [
      {
        "type": "HStack",
        "props": {"spacing": 12},
        "children": [
          {"type": "Image", "props": {"systemName": "person.crop.circle.fill", "size": 48, "color": "#0f3460"}},
          {
            "type": "VStack",
            "props": {"spacing": 4, "alignment": "leading"},
            "children": [
              {"type": "Text", "props": {"content": "@{{username}}", "size": 20, "weight": "bold", "color": "#FFFFFF", "dataSource": "polymarket:profile:distinct-baguette"}},
              {"type": "Text", "props": {"content": "Polymarket Trader", "size": 14, "color": "#FFFFFF", "opacity": 0.7}}
            ]
          }
        ]
      },
      {"type": "Divider", "props": {"color": "#FFFFFF", "opacity": 0.2}},
      {
        "type": "Grid",
        "props": {"columns": 2, "spacing": 12},
        "children": [
          {
            "type": "VStack",
            "props": {"spacing": 4, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "Total Volume", "size": 12, "color": "#FFFFFF", "opacity": 0.6}},
              {"type": "Text", "props": {"content": "${{volume}}", "size": 24, "weight": "bold", "color": "#00FF00", "dataSource": "polymarket:profile:distinct-baguette"}}
            ]
          },
          {
            "type": "VStack",
            "props": {"spacing": 4, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "Profit/Loss", "size": 12, "color": "#FFFFFF", "opacity": 0.6}},
              {"type": "Text", "props": {"content": "${{profit}}", "size": 24, "weight": "bold", "color": "{{profitColor}}", "dataSource": "polymarket:profile:distinct-baguette"}}
            ]
          },
          {
            "type": "VStack",
            "props": {"spacing": 4, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "Markets Traded", "size": 12, "color": "#FFFFFF", "opacity": 0.6}},
              {"type": "Text", "props": {"content": "{{marketsCount}}", "size": 24, "weight": "bold", "color": "#FFFFFF", "dataSource": "polymarket:profile:distinct-baguette"}}
            ]
          },
          {
            "type": "VStack",
            "props": {"spacing": 4, "padding": 12, "background": {"type": "blur"}, "borderRadius": 8},
            "children": [
              {"type": "Text", "props": {"content": "Win Rate", "size": 12, "color": "#FFFFFF", "opacity": 0.6}},
              {"type": "Text", "props": {"content": "{{winRate}}%", "size": 24, "weight": "bold", "color": "#FFFFFF", "dataSource": "polymarket:profile:distinct-baguette"}}
            ]
          }
        ]
      },
      {"type": "LineChart", "props": {"dataSource": "polymarket:profile:distinct-baguette:volumeHistory", "height": 150, "color": "#00FF00", "showGrid": true}}
    ]
  },
  "dataSources": [
    {"type": "polymarket", "endpoint": "profile", "username": "distinct-baguette", "updateFrequency": 300}
  ]
}

SECTION 5: DATA SOURCE PATTERNS

CRITICAL: How to fetch from ANY API

Pattern: Generic API Fetching
{
  "dataSource": "api:https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd",
  "jsonPath": "bitcoin.usd",
  "updateFrequency": 60
}

Pattern: Crypto from CoinGecko
{
  "dataSource": "crypto:bitcoin",
  "api": "coingecko",
  "endpoint": "/api/v3/simple/price",
  "params": {"ids": "bitcoin", "vs_currencies": "usd"},
  "variables": {"price": "bitcoin.usd", "change24h": "bitcoin.usd_24h_change"}
}

Pattern: Stocks from Yahoo Finance
{
  "dataSource": "stock:AAPL",
  "api": "yahoofinance",
  "endpoint": "/v8/finance/quote",
  "params": {"symbols": "AAPL"},
  "variables": {"price": "quoteResponse.result[0].regularMarketPrice", "changePercent": "quoteResponse.result[0].regularMarketChangePercent"}
}

Pattern: Polymarket Profile
{
  "dataSource": "polymarket:profile:distinct-baguette",
  "api": "polymarket-gamma",
  "endpoint": "/profiles/distinct-baguette",
  "variables": {
    "username": "username",
    "volume": "volume",
    "profit": "profit",
    "marketsCount": "markets_count",
    "winRate": "win_rate"
  }
}

Pattern: News from NewsAPI
{
  "dataSource": "news:tech AI jobs",
  "api": "newsapi",
  "endpoint": "/v2/everything",
  "params": {"q": "tech AND AI AND jobs", "sortBy": "publishedAt"},
  "variables": {"headlines": "articles[].title", "urls": "articles[].url"}
}

SECTION 6: ADVANCED UI PATTERNS

Pattern: Grid Layout (2x2, 3x3, etc.)
{
  "type": "Grid",
  "props": {"columns": 2, "spacing": 12},
  "children": ["4 items for 2x2 grid"]
}

Pattern: Side-by-side comparison
{
  "type": "HStack",
  "props": {"spacing": 20},
  "children": [
    {"left": "Left column"},
    {"type": "Divider", "props": {"orientation": "vertical"}},
    {"right": "Right column"}
  ]
}

Pattern: Stacked cards with dividers
{
  "type": "VStack",
  "props": {"spacing": 0},
  "children": [
    {"card": "Card 1"},
    {"type": "Divider"},
    {"card": "Card 2"},
    {"type": "Divider"},
    {"card": "Card 3"}
  ]
}

Pattern: Glassmorphism card
{
  "type": "VStack",
  "props": {
    "padding": 20,
    "background": {"type": "blur", "intensity": "medium"},
    "borderRadius": 16,
    "border": {"width": 1, "color": "#FFFFFF", "opacity": 0.2},
    "shadow": {"radius": 20, "opacity": 0.3, "color": "#000000"}
  }
}

Pattern: Gradient background
{
  "props": {
    "background": {
      "gradient": [
        {"color": "#667eea", "position": 0},
        {"color": "#764ba2", "position": 1}
      ]
    }
  }
}

Pattern: Animated icon (pulsing)
{
  "type": "Image",
  "props": {
    "systemName": "bitcoinsign.circle.fill",
    "size": 48,
    "color": "#F7931A",
    "animation": "pulse"
  }
}

KEY INSIGHTS FOR AI

1. MIX AND MATCH: Combine patterns freely
- Want time + weather + stocks in one widget? Yes
- Want 5 cryptocurrencies in a grid? Yes
- Want news headlines with clickable links? Yes

2. ANY API WORKS: Use the generic API pattern
- Just specify: URL, JSON path, update frequency
- System will fetch and inject data

3. LAYOUT FLEXIBILITY:
- HStack = side-by-side (time LEFT, weather RIGHT)
- VStack = stacked vertically
- Grid = multi-column grid layout
- Mix them: VStack of HStacks, HStack of Grids, etc.

4. ALWAYS ADD:
- Edit button for customization
- Proper spacing and padding
- Beautiful gradients or blur backgrounds
- Animations where appropriate
- Dividers between sections

5. DATA SOURCE CREATIVITY:
- If API exists, you can fetch from it
- Use "api:URL" pattern for custom APIs
- Specify JSON path to extract values
- Set appropriate update frequencies

════════════════════════════════════════════════════════════════
SECTION 7: GRID/HEATMAP PATTERNS (GitHub-style tracking)
════════════════════════════════════════════════════════════════

The GitHub contribution grid is a HEATMAP where:
- Each cell = a time period (hour/day/week/month)
- Cell color = intensity (0 contributions = gray, 50+ = dark green)
- Shows patterns over time visually

This pattern works for tracking ANYTHING:
- GitHub contributions
- Habit tracking (did I exercise today?)
- Mood tracking (how did I feel each day?)
- Productivity (hours worked per day)
- Sales metrics (revenue per day)
- App usage (screen time per day)

────────────────────────────────────────────────────
Pattern A: DAILY GRID (Last 365 days - GitHub style)
────────────────────────────────────────────────────

Example: GitHub Contributions
User request: "show my github contributions last year"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {
        "type": "HStack",
        "props": {"spacing": 8},
        "children": [
          {"type": "Text", "props": {"content": "GitHub Contributions", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
          {"type": "Spacer"},
          {"type": "Text", "props": {"content": "{{totalContributions}} total", "size": 14, "color": "#FFFFFF", "opacity": 0.7, "dataSource": "github:contributions:USERNAME"}}
        ]
      },
      {
        "type": "ContributionGrid",
        "props": {
          "dataSource": "github:contributions:USERNAME",
          "cellSize": 12,
          "cellSpacing": 3,
          "colorScale": [
            {"value": 0, "color": "#161b22"},
            {"value": 1, "color": "#0e4429"},
            {"value": 5, "color": "#006d32"},
            {"value": 10, "color": "#26a641"},
            {"value": 20, "color": "#39d353"}
          ],
          "showMonthLabels": true,
          "showDayLabels": true,
          "tooltip": "{{count}} contributions on {{date}}"
        }
      },
      {
        "type": "HStack",
        "props": {"spacing": 4, "alignment": "center"},
        "children": [
          {"type": "Text", "props": {"content": "Less", "size": 11, "color": "#FFFFFF", "opacity": 0.6}},
          {"type": "Rectangle", "props": {"width": 12, "height": 12, "fill": "#161b22", "cornerRadius": 2}},
          {"type": "Rectangle", "props": {"width": 12, "height": 12, "fill": "#0e4429", "cornerRadius": 2}},
          {"type": "Rectangle", "props": {"width": 12, "height": 12, "fill": "#006d32", "cornerRadius": 2}},
          {"type": "Rectangle", "props": {"width": 12, "height": 12, "fill": "#26a641", "cornerRadius": 2}},
          {"type": "Rectangle", "props": {"width": 12, "height": 12, "fill": "#39d353", "cornerRadius": 2}},
          {"type": "Text", "props": {"content": "More", "size": 11, "color": "#FFFFFF", "opacity": 0.6}}
        ]
      }
    ]
  },
  "dataSources": [
    {
      "type": "github",
      "endpoint": "contributions",
      "username": "USERNAME",
      "range": "last365days",
      "updateFrequency": 3600
    }
  ]
}

Data format returned by API:
{
  "totalContributions": 1247,
  "days": [
    {"date": "2026-02-16", "count": 12},
    {"date": "2026-02-15", "count": 8},
    {"date": "2026-02-14", "count": 0}
  ]
}

────────────────────────────────────────────────────
Pattern B: HOURLY GRID (24 hours x 7 days = Weekly pattern)
────────────────────────────────────────────────────

Example: Work Hours Heatmap
User request: "show when I'm most productive each day"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Work Hours This Week", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "HourlyGrid",
        "props": {
          "dataSource": "productivity:hourly",
          "cellSize": 20,
          "cellSpacing": 2,
          "rows": 7,
          "columns": 24,
          "rowLabels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
          "columnLabels": ["12a", "1a", "2a", "3a", "4a", "5a", "6a", "7a", "8a", "9a", "10a", "11a", "12p", "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p", "10p", "11p"],
          "colorScale": [
            {"value": 0, "color": "#1e1e1e"},
            {"value": 1, "color": "#0a3069"},
            {"value": 30, "color": "#1f6feb"},
            {"value": 60, "color": "#58a6ff"}
          ],
          "tooltip": "{{hours}}h worked at {{time}} on {{day}}"
        }
      },
      {"type": "Text", "props": {"content": "Darker = more productive", "size": 12, "color": "#FFFFFF", "opacity": 0.6}}
    ]
  },
  "dataSources": [
    {
      "type": "productivity",
      "endpoint": "hourly",
      "range": "thisWeek",
      "updateFrequency": 900
    }
  ]
}

Data format:
{
  "hours": [
    {"day": "Monday", "hour": 9, "value": 45},
    {"day": "Monday", "hour": 10, "value": 60}
  ]
}

────────────────────────────────────────────────────
Pattern C: MONTHLY GRID (12 months x years)
────────────────────────────────────────────────────

Example: Sales Revenue Heatmap
User request: "show monthly revenue for last 3 years"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Monthly Revenue (Last 3 Years)", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "MonthlyGrid",
        "props": {
          "dataSource": "sales:monthly",
          "cellSize": 40,
          "cellSpacing": 4,
          "rows": 3,
          "columns": 12,
          "rowLabels": ["2024", "2025", "2026"],
          "columnLabels": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
          "colorScale": [
            {"value": 0, "color": "#2d2d2d"},
            {"value": 10000, "color": "#1a5f3a"},
            {"value": 50000, "color": "#2d8f5c"},
            {"value": 100000, "color": "#40bf7e"}
          ],
          "tooltip": "${{revenue}} in {{month}} {{year}}",
          "valueFormat": "${{value}}K"
        }
      }
    ]
  },
  "dataSources": [
    {
      "type": "sales",
      "endpoint": "monthly",
      "range": "last36months",
      "updateFrequency": 86400
    }
  ]
}

────────────────────────────────────────────────────
Pattern D: HABIT TRACKER (Daily, binary yes/no)
────────────────────────────────────────────────────

Example: Exercise Tracking
User request: "track if I exercised each day"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Exercise Streak", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
      {"type": "Text", "props": {"content": "Current streak: {{currentStreak}} days", "size": 14, "color": "#00FF00", "dataSource": "habits:exercise"}},
      {
        "type": "HabitGrid",
        "props": {
          "dataSource": "habits:exercise",
          "cellSize": 15,
          "cellSpacing": 3,
          "range": "last90days",
          "colorScale": [
            {"value": false, "color": "#2d2d2d"},
            {"value": true, "color": "#00FF00"}
          ],
          "showMonthLabels": true,
          "tooltip": "{{status}} on {{date}}"
        }
      },
      {
        "type": "HStack",
        "props": {"spacing": 8},
        "children": [
          {"type": "Button", "props": {"label": "Mark Today", "action": "habits:exercise:markToday", "style": "primary"}},
          {"type": "Button", "props": {"label": "Reset", "action": "habits:exercise:reset", "style": "secondary"}}
        ]
      }
    ]
  },
  "state": {
    "currentStreak": 0,
    "days": {}
  },
  "actions": {
    "habits:exercise:markToday": "state.days[today] = true; recalculateStreak(); save()",
    "habits:exercise:reset": "state.days = {}; state.currentStreak = 0; save()"
  }
}

────────────────────────────────────────────────────
Pattern E: MOOD TRACKER (Categorical data)
────────────────────────────────────────────────────

Example: Daily Mood
User request: "track my mood each day"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Mood Tracker", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "MoodGrid",
        "props": {
          "dataSource": "mood:daily",
          "cellSize": 18,
          "cellSpacing": 3,
          "range": "last30days",
          "colorScale": [
            {"value": "great", "color": "#00FF00", "emoji": "smile"},
            {"value": "good", "color": "#90EE90", "emoji": "slight_smile"},
            {"value": "okay", "color": "#FFD700", "emoji": "neutral"},
            {"value": "bad", "color": "#FFA500", "emoji": "worried"},
            {"value": "terrible", "color": "#FF4500", "emoji": "cry"},
            {"value": null, "color": "#2d2d2d", "emoji": ""}
          ],
          "showEmojis": true,
          "tooltip": "{{mood}} on {{date}}"
        }
      },
      {
        "type": "HStack",
        "props": {"spacing": 6},
        "children": [
          {"type": "Button", "props": {"label": "Mood Great", "action": "mood:set:great"}},
          {"type": "Button", "props": {"label": "Mood Good", "action": "mood:set:good"}},
          {"type": "Button", "props": {"label": "Mood Okay", "action": "mood:set:okay"}},
          {"type": "Button", "props": {"label": "Mood Bad", "action": "mood:set:bad"}},
          {"type": "Button", "props": {"label": "Mood Terrible", "action": "mood:set:terrible"}}
        ]
      }
    ]
  }
}

────────────────────────────────────────────────────
Pattern F: WEEKLY GRID (Weeks x Days)
────────────────────────────────────────────────────

Example: Study Hours Per Day
User request: "track study hours last 12 weeks"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Study Hours (Last 12 Weeks)", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "WeeklyGrid",
        "props": {
          "dataSource": "study:hours",
          "cellSize": 16,
          "cellSpacing": 2,
          "rows": 12,
          "columns": 7,
          "columnLabels": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
          "colorScale": [
            {"value": 0, "color": "#1e1e1e"},
            {"value": 1, "color": "#0a4d2e"},
            {"value": 3, "color": "#1a7f50"},
            {"value": 5, "color": "#2db072"},
            {"value": 8, "color": "#40e094"}
          ],
          "tooltip": "{{hours}}h studied on {{date}}"
        }
      }
    ]
  }
}

────────────────────────────────────────────────────
Pattern G: YEAR OVERVIEW (12 months x ~30 days)
────────────────────────────────────────────────────

Example: Water Intake Tracker
User request: "did I drink 8 glasses of water each day this year"

{
  "schema": {
    "type": "VStack",
    "props": {"spacing": 12, "padding": 20},
    "children": [
      {"type": "Text", "props": {"content": "Water Intake 2026", "size": 18, "weight": "bold", "color": "#FFFFFF"}},
      {
        "type": "YearGrid",
        "props": {
          "dataSource": "health:water",
          "cellSize": 10,
          "cellSpacing": 2,
          "year": 2026,
          "colorScale": [
            {"value": 0, "color": "#1e1e1e"},
            {"value": 4, "color": "#1a3d5c"},
            {"value": 6, "color": "#2d5a7b"},
            {"value": 8, "color": "#3a89c9"},
            {"value": 10, "color": "#4fb3ff"}
          ],
          "tooltip": "{{glasses}} glasses on {{date}}",
          "goal": 8,
          "showGoalLine": true
        }
      },
      {"type": "Text", "props": {"content": "Goal: 8 glasses/day", "size": 12, "color": "#FFFFFF", "opacity": 0.6}}
    ]
  }
}

────────────────────────────────────────────────────
HOW THE AI SHOULD UNDERSTAND GRIDS
────────────────────────────────────────────────────

type: "ContributionGrid" | "HourlyGrid" | "MonthlyGrid" | "HabitGrid" | "MoodGrid" | "WeeklyGrid" | "YearGrid"

Common props:
- cellSize: number (size of each cell in pixels)
- cellSpacing: number (gap between cells)
- colorScale: array of {value, color} mappings
- tooltip: template string shown on hover
- dataSource: where to fetch data

Layout props:
- rows: number (for custom grids)
- columns: number (for custom grids)
- rowLabels: array of strings
- columnLabels: array of strings

Data props:
- range: "last7days" | "last30days" | "last90days" | "last365days" | "thisWeek" | "thisMonth" | "thisYear"
- updateFrequency: seconds

Time Granularities:

HOURLY: 24 columns (hours) x 7 rows (days)
- Use for: productivity tracking, app usage, sleep patterns

DAILY: 7 columns (days) x N rows (weeks)
- Use for: habits, exercise, mood, GitHub contributions
- Default: show last 365 days (52 weeks)

WEEKLY: 52 columns (weeks) x N rows (metrics)
- Use for: weekly goals, project milestones

MONTHLY: 12 columns (months) x N rows (years)
- Use for: revenue, sales, annual patterns

YEARLY: 365 cells arranged in calendar format
- Use for: year-at-a-glance view

Color Scales - Common Patterns:

Binary (yes/no):
[
  {"value": false, "color": "#2d2d2d"},
  {"value": true, "color": "#00FF00"}
]

Intensity (GitHub-style):
[
  {"value": 0, "color": "#161b22"},
  {"value": 1, "color": "#0e4429"},
  {"value": 5, "color": "#006d32"},
  {"value": 10, "color": "#26a641"},
  {"value": 20, "color": "#39d353"}
]

Gradient (heat map):
[
  {"value": 0, "color": "#1e1e1e"},
  {"value": 25, "color": "#1a5f3a"},
  {"value": 50, "color": "#2d8f5c"},
  {"value": 75, "color": "#40bf7e"},
  {"value": 100, "color": "#53ff8f"}
]

Categorical (mood, status):
[
  {"value": "excellent", "color": "#00FF00"},
  {"value": "good", "color": "#90EE90"},
  {"value": "average", "color": "#FFD700"},
  {"value": "poor", "color": "#FFA500"},
  {"value": "bad", "color": "#FF4500"}
]

────────────────────────────────────────────────────
REAL-WORLD USE CASES
────────────────────────────────────────────────────

GitHub-style for ANY metric:

"show my workout streak" -> DAILY grid, binary (did/didn't)
"track calories each day" -> DAILY grid, intensity (0-3000 cal)
"meditation minutes daily" -> DAILY grid, intensity (0-60 min)
"code commits this year" -> DAILY grid, intensity (0-50 commits)
"sales calls per day" -> DAILY grid, intensity (0-20 calls)

Hourly patterns:

"when do I get most emails" -> HOURLY grid (24x7), intensity
"productivity by hour" -> HOURLY grid, intensity (focus time)
"sleep schedule" -> HOURLY grid, binary (asleep/awake)
"meetings per hour" -> HOURLY grid, intensity (0-3 meetings)

Monthly overview:

"revenue last 3 years" -> MONTHLY grid (12x3), currency
"expenses by month" -> MONTHLY grid, currency
"team size over time" -> MONTHLY grid, count
"customer acquisition" -> MONTHLY grid, count

Custom tracking:

"reading goals (pages/day)" -> DAILY grid, intensity (0-100 pages)
"water intake (glasses/day)" -> DAILY grid, intensity (0-12 glasses)
"screen time (hours/day)" -> DAILY grid, intensity (0-16 hours)
"steps per day" -> DAILY grid, intensity (0-20000 steps)

────────────────────────────────────────────────────
AI DECISION TREE: Which grid to use?
────────────────────────────────────────────────────

User wants to track over TIME with VISUAL PATTERN?
-> YES? Use a grid/heatmap

What TIME GRANULARITY?
- Track by HOUR -> HourlyGrid (24x7)
- Track by DAY -> ContributionGrid/YearGrid (365 days)
- Track by WEEK -> WeeklyGrid (52 weeks)
- Track by MONTH -> MonthlyGrid (12 months)

What TYPE of data?
- Binary (yes/no, did/didn't) -> Use 2-color scale
- Intensity (how much) -> Use gradient color scale
- Categorical (mood, status) -> Use distinct colors per category

How far back?
- Last week -> 7 days
- Last month -> 30 days
- Last 3 months -> 90 days
- Last year -> 365 days
- Multiple years -> Monthly or Yearly grid

────────────────────────────────────────────────────
CRITICAL: ALWAYS INCLUDE
────────────────────────────────────────────────────

1. Color legend - show what colors mean
2. Tooltips - show exact value on hover
3. Total/stats - show aggregate (total contributions, current streak, etc.)
4. Interactive controls - buttons to mark today, reset, change range
5. State persistence - save data between sessions
6. Proper labels - month names, day names, axis labels

════════════════════════════════════════════════════════════════
