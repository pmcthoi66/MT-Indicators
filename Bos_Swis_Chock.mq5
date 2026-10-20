//+------------------------------------------------------------------+
//|                                      Combo_Swis_Chock.mq5 | v1.8 |
//|                                                                  |
//| v1.8: closed-bar swings, chronological breaks, symmetric CHOCH |
//| CHOCH: Chronological HH/HL <-> LL/LH State Machine              |
//|                                                                  |
//| BULLISH STRUCTURE                                                |
//|   HH -> HL                                                       |
//|   HL = Protected Low                                             |
//|   Break Protected Low = Bearish CHOCH                            |
//|                                                                  |
//| BEARISH STRUCTURE                                                |
//|   LL -> LH                                                       |
//|   LH = Protected High                                            |
//|   Break Protected High = Bullish CHOCH                           |
//|                                                                  |
//| Visual: horizontal line + text. NO ARROWS.                      |
//| History OFF: newest 3 signals TOTAL; ON: bounded history.       |
//| Disable/remove: delete instance objects and free owned arrays.  |
//| Signals use closed candles. Strength N confirms after N closes. |
//| Lookback is rolling: oldest events/state may leave the window.  |
//| Equal highs/lows are not strict pivots. Outside CHOCH pivots skip.|
//| CHOCH resets to UNKNOWN after each break, as in the source.      |
//| BOS: continuation break in established external structure.     |
//| BOS shares ExternalSwingStrength / CHOCHLookbackBars.           |
//| One event per level; CHOCH takes priority on ambiguous wick bar.|
//+------------------------------------------------------------------+
#property version "1.80"
#property strict
#property indicator_chart_window
#property indicator_plots 0

//==================================================================//
// INPUTS
//==================================================================//

input group "===== DISPLAY / PERFORMANCE ====="
input bool EnableIndicator = true;
input bool ShowHistory = false; // OFF: latest 3 signals TOTAL across enabled types
input int MaxHistorySignals = 100; // ON: latest N signals TOTAL, within lookback

//------------------------- SWIS -----------------------------------//
input group "===== SWIS ====="

input bool   ShowSWIS              = true;

input int    InternalSwingStrength = 2;
input int    SWISLookbackBars      = 200;

//------------------------- CHOCH ----------------------------------//
input group "===== CHOCH ====="

input bool   ShowCHOCH             = true;

input int    ExternalSwingStrength = 2;
input int    CHOCHLookbackBars     = 500;

input bool   RequireCloseBreak     = true;

//------------------------- BOS ------------------------------------//
input group "===== BOS (shared external structure) ====="
input bool   ShowBOS               = true;
input color  BullishBOSColor       = clrLimeGreen;
input color  BearishBOSColor       = clrTomato;
input int    BOSLineWidth          = 1;
input ENUM_LINE_STYLE BOSLineStyle = STYLE_SOLID;
input int    BOSTextSize           = 7;
input int    BOSTextDistance       = 10;

//------------------------- VISUAL ---------------------------------//
input group "===== VISUAL ====="

input color  SWISHighColor         = clrSteelBlue;
input color  SWISLowColor          = clrDarkGoldenrod;

input color  BullishCHOCHColor     = clrLimeGreen;
input color  BearishCHOCHColor     = clrTomato;

input int    SWISLineWidth         = 1;
input int    CHOCHLineWidth        = 1;

input ENUM_LINE_STYLE SWISLineStyle  = STYLE_DOT;
input ENUM_LINE_STYLE CHOCHLineStyle = STYLE_DASH;

input int    SWISTextSize          = 7;
input int    CHOCHTextSize         = 7;

input int    SWISTextDistance      = 8;
input int    CHOCHTextDistance     = 10;

//==================================================================//
// PREFIX
//==================================================================//

string PREFIX_SWIS;
string PREFIX_CHOCH;
string PREFIX_BOS;

//==================================================================//
// GLOBAL
//==================================================================//

datetime g_lastBarTime = 0;
int g_lastRatesTotal = 0;
string g_drawnObjects[];

//==================================================================//
// ENUM
//==================================================================//

enum StructureState
{
   STRUCTURE_UNKNOWN = 0,
   STRUCTURE_BULLISH = 1,
   STRUCTURE_BEARISH = 2
};

//==================================================================//
// STRUCTURES
//==================================================================//

struct SwingPoint
{
   int      bar;
   double   price;
   datetime time;
   bool     isHigh;
};

struct EventInfo
{
   int      levelBar;
   double   levelPrice;
   datetime levelTime;

