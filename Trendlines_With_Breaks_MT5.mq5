// Port of the Pine v5 source supplied by the user.
// Pivot confirmation, slope sampling, state and backpainting follow the source.
#property strict
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots 4
#property indicator_label1 "Upper"
#property indicator_type1 DRAW_LINE
#property indicator_label2 "Lower"
#property indicator_type2 DRAW_LINE
#property indicator_label3 "Upper Break"
#property indicator_type3 DRAW_NONE
#property indicator_label4 "Lower Break"
#property indicator_type4 DRAW_NONE

enum SlopeMethod { Atr, Stdev, Linreg };
input int SwingDetectionLookback=14;
input double Slope=1.0;
input SlopeMethod SlopeCalculationMethod=Atr;
input bool Backpaint=true;
input color UpTrendlineColor=C'0,137,123';
input color DownTrendlineColor=clrRed;
input bool ShowExtendedLines=true;
// Pine alertconditions require the user to create an alert; off by default here.
input bool EnablePopupAlerts=false;
input bool AlertsOnClosedBar=false;

double UpperPlot[],LowerPlot[],UpBreak[],DownBreak[];
double Upper[],Lower[],SlopePH[],SlopePL[],UpState[],DownState[],AtrValue[];
string prefix;
datetime lastUp=0,lastDown=0;

int OnInit()
{
 if(SwingDetectionLookback<1 || Slope<0) return INIT_PARAMETERS_INCORRECT;
 SetIndexBuffer(0,UpperPlot,INDICATOR_DATA);
 SetIndexBuffer(1,LowerPlot,INDICATOR_DATA);
 SetIndexBuffer(2,UpBreak,INDICATOR_DATA);
 SetIndexBuffer(3,DownBreak,INDICATOR_DATA);
 SetIndexBuffer(4,Upper,INDICATOR_CALCULATIONS);
 SetIndexBuffer(5,Lower,INDICATOR_CALCULATIONS);
 SetIndexBuffer(6,SlopePH,INDICATOR_CALCULATIONS);
 SetIndexBuffer(7,SlopePL,INDICATOR_CALCULATIONS);
 SetIndexBuffer(8,UpState,INDICATOR_CALCULATIONS);
 SetIndexBuffer(9,DownState,INDICATOR_CALCULATIONS);
 SetIndexBuffer(10,AtrValue,INDICATOR_CALCULATIONS);
 for(int p=0;p<4;p++) PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,UpTrendlineColor);
 PlotIndexSetInteger(1,PLOT_LINE_COLOR,DownTrendlineColor);
 PlotIndexSetInteger(0,PLOT_SHIFT,Backpaint ? -SwingDetectionLookback : 0);
 PlotIndexSetInteger(1,PLOT_SHIFT,Backpaint ? -SwingDetectionLookback : 0);
 IndicatorSetString(INDICATOR_SHORTNAME,"Trendlines with Breaks MT5");
 IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
 prefix="TWB_"+IntegerToString(ChartID())+"_"+IntegerToString((long)GetMicrosecondCount())+"_";
 return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { ObjectsDeleteAll(0,prefix); }

void BreakLabel(string name,datetime t,double price,bool up)
{
 if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,price);
 ObjectMove(0,name,0,t,price);
 ObjectSetString(0,name,OBJPROP_TEXT,up ? "B\n\x25B2" : "\x25BC\nB");
 ObjectSetString(0,name,OBJPROP_FONT,"Arial");
 ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
 ObjectSetInteger(0,name,OBJPROP_COLOR,up ? UpTrendlineColor : DownTrendlineColor);
 ObjectSetInteger(0,name,OBJPROP_ANCHOR,up ? ANCHOR_UPPER : ANCHOR_LOWER);
 ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
 ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
