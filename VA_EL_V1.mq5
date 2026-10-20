//+------------------------------------------------------------------+
//|                    VA_EL_V1 v1.30 - Volume Core                 |
//|      Volume histogram and average only.  |
//+------------------------------------------------------------------+
#property copyright "VE Pro), 2026"
#property link      "cdm.thoigmail.com"
#property version   "1.30"
#property strict
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_minimum 0

#property indicator_label1  "Volume"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrSilver,C'172,222,172',C'168,215,168',C'121,199,121',C'113,166,113',C'96,146,96',C'216,160,160',C'224,160,136',C'198,142,142',C'185,113,113',C'160,96,96',clrPurple
#property indicator_width1  2

#property indicator_label2  "Volume MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_width2  1

#property indicator_label3  "Relative volume (prior MA)"
#property indicator_type3   DRAW_NONE

enum enMaTypes
  {
   ma_sma,   // SMA
   ma_ema,   // EMA
   ma_smma,  // SMMA
   ma_lwma   // LWMA
  };

enum enVolumeType
  {
   vol_ticks, // Tick volume
   vol_volume // Real volume for the series; tick fallback if all real data is zero
  };

input group "Volume Core"
input bool         inpEnabled       = true;       // Enable volume histogram
input enVolumeType inpVolumeType    = vol_ticks;  // Volume source
input int          inpAveragePeriod = 20;         // Volume average period
input enMaTypes    inpAverageMethod = ma_sma;     // Average method
input bool         inpShowAverage   = true;       // Show volume average line
input bool         inpClosedColorsOnly = true;    // Use neutral color until bar closes
input bool         inpRequireFullPeriod = true;   // Wait for a full prior MA before classification

input group "Volume thresholds (multiple of prior MA)"
input double inpLowVolStartRatio      = 0.5; // Low tier begins
input double inpMediumVolStartRatio   = 1.0; // Medium tier begins
input double inpHighVolStartRatio    = 1.5; // High tier begins
input double inpVeryHighVolStartRatio = 2.0; // Very high tier begins
input double inpAbnormalVolumeRatio  = 3.0; // Extreme volume, purple

input group "Muted 5-level colors"
input color inpNeutralColor       = clrSilver;
input color inpUpVeryLowColor     = C'172,222,172';
input color inpUpLowColor         = C'168,215,168';
input color inpUpMediumColor      = C'121,199,121';
input color inpUpHighColor        = C'113,166,113';
input color inpUpVeryHighColor    = C'96,146,96';
input color inpDownVeryLowColor   = C'216,160,160';
input color inpDownLowColor       = C'224,160,136';
input color inpDownMediumColor    = C'198,142,142';
input color inpDownHighColor      = C'185,113,113';
input color inpDownVeryHighColor  = C'160,96,96';
input color inpExtremeVolumeColor = clrPurple; // Kept distinct from directional tiers

double BufferVolume[];
double BufferColorIndex[];
double BufferAverage[];
double BufferRelativeVolume[];
double BufferRollingSum[];
double BufferRollingWeighted[];
datetime FirstBarTime=0;
bool UsingRealVolume=false;
int LatestRealVolumeBar=-1;

double ReadVolume(const int i,const long &tick_volume[],const long &real_volume[])
  {
   // Keep one unit throughout the MA. A zero real-volume bar is not tick volume.
   return(MathMax(0.0,(double)(UsingRealVolume ? real_volume[i] : tick_volume[i])));
  }

