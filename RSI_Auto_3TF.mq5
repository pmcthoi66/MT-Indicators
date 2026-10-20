// RSI Auto 4TF - MT5.
// Historical points use RSI bars closed at that time.
// Added: SMA 7 of the current chart timeframe RSI.
#property copyright "RSI Auto 4TF"
#property version "1.21"
#property strict
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots 5

#property indicator_type1 DRAW_LINE
#property indicator_type2 DRAW_LINE
#property indicator_type3 DRAW_LINE
#property indicator_type4 DRAW_LINE
#property indicator_type5 DRAW_LINE

#property indicator_color1 clrWhite
#property indicator_color2 clrGreen
#property indicator_color3 clrOrange
#property indicator_color4 clrViolet
#property indicator_color5 clrYellow

#property indicator_style1 STYLE_DOT
#property indicator_style2 STYLE_SOLID
#property indicator_style3 STYLE_DASH
#property indicator_style4 STYLE_DASHDOT
#property indicator_style5 STYLE_SOLID

#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 1
#property indicator_width4 1
#property indicator_width5 1

#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 30
#property indicator_level2 50
#property indicator_level3 70
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

input int InpRSIPeriod=14;
input ENUM_APPLIED_PRICE InpPrice=PRICE_CLOSE;
input int InpHistoryBars=3000;       // Maximum chart bars
input bool InpLiveCurrentBar=true;  // Live RSI on the current chart bar

input color InpLowerColor=clrWhite;
input color InpCurrentColor=clrGreen;
input color InpHigherColor=clrOrange;
input color InpFourthColor=clrViolet;

input bool InpAutoTimeframes=true;
input ENUM_TIMEFRAMES InpTF1=PERIOD_M1;
input ENUM_TIMEFRAMES InpTF2=PERIOD_CURRENT;
input ENUM_TIMEFRAMES InpTF3=PERIOD_M15;
input ENUM_TIMEFRAMES InpTF4=PERIOD_H1;

double Lower[],Current[],Higher[],Fourth[],SMA7[];

ENUM_TIMEFRAMES TF[5];

int Handles[5]=
{
 INVALID_HANDLE,
 INVALID_HANDLE,
 INVALID_HANDLE,
 INVALID_HANDLE,
 INVALID_HANDLE
};

int SMAInputHandle=INVALID_HANDLE;

datetime LastNewest=0,LastOldest=0;

//------------------------------------------------------------------
string TFName(ENUM_TIMEFRAMES tf)
{
 string s=EnumToString(tf);
 StringReplace(s,"PERIOD_","");
 return s;
}

//------------------------------------------------------------------
void SelectFrames()
{
 if(!InpAutoTimeframes)
 {
  TF[0]=InpTF1;
  TF[1]=InpTF2;
  TF[2]=InpTF3;
  TF[3]=InpTF4;

  for(int k=0;k<4;k++)
   if(TF[k]==PERIOD_CURRENT)
    TF[k]=(ENUM_TIMEFRAMES)_Period;

  return;
 }

 if(_Period==PERIOD_M15)
 {
  TF[0]=PERIOD_M1;
  TF[1]=PERIOD_M5;
  TF[2]=PERIOD_M15;
  TF[3]=PERIOD_H1;
  return;
 }

 if(_Period==PERIOD_H1)
 {
  TF[0]=PERIOD_M5;
  TF[1]=PERIOD_M15;
  TF[2]=PERIOD_H1;
  TF[3]=PERIOD_H4;
  return;
 }

 if(_Period==PERIOD_H4)
 {
  TF[0]=PERIOD_M15;
  TF[1]=PERIOD_H1;
  TF[2]=PERIOD_H4;
  TF[3]=PERIOD_D1;
  return;
 }

 if(_Period==PERIOD_D1)
 {
  TF[0]=PERIOD_H1;
  TF[1]=PERIOD_H4;
  TF[2]=PERIOD_D1;
  TF[3]=PERIOD_W1;
  return;
 }

 ENUM_TIMEFRAMES ladder[]=
 {
  PERIOD_M1,
  PERIOD_M5,
  PERIOD_M15,
  PERIOD_H1,
  PERIOD_H4,
  PERIOD_D1,
  PERIOD_W1,
  PERIOD_MN1
 };

 TF[1]=(ENUM_TIMEFRAMES)_Period;
 TF[0]=PERIOD_M1;
 TF[2]=PERIOD_MN1;

 int sec=PeriodSeconds(TF[1]);

 for(int i=0;i<ArraySize(ladder);i++)
 {
  int n=PeriodSeconds(ladder[i]);

  if(n<sec)
   TF[0]=ladder[i];

  if(n>sec)
  {
   TF[2]=ladder[i];
   break;
  }
 }

 if(_Period==PERIOD_M1)
 {
  TF[0]=PERIOD_M5;
  TF[2]=PERIOD_M15;
 }

 if(_Period==PERIOD_MN1)
 {
  TF[0]=PERIOD_D1;
  TF[2]=PERIOD_W1;
 }

 TF[3]=PERIOD_CURRENT;

 for(int j=0;j<ArraySize(ladder);j++)
 {
  if(PeriodSeconds(ladder[j])>PeriodSeconds(TF[2]) &&
     ladder[j]!=TF[0] && ladder[j]!=TF[1])
  {
   TF[3]=ladder[j];
   break;
  }
 }

 if(TF[3]==PERIOD_CURRENT)
 {
  for(int j=ArraySize(ladder)-1;j>=0;j--)
  {
   if(ladder[j]!=TF[0] &&
      ladder[j]!=TF[1] &&
      ladder[j]!=TF[2])
   {
    TF[3]=ladder[j];
    break;
   }
  }
 }
}

