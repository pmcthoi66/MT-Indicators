//+------------------------------------------------------------------+
//|              Woodies_CCI_MT5_V3_2_Light.mq5                     |
//|                 Woodies CCI - Reversal Only                     |
//+------------------------------------------------------------------+
#property strict
#property version   "3.21"
#property indicator_separate_window
#property indicator_buffers 24
#property indicator_plots   15

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
#property indicator_label14 "Sell Confirmed"
#property indicator_type14 DRAW_ARROW
#property indicator_color14 clrRed
#property indicator_width14 2
#property indicator_label15 "Buy Confirmed"
#property indicator_type15 DRAW_ARROW
#property indicator_color15 clrLimeGreen
#property indicator_width15 2

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

// RSI_Violation V2.2 core: native MT5 RSI, without a visible RSI plot.
// All new inputs are appended to preserve existing parameter positions.
input string InpSectionRSI = "=== Hidden RSI Trend Filter ===";
input bool InpUseRSIFilter = true;
input int InpRSIPeriod = 13;
input ENUM_APPLIED_PRICE InpRSIPrice = PRICE_CLOSE;
input double InpRSIBuyFloor = 30.0;   // BUY blocked strictly below this
input double InpRSISellCeiling = 70.0; // SELL blocked strictly above this
input bool InpRequireRSISlope = false; // Optional: BUY rising / SELL falling

// Regression uses the last N RSI samples ending at the signal candle.
// Levels are optional and OFF: the default filter now follows RSI direction.
input bool InpUseRSIRegression = true;
input int InpRSISlopeBars = 13;
input double InpRSISlopeDeadband = 0.0; // RSI points per bar; 0 = strict sign
input bool InpUseRSILevels = false;     // Optional old 30/70 rule

// A short RSI turn can release the long RSI trend's opposite-side block.
input bool InpAllowRSIShortTurn = true;
input int InpRSIShortSlopeBars = 3;
input double InpRSIShortSlopeDeadband = 1; // Minimum opposite short slope

//==================================================================
// BUFFERS
//==================================================================
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
double RSIFilterBuffer[];
double RSICopy[];
double RSITrendBuffer[];
double RSIShortTrendBuffer[];
int g_rsiHandle = INVALID_HANDLE;
bool g_rsiWaiting = false;
datetime g_firstBarTime = 0;
datetime g_openBarTime = 0;
// Core plots can advance while the RSI-dependent signal suffix is pending.
int g_signalCalculated = 0;

