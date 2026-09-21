#property copyright "NAT Growth Lab"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

// Expert Advisor based on the TradingView AMD Scalping Strategy.
// Test in the MT5 Strategy Tester / demo account before using a live account.
input bool            InpEnableTrading = true;      // On/off is controlled from the chart buttons
input ulong           InpMagicNumber = 26092026;
input ENUM_TIMEFRAMES InpAMDTimeframe = PERIOD_H4;
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_M15;
input bool            InpOnlyM1M5 = true;
input bool            InpTradeAllHours = true;       // Still subject to the broker's symbol availability
input int             InpSessionStartHour = 0;       // Broker server time
input int             InpSessionEndHour = 23;        // Broker server time
input int             InpMaxSpreadPoints = 200;
input bool            InpIgnoreSpreadFilter = true;
input double          InpRiskPercent = 0.25;         // Equity risk per trade
input bool            InpUseCashRisk = true;
input double          InpMaxLossUSD = 1.50;
input bool            InpUseCashTakeProfit = false; // Exit profitable positions at market instead of placing a TP
input double          InpTakeProfitUSD = 0.00;
input bool            InpOpenOnActivation = false;   // Require a confirmed pullback setup
input bool            InpUseFixedLot = true;
input double          InpFixedLot = 0.01;
input int             InpMaxOpenPositions = 0;       // 0 = no EA position cap (hedging accounts)
input int             InpOrdersPerSignal = 1;
input int             InpMaxTradesPerDay = 0;        // 0 = no EA daily entry cap
input double          InpMaxTotalRiskUSD = 0.00;      // 0 = no EA open-risk cap
input double          InpMaxPerTradeRiskUSD = 0.00;   // 0 = no EA per-trade risk cap
input double          InpMaxDailyLossUSD = 0.00;      // 0 = no EA daily-loss cap
input bool            InpEvaluateEveryTick = true;
input int             InpMinimumSecondsBetweenEntries = 1;
input int             InpReentryCooldownSeconds = 1;
input int             InpMaxEntriesPerCandle = 0;    // 0 = no EA limit per candle (demo mode)
input bool            InpOneActiveTradeAtATime = true;
input int             InpMaxHoldSeconds = 0;          // 0 = no time-based exit
input bool            InpExitOnMicroReversal = false;
input double          InpFastLossExitUSD = 0.0;      // Broker-side stop is the hard loss limit
input double          InpQuickProfitCloseUSD = 1.00;
input double          InpBreakEvenTriggerUSD = 0.50;
input double          InpBreakEvenLockUSD = 0.10;    // Approximate profit to lock above/below entry
input bool            InpUseFastDirectionFallback = false;
input bool            InpUseCandleDirectionEntries = false;
input bool            InpCandleDirectionOverridesBias = false;
input bool            InpUseRetracementEntries = true;
input int             InpRetracementBufferPoints = 10;
input bool            InpExitOnLosingCandleFlip = false;
input bool            InpExitOnCandleDirectionFlip = false;
input bool            InpExitOnRetracementFailure = true;
input bool            InpShowStatusPanel = true;
input bool            InpBypassVolatilityFilter = false;
input int             InpSwingLeftBars = 3;
input int             InpSwingRightBars = 3;
input int             InpCooldownBars = 1;
input int             InpATRPeriod = 14;
input double          InpMinRiskATR = 0.75;
input int             InpEntryEMAPeriod = 20;
input int             InpHTFFastEMAPeriod = 50;
input int             InpHTFSlowEMAPeriod = 200;
input double          InpMinimumRelativeATR = 0.80;
input int             InpWickToleranceTicks = 0;
input int             InpMinimumStructureConfirmations = 1;
input int             InpMinimumAMDConfirmations = 2;
input bool            InpEnableLongs = true;
input bool            InpEnableShorts = true;
input bool            InpEnableAMDShorts = false;
input double          InpTP1R = 1.0;
input double          InpTP2R = 1.5;
input double          InpTP3R = 1.5;
input ulong           InpDeviationPoints = 100;
input int             InpStopSafetyBufferPoints = 50;
input int             InpMaxRequoteRetries = 3;
input ulong           InpRequoteDeviationStepPoints = 50;

CTrade trade;
int atrHandle = INVALID_HANDLE;
int entryEmaHandle = INVALID_HANDLE;
int htfFastHandle = INVALID_HANDLE;
int htfSlowHandle = INVALID_HANDLE;
datetime lastClosedBar = 0;
datetime lastSignalTime = 0;
datetime lastEntryTime = 0;
datetime lastExitTime = 0;
datetime trackedEntryCandle = 0;
int entriesThisCandle = 0;
datetime processedH4Time = 0;
double amdTargetLow = 0.0;
bool amdTargetActive = false;
bool tp1Done = false;
bool tp2Done = false;
int tradesToday = 0;
int trackedDayKey = -1;
string lastStatus = "Loading";
bool runtimeTradingEnabled = true;
string pauseButtonName = "AMDScalper_PAUSE";
string resumeButtonName = "AMDScalper_RESUME";

