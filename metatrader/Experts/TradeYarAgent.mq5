// TradeYar MT5 Agent â€” deliberately READ ONLY
#property strict
#property version "0.20"
input bool ExportQuotesToCommonFiles = false;
input int ExportIntervalSeconds = 5;
datetime lastExport = 0;
int OnInit() {
   Print("TradeYar MT5 read-only bridge. Order execution is disabled.");
   return(INIT_SUCCEEDED);
}
void OnTick() {
   if(!ExportQuotesToCommonFiles) return;
   if(ExportIntervalSeconds < 1 || TimeCurrent() - lastExport < ExportIntervalSeconds) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   int f = FileOpen("TradeYarTicks.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(f == INVALID_HANDLE) { Print("Snapshot write failed: ",GetLastError()); return; }
   FileWrite(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,
             DoubleToString(tick.bid,_Digits),DoubleToString(tick.ask,_Digits));
   FileClose(f);
   lastExport = TimeCurrent();
}
void OnDeinit(const int reason) { Print("TradeYar read-only agent stopped"); }