//+------------------------------------------------------------------+
//|              Woodies_CCI_MT5.mq5                     |
//|                 Woodies CCI - Reversal Only                     |
//+------------------------------------------------------------------+
#property strict
#property version   "2.99"
#property indicator_separate_window
#property indicator_buffers 23
#property indicator_plots   16

//==================================================================
// HISTOGRAM
//==================================================================
#property indicator_label1  "Hist Bull 6+"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDarkGreen
#property indicator_width1  1

#property indicator_label2  "Hist Bear 6+"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrMaroon
#property indicator_width2  1

#property indicator_label3  "Hist Early 1-4"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrGray
#property indicator_width3  1

#property indicator_label4  "Hist Transition 5"
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrYellow
#property indicator_width4  1

//==================================================================
// CCI
//==================================================================
#property indicator_label5  "CCI 14"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRoyalBlue
#property indicator_width5  1

#property indicator_label6  "Turbo CCI"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrOrange
#property indicator_width6  1

//==================================================================
// LEVELS
//==================================================================
#property indicator_label7  "Zero Line"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrGray
#property indicator_style7  STYLE_DOT

#property indicator_label8  "+100"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrIndianRed
#property indicator_style8  STYLE_DOT

#property indicator_label9  "-100"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrIndianRed
#property indicator_style9  STYLE_DOT

#property indicator_label10 "+200"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrGray
#property indicator_style10 STYLE_DOT

#property indicator_label11 "-200"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrGray
#property indicator_style11 STYLE_DOT

//==================================================================
// SIGNALS
//==================================================================
#property indicator_label12 "Early Sell"
#property indicator_type12  DRAW_ARROW
#property indicator_color12 clrRed
#property indicator_width12 1

#property indicator_label13 "Early Buy"
#property indicator_type13  DRAW_ARROW
#property indicator_color13 clrLimeGreen
#property indicator_width13 1

// Confirmation dots are additive; they never suppress an early arrow.
#property indicator_label14 "Sell Confirmed (same bar)"
#property indicator_type14 DRAW_ARROW
#property indicator_color14 clrRed
#property indicator_width14 2
#property indicator_label15 "Buy Confirmed (same bar)"
#property indicator_type15 DRAW_ARROW
#property indicator_color15 clrLimeGreen
#property indicator_width15 2

// Price direction colors; intensity follows relative volume.
#property indicator_label16 "Hist Price / Volume"
#property indicator_type16 DRAW_COLOR_HISTOGRAM
#property indicator_color16 clrPaleGreen,clrLimeGreen,clrForestGreen,clrDarkGreen,clrLightSalmon,clrTomato,clrFireBrick,clrMaroon,clrGray,clrLightYellow,clrGold,clrOrange,clrDarkRed
#property indicator_width16 2

//==================================================================
// INPUTS
//==================================================================
input string InpSectionCCI = "=== CCI Settings ===";

input int    InpCCIPeriod  = 14;
input int    InpTCCIPeriod = 6;

input double InpUpper200   = 200.0;
input double InpUpper100   = 100.0;
input double InpZeroLevel  = 0.0;
input double InpLower100   = -100.0;
input double InpLower200   = -200.0;

//==================================================================
// REVERSAL ENGINE
//==================================================================
input string InpSectionSignal = "=== Reversal Signal Engine ===";

input bool   InpClosedBarsOnly = true;

input double InpReversalLevel = 160.0;

input int    InpSignalCooldown = 1;

input double InpArrowOffset = 50.0;

// Early arrows default to V2.7 rules. Strict gates are opt-in only.
input string InpSectionFilters = "=== Optional Strict Gates (default OFF) ===";
input bool   InpShowConfirmationDots = true;
input bool   InpRequireTurboTurn = false;
input double InpTurboMinTurn = 0.0;       // Minimum new slope, in CCI points
input bool   InpOneSignalPerExtreme = false; // Rearm BUY at CCI >= 0, SELL at CCI <= 0
input bool   InpUseHistogramFilter = false;
input int    InpHistogramMinRun = 5;      // Previous same-zero-side run: yellow or mature
input double InpHistogramMinRetreat = 5.0; // Slow CCI recovery, in CCI points


//==================================================================
// ALERT
//==================================================================
input string InpSectionAlert = "=== M5 Signal Alert ===";
input bool   InpEnableAlert  = true;

//==================================================================
// SCALE
//==================================================================
input string InpSectionScale = "=== CCI Scale ===";

input double InpScaleMin = -250.0;
input double InpScaleMax = 250.0;
input bool   InpKeepMarkersVisible = true; // Keep arrow/dot pairs inside configured scale

// Appended to preserve previous input positions.
input bool InpEnabled = true; // OFF: hide plots, clear data, stop calculations/alerts

// Added at the end to preserve every existing input position.
// Price confirmation qualifies dots only; early arrow rules stay unchanged.
input string InpSectionPriceConfirm = "=== Same-bar Price Confirmation ===";
input bool InpUsePriceConfirmation = true;
input double InpConfirmMinBodyRatio = 0.25; // Candle body / full high-low range
input double InpConfirmMinCloseLocation = 0.60; // BUY close location >= 0.60; SELL <= 0.40
input bool InpConfirmRequireCloseProgress = true; // BUY close > previous close, SELL <
input bool InpAlertConfirmedOnly = false; // OFF retains original early-arrow alerts

