//+------------------------------------------------------------------+
//| Standard RSI + Early Momentum V2.2                               |
//| Core: native MT5 iRSI, unchanged applied price and RSI period.    |
//| Early is an extrapolation, not a prediction probability.         |
//| Live bar values/colors can change; no future bars are used.      |
//| History corrections/reloads can recalculate closed-bar values.   |
//+------------------------------------------------------------------+
#property strict
#property version "2.20"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 2
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

input int                InpRSIPeriod       = 13;          // RSI period
input ENUM_APPLIED_PRICE InpPrice           = PRICE_CLOSE; // Price

input bool               InpShowEarly       = true;        // Show early line
input int                InpMomentumPeriod  = 3;           // Momentum lookback
input double             InpEarlyStrength   = 0.35;        // Early strength
input double             InpEarlyLimit      = 8.0;         // Maximum early adjustment

//--- màu RSI chính
input color              InpRSIColor        = clrLime;

//--- màu Early Momentum
input color              InpEarlyNeutral    = clrDarkGray;
input color              InpEarlyDown       = clrDeepPink;
input color              InpEarlyUp         = clrGreen;

// New parameters appended to preserve previous input positions.
input double InpMomentumAlpha = 0.50; // Momentum smoothing (0 < alpha <= 1)
input double InpColorDeadband = 0.0;   // Neutral color when Early change <= RSI points

// Existing output buffer indexes are preserved.
double RSIBuffer[], EarlyBuffer[], EarlyColorBuffer[];
double MomentumBuffer[];
double RsiCopy[];
int rsiHandle=INVALID_HANDLE;
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
   if(InpRSIPeriod<2 || InpMomentumPeriod<1 ||
      !MathIsValidNumber(InpEarlyStrength) || InpEarlyStrength<0 ||
      !MathIsValidNumber(InpEarlyLimit) || InpEarlyLimit<0 ||
      !MathIsValidNumber(InpMomentumAlpha) || InpMomentumAlpha<=0 || InpMomentumAlpha>1 ||
      !MathIsValidNumber(InpColorDeadband) || InpColorDeadband<0 || InpColorDeadband>100 ||
      (int)InpPrice<(int)PRICE_CLOSE || (int)InpPrice>(int)PRICE_WEIGHTED)
      return(INIT_PARAMETERS_INCORRECT);
   SetIndexBuffer(0,RSIBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,EarlyBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,EarlyColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,MomentumBuffer,INDICATOR_CALCULATIONS);
   ArraySetAsSeries(RSIBuffer,false);
   ArraySetAsSeries(EarlyBuffer,false);
   ArraySetAsSeries(EarlyColorBuffer,false);
   ArraySetAsSeries(MomentumBuffer,false);
   ArraySetAsSeries(RsiCopy,false);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,InpRSIColor);
   PlotIndexSetInteger(1,PLOT_COLOR_INDEXES,3);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,0,InpEarlyNeutral);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,1,InpEarlyDown);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,2,InpEarlyUp);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpRSIPeriod);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpRSIPeriod);
   if(!InpShowEarly) PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_NONE);
   IndicatorSetString(INDICATOR_SHORTNAME,"RSI V2.2 ("+(string)InpRSIPeriod+")");
   IndicatorSetInteger(INDICATOR_DIGITS,2);
   rsiHandle=iRSI(_Symbol,_Period,InpRSIPeriod,InpPrice);
   if(rsiHandle==INVALID_HANDLE)
     {
      Print("Unable to create RSI handle. Error: ",GetLastError());
      return(INIT_FAILED);
     }
   oldestTime=0;
   newestTime=0;
   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],
                const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<1) return(0);
   ArraySetAsSeries(time,false);
   // Detect history replacement and charts with a fixed maximum bar count.
   bool reset=prev_calculated<=0 || prev_calculated>rates_total ||
              oldestTime!=time[0] ||
              (prev_calculated==rates_total && newestTime!=time[rates_total-1]);
   int ready=reset ? 0 : prev_calculated;
   int start=reset ? 0 : MathMax(0,prev_calculated-1);
   int count=rates_total-start;
   if(BarsCalculated(rsiHandle)<rates_total) return(ready);
   // Retain a scratch copy across calls; require the entire requested suffix.
   // CopyBuffer places the oldest copied value first (chronological order).
   if(CopyBuffer(rsiHandle,0,0,count,RsiCopy)!=count) return(ready);
   if(reset)
     {
      ArrayInitialize(RSIBuffer,EMPTY_VALUE);
      ArrayInitialize(EarlyBuffer,EMPTY_VALUE);
      ArrayInitialize(EarlyColorBuffer,0.0);
      ArrayInitialize(MomentumBuffer,0.0);
     }
   for(int i=start; i<rates_total && !IsStopped(); ++i)
     {
      RSIBuffer[i]=EMPTY_VALUE;
      EarlyBuffer[i]=EMPTY_VALUE;
      EarlyColorBuffer[i]=0.0;
      MomentumBuffer[i]=0.0;
      double rsi=RsiCopy[i-start];
      if(i<InpRSIPeriod || !ValidRSI(rsi)) continue;
      RSIBuffer[i]=rsi;
      if(!InpShowEarly) continue;
      EarlyBuffer[i]=rsi;
      // Before enough valid RSI bars exist, display RSI with neutral color.
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
      else if(InpColorDeadband==0.0)
         EarlyColorBuffer[i]=EarlyColorBuffer[i-1]; // Preserve original equal-value behavior.
      // Positive deadband: small slope gets neutral instead of stale direction.
     }
   if(IsStopped()) return(0);
   oldestTime=time[0];
   newestTime=time[rates_total-1];
   return(rates_total);
  }

void OnDeinit(const int reason)
  {
   if(rsiHandle!=INVALID_HANDLE) IndicatorRelease(rsiHandle);
  }
