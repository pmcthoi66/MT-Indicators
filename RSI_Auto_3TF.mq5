// RSI Auto 4TF - MT5.
// Historical points use RSI bars closed at that time.
// Added: SMA 7 of the current chart timeframe RSI.
#property copyright "RSI Auto 4TF"
#property version "1.31"
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
int Pending[5]={0,0,0,0,0};
ulong RetryAfter[5]={0,0,0,0,0};
datetime SourceFirst[5]={0,0,0,0,0};
int CalculatedSeen[5]={0,0,0,0,0};

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
bool ValidFrame(const ENUM_TIMEFRAMES tf)
{
 switch(tf)
 {
  case PERIOD_M1: case PERIOD_M2: case PERIOD_M3: case PERIOD_M4:
  case PERIOD_M5: case PERIOD_M6: case PERIOD_M10: case PERIOD_M12:
  case PERIOD_M15: case PERIOD_M20: case PERIOD_M30:
  case PERIOD_H1: case PERIOD_H2: case PERIOD_H3: case PERIOD_H4:
  case PERIOD_H6: case PERIOD_H8: case PERIOD_H12:
  case PERIOD_D1: case PERIOD_W1: case PERIOD_MN1: return true;
 }
 return false;
}

bool ValidRSI(const double value)
{
 return value!=EMPTY_VALUE && MathIsValidNumber(value) && value>=0.0 && value<=100.0;
}

// Calendar months cannot be represented by PeriodSeconds(PERIOD_MN1).
datetime BarClose(const datetime opened,const ENUM_TIMEFRAMES tf)
{
 if(tf==PERIOD_MN1)
 {
  MqlDateTime parts;
  if(!TimeToStruct(opened,parts)) return 0;
  parts.day=1; parts.hour=0; parts.min=0; parts.sec=0;
  if(++parts.mon>12) { parts.mon=1; parts.year++; }
  return StructToTime(parts);
 }
 int seconds=PeriodSeconds(tf);
 return seconds>0 ? opened+seconds : 0;
}

void ReleaseSources()
{
 // Release the dependent SMA before its input and each borrowed RSI once.
 for(int k=4;k>=0;k--)
 {
  int handle=Handles[k];
  if(handle==INVALID_HANDLE) continue;
  for(int j=0;j<k;j++)
   if(Handles[j]==handle) Handles[j]=INVALID_HANDLE;
  if(SMAInputHandle==handle) SMAInputHandle=INVALID_HANDLE;
  IndicatorRelease(handle);
  Handles[k]=INVALID_HANDLE;
 }
 if(SMAInputHandle!=INVALID_HANDLE)
 {
  IndicatorRelease(SMAInputHandle);
  SMAInputHandle=INVALID_HANDLE;
 }
}

