#property strict
#property version   "2.00"
#property description "Position Sizer & Basket Manager for MT4"
#property copyright "Tinashe Chimanikire"

// ============================================================
// MT4 POSITION SIZER & BASKET MANAGER
// Session boundary: 23:30 broker/server time
// Individual broker stop losses are NEVER changed by this EA.
// The red SL line is visual/calculation only.
// ============================================================

#define BASE_PANEL_X       12
#define BASE_PANEL_Y       16
#define BASE_PANEL_WIDTH   304
#define BASE_PANEL_HEIGHT  722

#define BASE_LABEL_X       11
#define BASE_VALUE_X       160
#define BASE_UNIT_X        256

#define BASE_FONT_TITLE    6
#define BASE_FONT_SECTION  6
#define BASE_FONT_NORMAL   5
#define BASE_FONT_SMALL    5

double panel_scale        = 1.0;
double auto_panel_scale   = 1.0;
double manual_panel_scale = 1.0;

bool   risk_percentage_mode = true;
bool   daily_percentage_mode = true;
bool   sl_line_enabled = true;

double risk_value = 1.0;
double daily_target_value = 5.0;

string GV_PREFIX;
string GV_RISK_MODE;
string GV_RISK_VALUE;
string GV_DAILY_MODE;
string GV_DAILY_VALUE;
string GV_PANEL_SCALE;
string GV_SL_ENABLED;
string GV_CLOSE_LOCK;


// ============================================================
// BASIC HELPERS
// ============================================================

string AccountCurrencyText()
{
   return AccountCurrency();
}

int PriceDigits()
{
   return (int)MarketInfo(Symbol(), MODE_DIGITS);
}

double PointSize()
{
   return MarketInfo(Symbol(), MODE_POINT);
}

double CurrentAsk()
{
   return MarketInfo(Symbol(), MODE_ASK);
}

double CurrentBid()
{
   return MarketInfo(Symbol(), MODE_BID);
}

datetime GetSessionStartForTime(datetime time_value)
{
   MqlDateTime parts;
   TimeToStruct(time_value, parts);

   parts.hour = 23;
   parts.min  = 30;
   parts.sec  = 0;

   datetime today_start = StructToTime(parts);

   if(time_value < today_start)
      return today_start - 86400;

   return today_start;
}

string SessionKey(datetime session_start, string suffix)
{
   return GV_PREFIX +
          "S_" +
          IntegerToString((int)session_start) +
          "_" +
          suffix;
}


// ============================================================
// GLOBAL VARIABLE KEYS
// ============================================================

void BuildGlobalVariableNames()
{
   GV_PREFIX =
      "PSBM4_" +
      IntegerToString(AccountNumber()) +
      "_";

   GV_RISK_MODE   = GV_PREFIX + "RISK_MODE";
   GV_RISK_VALUE  = GV_PREFIX + "RISK_VALUE";
   GV_DAILY_MODE  = GV_PREFIX + "DAILY_MODE";
   GV_DAILY_VALUE = GV_PREFIX + "DAILY_VALUE";
   GV_PANEL_SCALE = GV_PREFIX + "PANEL_SCALE";
   GV_SL_ENABLED  = GV_PREFIX + "SL_ENABLED";
   GV_CLOSE_LOCK  = GV_PREFIX + "CLOSE_LOCK";
}

void LoadSharedSettings()
{
   if(!GlobalVariableCheck(GV_RISK_MODE))
      GlobalVariableSet(GV_RISK_MODE, 1.0);

   if(!GlobalVariableCheck(GV_RISK_VALUE))
      GlobalVariableSet(GV_RISK_VALUE, 1.0);

   if(!GlobalVariableCheck(GV_DAILY_MODE))
      GlobalVariableSet(GV_DAILY_MODE, 1.0);

   if(!GlobalVariableCheck(GV_DAILY_VALUE))
      GlobalVariableSet(GV_DAILY_VALUE, 5.0);

   if(!GlobalVariableCheck(GV_PANEL_SCALE))
      GlobalVariableSet(GV_PANEL_SCALE, 1.0);

   if(!GlobalVariableCheck(GV_SL_ENABLED))
      GlobalVariableSet(GV_SL_ENABLED, 1.0);

   risk_percentage_mode =
      GlobalVariableGet(GV_RISK_MODE) > 0.5;

   risk_value =
      GlobalVariableGet(GV_RISK_VALUE);

   daily_percentage_mode =
      GlobalVariableGet(GV_DAILY_MODE) > 0.5;

   daily_target_value =
      GlobalVariableGet(GV_DAILY_VALUE);

   manual_panel_scale =
      GlobalVariableGet(GV_PANEL_SCALE);

   sl_line_enabled =
      GlobalVariableGet(GV_SL_ENABLED) > 0.5;

   if(manual_panel_scale < 0.50)
      manual_panel_scale = 0.50;

   if(manual_panel_scale > 1.50)
      manual_panel_scale = 1.50;
}


// ============================================================
// ORDER / SESSION HELPERS
// ============================================================

bool IsSelectedMarketOrder()
{
   int type = OrderType();
   return(type == OP_BUY || type == OP_SELL);
}

int GetSessionOpenOrderCount(datetime session_start)
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      if(GetSessionStartForTime(OrderOpenTime()) == session_start)
         count++;
   }

   return count;
}

double GetSessionFloatingPL(datetime session_start)
{
   double total = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      if(GetSessionStartForTime(OrderOpenTime()) != session_start)
         continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}

int GetCarryOverOrderCount()
{
   datetime current_session =
      GetSessionStartForTime(TimeCurrent());

   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      if(GetSessionStartForTime(OrderOpenTime()) < current_session)
         count++;
   }

   return count;
}

