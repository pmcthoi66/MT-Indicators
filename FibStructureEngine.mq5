//+------------------------------------------------------------------+
//|                                        FibStructureEngine.mq5    |
//------------------------------------------------------------------+
#property description "Fibo Structure Engine v2 — confirmed swings, BOS/CHoCH and Fibonacci levels"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot buffers for Buy/Sell signals
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//+------------------------------------------------------------------+
//| INPUT GROUPS                                                     |
//+------------------------------------------------------------------+

// ── Main Settings ──
input group              "⚙️ Main Settings"
input int                SwingLength       = 10;    // Swing Detection Length (3–50)
input bool               UseATRFilter      = true;  // ATR Swing Filter
input double             ATRMultiplier     = 0.5;   // ATR Filter Multiplier (0.1–3.0)
input int                SignalCooldown    = 5;     // Signal Cooldown (bars)
input int                MaxDisplayBars    = 3000;  // Draw signals/labels only in recent bars; 0 = all history

// ── Fibonacci Levels ──
input group              "📐 Fibonacci Levels"
input bool               ShowFib           = true;  // Show Fibonacci Levels
input int                FibExtendBars     = 20;    // Fib Extension Bars
input bool               ShowFib236        = false; // Show 0.236
input bool               ShowFib382        = true;  // Show 0.382
input bool               ShowFib500        = true;  // Show 0.500
input bool               ShowFib618        = true;  // Show 0.618
input bool               ShowFib786        = true;  // Show 0.786
input bool               ShowFibTarget     = true;  // Show Target (-0.618)
input bool               ShowFibTgt50      = true;  // Show -0.5
input double             ConfluenceTol     = 0.3;   // Confluence ATR Tolerance (0.05–1.0)

// ── Structure ──
input group              "🏗️ Structure"
input bool               ShowBOSCHoCH      = true;  // Show BOS / CHoCH
input bool               ShowSwingLabels   = true;  // Show Swing Labels (HH/HL/LH/LL)
input bool               ShowEngulfing     = true;  // Show Engulfing Signals

// ── Visual Settings ──
input group              "🎨 Visual Settings"
input bool               ShowSignals       = true;  // Show Buy/Sell Signals
input ENUM_LINE_STYLE    StructLineStyle   = STYLE_DASH; // Structure Line Style
input int                StructLineWidth   = 2;     // Structure Line Width (1–4)

// ── Colors ──
input group              "🎨 Colors"
input color              BullColor         = clrLime;       // Bull Color
input color              BearColor         = clrRed;        // Bear Color
input color              FibColor          = clrDodgerBlue; // Fib Lines Color
input color              ConfluenceColor   = clrGold;       // Confluence Color

//+------------------------------------------------------------------+
//| INDICATOR BUFFERS                                                |
//+------------------------------------------------------------------+
double BuyBuffer[];
double SellBuffer[];

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

// ATR handle
int    g_atrHandle       = INVALID_HANDLE;

// Swing tracking
double g_swHigh1         = 0, g_swHigh2 = 0;
int    g_swHigh1Idx      = -1, g_swHigh2Idx = -1;
double g_swLow1          = 0, g_swLow2  = 0;
int    g_swLow1Idx       = -1, g_swLow2Idx  = -1;
int    g_lastSwingType   = 0;    // +1 last accepted pivot high, -1 pivot low

// Structure
int    g_structureBias   = 0;   // +1 bullish, -1 bearish
double g_lastBrokenHigh  = 0;
double g_lastBrokenLow   = 0;
int    g_lastChochDir    = 0;

// Fibonacci anchors
double g_fibSwingHigh    = 0, g_fibSwingLow = 0;
int    g_fibSwingHighIdx = -1, g_fibSwingLowIdx = -1;
int    g_fibDirection    = 0;   // +1 bullish, -1 bearish
bool   g_fibHighIsLive   = false, g_fibLowIsLive = false;

// Cooldown
int    g_barsSinceBuy    = 999;
int    g_barsSinceSell   = 999;

// New-bar guard. A closed candle is processed once, even though OnCalculate
// is called on every incoming tick.
datetime g_lastProcessedClosedTime = 0;
int      g_barsSinceObjectPrune = 0;

// Warmup
int    g_warmupBars      = 50;

// Object name prefix
string g_prefix          = "FSE_";
long   g_chartID         = 0;

//+------------------------------------------------------------------+
//| HELPER: Unique object name                                       |
//+------------------------------------------------------------------+
string ObjName(string tag, int idx = 0)
{
   return g_prefix + tag + "_" + IntegerToString(idx);
}

string ObjNameAt(string tag, datetime stamp)
{
   return g_prefix + tag + "_" + IntegerToString((long)stamp);
}