//------------------------------------------------------------------
int OnInit()
{
 if(InpRSIPeriod<2 || InpHistoryBars<100)
  return INIT_PARAMETERS_INCORRECT;

 SetIndexBuffer(0,Lower,INDICATOR_DATA);
 SetIndexBuffer(1,Current,INDICATOR_DATA);
 SetIndexBuffer(2,Higher,INDICATOR_DATA);
 SetIndexBuffer(3,Fourth,INDICATOR_DATA);
 SetIndexBuffer(4,SMA7,INDICATOR_DATA);

 ArraySetAsSeries(Lower,true);
 ArraySetAsSeries(Current,true);
 ArraySetAsSeries(Higher,true);
 ArraySetAsSeries(Fourth,true);
 ArraySetAsSeries(SMA7,true);

 SelectFrames();

 color colors[]=
 {
  InpLowerColor,
  InpCurrentColor,
  InpHigherColor,
  InpFourthColor
 };

 ENUM_LINE_STYLE styles[]=
 {
  STYLE_DOT,
  STYLE_SOLID,
  STYLE_DASH,
  STYLE_DASHDOT
 };

 string title="RSI 4TF ("+IntegerToString(InpRSIPeriod)+") ";

 for(int k=0;k<4;k++)
 {
  Handles[k]=iRSI(_Symbol,TF[k],InpRSIPeriod,InpPrice);

  if(Handles[k]==INVALID_HANDLE)
   return INIT_FAILED;

  PlotIndexSetString(k,PLOT_LABEL,"RSI "+TFName(TF[k]));
  PlotIndexSetInteger(k,PLOT_LINE_COLOR,colors[k]);
  PlotIndexSetInteger(k,PLOT_LINE_WIDTH,1);

  PlotIndexSetInteger(
   k,
   PLOT_LINE_STYLE,
   TF[k]==(ENUM_TIMEFRAMES)_Period
   ? STYLE_SOLID
   : (k==1 ? STYLE_DASHDOTDOT : styles[k])
  );

  PlotIndexSetDouble(k,PLOT_EMPTY_VALUE,EMPTY_VALUE);

  title+=TFName(TF[k])+(k<3 ? " / " : "");
 }

 // SMA 7 uses the RSI of the current chart timeframe.
 TF[4]=(ENUM_TIMEFRAMES)_Period;

 SMAInputHandle=iRSI(
  _Symbol,
  TF[4],
  InpRSIPeriod,
  InpPrice
 );

 if(SMAInputHandle==INVALID_HANDLE)
  return INIT_FAILED;

 Handles[4]=iMA(
  _Symbol,
  TF[4],
  7,
  0,
  MODE_SMA,
  SMAInputHandle
 );

 if(Handles[4]==INVALID_HANDLE)
  return INIT_FAILED;

 PlotIndexSetString(
  4,
  PLOT_LABEL,
  "RSI SMA 7 "+TFName(TF[4])
 );

 PlotIndexSetInteger(4,PLOT_LINE_COLOR,clrYellow);
 PlotIndexSetInteger(4,PLOT_LINE_WIDTH,1);
 PlotIndexSetInteger(4,PLOT_LINE_STYLE,STYLE_SOLID);
 PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,EMPTY_VALUE);

 IndicatorSetString(
  INDICATOR_SHORTNAME,
  title+" | SMA 7 "+TFName(TF[4])
 );

 IndicatorSetInteger(INDICATOR_DIGITS,2);

 return INIT_SUCCEEDED;
}