   int      breakBar;
   double   breakPrice;
   datetime breakTime;

   bool     bullish;
   string   label;
};

struct DisplayEvent
{
   EventInfo ev;
   string prefix;
   color lineColor;
   int lineWidth;
   ENUM_LINE_STYLE lineStyle;
   int textSize;
   int textDistance;
};
DisplayEvent g_display[];

int DisplayLimit() { return ShowHistory ? MaxHistorySignals : 3; }

//==================================================================//
// DELETE PREFIX OBJECTS
//==================================================================//

void DeletePrefixObjects(const string prefix)
{
   if(StringLen(prefix) > 0) ObjectsDeleteAll(0, prefix, 0, -1);
}

//==================================================================//
// DELETE ALL OUR OBJECTS
//==================================================================//

void DeleteAllOurObjects()
{
   DeletePrefixObjects(PREFIX_SWIS);
   DeletePrefixObjects(PREFIX_CHOCH);
   DeletePrefixObjects(PREFIX_BOS);
}

//==================================================================//
// SWING HIGH
//==================================================================//

bool IsSwingHigh(const double &high[],
                 const int rates_total,
                 const int bar,
                 const int strength)
{
   if(strength < 1)
      return false;

   if(bar < strength)
      return false;

   if(bar + strength >= rates_total)
      return false;

   double p = high[bar];

   for(int k = 1; k <= strength; k++)
   {
      if(p <= high[bar - k])
         return false;

      if(p <= high[bar + k])
         return false;
   }

   return true;
}

//==================================================================//
// SWING LOW
//==================================================================//

bool IsSwingLow(const double &low[],
                const int rates_total,
                const int bar,
                const int strength)
{
   if(strength < 1)
      return false;

   if(bar < strength)
      return false;

   if(bar + strength >= rates_total)
      return false;

   double p = low[bar];

   for(int k = 1; k <= strength; k++)
   {
      if(p >= low[bar - k])
         return false;

      if(p >= low[bar + k])
         return false;
   }

   return true;
}

//==================================================================//
// BUILD SWINGS
//==================================================================//

void BuildSwings(const double &high[],
                 const double &low[],
                 const datetime &time[],
                 const int rates_total,
                 const int strength,
                 const int lookback,
                 SwingPoint &swings[])
{
   ArrayResize(swings, 0);

   if(strength < 1)
      return;

   int oldestBar = rates_total - strength - 1;

   if(lookback > 0)
      oldestBar = MathMin(oldestBar, lookback);

   if(oldestBar < strength + 1)
      return;

   for(int bar = oldestBar; bar >= strength + 1; bar--)
   {
      bool sh = IsSwingHigh(high,
                            rates_total,
                            bar,
                            strength);

      bool sl = IsSwingLow(low,
                           rates_total,
                           bar,
                           strength);

      if(sh)
      {
         int n = ArraySize(swings);

         ArrayResize(swings, n + 1, 128);

         swings[n].bar    = bar;
         swings[n].price  = high[bar];
         swings[n].time   = time[bar];
         swings[n].isHigh = true;
      }

      if(sl)
      {
         int n = ArraySize(swings);

         ArrayResize(swings, n + 1, 128);

         swings[n].bar    = bar;
         swings[n].price  = low[bar];
         swings[n].time   = time[bar];
         swings[n].isHigh = false;
      }
   }
}

//==================================================================//
// FIND BULLISH BREAK
//==================================================================//

bool FindBullishBreak(const double &high[],
                      const double &close[],
                      const int rates_total,
                      const int swingBar,
                      const double level,
                      int &breakBar)
{
   breakBar = -1;

   if(swingBar <= 1)
      return false;

   for(int bar = swingBar - InternalSwingStrength - 1; bar >= 1; bar--)
   {
      bool broken;

      if(RequireCloseBreak)
         broken = (close[bar] > level);
      else
         broken = (high[bar] > level);

      if(broken)
      {
         breakBar = bar;
         return true;
      }
   }

   return false;
}

//==================================================================//
// FIND BEARISH BREAK
//==================================================================//

bool FindBearishBreak(const double &low[],
                      const double &close[],
                      const int rates_total,
                      const int swingBar,
                      const double level,
                      int &breakBar)
{
   breakBar = -1;

   if(swingBar <= 1)
      return false;

   for(int bar = swingBar - InternalSwingStrength - 1; bar >= 1; bar--)
   {
      bool broken;

      if(RequireCloseBreak)
         broken = (close[bar] < level);
      else
         broken = (low[bar] < level);

      if(broken)
      {
         breakBar = bar;
         return true;
      }
   }

   return false;
}