int OnInit()
  {
   if(inpAveragePeriod<1 || inpAverageMethod<ma_sma || inpAverageMethod>ma_lwma ||
      inpVolumeType<vol_ticks || inpVolumeType>vol_volume ||
      !MathIsValidNumber(inpLowVolStartRatio) || !MathIsValidNumber(inpMediumVolStartRatio) ||
      !MathIsValidNumber(inpHighVolStartRatio) || !MathIsValidNumber(inpVeryHighVolStartRatio) ||
      !MathIsValidNumber(inpAbnormalVolumeRatio) ||
      inpLowVolStartRatio<=0 ||
      inpMediumVolStartRatio<=inpLowVolStartRatio ||
      inpHighVolStartRatio<=inpMediumVolStartRatio ||
      inpVeryHighVolStartRatio<=inpHighVolStartRatio ||
      inpAbnormalVolumeRatio<=inpVeryHighVolStartRatio)
      return(INIT_PARAMETERS_INCORRECT);

   if(!SetIndexBuffer(0,BufferVolume,INDICATOR_DATA) ||
      !SetIndexBuffer(1,BufferColorIndex,INDICATOR_COLOR_INDEX) ||
      !SetIndexBuffer(2,BufferAverage,INDICATOR_DATA) ||
      !SetIndexBuffer(3,BufferRelativeVolume,INDICATOR_DATA) ||
      !SetIndexBuffer(4,BufferRollingSum,INDICATOR_CALCULATIONS) ||
      !SetIndexBuffer(5,BufferRollingWeighted,INDICATOR_CALCULATIONS))
      return(INIT_FAILED);

   ArraySetAsSeries(BufferVolume,false);
   ArraySetAsSeries(BufferColorIndex,false);
   ArraySetAsSeries(BufferAverage,false);
   ArraySetAsSeries(BufferRelativeVolume,false);
   ArraySetAsSeries(BufferRollingSum,false);
   ArraySetAsSeries(BufferRollingWeighted,false);
   FirstBarTime=0;UsingRealVolume=false;LatestRealVolumeBar=-1;

   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,12);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,inpNeutralColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,inpUpVeryLowColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,2,inpUpLowColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,3,inpUpMediumColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,4,inpUpHighColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,5,inpUpVeryHighColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,6,inpDownVeryLowColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,7,inpDownLowColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,8,inpDownMediumColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,9,inpDownHighColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,10,inpDownVeryHighColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,11,inpExtremeVolumeColor);
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,inpShowAverage ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(2,PLOT_SHOW_DATA,true);
   PlotIndexSetString(0,PLOT_LABEL,"Volume");
   PlotIndexSetString(1,PLOT_LABEL,"Volume MA");
   PlotIndexSetString(2,PLOT_LABEL,"Relative volume (prior MA)");
   IndicatorSetInteger(INDICATOR_DIGITS,2);
   IndicatorSetString(INDICATOR_SHORTNAME,"VA_EL_V1 v1.30 Volume Core");
   return(INIT_SUCCEEDED);
  }