// Appended inputs preserve existing presets.
input string InpSectionHistColor = "=== HistBars Price / Volume Colors ===";
input bool InpHistPriceVolumeColors = true; // OFF restores original Woodies colors
input int InpHistVolumeLookback = 20; // Average of preceding bars, excluding current
input bool InpHistUseRealVolume = false; // Tick volume by default; real volume when supplied
input double InpHistAbnormalVolume = 2.5; // Bat thuong: volume / MA20 >= 2.5
input double InpHistSmallBodyRatio = 0.30; // Than nho: body / range <= 30%
input double InpHistLowVolumeRatio = 0.80; // Volume thap: volume / MA20 < 0.8

input bool InpRequirePriceBreak = true; // Thu: BUY dong tren dinh nen truoc; SELL dong duoi day. OFF = mui ten cu

//==================================================================
// BUFFERS
//==================================================================
double HistVolumeBuffer[];
double HistColorBuffer[];
double HistDarkGreenBuffer[];
double HistMaroonBuffer[];
double HistGrayBuffer[];
double HistYellowBuffer[];

double CCIBuffer[];
double TCCIBuffer[];

double ZeroLineBuffer[];
double Upper100Buffer[];
double Lower100Buffer[];
double Upper200Buffer[];
double Lower200Buffer[];

double SellSignalBuffer[];
double BuySignalBuffer[];
double SellConfirmBuffer[];
double BuyConfirmBuffer[];

// Calculation buffers follow terminal history resizing automatically.
double Price[];
double RunBuffer[];
double BuyAgeBuffer[];
double SellAgeBuffer[];
double BuyUsedBuffer[];
double SellUsedBuffer[];
datetime g_firstBarTime = 0;
datetime g_openBarTime = 0;
bool g_priceCacheValid = false;
double g_cachedOpen = 0.0, g_cachedHigh = 0.0, g_cachedLow = 0.0, g_cachedClose = 0.0;
long g_cachedTickVolume = 0, g_cachedRealVolume = 0;
int g_disabledBars = -1;

//==================================================================
// ALERT STATE
//==================================================================
datetime g_lastAlertTime = 0;
int      g_lastAlertType = 0;   // 1 = BUY, -1 = SELL
bool     g_alertInitialized = false;
datetime g_lastObservedAlertBar = 0;

//==================================================================
// VALID NUMBER
//==================================================================
bool Valid(const double v)
{
   return(v != EMPTY_VALUE && MathIsValidNumber(v));
}

//==================================================================
// CCI
//==================================================================
double CCI(const double &p[],
           const int i,
           const int period)
{
   if(period <= 1)
      return(EMPTY_VALUE);

   if(i < period - 1)
      return(EMPTY_VALUE);

   int first = i - period + 1;

   // Center on the current price to avoid subtracting two large prices.
   // Compensated sums reduce rounding error without rolling-sum drift.
   const double base = p[i];
   if(!Valid(base)) return(EMPTY_VALUE);
   double sum = 0.0, correction = 0.0;
   for(int j = first; j <= i; j++)
   {
      if(!Valid(p[j])) return(EMPTY_VALUE);
      double term = (p[j] - base) - correction;
      double next = sum + term;
      correction = (next - sum) - term;
      sum = next;
   }
   const double mean = sum / period;
   double dev = 0.0;
   correction = 0.0;
   for(int j = first; j <= i; j++)
   {
      double term = MathAbs((p[j] - base) - mean) - correction;
      double next = dev + term;
      correction = (next - dev) - term;
      dev = next;
   }
   dev /= period;
   if(dev <= 0.0)
      return(0.0);
   double value = -mean / (0.015 * dev);
   return(MathIsValidNumber(value) ? value : EMPTY_VALUE);
}

//==================================================================
// HISTOGRAM
//
// 1-4 = Gray
// 5   = Yellow
// 6+  = Green / Red
//
// Reset when CCI changes side of zero.
//==================================================================
void CalculateHistogram(const int rates_total, const int start)
{
   for(int i = start; i < rates_total; i++)
   {
      if((i & 255) == 0 && IsStopped()) return;
      HistDarkGreenBuffer[i] = EMPTY_VALUE;
      HistMaroonBuffer[i] = EMPTY_VALUE;
      HistGrayBuffer[i] = EMPTY_VALUE;
      HistYellowBuffer[i] = EMPTY_VALUE;
      RunBuffer[i] = 0.0;
      double cci = CCIBuffer[i];
      if(!Valid(cci)) continue;
      int side = cci > 0.0 ? 1 : (cci < 0.0 ? -1 : 0);
      int previousSide = 0;
      if(i > 0 && Valid(CCIBuffer[i-1]))
         previousSide = CCIBuffer[i-1] > 0.0 ? 1 : (CCIBuffer[i-1] < 0.0 ? -1 : 0);
      // Retain the actual run length: the histogram filter uses this state.
      int run = 1;
      if(side != 0 && side == previousSide && i > 0)
         run = (int)RunBuffer[i-1] + 1;
      RunBuffer[i] = run;
      if(side == 0 || run <= 4) HistGrayBuffer[i] = cci;
      else if(run == 5) HistYellowBuffer[i] = cci;
      else if(side > 0) HistDarkGreenBuffer[i] = cci;
      else HistMaroonBuffer[i] = cci;
   }
}

// One source for the whole calculation: never mix real and tick units per bar.
double HistVolumeAt(const int i, const long &tick_volume[], const long &volume[])
{
   return(MathMax(0.0, (double)(InpHistUseRealVolume ? volume[i] : tick_volume[i])));
}