void ResetEngineState()
{
   g_swHigh1 = g_swHigh2 = g_swLow1 = g_swLow2 = 0;
   g_swHigh1Idx = g_swHigh2Idx = g_swLow1Idx = g_swLow2Idx = -1;
   g_lastSwingType = 0;
   g_structureBias = 0;
   g_lastBrokenHigh = 0;
   g_lastBrokenLow = 0;
   g_lastChochDir = 0;
   g_fibSwingHigh = g_fibSwingLow = 0;
   g_fibSwingHighIdx = g_fibSwingLowIdx = -1;
   g_fibDirection = 0;
   g_fibHighIsLive = g_fibLowIsLive = false;
   g_barsSinceBuy = g_barsSinceSell = 999;
   g_lastProcessedClosedTime = 0;
   g_barsSinceObjectPrune = 0;
}

// In a series array, every stored historical shift moves one slot older
// when a newly closed bar is incorporated.
void ShiftStoredIndices()
{
   if(g_swHigh1Idx >= 0)      g_swHigh1Idx++;
   if(g_swHigh2Idx >= 0)      g_swHigh2Idx++;
   if(g_swLow1Idx >= 0)       g_swLow1Idx++;
   if(g_swLow2Idx >= 0)       g_swLow2Idx++;
   if(g_fibSwingHighIdx >= 0) g_fibSwingHighIdx++;
   if(g_fibSwingLowIdx >= 0)  g_fibSwingLowIdx++;
}