//==================================================================//
// DRAW EVENT
//==================================================================//

void PaintEvent(const string prefix,
               const string id,
               const EventInfo &ev,
               const color lineColor,
               const int lineWidth,
               const ENUM_LINE_STYLE lineStyle,
               const int textSize,
               const int textDistance)
{
   string lineName = prefix + "LINE_" + id;
   string textName = prefix + "TEXT_" + id;

   int drawn = ArraySize(g_drawnObjects);
   ArrayResize(g_drawnObjects, drawn + 2, 64);
   g_drawnObjects[drawn] = lineName;
   g_drawnObjects[drawn + 1] = textName;

   if(ObjectFind(0, lineName) < 0 && !ObjectCreate(0,
                    lineName,
                    OBJ_TREND,
                    0,
                    ev.levelTime,
                    ev.levelPrice,
                    ev.breakTime,
                    ev.levelPrice))
   {
      return;
   }

   ObjectMove(0, lineName, 0, ev.levelTime, ev.levelPrice);
   ObjectMove(0, lineName, 1, ev.breakTime, ev.levelPrice);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, false);



   long t1 = (long)ev.levelTime;
   long t2 = (long)ev.breakTime;

   datetime midTime = (datetime)((t1 + t2) / 2);

   double textPrice = ev.levelPrice;

   if(ev.bullish)
      textPrice += textDistance * _Point;
   else
      textPrice -= textDistance * _Point;

   if(ObjectFind(0, textName) < 0 && !ObjectCreate(0,
                    textName,
                    OBJ_TEXT,
                    0,
                    midTime,
                    textPrice))
   {
      return;
   }

   ObjectMove(0, textName, 0, midTime, textPrice);

   ObjectSetString(0,
                   textName,
                   OBJPROP_TEXT,
                   ev.label);

   ObjectSetInteger(0,
                    textName,
                    OBJPROP_COLOR,
                    lineColor);

   ObjectSetInteger(0,
                    textName,
                    OBJPROP_FONTSIZE,
                    textSize);

   ObjectSetString(0,
                   textName,
                   OBJPROP_FONT,
                   "Arial");

   if(ev.bullish)
      ObjectSetInteger(0,
                       textName,
                       OBJPROP_ANCHOR,
                       ANCHOR_LOWER);
   else
      ObjectSetInteger(0,
                       textName,
                       OBJPROP_ANCHOR,
                       ANCHOR_UPPER);

   ObjectSetInteger(0,
                    textName,
                    OBJPROP_BACK,
                    false);

   ObjectSetInteger(0,
                    textName,
                    OBJPROP_SELECTABLE,
                    false);

   ObjectSetInteger(0,
                    textName,
                    OBJPROP_SELECTED,
                    false);

   ObjectSetInteger(0,
                    textName,
                    OBJPROP_HIDDEN,
                    false);
}

// Queue only the newest DisplayLimit() events, independent of engine order.
// Ties: later pivot, then CHOCH > BOS > SWIS; stable order thereafter.
int EventPriority(const string label)
{
   if(label == "CHOCH") return 3;
   if(label == "BOS") return 2;
   return 1;
}
bool NewerEvent(const EventInfo &a, const EventInfo &b)
{
   if(a.breakTime != b.breakTime) return a.breakTime > b.breakTime;
   if(a.levelTime != b.levelTime) return a.levelTime > b.levelTime;
   return EventPriority(a.label) > EventPriority(b.label);
}
void DrawEvent(const string prefix, const string id, const EventInfo &ev,
               const color lineColor, const int lineWidth,
               const ENUM_LINE_STYLE lineStyle, const int textSize,
               const int textDistance)
{
   int n = ArraySize(g_display), limit = DisplayLimit();
   int at = 0;
   while(at < n && !NewerEvent(ev, g_display[at].ev)) at++;
   if(at >= limit) return;
   int next = MathMin(n + 1, limit);
   if(ArrayResize(g_display, next) < 0) return;
   for(int i = next - 1; i > at; i--) g_display[i] = g_display[i - 1];
   g_display[at].ev = ev;
   g_display[at].prefix = prefix;
   g_display[at].lineColor = lineColor;
   g_display[at].lineWidth = lineWidth;
   g_display[at].lineStyle = lineStyle;
   g_display[at].textSize = textSize;
   g_display[at].textDistance = textDistance;
}

