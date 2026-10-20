//+------------------------------------------------------------------+
//|                        MACD TradingView Style PRO v9.2 Final     |
//|                                       Copyright 2026, Littefrido |
//|                         https://www.mql5.com/en/users/littefrido |
//+------------------------------------------------------------------+
#property copyright "Littefrido"
#property link      "https://www.mql5.com/en/users/littefrido"
#property version   "9.20"
#property description "MACD EMA/EMA v9.2 - closed-bar signals; heuristic scores, not probabilities"

#property indicator_separate_window
#property indicator_buffers 12
#property indicator_plots   3

//--- ZERO LINE
#property indicator_level1       0.0
#property indicator_levelcolor   clrGray
#property indicator_levelstyle   STYLE_DOT

//--- Plot 1: MACD Line
#property indicator_label1  "MACD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_DASH
#property indicator_width1  2

//--- Plot 2: Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- Plot 3: 4-Color Histogram
#property indicator_label3  "Histogram"
#property indicator_type3   DRAW_COLOR_HISTOGRAM
#property indicator_color3  clrLimeGreen, clrDarkGreen, clrRed, clrLightCoral
#property indicator_style3  STYLE_DASH
#property indicator_width3  4

//--- ENUMS
enum ENUM_MACD_PRESET
{
   MACD_PRESET_12_26_9 = 0, // Standard (12, 26, 9)
   MACD_PRESET_8_21_5  = 1, // Fast Scalping XAUUSD (8, 21, 5)
   MACD_PRESET_CUSTOM  = 2  // Custom Parameters
};

enum ENUM_HTF_STATE
{
   HTF_STATE_NEUTRAL = 0,
   HTF_STATE_BULL    = 1,
   HTF_STATE_BEAR    = 2
};

//--- STRUCTS
struct VPEMetrics
{
   double volRatio;
   double bodyRatio;
   double rangeRatio;
   double efficiency;
   double closeLoc;
   double scoreContrib;
   string vpeStatus; // "EXPANSION", "ABSORPTION", "EXHAUSTION", "NO_SUPPLY_DEMAND", "NEUTRAL"
   bool   isValidSignal;
};

struct MomentumMetrics
{
   double macdSlopeAngle;
   double histoSlopeAngle;
   double normHistoDelta;
   bool   isExplosion;
   bool   isCompressed;
   bool   earlyTurnUp;
   bool   earlyTurnDown;
};

struct TrendMetrics
{
   bool   isUpTrend;
   bool   isDownTrend;
   double emaDist;
   string trendStr;
};

struct CandleMetrics
{
   bool   isBullishCandle;
   bool   isBearishCandle;
   double bodyRatio;
};

struct DivergenceMetrics
{
   string divList;
   bool   hasBullReg, hasBullHidden, hasBullTriple, hasBullExaggerated;
   bool   hasBearReg, hasBearHidden, hasBearTriple, hasBearExaggerated;
   bool   isConfirmed; // Trạng thái xác nhận từ bar InpSwingRight
};

struct ScoreMetrics
{
   int    buyScore;
   int    sellScore;
   string confidenceStr;
};

//--- INPUT PARAMETERS
input group "--- 1. MACD & MTF CONFIGURATION ---"
input ENUM_MACD_PRESET   InpPreset          = MACD_PRESET_8_21_5; // Cấu hình MACD
input int                InpFastEMA         = 12;                 // Fast EMA (Nếu Custom)
input int                InpSlowEMA         = 26;                 // Slow EMA (Nếu Custom)
input int                InpSignalEMA       = 9;                  // Signal EMA (Nếu Custom)
input ENUM_TIMEFRAMES    InpHTF             = PERIOD_M15;         // HTF Trend Filter
input bool               InpUseHTF          = true;               // Bật Lọc MTF (Closed Bar)

input group "--- 2. VOLUME PRICE EFFICIENCY (VPE ENGINE) ---"
input bool               InpUseVPE          = true;               // Bật Module VPE
input int                InpVolSmaPeriod    = 20;                 // Chu kỳ Volume SMA
input double             InpMinVolRatio     = 1.4;                // Ngưỡng Volume Expansion (Vol / SMA)
input double             InpMinEff          = 0.6;                // Efficiency tối thiểu (Body/Range)

input group "--- 3. ATR ANGLES & MOMENTUM ---"
input double             InpMinMacdAngle    = 15.0;               // MACD Slope Angle tối thiểu (Độ)
input double             InpMinHistoAngle   = 10.0;               // Histogram Angle tối thiểu (Độ)
input double             InpCompressThresh  = 0.05;               // Ngưỡng Nén (NormHisto < Ratio)
input double             InpExplosionThresh = 0.08;               // Ngưỡng Bùng nổ ATR Delta
input double             InpMinBodyAtrRatio = 0.35;               // Thân nến tối thiểu / ATR

input group "--- 4. PRO DIVERGENCE ENGINE ---"
input bool               InpShowDiv         = true;               // Bật Phân Kỳ
input bool               InpHiddenDiv       = true;               // Bật Phân Kỳ Ẩn (Hidden)
input bool               InpTripleDiv       = true;               // Bật Phân Kỳ Tam Giác (Triple)
input bool               InpExaggeratedDiv  = true;               // Bật Phân Kỳ Phóng Đại (Exaggerated)
input int                InpSwingLeft       = 3;                  // Swing Left
input int                InpSwingRight      = 2;                  // Swing Right (Khóa Repaint)
input bool InpDivOnPrice = true; // Draw divergence lines on price chart
input bool InpDivOnMACD = true; // Draw divergence lines in MACD pane
input color InpBullDivColor = clrLimeGreen;
input color InpBearDivColor = clrTomato;
input int                InpDivLookback     = 60;                 // Quét nến phân kỳ

input group "--- 5. DASHBOARD & ALERTS ---"
input bool               InpShowDash        = false;               // Bật Dashboard
input bool               InpAlertPopup      = false;              // Alert Popup
input bool               InpAlertPush       = false;              // Push Mobile
input bool               InpAlertZeroCross  = true;               // Báo MACD Zero Line Cross
input bool               InpAlertExplosion  = true;               // Báo Momentum Explosion
input bool               InpAlertEarlyTurn  = true;               // Báo Sớm Early Momentum Turn
input int                InpAlertCooldown   = 3;                  // Cooldown (Nến)
input int                InpAtrPeriod       = 14;                 // Chu kỳ ATR