//------------------------------------------------------------------
int OnInit()
{
 ReleaseSources();
 if(InpRSIPeriod<2 || InpHistoryBars<100 ||
    (int)InpPrice<(int)PRICE_CLOSE || (int)InpPrice>(int)PRICE_WEIGHTED)
  return INIT_PARAMETERS_INCORRECT;
 SelectFrames();
 TF[4]=(ENUM_TIMEFRAMES)_Period;
 for(int k=0;k<5;k++)
  if(!ValidFrame(TF[k])) return INIT_PARAMETERS_INCORRECT;

 if(!SetIndexBuffer(0,Lower,INDICATOR_DATA) ||
    !SetIndexBuffer(1,Current,INDICATOR_DATA) ||
    !SetIndexBuffer(2,Higher,INDICATOR_DATA) ||
    !SetIndexBuffer(3,Fourth,INDICATOR_DATA) ||
    !SetIndexBuffer(4,SMA7,INDICATOR_DATA)) return INIT_FAILED;
 ArraySetAsSeries(Lower,true);
 ArraySetAsSeries(Current,true);
 ArraySetAsSeries(Higher,true);
 ArraySetAsSeries(Fourth,true);
 ArraySetAsSeries(SMA7,true);

 LastNewest=0; LastOldest=0;
 for(int k=0;k<5;k++)
 {
  Pending[k]=0; RetryAfter[k]=0; SourceFirst[k]=0; CalculatedSeen[k]=0;
 }
 color colors[]={InpLowerColor,InpCurrentColor,InpHigherColor,InpFourthColor};
 ENUM_LINE_STYLE styles[]={STYLE_DOT,STYLE_SOLID,STYLE_DASH,STYLE_DASHDOT};
 string title="RSI 4TF ("+IntegerToString(InpRSIPeriod)+") ";
 for(int k=0;k<4;k++)
 {
  Handles[k]=INVALID_HANDLE;
  for(int j=0;j<k;j++)
   if(TF[j]==TF[k]) { Handles[k]=Handles[j]; break; }
  if(Handles[k]==INVALID_HANDLE)
   Handles[k]=iRSI(_Symbol,TF[k],InpRSIPeriod,InpPrice);
  if(Handles[k]==INVALID_HANDLE) { ReleaseSources(); return INIT_FAILED; }
  PlotIndexSetString(k,PLOT_LABEL,"RSI "+TFName(TF[k]));
  PlotIndexSetInteger(k,PLOT_LINE_COLOR,colors[k]);
  PlotIndexSetInteger(k,PLOT_LINE_WIDTH,1);
  PlotIndexSetInteger(k,PLOT_LINE_STYLE,TF[k]==(ENUM_TIMEFRAMES)_Period
                      ? STYLE_SOLID : (k==1 ? STYLE_DASHDOTDOT : styles[k]));
  PlotIndexSetDouble(k,PLOT_EMPTY_VALUE,EMPTY_VALUE);
  title+=TFName(TF[k])+(k<3 ? " / " : "");
 }
 SMAInputHandle=INVALID_HANDLE;
 for(int k=0;k<4;k++)
  if(TF[k]==TF[4]) { SMAInputHandle=Handles[k]; break; }
 if(SMAInputHandle==INVALID_HANDLE)
  SMAInputHandle=iRSI(_Symbol,TF[4],InpRSIPeriod,InpPrice);
 if(SMAInputHandle==INVALID_HANDLE) { ReleaseSources(); return INIT_FAILED; }
 Handles[4]=iMA(_Symbol,TF[4],7,0,MODE_SMA,SMAInputHandle);
 if(Handles[4]==INVALID_HANDLE) { ReleaseSources(); return INIT_FAILED; }
 PlotIndexSetString(4,PLOT_LABEL,"RSI SMA 7 "+TFName(TF[4]));
 PlotIndexSetInteger(4,PLOT_LINE_COLOR,clrYellow);
 PlotIndexSetInteger(4,PLOT_LINE_WIDTH,1);
 PlotIndexSetInteger(4,PLOT_LINE_STYLE,STYLE_SOLID);
 PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 IndicatorSetString(INDICATOR_SHORTNAME,title+" | SMA 7 "+TFName(TF[4])+
                    (InpLiveCurrentBar ? " | live current" : " | closed sources"));
 IndicatorSetInteger(INDICATOR_DIGITS,2);
 return INIT_SUCCEEDED;
}

void ClearLine(double &dest[],const int first,const int end)
{
 for(int i=first;i<end && !_StopFlag;i++) dest[i]=EMPTY_VALUE;
}

// Position of the newest source opening not later than the requested time.
// Cache arrays use chronological order, unlike the five plot buffers.
int SourcePosition(const datetime &opens[],const datetime endpoint)
{
 int left=0,right=ArraySize(opens);
 while(left<right)
 {
  int middle=left+(right-left)/2;
  if(opens[middle]<=endpoint) left=middle+1;
  else right=middle;
 }
 return left-1;
}

int ChartShift(const datetime &times[],const int count,const datetime stamp)
{
 int left=0,right=count-1;
 while(left<=right)
 {
  int middle=left+(right-left)/2;
  if(times[middle]==stamp) return middle;
  if(times[middle]>stamp) left=middle+1;
  else right=middle-1;
 }
 return -1;
}