// Palette: green 0..3, red 4..7, neutral 8, yellow 9..11, abnormal 12.
// Priority: small-body rising volume, abnormal volume, directional sequences.
int HistBarColor(const int i, const double average,
                 const double &open[], const double &high[], const double &low[],
                 const double &close[], const long &tick_volume[], const long &volume[])
{
   if(i < 1 || average <= 0.0 || !Valid(open[i]) || !Valid(high[i]) ||
      !Valid(low[i]) || !Valid(close[i]) || !Valid(close[i-1])) return(8);
   double current = HistVolumeAt(i, tick_volume, volume);
   double previous = HistVolumeAt(i-1, tick_volume, volume);
   double ratio = current / average;
   double range = high[i] - low[i];
   if(range <= 0.0 || !MathIsValidNumber(range) ||
      open[i] < low[i] || open[i] > high[i] ||
      close[i] < low[i] || close[i] > high[i]) return(8);
   bool growingVolume = current > previous;
   bool smallBody = MathAbs(close[i] - open[i]) / range <= InpHistSmallBodyRatio;
   if(smallBody && growingVolume && ratio >= 1.0)
      return(ratio < 1.5 ? 9 : (ratio < InpHistAbnormalVolume ? 10 : 11));
   if(ratio >= InpHistAbnormalVolume) return(12);
   int shade = ratio < 0.8 ? 0 : (ratio < 1.0 ? 1 : (ratio < 1.5 ? 2 : 3));
   if(close[i] > open[i] && close[i] > close[i-1] && growingVolume &&
      ratio >= InpHistLowVolumeRatio) return(shade);
   // Declining-volume bearish candles fade through the red palette,
   // including low-volume candles in that sequence.
   if(close[i] < open[i] && close[i] < close[i-1] && current < previous)
      return(4 + shade);
   if(ratio < InpHistLowVolumeRatio) return(8);
   // Other above-average directional candles retain their direction color.
   if(close[i] > open[i] && close[i] > close[i-1]) return(shade);
   if(close[i] < open[i] && close[i] < close[i-1]) return(4 + shade);
   return(8);
}

void CalculateHistColors(const int rates_total, const int start,
                         const double &open[], const double &high[], const double &low[],
                         const double &close[], const long &tick_volume[], const long &volume[])
{
   if(!InpHistPriceVolumeColors) return;
   double sum = 0.0;
   int first = MathMax(0, start - InpHistVolumeLookback);
   for(int j = first; j < start; j++)
   {
      if((j & 255) == 0 && IsStopped()) return;
      sum += HistVolumeAt(j, tick_volume, volume);
   }
   for(int i = start; i < rates_total; i++)
   {
      if((i & 255) == 0 && IsStopped()) return;
      HistVolumeBuffer[i] = Valid(CCIBuffer[i]) ? CCIBuffer[i] : EMPTY_VALUE;
      int count = MathMin(i, InpHistVolumeLookback);
      double average = count > 0 ? MathMax(0.0, sum) / count : 0.0;
      HistColorBuffer[i] = HistBarColor(i, average, open, high, low, close, tick_volume, volume);
      sum += HistVolumeAt(i, tick_volume, volume);
      if(i >= InpHistVolumeLookback)
         sum -= HistVolumeAt(i - InpHistVolumeLookback, tick_volume, volume);
   }
}

//==================================================================
// REVERSAL BUY
//==================================================================
bool IsReversalBuy(const int i)
{
   if(i < 1)
      return(false);

   double prevCCI  = CCIBuffer[i - 1];
   double currCCI  = CCIBuffer[i];

   double prevTCCI = TCCIBuffer[i - 1];
   double currTCCI = TCCIBuffer[i];

   if(!Valid(prevCCI) ||
      !Valid(currCCI) ||
      !Valid(prevTCCI) ||
      !Valid(currTCCI))
   {
      return(false);
   }

   // Previous CCI must be in negative extreme.
   if(prevCCI > -InpReversalLevel)
      return(false);

   // Turbo CCI turns upward.
   if(currTCCI <= prevTCCI)
      return(false);

   // Slow CCI must not continue falling.
   if(currCCI < prevCCI)
      return(false);

   return(true);
}

//==================================================================
// REVERSAL SELL
//==================================================================
bool IsReversalSell(const int i)
{
   if(i < 1)
      return(false);

   double prevCCI  = CCIBuffer[i - 1];
   double currCCI  = CCIBuffer[i];

   double prevTCCI = TCCIBuffer[i - 1];
   double currTCCI = TCCIBuffer[i];

   if(!Valid(prevCCI) ||
      !Valid(currCCI) ||
      !Valid(prevTCCI) ||
      !Valid(currTCCI))
   {
      return(false);
   }

   // Previous CCI must be in positive extreme.
   if(prevCCI < InpReversalLevel)
      return(false);

   // Turbo CCI turns downward.
   if(currTCCI >= prevTCCI)
      return(false);

   // Slow CCI must not continue rising.
   if(currCCI > prevCCI)
      return(false);

   return(true);
}

// Turbo must have just changed direction. A flat prior slope is allowed.
// Three completed samples are needed when closed-bar mode is enabled.
bool PassTurboTurn(const int i, const bool buy, const bool force = false)
{
   if(!InpRequireTurboTurn && !force) return(true);
   if(i < 2 || !Valid(TCCIBuffer[i-2]) ||
      !Valid(TCCIBuffer[i-1]) || !Valid(TCCIBuffer[i])) return(false);
   double oldSlope = TCCIBuffer[i-1] - TCCIBuffer[i-2];
   double newSlope = TCCIBuffer[i] - TCCIBuffer[i-1];
   if(buy) return(oldSlope <= 0.0 && newSlope > InpTurboMinTurn);
   return(oldSlope >= 0.0 && -newSlope > InpTurboMinTurn);
}