struct DailyStats
{
   double profit;
   double loss;
   int winners;
   int losers;
};

struct DrawdownStats
{
   double current;
   double currentPercent;
   double maximum;
   double maximumPercent;
};

int OwnPositionCount();
int EffectiveMaxPositions();
double TotalOpenRisk();
double DailyRealizedLoss();
void GetDailyStats(DailyStats &stats);
void GetDrawdownStats(DrawdownStats &stats);
void CreateControlButtons();
void DeleteControlButtons();

void SetStatus(const string status)
{
   lastStatus=status;
   if(!InpShowStatusPanel) return;
   DailyStats stats;
   DrawdownStats drawdown;
   GetDailyStats(stats);
   GetDrawdownStats(drawdown);
   string tradeCap=InpMaxTradesPerDay<=0 ? "unlimited" : IntegerToString(InpMaxTradesPerDay);
   bool isHedging=AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   string positionCap=InpMaxOpenPositions<=0 ? (isHedging ? "unlimited" : "1 (broker netting)") : IntegerToString(EffectiveMaxPositions());
   string riskCap=InpMaxTotalRiskUSD<=0.0 ? "unlimited" : "$"+DoubleToString(InpMaxTotalRiskUSD,2);
   string lossCap=InpMaxDailyLossUSD<=0.0 ? "unlimited" : "$"+DoubleToString(InpMaxDailyLossUSD,2);
   Comment("AMD Scalping EA\nBot: ",runtimeTradingEnabled ? "ACTIVE" : "PAUSED","\n",status,"\nSymbol: ",_Symbol,"  TF: ",EnumToString(_Period),"\nSymbol positions: ",IntegerToString(OwnPositionCount())," / ",positionCap,"\nGlobal open risk: $",DoubleToString(TotalOpenRisk(),2)," / ",riskCap,"\nDaily profit: $",DoubleToString(stats.profit,2),"  |  Daily loss: $",DoubleToString(stats.loss,2)," / ",lossCap,"\nWinners: ",IntegerToString(stats.winners),"  |  Losers: ",IntegerToString(stats.losers),"\nCurrent DD: $",DoubleToString(drawdown.current,2)," (",DoubleToString(drawdown.currentPercent,2),"%)  |  Max DD: $",DoubleToString(drawdown.maximum,2)," (",DoubleToString(drawdown.maximumPercent,2),"%)\nTrades today (symbol): ",IntegerToString(tradesToday)," / ",tradeCap);
}

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   atrHandle=iATR(_Symbol,_Period,InpATRPeriod);
   entryEmaHandle=iMA(_Symbol,_Period,InpEntryEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   htfFastHandle=iMA(_Symbol,InpTrendTimeframe,InpHTFFastEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   htfSlowHandle=iMA(_Symbol,InpTrendTimeframe,InpHTFSlowEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || entryEmaHandle==INVALID_HANDLE || htfFastHandle==INVALID_HANDLE || htfSlowHandle==INVALID_HANDLE)
   {
      Print("Could not create indicator handles.");
      return(INIT_FAILED);
   }
   runtimeTradingEnabled=InpEnableTrading;
   CreateControlButtons();
   SetStatus(InpEnableTrading ? "Loaded — waiting for a price tick" : "Disabled — set InpEnableTrading=true");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(entryEmaHandle!=INVALID_HANDLE) IndicatorRelease(entryEmaHandle);
   if(htfFastHandle!=INVALID_HANDLE) IndicatorRelease(htfFastHandle);
   if(htfSlowHandle!=INVALID_HANDLE) IndicatorRelease(htfSlowHandle);
   DeleteControlButtons();
   if(InpShowStatusPanel) Comment("");
}

void CreateButton(const string name,const string text,const int y,color background)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,104);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,24);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void CreateControlButtons()
{
   CreateButton(pauseButtonName,"PAUSE BOT",14,clrFireBrick);
   CreateButton(resumeButtonName,"RESUME BOT",44,clrForestGreen);
}

void DeleteControlButtons()
{
   ObjectDelete(0,pauseButtonName);
   ObjectDelete(0,resumeButtonName);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(sparam==pauseButtonName)
   {
      runtimeTradingEnabled=false;
      SetStatus("Paused from chart control — open positions remain protected");
   }
   else if(sparam==resumeButtonName)
   {
      if(!InpEnableTrading) SetStatus("Cannot resume — InpEnableTrading is false");
      else
      {
         runtimeTradingEnabled=true;
         SetStatus("Resumed from chart control — waiting for opportunity");
      }
   }
}

