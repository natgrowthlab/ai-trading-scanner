#property copyright "NAT Growth Lab"
#property version   "2.0"
#property indicator_chart_window
#property indicator_plots 0

// MT5 visual equivalent of tradingview/scanner.pine.
// It is an indicator: it never opens, closes, or modifies a trade.
input ENUM_TIMEFRAMES InpAMDTimeframe = PERIOD_H4;
input int    InpSwingLeftBars = 3;
input int    InpSwingRightBars = 3;
input int    InpCooldownBars = 8;
input int    InpWickToleranceTicks = 0;
input int    InpMinimumConfirmations = 1;
input bool   InpShowAMDTarget = true;
input bool   InpStructureFallback = true;
input int    InpATRPeriod = 14;
input double InpMinimumRiskATR = 0.5;
input double InpTargetRiskReward = 2.0;
input bool   InpShowSessionLevels = false;
input int    InpSessionStartHour = 0;
input int    InpSessionEndHour = 24;
input bool   InpTerminalAlerts = false;

string prefix = "AMDTradePlan_";
datetime lastProcessedBar = 0;
datetime lastSignalTime = 0;
datetime processedHigherTime = 0;
double amdTargetLow = 0.0;
bool amdTargetActive = false;

int activeDirection = 0;
datetime activeSignalTime = 0;
double activeEntry = 0.0, activeStop = 0.0, activeTarget = 0.0;
double activeTp1 = 0.0, activeTp2 = 0.0, activeTp3 = 0.0;
bool tp1Reached = false, tp2Reached = false;
string activeTag = "";
double sessionHigh = 0.0, sessionLow = 0.0;
int trackedSessionDay = -1;

void SetStatusPanel();

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"AI Trading Scanner · AMD");
   SetStatusPanel();
   ChartRedraw(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,prefix)==0) ObjectDelete(0,name);
   }
}

bool IsSwingHigh(const double &high[],int index,int count)
{
   for(int n=1;n<=InpSwingLeftBars;n++) if(index-n<0 || high[index]<=high[index-n]) return(false);
   for(int n=1;n<=InpSwingRightBars;n++) if(index+n>=count || high[index]<=high[index+n]) return(false);
   return(true);
}

bool IsSwingLow(const double &low[],int index,int count)
{
   for(int n=1;n<=InpSwingLeftBars;n++) if(index-n<0 || low[index]>=low[index-n]) return(false);
   for(int n=1;n<=InpSwingRightBars;n++) if(index+n>=count || low[index]>=low[index+n]) return(false);
   return(true);
}

double LatestSwingHigh(const double &high[],int count)
{
   int first=InpSwingRightBars+1;
   int last=MathMin(count-InpSwingLeftBars-1,300);
   for(int i=first;i<=last;i++) if(IsSwingHigh(high,i,count)) return(high[i]);
   return(0.0);
}

double LatestSwingLow(const double &low[],int count)
{
   int first=InpSwingRightBars+1;
   int last=MathMin(count-InpSwingLeftBars-1,300);
   for(int i=first;i<=last;i++) if(IsSwingLow(low,i,count)) return(low[i]);
   return(0.0);
}

double AverageTrueRange(const double &high[],const double &low[],const double &close[],int count)
{
   int bars=MathMin(InpATRPeriod,count-2);
   if(bars<=0) return(_Point*10.0);
   double total=0.0;
   for(int i=1;i<=bars;i++)
   {
      double previousClose=close[i+1];
      total+=MathMax(high[i]-low[i],MathMax(MathAbs(high[i]-previousClose),MathAbs(low[i]-previousClose)));
   }
   return(total/bars);
}

void SetLine(const string id,datetime t1,double price,datetime t2,color lineColor,ENUM_LINE_STYLE style,int width=2)
{
   string name=prefix+id;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,t1,price,t2,price);
   ObjectMove(0,name,0,t1,price);
   ObjectMove(0,name,1,t2,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
}

void SetRectangle(const string id,datetime t1,double top,datetime t2,double bottom,color fillColor)
{
   string name=prefix+id;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,top,t2,bottom);
   ObjectMove(0,name,0,t1,top);
   ObjectMove(0,name,1,t2,bottom);
   ObjectSetInteger(0,name,OBJPROP_COLOR,fillColor);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
}

void SetPriceLabel(const string id,datetime when,double price,string text,color labelColor)
{
   string name=prefix+id;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,when,price);
   ObjectMove(0,name,0,when,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text+"\n"+DoubleToString(price,_Digits));
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_COLOR,labelColor);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
}

void SetSignalLabel(const string id,datetime when,double price,bool isLong,string text,color labelColor)
{
   string name=prefix+id;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,when,price);
   ObjectMove(0,name,0,when,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_COLOR,labelColor);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,isLong ? ANCHOR_LOWER : ANCHOR_UPPER);
}