input group "--- 6. CONFIRMED SIGNALS ---"
input int InpHistoryBars = 300; // Object history window; 0 = latest closed bar only
input int InpMinSignalScore = 65; // Heuristic score, NOT a win probability
// MACD values remain live. Scores, divergence, arrows and alerts use closed bars.

//--- INDICATOR BUFFERS
double MACDBuffer[];
double SignalBuffer[];
double HistogramBuffer[];
double ColorBuffer[];
double BuyScoreBuffer[];      // Buffer 4: Expose cho EA (0-100)
double SellScoreBuffer[];     // Buffer 5: Expose cho EA (0-100)
double VPEScoreBuffer[];      // Buffer 6: Expose VPE Contrib cho EA
double FastEMABuffer[];
double SlowEMABuffer[];
double ATRBuffer[];
double EMA20Buffer[];
double EMA50Buffer[];

//--- GLOBAL VARIABLES
int            atr_handle        = INVALID_HANDLE;
int            ema20_handle      = INVALID_HANDLE;
int            ema50_handle      = INVALID_HANDLE;
datetime g_htfClosedTime = 0;
int g_htfCount = 0;
datetime g_htfTimes[];
double g_copyAtr[], g_copy20[], g_copy50[];
datetime g_firstTime = 0;
datetime g_lastProcessed = 0;
bool g_emitAlerts = false;
datetime g_signalTime = 0;
string         PrefixID          = "";
string         g_shortName       = "";
datetime       g_lastBarTime     = 0;
bool g_useHTF = false;
datetime g_alertTime = 0;
int            g_fastPeriod, g_slowPeriod, g_signalPeriod;

// HTF Cache Arrays; rebuilt on HTF close/history changes, never every tick
double         g_htfMacdArr[];
double         g_htfSigArr[];

// Dashboard State Metrics
ScoreMetrics      g_latestScore;
VPEMetrics        g_latestVPE;
MomentumMetrics   g_latestMom;
TrendMetrics      g_latestTrend;
ENUM_HTF_STATE    g_htfState     = HTF_STATE_NEUTRAL;
DivergenceMetrics g_latestDiv;

//--- FORWARD DECLARATIONS
double GetMomentumScore(double angle, double minAngle);
VPEMetrics CalculateVPE(int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[]);
void CalculateMomentum(int idx, double atrVal, double prevAtr, MomentumMetrics &mom);
void CalculateTrend(int idx, double atrVal, TrendMetrics &trend);
ENUM_HTF_STATE CalculateHTF(datetime barTime);
void CalculateCandleQuality(int idx, double atrVal, const double &open[], const double &close[], CandleMetrics &candle);
void CalculateDivergence(int idx, int total, const double &high[], const double &low[], const double &close[], const datetime &time[], ENUM_HTF_STATE htfState, DivergenceMetrics &div);
void CalculateScores(int idx, const VPEMetrics &vpe, const MomentumMetrics &mom, const TrendMetrics &trend, ENUM_HTF_STATE htfState, const CandleMetrics &candle, const DivergenceMetrics &div, ScoreMetrics &score);
void ProcessBarSignal(int idx, int total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const datetime &time[], bool isLiveBar);
bool IsSwingLow(int idx, int left, int right);
bool IsSwingHigh(int idx, int left, int right);
bool IsPriceSwingLow(int idx, int left, int right, const double &low[]);
bool IsPriceSwingHigh(int idx, int left, int right, const double &high[]);
void UpdateOrCreateTrendLine(string name, int subWindow, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width);
void UpdateOrCreateTextLabel(string name, int subWindow, datetime t, double p, string text, color clr, bool belowBar);
void UpdateOrCreateArrow(string name, datetime time, double price, ushort arrowCode, color clr);
void UpdateDashboard();
void TriggerConsolidatedAlert(string alertMsg);