bool BufferValue(const int handle,const int shift,double &value)
{
   double data[];
   if(CopyBuffer(handle,0,shift,1,data)!=1) return(false);
   value=data[0];
   return(true);
}

bool IsSwingHigh(const MqlRates &rates[],const int index,const int count)
{
   for(int n=1;n<=InpSwingLeftBars;n++) if(index-n<0 || rates[index].high<=rates[index-n].high) return(false);
   for(int n=1;n<=InpSwingRightBars;n++) if(index+n>=count || rates[index].high<=rates[index+n].high) return(false);
   return(true);
}

bool IsSwingLow(const MqlRates &rates[],const int index,const int count)
{
   for(int n=1;n<=InpSwingLeftBars;n++) if(index-n<0 || rates[index].low>=rates[index-n].low) return(false);
   for(int n=1;n<=InpSwingRightBars;n++) if(index+n>=count || rates[index].low>=rates[index+n].low) return(false);
   return(true);
}

double LatestSwingHigh(const MqlRates &rates[],const int count)
{
   int start=InpSwingRightBars+1;
   int finish=MathMin(count-InpSwingLeftBars-1,300);
   for(int i=start;i<=finish;i++) if(IsSwingHigh(rates,i,count)) return(rates[i].high);
   return(0.0);
}

double LatestSwingLow(const MqlRates &rates[],const int count)
{
   int start=InpSwingRightBars+1;
   int finish=MathMin(count-InpSwingLeftBars-1,300);
   for(int i=start;i<=finish;i++) if(IsSwingLow(rates,i,count)) return(rates[i].low);
   return(0.0);
}

bool InTradeSession()
{
   if(InpTradeAllHours) return(true);
   MqlDateTime now;
   TimeToStruct(TimeCurrent(),now);
   if(InpSessionStartHour<=InpSessionEndHour) return(now.hour>=InpSessionStartHour && now.hour<InpSessionEndHour);
   return(now.hour>=InpSessionStartHour || now.hour<InpSessionEndHour);
}

bool IsScalpingTimeframe()
{
   return(!InpOnlyM1M5 || _Period==PERIOD_M1 || _Period==PERIOD_M5);
}

bool HasOwnPosition(ulong &ticket)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong currentTicket=PositionGetTicket(i);
      if(currentTicket==0 || !PositionSelectByTicket(currentTicket)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
      {
         ticket=currentTicket;
         return(true);
      }
   }
   ticket=0;
   return(false);
}

int OwnPositionCount()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) count++;
   }
   return(count);
}

int EffectiveMaxPositions()
{
   long mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mode!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return(1);
   if(InpMaxOpenPositions<=0) return(1000); // No EA cap; broker margin and platform limits still apply.
   return(MathMax(1,InpMaxOpenPositions));
}

void RefreshTradeDay()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(),now);
   int dayKey=now.year*1000+now.day_of_year;
   if(dayKey!=trackedDayKey)
   {
      trackedDayKey=dayKey;
      tradesToday=0;
   }
}

void RefreshCandleEntryCount()
{
   datetime currentCandle=iTime(_Symbol,_Period,0);
   if(currentCandle<=0) return;
   if(currentCandle!=trackedEntryCandle)
   {
      trackedEntryCandle=currentCandle;
      entriesThisCandle=0;
   }
}

bool TradeResultOK()
{
   uint code=trade.ResultRetcode();
   if(code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_PLACED) return(true);
   Print("Trade request rejected: ",trade.ResultRetcodeDescription());
   return(false);
}

bool IsRetriablePriceResult(const uint code)
{
   return(code==TRADE_RETCODE_REQUOTE || code==TRADE_RETCODE_PRICE_CHANGED || code==TRADE_RETCODE_PRICE_OFF);
}

bool NormalizeOrderStops(const bool isBuy,double &stop,double &target)
{
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)) return(false);
   long stopsLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double minimumDistance=(MathMax((double)stopsLevel,(double)freezeLevel)+MathMax(1,InpStopSafetyBufferPoints))*_Point;
   if(isBuy)
   {
      stop=MathMin(stop,quote.bid-minimumDistance);
      if(target>0.0) target=MathMax(target,quote.bid+minimumDistance);
   }
   else
   {
      stop=MathMax(stop,quote.ask+minimumDistance);
      if(target>0.0) target=MathMin(target,quote.ask-minimumDistance);
   }
   stop=NormalizeDouble(stop,_Digits);
   if(target>0.0) target=NormalizeDouble(target,_Digits);
   return(isBuy ? (stop<quote.bid && (target==0.0 || target>quote.bid)) : (stop>quote.ask && (target==0.0 || target<quote.ask)));
}