bool SourceStable(const int k,const int sourceBars,const datetime newest)
{
 return !_StopFlag && iBars(_Symbol,TF[k])==sourceBars && iTime(_Symbol,TF[k],0)==newest;
}

// A successful read of the requested date is the readiness authority. An RSI
// handle need not have calculated every bar reported by iBars(). The request
// also starts on-demand calculation on a non-chart timeframe.
bool ReadExact(const int k,const datetime opened,const int sourceBars,
               const datetime newest,double &value)
{
 value=EMPTY_VALUE;
 if(!SourceStable(k,sourceBars,newest)) return false;
 double sample[];
 ArraySetAsSeries(sample,false);
 int copied=CopyBuffer(Handles[k],0,(datetime)opened,(datetime)opened,sample);
 if(copied!=1 || ArraySize(sample)!=1 || !SourceStable(k,sourceBars,newest) ||
    !ValidRSI(sample[0])) return false;
 value=sample[0];
 return true;
}

// Bind bulk values to absolute dates. A partial response has no assumed
// position: discard it, then resolve only the selected dates individually.
bool SourceChunk(const int k,const int first,const int limit,
                 const int sourceBars,const datetime newest,
                 double &values[],datetime &opens[],int &state[])
{
 if(!SourceStable(k,sourceBars,newest)) return false;
 int wanted=MathMin(limit,sourceBars-first);
 if(wanted<1) return false;
 ArraySetAsSeries(values,false);
 ArraySetAsSeries(opens,false);
 int dated=CopyTime(_Symbol,TF[k],first,wanted,opens);
 if(dated!=wanted || ArraySize(opens)!=wanted || _StopFlag) return false;
 for(int i=0;i<wanted && !_StopFlag;i++)
  if(opens[i]<=0 || (i>0 && opens[i]<=opens[i-1])) return false;
 if(_StopFlag) return false;
 int copied=CopyBuffer(Handles[k],0,(datetime)opens[0],(datetime)opens[wanted-1],values);
 if(!SourceStable(k,sourceBars,newest)) return false;
 if(ArrayResize(state,wanted)!=wanted) return false;
 ArrayInitialize(state,0);
 if(copied==wanted && ArraySize(values)==wanted)
 {
  for(int i=0;i<wanted && !_StopFlag;i++) state[i]=ValidRSI(values[i]) ? 1 : -1;
 }
 else
 {
  if(ArrayResize(values,wanted)!=wanted) return false;
  ArrayInitialize(values,EMPTY_VALUE);
 }
 return !_StopFlag;
}

// A time-history block can be pending too. Probe the actual candidate rather
// than requiring unrelated newer/older source candles to be readable.
bool ReadPoint(const int k,const datetime endpoint,const bool live,const int sourceBars,
               const datetime newest,const long warmup,double &value)
{
 value=EMPTY_VALUE;
 if(!SourceStable(k,sourceBars,newest)) return false;
 int shift=iBarShift(_Symbol,TF[k],endpoint,false);
 if(shift<0) return false;
 datetime opened=iTime(_Symbol,TF[k],shift);
 if(opened<=0 || opened>endpoint) return false;
 if(!live)
 {
  datetime closed=BarClose(opened,TF[k]);
  if(closed<=0) return false;
  if(closed>endpoint) { shift++; opened=iTime(_Symbol,TF[k],shift); }
 }
 if(shift>=sourceBars-warmup) return true;
 return opened>0 && opened<=endpoint && ReadExact(k,opened,sourceBars,newest,value);
}