int VolumeTier(const double relativeVolume)
  {
   if(relativeVolume>=inpVeryHighVolStartRatio) return(5);
   if(relativeVolume>=inpHighVolStartRatio) return(4);
   if(relativeVolume>=inpMediumVolStartRatio) return(3);
   if(relativeVolume>=inpLowVolStartRatio) return(2);
   return(1);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &real_volume[],
                const int &spread[])
  {
   if(rates_total<1 || _StopFlag) return(0);

   ArraySetAsSeries(time,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(close,false);
   ArraySetAsSeries(tick_volume,false);
   ArraySetAsSeries(real_volume,false);

   bool reset=prev_calculated<=0 || prev_calculated>rates_total || FirstBarTime!=time[0];
   FirstBarTime=time[0];
   int start=reset ? 0 : prev_calculated-1;
   int processed=start;
   if(!inpEnabled)
     {
      for(int i=start;i<rates_total && !_StopFlag;++i)
        {
         BufferVolume[i]=EMPTY_VALUE;
         BufferColorIndex[i]=0;
         BufferAverage[i]=EMPTY_VALUE;
         BufferRelativeVolume[i]=EMPTY_VALUE;
         BufferRollingSum[i]=0;
         BufferRollingWeighted[i]=0;
         processed=i+1;
        }
      return(processed);
     }

   int latestReal=(reset ? -1 : LatestRealVolumeBar);
   int scanStart=start;
   if(latestReal>=0 && (latestReal>=rates_total || real_volume[latestReal]<=0))
     {
      // A feed correction may remove the last positive real-volume sample.
      latestReal=-1;
      scanStart=0;
     }
   if(inpVolumeType==vol_volume)
     {
      for(int i=rates_total-1;i>=scanStart && !_StopFlag;--i)
         if(real_volume[i]>0) { latestReal=i;break; }
     }
   else
      latestReal=-1;
   if(_StopFlag) return(0);
   LatestRealVolumeBar=latestReal;
   bool realAvailable=latestReal>=0;
   if(reset || realAvailable!=UsingRealVolume)
     {
      UsingRealVolume=realAvailable;
      start=0; // Switching units requires rebuilding every dependent MA/color.
      if(inpVolumeType==vol_ticks)
         IndicatorSetString(INDICATOR_SHORTNAME,"VA_EL_V1 v1.30 Volume Core - Tick");
      else if(UsingRealVolume)
         IndicatorSetString(INDICATOR_SHORTNAME,"VA_EL_V1 v1.30 Volume Core - Real");
      else
         IndicatorSetString(INDICATOR_SHORTNAME,"VA_EL_V1 v1.30 Volume Core - Tick fallback");
     }
   processed=start;
   const double alpha=2.0/(inpAveragePeriod+1.0);

   for(int i=start;i<rates_total && !_StopFlag;++i)
     {
      double vol=ReadVolume(i,tick_volume,real_volume);
      BufferVolume[i]=vol;

      int count=MathMin(i+1,inpAveragePeriod);
      if(i==0)
         BufferRollingSum[i]=vol;
      else if(i<inpAveragePeriod)
         BufferRollingSum[i]=BufferRollingSum[i-1]+vol;
      else
         BufferRollingSum[i]=BufferRollingSum[i-1]+vol-BufferVolume[i-inpAveragePeriod];

      // O(1) weighted update during warmup as well as after the full window.
      if(i==0)
         BufferRollingWeighted[i]=vol;
      else if(i<inpAveragePeriod)
         BufferRollingWeighted[i]=BufferRollingWeighted[i-1]+(i+1.0)*vol;
      else
         BufferRollingWeighted[i]=BufferRollingWeighted[i-1]-BufferRollingSum[i-1]+inpAveragePeriod*vol;

      double average=0.0;
      if(inpAverageMethod==ma_sma)
         average=BufferRollingSum[i]/count;
      else if(inpAverageMethod==ma_ema)
         average=(i==0 ? vol : alpha*vol+(1.0-alpha)*BufferAverage[i-1]);
      else if(inpAverageMethod==ma_smma)
        {
         if(i<inpAveragePeriod-1)
            average=BufferRollingSum[i]/count;
         else if(i==inpAveragePeriod-1)
            average=BufferRollingSum[i]/inpAveragePeriod;
         else
            average=BufferAverage[i-1]+(vol-BufferAverage[i-1])/inpAveragePeriod;
        }
      else
         average=BufferRollingWeighted[i]/(count*(count+1.0)/2.0);

      BufferAverage[i]=average;
      if(!MathIsValidNumber(average) || average<0)
         BufferAverage[i]=0.0;

      int colorIndex=0;
      bool barMayBeColored=(!inpClosedColorsOnly || i<rates_total-1);
      double priorAverage=(i>0 ? BufferAverage[i-1] : 0.0);
      bool baselineReady=(!inpRequireFullPeriod || i>=inpAveragePeriod) && priorAverage>0.0;
      double relativeVolume=(baselineReady ? vol/priorAverage : 0.0);
      // A tiny EMA after a long zero run can overflow the ratio. Keep its
      // extreme classification, but never publish infinity in the Data Window.
      BufferRelativeVolume[i]=(baselineReady && MathIsValidNumber(relativeVolume) ? relativeVolume : EMPTY_VALUE);
      if(barMayBeColored && baselineReady && vol>0.0)
        {
         if(relativeVolume>=inpAbnormalVolumeRatio)
            colorIndex=11;
         else if(close[i]>open[i])
            colorIndex=VolumeTier(relativeVolume);
         else if(close[i]<open[i])
            colorIndex=5+VolumeTier(relativeVolume);
        }
      BufferColorIndex[i]=colorIndex;
      processed=i+1;
     }

   return(processed);
  }