double GetCarryOverFloatingPL()
{
   datetime current_session =
      GetSessionStartForTime(TimeCurrent());

   double total = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      if(GetSessionStartForTime(OrderOpenTime()) >= current_session)
         continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}

int GetCarryOverBasketCount()
{
   datetime current_session =
      GetSessionStartForTime(TimeCurrent());

   datetime sessions[];
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      datetime session_start =
         GetSessionStartForTime(OrderOpenTime());

      if(session_start >= current_session)
         continue;

      bool found = false;

      for(int j = 0; j < count; j++)
      {
         if(sessions[j] == session_start)
         {
            found = true;
            break;
         }
      }

      if(!found)
      {
         ArrayResize(sessions, count + 1);
         sessions[count] = session_start;
         count++;
      }
   }

   return count;
}


// ============================================================
// CLOSED P/L ATTRIBUTED TO ORIGINAL OPEN SESSION
// ============================================================

double GetSessionClosedPL(datetime session_start)
{
   double total = 0.0;

   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      // The order belongs to the session in which it was OPENED,
      // even if it was carried over and closed on a later day.
      if(GetSessionStartForTime(OrderOpenTime()) != session_start)
         continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}

// Used only to reconstruct the actual account balance at a session boundary.
// This uses close time because AccountBalance() changes when a trade closes.
double GetAccountRealizedSince(datetime session_start)
{
   double total = 0.0;

   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      if(OrderCloseTime() < session_start)
         continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}


// ============================================================
// SESSION STATE
// ============================================================

void EnsureSessionState(datetime session_start)
{
   string balance_key = SessionKey(session_start, "START_BAL");
   string mode_key    = SessionKey(session_start, "MODE");
   string target_key  = SessionKey(session_start, "TARGET");

   if(!GlobalVariableCheck(balance_key))
   {
      double start_balance = AccountBalance();

      datetime current_session =
         GetSessionStartForTime(TimeCurrent());

      // For the current session, reconstruct the balance at 23:30
      // from the present balance and realized P/L since the boundary.
      if(session_start == current_session)
         start_balance -= GetAccountRealizedSince(session_start);

      GlobalVariableSet(balance_key, start_balance);
   }

   if(!GlobalVariableCheck(mode_key))
      GlobalVariableSet(
         mode_key,
         daily_percentage_mode ? 1.0 : 0.0
      );

   if(!GlobalVariableCheck(target_key))
      GlobalVariableSet(
         target_key,
         daily_target_value
      );
}

double GetSessionStartBalance(datetime session_start)
{
   EnsureSessionState(session_start);
   return GlobalVariableGet(
      SessionKey(session_start, "START_BAL")
   );
}

bool GetSessionPercentageMode(datetime session_start)
{
   EnsureSessionState(session_start);
   return GlobalVariableGet(
      SessionKey(session_start, "MODE")
   ) > 0.5;
}

double GetSessionTargetInput(datetime session_start)
{
   EnsureSessionState(session_start);
   return GlobalVariableGet(
      SessionKey(session_start, "TARGET")
   );
}

double GetSessionTargetMoney(datetime session_start)
{
   double target = GetSessionTargetInput(session_start);

   if(GetSessionPercentageMode(session_start))
   {
      return
         GetSessionStartBalance(session_start) *
         target /
         100.0;
   }

   return target;
}

double GetSessionRemainingTargetMoney(datetime session_start)
{
   double remaining =
      GetSessionTargetMoney(session_start) -
      GetSessionClosedPL(session_start);

   if(remaining < 0.0)
      remaining = 0.0;

   return remaining;
}

double GetSessionClosedPercent(datetime session_start)
{
   double balance =
      GetSessionStartBalance(session_start);

   if(balance <= 0.0)
      return 0.0;

   return
      GetSessionClosedPL(session_start) /
      balance *
      100.0;
}

void UpdateCurrentSessionTargetFromUI()
{
   datetime current_session =
      GetSessionStartForTime(TimeCurrent());

   EnsureSessionState(current_session);

   GlobalVariableSet(
      SessionKey(current_session, "MODE"),
      daily_percentage_mode ? 1.0 : 0.0
   );

   GlobalVariableSet(
      SessionKey(current_session, "TARGET"),
      daily_target_value
   );
}


// ============================================================
// MULTI-CHART CLOSE LOCK
// ============================================================

bool AcquireCloseLock()
{
   if(!GlobalVariableCheck(GV_CLOSE_LOCK))
      GlobalVariableSet(GV_CLOSE_LOCK, 0.0);

   double now = (double)TimeCurrent();
   double old = GlobalVariableGet(GV_CLOSE_LOCK);

   // Recover a stale lock after 10 seconds.
   if(old > 0.0 && now - old <= 10.0)
      return false;

   return GlobalVariableSetOnCondition(
      GV_CLOSE_LOCK,
      now,
      old
   );
}

void ReleaseCloseLock()
{
   GlobalVariableSet(GV_CLOSE_LOCK, 0.0);
}


// ============================================================
// AUTOMATIC SESSION BASKET CLOSE
// ============================================================

bool CloseSessionOrders(datetime session_start)
{
   bool success = true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      if(GetSessionStartForTime(OrderOpenTime()) != session_start)
         continue;

      int ticket = OrderTicket();
      int type   = OrderType();
      double lots = OrderLots();
      string symbol = OrderSymbol();

      RefreshRates();

      double close_price =
         (type == OP_BUY)
         ? MarketInfo(symbol, MODE_BID)
         : MarketInfo(symbol, MODE_ASK);

      if(close_price <= 0.0)
      {
         success = false;
         continue;
      }

      ResetLastError();

      if(!OrderClose(
         ticket,
         lots,
         close_price,
         30,
         clrNONE
      ))
      {
         Print(
            "PSBM MT4: OrderClose failed. Ticket=",
            ticket,
            " Error=",
            GetLastError()
         );

         success = false;
      }
   }

   return success;
}

