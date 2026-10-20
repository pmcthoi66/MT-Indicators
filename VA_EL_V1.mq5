//+------------------------------------------------------------------+
//|                    VA_EL_V1 v1.29 - Volume Core                 |
//|      Volume histogram and average only; no price-pattern logic.  |
//+------------------------------------------------------------------+
#property copyright "© mladen (Enhanced VPE Engine Pro), 2026"
#property link      "mladenfx@gmail.com"
#property version   "1.29"
#property strict
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   2
#property indicator_minimum 0

#property indicator_label1  "Volume"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrSilver,C'172,222,172',C'168,215,168',C'121,199,121',C'113,166,113',C'96,146,96',C'216,160,160',C'224,160,136',C'198,142,142',C'185,113,113',C'160,96,96',clrPurple
#property indicator_width1  2

#property indicator_label2  "Volume MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_width2  1

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
   vol_volume // Real volume; falls back to tick volume if unavailable
  };

input group "Volume Core"
input bool         inpEnabled       = true;       // Enable volume histogram
input enVolumeType inpVolumeType    = vol_ticks;  // Volume source
input int          inpAveragePeriod = 20;         // Volume average period
input enMaTypes    inpAverageMethod = ma_sma;     // Average method
input bool         inpShowAverage   = true;       // Show volume average line
input bool         inpClosedColorsOnly = true;    // Use neutral color until bar closes

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
double BufferRollingSum[];
double BufferRollingWeighted[];

double ReadVolume(const int i,const long &tick_volume[],const long &real_volume[])
  {
   if(inpVolumeType==vol_volume && real_volume[i]>0)
      return((double)real_volume[i]);
   return((double)tick_volume[i]);
  }

int OnInit()
  {
   if(inpAveragePeriod<1 ||
      inpLowVolStartRatio<=0 ||
      inpMediumVolStartRatio<=inpLowVolStartRatio ||
      inpHighVolStartRatio<=inpMediumVolStartRatio ||
      inpVeryHighVolStartRatio<=inpHighVolStartRatio ||
      inpAbnormalVolumeRatio<=inpVeryHighVolStartRatio)
      return(INIT_PARAMETERS_INCORRECT);

   SetIndexBuffer(0,BufferVolume,INDICATOR_DATA);
   SetIndexBuffer(1,BufferColorIndex,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,BufferAverage,INDICATOR_DATA);
   SetIndexBuffer(3,BufferRollingSum,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,BufferRollingWeighted,INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BufferVolume,false);
   ArraySetAsSeries(BufferColorIndex,false);
   ArraySetAsSeries(BufferAverage,false);
   ArraySetAsSeries(BufferRollingSum,false);
   ArraySetAsSeries(BufferRollingWeighted,false);

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
   PlotIndexSetString(0,PLOT_LABEL,"Volume");
   PlotIndexSetString(1,PLOT_LABEL,"Volume MA");
   IndicatorSetString(INDICATOR_SHORTNAME,"VA_EL_V1 v1.29 Volume Core");
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
   if(rates_total<1) return(0);

   ArraySetAsSeries(time,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(close,false);
   ArraySetAsSeries(tick_volume,false);
   ArraySetAsSeries(real_volume,false);

   if(!inpEnabled)
     {
      if(prev_calculated==0)
         for(int i=0;i<rates_total;++i)
           {
            BufferVolume[i]=EMPTY_VALUE;
            BufferColorIndex[i]=0;
            BufferAverage[i]=EMPTY_VALUE;
            BufferRollingSum[i]=0;
            BufferRollingWeighted[i]=0;
           }
      return(rates_total);
     }

   int start=(prev_calculated>0 ? prev_calculated-1 : 0);
   if(start>=rates_total) start=0;
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
      else // LWMA: rolling weighted sum after the initial window
        {
         double weighted=0.0;
         if(i<inpAveragePeriod)
           {
            for(int j=0;j<=i;++j)
               weighted+=BufferVolume[i-j]*(i-j+1);
           }
         else
            weighted=BufferRollingWeighted[i-1]-BufferRollingSum[i-1]+inpAveragePeriod*vol;
         BufferRollingWeighted[i]=weighted;
         average=weighted/(count*(count+1.0)/2.0);
        }

      if(inpAverageMethod!=ma_lwma)
        {
         double weighted=0.0;
         if(i<inpAveragePeriod)
           {
            for(int j=0;j<=i;++j)
               weighted+=BufferVolume[i-j]*(i-j+1);
           }
         else
            weighted=BufferRollingWeighted[i-1]-BufferRollingSum[i-1]+inpAveragePeriod*vol;
         BufferRollingWeighted[i]=weighted;
        }

      BufferAverage[i]=average;
      if(!MathIsValidNumber(average) || average<0)
         BufferAverage[i]=0.0;

      int colorIndex=0;
      bool barMayBeColored=(!inpClosedColorsOnly || i<rates_total-1);
      double priorAverage=(i>0 ? BufferAverage[i-1] : 0.0);
      if(barMayBeColored && priorAverage>0.0 && vol>0.0)
        {
         double relativeVolume=vol/priorAverage;
         if(relativeVolume>=inpAbnormalVolumeRatio)
            colorIndex=11;
         else if(close[i]>open[i])
            colorIndex=VolumeTier(relativeVolume);
         else if(close[i]<open[i])
            colorIndex=5+VolumeTier(relativeVolume);
        }
      BufferColorIndex[i]=colorIndex;
     }

   return(rates_total);
  }