void FlushDisplay()
{
   string previous[];
   ArrayCopy(previous, g_drawnObjects);
   ArrayResize(g_drawnObjects, 0);
   for(int i = 0; i < ArraySize(g_display); i++)
   {
      DisplayEvent item = g_display[i];
      string id = IntegerToString((long)item.ev.breakTime) + "_" +
                  IntegerToString((long)item.ev.levelTime) + "_" +
                  (item.ev.bullish ? "UP" : "DOWN");
      PaintEvent(item.prefix, id, item.ev, item.lineColor, item.lineWidth,
                 item.lineStyle, item.textSize, item.textDistance);
   }
   // Only inspect this instance's prior drawings, never the whole chart.
   for(int i = 0; i < ArraySize(previous); i++)
   {
      bool keep = false;
      for(int j = 0; j < ArraySize(g_drawnObjects); j++)
         if(previous[i] == g_drawnObjects[j]) { keep = true; break; }
      if(!keep) ObjectDelete(0, previous[i]);
   }
   ArrayFree(previous);
   ArrayFree(g_display);
}

//==================================================================//
// PROCESS SWIS
//
// v1.8: closed-bar confirmation and break-time ordering.
//==================================================================//

void ProcessSWIS(const double &high[], const double &low[],
                 const double &close[], const datetime &time[], const int rates_total)
{
   if(!ShowSWIS) return;
   SwingPoint swings[];
   BuildSwings(high, low, time, rates_total, InternalSwingStrength, SWISLookbackBars, swings);
   for(int i = 0; i < ArraySize(swings); i++)
   {
      SwingPoint swing = swings[i];
      int brokenAt = -1;
      bool broken = swing.isHigh ?
         FindBullishBreak(high, close, rates_total, swing.bar, swing.price, brokenAt) :
         FindBearishBreak(low, close, rates_total, swing.bar, swing.price, brokenAt);
      if(!broken) continue;
      EventInfo ev;
      ev.levelBar = swing.bar; ev.levelPrice = swing.price; ev.levelTime = swing.time;
      ev.breakBar = brokenAt; ev.breakPrice = close[brokenAt]; ev.breakTime = time[brokenAt];
      ev.bullish = swing.isHigh; ev.label = "SWIS";
      DrawEvent(PREFIX_SWIS, "", ev, ev.bullish ? SWISHighColor : SWISLowColor,
                SWISLineWidth, SWISLineStyle, SWISTextSize, SWISTextDistance);
   }
   ArrayFree(swings);
}

//==================================================================//
// ADD CHOCH EVENT
//==================================================================//

void AddCHOCHEvent(EventInfo &events[],
                   int &eventCount,
                   const int levelBar,
                   const double levelPrice,
                   const datetime levelTime,
                   const int breakBar,
                   const double breakPrice,
                   const datetime breakTime,
                   const bool bullish,
                   const string label = "CHOCH")
{
   EventInfo ev;

   ev.levelBar   = levelBar;
   ev.levelPrice = levelPrice;
   ev.levelTime  = levelTime;

   ev.breakBar   = breakBar;
   ev.breakPrice = breakPrice;
   ev.breakTime  = breakTime;

   ev.bullish = bullish;
   ev.label   = label;

   int limit = DisplayLimit();
   if(eventCount >= limit)
   {
      for(int i = 1; i < eventCount; i++) events[i - 1] = events[i];
      events[eventCount - 1] = ev;
      return;
   }
   if(ArrayResize(events, eventCount + 1) < 0) return;
   events[eventCount++] = ev;
}

//==================================================================//
// RESET CHOCH STRUCTURE
//==================================================================//

void ResetCHOCHStructure(StructureState &state,

                         bool &hasLastHigh,
                         double &lastHigh,
                         int &lastHighBar,
                         datetime &lastHighTime,

                         bool &hasLastLow,
                         double &lastLow,
                         int &lastLowBar,
                         datetime &lastLowTime,

                         bool &hasHH,
                         int &hhBar,

                         bool &hasHL,
                         int &hlBar,

                         bool &hasLL,
                         int &llBar,

                         bool &hasLH,
                         int &lhBar,

                         bool &hasProtectedLow,
                         double &protectedLow,
                         int &protectedLowBar,
                         datetime &protectedLowTime,

                         bool &hasProtectedHigh,
                         double &protectedHigh,
                         int &protectedHighBar,
                         datetime &protectedHighTime)
{
   state = STRUCTURE_UNKNOWN;

   hasLastHigh = false;
   lastHigh = 0.0;
   lastHighBar = -1;
   lastHighTime = 0;

   hasLastLow = false;
   lastLow = 0.0;
   lastLowBar = -1;
   lastLowTime = 0;

   hasHH = false;
   hhBar = -1;

   hasHL = false;
   hlBar = -1;

   hasLL = false;
   llBar = -1;

   hasLH = false;
   lhBar = -1;

   hasProtectedLow = false;
   protectedLow = 0.0;
   protectedLowBar = -1;
   protectedLowTime = 0;

   hasProtectedHigh = false;
   protectedHigh = 0.0;
   protectedHighBar = -1;
   protectedHighTime = 0;
}