//+------------------------------------------------------------------+
//| Get Color Index for Histogram                                    |
//+------------------------------------------------------------------+
int GetMomentumColor(double cur, double prev, double atr)
{
   if(cur >= 0) return cur > prev ? 0 : 1;
   return cur > prev ? 3 : 2;
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpPreset == MACD_PRESET_8_21_5)
   {
      g_fastPeriod = 8; g_slowPeriod = 21; g_signalPeriod = 5;
   }
   else if(InpPreset == MACD_PRESET_12_26_9)
   {
      g_fastPeriod = 12; g_slowPeriod = 26; g_signalPeriod = 9;
   }
   else
   {
      g_fastPeriod = InpFastEMA; g_slowPeriod = InpSlowEMA; g_signalPeriod = InpSignalEMA;
   }

   if(g_fastPeriod < 1 || g_slowPeriod <= g_fastPeriod || g_signalPeriod < 1 ||
      InpAtrPeriod < 1 || InpVolSmaPeriod < 1 || InpSwingLeft < 1 || InpSwingRight < 1 ||
      InpDivLookback < InpSwingLeft + InpSwingRight + 2 || InpHistoryBars < 0 ||
      InpAlertCooldown < 0 || InpMinSignalScore < 0 || InpMinSignalScore > 100 ||
      InpMinMacdAngle <= 0 || InpMinHistoAngle <= 0 || InpMinVolRatio <= 0 ||
      InpMinEff < 0 || InpMinEff > 1 || InpCompressThresh < 0 ||
      InpExplosionThresh <= 0 || InpMinBodyAtrRatio < 0)
      return INIT_PARAMETERS_INCORRECT;
   g_useHTF=InpUseHTF;
   if(g_useHTF && PeriodSeconds(InpHTF) <= PeriodSeconds(_Period))
   {
      Print("HTF filter disabled: selected HTF is not above chart timeframe. MACD remains active.");
      g_useHTF=false;
   }
   PrefixID = "TV_MACD_" + IntegerToString(ChartID()) + "_" + IntegerToString((long)GetMicrosecondCount()) + "_";
   SetIndexBuffer(0,  MACDBuffer,         INDICATOR_DATA);
   SetIndexBuffer(1,  SignalBuffer,       INDICATOR_DATA);
   SetIndexBuffer(2,  HistogramBuffer,    INDICATOR_DATA);
   SetIndexBuffer(3,  ColorBuffer,        INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,  BuyScoreBuffer,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,  SellScoreBuffer,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,  VPEScoreBuffer,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,  FastEMABuffer,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,  SlowEMABuffer,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,  ATRBuffer,          INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, EMA20Buffer,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, EMA50Buffer,        INDICATOR_CALCULATIONS);

   ArraySetAsSeries(MACDBuffer,         false);
   ArraySetAsSeries(SignalBuffer,       false);
   ArraySetAsSeries(HistogramBuffer,    false);
   ArraySetAsSeries(ColorBuffer,        false);
   ArraySetAsSeries(BuyScoreBuffer,     false);
   ArraySetAsSeries(SellScoreBuffer,    false);
   ArraySetAsSeries(VPEScoreBuffer,     false);
   ArraySetAsSeries(FastEMABuffer,      false);
   ArraySetAsSeries(SlowEMABuffer,      false);
   ArraySetAsSeries(ATRBuffer,          false);
   ArraySetAsSeries(EMA20Buffer,        false);
   ArraySetAsSeries(EMA50Buffer,        false);

   int firstPlotBar = g_slowPeriod + g_signalPeriod - 1;
   for(int i = 0; i < 3; i++)
   {
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, firstPlotBar);
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   }

   atr_handle   = iATR(_Symbol, _Period, InpAtrPeriod);
   ema20_handle = iMA(_Symbol, _Period, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50_handle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(atr_handle == INVALID_HANDLE || ema20_handle == INVALID_HANDLE || ema50_handle == INVALID_HANDLE)
   {
      Print("❌ [INIT ERROR] Không thể khởi tạo Handles!");
      return INIT_FAILED;
   }

   g_shortName = StringFormat("MACD TV PRO v9.2 (%d,%d,%d)", g_fastPeriod, g_slowPeriod, g_signalPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, g_shortName);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atr_handle != INVALID_HANDLE)      IndicatorRelease(atr_handle);
   if(ema20_handle != INVALID_HANDLE)    IndicatorRelease(ema20_handle);
   if(ema50_handle != INVALID_HANDLE)    IndicatorRelease(ema50_handle);
   ArrayFree(g_htfMacdArr); ArrayFree(g_htfSigArr); ArrayFree(g_htfTimes);
   ArrayFree(g_copyAtr); ArrayFree(g_copy20); ArrayFree(g_copy50);
   if(PrefixID != "") ObjectsDeleteAll(0, PrefixID);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| MAIN CALCULATION ENGINE                                          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
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
   ArraySetAsSeries(time,false); ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false); ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false); ArraySetAsSeries(tick_volume,false);
   if(rates_total < 3) return 0;
   bool reset = prev_calculated <= 0 || prev_calculated > rates_total || g_firstTime != time[0];
   int start = reset ? 0 : MathMax(1,prev_calculated-1);
   int count = rates_total-start;
   if(BarsCalculated(atr_handle)<rates_total || BarsCalculated(ema20_handle)<rates_total ||
      BarsCalculated(ema50_handle)<rates_total) return prev_calculated;
   // Copy into temporary ascending arrays, then align the tail explicitly.
   if(CopyBuffer(atr_handle,0,0,count,g_copyAtr)!=count ||
      CopyBuffer(ema20_handle,0,0,count,g_copy20)!=count ||
      CopyBuffer(ema50_handle,0,0,count,g_copy50)!=count) return prev_calculated;
   if(reset) g_htfClosedTime=0;
   if(g_useHTF && !RefreshHTF()) return prev_calculated;
   if(reset)
   {
      ObjectsDeleteAll(0,PrefixID);
      ArrayInitialize(BuyScoreBuffer,EMPTY_VALUE);
      ArrayInitialize(SellScoreBuffer,EMPTY_VALUE);
      ArrayInitialize(VPEScoreBuffer,EMPTY_VALUE);
      g_lastProcessed=0; g_signalTime=0; g_alertTime=0; g_firstTime=time[0];
   }
   double af=2.0/(g_fastPeriod+1), as=2.0/(g_slowPeriod+1), ag=2.0/(g_signalPeriod+1);
   for(int i=start;i<rates_total;i++)
   {
      int j=i-start;
      ATRBuffer[i]=g_copyAtr[j]; EMA20Buffer[i]=g_copy20[j]; EMA50Buffer[i]=g_copy50[j];
      if(i==0)
      {
         FastEMABuffer[i]=close[i]; SlowEMABuffer[i]=close[i];
         MACDBuffer[i]=0; SignalBuffer[i]=0;
      }
      else
      {
         FastEMABuffer[i]=af*close[i]+(1-af)*FastEMABuffer[i-1];
         SlowEMABuffer[i]=as*close[i]+(1-as)*SlowEMABuffer[i-1];
         MACDBuffer[i]=FastEMABuffer[i]-SlowEMABuffer[i];
         SignalBuffer[i]=ag*MACDBuffer[i]+(1-ag)*SignalBuffer[i-1];
      }
      HistogramBuffer[i]=MACDBuffer[i]-SignalBuffer[i];
      ColorBuffer[i]=GetMomentumColor(HistogramBuffer[i],i>0?HistogramBuffer[i-1]:0,ATRBuffer[i]);
   }
   int closed=rates_total-2;
   int warmup=MathMax(50,MathMax(InpVolSmaPeriod,MathMax(InpAtrPeriod,g_slowPeriod+g_signalPeriod)));
   if(reset || time[closed]!=g_lastProcessed)
   {
      // Same ordered closed-bar processing on initial history and live updates.
      int scan=reset ? MathMax(warmup,closed-MathMax(0,InpHistoryBars-1)) : MathMax(warmup,start);
      for(int i=scan;i<=closed;i++)
      {
         g_emitAlerts=!reset && i==closed;
         ProcessBarSignal(i,rates_total,open,high,low,close,tick_volume,time,i==closed);
      }
      g_emitAlerts=false; g_lastProcessed=time[closed]; g_lastBarTime=time[closed];
      if(closed>=warmup && InpShowDash) UpdateDashboard();
      datetime cutoff=time[MathMax(0,closed-MathMax(0,InpHistoryBars-1))];
      for(int o=ObjectsTotal(0)-1;o>=0;o--)
      {
         string name=ObjectName(0,o);
         if(StringFind(name,PrefixID)!=0 || name==PrefixID+"Dashboard_Label") continue;
         if((datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0)<cutoff) ObjectDelete(0,name);
      }
   }
   // Current bar score deliberately unavailable until close.
   BuyScoreBuffer[rates_total-1]=EMPTY_VALUE;
   SellScoreBuffer[rates_total-1]=EMPTY_VALUE;
   VPEScoreBuffer[rates_total-1]=EMPTY_VALUE;
   return rates_total;
}