// Previous histogram establishes the regime; current height confirms recovery.
// Color alone is never interpreted as a BUY/SELL command.
bool PassHistogram(const int i, const bool buy, const bool force = false)
{
   if(!InpUseHistogramFilter && !force) return(true);
   if(i < 1 || RunBuffer[i-1] < InpHistogramMinRun ||
      !Valid(CCIBuffer[i-1]) || !Valid(CCIBuffer[i])) return(false);
   double previous = CCIBuffer[i-1];
   double current = CCIBuffer[i];
   if(buy) return(previous < 0.0 && current > previous &&
                  current - previous >= InpHistogramMinRetreat);
   return(previous > 0.0 && current < previous &&
          previous - current >= InpHistogramMinRetreat);
}

//==================================================================
// SIGNAL CALCULATION
//
// ONLY REVERSAL.
//==================================================================
// These coordinates are display positions, not CCI measurements.
// Reserve room for the confirmation dot so neither mark is clipped.
double SignalPosition(const int i, const bool buy)
{
   double offset = MathMax(InpArrowOffset, MathAbs(CCIBuffer[i]) * 0.05);
   double position = CCIBuffer[i] + (buy ? -offset : offset);
   if(!InpKeepMarkersVisible) return(position);
   double span = InpScaleMax - InpScaleMin;
   double margin = span * 0.06;
   double gap = span * 0.03;
   double lower = InpScaleMin + margin + (buy ? 0.0 : gap);
   double upper = InpScaleMax - margin - (buy ? gap : 0.0);
   return(MathMax(lower, MathMin(upper, position)));
}

double ConfirmationPosition(const int i, const bool buy)
{
   double offset = MathMax(InpArrowOffset, MathAbs(CCIBuffer[i]) * 0.05);
   if(!InpKeepMarkersVisible)
      return(CCIBuffer[i] + (buy ? -offset : offset) * 0.45);
   double span = InpScaleMax - InpScaleMin;
   double gap = span * 0.03;
   double lower = InpScaleMin + span * 0.06;
   double upper = InpScaleMax - span * 0.06;
   double arrow = buy ? BuySignalBuffer[i] : SellSignalBuffer[i];
   double desired = CCIBuffer[i] + (buy ? -offset : offset) * 0.45;
   if(buy) return(MathMin(upper, MathMax(arrow + gap, desired)));
   return(MathMax(lower, MathMin(arrow - gap, desired)));
}

// Independent OHLC evidence, using the signal candle and earlier data only.
// The "confirmed" mark remains a same-bar qualification, not a future-price promise.
bool PassPriceConfirmation(const int i, const bool buy,
                           const double &open[], const double &high[],
                           const double &low[], const double &close[])
{
   if(!InpUsePriceConfirmation) return(true);
   if(i < 0 || !Valid(open[i]) || !Valid(high[i]) ||
      !Valid(low[i]) || !Valid(close[i])) return(false);
   double range = high[i] - low[i];
   // Reject impossible OHLC and zero-range bars instead of accepting a false ratio.
   if(!MathIsValidNumber(range) || range <= 0.0 ||
      open[i] < low[i] || open[i] > high[i] ||
      close[i] < low[i] || close[i] > high[i]) return(false);
   // Price subtraction/division can put a mathematical boundary (0.60,
   // 0.40, 0.25) a few ulps on the wrong side. This bounded ratio tolerance
   // only covers roundoff; it does not relax candle direction/progress.
   double magnitude = MathMax(MathAbs(high[i]), MathAbs(low[i]));
   magnitude = MathMax(magnitude, MathMax(MathAbs(open[i]), MathAbs(close[i])));
   double ratioTolerance = MathMin(1.0e-7,
                                  MathMax(1.0e-12, 16.0 * DBL_EPSILON * (magnitude / range)));
   double bodyRatio = MathAbs(close[i] - open[i]) / range;
   if(bodyRatio + ratioTolerance < InpConfirmMinBodyRatio) return(false);
   double closeLocation = (close[i] - low[i]) / range;
   if(buy)
   {
      if(close[i] <= open[i] || closeLocation + ratioTolerance < InpConfirmMinCloseLocation) return(false);
   }
   else
   {
      if(close[i] >= open[i] || closeLocation - ratioTolerance > 1.0 - InpConfirmMinCloseLocation) return(false);
   }
   if(InpConfirmRequireCloseProgress)
   {
      if(i < 1 || !Valid(close[i-1])) return(false);
      if(buy ? close[i] <= close[i-1] : close[i] >= close[i-1]) return(false);
   }
   return(true);
}

// Same-bar price gate, without future bars or pending/backfilled arrows.
bool PassArrowPriceBreak(const int i, const bool buy,
                         const double &open[], const double &high[],
                         const double &low[], const double &close[])
{
   if(!InpRequirePriceBreak) return(true);
   if(i < 1 || !Valid(open[i]) || !Valid(close[i]) ||
      !Valid(high[i-1]) || !Valid(low[i-1]) || high[i-1] < low[i-1]) return(false);
   if(buy) return(close[i] > open[i] && close[i] > high[i-1]);
   return(close[i] < open[i] && close[i] < low[i-1]);
}