//------------------------------------------------------------------
bool FillLine(const int k,double &dest[],const datetime &times[],const int count,
              const datetime now,const int sourceBars,const datetime firstSource,
              const datetime newestSource)
{
 long warmup=(long)InpRSIPeriod+(k==4 ? 6 : 0);
 if(sourceBars<=warmup) return true; // Expected RSI/SMA warmup, not an error.
 double values[];
 datetime opens[];
 int state[];
 int cacheFirst=-1;
 datetime ceiling=0;
 int chartSeconds=PeriodSeconds((ENUM_TIMEFRAMES)_Period);
 int sourceSeconds=PeriodSeconds(TF[k]);
 // Sparse lower-frame samples need tiny blocks; dense histories amortize the
 // lookups over bounded blocks. No source allocation can grow with TF ratio.
 int limit=(count<=2 || (double)chartSeconds/sourceSeconds>64.0) ? 8 : 512;
 bool complete=true;
 for(int i=0;i<count && !_StopFlag;i++)
 {
  datetime endpoint=now;
  if(i>0)
  {
   endpoint=BarClose(times[i],(ENUM_TIMEFRAMES)_Period);
   // An actual earlier opening can terminate a shortened chart candle.
   if(times[i-1]>times[i] && times[i-1]<endpoint) endpoint=times[i-1];
  }
  if(endpoint<=0) { complete=false; continue; }
  if(endpoint<firstSource) continue; // Render the available overlap.
  bool live=(i==0 && InpLiveCurrentBar);
  if(cacheFirst<0 || endpoint<opens[0] || endpoint>ceiling)
  {
   int shift=iBarShift(_Symbol,TF[k],endpoint,false);
   if(shift<0) { complete=false; continue; }
   cacheFirst=MathMax(0,shift-1);
   if(!SourceChunk(k,cacheFirst,limit,sourceBars,newestSource,values,opens,state))
   {
    cacheFirst=-1;
    if(!SourceStable(k,sourceBars,newestSource)) return false;
    double point;
    if(ReadPoint(k,endpoint,live,sourceBars,newestSource,warmup,point))
    { if(ValidRSI(point)) dest[i]=point; }
    else complete=false;
    continue;
   }
   ceiling=endpoint;
  }
  int position=SourcePosition(opens,endpoint);
  if(position<0) { complete=false; continue; }
  int shift=cacheFirst+ArraySize(opens)-1-position;
  if(!live)
  {
   datetime closed=BarClose(opens[position],TF[k]);
   if(closed<=0) { complete=false; continue; }
   if(closed>endpoint) { shift++; position--; }
  }
  if(shift>=sourceBars-warmup) continue;
  if(position<0)
  {
   cacheFirst=MathMax(0,shift-1);
   if(!SourceChunk(k,cacheFirst,limit,sourceBars,newestSource,values,opens,state))
   {
    cacheFirst=-1;
    if(!SourceStable(k,sourceBars,newestSource)) return false;
    double point;
    if(ReadPoint(k,endpoint,live,sourceBars,newestSource,warmup,point))
    { if(ValidRSI(point)) dest[i]=point; }
    else complete=false;
    continue;
   }
   ceiling=endpoint;
   position=SourcePosition(opens,endpoint);
   if(position>=0 && !live)
   {
    datetime closed=BarClose(opens[position],TF[k]);
    if(closed<=0) { complete=false; continue; }
    if(closed>endpoint) position--;
   }
   shift=cacheFirst+ArraySize(opens)-1-position;
   if(shift>=sourceBars-warmup) continue;
  }
  if(position<0 || position>=ArraySize(values)) { complete=false; continue; }
  if(state[position]==0)
  {
   double point;
   if(ReadExact(k,opens[position],sourceBars,newestSource,point))
   { values[position]=point; state[position]=1; }
   else state[position]=-1;
  }
  if(state[position]!=1) { complete=false; continue; }
  dest[i]=values[position];
 }
 return !_StopFlag && complete && iBars(_Symbol,TF[k])==sourceBars &&
        iTime(_Symbol,TF[k],0)==newestSource;
}

