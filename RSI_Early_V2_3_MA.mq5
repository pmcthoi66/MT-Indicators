//+------------------------------------------------------------------+
//| Standard RSI + Early Momentum V2.3 + MA of native RSI             |
//| Early is an extrapolation, not a prediction probability.         |
//| Live values/colors can change; no future bars are used.          |
//| History corrections/reloads can recalculate closed-bar values.   |
//+------------------------------------------------------------------+
#property strict
#property version "2.30"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots 3
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30
#property indicator_level2 50
#property indicator_level3 70
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_label1 "RSI"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrLime
#property indicator_width1 1
#property indicator_label2 "Early Momentum"
#property indicator_type2 DRAW_COLOR_LINE
#property indicator_color2 clrDarkGray,clrDeepPink,clrGreen
#property indicator_width2 2
#property indicator_label3 "MA of RSI"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrViolet
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

input int                InpRSIPeriod       = 13;
input ENUM_APPLIED_PRICE InpPrice           = PRICE_CLOSE;
input bool               InpShowEarly       = true;
input int                InpMomentumPeriod  = 3;
input double             InpEarlyStrength   = 0.35;
input double             InpEarlyLimit      = 8.0;
input color              InpRSIColor        = clrLime;
input color              InpEarlyNeutral    = clrDarkGray;
input color              InpEarlyDown       = clrDeepPink;
input color              InpEarlyUp         = clrGreen;
input double InpMomentumAlpha = 0.50;
input double InpColorDeadband = 0.0;
// Appended inputs preserve all previous input positions.
input bool               InpShowMA   = true;      // Show MA of main RSI
input int                InpMAPeriod = 14;        // RSI average period
input ENUM_MA_METHOD     InpMAMethod = MODE_SMA;  // SMA / EMA / SMMA / LWMA
input color              InpMAColor  = clrViolet;

// Plot buffers are contiguous: RSI=0, Early=1, color=2, MA=3.
// Internal momentum calculation buffer moves to index 4.
double RSIBuffer[], EarlyBuffer[], EarlyColorBuffer[], MomentumBuffer[], MABuffer[];
double RsiCopy[], MACopy[];
int rsiHandle=INVALID_HANDLE, maHandle=INVALID_HANDLE;
datetime oldestTime=0, newestTime=0;

