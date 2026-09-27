#property strict
#property version   "1.00"
#property description "Position Sizer & Basket Manager for MT4"
#property copyright "Tinashe Chimanikire"


// ============================================================
// INITIALIZATION
// ============================================================

int OnInit()
{
   Print("Position Sizer & Basket Manager MT4 started.");

   // Run OnTimer() once every second.
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}


// ============================================================
// CLEANUP
// ============================================================

void OnDeinit(const int reason)
{
   // Stop the one-second timer.
   EventKillTimer();

   Print("Position Sizer & Basket Manager MT4 stopped.");
}


// ============================================================
// PRICE TICK
// ============================================================

void OnTick()
{
   // Trading and basket logic will be added later.
}


// ============================================================
// ONE-SECOND TIMER
// ============================================================

void OnTimer()
{
   // Account-wide basket monitoring will eventually run here.
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
   // Panel buttons, input boxes and the SL line
   // will eventually be handled here.
}