void CalculateSignals(const int rates_total, const int start,
                      const double &open[], const double &high[],
                      const double &low[], const double &close[])
{
   // Arrows and confirmation use only candle i and earlier candles.
   const int firstSignal = MathMax(InpCCIPeriod, InpTCCIPeriod);
   const int last = rates_total - (InpClosedBarsOnly ? 2 : 1);
   for(int i = start; i < rates_total; i++)
   {
      if((i & 255) == 0 && IsStopped()) return;
      SellSignalBuffer[i] = EMPTY_VALUE;
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellConfirmBuffer[i] = EMPTY_VALUE;
      BuyConfirmBuffer[i] = EMPTY_VALUE;
      // Distances, rather than absolute indices, survive history shifts.
      double buyAge = i > 0 ? MathMin((double)InpSignalCooldown, BuyAgeBuffer[i-1] + 1.0) : InpSignalCooldown;
      double sellAge = i > 0 ? MathMin((double)InpSignalCooldown, SellAgeBuffer[i-1] + 1.0) : InpSignalCooldown;
      double buyUsed = i > 0 ? BuyUsedBuffer[i-1] : 0.0;
      double sellUsed = i > 0 ? SellUsedBuffer[i-1] : 0.0;
      // A new same-side extreme is eligible only after a zero-line reset.
      if(i == 0 || !Valid(CCIBuffer[i-1]))
      {
         buyUsed = 0.0;
         sellUsed = 0.0;
      }
      else
      {
         if(CCIBuffer[i-1] >= 0.0) buyUsed = 0.0;
         if(CCIBuffer[i-1] <= 0.0) sellUsed = 0.0;
      }
      if(i >= firstSignal && i <= last)
      {
         bool buy = IsReversalBuy(i) && PassArrowPriceBreak(i, true, open, high, low, close) && PassTurboTurn(i, true) && PassHistogram(i, true) &&
                    (!InpOneSignalPerExtreme || buyUsed == 0.0);
         bool sell = IsReversalSell(i) && PassArrowPriceBreak(i, false, open, high, low, close) && PassTurboTurn(i, false) && PassHistogram(i, false) &&
                     (!InpOneSignalPerExtreme || sellUsed == 0.0);
         if(buy && !sell && buyAge >= InpSignalCooldown)
         {
            BuySignalBuffer[i] = SignalPosition(i, true);
            buyAge = 0.0;
            buyUsed = 1.0;
         }
         if(sell && !buy && sellAge >= InpSignalCooldown)
         {
            SellSignalBuffer[i] = SignalPosition(i, false);
            sellAge = 0.0;
            sellUsed = 1.0;
         }
      }
      BuyAgeBuffer[i] = buyAge;
      SellAgeBuffer[i] = sellAge;
      // Confirmation is evaluated on the SAME candle as an early arrow.
      // It does not wait for a future candle or backfill an old signal.
      if(InpShowConfirmationDots && i >= firstSignal && i <= last)
      {
         if(BuySignalBuffer[i] != EMPTY_VALUE && PassTurboTurn(i, true, true) && PassHistogram(i, true, true) &&
            PassPriceConfirmation(i, true, open, high, low, close))
            BuyConfirmBuffer[i] = ConfirmationPosition(i, true);
         if(SellSignalBuffer[i] != EMPTY_VALUE && PassTurboTurn(i, false, true) && PassHistogram(i, false, true) &&
            PassPriceConfirmation(i, false, open, high, low, close))
            SellConfirmBuffer[i] = ConfirmationPosition(i, false);
      }
      BuyUsedBuffer[i] = buyUsed;
      SellUsedBuffer[i] = sellUsed;
   }
}

//==================================================================
// M5 SIGNAL ALERT
//==================================================================
// Alert ONLY when a new arrow appears on M5.
// Existing historical arrows at initialization do not trigger alert.
// If InpClosedBarsOnly = true, only the latest CLOSED M5 bar is checked.
//==================================================================
void CheckM5SignalAlert(const int rates_total,
                        const datetime &time[])
{
   if(!InpEnabled || _Period != PERIOD_M5)
      return;

   if(!InpEnableAlert || rates_total < 2)
      return;

   int signalBar = rates_total - 1;

   if(InpClosedBarsOnly)
      signalBar = rates_total - 2;

   if(signalBar < 0)
      return;

   int signalType = 0;

   if(Valid(BuySignalBuffer[signalBar]) && (!InpAlertConfirmedOnly || Valid(BuyConfirmBuffer[signalBar])))
      signalType = 1;
   else
   if(Valid(SellSignalBuffer[signalBar]) && (!InpAlertConfirmedOnly || Valid(SellConfirmBuffer[signalBar])))
      signalType = -1;

   // First calculation: synchronize with existing arrows.
   // No alert for historical signals already present.
   if(!g_alertInitialized)
   {
      g_alertInitialized = true;
      g_lastObservedAlertBar = time[signalBar];

      if(signalType != 0)
      {
         g_lastAlertTime = time[signalBar];
         g_lastAlertType = signalType;
      }

      return;
   }

   // A historical rebuild is not a new live signal. Keep this time cursor
   // across left-boundary changes so fixed-size charts still alert new bars.
   if(time[signalBar] < g_lastObservedAlertBar) return;
   if(InpClosedBarsOnly && time[signalBar] == g_lastObservedAlertBar) return;
   g_lastObservedAlertBar = time[signalBar];

   // No new arrow.
   if(signalType == 0)
      return;

   // Same arrow already alerted.
   if(time[signalBar] == g_lastAlertTime &&
      signalType == g_lastAlertType)
      return;

   // Save state before Alert() to prevent duplicate alerts.
   g_lastAlertTime = time[signalBar];
   g_lastAlertType = signalType;

   if(signalType == 1)
   {
      Alert("Woodies CCI M5 - ", _Symbol, InpAlertConfirmedOnly ? " - BUY confirmed (same bar)" : " - BUY early signal");
   }
   else
   {
      Alert("Woodies CCI M5 - ", _Symbol, InpAlertConfirmedOnly ? " - SELL confirmed (same bar)" : " - SELL early signal");
   }
}