bool SendOrderWithRetries(const bool isBuy,const double volume,double &stop,double &target)
{
   for(int attempt=0;attempt<=InpMaxRequoteRetries;attempt++)
   {
      if(!NormalizeOrderStops(isBuy,stop,target))
      {
         SetStatus("Blocked — cannot place valid broker stops");
         break;
      }
      trade.SetDeviationInPoints(InpDeviationPoints+(ulong)attempt*InpRequoteDeviationStepPoints);
      bool sent=isBuy ? trade.Buy(volume,_Symbol,0.0,stop,target,"AMD scalp long") : trade.Sell(volume,_Symbol,0.0,stop,target,"AMD scalp short");
      uint code=trade.ResultRetcode();
      if(sent && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_PLACED))
      {
         trade.SetDeviationInPoints(InpDeviationPoints);
         return(true);
      }
      if(!IsRetriablePriceResult(code))
      {
         Print("Trade request rejected: ",trade.ResultRetcodeDescription());
         break;
      }
      Print("Price changed; retrying order ",IntegerToString(attempt+1)," of ",IntegerToString(InpMaxRequoteRetries));
   }
   trade.SetDeviationInPoints(InpDeviationPoints);
   return(false);
}

int VolumeDigits()
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   int digits=0;
   while(step<1.0 && digits<8) { step*=10.0; digits++; }
   return(digits);
}

double NormalizeVolume(const double volume)
{
   double minVolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxVolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0) return(0.0);
   double normalized=MathFloor(volume/step)*step;
   normalized=MathMax(minVolume,MathMin(normalized,maxVolume));
   return(NormalizeDouble(normalized,VolumeDigits()));
}

double RiskBasedVolume(const double entry,const double stop)
{
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double riskMoney=InpUseCashRisk ? InpMaxLossUSD : AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
   if(tickSize<=0.0 || tickValue<=0.0 || riskMoney<=0.0) return(0.0);
   double lossPerLot=MathAbs(entry-stop)/tickSize*tickValue;
   if(lossPerLot<=0.0) return(0.0);
   double rawVolume=riskMoney/lossPerLot;
   if(rawVolume<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)) return(0.0);
   return(NormalizeVolume(rawVolume));
}

double CashPriceDistance(const double volume,const double cashAmount)
{
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(volume<=0.0 || cashAmount<=0.0 || tickSize<=0.0 || tickValue<=0.0) return(0.0);
   return(cashAmount*tickSize/(volume*tickValue));
}

bool MoveStopToProtectedBreakEven(const ulong ticket,const bool isBuy,const double entry,const double currentStop,const double target,const double volume)
{
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)) return(false);
   long stopsLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double minimumDistance=(MathMax((double)stopsLevel,(double)freezeLevel)+MathMax(1,InpStopSafetyBufferPoints))*_Point;
   double lockDistance=CashPriceDistance(volume,InpBreakEvenLockUSD);
   if(lockDistance<0.0) lockDistance=0.0;
   double protectedStop;
   if(isBuy)
   {
      protectedStop=MathMin(entry+lockDistance,quote.bid-minimumDistance);
      if(protectedStop<=entry+_Point || (currentStop>0.0 && protectedStop<=currentStop+_Point)) return(false);
   }
   else
   {
      protectedStop=MathMax(entry-lockDistance,quote.ask+minimumDistance);
      if(protectedStop>=entry-_Point || (currentStop>0.0 && protectedStop>=currentStop-_Point)) return(false);
   }
   bool sent=trade.PositionModify(ticket,NormalizeDouble(protectedStop,_Digits),target);
   if(!sent || !TradeResultOK()) return(false);
   Print("Break-even protected for position ",IntegerToString((int)ticket)," at ",DoubleToString(protectedStop,_Digits));
   return(true);
}

double RiskMoneyForVolume(const double entry,const double stop,const double volume)
{
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0.0 || tickValue<=0.0 || volume<=0.0) return(0.0);
   return(MathAbs(entry-stop)/tickSize*tickValue*volume);
}

double TotalOpenRisk()
{
   double risk=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      risk+=RiskMoneyForVolume(PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL),PositionGetDouble(POSITION_VOLUME));
   }
   return(risk);
}

bool PositionIdentifierIsOpen(const long identifier)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_IDENTIFIER)==identifier) return(true);
   }
   return(false);
}