bool ValidRSI(const double value)
{
 return(MathIsValidNumber(value) && value!=EMPTY_VALUE && value>=0.0 && value<=100.0);
}
double ClampValue(const double value,const double minimum,const double maximum)
{
 return(MathMax(minimum,MathMin(maximum,value)));
}
int OnInit()
{
 if(InpRSIPeriod<2 || InpMomentumPeriod<1 || InpMAPeriod<1 ||
    !MathIsValidNumber(InpEarlyStrength) || InpEarlyStrength<0 ||
    !MathIsValidNumber(InpEarlyLimit) || InpEarlyLimit<0 ||
    !MathIsValidNumber(InpMomentumAlpha) || InpMomentumAlpha<=0 || InpMomentumAlpha>1 ||
    !MathIsValidNumber(InpColorDeadband) || InpColorDeadband<0 || InpColorDeadband>100 ||
    (int)InpPrice<(int)PRICE_CLOSE || (int)InpPrice>(int)PRICE_WEIGHTED ||
    (int)InpMAMethod<(int)MODE_SMA || (int)InpMAMethod>(int)MODE_LWMA)
    return(INIT_PARAMETERS_INCORRECT);
 SetIndexBuffer(0,RSIBuffer,INDICATOR_DATA);
 SetIndexBuffer(1,EarlyBuffer,INDICATOR_DATA);
 SetIndexBuffer(2,EarlyColorBuffer,INDICATOR_COLOR_INDEX);
 SetIndexBuffer(3,MABuffer,INDICATOR_DATA);
 SetIndexBuffer(4,MomentumBuffer,INDICATOR_CALCULATIONS);
 ArraySetAsSeries(RSIBuffer,false);
 ArraySetAsSeries(EarlyBuffer,false);
 ArraySetAsSeries(EarlyColorBuffer,false);
 ArraySetAsSeries(MomentumBuffer,false);
 ArraySetAsSeries(MABuffer,false);
 ArraySetAsSeries(RsiCopy,false);
 ArraySetAsSeries(MACopy,false);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,InpRSIColor);
 PlotIndexSetInteger(1,PLOT_COLOR_INDEXES,3);
 PlotIndexSetInteger(1,PLOT_LINE_COLOR,0,InpEarlyNeutral);
 PlotIndexSetInteger(1,PLOT_LINE_COLOR,1,InpEarlyDown);
 PlotIndexSetInteger(1,PLOT_LINE_COLOR,2,InpEarlyUp);
 for(int p=0;p<3;p++) PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpRSIPeriod);
 PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpRSIPeriod);
 PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,InpRSIPeriod+InpMAPeriod-1);
 PlotIndexSetInteger(2,PLOT_LINE_COLOR,InpMAColor);
 PlotIndexSetString(2,PLOT_LABEL,"MA RSI ("+(string)InpMAPeriod+", "+EnumToString(InpMAMethod)+")");
 if(!InpShowEarly) PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_NONE);
 if(!InpShowMA) PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_NONE);
 IndicatorSetString(INDICATOR_SHORTNAME,"RSI + Early V2.3 ("+(string)InpRSIPeriod+")"+(InpShowMA?" + MA("+(string)InpMAPeriod+")":""));
 IndicatorSetInteger(INDICATOR_DIGITS,2);
 rsiHandle=iRSI(_Symbol,_Period,InpRSIPeriod,InpPrice);
 if(rsiHandle==INVALID_HANDLE)
 {
  Print("Unable to create RSI handle. Error: ",GetLastError());
  return(INIT_FAILED);
 }
 if(InpShowMA)
 {
  // Native handle chaining: MA is applied to RSI, not to price or Early.
  maHandle=iMA(_Symbol,_Period,InpMAPeriod,0,InpMAMethod,rsiHandle);
  if(maHandle==INVALID_HANDLE)
  {
   Print("Unable to create RSI MA handle. Error: ",GetLastError());
   return(INIT_FAILED);
  }
 }
 oldestTime=0; newestTime=0;
 return(INIT_SUCCEEDED);
}
int OnCalculate(const int rates_total,const int prev_calculated,
 const datetime &time[],const double &open[],const double &high[],
 const double &low[],const double &close[],const long &tick_volume[],
 const long &volume[],const int &spread[])
{
 if(rates_total<1) return(0);
 ArraySetAsSeries(time,false);
 bool reset=prev_calculated<=0 || prev_calculated>rates_total ||
            oldestTime!=time[0] ||
            (prev_calculated==rates_total && newestTime!=time[rates_total-1]);
 int ready=reset?0:prev_calculated;
 int start=reset?0:MathMax(0,prev_calculated-1);
 int count=rates_total-start;
 if(BarsCalculated(rsiHandle)<rates_total) return(ready);
 if(CopyBuffer(rsiHandle,0,0,count,RsiCopy)!=count) return(ready);
 // Fetch both complete suffixes before modifying any output state.
 if(InpShowMA)
 {
  if(BarsCalculated(maHandle)<rates_total) return(ready);
  if(CopyBuffer(maHandle,0,0,count,MACopy)!=count) return(ready);
 }
 if(reset)
 {
  ArrayInitialize(RSIBuffer,EMPTY_VALUE);
  ArrayInitialize(EarlyBuffer,EMPTY_VALUE);
  ArrayInitialize(EarlyColorBuffer,0.0);
  ArrayInitialize(MomentumBuffer,0.0);
  ArrayInitialize(MABuffer,EMPTY_VALUE);
 }
 for(int i=start;i<rates_total && !IsStopped();++i)
 {
  RSIBuffer[i]=EMPTY_VALUE;
  EarlyBuffer[i]=EMPTY_VALUE;
  EarlyColorBuffer[i]=0.0;
  MomentumBuffer[i]=0.0;
  MABuffer[i]=EMPTY_VALUE;
  double rsi=RsiCopy[i-start];
  if(i<InpRSIPeriod || !ValidRSI(rsi)) continue;
  RSIBuffer[i]=rsi;
  // MA remains independent of the Early visibility and momentum settings.
  if(InpShowMA && i-InpRSIPeriod>=InpMAPeriod-1 && ValidRSI(MACopy[i-start]))
   MABuffer[i]=MACopy[i-start];
  if(!InpShowEarly) continue;
  EarlyBuffer[i]=rsi;
  if(i-InpRSIPeriod<InpMomentumPeriod) continue;
  int previous=i-InpMomentumPeriod;
  if(!ValidRSI(RSIBuffer[previous])) continue;
  double rawMomentum=rsi-RSIBuffer[previous];
  if(i-InpRSIPeriod==InpMomentumPeriod || !ValidRSI(RSIBuffer[i-1]))
   MomentumBuffer[i]=rawMomentum;
  else
   MomentumBuffer[i]=MomentumBuffer[i-1]+InpMomentumAlpha*(rawMomentum-MomentumBuffer[i-1]);
  double adjustment=ClampValue(MomentumBuffer[i]*InpEarlyStrength,-InpEarlyLimit,InpEarlyLimit);
  EarlyBuffer[i]=ClampValue(rsi+adjustment,0.0,100.0);
  if(!ValidRSI(EarlyBuffer[i-1])) continue;
  double delta=EarlyBuffer[i]-EarlyBuffer[i-1];
  if(delta>InpColorDeadband) EarlyColorBuffer[i]=2.0;
  else if(delta<-InpColorDeadband) EarlyColorBuffer[i]=1.0;
  else if(InpColorDeadband==0.0) EarlyColorBuffer[i]=EarlyColorBuffer[i-1];
 }
 if(IsStopped()) return(0);
 oldestTime=time[0]; newestTime=time[rates_total-1];
 return(rates_total);
}
void OnDeinit(const int reason)
{
 if(maHandle!=INVALID_HANDLE) {IndicatorRelease(maHandle);maHandle=INVALID_HANDLE;}
 if(rsiHandle!=INVALID_HANDLE) {IndicatorRelease(rsiHandle);rsiHandle=INVALID_HANDLE;}
 ArrayFree(RsiCopy); ArrayFree(MACopy);
}
