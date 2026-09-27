# MT4 Position Sizer & Basket Manager

An Expert Advisor (EA) for MetaTrader 4 designed to help manage manual trades through risk-based position sizing, visual stop-loss calculations, daily profit targets, session-separated basket management, and multi-day carry-over trade tracking.

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
- Multi-day carry-over trade management
- Automatic basket closing when a session target is reached
- Responsive chart panel
- Manual panel scaling from 50% to 150%
- Separate panel sections for Current Basket, Carry-Over, Daily Performance, and Position Sizer
- Multi-chart/account-wide shared settings
- Panel close button
- Session boundary at 23:30 broker/server time

## How It Works

### Position Sizer

The Position Sizer helps calculate the appropriate trade size before manually opening a trade.

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

The spread is added once when the stop-loss level is entered or moved. Resizing the chart or changing the panel scale does not repeatedly add the spread.

**Important:** The EA does not create, move, or delete the actual broker stop loss on your trade. You remain responsible for setting the real stop loss when placing or managing your trade.

### Daily Profit Target

The Daily Performance section allows the target to be specified as either:

- A percentage, or
- A fixed monetary amount.

The remaining target is calculated dynamically using the session's realised profit/loss.

For example:

If the daily target is $100 and $40 has already been realised, the remaining target is $60.

The EA continues monitoring the remaining amount rather than restarting the full target after each closed trade.

### Trading Sessions

The EA uses a custom trading-day boundary:

**23:30:00 to 23:29:59 broker/server time**

A trade permanently belongs to the session in which it was originally opened.

For example:

- A trade opened at `23:29:59` belongs to the previous session.
- A trade opened at `23:30:00` belongs to the new session.

This allows the EA to separate trades and profit targets across trading days.

A new session does not absorb trades that were opened during an earlier session.

### Carry-Over Trades

A trade that remains open after the session changes becomes a carry-over trade.

Carry-over trades remain permanently associated with their original session and original session target.

They are not transferred into the new day's basket.

A carry-over trade can remain open for multiple days. Regardless of whether it remains open for two days, five days, or longer, it continues to belong to the session in which it was originally opened.

For example:

```text
Monday Basket
└── Trade A still open

Tuesday Basket
├── Trade B
└── Trade C

Wednesday Basket
└── Trade D
```

If Trade A remains open until Thursday, it is still part of the Monday basket.

This means several session baskets can coexist without mixing their trades or profit targets.

The number of active baskets therefore depends on the number of sessions that still contain open trades — not simply on how many days the EA has been running.

Once all trades belonging to an old session are closed, that session no longer has an active carry-over basket.

### Automatic Basket Closing

The EA monitors each session basket independently.

Each basket retains its own:

- Original session
- Profit target
- Realised profit/loss
- Remaining target
- Open trades

When a session's floating profit reaches the remaining target for that session, the EA can close the open trades belonging to that specific session.

Trades belonging to another session are not included in that basket closure.

For example:

```text
Monday Basket
Target remaining: $40
Floating P/L:     $45
Result:            Monday trades can be closed

Tuesday Basket
Target remaining: $70
Floating P/L:     $20
Result:            Tuesday trades remain open
```

Even though both baskets exist at the same time, reaching the Monday target does not cause the Tuesday trades to be closed.

### Realised Profit/Loss Attribution

Closed profit/loss is associated with the session in which the trade was originally opened.

For example:

If a trade is opened on Monday but closes on Wednesday, its realised profit/loss still belongs to the Monday session.

This prevents profits or losses from old carry-over trades from incorrectly changing the current day's basket.

## Installation

1. Open MetaTrader 4.
2. Click `File > Open Data Folder`.
3. Open:

   `MQL4 > Experts`

4. Copy `PositionSizerBasketManager.mq4` into the `Experts` folder.
5. Open MetaEditor.
6. Open the EA source file.
7. Press `F7` to compile it.
8. Confirm that the file compiles successfully.
9. Return to MetaTrader 4.
10. Refresh the Expert Advisors list if necessary.
11. Drag the EA onto the chart you want to use.

Under the EA settings:

- Enable `Allow live trading`.
- Make sure automated trading is enabled in MetaTrader 4.
- `Allow DLL imports` is **not required**.
- External expert imports are **not required**.

## Using the Panel

After attaching the EA to a chart, the panel provides separate sections for:

- Current Basket
- Carry-Over
- Daily Performance
- Position Sizer

### Panel Scaling

Use:

- `-` to make the panel smaller.
- `+` to make the panel larger.

The panel can be manually scaled between **50% and 150%**.

The EA initially attempts to fit the panel to the available chart size. Once the manual scaling controls are used, the selected manual scale takes priority.

### Closing the Panel

Use `X` to remove the EA and its panel from the current chart.

The `X` button does **not** close your trades.

It only removes the EA from that chart.

## Multi-Chart Use

The EA can be attached to multiple charts.

Account-level basket and session information is shared so that separate EA instances can work with the same account state.

This allows the trader to monitor and manage manual positions across multiple symbols while maintaining the same session-based basket structure.

## Important Notes

This EA is a trade-management and position-sizing tool.

It does not:

- Automatically generate trading signals
- Automatically decide when to enter a trade
- Automatically open trades
- Modify the individual broker stop loss
- Combine trades from different trading sessions into one basket
- Transfer an old carry-over trade into the current day's basket
- Guarantee profits or prevent losses

The visual SL line is used only for risk and position-size calculations.

The calculated position size is informational and may be larger than the broker's permitted maximum lot size. The broker maximum is displayed separately so the trader can compare the calculated requirement with the broker's trading limits.

Required margin in MetaTrader 4 is estimated using the account and broker information available through MT4. Actual margin requirements can vary at execution.

Position sizing, margin requirements, spread, execution price, slippage, commissions, swaps, leverage, and trading conditions may vary depending on the broker, account type, symbol, and current market conditions.

Basket closing also depends on the broker successfully accepting the individual trade-close requests.

Always test the EA thoroughly on a demo account before using it with real funds.

## Author

**Tinashe Chimanikire**
