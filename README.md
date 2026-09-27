# MT4 Position Sizer & Basket Manager

A MetaTrader 4 Expert Advisor for position sizing, panel-based trade execution, risk management, daily profit targets, and multi-session basket management.

Developed by **Tinashe Chimanikire**.

## Features

### Position Sizer

The EA calculates position size using either:

- Percentage risk
- Fixed-money risk

The calculation uses:

- Current executable market price
- Selected Stop Loss
- MT4 tick size
- MT4 tick value
- Broker lot step
- Broker minimum and maximum lot sizes

The panel displays:

- Current Spread
- Risk Amount
- Calculated Size
- Broker Max
- Required Margin

The calculated size is shown independently from the broker maximum.

### Panel Trade Execution

Trades can be executed directly from the EA using:

- BUY
- SELL

For panel-executed trades:

- BUY uses the current Ask price.
- SELL uses the current Bid price.
- The selected Stop Loss becomes the actual broker Stop Loss.
- Position size is recalculated immediately before execution using the latest market price.
- The EA does not intentionally draw BUY, SELL, or exit arrows on the chart.

This helps keep the chart clean while retaining the custom Stop Loss line.

### Stop Loss Line

The EA provides a draggable red Stop Loss line.

The Stop Loss can be changed by:

- Dragging the SL line
- Entering the SL price directly into the panel

The SL field represents the actual broker Stop Loss price for trades executed from the panel.

The SL line can be switched ON or OFF.

### Cost-Aware Risk

The EA includes a:

`RISK COSTS: ON / OFF`

control.

When enabled, the position-size calculation can include an estimated round-trip commission in the planned trade risk.

The current commission estimate was calibrated using an FTMO ETHUSD test trade.

Because commission structures can vary between brokers, accounts, and symbols, the estimate may require adjustment for other trading environments.

### Required Margin

The panel displays the estimated margin required for the calculated trade size.

MT4's broker margin rules are queried using `AccountFreeMarginCheck()`.

This allows the trader to compare the planned position with available account margin before execution.

### Daily Target

The daily target can be configured as either:

- Percentage
- Fixed money

The remaining target is dynamically calculated from the session's realized profit or loss.

### Trading Session

The EA uses a custom trading-day boundary:

**23:30:00 → 23:29:59 broker/server time**

For example:

- A trade opened at 23:29:59 belongs to the previous session.
- A trade opened at 23:30:00 belongs to the new session.

### Multi-Day and Carry-Over Positions

Every position permanently belongs to the trading session in which it was originally opened.

For example, if a trade is opened on Monday and remains open until Thursday, it remains part of Monday's basket.

It does not become part of Tuesday's, Wednesday's, or Thursday's basket.

Multiple session baskets can therefore coexist.

The Carry-Over section displays positions belonging to older sessions separately from the current session.

### Session Profit Attribution

Closed profit and loss is attributed to the session in which the position was originally opened, not the session in which it was closed.

Session calculations include:

- Trading profit/loss
- Swap
- Commission

### Automatic Basket Closing

Each session has its own independent target.

When an active session basket reaches its remaining target, the EA can automatically close the positions belonging to that session.

Positions belonging to other sessions are not included in that basket close.

This prevents a new day's trades from being mixed with older carry-over positions.

### Multi-Chart Operation

The EA can be attached to multiple MT4 charts.

Shared settings use MT4 Terminal Global Variables so important account-wide settings can be synchronized between EA instances.

A close lock helps prevent multiple chart instances from attempting the same automatic basket close simultaneously.

### Responsive Panel

The panel automatically adapts to the chart dimensions.

Manual scaling is also available using:

- `-`
- `+`

Each click changes the manual panel scale by **1 percentage point**.

The supported manual scale range is:

**50% – 150%**

### Remove EA

The `X` button removes the EA and its panel from the current chart.

It does **not** close open trading positions.

## Installation

1. Open MetaTrader 4.
2. Select **File → Open Data Folder**.
3. Open `MQL4`.
4. Open `Experts`.
5. Copy `PositionSizerBasketManager.mq4` into the Experts folder.
6. Open MetaEditor.
7. Compile the EA.
8. Return to MT4.
9. Attach the EA to the required chart.
10. Enable **AutoTrading**.
11. Enable **Allow live trading** in the EA properties if panel trade execution is required.

## Important Notes

The EA is a trading and risk-management tool. Position-size calculations depend on the symbol information supplied by the broker.

Tick value, tick size, commission, margin requirements, spreads, execution prices, and slippage can vary by broker and symbol.

The cost-aware risk calculation uses an estimated commission value and should be verified against the broker's actual commission structure before relying on it for live risk limits.

Always test new versions on a demo account before using them on a live or funded account.

## Current Version

**v2.13**

Current functionality includes:

- Direct BUY/SELL execution
- Actual broker Stop Loss
- Cost-aware risk sizing
- Required Margin display
- Clean chart execution without EA-generated entry/exit arrows
- 1% manual panel scaling
- Daily targets
- Multi-day carry-over baskets
- Session-specific automatic basket closing

## Author

**Tinashe Chimanikire**