void GetDailyStats(DailyStats &stats)
{
   MqlDateTime day;
   TimeToStruct(TimeCurrent(),day);
   day.hour=0;
   day.min=0;
   day.sec=0;
   stats.profit=0.0;
   stats.loss=0.0;
   stats.winners=0;
   stats.losers=0;
   if(!HistorySelect(StructToTime(day),TimeCurrent())) return;
   long positionIds[];
   double positionNet[];
   int positionCount=0;
   uint dealCount=HistoryDealsTotal();
   for(uint i=0;i<dealCount;i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 || (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber) continue;
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY) continue;
      double net=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_SWAP);
      if(net>=0.0) stats.profit+=net; else stats.loss-=net;
      long positionId=(long)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      int index=-1;
      for(int n=0;n<positionCount;n++) if(positionIds[n]==positionId) { index=n; break; }
      if(index<0)
      {
         ArrayResize(positionIds,positionCount+1);
         ArrayResize(positionNet,positionCount+1);
         index=positionCount;
         positionIds[index]=positionId;
         positionNet[index]=0.0;
         positionCount++;
      }
      positionNet[index]+=net;
   }
   for(int i=0;i<positionCount;i++)
   {
      if(PositionIdentifierIsOpen(positionIds[i])) continue;
      if(positionNet[i]>0.0) stats.winners++;
      if(positionNet[i]<0.0) stats.losers++;
   }
}

double DailyRealizedLoss()
{
   DailyStats stats;
   GetDailyStats(stats);
   return(stats.loss);
}

string DrawdownKey(const string suffix)
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(),now);
   int dayKey=now.year*10000+now.mon*100+now.day;
   return("AMDScalperDD_"+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((int)InpMagicNumber)+"_"+IntegerToString(dayKey)+"_"+suffix);
}

void GetDrawdownStats(DrawdownStats &stats)
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   string peakKey=DrawdownKey("peak");
   string maxKey=DrawdownKey("max");
   double peak=GlobalVariableCheck(peakKey) ? GlobalVariableGet(peakKey) : equity;
   double maximum=GlobalVariableCheck(maxKey) ? GlobalVariableGet(maxKey) : 0.0;
   if(equity>peak)
   {
      peak=equity;
      GlobalVariableSet(peakKey,peak);
   }
   else if(!GlobalVariableCheck(peakKey)) GlobalVariableSet(peakKey,peak);
   double current=MathMax(0.0,peak-equity);
   if(current>maximum)
   {
      maximum=current;
      GlobalVariableSet(maxKey,maximum);
   }
   else if(!GlobalVariableCheck(maxKey)) GlobalVariableSet(maxKey,maximum);
   stats.current=current;
   stats.currentPercent=peak>0.0 ? current/peak*100.0 : 0.0;
   stats.maximum=maximum;
   stats.maximumPercent=peak>0.0 ? maximum/peak*100.0 : 0.0;
}

bool SpreadAllowed()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return(false);
   return((tick.ask-tick.bid)/_Point<=InpMaxSpreadPoints);
}

void UpdateAMDTarget()
{
   MqlRates h4[];
   ArraySetAsSeries(h4,true);
   if(CopyRates(_Symbol,InpAMDTimeframe,1,1,h4)!=1) return;
   if(h4[0].time==processedH4Time) return;
   processedH4Time=h4[0].time;
   bool noLowerWick=h4[0].low>=MathMin(h4[0].open,h4[0].close)-_Point*InpWickToleranceTicks;
   if(noLowerWick)
   {
      amdTargetLow=h4[0].low;
      amdTargetActive=true;
   }
}

bool ClosePartial(const ulong ticket,const double requestedVolume)
{
   if(!PositionSelectByTicket(ticket)) return(false);
   double currentVolume=PositionGetDouble(POSITION_VOLUME);
   double minVolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double closeVolume=NormalizeVolume(requestedVolume);
   if(closeVolume<minVolume || currentVolume-closeVolume<minVolume) return(false);
   bool sent=trade.PositionClosePartial(ticket,closeVolume);
   if(!sent || !TradeResultOK()) return(false);
   return(true);
}