//==================================================================//
// PROCESS CHOCH
//
// CHRONOLOGICAL STRUCTURE
//
// UNKNOWN:
//   HH -> HL  = BULLISH
//   LL -> LH  = BEARISH
//
// BULLISH:
//   Only protected HL controls bearish CHOCH.
//
// BEARISH:
//   Only protected LH controls bullish CHOCH.
//
// After CHOCH:
//   Complete reset.
//==================================================================//

void ProcessCHOCH(const double &high[],
                  const double &low[],
                  const double &close[],
                  const datetime &time[],
                  const int rates_total)
{
   if(!ShowCHOCH && !ShowBOS)
      return;

   if(ExternalSwingStrength < 1)
      return;

   if(rates_total < ExternalSwingStrength * 2 + 20)
      return;

   StructureState state = STRUCTURE_UNKNOWN;
   int lastResetBar = rates_total;

   //---------------------------------------------------------------//
   // LAST HIGH / LOW
   //---------------------------------------------------------------//

   bool hasLastHigh = false;
   double lastHigh = 0.0;
   int lastHighBar = -1;
   datetime lastHighTime = 0;

   bool hasLastLow = false;
   double lastLow = 0.0;
   int lastLowBar = -1;
   datetime lastLowTime = 0;

   //---------------------------------------------------------------//
   // STRUCTURE
   //---------------------------------------------------------------//

   bool hasHH = false;
   int hhBar = -1;

   bool hasHL = false;
   int hlBar = -1;

   bool hasLL = false;
   int llBar = -1;

   bool hasLH = false;
   int lhBar = -1;

   //---------------------------------------------------------------//
   // PROTECTED LEVELS
   //---------------------------------------------------------------//

   bool hasProtectedLow = false;
   double protectedLow = 0.0;
   int protectedLowBar = -1;
   datetime protectedLowTime = 0;

   bool hasProtectedHigh = false;
   double protectedHigh = 0.0;
   int protectedHighBar = -1;
   datetime protectedHighTime = 0;

   //---------------------------------------------------------------//
   // EVENTS
   //---------------------------------------------------------------//

   SwingPoint bosHigh, bosLow;
   bosHigh.bar = -1; bosHigh.price = 0.0; bosHigh.time = 0; bosHigh.isHigh = true;
   bosLow.bar = -1; bosLow.price = 0.0; bosLow.time = 0; bosLow.isHigh = false;
   bool hasBOSHigh = false, hasBOSLow = false;
   bool bosHighReady = false, bosLowReady = false;
   EventInfo bosEvents[];
   int bosCount = 0;

   EventInfo events[];
   int eventCount = 0;

   //---------------------------------------------------------------//
   // LOOKBACK
   //---------------------------------------------------------------//

   int oldestCurrentBar =
      rates_total -
      ExternalSwingStrength * 2 -
      2;

   if(CHOCHLookbackBars > 0)
      oldestCurrentBar =
         MathMin(oldestCurrentBar,
                 CHOCHLookbackBars);

   if(oldestCurrentBar < 1)
      return;

   //---------------------------------------------------------------//
   // OLD -> NEW
   //
   // Series array:
   // larger bar index = older
   // smaller bar index = newer
   //---------------------------------------------------------------//

   for(int bar = oldestCurrentBar; bar >= 1; bar--)
   {
      //------------------------------------------------------------//
      // BULLISH STRUCTURE
      //
      // HH -> HL
      // Protected HL broken = bearish CHOCH
      //------------------------------------------------------------//

      if(state == STRUCTURE_BULLISH &&
         hasProtectedLow)
      {
         bool broken = false;

         if(RequireCloseBreak)
            broken = (close[bar] < protectedLow);
         else
            broken = (low[bar] < protectedLow);

         if(broken)
         {
            AddCHOCHEvent(events,
                          eventCount,
                          protectedLowBar,
                          protectedLow,
                          protectedLowTime,
                          bar,
                          close[bar],
                          time[bar],
                          false);

            hasBOSHigh = false;
            hasBOSLow = false;
            bosHighReady = false;
            bosLowReady = false;
            lastResetBar = bar;
            ResetCHOCHStructure(state,

                                hasLastHigh,
                                lastHigh,
                                lastHighBar,
                                lastHighTime,

                                hasLastLow,
                                lastLow,
                                lastLowBar,
                                lastLowTime,

                                hasHH,
                                hhBar,

                                hasHL,
                                hlBar,

                                hasLL,
                                llBar,

                                hasLH,
                                lhBar,

                                hasProtectedLow,
                                protectedLow,
                                protectedLowBar,
                                protectedLowTime,

                                hasProtectedHigh,
                                protectedHigh,
                                protectedHighBar,
                                protectedHighTime);

            continue;
         }
      }

      //------------------------------------------------------------//
      // BEARISH STRUCTURE
      //
      // LL -> LH
      // Protected LH broken = bullish CHOCH
      //------------------------------------------------------------//

      if(state == STRUCTURE_BEARISH &&
         hasProtectedHigh)
      {
         bool broken = false;

         if(RequireCloseBreak)
            broken = (close[bar] > protectedHigh);
         else
            broken = (high[bar] > protectedHigh);

         if(broken)
         {
            AddCHOCHEvent(events,
                          eventCount,
                          protectedHighBar,
                          protectedHigh,
                          protectedHighTime,
                          bar,
                          close[bar],
                          time[bar],
                          true);

            hasBOSHigh = false;
            hasBOSLow = false;
            bosHighReady = false;
            bosLowReady = false;
            lastResetBar = bar;
            ResetCHOCHStructure(state,

                                hasLastHigh,
                                lastHigh,
                                lastHighBar,
                                lastHighTime,

                                hasLastLow,
                                lastLow,
                                lastLowBar,
                                lastLowTime,

                                hasHH,
                                hhBar,

                                hasHL,
                                hlBar,

                                hasLL,
                                llBar,

                                hasLH,
                                lhBar,

                                hasProtectedLow,
                                protectedLow,
                                protectedLowBar,
                                protectedLowTime,

                                hasProtectedHigh,
                                protectedHigh,
                                protectedHighBar,
                                protectedHighTime);

            continue;
         }
      }

      // Consume a level at its FIRST closed-bar break, including UNKNOWN.
      // An earlier break must never be relabeled retrospectively as BOS.
      if(hasBOSHigh && bosHighReady &&
         (RequireCloseBreak ? close[bar] > bosHigh.price : high[bar] > bosHigh.price))
      {
         bosHighReady = false;
         if(state == STRUCTURE_BULLISH)
         {
            AddCHOCHEvent(bosEvents, bosCount, bosHigh.bar, bosHigh.price,
                          bosHigh.time, bar, close[bar], time[bar], true, "BOS");
         }
      }
      if(hasBOSLow && bosLowReady &&
         (RequireCloseBreak ? close[bar] < bosLow.price : low[bar] < bosLow.price))
      {
         bosLowReady = false;
         if(state == STRUCTURE_BEARISH)
         {
            AddCHOCHEvent(bosEvents, bosCount, bosLow.bar, bosLow.price,
                          bosLow.time, bar, close[bar], time[bar], false, "BOS");
         }
      }

      //------------------------------------------------------------//
      // Confirm swing
      //------------------------------------------------------------//

      int candidate =
         bar + ExternalSwingStrength;

      if(candidate >= ExternalSwingStrength &&
         candidate + ExternalSwingStrength < rates_total &&
         candidate < lastResetBar)
      {
         bool newSwingHigh =
            IsSwingHigh(high,
                        rates_total,
                        candidate,
                        ExternalSwingStrength);

         bool newSwingLow =
            IsSwingLow(low,
                       rates_total,
                       candidate,
                       ExternalSwingStrength);

         //---------------------------------------------------------//
         // HIGH STRUCTURE
         //---------------------------------------------------------//

         if(newSwingHigh && newSwingLow)
         {
            newSwingHigh = false;
            newSwingLow = false;
         }

         // In a bullish structure, a lower high cannot replace the BOS high.
         // In a bearish structure, a higher low cannot replace the BOS low.
         if(newSwingHigh &&
            (!hasBOSHigh || state != STRUCTURE_BULLISH || high[candidate] > bosHigh.price))
         {
            bosHigh.bar = candidate;
            bosHigh.price = high[candidate];
            bosHigh.time = time[candidate];
            bosHigh.isHigh = true;
            hasBOSHigh = true;
            bosHighReady = true;
         }
         if(newSwingLow &&
            (!hasBOSLow || state != STRUCTURE_BEARISH || low[candidate] < bosLow.price))
         {
            bosLow.bar = candidate;
            bosLow.price = low[candidate];
            bosLow.time = time[candidate];
            bosLow.isHigh = false;
            hasBOSLow = true;
            bosLowReady = true;
         }

         if(newSwingHigh)
         {
            double p = high[candidate];

            if(!hasLastHigh)
            {
               hasLastHigh = true;

               lastHigh = p;
               lastHighBar = candidate;
               lastHighTime = time[candidate];
            }
            else
            {
               if(p > lastHigh)
               {
                  // New Higher High.
                  hasLL = false;
                  hasHH = true;
                  hhBar = candidate;
               }
               else
               if(p < lastHigh)
               {
                  // New Lower High.
                  hasHH = false;
                  hasLH = true;
                  lhBar = candidate;

                  //------------------------------------------------//
                  // LL -> LH
                  //
                  // Important:
                  // llBar > lhBar means LL happened BEFORE LH
                  // chronologically.
                  //------------------------------------------------//

                  if(state == STRUCTURE_UNKNOWN &&
                     hasLL &&
                     llBar > lhBar)
                  {
                     state = STRUCTURE_BEARISH;

                     hasProtectedHigh = true;
                     protectedHigh = p;
                     protectedHighBar = candidate;
                     protectedHighTime = time[candidate];

                     hasProtectedLow = false;
                     protectedLow = 0.0;
                     protectedLowBar = -1;
                     protectedLowTime = 0;
                     hasLL = false;
                  }
                  else if(state == STRUCTURE_BEARISH && hasLL && llBar > lhBar)
                  {
                     hasProtectedHigh = true;
                     protectedHigh = p;
                     protectedHighBar = candidate;
                     protectedHighTime = time[candidate];
                     hasLL = false;
                  }
               }

               lastHigh = p;
               lastHighBar = candidate;
               lastHighTime = time[candidate];
            }
         }

         //---------------------------------------------------------//
         // LOW STRUCTURE
         //---------------------------------------------------------//

         if(newSwingLow)
         {
            double p = low[candidate];

            if(!hasLastLow)
            {
               hasLastLow = true;

               lastLow = p;
               lastLowBar = candidate;
               lastLowTime = time[candidate];
            }
            else
            {
               if(p > lastLow)
               {
                  // New Higher Low.
                  hasLL = false;
                  hasHL = true;
                  hlBar = candidate;

                  //------------------------------------------------//
                  // HH -> HL
                  //
                  // Important:
                  // hhBar > hlBar means HH happened BEFORE HL.
                  //------------------------------------------------//

                  if(state == STRUCTURE_UNKNOWN &&
                     hasHH &&
                     hhBar > hlBar)
                  {
                     state = STRUCTURE_BULLISH;

                     hasProtectedLow = true;
                     protectedLow = p;
                     protectedLowBar = candidate;
                     protectedLowTime = time[candidate];

                     hasProtectedHigh = false;
                     protectedHigh = 0.0;
                     protectedHighBar = -1;
                     protectedHighTime = 0;
                     hasHH = false;
                  }
                  else
                  if(state == STRUCTURE_BULLISH &&
                     hasHH &&
                     hhBar > hlBar)
                  {
                     //------------------------------------------------//
                     // New HH followed by new HL.
                     // Update protected low.
                     //------------------------------------------------//

                     hasProtectedLow = true;
                     protectedLow = p;
                     protectedLowBar = candidate;
                     protectedLowTime = time[candidate];
                     hasHH = false;
                  }
               }
               else
               if(p < lastLow)
               {
                  // New Lower Low.
                  hasHH = false;
                  hasLL = true;
                  llBar = candidate;
               }

               lastLow = p;
               lastLowBar = candidate;
               lastLowTime = time[candidate];
            }
         }
      }


   }

   //---------------------------------------------------------------//
   // NO EVENTS
   //---------------------------------------------------------------//

   if(ShowBOS)
      for(int i = 0; i < bosCount; i++)
      {
         EventInfo ev = bosEvents[i];
         DrawEvent(PREFIX_BOS, "", ev, ev.bullish ? BullishBOSColor : BearishBOSColor,
                   BOSLineWidth, BOSLineStyle, BOSTextSize, BOSTextDistance);
      }
   if(ShowCHOCH)
      for(int i = 0; i < eventCount; i++)
      {
         EventInfo ev = events[i];
         DrawEvent(PREFIX_CHOCH, "", ev, ev.bullish ? BullishCHOCHColor : BearishCHOCHColor,
                   CHOCHLineWidth, CHOCHLineStyle, CHOCHTextSize, CHOCHTextDistance);
      }
   ArrayFree(events);
   ArrayFree(bosEvents);
}

