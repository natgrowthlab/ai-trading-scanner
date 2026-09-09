#property copyright "NAT Growth Lab"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

// Expert Advisor based on the TradingView AMD Scalping Strategy.
// Test in the MT5 Strategy Tester / demo account before using a live account.
input bool            InpEnableTrading = true;
input ulong           InpMagicNumber = 26092026;
input ENUM_TIMEFRAMES InpAMDTimeframe = PERIOD_H4;
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_M15;
input bool            InpOnlyM1M5 = true;
input int             InpSessionStartHour = 0;       // Broker server time
input int             InpSessionEndHour = 23;        // Broker server time
input int             InpMaxSpreadPoints = 200;
input bool            InpIgnoreSpreadFilter = true;  // Spread remains a real cost; this only removes the entry block
input double          InpRiskPercent = 0.25;         // Equity risk per trade
input bool            InpUseCashRisk = true;
input double          InpMaxLossUSD = 4.00;
input bool            InpUseCashTakeProfit = true;
input double          InpTakeProfitUSD = 3.00;
input bool            InpOpenOnActivation = true;    // Uses trend bias when no full setup is present
input bool            InpUseFixedLot = true;
input double          InpFixedLot = 0.01;
input int             InpMaxOpenPositions = 5;
input int             InpOrdersPerSignal = 2;
input int             InpMaxTradesPerDay = 0;        // 0 = unlimited; loss and risk limits still apply
input double          InpMaxTotalRiskUSD = 200.00;
input double          InpMaxPerTradeRiskUSD = 4.00;
input double          InpMaxDailyLossUSD = 100.00;
input bool            InpEvaluateEveryTick = true;
input int             InpMinimumSecondsBetweenEntries = 5;
input int             InpReentryCooldownSeconds = 3;
input int             InpMaxHoldSeconds = 120;
input bool            InpExitOnMicroReversal = true;
input double          InpFastLossExitUSD = 1.50;
input double          InpBreakEvenTriggerUSD = 0.01; // Move SL to entry as soon as the position is positive
input bool            InpUseFastDirectionFallback = true;
input bool            InpUseCandleDirectionEntries = true; // Permit rapid entries in the live candle direction
input bool            InpShowStatusPanel = true;
input bool            InpBypassVolatilityFilter = true;
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
input bool            InpEnableAMDShorts = true;
input double          InpTP1R = 1.0;
input double          InpTP2R = 1.5;
input double          InpTP3R = 2.0;
input ulong           InpDeviationPoints = 20;

CTrade trade;
int atrHandle = INVALID_HANDLE;
int entryEmaHandle = INVALID_HANDLE;
int htfFastHandle = INVALID_HANDLE;
int htfSlowHandle = INVALID_HANDLE;
datetime lastClosedBar = 0;
datetime lastSignalTime = 0;
datetime lastEntryTime = 0;
datetime lastExitTime = 0;
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
   Comment("AMD Scalping EA\nBot: ",runtimeTradingEnabled ? "ACTIVE" : "PAUSED","\n",status,"\nSymbol: ",_Symbol,"  TF: ",EnumToString(_Period),"\nSymbol positions: ",IntegerToString(OwnPositionCount())," / ",IntegerToString(EffectiveMaxPositions()),"\nGlobal open risk: $",DoubleToString(TotalOpenRisk(),2)," / $",DoubleToString(InpMaxTotalRiskUSD,2),"\nDaily profit: $",DoubleToString(stats.profit,2),"  |  Daily loss: $",DoubleToString(stats.loss,2)," / $",DoubleToString(InpMaxDailyLossUSD,2),"\nWinners: ",IntegerToString(stats.winners),"  |  Losers: ",IntegerToString(stats.losers),"\nCurrent DD: $",DoubleToString(drawdown.current,2)," (",DoubleToString(drawdown.currentPercent,2),"%)  |  Max DD: $",DoubleToString(drawdown.maximum,2)," (",DoubleToString(drawdown.maximumPercent,2),"%)\nTrades today (symbol): ",IntegerToString(tradesToday)," / ",tradeCap);
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

