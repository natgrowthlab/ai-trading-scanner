#property copyright "NAT Growth Lab"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

// Expert Advisor based on the TradingView AMD Scalping Strategy.
// Start with InpEnableTrading=false and test in the MT5 Strategy Tester / demo account.
input bool            InpEnableTrading = false;
input ulong           InpMagicNumber = 26092026;
input ENUM_TIMEFRAMES InpAMDTimeframe = PERIOD_H4;
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_H1;
input bool            InpOnlyM1M5 = true;
input int             InpSessionStartHour = 7;       // Broker server time
input int             InpSessionEndHour = 17;        // Broker server time
input int             InpMaxSpreadPoints = 30;
input double          InpRiskPercent = 0.25;         // Equity risk per trade
input bool            InpUseCashRisk = true;
input double          InpMaxLossUSD = 0.50;
input bool            InpUseCashTakeProfit = true;
input double          InpTakeProfitUSD = 1.00;
input bool            InpOpenOnActivation = false;   // Uses trend bias when no full setup is present
input int             InpSwingLeftBars = 3;
input int             InpSwingRightBars = 3;
input int             InpCooldownBars = 12;
input int             InpATRPeriod = 14;
input double          InpMinRiskATR = 0.75;
input int             InpEntryEMAPeriod = 20;
input int             InpHTFFastEMAPeriod = 50;
input int             InpHTFSlowEMAPeriod = 200;
input double          InpMinimumRelativeATR = 0.80;
input int             InpWickToleranceTicks = 0;
input int             InpMinimumStructureConfirmations = 1;
input int             InpMinimumAMDConfirmations = 2;
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
datetime processedH4Time = 0;
double amdTargetLow = 0.0;
bool amdTargetActive = false;
bool tp1Done = false;
bool tp2Done = false;

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
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(entryEmaHandle!=INVALID_HANDLE) IndicatorRelease(entryEmaHandle);
   if(htfFastHandle!=INVALID_HANDLE) IndicatorRelease(htfFastHandle);
   if(htfSlowHandle!=INVALID_HANDLE) IndicatorRelease(htfSlowHandle);
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
   ulong ticket;
   if(!HasOwnPosition(ticket) || !PositionSelectByTicket(ticket)) return;
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double stop=PositionGetDouble(POSITION_SL);
   double target=PositionGetDouble(POSITION_TP);
   double volume=PositionGetDouble(POSITION_VOLUME);
   double risk=MathAbs(entry-stop);
   if(risk<=_Point) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   bool isBuy=type==POSITION_TYPE_BUY;
   double price=isBuy ? tick.bid : tick.ask;
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