// No objects, timer, external indicator handles or heap objects are owned.
// Bound indicator buffers belong to MT5 and must not be ArrayFree'd.
void ResetRuntimeState()
{
   g_firstBarTime = 0;
   g_openBarTime = 0;
   g_alertInitialized = false;
   g_lastObservedAlertBar = 0;
   g_lastAlertTime = 0;
   g_lastAlertType = 0;
   g_priceCacheValid = false;
   g_cachedOpen = g_cachedHigh = g_cachedLow = g_cachedClose = 0.0;
   g_cachedTickVolume = g_cachedRealVolume = 0;
   g_disabledBars = -1;
}

void ClearDisabledBuffers()
{
   ArrayInitialize(HistVolumeBuffer, EMPTY_VALUE);
   ArrayInitialize(HistColorBuffer, 8.0);
   ArrayInitialize(HistDarkGreenBuffer, EMPTY_VALUE);
   ArrayInitialize(HistMaroonBuffer, EMPTY_VALUE);
   ArrayInitialize(HistGrayBuffer, EMPTY_VALUE);
   ArrayInitialize(HistYellowBuffer, EMPTY_VALUE);
   ArrayInitialize(CCIBuffer, EMPTY_VALUE);
   ArrayInitialize(TCCIBuffer, EMPTY_VALUE);
   ArrayInitialize(ZeroLineBuffer, EMPTY_VALUE);
   ArrayInitialize(Upper100Buffer, EMPTY_VALUE);
   ArrayInitialize(Lower100Buffer, EMPTY_VALUE);
   ArrayInitialize(Upper200Buffer, EMPTY_VALUE);
   ArrayInitialize(Lower200Buffer, EMPTY_VALUE);
   ArrayInitialize(SellSignalBuffer, EMPTY_VALUE);
   ArrayInitialize(BuySignalBuffer, EMPTY_VALUE);
   ArrayInitialize(SellConfirmBuffer, EMPTY_VALUE);
   ArrayInitialize(BuyConfirmBuffer, EMPTY_VALUE);
   ArrayInitialize(Price, EMPTY_VALUE);
   ArrayInitialize(RunBuffer, EMPTY_VALUE);
   ArrayInitialize(BuyAgeBuffer, EMPTY_VALUE);
   ArrayInitialize(SellAgeBuffer, EMPTY_VALUE);
   ArrayInitialize(BuyUsedBuffer, EMPTY_VALUE);
   ArrayInitialize(SellUsedBuffer, EMPTY_VALUE);
}