bool TradeResultOK()
{
   uint code=trade.ResultRetcode();
   if(code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_PLACED) return(true);
   Print("Trade request rejected: ",trade.ResultRetcodeDescription());
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
      bool reversalExit=InpExitOnMicroReversal && emaReady &&
                        (isBuy ? (price<entryEma && entryEma<previousEntryEma) : (price>entryEma && entryEma>previousEntryEma));
      if(timeExit || lossExit || reversalExit)
      {
         string reason=timeExit ? "time limit" : (lossExit ? "fast loss limit" : (profit>0.0 ? "dynamic profit exit" : "micro reversal"));
         bool sent=trade.PositionClose(ticket);
         if(sent && TradeResultOK())
         {
            lastExitTime=TimeCurrent();
            SetStatus("CLOSED "+(isBuy ? "BUY" : "SELL")+" — "+reason+"; re-entry may be evaluated after cooldown");
         }
         continue;
      }

      // Once a rapid trade has made enough, remove price risk while its broker-side TP remains active.
      if(InpBreakEvenTriggerUSD>0.0 && profit>=InpBreakEvenTriggerUSD)
      {
         bool improvesStop=(isBuy && (stop==0.0 || entry>stop+_Point)) || (!isBuy && (stop==0.0 || entry<stop-_Point));
         if(improvesStop) trade.PositionModify(ticket,NormalizeDouble(entry,_Digits),target);
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
   if(DailyRealizedLoss()>=InpMaxDailyLossUSD) { SetStatus("Blocked — daily loss limit reached"); return; }
   int maxPositions=EffectiveMaxPositions();
   int openPositions=OwnPositionCount();
   if(openPositions>=maxPositions) { SetStatus("Waiting — maximum open positions reached"); return; }
   if(InpMaxTradesPerDay>0 && tradesToday>=InpMaxTradesPerDay) { SetStatus("Waiting — daily trade limit reached"); return; }
   int seconds=PeriodSeconds(_Period);
   if(intrabar && lastEntryTime>0 && TimeCurrent()-lastEntryTime<InpMinimumSecondsBetweenEntries) { SetStatus("Waiting — intrabar entry cooldown"); return; }
   if(intrabar && lastExitTime>0 && TimeCurrent()-lastExitTime<InpReentryCooldownSeconds) { SetStatus("Waiting — rapid re-entry cooldown"); return; }
   if(!intrabar && lastSignalTime>0 && iTime(_Symbol,_Period,1)-lastSignalTime<(datetime)((seconds>0 ? seconds : 60)*InpCooldownBars)) { SetStatus("Waiting — bar cooldown"); return; }

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int count=CopyRates(_Symbol,_Period,0,360,rates);
   if(count<MathMax(InpATRPeriod+10,80)) { SetStatus("Waiting — insufficient price history"); return; }
   int signalShift=intrabar ? 0 : 1;
   int priorShift=signalShift+1;
   int fvgShift=signalShift+2;
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
   bool fastTrendLong=rates[signalShift].close>entryEma && entryEma>=previousEntryEma;
   bool fastTrendShort=rates[signalShift].close<entryEma && entryEma<=previousEntryEma;
   bool candleLong=rates[signalShift].close>rates[signalShift].open;
   bool candleShort=rates[signalShift].close<rates[signalShift].open;
   bool longSignal=InpEnableLongs && trendLong && rates[signalShift].close>entryEma && bullishBreak && longScore>=InpMinimumStructureConfirmations;
   bool amdShort=InpEnableShorts && InpEnableAMDShorts && amdTargetActive && rates[signalShift].close>amdTargetLow && trendShort && shortScore>=InpMinimumAMDConfirmations;
   bool shortSignal=InpEnableShorts && trendShort && rates[signalShift].close<entryEma && bearishBreak && shortScore>=InpMinimumStructureConfirmations;
   bool activationLong=InpEnableLongs && InpOpenOnActivation && ((trendLong && rates[signalShift].close>entryEma) || (InpUseFastDirectionFallback && fastTrendLong) || (InpUseCandleDirectionEntries && candleLong));
   bool activationShort=InpEnableShorts && InpOpenOnActivation && ((trendShort && rates[signalShift].close<entryEma) || (InpUseFastDirectionFallback && fastTrendShort) || (InpUseCandleDirectionEntries && candleShort));
   if(!longSignal && !amdShort && !shortSignal)
   {
      longSignal=activationLong;
      shortSignal=activationShort;
   }
   if(!longSignal && !amdShort && !shortSignal) { SetStatus("Waiting — no qualifying direction or setup"); return; }

   // A higher-timeframe BUY bias and a live bearish candle can otherwise be true at the
   // same time. Resolve the conflict using the live candle, rather than always choosing BUY.
   if(longSignal && (shortSignal || amdShort))
   {
      if(candleShort)
      {
         longSignal=false;
         shortSignal=true;
      }
      else
      {
         shortSignal=false;
         amdShort=false;
      }
   }

   bool isBuy=longSignal;
   double entry=isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double stop=isBuy ? MathMin(rates[signalShift].low,swingLow>0.0 ? swingLow : rates[signalShift].low) : MathMax(rates[signalShift].high,swingHigh>0.0 ? swingHigh : rates[signalShift].high);
   stop=isBuy ? MathMin(stop,entry-atr*InpMinRiskATR) : MathMax(stop,entry+atr*InpMinRiskATR);
   double risk=MathAbs(entry-stop);
   if(risk<=_Point) { SetStatus("Blocked — invalid stop distance"); return; }
   double volume=InpUseFixedLot ? NormalizeVolume(InpFixedLot) : RiskBasedVolume(entry,stop);
   if(volume<=0.0) { SetStatus("Blocked — lot minimum exceeds risk limit"); return; }
   double target=isBuy ? entry+risk*InpTP3R : (amdShort ? MathMin(amdTargetLow,entry-risk*InpTP3R) : entry-risk*InpTP3R);
   if(InpUseCashTakeProfit)
   {
      double cashDistance=CashPriceDistance(volume,InpTakeProfitUSD);
      if(cashDistance<=0.0) { SetStatus("Blocked — cannot calculate cash target"); return; }
      target=isBuy ? entry+cashDistance : entry-cashDistance;
   }
   double minimumStopDistance=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if((isBuy && (entry-stop<minimumStopDistance || target-entry<minimumStopDistance)) || (!isBuy && (stop-entry<minimumStopDistance || entry-target<minimumStopDistance))) { SetStatus("Blocked — broker minimum stop distance"); return; }
   double tradeRisk=RiskMoneyForVolume(entry,stop,volume);
   if(tradeRisk<=0.0 || tradeRisk>InpMaxPerTradeRiskUSD) { SetStatus("Blocked — next risk $"+DoubleToString(tradeRisk,2)+" exceeds per-trade limit $"+DoubleToString(InpMaxPerTradeRiskUSD,2)); return; }
   if(TotalOpenRisk()+tradeRisk>InpMaxTotalRiskUSD) { SetStatus("Blocked — next risk $"+DoubleToString(tradeRisk,2)+" exceeds open-risk limit $"+DoubleToString(InpMaxTotalRiskUSD,2)); return; }
   int permittedOrders=MathMin(InpOrdersPerSignal,maxPositions-openPositions);
   if(InpMaxTradesPerDay>0) permittedOrders=MathMin(permittedOrders,InpMaxTradesPerDay-tradesToday);
   for(int orderNumber=0;orderNumber<permittedOrders;orderNumber++)
   {
      if(TotalOpenRisk()+tradeRisk>InpMaxTotalRiskUSD) break;
      bool sent=isBuy ? trade.Buy(volume,_Symbol,0.0,NormalizeDouble(stop,_Digits),NormalizeDouble(target,_Digits),"AMD scalp long") : trade.Sell(volume,_Symbol,0.0,NormalizeDouble(stop,_Digits),NormalizeDouble(target,_Digits),"AMD scalp short");
      if(sent && TradeResultOK())
      {
         lastSignalTime=rates[signalShift].time;
         lastEntryTime=TimeCurrent();
         tradesToday++;
         tp1Done=false;
         tp2Done=false;
         Print("AMD Scalping EA opened ",isBuy ? "BUY" : "SELL"," ",DoubleToString(volume,VolumeDigits()));
         SetStatus("OPENED "+(isBuy ? "BUY" : "SELL")+" "+DoubleToString(volume,VolumeDigits())+" lots");
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
