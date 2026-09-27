# MT4 Position Sizer & Basket Manager

An Expert Advisor (EA) for MetaTrader 4 designed to help manage manual trades through risk-based position sizing, visual stop-loss calculations, daily profit targets, session-separated basket management, and carry-over trade tracking.

The EA does not place trades automatically. It is designed to assist with trades opened manually by the trader.

## Features

- Percentage-based or fixed-money risk calculation
- Automatic position-size calculation
- Displays the calculated lot size without artificially capping it to the broker maximum
- Displays the broker's maximum allowed lot size separately
- Calculates estimated required margin
- Displays the current spread
- Visual draggable stop-loss line
- Automatically adds the current spread to the entered stop-loss level
- Automatically adds the current spread after manually moving the stop-loss line
- Does not create or modify the broker's actual stop loss
- Percentage-based or fixed-money daily profit targets
- Tracks realised and floating profit/loss
- Session-separated basket management
- Carry-over trade management
- Automatic basket closing when a session target is reached
- Responsive chart panel
- Manual panel scaling from 50% to 150%
- Separate panel sections for Current Basket, Carry-Over, Daily Performance, and Position Sizer
- Multi-chart/account-wide shared settings
- Panel close button
- Session boundary at 23:30 broker/server time

## How It Works

### Position Sizer

The Position Sizer helps calculate the appropriate trade size before manually opening a position.

1. Select the risk mode:
   - `Percentage` — risk a percentage of the account balance.
   - `Money` — risk a fixed amount of money.

2. Enter the amount or percentage you want to risk.

3. Enter the intended entry price.

4. Enter your intended stop-loss price or move the visual SL line on the chart.

5. The EA automatically adds the current spread to the stop-loss level.

6. Click `CALCULATE`.

The panel displays:

- Risk Amount
- Calculated Size
- Broker Max
- Required Margin
- Current Spread

The calculated size is informational. The EA does not automatically open the trade.

### Visual Stop-Loss Line

The SL line is a calculation tool only.

You can either:

- Type a stop-loss price into the Stop Loss field, or
- Drag the SL line directly on the chart.

The current spread is automatically added to the selected stop-loss level.

The adjusted stop-loss price is then displayed in the Stop Loss field and used for the position-size calculation.

**Important:** The EA does not create, move, or delete the actual broker stop loss on your trade. You remain responsible for setting the real stop loss when placing or managing your position.

### Daily Profit Target

The Daily Performance section allows the target to be specified as either:

- A percentage, or
- A fixed monetary amount.

The remaining target is calculated dynamically using the session's realised profit/loss.

For example:

If the daily target is $100 and $40 has already been realised, the remaining target is $60.

### Trading Sessions

The EA uses a custom trading-day boundary:

**23:30:00 to 23:29:59 broker/server time**

A trade permanently belongs to the session in which it was opened.

For example:

- A trade opened at `23:29:59` belongs to the previous session.
- A trade opened at `23:30:00` belongs to the new session.

This allows the EA to correctly separate trades across trading days.

### Carry-Over Trades

A position that remains open after the session changes becomes a carry-over position.

Carry-over positions remain associated with their original session and original session target.

They are not added to the new day's basket.

This means several session baskets can coexist without mixing their profit targets.

### Automatic Basket Closing

The EA monitors each session basket independently.

When a session's floating profit reaches the remaining target for that session, the EA can close the open positions belonging to that specific session.

Positions belonging to another session are not included in that basket closure.

## Installation

1. Open MetaTrader 4.
2. Click `File > Open Data Folder`.
3. Open:

   `MQL4 > Experts`

4. Copy `PositionSizerBasketManager.mq4` into the `Experts` folder.
5. Open MetaEditor.
6. Open the EA source file.
7. Press `F7` to compile it.
8. Return to MetaTrader 4.
9. Refresh the Expert Advisors list if necessary.
10. Drag the EA onto the chart you want to use.

Under the EA settings:

- Enable `Allow live trading`.
- `Allow DLL imports` is **not required**.
- External expert imports are **not required**.

## Using the Panel

After attaching the EA to a chart:

- Use `-` to make the panel smaller.
- Use `+` to make the panel larger.
- The panel can be manually scaled between 50% and 150%.
- Use `X` to remove the EA and its panel from the current chart.

The `X` button does **not** close your trades.

## Important Notes

This EA is a trade-management and position-sizing tool.

It does not:

- Automatically generate trading signals
- Automatically decide when to enter a trade
- Automatically open trades
- Modify the individual broker stop loss
- Guarantee profits or prevent losses

Position sizing, margin calculations, spread, execution price, slippage, and available leverage may vary depending on the broker and account conditions.

Always test the EA on a demo account before using it with real funds.

## Author

**Tinashe Chimanikire**