void ManageOpenPosition()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   double entryEma=0.0;
   double previousEntryEma=0.0;
   bool emaReady=BufferValue(entryEmaHandle,0,entryEma) && BufferValue(entryEmaHandle,1,previousEntryEma);

   // Iterate in reverse because a close can change the positions collection.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;

      long type=PositionGetInteger(POSITION_TYPE);
      bool isBuy=type==POSITION_TYPE_BUY;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double stop=PositionGetDouble(POSITION_SL);
      double target=PositionGetDouble(POSITION_TP);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double price=isBuy ? tick.bid : tick.ask;
      double profit=PositionGetDouble(POSITION_PROFIT);
      datetime openedAt=(datetime)PositionGetInteger(POSITION_TIME);
      int heldSeconds=(int)(TimeCurrent()-openedAt);

      bool timeExit=InpMaxHoldSeconds>0 && heldSeconds>=InpMaxHoldSeconds;
      bool lossExit=InpFastLossExitUSD>0.0 && profit<=-InpFastLossExitUSD;
      bool profitExit=InpQuickProfitCloseUSD>0.0 && profit>=InpQuickProfitCloseUSD;
      bool reversalExit=InpExitOnMicroReversal && emaReady &&
                        (isBuy ? (price<entryEma && entryEma<previousEntryEma) : (price>entryEma && entryEma>previousEntryEma));
      double candleOpen=iOpen(_Symbol,_Period,0);
      bool candleFlipExit=InpExitOnLosingCandleFlip && profit<0.0 && candleOpen>0.0 &&
                          (isBuy ? price<candleOpen : price>candleOpen);
      bool directionFlipExit=InpExitOnCandleDirectionFlip && candleOpen>0.0 &&
                             (isBuy ? price<candleOpen : price>candleOpen);
      double retracementBuffer=InpRetracementBufferPoints*_Point;
      bool retracementFailure=InpExitOnRetracementFailure && emaReady &&
                              (isBuy ? price<entryEma-retracementBuffer : price>entryEma+retracementBuffer);
      if(timeExit || lossExit || profitExit || reversalExit || candleFlipExit || directionFlipExit || retracementFailure)
      {
         string reason=timeExit ? "time limit" : (lossExit ? "fast loss limit" : (profitExit ? "quick profit target" : (retracementFailure ? "retracement failure" : (directionFlipExit ? "candle direction flip" : (candleFlipExit ? "losing candle flip" : (profit>0.0 ? "dynamic profit exit" : "micro reversal"))))));
         bool sent=trade.PositionClose(ticket);
         if(sent && TradeResultOK())
         {
            lastExitTime=TimeCurrent();
            SetStatus("CLOSED "+(isBuy ? "BUY" : "SELL")+" — "+reason+"; re-entry may be evaluated after cooldown");
         }
         continue;
      }

      // Lock a small realised-profit buffer; retry on later ticks if broker distance rules prevent it now.
      if(InpBreakEvenTriggerUSD>0.0 && profit>=InpBreakEvenTriggerUSD)
      {
         if(MoveStopToProtectedBreakEven(ticket,isBuy,entry,stop,target,volume))
            SetStatus("BREAK-EVEN LOCKED "+(isBuy ? "BUY" : "SELL")+" — profit protected");
      }

      // Partial targets are only safe when a single net position is used.
      if(EffectiveMaxPositions()>1) continue;
      double risk=MathAbs(entry-stop);
      if(risk<=_Point || target<=0.0) continue;
      double targetDistance=MathAbs(target-entry);
      double tp1=isBuy ? entry+targetDistance/3.0 : entry-targetDistance/3.0;
      double tp2=isBuy ? entry+targetDistance*2.0/3.0 : entry-targetDistance*2.0/3.0;
      if(!tp1Done && (isBuy ? price>=tp1 : price<=tp1))
      {
         ClosePartial(ticket,volume*0.33);
         trade.PositionModify(ticket,entry,target);
         tp1Done=true;
      }
      if(!tp2Done && (isBuy ? price>=tp2 : price<=tp2))
      {
         ClosePartial(ticket,volume*0.33);
         trade.PositionModify(ticket,entry,target);
         tp2Done=true;
      }
   }
}