//==================================================================
// ALERT STATE
//==================================================================
datetime g_lastAlertTime = 0;
int      g_lastAlertType = 0;   // 1 = BUY, -1 = SELL
bool     g_alertInitialized = false;

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
   double sum = 0.0, correction = 0.0;
   for(int j = first; j <= i && !_StopFlag; j++)
   {
      double term = (p[j] - base) - correction;
      double next = sum + term;
      correction = (next - sum) - term;
      sum = next;
   }
   if(_StopFlag) return(EMPTY_VALUE);
   const double mean = sum / period;
   double dev = 0.0;
   correction = 0.0;
   for(int j = first; j <= i && !_StopFlag; j++)
   {
      double term = MathAbs((p[j] - base) - mean) - correction;
      double next = dev + term;
      correction = (next - dev) - term;
      dev = next;
   }
   if(_StopFlag) return(EMPTY_VALUE);
   dev /= period;
   if(dev <= 0.0)
      return(0.0);
   double denominator = 0.015 * dev;
   // Retain the usual rounding; avoid zero division for subnormal data.
   double value = denominator > 0.0 ? -mean / denominator : (-mean / dev) / 0.015;
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
   for(int i = start; i < rates_total && !_StopFlag; i++)
   {
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
   if(i < 2 || !Valid(TCCIBuffer[i-2])) return(false);
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
   if(i < 1 || RunBuffer[i-1] < InpHistogramMinRun) return(false);
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
bool ValidRSIFilterValue(const double value)
{
   return(Valid(value) && value >= 0.0 && value <= 100.0);
}

// Least-squares slope against candle number, in RSI points per bar.
// Subtract a reference RSI to retain exact zero for a flat sequence.
double RSIRegressionSlope(const int i, const int bars = 0)
{
   int n = bars > 0 ? bars : InpRSISlopeBars;
   int first = i - n + 1;
   if(first < InpRSIPeriod || !ValidRSIFilterValue(RSIFilterBuffer[i]))
      return(EMPTY_VALUE);
   double meanX = ((double)n - 1.0) * 0.5;
   double numerator = 0.0;
   double base = RSIFilterBuffer[first];
   if(!ValidRSIFilterValue(base)) return(EMPTY_VALUE);
   for(int k = 0; k < n && !_StopFlag; k++)
   {
      double value = RSIFilterBuffer[first+k];
      if(!ValidRSIFilterValue(value)) return(EMPTY_VALUE);
      numerator += ((double)k - meanX) * (value - base);
   }
   if(_StopFlag) return(EMPTY_VALUE);
   double size = (double)n;
   double denominator = size * (size * size - 1.0) / 12.0;
   double slope = numerator / denominator;
   return(Valid(slope) ? slope : EMPTY_VALUE);
}

bool PassRSIFilter(const int i, const bool buy)
{
   if(!InpUseRSIFilter) return(true);
   if(i < InpRSIPeriod || !ValidRSIFilterValue(RSIFilterBuffer[i])) return(false);
   if(InpUseRSIRegression)
   {
      double slope = RSITrendBuffer[i];
      if(!Valid(slope)) return(false); // Require N valid RSI candles.
      bool againstLong = buy ? slope < -InpRSISlopeDeadband
                             : slope > InpRSISlopeDeadband;
      if(againstLong)
      {
         if(!InpAllowRSIShortTurn) return(false);
         double shortSlope = RSIShortTrendBuffer[i];
         if(!Valid(shortSlope)) return(false);
         // Flat short RSI does not release the block: an opposite slope is required.
         bool recovering = buy ? shortSlope > InpRSIShortSlopeDeadband
                               : shortSlope < -InpRSIShortSlopeDeadband;
         if(!recovering) return(false);
      }
   }
   double rsi = RSIFilterBuffer[i];
   if(InpUseRSILevels)
   {
      if(buy && rsi < InpRSIBuyFloor) return(false);
      if(!buy && rsi > InpRSISellCeiling) return(false);
   }
   // Previous V3.0 one-candle slope option, still optional and OFF.
   if(!InpRequireRSISlope) return(true);
   if(i < 1 || !ValidRSIFilterValue(RSIFilterBuffer[i-1])) return(false);
   return(buy ? rsi > RSIFilterBuffer[i-1] : rsi < RSIFilterBuffer[i-1]);
}

// Data is aligned to the same candle as CCI and the emitted arrow.
bool LoadRSIFilter(const int rates_total, const int start)
{
   if(!InpUseRSIFilter) return(true);
   int count = rates_total - start;
   if(g_rsiHandle == INVALID_HANDLE || BarsCalculated(g_rsiHandle) < rates_total)
      return(false);
   if(CopyBuffer(g_rsiHandle, 0, 0, count, RSICopy) != count) return(false);
   // A successful copy can still contain uncalculated samples. Do not advance
   // the signal cursor until every needed closed/live RSI sample is valid.
   // The unfinished candle is not required by closed-bar signals.
   int lastNeeded = rates_total - (InpClosedBarsOnly ? 2 : 1);
   for(int i = MathMax(start, InpRSIPeriod); i <= lastNeeded && !_StopFlag; i++)
      if(!ValidRSIFilterValue(RSICopy[i-start])) return(false);
   if(_StopFlag) return(false);
   for(int i = start; i < rates_total && !_StopFlag; i++)
      RSIFilterBuffer[i] = i >= InpRSIPeriod && ValidRSIFilterValue(RSICopy[i-start])
                           ? RSICopy[i-start] : EMPTY_VALUE;
   return(!_StopFlag);
}

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

void CalculateSignals(const int rates_total, const int start)
{
   const int firstSignal = MathMax(InpCCIPeriod, InpTCCIPeriod);
   const int last = rates_total - (InpClosedBarsOnly ? 2 : 1);
   for(int i = start; i < rates_total && !_StopFlag; i++)
   {
      SellSignalBuffer[i] = EMPTY_VALUE;
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellConfirmBuffer[i] = EMPTY_VALUE;
      BuyConfirmBuffer[i] = EMPTY_VALUE;
      RSITrendBuffer[i] = EMPTY_VALUE;
      RSIShortTrendBuffer[i] = EMPTY_VALUE;
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
         // Cheap gates precede regression. The opposite CCI extremes make
         // BUY and SELL candidates mutually exclusive for a positive level.
         bool buy = buyAge >= InpSignalCooldown && IsReversalBuy(i) &&
                    PassTurboTurn(i, true) && PassHistogram(i, true) &&
                    (!InpOneSignalPerExtreme || buyUsed == 0.0);
         bool sell = sellAge >= InpSignalCooldown && IsReversalSell(i) &&
                     PassTurboTurn(i, false) && PassHistogram(i, false) &&
                     (!InpOneSignalPerExtreme || sellUsed == 0.0);
         if((buy || sell) && InpUseRSIFilter && InpUseRSIRegression)
         {
            RSITrendBuffer[i] = RSIRegressionSlope(i);
            double slope = RSITrendBuffer[i];
            bool againstLong = Valid(slope) &&
                               (buy ? slope < -InpRSISlopeDeadband : slope > InpRSISlopeDeadband);
            if(againstLong && InpAllowRSIShortTurn)
               RSIShortTrendBuffer[i] = RSIRegressionSlope(i, InpRSIShortSlopeBars);
         }
         if(_StopFlag) return;
         buy = buy && PassRSIFilter(i, true);
         sell = sell && PassRSIFilter(i, false);
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
         if(BuySignalBuffer[i] != EMPTY_VALUE && PassTurboTurn(i, true, true) && PassHistogram(i, true, true))
            BuyConfirmBuffer[i] = ConfirmationPosition(i, true);
         if(SellSignalBuffer[i] != EMPTY_VALUE && PassTurboTurn(i, false, true) && PassHistogram(i, false, true))
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
   if(_Period != PERIOD_M5)
      return;

   if(!InpEnableAlert || rates_total < 2)
      return;

   int signalBar = rates_total - 1;

   if(InpClosedBarsOnly)
      signalBar = rates_total - 2;

   if(signalBar < 0)
      return;

   int signalType = 0;

   if(BuySignalBuffer[signalBar] != EMPTY_VALUE)
      signalType = 1;
   else
   if(SellSignalBuffer[signalBar] != EMPTY_VALUE)
      signalType = -1;

   // First calculation: synchronize with existing arrows.
   // No alert for historical signals already present.
   if(!g_alertInitialized)
   {
      g_alertInitialized = true;

      if(signalType != 0)
      {
         g_lastAlertTime = time[signalBar];
         g_lastAlertType = signalType;
      }

      return;
   }

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
      Alert("Woodies CCI M5 - ", _Symbol, " - BUY signal");
   }
   else
   {
      Alert("Woodies CCI M5 - ", _Symbol, " - SELL signal");
   }
}

// ON INIT
//==================================================================
int OnInit()
{
   if(InpRSIShortSlopeBars < 2 || InpRSIShortSlopeBars >= InpRSISlopeBars ||
      !MathIsValidNumber(InpRSIShortSlopeDeadband) || InpRSIShortSlopeDeadband < 0.0 ||
      InpRSISlopeBars < 2 || !MathIsValidNumber(InpRSISlopeDeadband) ||
      InpRSISlopeDeadband < 0.0 || InpRSIPeriod < 2 || (int)InpRSIPrice < (int)PRICE_CLOSE ||
      (int)InpRSIPrice > (int)PRICE_WEIGHTED ||
      !MathIsValidNumber(InpRSIBuyFloor) || !MathIsValidNumber(InpRSISellCeiling) ||
      InpRSIBuyFloor < 0.0 || InpRSISellCeiling > 100.0 ||
      InpRSIBuyFloor >= InpRSISellCeiling ||
      InpHistogramMinRun < 1 ||
      !MathIsValidNumber(InpHistogramMinRetreat) || InpHistogramMinRetreat < 0.0 ||
      !MathIsValidNumber(InpTurboMinTurn) || InpTurboMinTurn < 0.0 ||
      InpCCIPeriod < 2 || InpTCCIPeriod < 2 || InpSignalCooldown < 0 ||
      !MathIsValidNumber(InpReversalLevel) || InpReversalLevel <= 0.0 ||
      !MathIsValidNumber(InpArrowOffset) || InpArrowOffset < 0.0 ||
      !MathIsValidNumber(InpScaleMin) || !MathIsValidNumber(InpScaleMax) ||
      !MathIsValidNumber(InpLower200) || !MathIsValidNumber(InpLower100) ||
      !MathIsValidNumber(InpZeroLevel) || !MathIsValidNumber(InpUpper100) ||
      !MathIsValidNumber(InpUpper200) || InpScaleMin >= InpScaleMax ||
      !MathIsValidNumber(InpScaleMax - InpScaleMin) ||
      !(InpLower200 < InpLower100 && InpLower100 < InpZeroLevel &&
        InpZeroLevel < InpUpper100 && InpUpper100 < InpUpper200))
   {
      Print("Woodies CCI: invalid periods, levels, cooldown, filters, offset or scale.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   g_rsiHandle = INVALID_HANDLE;
   g_rsiWaiting = false;
   if(!SetIndexBuffer(23, RSIShortTrendBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   ArraySetAsSeries(RSIShortTrendBuffer, false);
   if(!SetIndexBuffer(22, RSITrendBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   ArraySetAsSeries(RSITrendBuffer, false);
   if(!SetIndexBuffer(21, RSIFilterBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   ArraySetAsSeries(RSIFilterBuffer, false);
   ArraySetAsSeries(RSICopy, false);
   g_alertInitialized = false;
   g_lastAlertTime = 0;
   g_lastAlertType = 0;
   g_firstBarTime = 0;
   g_openBarTime = 0;
   g_signalCalculated = 0;
   if(!SetIndexBuffer(15, Price, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!SetIndexBuffer(16, RunBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!SetIndexBuffer(17, BuyAgeBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!SetIndexBuffer(18, SellAgeBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!SetIndexBuffer(19, BuyUsedBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   if(!SetIndexBuffer(20, SellUsedBuffer, INDICATOR_CALCULATIONS)) return(INIT_FAILED);
   ArraySetAsSeries(BuyUsedBuffer, false);
   ArraySetAsSeries(SellUsedBuffer, false);
   ArraySetAsSeries(Price, false);
   ArraySetAsSeries(RunBuffer, false);
   ArraySetAsSeries(BuyAgeBuffer, false);
   ArraySetAsSeries(SellAgeBuffer, false);
   //===============================================================
   // Histogram buffers
   //===============================================================
   if(!SetIndexBuffer(0, HistDarkGreenBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(1, HistMaroonBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(2, HistGrayBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(3, HistYellowBuffer, INDICATOR_DATA)) return(INIT_FAILED);

   //===============================================================
   // CCI buffers
   //===============================================================
   if(!SetIndexBuffer(4, CCIBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(5, TCCIBuffer, INDICATOR_DATA)) return(INIT_FAILED);

   //===============================================================
   // Level buffers
   //===============================================================
   if(!SetIndexBuffer(6, ZeroLineBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(7, Upper100Buffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(8, Lower100Buffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(9, Upper200Buffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(10, Lower200Buffer, INDICATOR_DATA)) return(INIT_FAILED);

   //===============================================================
   // Signal buffers
   //===============================================================
   if(!SetIndexBuffer(11, SellSignalBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(12, BuySignalBuffer, INDICATOR_DATA)) return(INIT_FAILED);

   if(!SetIndexBuffer(13, SellConfirmBuffer, INDICATOR_DATA)) return(INIT_FAILED);
   if(!SetIndexBuffer(14, BuyConfirmBuffer, INDICATOR_DATA)) return(INIT_FAILED);
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

   // Bindings cannot leave a newly created RSI handle behind on failure.
   if(InpUseRSIFilter)
   {
      g_rsiHandle = iRSI(_Symbol, _Period, InpRSIPeriod, InpRSIPrice);
      if(g_rsiHandle == INVALID_HANDLE)
      {
         Print("Woodies CCI: cannot create RSI handle. Error: ", GetLastError());
         return(INIT_FAILED);
      }
   }

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
   // 11-12 hidden
   //
   // The previous duplicate loop has been removed.
   //===============================================================
   for(int i = 0; i < 11; i++)
   {
      PlotIndexSetInteger(
         i,
         PLOT_SHOW_DATA,
         true
      );
   }

   PlotIndexSetInteger(
      11,
      PLOT_SHOW_DATA,
      false
   );

   PlotIndexSetInteger(
      12,
      PLOT_SHOW_DATA,
      false
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
      "Woodies CCI V3.21 - RSI Trend " + IntegerToString(InpRSISlopeBars) + "/" + IntegerToString(InpRSIShortSlopeBars)
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
   return(INIT_SUCCEEDED);
}

//==================================================================
// ON DEINIT
//==================================================================
void OnDeinit(const int reason)
{
   if(g_rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_rsiHandle);
      g_rsiHandle = INVALID_HANDLE;
   }
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
   if(rates_total <= 0 || _StopFlag) return(0);
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

   // A history reload or a shifted left boundary invalidates cached states.
   bool reset = prev_calculated <= 0 || prev_calculated > rates_total ||
                g_firstBarTime != time[0] ||
                (prev_calculated == rates_total && g_openBarTime != time[rates_total-1]);
   int start = reset ? 0 : MathMax(0, prev_calculated - 1);
   if(reset)
   {
      g_alertInitialized = false;
      g_signalCalculated = 0;
   }
   int signalStart = MathMax(0, MathMin(prev_calculated, g_signalCalculated) - 1);
   // Core plots do not depend on RSI availability. A separate signal cursor
   // retains the missing suffix without recalculating the whole CCI history.
   for(int i = start; i < rates_total && !_StopFlag; i++)
   {
      // Algebraically equivalent typical price, with smaller intermediates.
      Price[i] = close[i] + ((high[i] - close[i]) + (low[i] - close[i])) / 3.0;
      CCIBuffer[i] = CCI(Price, i, InpCCIPeriod);
      TCCIBuffer[i] = InpTCCIPeriod == InpCCIPeriod ? CCIBuffer[i] : CCI(Price, i, InpTCCIPeriod);
      ZeroLineBuffer[i] = InpZeroLevel;
      Upper100Buffer[i] = InpUpper100;
      Lower100Buffer[i] = InpLower100;
      Upper200Buffer[i] = InpUpper200;
      Lower200Buffer[i] = InpLower200;
   }
   if(_StopFlag) return(0);
   CalculateHistogram(rates_total, start);
   if(_StopFlag) return(0);
   g_firstBarTime = time[0];
   g_openBarTime = time[rates_total-1];

   // In closed-bar mode, an ordinary tick cannot change a signal. RSI is
   // loaded again on the next new bar, or while a missing suffix is pending.
   if(!reset && InpClosedBarsOnly && prev_calculated == rates_total &&
      g_signalCalculated == rates_total && !g_rsiWaiting)
   {
      CalculateSignals(rates_total, rates_total-1);
      return(_StopFlag ? 0 : rates_total);
   }
   if(!LoadRSIFilter(rates_total, signalStart))
   {
      if(_StopFlag) return(0);
      for(int i = start; i < rates_total && !_StopFlag; i++)
      {
         BuySignalBuffer[i] = EMPTY_VALUE;
         SellSignalBuffer[i] = EMPTY_VALUE;
         BuyConfirmBuffer[i] = EMPTY_VALUE;
         SellConfirmBuffer[i] = EMPTY_VALUE;
         RSIFilterBuffer[i] = EMPTY_VALUE;
         RSITrendBuffer[i] = EMPTY_VALUE;
         RSIShortTrendBuffer[i] = EMPTY_VALUE;
      }
      if(_StopFlag) return(0);
      if(!g_rsiWaiting)
         Print("Woodies CCI: waiting for RSI data; signals temporarily blocked.");
      g_rsiWaiting = true;
      return(rates_total);
   }
   g_rsiWaiting = false;
   CalculateSignals(rates_total, signalStart);
   if(_StopFlag) return(0);
   g_signalCalculated = rates_total;
   // Do not prime alerts until both the signal candle and its predecessor exist.
   int signalBar = rates_total - (InpClosedBarsOnly ? 2 : 1);
   if(signalBar >= MathMax(InpCCIPeriod, InpTCCIPeriod))
      CheckM5SignalAlert(rates_total, time);
   return(rates_total);
}
//+------------------------------------------------------------------+