//------------------------------------------------------------------
bool FillLine(
 const int k,
 double &dest[],
 const datetime &times[],
 const int count
)
{
 int oldest=iBarShift(
  _Symbol,
  TF[k],
  times[count-1],
  false
 );

 if(oldest<0)
  return false;

 int available=BarsCalculated(Handles[k]);

 // SMA 7 requires six additional RSI values.
 int warmup=InpRSIPeriod+(k==4 ? 6 : 0);

 if(available<=warmup)
  return false;

 int wanted=MathMin(oldest+3,available);

 double values[];
 datetime opens[];

 ArraySetAsSeries(values,true);
 ArraySetAsSeries(opens,true);

 int copied=CopyBuffer(
  Handles[k],
  0,
  0,
  wanted,
  values
 );

 int dated=CopyTime(
  _Symbol,
  TF[k],
  0,
  wanted,
  opens
 );

 if(copied!=wanted || dated!=wanted)
  return false;

 for(int i=count-1;i>=0;i--)
 {
  bool live=(i==0 && InpLiveCurrentBar);

  datetime endpoint=(
   i==0 ? TimeCurrent() : times[i-1]
  );

  int shift=iBarShift(
   _Symbol,
   TF[k],
   endpoint,
   false
  );

  if(shift<0 || shift>=wanted)
  {
   dest[i]=EMPTY_VALUE;
   continue;
  }

  // Use only closed source candles unless the current point is live.
  if(!live)
  {
   if(shift==0 || opens[shift-1]>endpoint)
    shift++;
  }

  dest[i]=(
   shift<wanted && shift<available-warmup
   ? values[shift]
   : EMPTY_VALUE
  );
 }

 return true;
}

//------------------------------------------------------------------
int OnCalculate(
 const int rates_total,
 const int prev_calculated,
 const datetime &time[],
 const double &open[],
 const double &high[],
 const double &low[],
 const double &close[],
 const long &tick_volume[],
 const long &volume[],
 const int &spread[]
)
{
 if(rates_total<2)
  return 0;

 ArraySetAsSeries(time,true);

 bool reset=(
  prev_calculated<=0 ||
  prev_calculated>rates_total ||
  LastOldest!=time[rates_total-1] ||
  (prev_calculated==rates_total && LastNewest!=time[0])
 );

 if(reset)
 {
  ArrayInitialize(Lower,EMPTY_VALUE);
  ArrayInitialize(Current,EMPTY_VALUE);
  ArrayInitialize(Higher,EMPTY_VALUE);
  ArrayInitialize(Fourth,EMPTY_VALUE);
  ArrayInitialize(SMA7,EMPTY_VALUE);
 }

 int total=MathMin(rates_total,InpHistoryBars);

 int count=(
  reset
  ? total
  : MathMin(total,rates_total-prev_calculated+2)
 );

 if(count<1)
  count=1;

 bool a=FillLine(0,Lower,time,count);
 bool b=FillLine(1,Current,time,count);
 bool c=FillLine(2,Higher,time,count);
 bool d=FillLine(3,Fourth,time,count);
 bool e=FillLine(4,SMA7,time,count);

 if(total<rates_total)
 {
  Lower[total]=EMPTY_VALUE;
  Current[total]=EMPTY_VALUE;
  Higher[total]=EMPTY_VALUE;
  Fourth[total]=EMPTY_VALUE;
  SMA7[total]=EMPTY_VALUE;
 }

 if(a && b && c && d && e)
 {
  LastNewest=time[0];
  LastOldest=time[rates_total-1];
  return rates_total;
 }

 return 0;
}

//------------------------------------------------------------------
void OnDeinit(const int reason)
{
 for(int k=4;k>=0;k--)
 {
  if(Handles[k]!=INVALID_HANDLE)
  {
   IndicatorRelease(Handles[k]);
   Handles[k]=INVALID_HANDLE;
  }
 }

 if(SMAInputHandle!=INVALID_HANDLE)
 {
  IndicatorRelease(SMAInputHandle);
  SMAInputHandle=INVALID_HANDLE;
 }
}