void Extension(string name,datetime t1,double p1,datetime t2,double p2,color c)
{
 if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
 ObjectMove(0,name,0,t1,p1); ObjectMove(0,name,1,t2,p2);
 ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
 ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
 ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
 ObjectSetInteger(0,name,OBJPROP_COLOR,c);
 ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
 ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
 const double &open[],const double &high[],const double &low[],const double &close[],
 const long &tick_volume[],const long &volume[],const int &spread[])
{
 ArraySetAsSeries(time,false); ArraySetAsSeries(high,false);
 ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
 int L=SwingDetectionLookback;
 if(rates_total<1) return 0;
 int start=prev_calculated>0 && prev_calculated<=rates_total ? prev_calculated-1 : 0;
 if(start==0) {ObjectsDeleteAll(0,prefix); lastUp=0; lastDown=0;}
 // Recreate the last confirmed extension, so a provisional pivot can disappear intrabar.
 int latestPH=-1,latestPL=-1;
 for(int i=start;i<rates_total;i++)
 {
  double tr=high[i]-low[i];
  if(i>0) tr=MathMax(tr,MathMax(MathAbs(high[i]-close[i-1]),MathAbs(low[i]-close[i-1])));
  AtrValue[i]=EMPTY_VALUE;
  if(i==L-1)
  {
   double sum=0;
   for(int k=0;k<L;k++) { int j=i-k; double v=high[j]-low[j];
    if(j>0) v=MathMax(v,MathMax(MathAbs(high[j]-close[j-1]),MathAbs(low[j]-close[j-1])));
    sum+=v;
   }
   AtrValue[i]=sum/L;
  }
  else if(i>=L) AtrValue[i]=(AtrValue[i-1]*(L-1)+tr)/L;
  double slope=EMPTY_VALUE;
  if(i>=L-1)
  {
   if(SlopeCalculationMethod==Atr) slope=AtrValue[i]/L*Slope;
   else
   {
    double mean=0; for(int k=0;k<L;k++) mean+=close[i-k]; mean/=L;
    double variance=0,covariance=0,xvariance=0;
    for(int k=0;k<L;k++)
    {
     double dy=close[i-k]-mean,dx=(L-1)/2.0-k;
     variance+=dy*dy; covariance+=dy*dx; xvariance+=dx*dx;
    }
    slope=SlopeCalculationMethod==Stdev ? MathSqrt(variance/L)/L*Slope :
       (xvariance>0 ? MathAbs(covariance/xvariance)/2.0*Slope : EMPTY_VALUE);
   }
  }
  bool ph=false,pl=false; int pivot=i-L;
  if(i>=2*L)
  {
   ph=true; pl=true;
   for(int k=1;k<=L;k++)
   {
    // Pine selects the most recent occurrence when pivot extremes tie.
    if(high[pivot]<high[pivot-k] || high[pivot]<=high[pivot+k]) ph=false;
    if(low[pivot]>low[pivot-k] || low[pivot]>=low[pivot+k]) pl=false;
   }
   ph=ph && high[pivot]!=0; pl=pl && low[pivot]!=0;
  }
  double oldU=i>0?Upper[i-1]:0, oldD=i>0?Lower[i-1]:0;
  SlopePH[i]=ph?slope:(i>0?SlopePH[i-1]:0);
  SlopePL[i]=pl?slope:(i>0?SlopePL[i-1]:0);
  Upper[i]=ph?high[pivot]:oldU-SlopePH[i];
  Lower[i]=pl?low[pivot]:oldD+SlopePL[i];
  double u=Upper[i]-SlopePH[i]*L,d=Lower[i]+SlopePL[i]*L;
  double oldUS=i>0?UpState[i-1]:0,oldDS=i>0?DownState[i-1]:0;
  UpState[i]=ph?0:(close[i]>u?1:oldUS);
  DownState[i]=pl?0:(close[i]<d?1:oldDS);
  UpperPlot[i]=ph?EMPTY_VALUE:(Backpaint?Upper[i]:u);
  LowerPlot[i]=pl?EMPTY_VALUE:(Backpaint?Lower[i]:d);
  bool ub=i>0 && UpState[i]>oldUS, db=i>0 && DownState[i]>oldDS;
  UpBreak[i]=ub?low[i]:EMPTY_VALUE; DownBreak[i]=db?high[i]:EMPTY_VALUE;
  string un=prefix+"BUp_"+IntegerToString((long)time[i]);
  string dn=prefix+"BDn_"+IntegerToString((long)time[i]);
  if(ub) BreakLabel(un,time[i],low[i],true); else ObjectDelete(0,un);
  if(db) BreakLabel(dn,time[i],high[i],false); else ObjectDelete(0,dn);
  if(ph) latestPH=i; if(pl) latestPL=i;
 }
 // Find the latest valid pivot if the recalculated tail did not contain one.
 for(int i=rates_total-1;i>=2*L && (latestPH<0 || latestPL<0);i--)
 {
  int p=i-L; bool ph=true,pl=true;
  for(int k=1;k<=L;k++)
  {
   if(high[p]<high[p-k] || high[p]<=high[p+k]) ph=false;
   if(low[p]>low[p-k] || low[p]>=low[p+k]) pl=false;
  }
  if(latestPH<0 && ph && high[p]!=0) latestPH=i;
  if(latestPL<0 && pl && low[p]!=0) latestPL=i;
 }
 if(ShowExtendedLines)
 {
  if(latestPH>=0)
  {
   int i=latestPH,j=Backpaint?i-L:i;
   double v=Backpaint?high[i-L]:Upper[i]-SlopePH[i]*L;
   datetime t2=j+1<rates_total?time[j+1]:(datetime)(time[j]+PeriodSeconds(_Period));
   Extension(prefix+"UpperRay",time[j],v,t2,v-SlopePH[i],UpTrendlineColor);
  }
  else ObjectDelete(0,prefix+"UpperRay");
  if(latestPL>=0)
  {
   int i=latestPL,j=Backpaint?i-L:i;
   double v=Backpaint?low[i-L]:Lower[i]+SlopePL[i]*L;
   datetime t2=j+1<rates_total?time[j+1]:(datetime)(time[j]+PeriodSeconds(_Period));
   Extension(prefix+"LowerRay",time[j],v,t2,v+SlopePL[i],DownTrendlineColor);
  }
  else ObjectDelete(0,prefix+"LowerRay");
 }
 if(EnablePopupAlerts && prev_calculated>0)
 {
  int a=rates_total-(AlertsOnClosedBar?2:1);
  if(a>=0)
  {
   if(UpBreak[a]!=EMPTY_VALUE && lastUp!=time[a])
   {lastUp=time[a]; Alert(_Symbol," ",EnumToString(_Period),": Price broke the down-trendline upward");}
   if(DownBreak[a]!=EMPTY_VALUE && lastDown!=time[a])
   {lastDown=time[a]; Alert(_Symbol," ",EnumToString(_Period),": Price broke the up-trendline downward");}
  }
 }
 return rates_total;
}