void SetStatusPanel()
{
   string name=prefix+"STATUS";
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   string state=amdTargetActive ? "AMD 4H TARGET: "+DoubleToString(amdTargetLow,_Digits)+"\nWaiting lower-TF bearish confirmation" : "AMD: waiting for a closed 4H candle without lower wick";
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,14);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,24);
   ObjectSetInteger(0,name,OBJPROP_COLOR,amdTargetActive ? clrMagenta : clrSilver);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,name,OBJPROP_TEXT,"AI Trading Scanner\n"+state);
}

void DrawActivePlan(datetime right)
{
   if(activeDirection==0) return;
   SetRectangle(activeTag+"_profit",activeSignalTime,MathMax(activeEntry,activeTarget),right,MathMin(activeEntry,activeTarget),clrDarkGreen);
   SetRectangle(activeTag+"_stop",activeSignalTime,MathMax(activeEntry,activeStop),right,MathMin(activeEntry,activeStop),clrMaroon);
   SetLine(activeTag+"_entry",activeSignalTime,activeEntry,right,clrDeepSkyBlue,STYLE_SOLID);
   SetLine(activeTag+"_tp1",activeSignalTime,activeTp1,right,clrLime,STYLE_DASH);
   SetLine(activeTag+"_tp2",activeSignalTime,activeTp2,right,clrOrange,STYLE_DASH);
   SetLine(activeTag+"_tp3",activeSignalTime,activeTp3,right,clrMagenta,STYLE_DASH);
   SetLine(activeTag+"_sl",activeSignalTime,activeStop,right,clrRed,STYLE_DASH);
   SetPriceLabel(activeTag+"_entry_text",right,activeEntry,"ENTRY",clrDeepSkyBlue);
   SetPriceLabel(activeTag+"_tp1_text",right,activeTp1,"TP1",clrLime);
   SetPriceLabel(activeTag+"_tp2_text",right,activeTp2,"TP2",clrOrange);
   SetPriceLabel(activeTag+"_tp3_text",right,activeTp3,"TP3",clrMagenta);
   SetPriceLabel(activeTag+"_sl_text",right,activeStop,"SL",clrRed);
}

void StartPlan(datetime signalTime,double entry,double stop,double target,bool isLong)
{
   activeDirection=isLong ? 1 : -1;
   activeSignalTime=signalTime;
   activeEntry=NormalizeDouble(entry,_Digits);
   activeStop=NormalizeDouble(stop,_Digits);
   activeTarget=NormalizeDouble(target,_Digits);
   double targetDistance=MathAbs(activeTarget-activeEntry);
   activeTp1=NormalizeDouble(isLong ? activeEntry+targetDistance/3.0 : activeEntry-targetDistance/3.0,_Digits);
   activeTp2=NormalizeDouble(isLong ? activeEntry+targetDistance*2.0/3.0 : activeEntry-targetDistance*2.0/3.0,_Digits);
   activeTp3=activeTarget;
   tp1Reached=false;
   tp2Reached=false;
   activeTag=IntegerToString((int)signalTime);
   SetSignalLabel(activeTag+"_signal",signalTime,entry,isLong,isLong ? "BUY" : "SELL",isLong ? clrLime : clrTomato);
   int seconds=PeriodSeconds(_Period);
   DrawActivePlan(signalTime+(datetime)(seconds>0 ? seconds : 60));
   if(InpTerminalAlerts) Alert(_Symbol+" "+(isLong ? "BUY" : "SELL")+" | Entry: "+DoubleToString(activeEntry,_Digits));
}

void UpdateActivePlan(datetime barTime,double high,double low)
{
   if(activeDirection==0) return;
   int seconds=PeriodSeconds(_Period);
   datetime right=barTime+(datetime)(seconds>0 ? seconds : 60);
   DrawActivePlan(right);
   bool tp1Hit=activeDirection==1 ? high>=activeTp1 : low<=activeTp1;
   bool tp2Hit=activeDirection==1 ? high>=activeTp2 : low<=activeTp2;
   bool targetHit=activeDirection==1 ? high>=activeTarget : low<=activeTarget;
   bool stopHit=activeDirection==1 ? low<=activeStop : high>=activeStop;
   if(tp1Hit && !tp1Reached)
   {
      SetSignalLabel(activeTag+"_tp1_hit",barTime,activeTp1,activeDirection==1,"TP1 HIT",clrLime);
      tp1Reached=true;
   }
   if(tp2Hit && !tp2Reached)
   {
      SetSignalLabel(activeTag+"_tp2_hit",barTime,activeTp2,activeDirection==1,"TP2 HIT",clrOrange);
      tp2Reached=true;
   }
   if(targetHit || stopHit)
   {
      SetSignalLabel(activeTag+"_outcome",barTime,targetHit ? activeTarget : activeStop,activeDirection==1,targetHit ? (activeDirection==1 ? "Long TP" : "Short TP") : (activeDirection==1 ? "Long SL" : "Short SL"),targetHit ? clrMagenta : clrRed);
      if(targetHit) amdTargetActive=false;
      activeDirection=0;
   }
}

