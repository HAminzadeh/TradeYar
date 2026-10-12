// TradeYar MT5 Agent - starter scaffold
#property strict
#property version "0.10"

input bool EnableLiveTrading = false;

int OnInit()
{
   Print("TradeYar MT5 Agent initialized");
   Print("Real order execution is disabled");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   // Future: receive analysis and draw chart overlays.
   // No real orders are submitted.
}

void OnDeinit(const int reason)
{
   Print("TradeYar Agent stopped");
}