void CheckBasketTakeProfit()
{
   datetime sessions[];
   int session_count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(!IsSelectedMarketOrder())
         continue;

      datetime session_start =
         GetSessionStartForTime(OrderOpenTime());

      EnsureSessionState(session_start);

      bool found = false;

      for(int j = 0; j < session_count; j++)
      {
         if(sessions[j] == session_start)
         {
            found = true;
            break;
         }
      }

      if(!found)
      {
         ArrayResize(sessions, session_count + 1);
         sessions[session_count] = session_start;
         session_count++;
      }
   }

   for(int i = 0; i < session_count; i++)
   {
      datetime session_start = sessions[i];

      double remaining =
         GetSessionRemainingTargetMoney(session_start);

      // If realized P/L alone has already met the target,
      // do not automatically close unrelated remaining trades.
      if(remaining <= 0.0)
         continue;

      double floating =
         GetSessionFloatingPL(session_start);

      if(floating < remaining)
         continue;

      if(!AcquireCloseLock())
         return;

      CloseSessionOrders(session_start);
      ReleaseCloseLock();
   }
}


// ============================================================
// POSITION SIZER
// ============================================================

double GetRiskAmount()
{
   if(risk_percentage_mode)
      return AccountBalance() * risk_value / 100.0;

   return risk_value;
}

double NormalizeCalculatedVolume(double volume)
{
   double step =
      MarketInfo(Symbol(), MODE_LOTSTEP);

   if(step <= 0.0)
      return 0.0;

   return MathFloor(volume / step) * step;
}

double GetOneLotLoss(double entry, double stop)
{
   double tick_size =
      MarketInfo(Symbol(), MODE_TICKSIZE);

   double tick_value =
      MarketInfo(Symbol(), MODE_TICKVALUE);

   if(tick_size <= 0.0 || tick_value <= 0.0)
      return 0.0;

   return
      MathAbs(entry - stop) /
      tick_size *
      tick_value;
}

double GetBrokerRequiredMargin(
   int order_type,
   double volume
)
{
   if(volume <= 0.0)
      return 0.0;

   double free_before =
      AccountFreeMargin();

   ResetLastError();

   double free_after =
      AccountFreeMarginCheck(
         Symbol(),
         order_type,
         volume
      );

   // MT4 has no MT5-style OrderCalcMargin(entry price).
   // AccountFreeMarginCheck uses the broker's current margin rules
   // for this account, symbol, direction and volume.
   double required =
      free_before - free_after;

   if(required < 0.0)
      required = 0.0;

   return required;
}

void CalculatePositionSize()
{
   double entry =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_ENTRY_EDIT",
            OBJPROP_TEXT
         )
      );

   double stop =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_SL_EDIT",
            OBJPROP_TEXT
         )
      );

   double entered_risk =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_RISK_EDIT",
            OBJPROP_TEXT
         )
      );

   if(
      entered_risk <= 0.0 ||
      entry <= 0.0 ||
      stop <= 0.0 ||
      entry == stop
   )
      return;

   risk_value = entered_risk;

   GlobalVariableSet(
      GV_RISK_VALUE,
      risk_value
   );

   double risk_amount =
      GetRiskAmount();

   double one_lot_loss =
      GetOneLotLoss(
         entry,
         stop
      );

   if(one_lot_loss <= 0.0)
      return;

   double raw_volume =
      risk_amount /
      one_lot_loss;

   double calculated_volume =
      NormalizeCalculatedVolume(
         raw_volume
      );

   double minimum =
      MarketInfo(
         Symbol(),
         MODE_MINLOT
      );

   double maximum =
      MarketInfo(
         Symbol(),
         MODE_MAXLOT
      );

   int order_type =
      (stop < entry)
      ? OP_BUY
      : OP_SELL;

   double required_margin =
      GetBrokerRequiredMargin(
         order_type,
         calculated_volume
      );

   ObjectSetString(
      0,
      "PSBM_RISK_AMOUNT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(risk_amount, 2)
   );

   ObjectSetString(
      0,
      "PSBM_BROKER_MAX_VALUE",
      OBJPROP_TEXT,
      DoubleToString(maximum, 2)
   );

   ObjectSetString(
      0,
      "PSBM_MARGIN_VALUE",
      OBJPROP_TEXT,
      DoubleToString(required_margin, 2)
   );

   ObjectSetString(
      0,
      "PSBM_MARGIN_UNIT",
      OBJPROP_TEXT,
      AccountCurrencyText()
   );

   if(
      calculated_volume <= 0.0 ||
      calculated_volume < minimum
   )
   {
      ObjectSetString(
         0,
         "PSBM_CALCULATED_VALUE",
         OBJPROP_TEXT,
         "BELOW MIN"
      );

      ObjectSetInteger(
         0,
         "PSBM_CALCULATED_VALUE",
         OBJPROP_COLOR,
         clrOrange
      );
   }
   else
   {
      ObjectSetString(
         0,
         "PSBM_CALCULATED_VALUE",
         OBJPROP_TEXT,
         DoubleToString(calculated_volume, 2)
      );

      ObjectSetInteger(
         0,
         "PSBM_CALCULATED_VALUE",
         OBJPROP_COLOR,
         calculated_volume > maximum
         ? clrOrange
         : C'90,220,140'
      );
   }

   ChartRedraw();
}


// ============================================================
// SPREAD / PRICE
// ============================================================

