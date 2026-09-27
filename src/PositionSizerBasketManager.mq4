#property strict
#property version   "1.01"
#property description "Position Sizer & Basket Manager for MT4"
#property copyright "Tinashe Chimanikire"


// ============================================================
// SESSION TIME
// ============================================================

datetime GetSessionStartForTime(datetime time_value)
{
   MqlDateTime parts;

   // Break the supplied time into year, month, day,
   // hour, minute and second.
   TimeToStruct(
      time_value,
      parts
   );


   // Set the time to the daily session boundary.
   parts.hour = 23;
   parts.min  = 30;
   parts.sec  = 0;


   datetime today_session_start =
      StructToTime(parts);


   // Before 23:30 means the trade/time belongs
   // to the session that started the previous day.
   if(time_value < today_session_start)
   {
      return(
         today_session_start - 86400
      );
   }


   // At or after 23:30 belongs to today's session.
   return(today_session_start);
}


// ============================================================
// INITIALIZATION
// ============================================================

int OnInit()
{
   Print(
      "Position Sizer & Basket Manager MT4 started."
   );


   datetime current_session =
      GetSessionStartForTime(
         TimeCurrent()
      );


   Print(
      "Current session started: ",
      TimeToString(
         current_session,
         TIME_DATE | TIME_SECONDS
      )
   );


   // Run OnTimer() every second.
   EventSetTimer(1);


   return(INIT_SUCCEEDED);
}


// ============================================================
// CLEANUP
// ============================================================

void OnDeinit(const int reason)
{
   // Stop the timer when the EA is removed.
   EventKillTimer();


   Print(
      "Position Sizer & Basket Manager MT4 stopped."
   );
}


// ============================================================
// PRICE TICK
// ============================================================

void OnTick()
{
   // Price-related functionality will be added later.
}


// ============================================================
// ONE-SECOND TIMER
// ============================================================

void OnTimer()
{
   // Account-wide basket monitoring will be added here.
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
   // Panel controls and SL-line events
   // will be handled here later.
}