//+------------------------------------------------------------------+
//| HELPER: Create / update a trend line                             |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2,
                   color clr, ENUM_LINE_STYLE style, int width, string tooltip = "")
{
   if(ObjectFind(g_chartID, name) < 0)
      ObjectCreate(g_chartID, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(g_chartID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(g_chartID, name, OBJPROP_STYLE, style);
   ObjectSetInteger(g_chartID, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(g_chartID, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (g_chartID, name, OBJPROP_TOOLTIP, tooltip);
   ObjectSetInteger(g_chartID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chartID, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| HELPER: Horizontal ray line (for Fib levels)                    |
//+------------------------------------------------------------------+
void DrawHorizLine(string name, datetime tFrom, double price,
                   color clr, ENUM_LINE_STYLE style, int width, string tooltip = "",
                   datetime tTo = 0)
{
   // tTo = 0 ho to default: current candle se 5 bars aage
   if(tTo == 0) tTo = TimeCurrent() + (datetime)5 * PeriodSeconds();
   if(ObjectFind(g_chartID, name) < 0)
      ObjectCreate(g_chartID, name, OBJ_TREND, 0, tFrom, price, tTo, price);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,  0, tFrom);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,  1, tTo);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(g_chartID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(g_chartID, name, OBJPROP_STYLE, style);
   ObjectSetInteger(g_chartID, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(g_chartID, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString (g_chartID, name, OBJPROP_TOOLTIP, tooltip);
   ObjectSetInteger(g_chartID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chartID, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| HELPER: Text label — price chart par OBJ_TEXT                   |
//+------------------------------------------------------------------+
void DrawLabel(string name, datetime t, double price, string txt,
               color clr, bool above, string tooltip = "")
{
   // Price offset taake label line se thoda door rahe
   double range = g_fibSwingHigh - g_fibSwingLow;
   double offset = range * 0.003;  // 0.3% range ka offset
   double labelPrice = above ? price + offset : price - offset;

   ENUM_ANCHOR_POINT anchor = above ? ANCHOR_LOWER : ANCHOR_UPPER;
   if(ObjectFind(g_chartID, name) < 0)
      ObjectCreate(g_chartID, name, OBJ_TEXT, 0, t, labelPrice);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,      t);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE,     labelPrice);
   ObjectSetString (g_chartID, name, OBJPROP_TEXT,      txt);
   ObjectSetInteger(g_chartID, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(g_chartID, name, OBJPROP_FONTSIZE,  8);
   ObjectSetInteger(g_chartID, name, OBJPROP_ANCHOR,    anchor);
   ObjectSetString (g_chartID, name, OBJPROP_TOOLTIP,   tooltip);
   ObjectSetInteger(g_chartID, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(g_chartID, name, OBJPROP_HIDDEN,    true);
}

//+------------------------------------------------------------------+
//| HELPER: Rectangle box                                           |
//+------------------------------------------------------------------+
void DrawBox(string name, datetime t1, double top, datetime t2, double bot,
             color borderClr)
{
   if(ObjectFind(g_chartID, name) < 0)
      ObjectCreate(g_chartID, name, OBJ_RECTANGLE, 0, t1, top, t2, bot);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,       0, t1);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE,      0, top);
   ObjectSetInteger(g_chartID, name, OBJPROP_TIME,       1, t2);
   ObjectSetDouble (g_chartID, name, OBJPROP_PRICE,      1, bot);
   ObjectSetInteger(g_chartID, name, OBJPROP_COLOR,      borderClr);
   ObjectSetInteger(g_chartID, name, OBJPROP_FILL,       false);
   ObjectSetInteger(g_chartID, name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(g_chartID, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(g_chartID, name, OBJPROP_BACK,       true);
   ObjectSetInteger(g_chartID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chartID, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
//| HELPER: Delete all objects with prefix                          |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   for(int i = ObjectsTotal(g_chartID) - 1; i >= 0; i--)
   {
      string name = ObjectName(g_chartID, i);
      if(StringFind(name, g_prefix) == 0)
         ObjectDelete(g_chartID, name);
   }
}

void PruneOldDisplayObjects(datetime cutoff)
{
   if(cutoff <= 0) return;
   for(int i = ObjectsTotal(g_chartID) - 1; i >= 0; i--)
   {
      string name = ObjectName(g_chartID, i);
      if(StringFind(name, g_prefix) != 0 || StringFind(name, g_prefix + "FIB") == 0)
         continue;

      // Timestamp-based display object names let us prune without making
      // synchronous ObjectGetInteger calls for every chart object.
      int sep = -1;
      for(int j = StringLen(name) - 1; j >= 0; j--)
      {
         if(StringGetCharacter(name, j) == '_') { sep = j; break; }
      }
      if(sep < 0) continue;
      datetime stamp = (datetime)StringToInteger(StringSubstr(name, sep + 1));
      if(stamp > 0 && stamp < cutoff)
         ObjectDelete(g_chartID, name);
   }
}

//+------------------------------------------------------------------+
//| HELPER: Delete objects containing a tag                         |
//+------------------------------------------------------------------+
void DeleteTagObjects(string tag)
{
   for(int i = ObjectsTotal(g_chartID) - 1; i >= 0; i--)
   {
      string name = ObjectName(g_chartID, i);
      if(StringFind(name, g_prefix + tag) == 0)
         ObjectDelete(g_chartID, name);
   }
}

//+------------------------------------------------------------------+
//| HELPER: Fibonacci level calculation (Bullish — High se neeche)  |
//+------------------------------------------------------------------+
double FibLevel(double swH, double swL, double ratio)
{
   return swH - (swH - swL) * ratio;
}

//+------------------------------------------------------------------+
//| HELPER: Fibonacci level calculation (Bearish — Low se upar)     |
//+------------------------------------------------------------------+
double FibLevelBear(double swH, double swL, double ratio)
{
   return swL + (swH - swL) * ratio;
}

//+------------------------------------------------------------------+
//| HELPER: Pivot High detection                                    |
//+------------------------------------------------------------------+
bool IsPivotHigh(const double &high[], int shift, int len)
{
   if(shift < len || shift + len >= ArraySize(high)) return false;
   double val = high[shift];
   for(int i = 1; i <= len; i++)
      if(high[shift - i] >= val || high[shift + i] >= val) return false;
   return true;
}

//+------------------------------------------------------------------+
//| HELPER: Pivot Low detection                                     |
//+------------------------------------------------------------------+
bool IsPivotLow(const double &low[], int shift, int len)
{
   if(shift < len || shift + len >= ArraySize(low)) return false;
   double val = low[shift];
   for(int i = 1; i <= len; i++)
      if(low[shift - i] <= val || low[shift + i] <= val) return false;
   return true;
}



//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(SwingLength < 3 || SwingLength > 50 ||
      ATRMultiplier < 0.0 || ATRMultiplier > 3.0 ||
      SignalCooldown < 0 || MaxDisplayBars < 0 || FibExtendBars < 1 ||
      ConfluenceTol < 0.0 || ConfluenceTol > 1.0 ||
      StructLineWidth < 1 || StructLineWidth > 4)
      return INIT_PARAMETERS_INCORRECT;

   g_chartID    = ChartID();
   g_warmupBars = MathMax(SwingLength * 3, 50);

   // ATR handle (period 14)
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create ATR handle");
      return INIT_FAILED;
   }

   // Setup buffers
   SetIndexBuffer(0, BuyBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   // Arrow codes: 233=up arrow, 234=down arrow
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);

   ArraySetAsSeries(BuyBuffer,  true);
   ArraySetAsSeries(SellBuffer, true);

   ResetEngineState();

   DeleteAllObjects();
   ChartRedraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllObjects();
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OnCalculate — main loop                                          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   if(rates_total < g_warmupBars + SwingLength * 2 + 5)
      return 0;

   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time,  true);

   // Rebuild on first call/history reset. Otherwise wait until a new closed
   // candle exists; this prevents repeated signals and tick-based cooldowns.
   bool fullRebuild = (prev_calculated == 0 || g_lastProcessedClosedTime == 0 ||
                       prev_calculated > rates_total);
   int startBar = -1;
   if(fullRebuild)
      startBar = rates_total - 1 - SwingLength * 2;
   else
   {
      if(time[1] == g_lastProcessedClosedTime)
         return rates_total;

      int oldClosedShift = -1;
      for(int k = 2; k < rates_total; k++)
      {
         if(time[k] == g_lastProcessedClosedTime)
         {
            oldClosedShift = k;
            break;
         }
      }
      if(oldClosedShift < 0)
      {
         fullRebuild = true;
         startBar = rates_total - 1 - SwingLength * 2;
      }
      else
         startBar = oldClosedShift - 1;
   }
   if(startBar < 1) startBar = 0;

   // Only copy the ATR span needed for the bars being processed and their
   // delayed pivot confirmations.
   int copyCount = fullRebuild ? rates_total :
                   (int)MathMin(rates_total, startBar + SwingLength * 2 + 1);
   double atrArr[];
   ArraySetAsSeries(atrArr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, copyCount, atrArr) < copyCount)
      return (prev_calculated > 0 ? prev_calculated : 0);

   if(fullRebuild)
   {
      ResetEngineState();
      DeleteAllObjects();
      ArrayInitialize(BuyBuffer, 0.0);
      ArrayInitialize(SellBuffer, 0.0);
   }

   //--- Loop from oldest to newest (series arrays: index 0 = newest)
   for(int i = startBar; i >= 1; i--)
   {
      if(i >= rates_total) continue;

      double atr = atrArr[i];
      if(atr <= 0)
      {
         if(fullRebuild) continue; // ATR warm-up on the oldest history
         return (prev_calculated > 0 ? prev_calculated : 0);
      }

      if(!fullRebuild)
         ShiftStoredIndices();

      bool isWarmedUp = (rates_total - 1 - i) >= g_warmupBars;
      bool withinDisplayHistory = (MaxDisplayBars == 0 || i <= MaxDisplayBars);

      // ── Pivot Detection ──
      bool newSwingHigh = false, newSwingLow = false;
      int confirmedPivotShift = i + SwingLength;
      double pivotATR = (confirmedPivotShift < copyCount && atrArr[confirmedPivotShift] > 0)
                        ? atrArr[confirmedPivotShift] : atr;
      double atrMinSize = UseATRFilter ? pivotATR * ATRMultiplier : 0.0;

      // A swing at pivotShift is admitted only after SwingLength newer bars
      // have closed. This avoids using a future-confirmed pivot too early.
      if(confirmedPivotShift < rates_total && IsPivotHigh(high, confirmedPivotShift, SwingLength))
      {
         bool pass = (g_swLow1 == 0) || (high[confirmedPivotShift] - g_swLow1 >= atrMinSize);
         if(pass)
         {
            if(g_lastSwingType == 1)
            {
               // Consecutive same-side pivots refine the active extreme;
               // a weaker high cannot replace the confirmed structure high.
               if(high[confirmedPivotShift] > g_swHigh1)
               {
                  if(g_swHigh1Idx >= 0)
                     ObjectDelete(g_chartID, ObjNameAt("SWH", time[g_swHigh1Idx]));
                  g_swHigh1 = high[confirmedPivotShift];
                  g_swHigh1Idx = confirmedPivotShift;
                  newSwingHigh = true;
               }
            }
            else
            {
               g_swHigh2 = g_swHigh1;
               g_swHigh2Idx = g_swHigh1Idx;
               g_swHigh1 = high[confirmedPivotShift];
               g_swHigh1Idx = confirmedPivotShift;
               g_lastSwingType = 1;
               newSwingHigh = true;
            }
         }
      }

      if(confirmedPivotShift < rates_total && IsPivotLow(low, confirmedPivotShift, SwingLength))
      {
         bool pass = (g_swHigh1 == 0) || (g_swHigh1 - low[confirmedPivotShift] >= atrMinSize);
         if(pass)
         {
            if(g_lastSwingType == -1)
            {
               // Consecutive same-side pivots refine the active extreme.
               if(low[confirmedPivotShift] < g_swLow1)
               {
                  if(g_swLow1Idx >= 0)
                     ObjectDelete(g_chartID, ObjNameAt("SWL", time[g_swLow1Idx]));
                  g_swLow1 = low[confirmedPivotShift];
                  g_swLow1Idx = confirmedPivotShift;
                  newSwingLow = true;
               }
            }
            else
            {
               g_swLow2 = g_swLow1;
               g_swLow2Idx = g_swLow1Idx;
               g_swLow1 = low[confirmedPivotShift];
               g_swLow1Idx = confirmedPivotShift;
               g_lastSwingType = -1;
               newSwingLow = true;
            }
         }
      }

      // ── Swing Labels ──
      if(isWarmedUp && withinDisplayHistory && ShowSwingLabels && newSwingHigh && g_swHigh2 > 0)
      {
         string lbl  = (g_swHigh1 > g_swHigh2) ? "HH" : "LH";
         color  clr  = (g_swHigh1 > g_swHigh2) ? BullColor : BearColor;
         string name = ObjNameAt("SWH", time[g_swHigh1Idx]);
         DrawLabel(name, time[g_swHigh1Idx], g_swHigh1, lbl, clr, true, lbl);
      }

      if(isWarmedUp && withinDisplayHistory && ShowSwingLabels && newSwingLow && g_swLow2 > 0)
      {
         string lbl  = (g_swLow1 > g_swLow2) ? "HL" : "LL";
         color  clr  = (g_swLow1 > g_swLow2) ? BullColor : BearColor;
         string name = ObjNameAt("SWL", time[g_swLow1Idx]);
         DrawLabel(name, time[g_swLow1Idx], g_swLow1, lbl, clr, false, lbl);
      }

      // ── Structure Detection (BOS / CHoCH) ──
      bool isBOS = false, isCHoCH = false;
      bool isBullBreak = false, isBearBreak = false;

      bool bullBreakCond = (g_swHigh1 > 0) && isWarmedUp &&
                           (close[i] > g_swHigh1) &&
                           (g_lastBrokenHigh == 0 || g_swHigh1 != g_lastBrokenHigh);
      bool bearBreakCond = (g_swLow1 > 0) && isWarmedUp &&
                           (close[i] < g_swLow1) &&
                           (g_lastBrokenLow == 0 || g_swLow1 != g_lastBrokenLow);

      // Prioritize CHoCH on same bar
      if(bullBreakCond && bearBreakCond)
      {
         if(g_structureBias <= 0) bearBreakCond = false;
         else                     bullBreakCond = false;
      }

      if(bullBreakCond)
      {
         // The first break establishes direction; only a break against an
         // established bias is a CHoCH.
         if(g_structureBias < 0) { isCHoCH = true; g_lastChochDir = 1; }
         else                      isBOS   = true;
         g_structureBias  = 1;
         isBullBreak      = true;
         g_lastBrokenHigh = g_swHigh1;
      }

      if(bearBreakCond)
      {
         if(g_structureBias > 0) { isCHoCH = true; g_lastChochDir = -1; }
         else                      isBOS   = true;
         g_structureBias = -1;
         isBearBreak     = true;
         g_lastBrokenLow = g_swLow1;
      }

      // ── Draw BOS / CHoCH lines ──
      if(isWarmedUp && withinDisplayHistory && ShowBOSCHoCH && (isBOS || isCHoCH))
      {
         double bkPrice = isBullBreak ? g_swHigh1 : g_swLow1;
         color  bkClr   = isBullBreak ? BullColor : BearColor;
         string bkTxt   = isCHoCH ? "CHoCH" : "BOS";
         int    startI  = isBullBreak ? g_swHigh1Idx : g_swLow1Idx;
         if(startI < 0) startI = i + 10;

         string lineName = ObjNameAt(bkTxt, time[i]);
         string lblName  = ObjNameAt(bkTxt + "L", time[i]);

         DrawTrendLine(lineName, time[startI], bkPrice, time[i], bkPrice,
                       bkClr, StructLineStyle, StructLineWidth,
                       bkTxt + " @ " + DoubleToString(bkPrice, _Digits));

         int midI = (startI + i) / 2;
         if(midI >= 0 && midI < rates_total)
            DrawLabel(lblName, time[midI], bkPrice, bkTxt, bkClr,
                      isBullBreak, bkTxt + " @ " + DoubleToString(bkPrice, _Digits));
      }

      // ── Fibonacci Anchor Updates ──
      if(isCHoCH && isBullBreak)
      {
         g_fibDirection    = 1;
         g_fibSwingHigh    = high[i];   g_fibSwingHighIdx = i;
         g_fibSwingLow     = g_swLow1;  g_fibSwingLowIdx  = (g_swLow1Idx >= 0) ? g_swLow1Idx : i + 10;
         g_fibHighIsLive   = true;      g_fibLowIsLive    = false;
         if(!fullRebuild) RedrawFibLevels(time, rates_total);
      }
      if(isCHoCH && isBearBreak)
      {
         g_fibDirection    = -1;
         g_fibSwingLow     = low[i];    g_fibSwingLowIdx  = i;
         g_fibSwingHigh    = g_swHigh1; g_fibSwingHighIdx = (g_swHigh1Idx >= 0) ? g_swHigh1Idx : i + 10;
         g_fibLowIsLive    = true;      g_fibHighIsLive   = false;
         if(!fullRebuild) RedrawFibLevels(time, rates_total);
      }
      if(isBOS && isBullBreak)
      {
         g_fibSwingHigh    = high[i];   g_fibSwingHighIdx = i;
         g_fibSwingLow     = g_swLow1;  g_fibSwingLowIdx  = (g_swLow1Idx >= 0) ? g_swLow1Idx : i + 10;
         g_fibHighIsLive   = true;      g_fibLowIsLive    = false;
         if(!fullRebuild) RedrawFibLevels(time, rates_total);
      }
      if(isBOS && isBearBreak)
      {
         g_fibSwingLow     = low[i];    g_fibSwingLowIdx  = i;
         g_fibSwingHigh    = g_swHigh1; g_fibSwingHighIdx = (g_swHigh1Idx >= 0) ? g_swHigh1Idx : i + 10;
         g_fibLowIsLive    = true;      g_fibHighIsLive   = false;
         if(!fullRebuild) RedrawFibLevels(time, rates_total);
      }

      // Trail live edge
      if(!isBullBreak && !isBearBreak)
      {
         if(g_fibHighIsLive && g_fibSwingHigh > 0 && high[i] > g_fibSwingHigh)
         {
            g_fibSwingHigh    = high[i];
            g_fibSwingHighIdx = i;
            if(!fullRebuild) RedrawFibLevels(time, rates_total);
         }
         if(g_fibLowIsLive && g_fibSwingLow > 0 && low[i] < g_fibSwingLow)
         {
            g_fibSwingLow    = low[i];
            g_fibSwingLowIdx = i;
            if(!fullRebuild) RedrawFibLevels(time, rates_total);
         }
      }

      // ── Compute current Fib levels for signals ──
      double fib382 = 0, fib500 = 0, fib618 = 0, fib786 = 0;
      bool fibRangeValid = (g_fibSwingHigh > 0 && g_fibSwingLow > 0 &&
                            g_fibSwingHigh > g_fibSwingLow);

      if(fibRangeValid)
      {
         if(g_fibDirection == 1)
         {
            fib382     = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.382);
            fib500     = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.500);
            fib618     = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.618);
            fib786     = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.786);
         }
         else if(g_fibDirection == -1)
         {
            // FIX: FibLevelBear helper use — consistent approach
            fib382     = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.382);
            fib500     = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.500);
            fib618     = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.618);
            fib786     = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.786);
         }
      }

      // ── Premium / Discount ──
      bool inPremium = false, inDiscount = false;
      if(fibRangeValid && fib500 > 0)
      {
         // Premium/discount are price locations within the same low-to-high
         // range for either trend direction; they do not swap on a downtrend.
         inPremium  = close[i] > fib500;
         inDiscount = close[i] <= fib500;
      }

      // ── Confluence Score ──
      double confTol = atr * ConfluenceTol;
      double confW   = 0;
      if(fibRangeValid)
      {
         if(MathAbs(close[i] - fib382) <= confTol) confW += 1.5;
         if(MathAbs(close[i] - fib500) <= confTol) confW += 2.0;
         if(MathAbs(close[i] - fib618) <= confTol) confW += 2.5;
         if(MathAbs(close[i] - fib786) <= confTol) confW += 1.5;
         if(g_swHigh1 > 0 && MathAbs(close[i] - g_swHigh1) <= confTol) confW += 1.0;
         if(g_swLow1  > 0 && MathAbs(close[i] - g_swLow1)  <= confTol) confW += 1.0;
      }
      int confScore = (int)MathMin(confW * 10.0, 100.0);

      // ── Engulfing Pattern ──
      double body     = MathAbs(close[i] - open[i]);
      double bodyAvg  = atr * 0.7; // approximation
      bool isLongBody = body > bodyAvg;
      bool prevSmall  = MathAbs(close[i+1] - open[i+1]) < bodyAvg;

      bool bearEngulf = (close[i] < open[i]) && isLongBody &&
                        (close[i+1] > open[i+1]) && prevSmall &&
                        (close[i] <= open[i+1]) && (open[i] >= close[i+1]);

      bool bullEngulf = (close[i] > open[i]) && isLongBody &&
                        (close[i+1] < open[i+1]) && prevSmall &&
                        (close[i] >= open[i+1]) && (open[i] <= close[i+1]);

      bool bearEngulfCtx = bearEngulf && isWarmedUp && (inPremium || confW >= 1.5);
      bool bullEngulfCtx = bullEngulf && isWarmedUp && (inDiscount || confW >= 1.5);

      // Engulfing visuals
      if(isWarmedUp && withinDisplayHistory && ShowEngulfing && bearEngulfCtx)
         DrawLabel(ObjNameAt("BENG", time[i]), time[i], high[i], "▼", BearColor, true, "Bearish Engulfing");
      if(isWarmedUp && withinDisplayHistory && ShowEngulfing && bullEngulfCtx)
         DrawLabel(ObjNameAt("UENG", time[i]), time[i], low[i],  "▲", BullColor, false, "Bullish Engulfing");

      // ── Signal Logic with Cooldown ──
      // Cooldown increment har bar pe
      g_barsSinceBuy++;
      g_barsSinceSell++;

      bool buyRaw  = (bullEngulfCtx && g_structureBias == 1 && confW >= 1.5) || (isCHoCH && isBullBreak);
      bool sellRaw = (bearEngulfCtx && g_structureBias == -1 && confW >= 1.5) || (isCHoCH && isBearBreak);

      // FIX: Same bar pe buy aur sell dono prevent karo — buy ko priority
      if(buyRaw && sellRaw) sellRaw = false;

      bool confirmedBuy  = buyRaw  && g_barsSinceBuy  >= SignalCooldown;
      bool confirmedSell = sellRaw && g_barsSinceSell >= SignalCooldown;

      if(confirmedBuy)  g_barsSinceBuy  = 0;
      if(confirmedSell) g_barsSinceSell = 0;

      // Buffer output
      BuyBuffer[i]  = confirmedBuy  && ShowSignals && withinDisplayHistory ? low[i]  - atr * 0.3 : 0.0;
      SellBuffer[i] = confirmedSell && ShowSignals && withinDisplayHistory ? high[i] + atr * 0.3 : 0.0;

      // ── Alerts (only on live bar) ──
      if(i == 1 && isWarmedUp)
      {
         if(confirmedBuy)
         {
            double sl = close[i] - atr * 1.5;
            double tp = close[i] + atr * 2.5;
            string msg = "🟢 BUY | " + _Symbol +
                         " | Price: " + DoubleToString(close[i], _Digits) +
                         " | Conf: " + IntegerToString(confScore) +
                         " | SL: " + DoubleToString(sl, _Digits) +
                         " | TP: " + DoubleToString(tp, _Digits);
            Alert(msg);
         }
         if(confirmedSell)
         {
            double sl = close[i] + atr * 1.5;
            double tp = close[i] - atr * 2.5;
            string msg = "🔴 SELL | " + _Symbol +
                         " | Price: " + DoubleToString(close[i], _Digits) +
                         " | Conf: " + IntegerToString(confScore) +
                         " | SL: " + DoubleToString(sl, _Digits) +
                         " | TP: " + DoubleToString(tp, _Digits);
            Alert(msg);
         }
         if(isBOS)
         {
            string dir = isBullBreak ? "Bullish" : "Bearish";
            Alert("🔵 BOS | " + _Symbol + " | " + dir + " | Price: " + DoubleToString(close[i], _Digits));
         }
         if(isCHoCH)
         {
            string dir = isBullBreak ? "Bullish" : "Bearish";
            Alert("🟡 CHoCH | " + _Symbol + " | " + dir + " | Price: " + DoubleToString(close[i], _Digits));
         }
      }

      // ── Dashboard removed ──
   }

   if(fullRebuild)
      RedrawFibLevels(time, rates_total);

   if(MaxDisplayBars > 0 && rates_total > MaxDisplayBars + 1)
   {
      bool pruneNow = fullRebuild;
      if(!fullRebuild && ++g_barsSinceObjectPrune >= 100)
      {
         pruneNow = true;
         g_barsSinceObjectPrune = 0;
      }
      if(pruneNow)
         PruneOldDisplayObjects(time[MaxDisplayBars]);
      // As the series advances, clear the buffer value that just moved
      // beyond the visible history window.
      BuyBuffer[MaxDisplayBars + 1] = 0.0;
      SellBuffer[MaxDisplayBars + 1] = 0.0;
   }

   g_lastProcessedClosedTime = time[1];

   ChartRedraw();
   return rates_total;
}