void EvaluateEntry()
{
   if(!InpEnableTrading || !IsScalpingTimeframe() || !InTradeSession() || !SpreadAllowed()) return;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return;
   ulong ticket;
   if(HasOwnPosition(ticket)) return;
   int seconds=PeriodSeconds(_Period);
   if(lastSignalTime>0 && iTime(_Symbol,_Period,1)-lastSignalTime<(datetime)((seconds>0 ? seconds : 60)*InpCooldownBars)) return;

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int count=CopyRates(_Symbol,_Period,0,360,rates);
   if(count<MathMax(InpATRPeriod+10,80)) return;
   double atr,entryEma,htfFast,htfSlow;
   if(!BufferValue(atrHandle,1,atr) || !BufferValue(entryEmaHandle,1,entryEma) || !BufferValue(htfFastHandle,1,htfFast) || !BufferValue(htfSlowHandle,1,htfSlow)) return;
   double htfClose=iClose(_Symbol,InpTrendTimeframe,1);
   if(htfClose<=0.0) return;
   double relativeAtr=atr/rates[1].close;
   double relativeAtrAverage=0.0;
   for(int i=1;i<=50;i++)
   {
      double atrAt;
      if(!BufferValue(atrHandle,i,atrAt)) return;
      relativeAtrAverage+=atrAt/rates[i].close;
   }
   relativeAtrAverage/=50.0;
   if(relativeAtr<relativeAtrAverage*InpMinimumRelativeATR) return;

   UpdateAMDTarget();
   double swingHigh=LatestSwingHigh(rates,count);
   double swingLow=LatestSwingLow(rates,count);
   bool bullishBreak=swingHigh>0.0 && rates[1].close>swingHigh && rates[2].close<=swingHigh;
   bool bearishBreak=swingLow>0.0 && rates[1].close<swingLow && rates[2].close>=swingLow;
   bool sweepLow=swingLow>0.0 && rates[1].low<swingLow && rates[1].close>swingLow;
   bool sweepHigh=swingHigh>0.0 && rates[1].high>swingHigh && rates[1].close<swingHigh;
   bool bullishFvg=rates[1].low>rates[3].high;
   bool bearishFvg=rates[1].high<rates[3].low;
   int longScore=(sweepLow ? 1 : 0)+(bullishFvg ? 1 : 0);
   int shortScore=(sweepHigh ? 1 : 0)+(bearishFvg ? 1 : 0);
   bool trendLong=htfClose>htfFast && htfFast>htfSlow;
   bool trendShort=htfClose<htfFast && htfFast<htfSlow;
   bool longSignal=trendLong && rates[1].close>entryEma && bullishBreak && longScore>=InpMinimumStructureConfirmations;
   bool amdShort=InpEnableAMDShorts && amdTargetActive && rates[1].close>amdTargetLow && trendShort && shortScore>=InpMinimumAMDConfirmations;
   bool shortSignal=trendShort && rates[1].close<entryEma && bearishBreak && shortScore>=InpMinimumStructureConfirmations;
   bool activationLong=InpOpenOnActivation && trendLong && rates[1].close>entryEma;
   bool activationShort=InpOpenOnActivation && trendShort && rates[1].close<entryEma;
   if(!longSignal && !amdShort && !shortSignal)
   {
      longSignal=activationLong;
      shortSignal=activationShort;
   }
   if(!longSignal && !amdShort && !shortSignal) return;

   bool isBuy=longSignal;
   double entry=isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double stop=isBuy ? MathMin(rates[1].low,swingLow>0.0 ? swingLow : rates[1].low) : MathMax(rates[1].high,swingHigh>0.0 ? swingHigh : rates[1].high);
   stop=isBuy ? MathMin(stop,entry-atr*InpMinRiskATR) : MathMax(stop,entry+atr*InpMinRiskATR);
   double risk=MathAbs(entry-stop);
   if(risk<=_Point) return;
   double volume=RiskBasedVolume(entry,stop);
   if(volume<=0.0) return;
   double target=isBuy ? entry+risk*InpTP3R : (amdShort ? MathMin(amdTargetLow,entry-risk*InpTP3R) : entry-risk*InpTP3R);
   if(InpUseCashTakeProfit)
   {
      double cashDistance=CashPriceDistance(volume,InpTakeProfitUSD);
      if(cashDistance<=0.0) return;
      target=isBuy ? entry+cashDistance : entry-cashDistance;
   }
   double minimumStopDistance=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if((isBuy && (entry-stop<minimumStopDistance || target-entry<minimumStopDistance)) || (!isBuy && (stop-entry<minimumStopDistance || entry-target<minimumStopDistance))) return;
   bool sent=isBuy ? trade.Buy(volume,_Symbol,0.0,NormalizeDouble(stop,_Digits),NormalizeDouble(target,_Digits),"AMD scalp long") : trade.Sell(volume,_Symbol,0.0,NormalizeDouble(stop,_Digits),NormalizeDouble(target,_Digits),"AMD scalp short");
   if(sent && TradeResultOK())
   {
      lastSignalTime=rates[1].time;
      tp1Done=false;
      tp2Done=false;
      Print("AMD Scalping EA opened ",isBuy ? "BUY" : "SELL"," ",DoubleToString(volume,VolumeDigits()));
   }
}

void OnTick()
{
   ManageOpenPosition();
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
