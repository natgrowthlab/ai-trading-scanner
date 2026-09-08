#property copyright "NAT Growth Lab"
#property version   "1.0"
#property indicator_chart_window
#property indicator_plots 0

// AMD visual indicator for MT5. It does not place trades.
input ENUM_TIMEFRAMES InpAMDTimeframe = PERIOD_H4;
input int    InpSwingBars = 3;
input int    InpCooldownBars = 8;
input int    InpATRPeriod = 14;
input double InpMinStopATR = 0.5;
input double InpFallbackRR = 2.0;
input bool   InpStructureFallback = true;
input int    InpPlanBarsRight = 30;
input bool   InpShowAMDTarget = true;

string prefix = "AMDTradePlan_";
datetime lastProcessedBar = 0;
datetime lastSignalTime = 0;
double amdTargetLow = 0.0;
bool amdTargetActive = false;
datetime processedH4Time = 0;

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"AMD Trade Plan MT5");
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

bool IsSwingHigh(const double &high[],int i,int count)
{
   for(int n=1;n<=InpSwingBars;n++) if(i-n<0 || i+n>=count || high[i]<=high[i-n] || high[i]<=high[i+n]) return(false);
   return(true);
}

bool IsSwingLow(const double &low[],int i,int count)
{
   for(int n=1;n<=InpSwingBars;n++) if(i-n<0 || i+n>=count || low[i]>=low[i-n] || low[i]>=low[i+n]) return(false);
   return(true);
}

double LatestSwingHigh(const double &high[],int count)
{
   for(int i=InpSwingBars+2;i<MathMin(count- InpSwingBars,250);i++) if(IsSwingHigh(high,i,count)) return(high[i]);
   return(0.0);
}

double LatestSwingLow(const double &low[],int count)
{
   for(int i=InpSwingBars+2;i<MathMin(count- InpSwingBars,250);i++) if(IsSwingLow(low,i,count)) return(low[i]);
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
      double trueRange=MathMax(high[i]-low[i],MathMax(MathAbs(high[i]-previousClose),MathAbs(low[i]-previousClose)));
      total+=trueRange;
   }
   return(total/bars);
}

void Line(const string id,datetime t1,double p,datetime t2,color c,ENUM_LINE_STYLE style)
{
   string n=prefix+id;
   ObjectCreate(0,n,OBJ_TREND,0,t1,p,t2,p);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_STYLE,style); ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
}

void PriceLabel(const string id,datetime t,double p,string text,color c)
{
   string n=prefix+id;
   ObjectCreate(0,n,OBJ_TEXT,0,t,p);
   ObjectSetString(0,n,OBJPROP_TEXT,text+"\n"+DoubleToString(p,_Digits));
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9); ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
}

void Rectangle(const string id,datetime t1,double top,datetime t2,double bottom,color c)
{
   string n=prefix+id;
   ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,top,t2,bottom);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_FILL,true); ObjectSetInteger(0,n,OBJPROP_BACK,true);
}

void DrawPlan(datetime signalTime,double entry,double stop,double target,bool isBuy)
{
   datetime right=signalTime+(datetime)(PeriodSeconds(_Period)*InpPlanBarsRight);
   double distance=MathAbs(target-entry);
   double tp1=NormalizeDouble(isBuy ? entry+distance/3.0 : entry-distance/3.0,_Digits);
   double tp2=NormalizeDouble(isBuy ? entry+distance*2.0/3.0 : entry-distance*2.0/3.0,_Digits);
   string tag=IntegerToString((int)signalTime);
   Rectangle(tag+"_profit",signalTime,MathMax(entry,target),right,MathMin(entry,target),clrDarkGreen);
   Rectangle(tag+"_risk",signalTime,MathMax(entry,stop),right,MathMin(entry,stop),clrMaroon);
   Line(tag+"_entry",signalTime,entry,right,clrDeepSkyBlue,STYLE_SOLID);
   Line(tag+"_tp1",signalTime,tp1,right,clrLime,STYLE_DASH);
   Line(tag+"_tp2",signalTime,tp2,right,clrOrange,STYLE_DASH);
   Line(tag+"_tp3",signalTime,target,right,clrMagenta,STYLE_DASH);
   Line(tag+"_sl",signalTime,stop,right,clrRed,STYLE_DASH);
   PriceLabel(tag+"_entry_label",right,entry,"ENTRY",clrDeepSkyBlue);
   PriceLabel(tag+"_tp1_label",right,tp1,"TP1",clrLime);
   PriceLabel(tag+"_tp2_label",right,tp2,"TP2",clrOrange);
   PriceLabel(tag+"_tp3_label",right,target,"TP3",clrMagenta);
   PriceLabel(tag+"_sl_label",right,stop,"SL",clrRed);
   PriceLabel(tag+"_signal",signalTime,entry,isBuy ? "BUY" : "SELL",isBuy ? clrLime : clrTomato);
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   if(rates_total<60 || time[1]==lastProcessedBar) return(rates_total);
   lastProcessedBar=time[1];
   datetime h4time=iTime(_Symbol,InpAMDTimeframe,1);
   double h4open=iOpen(_Symbol,InpAMDTimeframe,1), h4close=iClose(_Symbol,InpAMDTimeframe,1), h4low=iLow(_Symbol,InpAMDTimeframe,1);
   if(h4time>0 && h4time!=processedH4Time)
   {
      processedH4Time=h4time;
      if(h4low<=MathMin(h4open,h4close)+_Point*0.1)
      {
         amdTargetLow=h4low; amdTargetActive=true;
         if(InpShowAMDTarget) Line("AMD_TARGET",time[1],amdTargetLow,time[1]+PeriodSeconds(_Period)*InpPlanBarsRight,clrMagenta,STYLE_DASH);
      }
   }
   double swingHigh=LatestSwingHigh(high,rates_total), swingLow=LatestSwingLow(low,rates_total);
   bool bullishBreak=swingHigh>0 && close[1]>swingHigh && close[2]<=swingHigh;
   bool bearishBreak=swingLow>0 && close[1]<swingLow && close[2]>=swingLow;
   bool sweepHigh=swingHigh>0 && high[1]>swingHigh && close[1]<swingHigh;
   bool bearishFvg=high[1]<low[3];
   bool amdShort=amdTargetActive && close[1]>amdTargetLow && (bearishBreak || sweepHigh || bearishFvg);
   bool buy=InpStructureFallback && bullishBreak && !amdShort;
   bool sell=amdShort || (InpStructureFallback && bearishBreak);
   if((buy || sell) && (lastSignalTime==0 || (time[1]-lastSignalTime)>=PeriodSeconds(_Period)*InpCooldownBars))
   {
      lastSignalTime=time[1];
      double atr=AverageTrueRange(high,low,close,rates_total);
      double entry=NormalizeDouble(close[1],_Digits);
      double stop=buy ? MathMin(low[1],swingLow) : MathMax(high[1],swingHigh);
      if(buy) stop=MathMin(stop,entry-atr*InpMinStopATR); else stop=MathMax(stop,entry+atr*InpMinStopATR);
      stop=NormalizeDouble(stop,_Digits);
      double risk=MathAbs(entry-stop);
      double target=buy ? entry+risk*InpFallbackRR : (amdShort ? amdTargetLow : entry-risk*InpFallbackRR);
      DrawPlan(time[1],entry,stop,NormalizeDouble(target,_Digits),buy);
      if(amdShort) amdTargetActive=false;
   }
   return(rates_total);
}