void UpdateLine(const int k,double &dest[],const datetime &times[],
                const int baseCount,const int total,const int newBars,
                const datetime now,const ulong clock)
{
 int backlog=baseCount;
 bool waiting=Pending[k]>0;
 if(waiting) backlog=MathMax(backlog,(int)MathMin((long)total,(long)Pending[k]+newBars));
 int calculated=BarsCalculated(Handles[k]);
 bool replay=!waiting || clock>=RetryAfter[k] || calculated>CalculatedSeen[k];
 int count=replay ? backlog : baseCount;
 int bars=iBars(_Symbol,TF[k]);
 datetime first=bars>0 ? iTime(_Symbol,TF[k],bars-1) : 0;
 datetime newest=bars>0 ? iTime(_Symbol,TF[k],0) : 0;
 // Loading older source history can fill points previously outside coverage.
 // Normal retirement of old source bars does not invalidate published points.
 if(SourceFirst[k]==0 || (first>0 && first<SourceFirst[k])) { count=total; replay=true; }
 // Preserve published closed points while older data is pending. Even while
 // throttling historical retries, refresh the changing points independently.
 ClearLine(dest,0,baseCount);
 bool ready=bars>0 && first>0 && newest>0;
 if(ready) ready=FillLine(k,dest,times,count,now,bars,first,newest);
 if(_StopFlag) return;
 CalculatedSeen[k]=calculated;
 if(bars>0 && first>0 && SourceStable(k,bars,newest)) SourceFirst[k]=first;
 if(ready && count>=backlog)
 {
  Pending[k]=0; RetryAfter[k]=0;
 }
 else
 {
  Pending[k]=MathMax(backlog,count);
  if(replay) RetryAfter[k]=clock+(count>baseCount ? 1000 : 250);
 }
}

//------------------------------------------------------------------
int OnCalculate(const int rates_total,const int prev_calculated,
 const datetime &time[],const double &open[],const double &high[],const double &low[],
 const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
 if(rates_total<1 || _StopFlag) return 0;
 ArraySetAsSeries(time,true);
 bool reset=prev_calculated<=0 || prev_calculated>rates_total || LastNewest==0;
 int newBars=0;
 if(!reset)
 {
  if(time[0]!=LastNewest)
  {
   newBars=ChartShift(time,rates_total,LastNewest);
   if(newBars<1 || time[rates_total-1]<LastOldest) reset=true;
  }
  else if(prev_calculated!=rates_total || LastOldest!=time[rates_total-1]) reset=true;
 }
 int total=MathMin(rates_total,InpHistoryBars);
 int count=reset ? total : MathMin(total,newBars+1);
 if(reset)
 {
  ArrayInitialize(Lower,EMPTY_VALUE); ArrayInitialize(Current,EMPTY_VALUE);
  ArrayInitialize(Higher,EMPTY_VALUE); ArrayInitialize(Fourth,EMPTY_VALUE);
  ArrayInitialize(SMA7,EMPTY_VALUE);
  for(int k=0;k<5;k++) { Pending[k]=0; RetryAfter[k]=0; SourceFirst[k]=0; CalculatedSeen[k]=0; }
  newBars=0;
 }
 else
 {
  int end=(int)MathMin((long)rates_total,(long)MathMin(prev_calculated,InpHistoryBars)+newBars);
  ClearLine(Lower,total,end); ClearLine(Current,total,end);
  ClearLine(Higher,total,end); ClearLine(Fourth,total,end); ClearLine(SMA7,total,end);
 }
 datetime now=TimeCurrent();
 ulong clock=GetTickCount64();
 UpdateLine(0,Lower,time,count,total,newBars,now,clock);
 UpdateLine(1,Current,time,count,total,newBars,now,clock);
 UpdateLine(2,Higher,time,count,total,newBars,now,clock);
 UpdateLine(3,Fourth,time,count,total,newBars,now,clock);
 UpdateLine(4,SMA7,time,count,total,newBars,now,clock);
 if(_StopFlag) return 0;
 LastNewest=time[0]; LastOldest=time[rates_total-1];
 // Each line owns its pending suffix; one unavailable TF does not reset all.
 return rates_total;
}

//------------------------------------------------------------------
void OnDeinit(const int reason)
{
 ReleaseSources();
}