// EMA/EMA HTF cache. Includes timestamps; never indexes a stale cache by Bars().
bool RefreshHTF()
{
   int n=Bars(_Symbol,InpHTF);
   datetime last=iTime(_Symbol,InpHTF,1);
   if(n<g_slowPeriod+g_signalPeriod+2 || last==0) return false;
   if(last==g_htfClosedTime && n==g_htfCount) return true;
   MqlRates bars[]; ArraySetAsSeries(bars,false);
   if(CopyRates(_Symbol,InpHTF,0,n,bars)!=n) return false;
   ArrayResize(g_htfMacdArr,n); ArrayResize(g_htfSigArr,n); ArrayResize(g_htfTimes,n);
   double af=2.0/(g_fastPeriod+1), as=2.0/(g_slowPeriod+1), ag=2.0/(g_signalPeriod+1);
   double fast=bars[0].close, slow=fast, signal=0;
   for(int i=0;i<n;i++)
   {
      if(i>0) { fast=af*bars[i].close+(1-af)*fast; slow=as*bars[i].close+(1-as)*slow; }
      double macd=fast-slow;
      signal=ag*macd+(1-ag)*signal;
      g_htfMacdArr[i]=macd; g_htfSigArr[i]=signal; g_htfTimes[i]=bars[i].time;
   }
   g_htfCount=n; g_htfClosedTime=last;
   return true;
}

//+------------------------------------------------------------------+
//| TIERED MOMENTUM SCORE EVALUATOR                                  |
//+------------------------------------------------------------------+
double GetMomentumScore(double angle, double minAngle)
{
   double a = MathAbs(angle);

   if(a < minAngle)
      return 0.0;

   if(a < minAngle * 2.0)
      return 5.0;

   if(a < minAngle * 3.5)
      return 10.0;

   return 15.0;
}