double GetCurrentSpreadPoints()
{
   double point = PointSize();

   if(point <= 0.0)
      return 0.0;

   return
      (CurrentAsk() - CurrentBid()) /
      point;
}


// ============================================================
// RESPONSIVE PANEL SCALE
// ============================================================

int S(double value)
{
   int result =
      (int)MathRound(
         value * panel_scale
      );

   if(result < 1)
      result = 1;

   return result;
}

int PanelX()
{
   return S(BASE_PANEL_X);
}

int PanelY()
{
   return S(BASE_PANEL_Y);
}

int PanelWidth()
{
   return S(BASE_PANEL_WIDTH);
}

int PanelHeight()
{
   return S(BASE_PANEL_HEIGHT);
}

int LabelX()
{
   return PanelX() + S(BASE_LABEL_X);
}

int ValueX()
{
   return PanelX() + S(BASE_VALUE_X);
}

int UnitX()
{
   return PanelX() + S(BASE_UNIT_X);
}

int FontSize(int base_size)
{
   // 20% larger baseline than the original panel.
   int size =
      (int)MathRound(
         base_size *
         1.20 *
         panel_scale
      );

   if(size < 4)
      size = 4;

   return size;
}

void CalculatePanelScale()
{
   long chart_width =
      ChartGetInteger(
         0,
         CHART_WIDTH_IN_PIXELS,
         0
      );

   long chart_height =
      ChartGetInteger(
         0,
         CHART_HEIGHT_IN_PIXELS,
         0
      );

   if(
      chart_width <= 0 ||
      chart_height <= 0
   )
   {
      auto_panel_scale = 1.0;
      panel_scale = manual_panel_scale;
      return;
   }

   double available_width =
      (double)chart_width - 20.0;

   double available_height =
      (double)chart_height - 20.0;

   double width_scale =
      available_width /
      (double)(
         BASE_PANEL_X +
         BASE_PANEL_WIDTH
      );

   double height_scale =
      available_height /
      (double)(
         BASE_PANEL_Y +
         BASE_PANEL_HEIGHT
      );

   auto_panel_scale =
      MathMin(
         width_scale,
         height_scale
      );

   if(auto_panel_scale > 1.0)
      auto_panel_scale = 1.0;

   if(auto_panel_scale < 0.50)
      auto_panel_scale = 0.50;

   panel_scale =
      auto_panel_scale *
      manual_panel_scale;

   if(panel_scale < 0.25)
      panel_scale = 0.25;

   if(panel_scale > 1.50)
      panel_scale = 1.50;
}


// ============================================================
// OBJECT HELPERS
// ============================================================

void CreateRectangle(
   string name,
   int x,
   int y,
   int width,
   int height,
   color background,
   color border
)
{
   ObjectDelete(0, name);

   if(!ObjectCreate(
      0,
      name,
      OBJ_RECTANGLE_LABEL,
      0,
      0,
      0
   ))
      return;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

void CreateLabel(
   string name,
   string text,
   int x,
   int y,
   int font_size,
   color text_color
)
{
   ObjectDelete(0, name);

   if(!ObjectCreate(
      0,
      name,
      OBJ_LABEL,
      0,
      0,
      0
   ))
      return;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
}

void CreateValue(
   string name,
   string text,
   int y,
   color text_color
)
{
   CreateLabel(
      name,
      text,
      ValueX(),
      y,
      FontSize(BASE_FONT_NORMAL),
      text_color
   );
}

void CreateButton(
   string name,
   string text,
   int x,
   int y,
   int width,
   int height,
   color background
)
{
   ObjectDelete(0, name);

   if(!ObjectCreate(
      0,
      name,
      OBJ_BUTTON,
      0,
      0,
      0
   ))
      return;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize(BASE_FONT_SMALL));
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
}

void CreateEdit(
   string name,
   string text,
   int x,
   int y,
   int width,
   int height
)
{
   ObjectDelete(0, name);

   if(!ObjectCreate(
      0,
      name,
      OBJ_EDIT,
      0,
      0,
      0
   ))
      return;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'42,46,56');
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize(BASE_FONT_SMALL));
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_RIGHT);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
}


// ============================================================
// STOP LOSS LINE
// ============================================================

void DeleteStopLossLine()
{
   ObjectDelete(
      0,
      "PSBM_SL_LINE"
   );
}

void CreateStopLossLine()
{
   if(!sl_line_enabled)
      return;

   double price = 0.0;

   if(ObjectFind(
      0,
      "PSBM_SL_EDIT"
   ) >= 0)
   {
      price =
         StringToDouble(
            ObjectGetString(
               0,
               "PSBM_SL_EDIT",
               OBJPROP_TEXT
            )
         );
   }

   if(price <= 0.0)
      price =
         CurrentAsk() -
         100.0 *
         PointSize();

   price =
      NormalizeDouble(
         price,
         PriceDigits()
      );

   ObjectDelete(
      0,
      "PSBM_SL_LINE"
   );

   if(!ObjectCreate(
      0,
      "PSBM_SL_LINE",
      OBJ_HLINE,
      0,
      0,
      price
   ))
      return;

   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_SELECTED, true);
   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "PSBM_SL_LINE", OBJPROP_HIDDEN, true);
}

void UpdateStopLossFromLine()
{
   if(
      !sl_line_enabled ||
      ObjectFind(
         0,
         "PSBM_SL_LINE"
      ) < 0
   )
      return;

   double price =
      ObjectGetDouble(
         0,
         "PSBM_SL_LINE",
         OBJPROP_PRICE1
      );

   price =
      NormalizeDouble(
         price,
         PriceDigits()
      );

   ObjectSetString(
      0,
      "PSBM_SL_EDIT",
      OBJPROP_TEXT,
      DoubleToString(
         price,
         PriceDigits()
      )
   );
}