void EvaluateEntry(const bool intrabar=false)
{
   if(!InpEnableTrading) { SetStatus("Disabled — set InpEnableTrading=true"); return; }
   if(!runtimeTradingEnabled) { SetStatus("Paused from chart control"); return; }
   if(!IsScalpingTimeframe()) { SetStatus("Blocked — attach to M1 or M5"); return; }
   if(!InTradeSession()) { SetStatus("Waiting — outside broker session"); return; }
   if(!InpIgnoreSpreadFilter && !SpreadAllowed()) { SetStatus("Waiting — spread exceeds InpMaxSpreadPoints"); return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) { SetStatus("Blocked — Algo Trading permission is off"); return; }
   RefreshTradeDay();
   RefreshCandleEntryCount();
   if(InpMaxDailyLossUSD>0.0 && DailyRealizedLoss()>=InpMaxDailyLossUSD) { SetStatus("Blocked — daily loss limit reached"); return; }
   int maxPositions=EffectiveMaxPositions();
   int openPositions=OwnPositionCount();
   if(openPositions>=maxPositions) { SetStatus("Waiting — maximum open positions reached"); return; }
   if(InpOneActiveTradeAtATime && openPositions>0) { SetStatus("Waiting — current candle trade is active"); return; }
   if(InpMaxTradesPerDay>0 && tradesToday>=InpMaxTradesPerDay) { SetStatus("Waiting — daily trade limit reached"); return; }
   int seconds=PeriodSeconds(_Period);
   if(intrabar && lastEntryTime>0 && TimeCurrent()-lastEntryTime<InpMinimumSecondsBetweenEntries) { SetStatus("Waiting — intrabar entry cooldown"); return; }
   if(intrabar && lastExitTime>0 && TimeCurrent()-lastExitTime<InpReentryCooldownSeconds) { SetStatus("Waiting — rapid re-entry cooldown"); return; }
   if(intrabar && InpMaxEntriesPerCandle>0 && entriesThisCandle>=InpMaxEntriesPerCandle) { SetStatus("Waiting — maximum entries reached for this candle"); return; }
   if(!intrabar && lastSignalTime>0 && iTime(_Symbol,_Period,1)-lastSignalTime<(datetime)((seconds>0 ? seconds : 60)*InpCooldownBars)) { SetStatus("Waiting — bar cooldown"); return; }

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int count=CopyRates(_Symbol,_Period,0,360,rates);
   if(count<MathMax(InpATRPeriod+10,80)) { SetStatus("Waiting — insufficient price history"); return; }
   int signalShift=intrabar ? 0 : 1;
   int priorShift=signalShift+1;
   double atr,entryEma,previousEntryEma,htfFast,htfSlow;
   if(!BufferValue(atrHandle,signalShift,atr) || !BufferValue(entryEmaHandle,signalShift,entryEma) || !BufferValue(entryEmaHandle,priorShift,previousEntryEma) || !BufferValue(htfFastHandle,1,htfFast) || !BufferValue(htfSlowHandle,1,htfSlow)) { SetStatus("Waiting — indicator data loading"); return; }
   double htfClose=iClose(_Symbol,InpTrendTimeframe,1);
   if(htfClose<=0.0) { SetStatus("Waiting — H1 data loading"); return; }
   double relativeAtr=atr/rates[signalShift].close;
   double relativeAtrAverage=0.0;
   for(int i=1;i<=50;i++)
   {
      double atrAt;
      if(!BufferValue(atrHandle,i,atrAt)) { SetStatus("Waiting — ATR data loading"); return; }
      relativeAtrAverage+=atrAt/rates[i].close;
   }
   relativeAtrAverage/=50.0;
   if(!InpBypassVolatilityFilter && relativeAtr<relativeAtrAverage*InpMinimumRelativeATR) { SetStatus("Waiting — volatility filter"); return; }

   UpdateAMDTarget();
   int fvgShift=signalShift+2;
   double swingHigh=LatestSwingHigh(rates,count);
   double swingLow=LatestSwingLow(rates,count);
   bool bullishBreak=swingHigh>0.0 && rates[signalShift].close>swingHigh && rates[priorShift].close<=swingHigh;
   bool bearishBreak=swingLow>0.0 && rates[signalShift].close<swingLow && rates[priorShift].close>=swingLow;
   bool sweepLow=swingLow>0.0 && rates[signalShift].low<swingLow && rates[signalShift].close>swingLow;
   bool sweepHigh=swingHigh>0.0 && rates[signalShift].high>swingHigh && rates[signalShift].close<swingHigh;
   bool bullishFvg=rates[signalShift].low>rates[fvgShift].high;
   bool bearishFvg=rates[signalShift].high<rates[fvgShift].low;
   int longScore=(sweepLow ? 1 : 0)+(bullishFvg ? 1 : 0);
   int shortScore=(sweepHigh ? 1 : 0)+(bearishFvg ? 1 : 0);
   bool trendLong=htfClose>htfFast && htfFast>htfSlow;
   bool trendShort=htfClose<htfFast && htfFast<htfSlow;
   bool longSignal=InpEnableLongs && trendLong && rates[signalShift].close>entryEma && bullishBreak && longScore>=InpMinimumStructureConfirmations;
   bool amdShort=InpEnableShorts && InpEnableAMDShorts && amdTargetActive && rates[signalShift].close>amdTargetLow && trendShort && shortScore>=InpMinimumAMDConfirmations;
   bool shortSignal=InpEnableShorts && trendShort && rates[signalShift].close<entryEma && bearishBreak && shortScore>=InpMinimumStructureConfirmations;
   if(InpOpenOnActivation && !longSignal && !amdShort && !shortSignal)
   {
      longSignal=InpEnableLongs && trendLong && rates[signalShift].close>entryEma;
      shortSignal=InpEnableShorts && trendShort && rates[signalShift].close<entryEma;
   }
   bool usedRetracement=false;
   MqlTick liveTick;
   if(!SymbolInfoTick(_Symbol,liveTick)) { SetStatus("Waiting — no current broker quote"); return; }
   double retracementBuffer=InpRetracementBufferPoints*_Point;
   bool longRetracement=trendLong && rates[signalShift].low<=entryEma+retracementBuffer && liveTick.bid>entryEma+retracementBuffer;
   bool shortRetracement=trendShort && rates[signalShift].high>=entryEma-retracementBuffer && liveTick.ask<entryEma-retracementBuffer;
   if(intrabar && InpUseRetracementEntries)
   {
      longSignal=InpEnableLongs && longRetracement;
      shortSignal=InpEnableShorts && shortRetracement;
      amdShort=false;
      usedRetracement=true;
   }
   if(!longSignal && !amdShort && !shortSignal)
   {
      SetStatus(intrabar && InpUseRetracementEntries ? "Waiting — no valid retracement" : "Waiting — no validated AMD structure");
      return;
   }

   bool isBuy=longSignal;
   double entry=isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double stop=isBuy ? MathMin(rates[signalShift].low,swingLow>0.0 ? swingLow : rates[signalShift].low) : MathMax(rates[signalShift].high,swingHigh>0.0 ? swingHigh : rates[signalShift].high);
   stop=isBuy ? MathMin(stop,entry-atr*InpMinRiskATR) : MathMax(stop,entry+atr*InpMinRiskATR);
   double risk=MathAbs(entry-stop);
   if(risk<=_Point) { SetStatus("Blocked — invalid stop distance"); return; }
   double volume=InpUseFixedLot ? NormalizeVolume(InpFixedLot) : RiskBasedVolume(entry,stop);
   if(volume<=0.0) { SetStatus("Blocked — lot minimum exceeds risk limit"); return; }
   double target=0.0;
   if(InpUseCashTakeProfit)
   {
      double cashDistance=CashPriceDistance(volume,InpTakeProfitUSD);
      if(cashDistance<=0.0) { SetStatus("Blocked — cannot calculate cash target"); return; }
      target=isBuy ? entry+cashDistance : entry-cashDistance;
   }
   if(!NormalizeOrderStops(isBuy,stop,target)) { SetStatus("Waiting — no valid broker stops yet"); return; }
   double tradeRisk=RiskMoneyForVolume(entry,stop,volume);
   if(tradeRisk<=0.0 || (InpMaxPerTradeRiskUSD>0.0 && tradeRisk>InpMaxPerTradeRiskUSD)) { SetStatus("Blocked — invalid or capped trade risk $"+DoubleToString(tradeRisk,2)); return; }
   if(InpMaxTotalRiskUSD>0.0 && TotalOpenRisk()+tradeRisk>InpMaxTotalRiskUSD) { SetStatus("Blocked — next risk $"+DoubleToString(tradeRisk,2)+" exceeds open-risk limit $"+DoubleToString(InpMaxTotalRiskUSD,2)); return; }
   int permittedOrders=MathMin(InpOrdersPerSignal,maxPositions-openPositions);
   if(InpMaxTradesPerDay>0) permittedOrders=MathMin(permittedOrders,InpMaxTradesPerDay-tradesToday);
   if(intrabar && InpMaxEntriesPerCandle>0) permittedOrders=MathMin(permittedOrders,InpMaxEntriesPerCandle-entriesThisCandle);
   for(int orderNumber=0;orderNumber<permittedOrders;orderNumber++)
   {
      if(InpMaxTotalRiskUSD>0.0 && TotalOpenRisk()+tradeRisk>InpMaxTotalRiskUSD) break;
      if(SendOrderWithRetries(isBuy,volume,stop,target))
      {
         lastSignalTime=rates[signalShift].time;
         lastEntryTime=TimeCurrent();
         tradesToday++;
         if(intrabar) entriesThisCandle++;
         tp1Done=false;
         tp2Done=false;
         Print("AMD Scalping EA opened ",isBuy ? "BUY" : "SELL"," ",DoubleToString(volume,VolumeDigits()));
         SetStatus("OPENED "+(isBuy ? "BUY" : "SELL")+" "+DoubleToString(volume,VolumeDigits())+" lots"+(usedRetracement ? " — EMA retracement" : " — validated AMD structure"));
      }
      else SetStatus("Broker rejected order — see Experts tab");
   }
}

void OnTick()
{
   ManageOpenPosition();
   SetStatus(lastStatus);
   if(InpEvaluateEveryTick)
   {
      EvaluateEntry(true);
      return;
   }
   datetime closedBar=iTime(_Symbol,_Period,1);
   if(closedBar<=0) return;
   if(lastClosedBar==0)
   {
      lastClosedBar=closedBar;
      EvaluateEntry();
      return;
   }
   if(closedBar==lastClosedBar) return;
   lastClosedBar=closedBar;
   EvaluateEntry();
}