//+------------------------------------------------------------------+
//| SUB-MODULE 1: VOLUME PRICE EFFICIENCY (VPE ENGINE)              |
//+------------------------------------------------------------------+
VPEMetrics CalculateVPE(int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
{
   VPEMetrics vpe;
   vpe.volRatio       = 1.0;
   vpe.bodyRatio      = 0.0;
   vpe.rangeRatio     = 0.0;
   vpe.efficiency     = 0.0;
   vpe.closeLoc       = 0.5;
   vpe.scoreContrib   = 0.0;
   vpe.vpeStatus      = "NEUTRAL";
   vpe.isValidSignal  = false;

   if(!InpUseVPE || idx < InpVolSmaPeriod) return vpe;

   double sumVol = 0.0;
   for(int k = 0; k < InpVolSmaPeriod; k++) sumVol += (double)volume[idx - k];
   double volSma = sumVol / InpVolSmaPeriod;

   if(volSma > 0) vpe.volRatio = (double)volume[idx] / volSma;

   double atrVal = (ATRBuffer[idx] > 0) ? ATRBuffer[idx] : 1.0;
   double range  = high[idx] - low[idx];
   double body   = MathAbs(close[idx] - open[idx]);

   vpe.rangeRatio = range / atrVal;
   vpe.bodyRatio  = body / atrVal;
   vpe.efficiency = (range > 0) ? (body / range) : 0.0;
   vpe.closeLoc   = (range > 0) ? ((close[idx] - low[idx]) / range) : 0.5;

   bool isBull = (close[idx] > open[idx]);

   // 1. VOLUME EXPANSION
   if(vpe.volRatio >= InpMinVolRatio && vpe.bodyRatio >= InpMinBodyAtrRatio && vpe.efficiency >= InpMinEff)
   {
      if((isBull && vpe.closeLoc >= 0.70) || (!isBull && vpe.closeLoc <= 0.30))
      {
         vpe.scoreContrib  = +20.0;
         vpe.vpeStatus     = "EXPANSION";
         vpe.isValidSignal = true;
      }
   }
   // 2. ABSORPTION / EXHAUSTION
   else if(vpe.volRatio >= 1.5 && (vpe.efficiency < 0.35 || vpe.bodyRatio < 0.25))
   {
      vpe.scoreContrib  = -15.0;
      vpe.vpeStatus     = (vpe.closeLoc > 0.35 && vpe.closeLoc < 0.65) ? "ABSORPTION" : "EXHAUSTION";
      vpe.isValidSignal = false;
   }
   // 3. NO SUPPLY / NO DEMAND PULLBACK
   else if(vpe.volRatio < 0.65 && vpe.bodyRatio < 0.35)
   {
      vpe.scoreContrib  = +10.0;
      vpe.vpeStatus     = "NO_SUPPLY_DEMAND";
      vpe.isValidSignal = true;
   }

   return vpe;
}

//+------------------------------------------------------------------+
//| SUB-MODULE 2: CALCULATE MOMENTUM                                |
//+------------------------------------------------------------------+
void CalculateMomentum(int idx, double atrVal, double prevAtr, MomentumMetrics &mom)
{
   double macdSlope  = (MACDBuffer[idx] - MACDBuffer[idx-1]) / atrVal;
   double histoSlope = (HistogramBuffer[idx] - HistogramBuffer[idx-1]) / atrVal;

   mom.macdSlopeAngle  = MathArctan(macdSlope) * (180.0 / M_PI);
   mom.histoSlopeAngle = MathArctan(histoSlope) * (180.0 / M_PI);

   double normHisto     = HistogramBuffer[idx] / atrVal;
   double prevNormHisto = HistogramBuffer[idx-1] / (prevAtr > 0 ? prevAtr : atrVal);
   mom.normHistoDelta   = MathAbs(normHisto - prevNormHisto);

   mom.isExplosion  = (mom.normHistoDelta >= InpExplosionThresh);
   mom.isCompressed = (MathAbs(normHisto) < InpCompressThresh);

   mom.earlyTurnUp   = (HistogramBuffer[idx-1] < HistogramBuffer[idx-2] && HistogramBuffer[idx] > HistogramBuffer[idx-1] && HistogramBuffer[idx] < 0 && mom.histoSlopeAngle > 5.0);
   mom.earlyTurnDown = (HistogramBuffer[idx-1] > HistogramBuffer[idx-2] && HistogramBuffer[idx] < HistogramBuffer[idx-1] && HistogramBuffer[idx] > 0 && mom.histoSlopeAngle < -5.0);
}

//+------------------------------------------------------------------+
//| SUB-MODULE 3: CALCULATE TREND                                   |
//+------------------------------------------------------------------+
void CalculateTrend(int idx, double atrVal, TrendMetrics &trend)
{
   double emaF0 = EMA20Buffer[idx], emaF1 = EMA20Buffer[idx-1];
   double emaS0 = EMA50Buffer[idx];

   double emaSlope = (emaF0 - emaF1) / atrVal;
   trend.emaDist   = MathAbs(emaF0 - emaS0) / atrVal;

   trend.isUpTrend   = (emaF0 > emaS0) && (emaSlope > 0.05);
   trend.isDownTrend = (emaF0 < emaS0) && (emaSlope < -0.05);

   trend.trendStr  = trend.isUpTrend ? StringFormat("BULLISH (D:%.2f)", trend.emaDist) : 
                    (trend.isDownTrend ? StringFormat("BEARISH (D:%.2f)", trend.emaDist) : "SIDEWAY");
}

//+------------------------------------------------------------------+
//| SUB-MODULE 4: CALCULATE HTF (NON-REPAINTING)                    |
//+------------------------------------------------------------------+
ENUM_HTF_STATE CalculateHTF(datetime barTime)
{
   if(!g_useHTF) return HTF_STATE_NEUTRAL;
   // Latest completed HTF candle at the LTF bar OPEN (conservative, reproducible).
   int lo=0, hi=ArraySize(g_htfTimes)-1, containing=-1;
   while(lo<=hi)
   {
      int mid=(lo+hi)/2;
      if(g_htfTimes[mid]<=barTime) { containing=mid; lo=mid+1; }
      else hi=mid-1;
   }
   int index=containing-1;
   if(index<g_slowPeriod+g_signalPeriod-1) return HTF_STATE_NEUTRAL;
   if(g_htfMacdArr[index]>g_htfSigArr[index]) return HTF_STATE_BULL;
   if(g_htfMacdArr[index]<g_htfSigArr[index]) return HTF_STATE_BEAR;
   return HTF_STATE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| SUB-MODULE 5: CALCULATE CANDLE QUALITY                          |
//+------------------------------------------------------------------+
void CalculateCandleQuality(int idx, double atrVal, const double &open[], const double &close[], CandleMetrics &candle)
{
   double body = MathAbs(close[idx] - open[idx]);
   candle.bodyRatio       = body / atrVal;
   candle.isBullishCandle = (close[idx] > open[idx]) && (candle.bodyRatio >= InpMinBodyAtrRatio);
   candle.isBearishCandle = (close[idx] < open[idx]) && (candle.bodyRatio >= InpMinBodyAtrRatio);
}

//+------------------------------------------------------------------+
//| SUB-MODULE 6: HIGH-PERFORMANCE DIVERGENCE ENGINE                |
//+------------------------------------------------------------------+
void CalculateDivergence(int idx, int total, const double &high[], const double &low[], const double &close[], const datetime &time[], ENUM_HTF_STATE htfState, DivergenceMetrics &div)
{
   div.divList = "";
   div.hasBullReg = div.hasBullHidden = div.hasBullTriple = div.hasBullExaggerated = false;
   div.hasBearReg = div.hasBearHidden = div.hasBearTriple = div.hasBearExaggerated = false;
   div.isConfirmed = false;

   if(!InpShowDiv) return;

   int macdSubWindow = ChartWindowFind();
   if(macdSubWindow < 0) return;

   // 1. BULLISH DIVERGENCE
   int p1 = -1, p2 = -1, p3 = -1;
   for(int k = idx - InpSwingRight; k >= MathMax(InpSwingLeft,idx - InpDivLookback); k--)
   {
      if(IsSwingLow(k, InpSwingLeft, InpSwingRight))
      {
         if(p1 == -1) p1 = k;
         else if(p2 == -1) p2 = k;
         else { p3 = k; break; }
      }
   }

   if(p1 != -1 && p2 != -1)
   {
      double pr1 = low[p1], pr2 = low[p2];
      datetime t1 = time[p2], t2 = time[p1];

      double lastSwingHigh = 0.0;
      for(int x = p1 - 1; x >= p2; x--)
      {
         if(IsPriceSwingHigh(x, InpSwingLeft, InpSwingRight, high))
         {
            lastSwingHigh = high[x];
            break;
         }
      }
      if(lastSwingHigh == 0.0) lastSwingHigh = high[p1 - 1];
      bool isReversalConfirmed = (close[idx] > lastSwingHigh);

      if(pr1 < pr2 && MACDBuffer[p1] > MACDBuffer[p2] && MACDBuffer[p1] < 0)
      {
         if(isReversalConfirmed && htfState != HTF_STATE_BEAR)
         {
            div.hasBullReg = true; div.isConfirmed = true; div.divList += "REG_BULL ";
            DrawDivergencePair("REG_BULL",true,false,macdSubWindow,t1,pr2,MACDBuffer[p2],t2,pr1,MACDBuffer[p1],time[idx],low[idx]);
         }
      }
      if(InpHiddenDiv && pr1 > pr2 && MACDBuffer[p1] < MACDBuffer[p2] && MACDBuffer[p1] < 0)
      {
         div.hasBullHidden = true; div.divList += "HID_BULL ";
         DrawDivergencePair("HID_BULL",true,true,macdSubWindow,t1,pr2,MACDBuffer[p2],t2,pr1,MACDBuffer[p1],time[idx],low[idx]);
      }
      if(InpExaggeratedDiv && MathAbs(pr1 - pr2) <= ATRBuffer[idx] * 0.15 && MACDBuffer[p1] > MACDBuffer[p2] && MACDBuffer[p1] < 0)
      {
         div.hasBullExaggerated = true; div.divList += "EX_BULL ";
         DrawDivergencePair("EX_BULL",true,false,macdSubWindow,t1,pr2,MACDBuffer[p2],t2,pr1,MACDBuffer[p1],time[idx],low[idx]);
      }
      if(InpTripleDiv && p3 != -1)
      {
         if(pr1 < pr2 && pr2 < low[p3] && MACDBuffer[p1] > MACDBuffer[p2] && MACDBuffer[p2] > MACDBuffer[p3] && MACDBuffer[p1] < 0)
         {
            div.hasBullTriple = true; div.divList += "TRIPLE_BULL ";
         DrawDivergencePair("TRIPLE_BULL",true,false,macdSubWindow,t1,pr2,MACDBuffer[p2],t2,pr1,MACDBuffer[p1],time[idx],low[idx]);
         DrawDivergencePair("TRIPLE_BULL_LEG1",true,false,macdSubWindow,time[p3],low[p3],MACDBuffer[p3],t1,pr2,MACDBuffer[p2],time[idx],low[idx],false);
         }
      }
   }

   // 2. BEARISH DIVERGENCE
   int r1 = -1, r2 = -1, r3 = -1;
   for(int k = idx - InpSwingRight; k >= MathMax(InpSwingLeft,idx - InpDivLookback); k--)
   {
      if(IsSwingHigh(k, InpSwingLeft, InpSwingRight))
      {
         if(r1 == -1) r1 = k;
         else if(r2 == -1) r2 = k;
         else { r3 = k; break; }
      }
   }

   if(r1 != -1 && r2 != -1)
   {
      double pr1 = high[r1], pr2 = high[r2];
      datetime t1 = time[r2], t2 = time[r1];

      double lastSwingLow = 0.0;
      for(int x = r1 - 1; x >= r2; x--)
      {
         if(IsPriceSwingLow(x, InpSwingLeft, InpSwingRight, low))
         {
            lastSwingLow = low[x];
            break;
         }
      }
      if(lastSwingLow == 0.0) lastSwingLow = low[r1 - 1];
      bool isReversalConfirmed = (close[idx] < lastSwingLow);

      if(pr1 > pr2 && MACDBuffer[r1] < MACDBuffer[r2] && MACDBuffer[r1] > 0)
      {
         if(isReversalConfirmed && htfState != HTF_STATE_BULL)
         {
            div.hasBearReg = true; div.isConfirmed = true; div.divList += "REG_BEAR ";
            DrawDivergencePair("REG_BEAR",false,false,macdSubWindow,t1,pr2,MACDBuffer[r2],t2,pr1,MACDBuffer[r1],time[idx],high[idx]);
         }
      }
      if(InpHiddenDiv && pr1 < pr2 && MACDBuffer[r1] > MACDBuffer[r2] && MACDBuffer[r1] > 0)
      {
         div.hasBearHidden = true; div.divList += "HID_BEAR ";
         DrawDivergencePair("HID_BEAR",false,true,macdSubWindow,t1,pr2,MACDBuffer[r2],t2,pr1,MACDBuffer[r1],time[idx],high[idx]);
      }
      if(InpExaggeratedDiv && MathAbs(pr1 - pr2) <= ATRBuffer[idx] * 0.15 && MACDBuffer[r1] < MACDBuffer[r2] && MACDBuffer[r1] > 0)
      {
         div.hasBearExaggerated = true; div.divList += "EX_BEAR ";
         DrawDivergencePair("EX_BEAR",false,false,macdSubWindow,t1,pr2,MACDBuffer[r2],t2,pr1,MACDBuffer[r1],time[idx],high[idx]);
      }
      if(InpTripleDiv && r3 != -1)
      {
         if(pr1 > pr2 && pr2 > high[r3] && MACDBuffer[r1] < MACDBuffer[r2] && MACDBuffer[r2] < MACDBuffer[r3] && MACDBuffer[r1] > 0)
         {
            div.hasBearTriple = true; div.divList += "TRIPLE_BEAR ";
         DrawDivergencePair("TRIPLE_BEAR",false,false,macdSubWindow,t1,pr2,MACDBuffer[r2],t2,pr1,MACDBuffer[r1],time[idx],high[idx]);
         DrawDivergencePair("TRIPLE_BEAR_LEG1",false,false,macdSubWindow,time[r3],high[r3],MACDBuffer[r3],t1,pr2,MACDBuffer[r2],time[idx],high[idx],false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SUB-MODULE 7: V9 MULTI-LAYER SCORE ENGINE                       |
//+------------------------------------------------------------------+
void CalculateScores(int idx, const VPEMetrics &vpe, const MomentumMetrics &mom, const TrendMetrics &trend, ENUM_HTF_STATE htfState, const CandleMetrics &candle, const DivergenceMetrics &div, ScoreMetrics &score)
{
   double buyRaw = 0.0, sellRaw = 0.0;
   double maxPotential = 85.0 + (g_useHTF?15.0:0.0) + (InpUseVPE?20.0:0.0) + (InpShowDiv?20.0:0.0);

   bool buyCross  = (MACDBuffer[idx] > SignalBuffer[idx] && MACDBuffer[idx-1] <= SignalBuffer[idx-1]);
   bool sellCross = (MACDBuffer[idx] < SignalBuffer[idx] && MACDBuffer[idx-1] >= SignalBuffer[idx-1]);

   // 1. MACD & SLOPE ANGLES (Đánh giá phân tầng theo góc dốc)
   if(buyCross && MathAbs(mom.macdSlopeAngle) >= InpMinMacdAngle) buyRaw += 20.0;
   if(sellCross && MathAbs(mom.macdSlopeAngle) >= InpMinMacdAngle) sellRaw += 20.0;

   if(MACDBuffer[idx] > 0) buyRaw += 10.0;
   if(MACDBuffer[idx] < 0) sellRaw += 10.0;

   if(mom.macdSlopeAngle > 0) buyRaw += GetMomentumScore(mom.macdSlopeAngle, InpMinMacdAngle);
   if(mom.macdSlopeAngle < 0) sellRaw += GetMomentumScore(-mom.macdSlopeAngle, InpMinMacdAngle);

   if(mom.histoSlopeAngle > 0) buyRaw += GetMomentumScore(mom.histoSlopeAngle, InpMinHistoAngle);
   if(mom.histoSlopeAngle < 0) sellRaw += GetMomentumScore(-mom.histoSlopeAngle, InpMinHistoAngle);

   // 2. TREND & HTF ALIGNMENT
   if(trend.isUpTrend)   buyRaw += 15.0;
   if(trend.isDownTrend) sellRaw += 15.0;

   if(htfState == HTF_STATE_BULL) buyRaw += 15.0;
   if(htfState == HTF_STATE_BEAR) sellRaw += 15.0;

   // 3. CANDLE QUALITY & VPE VALIDATION
   if(candle.isBullishCandle) buyRaw += 10.0;
   if(candle.isBearishCandle) sellRaw += 10.0;

   if(InpUseVPE)
   {
      if(vpe.vpeStatus == "EXPANSION")
      {
         if(mom.histoSlopeAngle > 0) buyRaw += vpe.scoreContrib;
         else if(mom.histoSlopeAngle < 0) sellRaw += vpe.scoreContrib;
      }
      else if(vpe.vpeStatus == "NO_SUPPLY_DEMAND")
      {
         if(trend.isUpTrend)   buyRaw += vpe.scoreContrib;
         if(trend.isDownTrend) sellRaw += vpe.scoreContrib;
      }
      else if(vpe.vpeStatus == "ABSORPTION" || vpe.vpeStatus == "EXHAUSTION")
      {
         buyRaw  += vpe.scoreContrib;
         sellRaw += vpe.scoreContrib;
      }
   }

   // 4. DIVERGENCE FACTORS
   // Count strongest divergence once; overlapping labels are correlated evidence.
   double bullDiv=0, bearDiv=0;
   if(div.hasBullReg || div.hasBullTriple) bullDiv=20;
   else if(div.hasBullHidden) bullDiv=15;
   else if(div.hasBullExaggerated) bullDiv=10;
   if(div.hasBearReg || div.hasBearTriple) bearDiv=20;
   else if(div.hasBearHidden) bearDiv=15;
   else if(div.hasBearExaggerated) bearDiv=10;
   buyRaw+=bullDiv; sellRaw+=bearDiv;

   // 5. CONTEXT RISK PENALTIES
   if(htfState == HTF_STATE_BEAR) buyRaw -= 20.0;
   if(htfState == HTF_STATE_BULL) sellRaw -= 20.0;

   if(mom.isCompressed) { buyRaw -= 10.0; sellRaw -= 10.0; }

   score.buyScore  = (int)MathMin(100, MathMax(0, MathRound((buyRaw / maxPotential) * 100.0)));
   score.sellScore = (int)MathMin(100, MathMax(0, MathRound((sellRaw / maxPotential) * 100.0)));

   int topScore = MathMax(score.buyScore, score.sellScore);
   if(topScore >= 85)      score.confidenceStr = "EXCELLENT";
   else if(topScore >= 70) score.confidenceStr = "STRONG";
   else if(topScore >= 50) score.confidenceStr = "MODERATE";
   else                    score.confidenceStr = "WEAK";
}

//+------------------------------------------------------------------+
//| SUB-MODULE 8: MASTER BAR SIGNAL PROCESSOR                       |
//+------------------------------------------------------------------+
void ProcessBarSignal(int idx, int total, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const datetime &time[], bool isLiveBar)
{
   double atrVal  = (ATRBuffer[idx] > 0) ? ATRBuffer[idx] : 1.0;
   double prevAtr = (idx > 0 && ATRBuffer[idx-1] > 0) ? ATRBuffer[idx-1] : atrVal;

   VPEMetrics        vpe = CalculateVPE(idx, open, high, low, close, volume);
   MomentumMetrics   mom;
   TrendMetrics      trend;
   CandleMetrics     candle;
   DivergenceMetrics div;
   ScoreMetrics      score;

   CalculateMomentum(idx, atrVal, prevAtr, mom);
   CalculateTrend(idx, atrVal, trend);
   ENUM_HTF_STATE htfState = CalculateHTF(time[idx]);
   CalculateCandleQuality(idx, atrVal, open, close, candle);
   CalculateDivergence(idx, total, high, low, close, time, htfState, div);
   CalculateScores(idx, vpe, mom, trend, htfState, candle, div, score);

   BuyScoreBuffer[idx]  = (double)score.buyScore;
   SellScoreBuffer[idx] = (double)score.sellScore;
   VPEScoreBuffer[idx]  = vpe.scoreContrib;

   {
      if(isLiveBar)
      {
      g_latestVPE   = vpe;
      g_latestMom   = mom;
      g_latestTrend = trend;
      g_htfState    = htfState;
      g_latestDiv   = div;
      g_latestScore = score;
      }

      datetime barTime = time[idx];
      bool buyCross  = (MACDBuffer[idx] > SignalBuffer[idx] && MACDBuffer[idx-1] <= SignalBuffer[idx-1]);
      bool sellCross = (MACDBuffer[idx] < SignalBuffer[idx] && MACDBuffer[idx-1] >= SignalBuffer[idx-1]);
      bool zeroCross = (MACDBuffer[idx]>0 && MACDBuffer[idx-1]<=0) || (MACDBuffer[idx]<0 && MACDBuffer[idx-1]>=0);

      if(g_signalTime==0 || idx-iBarShiftAscending(g_signalTime,time,total)>=MathMax(1,InpAlertCooldown))
      {
         if(buyCross && score.buyScore >= InpMinSignalScore && candle.isBullishCandle)
         {
            UpdateOrCreateArrow(PrefixID + "Arr_Buy_" + TimeToString(barTime), barTime, low[idx] - (atrVal * 0.5), 233, clrLimeGreen);
            TriggerConsolidatedAlert(StringFormat("🟢 BUY SCORE: %d | Conf: %s | VPE: %s | Slope: %.1f° | Div: %s", score.buyScore, score.confidenceStr, vpe.vpeStatus, mom.macdSlopeAngle, div.divList));
            g_signalTime=barTime;
         }
         else if(sellCross && score.sellScore >= InpMinSignalScore && candle.isBearishCandle)
         {
            UpdateOrCreateArrow(PrefixID + "Arr_Sell_" + TimeToString(barTime), barTime, high[idx] + (atrVal * 0.5), 234, clrRed);
            TriggerConsolidatedAlert(StringFormat("🔴 SELL SCORE: %d | Conf: %s | VPE: %s | Slope: %.1f° | Div: %s", score.sellScore, score.confidenceStr, vpe.vpeStatus, mom.macdSlopeAngle, div.divList));
            g_signalTime=barTime;
         }
      }
      if(g_emitAlerts && (g_alertTime==0 || idx-iBarShiftAscending(g_alertTime,time,total)>=MathMax(1,InpAlertCooldown)) && g_signalTime!=barTime)
      {
         if(g_emitAlerts && InpAlertZeroCross && zeroCross)
         {
            TriggerConsolidatedAlert(StringFormat("⚡ MACD ZERO CROSS | Value: %.4f | Direction: %s", MACDBuffer[idx], (MACDBuffer[idx]>0?"UP":"DOWN")));
            g_alertTime=barTime;
         }
         else if(g_emitAlerts && InpAlertExplosion && mom.isExplosion && MathAbs(HistogramBuffer[idx-1]/prevAtr-HistogramBuffer[idx-2]/(ATRBuffer[idx-2]>0?ATRBuffer[idx-2]:prevAtr))<InpExplosionThresh)
         {
            TriggerConsolidatedAlert(StringFormat("💥 MOMENTUM EXPLOSION | NormDelta: %.4f | VPE: %s", mom.normHistoDelta, vpe.vpeStatus));
            g_alertTime=barTime;
         }
         else if(g_emitAlerts && InpAlertEarlyTurn && (mom.earlyTurnUp || mom.earlyTurnDown))
         {
            TriggerConsolidatedAlert(StringFormat("🔄 EARLY TURN | Dir: %s", mom.earlyTurnUp ? "BULLISH" : "BEARISH"));
            g_alertTime=barTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SWING DETECTORS                                                  |
//+------------------------------------------------------------------+
bool IsSwingLow(int idx, int left, int right)
{
   if(idx-left<0 || idx+right>=ArraySize(MACDBuffer)) return false;
   for(int i = 1; i <= left; i++)  if(MACDBuffer[idx] >= MACDBuffer[idx - i]) return false;
   for(int i = 1; i <= right; i++) if(MACDBuffer[idx] > MACDBuffer[idx + i])  return false;
   return true;
}

bool IsSwingHigh(int idx, int left, int right)
{
   if(idx-left<0 || idx+right>=ArraySize(MACDBuffer)) return false;
   for(int i = 1; i <= left; i++)  if(MACDBuffer[idx] <= MACDBuffer[idx - i]) return false;
   for(int i = 1; i <= right; i++) if(MACDBuffer[idx] < MACDBuffer[idx + i])  return false;
   return true;
}

bool IsPriceSwingLow(int idx, int left, int right, const double &low[])
{
   if(idx-left<0 || idx+right>=ArraySize(low)) return false;
   for(int i = 1; i <= left; i++)  if(low[idx] >= low[idx - i]) return false;
   for(int i = 1; i <= right; i++) if(low[idx] > low[idx + i])  return false;
   return true;
}

bool IsPriceSwingHigh(int idx, int left, int right, const double &high[])
{
   if(idx-left<0 || idx+right>=ArraySize(high)) return false;
   for(int i = 1; i <= left; i++)  if(high[idx] <= high[idx - i]) return false;
   for(int i = 1; i <= right; i++) if(high[idx] < high[idx + i])  return false;
   return true;
}

//+------------------------------------------------------------------+
//| VISUAL DRAWING & DASHBOARD                                       |
//+------------------------------------------------------------------+
void UpdateOrCreateTrendLine(string name, int subWindow, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TREND, subWindow, t1, p1, t2, p2);
   else { ObjectMove(0, name, 0, t1, p1); ObjectMove(0, name, 1, t2, p2); }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdateOrCreateTextLabel(string name, int subWindow, datetime t, double p, string text, color clr, bool belowBar)
{
   if(ObjectFind(0,name)>=0) return;
   ObjectCreate(0,name,OBJ_TEXT,subWindow,t,p);

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, belowBar ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdateOrCreateArrow(string name, datetime time, double price, ushort arrowCode, color clr)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   else ObjectMove(0, name, 0, time, price);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdateDashboard()
{
   string status = "NEUTRAL";
   color statusColor = clrGray;

   if(g_latestScore.buyScore >= 75)       { status = "VERY STRONG BUY"; statusColor = clrLime; }
   else if(g_latestScore.buyScore >= 60)  { status = "STRONG BUY";      statusColor = clrLimeGreen; }
   else if(g_latestScore.sellScore >= 75) { status = "VERY STRONG SELL";statusColor = clrRed; }
   else if(g_latestScore.sellScore >= 60) { status = "STRONG SELL";     statusColor = clrLightCoral; }

   string htfStr   = (g_htfState == HTF_STATE_BULL) ? "BULL" : ((g_htfState == HTF_STATE_BEAR) ? "BEAR" : "NEUTRAL");
   if(!g_useHTF) htfStr="OFF";
   string momState = g_latestMom.isExplosion ? "EXPLOSIVE" : (g_latestMom.isCompressed ? "COMPRESSED" : "NORMAL");

   string content = StringFormat(" [MACD PRO v9.2] | Status: %s | Strength: %s | Buy Score: %d | Sell Score: %d\n Trend: %s | VPE Status: %s (Eff:%.2f) | Momentum: %s (Angle:%.1f°)\n HTF: %s | Div: %s | ATR: %.2f",
                                 status, g_latestScore.confidenceStr, g_latestScore.buyScore, g_latestScore.sellScore,
                                 g_latestTrend.trendStr, g_latestVPE.vpeStatus, g_latestVPE.efficiency,
                                 momState, g_latestMom.macdSlopeAngle,
                                 htfStr, (g_latestDiv.divList == "" ? "NONE" : g_latestDiv.divList), ATRBuffer[ArraySize(ATRBuffer)-2]);

   string objName = PrefixID + "Dashboard_Label";
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }

   ObjectSetString(0, objName, OBJPROP_TEXT, content);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, statusColor);
}

void TriggerConsolidatedAlert(string alertMsg)
{
   if(!g_emitAlerts) return;
   if(InpAlertPopup) Alert(alertMsg);
   if(InpAlertPush)  SendNotification(alertMsg);
}
// Binary search for the timestamp of the last emitted signal.
int iBarShiftAscending(datetime t,const datetime &times[],int total)
{
   int lo=0,hi=total-1;
   while(lo<=hi) { int mid=(lo+hi)/2; if(times[mid]==t) return mid;
      if(times[mid]<t) lo=mid+1; else hi=mid-1; }
   return -1000000;
}

// Draw only once per type and pivot pair. Labels mark the detection/confirmation
// bar; geometric lines join older pivots and are available only at confirmation.
void DrawDivergencePair(string kind,bool bullish,bool hidden,int window,
                       datetime ta,double pa,double ma,datetime tb,double pb,double mb,
                       datetime confirmed,double labelPrice,bool label=true)
{
   string key=PrefixID+"DIV_"+kind+"_"+IntegerToString((long)ta)+"_"+IntegerToString((long)tb);
   color c=bullish?InpBullDivColor:InpBearDivColor;
   ENUM_LINE_STYLE style=hidden?STYLE_DASH:STYLE_SOLID;
   if(InpDivOnPrice && ObjectFind(0,key+"_P")<0)
   {
      UpdateOrCreateTrendLine(key+"_P",0,ta,pa,tb,pb,c,style,1);
      ObjectSetString(0,key+"_P",OBJPROP_TOOLTIP,kind+" | Confirmed: "+TimeToString(confirmed));
   }
   if(InpDivOnMACD && ObjectFind(0,key+"_M")<0)
   {
      UpdateOrCreateTrendLine(key+"_M",window,ta,ma,tb,mb,c,style,1);
      ObjectSetString(0,key+"_M",OBJPROP_TOOLTIP,kind+" | Confirmed: "+TimeToString(confirmed));
   }
   if(!label) return;
   double y=labelPrice;
   if(InpDivOnPrice) UpdateOrCreateTextLabel(key+"_TP",0,confirmed,y,kind,c,bullish);
   if(InpDivOnMACD) UpdateOrCreateTextLabel(key+"_TM",window,confirmed,mb,kind,c,bullish);
}