//==================================================================//
// ON INIT
//==================================================================//

int OnInit()
{
   if(InternalSwingStrength < 1 || InternalSwingStrength > 1000 ||
      ExternalSwingStrength < 1 || ExternalSwingStrength > 1000 ||
      SWISLookbackBars < 0 || CHOCHLookbackBars < 0 ||
      (SWISLookbackBars > 0 && SWISLookbackBars < InternalSwingStrength + 1) ||
      MaxHistorySignals < 1 || MaxHistorySignals > 1000 ||
      BOSLineWidth < 1 || BOSLineWidth > 5 || BOSTextSize < 1 || BOSTextDistance < 0 ||
      SWISLineWidth < 1 || SWISLineWidth > 5 ||
      CHOCHLineWidth < 1 || CHOCHLineWidth > 5 ||
      SWISTextSize < 1 || CHOCHTextSize < 1 ||
      SWISTextDistance < 0 || CHOCHTextDistance < 0)
   {
      Print("SWIS + CHOCH: invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }
   string instance = "SC18_" + IntegerToString((long)GetMicrosecondCount()) + "_";
   PREFIX_SWIS = instance + "S_";
   PREFIX_CHOCH = instance + "C_";
   PREFIX_BOS = instance + "B_";
   g_lastBarTime = 0;
   g_lastRatesTotal = 0;

   IndicatorSetString(INDICATOR_SHORTNAME,
                      "SWIS + CHOCH + BOS v1.8");

   return(INIT_SUCCEEDED);
}

//==================================================================//
// ON DEINIT
//==================================================================//

void OnDeinit(const int reason)
{
   DeleteAllOurObjects();
   ArrayFree(g_drawnObjects);
   ArrayFree(g_display);
   g_lastBarTime = 0;
   g_lastRatesTotal = 0;
   ChartRedraw(0);
}

//==================================================================//
// ON CALCULATE
//==================================================================//

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
   if(!EnableIndicator || (!ShowSWIS && !ShowCHOCH && !ShowBOS))
   {
      if(ArraySize(g_drawnObjects) > 0)
      {
         DeleteAllOurObjects();
         ChartRedraw(0);
      }
      ArrayFree(g_drawnObjects);
      ArrayFree(g_display);
      g_lastBarTime = 0;
      g_lastRatesTotal = 0;
      return rates_total;
   }

   int minBars =
      MathMax(InternalSwingStrength * 2 + 20,
              ExternalSwingStrength * 2 + 20);

   if(rates_total < minBars)
   {
      DeleteAllOurObjects();
      ArrayFree(g_drawnObjects);
      ArrayFree(g_display);
      ChartRedraw(0);
      return 0;
   }

   //---------------------------------------------------------------//
   // Force series arrays
   //---------------------------------------------------------------//

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(spread, true);

   //---------------------------------------------------------------//
   // NEW BAR ONLY
   //---------------------------------------------------------------//

   if(prev_calculated > 0 && g_lastBarTime == time[0] &&
      g_lastRatesTotal == rates_total)
      return rates_total;

   g_lastBarTime = time[0];
   g_lastRatesTotal = rates_total;

   //---------------------------------------------------------------//
   // START DRAW PASS
   //---------------------------------------------------------------//

   ArrayResize(g_display, 0);

   //---------------------------------------------------------------//
   // SWIS
   //---------------------------------------------------------------//

   ProcessSWIS(high,
               low,
               close,
               time,
               rates_total);

   //---------------------------------------------------------------//
   // CHOCH
   //---------------------------------------------------------------//

   ProcessCHOCH(high,
                low,
                close,
                time,
                rates_total);

   //---------------------------------------------------------------//
   // REDRAW
   //---------------------------------------------------------------//

   FlushDisplay();
   ChartRedraw(0);

   return rates_total;
}
//+------------------------------------------------------------------+