//+------------------------------------------------------------------+
//| Redraw all Fibonacci objects                                     |
//+------------------------------------------------------------------+
void RedrawFibLevels(const datetime &time[], int rates_total)
{
   if(!ShowFib) return;
   if(g_fibSwingHigh <= 0 || g_fibSwingLow <= 0 || g_fibSwingHigh <= g_fibSwingLow) return;

   // Delete old fib objects
   DeleteTagObjects("FIB");

   int    startIdx  = (g_fibSwingLowIdx >= 0 && g_fibSwingLowIdx < rates_total)  ? g_fibSwingLowIdx  : 0;
   int    highIdx   = (g_fibSwingHighIdx >= 0 && g_fibSwingHighIdx < rates_total) ? g_fibSwingHighIdx : 0;

   // Swing anchors — actual chart time use karo (TimeCurrent se nahi)
   datetime tSwingHigh = time[highIdx];
   datetime tSwingLow  = time[startIdx];

   // Left side: jo swing pehle aaya wo starting point
   datetime t0   = MathMin(tSwingHigh, tSwingLow);
   // Right side: current candle (time[0]) se FibExtendBars aage
   datetime tEnd = time[0] + (datetime)FibExtendBars * PeriodSeconds();

   // Reference line — actual swing high aur low ke beech
   DrawTrendLine(ObjName("FIB_REF"), tSwingLow, g_fibSwingLow, tSwingHigh, g_fibSwingHigh,
                 ColorToARGB(FibColor, 100), STYLE_DOT, 1, "Fib Reference");

   double fib236p = 0, fib382p = 0, fib500p = 0, fib618p = 0, fib786p = 0;
   double fibTgtp = 0, fibT50p = 0;

   if(g_fibDirection == 1)
   {
      fib236p = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.236);
      fib382p = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.382);
      fib500p = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.500);
      fib618p = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.618);
      fib786p = FibLevel(g_fibSwingHigh, g_fibSwingLow, 0.786);
      fibT50p = FibLevel(g_fibSwingHigh, g_fibSwingLow, -0.5);
      fibTgtp = FibLevel(g_fibSwingHigh, g_fibSwingLow, -0.618);
   }
   else
   {
      // FIX: FibLevelBear helper use — consistent approach
      fib236p = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.236);
      fib382p = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.382);
      fib500p = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.500);
      fib618p = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.618);
      fib786p = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, 0.786);
      fibT50p = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, -0.5);
      fibTgtp = FibLevelBear(g_fibSwingHigh, g_fibSwingLow, -0.618);
   }

   // Label position — tEnd se 2 bars aage taake clearly dikhe
   datetime tLbl = tEnd + (datetime)2 * PeriodSeconds();

   // Bullish: levels neeche hain (retracement), label bhi neeche
   // Bearish: levels upar hain (retracement), label bhi upar
   bool fibLblAbove = (g_fibDirection == -1);

   // Draw lines
   if(ShowFib236)
   {
      DrawHorizLine(ObjName("FIB236"), t0, fib236p, FibColor, STYLE_DOT, 1,
                    "Fib 0.236: " + DoubleToString(fib236p, _Digits), tEnd);
      DrawLabel(ObjName("FIB236L"), tLbl, fib236p, "0.236", FibColor, fibLblAbove);
   }
   if(ShowFib382)
   {
      DrawHorizLine(ObjName("FIB382"), t0, fib382p, FibColor, STYLE_DOT, 1,
                    "Fib 0.382: " + DoubleToString(fib382p, _Digits), tEnd);
      DrawLabel(ObjName("FIB382L"), tLbl, fib382p, "0.382", FibColor, fibLblAbove);
   }
   if(ShowFib500)
   {
      DrawHorizLine(ObjName("FIB500"), t0, fib500p, FibColor, STYLE_DASH, 2,
                    "Fib 0.500: " + DoubleToString(fib500p, _Digits), tEnd);
      DrawLabel(ObjName("FIB500L"), tLbl, fib500p, "0.500", FibColor, fibLblAbove);
   }
   if(ShowFib618)
   {
      DrawHorizLine(ObjName("FIB618"), t0, fib618p, FibColor, STYLE_SOLID, 2,
                    "Fib 0.618: " + DoubleToString(fib618p, _Digits), tEnd);
      DrawLabel(ObjName("FIB618L"), tLbl, fib618p, "0.618", FibColor, fibLblAbove);
   }
   if(ShowFib786)
   {
      DrawHorizLine(ObjName("FIB786"), t0, fib786p, FibColor, STYLE_DOT, 1,
                    "Fib 0.786: " + DoubleToString(fib786p, _Digits), tEnd);
      DrawLabel(ObjName("FIB786L"), tLbl, fib786p, "0.786", FibColor, fibLblAbove);
   }

   // Golden Zone box (0.500 – 0.786) — sahi t0 aur tEnd use ho raha hai swing anchors ke saath
   double gzTop = MathMax(fib500p, fib786p);
   double gzBot = MathMin(fib500p, fib786p);
   DrawBox(ObjName("FIB_GZ"), t0, gzTop, tEnd, gzBot, clrGold);

   // Target lines
   color tgtClr = g_fibDirection == 1 ? BullColor : BearColor;
   bool  tgtAbove = (g_fibDirection == 1);
   if(ShowFibTarget)
   {
      string tgtLbl = g_fibDirection == 1 ? "Target ↑" : "Target ↓";
      DrawHorizLine(ObjName("FIB_TGT"), t0, fibTgtp, tgtClr, STYLE_DASH, 2,
                    tgtLbl + " (-0.618): " + DoubleToString(fibTgtp, _Digits), tEnd);
      DrawLabel(ObjName("FIB_TGTL"), tLbl, fibTgtp, tgtLbl, tgtClr, tgtAbove);
   }
   if(ShowFibTgt50)
   {
      string t50Lbl = g_fibDirection == 1 ? "-0.5 ↑" : "-0.5 ↓";
      DrawHorizLine(ObjName("FIB_T50"), t0, fibT50p, tgtClr, STYLE_DOT, 1,
                    t50Lbl + ": " + DoubleToString(fibT50p, _Digits), tEnd);
      DrawLabel(ObjName("FIB_T50L"), tLbl, fibT50p, t50Lbl, tgtClr, tgtAbove);
   }

   // Target zone box
   if(ShowFibTarget || ShowFibTgt50)
   {
      double tzTop = MathMax(fibT50p, fibTgtp);
      double tzBot = MathMin(fibT50p, fibTgtp);
      DrawBox(ObjName("FIB_TZ"), t0, tzTop, tEnd, tzBot, tgtClr);
   }
}
//+------------------------------------------------------------------+