void UpdateStopLossLineFromInput()
{
   if(!sl_line_enabled)
      return;

   double price =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_SL_EDIT",
            OBJPROP_TEXT
         )
      );

   if(price <= 0.0)
      return;

   if(ObjectFind(
      0,
      "PSBM_SL_LINE"
   ) < 0)
   {
      CreateStopLossLine();
      return;
   }

   ObjectSetDouble(
      0,
      "PSBM_SL_LINE",
      OBJPROP_PRICE1,
      NormalizeDouble(
         price,
         PriceDigits()
      )
   );
}

void UpdateSLButton()
{
   if(ObjectFind(
      0,
      "PSBM_SL_TOGGLE"
   ) < 0)
      return;

   ObjectSetString(
      0,
      "PSBM_SL_TOGGLE",
      OBJPROP_TEXT,
      sl_line_enabled
      ? "SL LINE ON"
      : "SL LINE OFF"
   );

   ObjectSetInteger(
      0,
      "PSBM_SL_TOGGLE",
      OBJPROP_BGCOLOR,
      sl_line_enabled
      ? C'45,115,75'
      : C'110,55,55'
   );
}


// ============================================================
// PANEL
// ============================================================

void DeletePanelObjects()
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name =
         ObjectName(
            0,
            i,
            -1,
            -1
         );

      if(StringFind(name, "PSBM_") == 0)
         ObjectDelete(0, name);
   }
}