void UpdateSessionLevels(datetime barTime,double high,double low)
{
   if(!InpShowSessionLevels) return;
   MqlDateTime parts;
   TimeToStruct(barTime,parts);
   bool inSession=InpSessionStartHour<=InpSessionEndHour ? (parts.hour>=InpSessionStartHour && parts.hour<InpSessionEndHour) : (parts.hour>=InpSessionStartHour || parts.hour<InpSessionEndHour);
   if(!inSession) return;
   if(parts.day_of_year!=trackedSessionDay)
   {
      trackedSessionDay=parts.day_of_year;
      sessionHigh=high;
      sessionLow=low;
   }
   sessionHigh=MathMax(sessionHigh,high);
   sessionLow=MathMin(sessionLow,low);
   SetLine("SESSION_HIGH",barTime,sessionHigh,barTime+86400,clrAqua,STYLE_DASH,1);
   SetLine("SESSION_LOW",barTime,sessionLow,barTime+86400,clrAqua,STYLE_DASH,1);
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   if(rates_total<MathMax(InpATRPeriod+5,60))
   {
      SetStatusPanel();
      return(rates_total);
   }
   if(time[1]==lastProcessedBar) return(rates_total);
   lastProcessedBar=time[1];

   datetime h4time=iTime(_Symbol,InpAMDTimeframe,1);
   if(h4time>0 && h4time!=processedHigherTime)
   {
      processedHigherTime=h4time;
      double h4open=iOpen(_Symbol,InpAMDTimeframe,1);
      double h4close=iClose(_Symbol,InpAMDTimeframe,1);
      double h4low=iLow(_Symbol,InpAMDTimeframe,1);
      bool h4NoLowerWick=h4low>=MathMin(h4open,h4close)-_Point*InpWickToleranceTicks;
      if(h4NoLowerWick)
      {
         amdTargetLow=h4low;
         amdTargetActive=true;
      }
   }

   int seconds=PeriodSeconds(_Period);
   if(InpShowAMDTarget && amdTargetActive) SetLine("AMD_TARGET",time[1],amdTargetLow,time[1]+(datetime)((seconds>0 ? seconds : 60)*100),clrMagenta,STYLE_DASH);
   SetStatusPanel();
   UpdateSessionLevels(time[1],high[1],low[1]);
   UpdateActivePlan(time[1],high[1],low[1]);

   double lastSwingHigh=LatestSwingHigh(high,rates_total);
   double lastSwingLow=LatestSwingLow(low,rates_total);
   bool bullishBreak=lastSwingHigh>0.0 && close[1]>lastSwingHigh && close[2]<=lastSwingHigh;
   bool bearishBreak=lastSwingLow>0.0 && close[1]<lastSwingLow && close[2]>=lastSwingLow;
   bool liquiditySweepHigh=lastSwingHigh>0.0 && high[1]>lastSwingHigh && close[1]<lastSwingHigh;
   bool bearishFvg=high[1]<low[3];
   int confirmationScore=(liquiditySweepHigh ? 1 : 0)+(bearishBreak ? 1 : 0)+(bearishFvg ? 1 : 0);
   bool cooldownComplete=lastSignalTime==0 || (time[1]-lastSignalTime)>=((seconds>0 ? seconds : 60)*InpCooldownBars);
   bool amdShortSignal=amdTargetActive && close[1]>amdTargetLow && confirmationScore>=InpMinimumConfirmations;
   bool longSignal=cooldownComplete && InpStructureFallback && bullishBreak;
   bool shortSignal=cooldownComplete && (amdShortSignal || (InpStructureFallback && bearishBreak));

   if(longSignal || shortSignal)
   {
      bool isLong=longSignal && !shortSignal;
      lastSignalTime=time[1];
      double entry=close[1];
      double atr=AverageTrueRange(high,low,close,rates_total);
      double longStopCandidate=MathMin(low[1],lastSwingLow>0.0 ? lastSwingLow : low[1]);
      double shortStopCandidate=MathMax(high[1],lastSwingHigh>0.0 ? lastSwingHigh : high[1]);
      double stop=isLong ? MathMin(longStopCandidate,entry-atr*InpMinimumRiskATR) : MathMax(shortStopCandidate,entry+atr*InpMinimumRiskATR);
      double risk=MathAbs(entry-stop);
      double target=isLong ? entry+risk*InpTargetRiskReward : (amdShortSignal ? amdTargetLow : entry-risk*InpTargetRiskReward);
      StartPlan(time[1],entry,stop,target,isLong);
   }
   ChartRedraw(0);
   return(rates_total);
}