void ConfigureDisabledView()
{
   for(int plot = 0; plot < 16; plot++)
   {
      PlotIndexSetInteger(plot, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(plot, PLOT_SHOW_DATA, false);
   }
   // A disabled indicator remains attached, so its empty subwindow may remain.
   IndicatorSetString(INDICATOR_SHORTNAME, " ");
}

bool BindBuffer(const int index, double &buffer[], const ENUM_INDEXBUFFER_TYPE kind)
{
   if(SetIndexBuffer(index, buffer, kind)) return(true);
   Print("Woodies CCI: buffer binding failed at index ", index, ". Error: ", GetLastError());
   return(false);
}

// ON INIT
//==================================================================
int OnInit()
{
   if(!MathIsValidNumber(InpHistAbnormalVolume) || InpHistAbnormalVolume <= 1.5 ||
      !MathIsValidNumber(InpHistSmallBodyRatio) || InpHistSmallBodyRatio < 0.0 || InpHistSmallBodyRatio > 1.0 ||
      !MathIsValidNumber(InpHistLowVolumeRatio) || InpHistLowVolumeRatio <= 0.0 || InpHistLowVolumeRatio > 1.0 ||
      InpHistVolumeLookback < 1 || InpHistVolumeLookback > 10000 ||
      !MathIsValidNumber(InpConfirmMinBodyRatio) || InpConfirmMinBodyRatio < 0.0 ||
      InpConfirmMinBodyRatio > 1.0 || !MathIsValidNumber(InpConfirmMinCloseLocation) ||
      InpConfirmMinCloseLocation < 0.5 || InpConfirmMinCloseLocation > 1.0 ||
      (InpAlertConfirmedOnly && !InpShowConfirmationDots) ||
      InpHistogramMinRun < 1 ||
      !MathIsValidNumber(InpHistogramMinRetreat) || InpHistogramMinRetreat < 0.0 ||
      !MathIsValidNumber(InpTurboMinTurn) || InpTurboMinTurn < 0.0 ||
      InpCCIPeriod < 2 || InpTCCIPeriod < 2 || InpSignalCooldown < 0 ||
      !MathIsValidNumber(InpReversalLevel) || InpReversalLevel <= 0.0 ||
      !MathIsValidNumber(InpArrowOffset) || InpArrowOffset < 0.0 ||
      !MathIsValidNumber(InpScaleMin) || !MathIsValidNumber(InpScaleMax) ||
      !MathIsValidNumber(InpLower200) || !MathIsValidNumber(InpLower100) ||
      !MathIsValidNumber(InpZeroLevel) || !MathIsValidNumber(InpUpper100) ||
      !MathIsValidNumber(InpUpper200) || InpScaleMin >= InpScaleMax || !MathIsValidNumber(InpScaleMax - InpScaleMin) ||
      !(InpLower200 < InpLower100 && InpLower100 < InpZeroLevel &&
        InpZeroLevel < InpUpper100 && InpUpper100 < InpUpper200))
   {
      Print("Woodies CCI: invalid parameters; confirmed-only alerts require confirmation dots ON.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   ResetRuntimeState();
   if(!BindBuffer(15, HistVolumeBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(16, HistColorBuffer, INDICATOR_COLOR_INDEX)) return(INIT_FAILED);
   ArraySetAsSeries(HistVolumeBuffer, false);
   ArraySetAsSeries(HistColorBuffer, false);
   if(!BindBuffer(17, Price, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!BindBuffer(18, RunBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!BindBuffer(19, BuyAgeBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!BindBuffer(20, SellAgeBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!BindBuffer(21, BuyUsedBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!BindBuffer(22, SellUsedBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   ArraySetAsSeries(BuyUsedBuffer, false);
   ArraySetAsSeries(SellUsedBuffer, false);
   ArraySetAsSeries(Price, false);
   ArraySetAsSeries(RunBuffer, false);
   ArraySetAsSeries(BuyAgeBuffer, false);
   ArraySetAsSeries(SellAgeBuffer, false);
   //===============================================================
   // Histogram buffers
   //===============================================================
   if(!BindBuffer(0, HistDarkGreenBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(1, HistMaroonBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(2, HistGrayBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(3, HistYellowBuffer, INDICATOR_DATA)) return(INIT_FAILED);

   //===============================================================
   // CCI buffers
   //===============================================================
   if(!BindBuffer(4, CCIBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(5, TCCIBuffer, INDICATOR_DATA)) return(INIT_FAILED);

   //===============================================================
   // Level buffers
   //===============================================================
   if(!BindBuffer(6, ZeroLineBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(7, Upper100Buffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(8, Lower100Buffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(9, Upper200Buffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(10, Lower200Buffer, INDICATOR_DATA)) return(INIT_FAILED);

   //===============================================================
   // Signal buffers
   //===============================================================
   if(!BindBuffer(11, SellSignalBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(12, BuySignalBuffer, INDICATOR_DATA)) return(INIT_FAILED);

   if(!BindBuffer(13, SellConfirmBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!BindBuffer(14, BuyConfirmBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   ArraySetAsSeries(SellConfirmBuffer, false);
   ArraySetAsSeries(BuyConfirmBuffer, false);
   //===============================================================
   // Array direction
   //===============================================================
   ArraySetAsSeries(HistDarkGreenBuffer, false);
   ArraySetAsSeries(HistMaroonBuffer,    false);
   ArraySetAsSeries(HistGrayBuffer,      false);
   ArraySetAsSeries(HistYellowBuffer,    false);

   ArraySetAsSeries(CCIBuffer,  false);
   ArraySetAsSeries(TCCIBuffer, false);

   ArraySetAsSeries(ZeroLineBuffer, false);
   ArraySetAsSeries(Upper100Buffer, false);
   ArraySetAsSeries(Lower100Buffer, false);
   ArraySetAsSeries(Upper200Buffer, false);
   ArraySetAsSeries(Lower200Buffer, false);

   ArraySetAsSeries(SellSignalBuffer, false);
   ArraySetAsSeries(BuySignalBuffer,  false);

   // Set drawing types BEFORE glyphs and other plot properties. Changing
   // DRAW_TYPE can reset renderer defaults (DRAW_ARROW's default is a dot).
   for(int plot = 0; plot < 16; plot++)
      PlotIndexSetInteger(plot, PLOT_DRAW_TYPE,
                          plot < 4 ? (InpHistPriceVolumeColors ? DRAW_NONE : DRAW_HISTOGRAM) :
                          (plot < 11 ? DRAW_LINE : (plot < 15 ? DRAW_ARROW :
                          (InpHistPriceVolumeColors ? DRAW_COLOR_HISTOGRAM : DRAW_NONE))));

   PlotIndexSetInteger(15, PLOT_COLOR_INDEXES, 13);
   color histPalette[13] = {clrPaleGreen, clrLimeGreen, clrForestGreen, clrDarkGreen,
                           clrLightSalmon, clrTomato, clrFireBrick, clrMaroon, clrGray,
                           clrLightYellow, clrGold, clrOrange, clrDarkRed};
   for(int shade = 0; shade < 13; shade++)
      PlotIndexSetInteger(15, PLOT_LINE_COLOR, shade, histPalette[shade]);
   PlotIndexSetInteger(15, PLOT_DRAW_BEGIN, InpCCIPeriod - 1);
   PlotIndexSetInteger(15, PLOT_SHOW_DATA, InpHistPriceVolumeColors);
   PlotIndexSetInteger(15, PLOT_SHIFT, 0);
   PlotIndexSetDouble(15, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //===============================================================
   // Arrow codes
   //===============================================================
   PlotIndexSetInteger(11, PLOT_ARROW, 234);
   PlotIndexSetInteger(12, PLOT_ARROW, 233);
   PlotIndexSetInteger(13, PLOT_ARROW, 159);
   PlotIndexSetInteger(14, PLOT_ARROW, 159);

   //===============================================================
   // Empty values
   //===============================================================
   for(int i = 0; i < 15; i++)
   {
      PlotIndexSetInteger(i, PLOT_SHIFT, 0);
      PlotIndexSetDouble(
         i,
         PLOT_EMPTY_VALUE,
         EMPTY_VALUE
      );
   }

   //===============================================================
   // Data Window
   //
   // 0-10 visible
   // 11-14 visible: use Data Window to match arrow/dot to candle time
   //
   // The previous duplicate loop has been removed.
   //===============================================================
   for(int i = 0; i < 11; i++)
   {
      PlotIndexSetInteger(i, PLOT_SHOW_DATA, i >= 4 || !InpHistPriceVolumeColors);
   }

   PlotIndexSetInteger(
      11,
      PLOT_SHOW_DATA,
      true
   );

   PlotIndexSetInteger(
      12,
      PLOT_SHOW_DATA,
      true
   );

   //===============================================================
   // Scale
   //===============================================================
   IndicatorSetDouble(
      INDICATOR_MINIMUM,
      InpScaleMin
   );

   IndicatorSetDouble(
      INDICATOR_MAXIMUM,
      InpScaleMax
   );

   IndicatorSetInteger(
      INDICATOR_DIGITS,
      2
   );

   //===============================================================
   // Short name
   //===============================================================
   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "Woodies CCI 2.9.9 - Early + Same-bar Confirmation"
   );

   PlotIndexSetString(4, PLOT_LABEL, "CCI " + IntegerToString(InpCCIPeriod));
   PlotIndexSetString(5, PLOT_LABEL, "Turbo CCI " + IntegerToString(InpTCCIPeriod));
   for(int k = 0; k < 5; k++) PlotIndexSetInteger(k, PLOT_DRAW_BEGIN, InpCCIPeriod - 1);
   PlotIndexSetInteger(5, PLOT_DRAW_BEGIN, InpTCCIPeriod - 1);
   PlotIndexSetInteger(11, PLOT_DRAW_BEGIN, MathMax(InpCCIPeriod, InpTCCIPeriod));
   PlotIndexSetInteger(12, PLOT_DRAW_BEGIN, MathMax(InpCCIPeriod, InpTCCIPeriod));
   PlotIndexSetInteger(13, PLOT_DRAW_BEGIN, MathMax(InpCCIPeriod, InpTCCIPeriod));
   PlotIndexSetInteger(14, PLOT_DRAW_BEGIN, MathMax(InpCCIPeriod, InpTCCIPeriod));
   PlotIndexSetInteger(13, PLOT_SHOW_DATA, true);
   PlotIndexSetInteger(14, PLOT_SHOW_DATA, true);
   if(!InpEnabled) ConfigureDisabledView();
   return(INIT_SUCCEEDED);
}

//==================================================================
// ON DEINIT
//==================================================================
void OnDeinit(const int reason)
{
   // MT5 releases all 23 bound buffers on unload. Do not sweep chart objects
   // or comments owned by other indicators, and do not touch terminal logs.
   ResetRuntimeState();
}

//==================================================================
// ON CALCULATE
//==================================================================
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
   const int &spread[])
{
   if(rates_total <= 0 || IsStopped()) return(0);
   if(!InpEnabled)
   {
      // Clear once per buffer resize/reinitialization; every subsequent tick
      // exits immediately without CCI, histogram, signal or alert work.
      if(g_disabledBars != rates_total || prev_calculated == 0)
      {
         ClearDisabledBuffers();
         g_disabledBars = rates_total;
      }
      return(rates_total);
   }
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(volume, false);

   // A history reload or a shifted left boundary invalidates cached states.
   bool reset = prev_calculated <= 0 || prev_calculated > rates_total ||
                g_firstBarTime != time[0] ||
                (prev_calculated == rates_total && g_openBarTime != time[rates_total-1]);
   int openBar = rates_total - 1;
   // Volume-only ticks recolor the current bar without recalculating CCI/signals.
   if(!reset && prev_calculated == rates_total && g_priceCacheValid &&
      g_cachedOpen == open[openBar] && g_cachedHigh == high[openBar] && g_cachedLow == low[openBar] &&
      g_cachedClose == close[openBar])
   {
      bool changedVolume = InpHistUseRealVolume ? g_cachedRealVolume != volume[openBar] :
                                                g_cachedTickVolume != tick_volume[openBar];
      if(InpHistPriceVolumeColors && changedVolume)
         CalculateHistColors(rates_total, openBar, open, high, low, close, tick_volume, volume);
      if(IsStopped()) return(0);
      g_cachedTickVolume = tick_volume[openBar];
      g_cachedRealVolume = volume[openBar];
      return(rates_total);
   }
   int start = reset ? 0 : MathMax(0, prev_calculated - 1);
   // History rebuilds preserve the alert time cursor; only OnInit resets it.
   for(int i = start; i < rates_total; i++)
   {
      if((i & 255) == 0 && IsStopped()) return(0);
      // Algebraically equivalent typical price, with smaller intermediates.
      Price[i] = close[i] + ((high[i] - close[i]) + (low[i] - close[i])) / 3.0;
      CCIBuffer[i] = CCI(Price, i, InpCCIPeriod);
      TCCIBuffer[i] = CCI(Price, i, InpTCCIPeriod);
      ZeroLineBuffer[i] = InpZeroLevel;
      Upper100Buffer[i] = InpUpper100;
      Lower100Buffer[i] = InpLower100;
      Upper200Buffer[i] = InpUpper200;
      Lower200Buffer[i] = InpLower200;
   }
   if(IsStopped()) return(0);
   CalculateHistogram(rates_total, start);
   CalculateHistColors(rates_total, start, open, high, low, close, tick_volume, volume);
   if(IsStopped()) return(0);
   // Closed signals cannot change when only the open candle changes.
   bool updateSignals = !InpClosedBarsOnly || reset || prev_calculated != rates_total;
   if(updateSignals) CalculateSignals(rates_total, start, open, high, low, close);
   if(IsStopped()) return(0);
   // Do not prime alerts until both the signal candle and its predecessor exist.
   int signalBar = rates_total - (InpClosedBarsOnly ? 2 : 1);
   if(updateSignals && signalBar >= MathMax(InpCCIPeriod, InpTCCIPeriod))
      CheckM5SignalAlert(rates_total, time);
   g_firstBarTime = time[0];
   g_openBarTime = time[openBar];
   g_cachedOpen = open[openBar];
   g_cachedHigh = high[openBar];
   g_cachedLow = low[openBar];
   g_cachedClose = close[openBar];
   g_cachedTickVolume = tick_volume[openBar];
   g_cachedRealVolume = volume[openBar];
   g_priceCacheValid = true;
   return(rates_total);
}
//+------------------------------------------------------------------+