void CreatePanel()
{
   CalculatePanelScale();

   string currency =
      AccountCurrencyText();

   int digits =
      PriceDigits();

   double current_price =
      CurrentAsk();

   int px = PanelX();
   int py = PanelY();
   int pw = PanelWidth();

   CreateRectangle(
      "PSBM_PANEL",
      px,
      py,
      pw,
      PanelHeight(),
      C'25,28,35',
      C'70,75,85'
   );

   CreateRectangle(
      "PSBM_HEADER",
      px,
      py,
      pw,
      S(42),
      C'35,39,48',
      C'35,39,48'
   );

   CreateLabel(
      "PSBM_TITLE",
      "POSITION SIZER & BASKET MANAGER",
      LabelX(),
      py + S(6),
      FontSize(BASE_FONT_TITLE),
      clrWhite
   );

   CreateLabel(
      "PSBM_SUBTITLE",
      "Account-wide manual trade management",
      LabelX(),
      py + S(24),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );

   // Manual scale controls aligned with the management subtitle.
   CreateButton(
      "PSBM_SCALE_MINUS",
      "-",
      px + S(216),
      py + S(22),
      S(18),
      S(17),
      C'55,60,70'
   );

   CreateLabel(
      "PSBM_SCALE_VALUE",
      IntegerToString(
         (int)MathRound(
            manual_panel_scale *
            100.0
         )
      ) + "%",
      px + S(237),
      py + S(25),
      FontSize(BASE_FONT_SMALL),
      C'200,205,215'
   );

   CreateButton(
      "PSBM_SCALE_PLUS",
      "+",
      px + S(276),
      py + S(22),
      S(18),
      S(17),
      C'55,60,70'
   );


   // CURRENT BASKET
   CreateLabel("PSBM_BASKET_TITLE", "CURRENT BASKET",
               LabelX(), py + S(51), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_POSITIONS_LABEL", "Positions",
               LabelX(), py + S(72), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_POSITIONS_VALUE", "0", py + S(72), clrWhite);

   CreateLabel("PSBM_PROFIT_LABEL", "Floating P/L",
               LabelX(), py + S(91), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_PROFIT_VALUE", "0.00", py + S(91), clrWhite);

   CreateLabel("PSBM_TP_VALUE_LABEL", "Remaining Target",
               LabelX(), py + S(110), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_TARGET_VALUE", "0.00", py + S(110), C'90,220,140');
   CreateLabel("PSBM_TARGET_UNIT", currency,
               UnitX(), py + S(111), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_STATUS_LABEL", "Status",
               LabelX(), py + S(129), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_STATUS_VALUE", "WAITING", py + S(129), C'255,190,80');


   // CARRY-OVER
   CreateLabel("PSBM_CARRY_TITLE", "CARRY-OVER",
               LabelX(), py + S(158), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_CARRY_BASKETS_LABEL", "Older Baskets",
               LabelX(), py + S(179), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CARRY_BASKETS_VALUE", "0", py + S(179), clrWhite);

   CreateLabel("PSBM_CARRY_POSITIONS_LABEL", "Positions",
               LabelX(), py + S(198), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CARRY_POSITIONS_VALUE", "0", py + S(198), clrWhite);

   CreateLabel("PSBM_CARRY_PL_LABEL", "Floating P/L",
               LabelX(), py + S(217), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CARRY_PL_VALUE", "0.00", py + S(217), clrWhite);


   // DAILY PERFORMANCE
   CreateLabel("PSBM_DAILY_TITLE", "DAILY PERFORMANCE",
               LabelX(), py + S(246), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_DAILY_MODE_LABEL", "Target Mode",
               LabelX(), py + S(267), FontSize(BASE_FONT_NORMAL), C'190,195,205');

   CreateButton(
      "PSBM_DAILY_MODE_BUTTON",
      daily_percentage_mode ? "Percentage" : "Money",
      ValueX(),
      py + S(263),
      S(88),
      S(19),
      C'55,60,70'
   );

   CreateLabel("PSBM_DAILY_TARGET_LABEL", "Daily Target",
               LabelX(), py + S(291), FontSize(BASE_FONT_NORMAL), C'190,195,205');

   CreateEdit(
      "PSBM_DAILY_TARGET_EDIT",
      DoubleToString(daily_target_value, 2),
      ValueX(),
      py + S(287),
      S(72),
      S(19)
   );

   CreateLabel(
      "PSBM_DAILY_TARGET_UNIT",
      daily_percentage_mode ? "%" : currency,
      UnitX(),
      py + S(291),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );

   CreateLabel("PSBM_CLOSED_PL_LABEL", "Closed P/L",
               LabelX(), py + S(315), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CLOSED_PL_VALUE", "0.00", py + S(315), clrWhite);

   CreateLabel("PSBM_CLOSED_PERCENT_LABEL", "Closed P/L %",
               LabelX(), py + S(334), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CLOSED_PERCENT_VALUE", "0.00%", py + S(334), clrWhite);

   CreateLabel("PSBM_DAILY_REMAINING_LABEL", "Remaining Target",
               LabelX(), py + S(353), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_DAILY_REMAINING_VALUE", "0.00", py + S(353), C'90,220,140');

   CreateLabel("PSBM_DAILY_STATUS_LABEL", "Status",
               LabelX(), py + S(372), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_DAILY_STATUS_VALUE", "ACTIVE", py + S(372), C'255,190,80');


   // POSITION SIZER
   CreateLabel("PSBM_SIZER_TITLE", "POSITION SIZER",
               LabelX(), py + S(402), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_SYMBOL_LABEL", "Symbol",
               LabelX(), py + S(423), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_SYMBOL_VALUE", Symbol(), py + S(423), clrWhite);

   CreateLabel("PSBM_SPREAD_LABEL", "Current Spread",
               LabelX(), py + S(442), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_SPREAD_VALUE", "0.0", py + S(442), clrWhite);
   CreateLabel("PSBM_SPREAD_UNIT", "points",
               UnitX(), py + S(443), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_RISK_MODE_LABEL", "Risk Mode",
               LabelX(), py + S(466), FontSize(BASE_FONT_NORMAL), C'190,195,205');

   CreateButton(
      "PSBM_RISK_MODE_BUTTON",
      risk_percentage_mode ? "Percentage" : "Money",
      ValueX(),
      py + S(462),
      S(88),
      S(19),
      C'55,60,70'
   );

   CreateLabel("PSBM_RISK_LABEL", "Risk",
               LabelX(), py + S(490), FontSize(BASE_FONT_NORMAL), C'190,195,205');

   CreateEdit(
      "PSBM_RISK_EDIT",
      DoubleToString(risk_value, 2),
      ValueX(),
      py + S(486),
      S(72),
      S(19)
   );

   CreateLabel(
      "PSBM_RISK_UNIT",
      risk_percentage_mode ? "%" : currency,
      UnitX(),
      py + S(490),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );

   CreateLabel("PSBM_ENTRY_LABEL", "Entry Price",
               LabelX(), py + S(514), FontSize(BASE_FONT_NORMAL), C'190,195,205');

   CreateEdit(
      "PSBM_ENTRY_EDIT",
      DoubleToString(current_price, digits),
      ValueX(),
      py + S(510),
      S(96),
      S(19)
   );

   double initial_sl =
      current_price -
      100.0 *
      PointSize();

   CreateLabel("PSBM_SL_LABEL", "Stop Loss",
               LabelX(), py + S(538), FontSize(BASE_FONT_NORMAL), C'190,195,205');

   CreateEdit(
      "PSBM_SL_EDIT",
      DoubleToString(initial_sl, digits),
      ValueX(),
      py + S(534),
      S(96),
      S(19)
   );

   CreateButton(
      "PSBM_SL_TOGGLE",
      sl_line_enabled ? "SL LINE ON" : "SL LINE OFF",
      LabelX(),
      py + S(558),
      S(88),
      S(19),
      sl_line_enabled
      ? C'45,115,75'
      : C'110,55,55'
   );

   CreateLabel("PSBM_RISK_AMOUNT_LABEL", "Risk Amount",
               LabelX(), py + S(586), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_RISK_AMOUNT_VALUE", "0.00", py + S(586), clrWhite);
   CreateLabel("PSBM_RISK_AMOUNT_UNIT", currency,
               UnitX(), py + S(587), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_CALCULATED_LABEL", "Calculated Size",
               LabelX(), py + S(610), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CALCULATED_VALUE", "0.00", py + S(610), C'90,220,140');
   CreateLabel("PSBM_CALCULATED_UNIT", "lots",
               UnitX(), py + S(611), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_BROKER_MAX_LABEL", "Broker Max",
               LabelX(), py + S(634), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_BROKER_MAX_VALUE", "0.00", py + S(634), clrWhite);
   CreateLabel("PSBM_BROKER_MAX_UNIT", "lots",
               UnitX(), py + S(635), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_MARGIN_LABEL", "Required Margin",
               LabelX(), py + S(658), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_MARGIN_VALUE", "0.00", py + S(658), clrWhite);
   CreateLabel("PSBM_MARGIN_UNIT", currency,
               UnitX(), py + S(659), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateButton(
      "PSBM_CALCULATE_BUTTON",
      "CALCULATE",
      LabelX(),
      py + S(682),
      pw - S(22),
      S(21),
      C'45,105,155'
   );

   CreateLabel(
      "PSBM_SIGNATURE",
      "By Tinashe Chimanikire",
      LabelX(),
      py + S(708),
      FontSize(BASE_FONT_SMALL),
      C'130,135,145'
   );

   if(sl_line_enabled)
      CreateStopLossLine();

   ChartRedraw();
}

void RebuildResponsivePanel()
{
   // Preserve current editable values before rebuilding.
   string risk_text = "";
   string entry_text = "";
   string sl_text = "";
   string daily_text = "";

   if(ObjectFind(0, "PSBM_RISK_EDIT") >= 0)
      risk_text = ObjectGetString(0, "PSBM_RISK_EDIT", OBJPROP_TEXT);

   if(ObjectFind(0, "PSBM_ENTRY_EDIT") >= 0)
      entry_text = ObjectGetString(0, "PSBM_ENTRY_EDIT", OBJPROP_TEXT);

   if(ObjectFind(0, "PSBM_SL_EDIT") >= 0)
      sl_text = ObjectGetString(0, "PSBM_SL_EDIT", OBJPROP_TEXT);

   if(ObjectFind(0, "PSBM_DAILY_TARGET_EDIT") >= 0)
      daily_text = ObjectGetString(0, "PSBM_DAILY_TARGET_EDIT", OBJPROP_TEXT);

   DeletePanelObjects();
   CreatePanel();

   if(risk_text != "")
      ObjectSetString(0, "PSBM_RISK_EDIT", OBJPROP_TEXT, risk_text);

   if(entry_text != "")
      ObjectSetString(0, "PSBM_ENTRY_EDIT", OBJPROP_TEXT, entry_text);

   if(sl_text != "")
      ObjectSetString(0, "PSBM_SL_EDIT", OBJPROP_TEXT, sl_text);

   if(daily_text != "")
      ObjectSetString(0, "PSBM_DAILY_TARGET_EDIT", OBJPROP_TEXT, daily_text);

   if(sl_line_enabled)
      UpdateStopLossLineFromInput();

   ChartRedraw();
}


// ============================================================
// PANEL UPDATE
// ============================================================

void UpdatePanelBackground(double closed_pl, double target_money)
{
   color panel_color = C'25,28,35';
   color header_color = C'35,39,48';

   if(closed_pl < 0.0)
   {
      panel_color = C'52,29,31';
      header_color = C'72,34,37';
   }
   else if(target_money > 0.0 && closed_pl >= target_money)
   {
      panel_color = C'27,48,35';
      header_color = C'31,67,44';
   }

   ObjectSetInteger(
      0,
      "PSBM_PANEL",
      OBJPROP_BGCOLOR,
      panel_color
   );

   ObjectSetInteger(
      0,
      "PSBM_HEADER",
      OBJPROP_BGCOLOR,
      header_color
   );
}

void UpdatePanel()
{
   datetime current_session =
      GetSessionStartForTime(
         TimeCurrent()
      );

   EnsureSessionState(current_session);

   int positions =
      GetSessionOpenOrderCount(
         current_session
      );

   double floating =
      GetSessionFloatingPL(
         current_session
      );

   double closed =
      GetSessionClosedPL(
         current_session
      );

   double closed_percent =
      GetSessionClosedPercent(
         current_session
      );

   double target_money =
      GetSessionTargetMoney(
         current_session
      );

   double remaining =
      GetSessionRemainingTargetMoney(
         current_session
      );

   int carry_baskets =
      GetCarryOverBasketCount();

   int carry_positions =
      GetCarryOverOrderCount();

   double carry_pl =
      GetCarryOverFloatingPL();

   ObjectSetString(0, "PSBM_POSITIONS_VALUE", OBJPROP_TEXT,
                   IntegerToString(positions));

   ObjectSetString(0, "PSBM_PROFIT_VALUE", OBJPROP_TEXT,
                   DoubleToString(floating, 2));

   ObjectSetString(0, "PSBM_TARGET_VALUE", OBJPROP_TEXT,
                   DoubleToString(remaining, 2));

   ObjectSetString(0, "PSBM_STATUS_VALUE", OBJPROP_TEXT,
                   positions > 0 ? "ACTIVE" : "WAITING");

   ObjectSetString(0, "PSBM_CARRY_BASKETS_VALUE", OBJPROP_TEXT,
                   IntegerToString(carry_baskets));

   ObjectSetString(0, "PSBM_CARRY_POSITIONS_VALUE", OBJPROP_TEXT,
                   IntegerToString(carry_positions));

   ObjectSetString(0, "PSBM_CARRY_PL_VALUE", OBJPROP_TEXT,
                   DoubleToString(carry_pl, 2));

   ObjectSetString(0, "PSBM_CLOSED_PL_VALUE", OBJPROP_TEXT,
                   DoubleToString(closed, 2));

   ObjectSetString(0, "PSBM_CLOSED_PERCENT_VALUE", OBJPROP_TEXT,
                   DoubleToString(closed_percent, 2) + "%");

   ObjectSetString(0, "PSBM_DAILY_REMAINING_VALUE", OBJPROP_TEXT,
                   DoubleToString(remaining, 2));

   ObjectSetString(
      0,
      "PSBM_DAILY_STATUS_VALUE",
      OBJPROP_TEXT,
      closed >= target_money && target_money > 0.0
      ? "TARGET REACHED"
      : "ACTIVE"
   );

   ObjectSetString(
      0,
      "PSBM_SPREAD_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         GetCurrentSpreadPoints(),
         1
      )
   );

   ObjectSetString(
      0,
      "PSBM_DAILY_TARGET_UNIT",
      OBJPROP_TEXT,
      daily_percentage_mode
      ? "%"
      : AccountCurrencyText()
   );

   ObjectSetString(
      0,
      "PSBM_RISK_UNIT",
      OBJPROP_TEXT,
      risk_percentage_mode
      ? "%"
      : AccountCurrencyText()
   );

   UpdatePanelBackground(
      closed,
      target_money
   );

   ChartRedraw();
}


// ============================================================
// INITIALIZATION / CLEANUP
// ============================================================

int OnInit()
{
   BuildGlobalVariableNames();
   LoadSharedSettings();

   datetime current_session =
      GetSessionStartForTime(
         TimeCurrent()
      );

   EnsureSessionState(
      current_session
   );

   CreatePanel();
   UpdatePanel();

   EventSetTimer(1);

   Print(
      "Position Sizer & Basket Manager MT4 started. Session: ",
      TimeToString(
         current_session,
         TIME_DATE | TIME_SECONDS
      )
   );

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   DeletePanelObjects();

   ChartRedraw();

   Print(
      "Position Sizer & Basket Manager MT4 stopped."
   );
}


// ============================================================
// TICK / TIMER
// ============================================================

void OnTick()
{
   // Basket management is timer-driven so it is not dependent
   // only on ticks from this chart's symbol.
}

void OnTimer()
{
   // Pull shared settings changed by another chart instance.
   risk_percentage_mode =
      GlobalVariableGet(GV_RISK_MODE) > 0.5;

   risk_value =
      GlobalVariableGet(GV_RISK_VALUE);

   daily_percentage_mode =
      GlobalVariableGet(GV_DAILY_MODE) > 0.5;

   daily_target_value =
      GlobalVariableGet(GV_DAILY_VALUE);

   CheckBasketTakeProfit();
   UpdatePanel();
}


// ============================================================
// CHART EVENTS
// ============================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam
)
{
   // Re-fit panel when chart/monitor dimensions change.
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RebuildResponsivePanel();
      return;
   }

   // SL line dragged.
   if(
      id == CHARTEVENT_OBJECT_DRAG &&
      sparam == "PSBM_SL_LINE"
   )
   {
      UpdateStopLossFromLine();
      return;
   }

   // Edited text committed.
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == "PSBM_SL_EDIT")
      {
         UpdateStopLossLineFromInput();
         return;
      }

      if(sparam == "PSBM_RISK_EDIT")
      {
         double value =
            StringToDouble(
               ObjectGetString(
                  0,
                  "PSBM_RISK_EDIT",
                  OBJPROP_TEXT
               )
            );

         if(value > 0.0)
         {
            risk_value = value;
            GlobalVariableSet(
               GV_RISK_VALUE,
               risk_value
            );
         }

         return;
      }

      if(sparam == "PSBM_DAILY_TARGET_EDIT")
      {
         double value =
            StringToDouble(
               ObjectGetString(
                  0,
                  "PSBM_DAILY_TARGET_EDIT",
                  OBJPROP_TEXT
               )
            );

         if(value > 0.0)
         {
            daily_target_value = value;

            GlobalVariableSet(
               GV_DAILY_VALUE,
               daily_target_value
            );

            UpdateCurrentSessionTargetFromUI();
            UpdatePanel();
         }

         return;
      }
   }

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;


   // PANEL SCALE -
   if(sparam == "PSBM_SCALE_MINUS")
   {
      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );

      manual_panel_scale -= 0.10;

      if(manual_panel_scale < 0.50)
         manual_panel_scale = 0.50;

      GlobalVariableSet(
         GV_PANEL_SCALE,
         manual_panel_scale
      );

      RebuildResponsivePanel();
      return;
   }


   // PANEL SCALE +
   if(sparam == "PSBM_SCALE_PLUS")
   {
      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );

      manual_panel_scale += 0.10;

      if(manual_panel_scale > 1.50)
         manual_panel_scale = 1.50;

      GlobalVariableSet(
         GV_PANEL_SCALE,
         manual_panel_scale
      );

      RebuildResponsivePanel();
      return;
   }


   // DAILY TARGET MODE
   if(sparam == "PSBM_DAILY_MODE_BUTTON")
   {
      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );

      daily_percentage_mode =
         !daily_percentage_mode;

      GlobalVariableSet(
         GV_DAILY_MODE,
         daily_percentage_mode
         ? 1.0
         : 0.0
      );

      UpdateCurrentSessionTargetFromUI();

      ObjectSetString(
         0,
         "PSBM_DAILY_MODE_BUTTON",
         OBJPROP_TEXT,
         daily_percentage_mode
         ? "Percentage"
         : "Money"
      );

      ObjectSetString(
         0,
         "PSBM_DAILY_TARGET_UNIT",
         OBJPROP_TEXT,
         daily_percentage_mode
         ? "%"
         : AccountCurrencyText()
      );

      UpdatePanel();
      return;
   }


   // RISK MODE
   if(sparam == "PSBM_RISK_MODE_BUTTON")
   {
      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );

      risk_percentage_mode =
         !risk_percentage_mode;

      GlobalVariableSet(
         GV_RISK_MODE,
         risk_percentage_mode
         ? 1.0
         : 0.0
      );

      ObjectSetString(
         0,
         "PSBM_RISK_MODE_BUTTON",
         OBJPROP_TEXT,
         risk_percentage_mode
         ? "Percentage"
         : "Money"
      );

      ObjectSetString(
         0,
         "PSBM_RISK_UNIT",
         OBJPROP_TEXT,
         risk_percentage_mode
         ? "%"
         : AccountCurrencyText()
      );

      ChartRedraw();
      return;
   }


   // STOP LOSS LINE ON/OFF
   if(sparam == "PSBM_SL_TOGGLE")
   {
      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );

      sl_line_enabled =
         !sl_line_enabled;

      GlobalVariableSet(
         GV_SL_ENABLED,
         sl_line_enabled
         ? 1.0
         : 0.0
      );

      if(sl_line_enabled)
         CreateStopLossLine();
      else
         DeleteStopLossLine();

      UpdateSLButton();
      ChartRedraw();
      return;
   }


   // POSITION SIZE CALCULATION
   if(sparam == "PSBM_CALCULATE_BUTTON")
   {
      ObjectSetInteger(
         0,
         sparam,
         OBJPROP_STATE,
         false
      );

      CalculatePositionSize();
      return;
   }
}
