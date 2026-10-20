//+------------------------------------------------------------------+
//|              Entry.mq5 - TradingView-style three-target position tool                          |
//|              Visual Risk / Reward Calculator                     |
//|              CUSTOM INDICATOR - NO TRADING                       |
//+------------------------------------------------------------------+
#property strict
#property version   "3.22"
#property description "Visual position tool: independent Entry / SL / TP1 / TP2 / TP3, zones and live RR"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//==================================================================
// INPUTS
//==================================================================

enum ENUM_ENTRY_SIDE { ENTRY_BOTH=0, ENTRY_LONG_ONLY=1, ENTRY_SHORT_ONLY=2 };
input group "===== OPTIONAL EMA AUTO SETUP ====="
input bool InpAutoEMA = false; // Visual setup only. Never sends orders.
input int InpFastEMA = 10;
input int InpSlowEMA = 20;
input ENUM_ENTRY_SIDE InpTradeSide = ENTRY_BOTH;
input group "===== INITIAL R:R ====="

input double InpRR1 = 1.0;                  // Initial TP1 = 1R
input double InpRR2 = 2.0;                  // Initial TP2 = 2R
input double InpRR3 = 3.0;                  // Initial TP3 = 3R

input group "===== TOOL SIZE ====="

input int    InpWidthBars     = 10;         // Width in candles
input double InpMinRiskPoints = 10;         // Minimum risk in points

input group "===== COLORS ====="

input color InpSLColor     = clrRed;
input color InpEntryColor  = clrDodgerBlue;
input color InpTPColor     = clrLightGreen;
input color InpHandleColor = clrWhite;
input bool InpShowZones = true;
input color InpRiskZoneColor = C'65,25,30';
input color InpRewardZoneColor = C'20,55,40';
input int InpHitPixels = 6; // Grab a level within this pixel distance
// Double-click: create using candle close / wick; inside tool: remove.
// Gold bottom-center dot: scale SL and all TPs around fixed Entry.
// SL line: SL only. Any TP line: scale all TPs around fixed Entry.
// Body: move all. Entry line: Entry only. White right-center dot: width.


input group "===== LINE ====="

input ENUM_LINE_STYLE InpLineStyle = STYLE_DOT;
input int InpLineWidth = 1;

input group "===== MOUSE ====="

input int InpDragThreshold     = 4;
input int InpDoubleClickMS     = 500;
input int InpDoubleClickPixels = 10;

//==================================================================
// ENUMS
//==================================================================

enum ENUM_RR_DIRECTION
{
   RR_BUY  = 0,
   RR_SELL = 1
};

enum ENUM_MOUSE_MODE
{
   MOUSE_NONE   = 0,
   MOUSE_MOVE   = 1,
   MOUSE_RESIZE = 2
};

//==================================================================
// GLOBALS
//==================================================================

long g_chartID = 0;
string g_prefix;
int g_editLevel = -1; // 0 entry, 1 SL, 2..4 grouped TPs, 5 width, 6 scale all
int g_fastEMAHandle=INVALID_HANDLE,g_slowEMAHandle=INVALID_HANDLE;
datetime g_lastEMABar=0;
double g_scaleSL0=0,g_scaleTP10=0,g_scaleTP20=0,g_scaleTP30=0;
bool g_chartLocked = false; // Hover locks mouse scrolling before button down.
bool g_dragChartLocked=false,g_oldScaleFix=false,g_scaleWasChanged=false;
double g_oldFixedMin=0,g_oldFixedMax=0;
int g_widthStartY=0;
int g_nativeHandle=-1; // 5 width, 6 bottom scaling; MT5 owns dragging these objects.
bool g_nativeChanged=false;
bool g_riskZoneReady=false,g_rewardZoneReady=false,g_widthHandleReady=false;
bool g_renderPending=false,g_forceLabelText=false;
ulong g_lastRenderMS=0,g_lastLabelMS=0,g_lastNativePollMS=0,g_lastIdlePollMS=0,g_lastLockCheckMS=0;
string g_cachedLabel[5];
double g_nativeBasePrice=0,g_nativeLastPrice=0;
datetime g_nativeLastTime=0;
bool g_oldMouseEvents = false;
double g_editPrice0 = 0;
double g_pressPrice = 0;
datetime g_pressTime = 0;
datetime g_editEnd0 = 0;


//------------------------------------------------------------------
// Tool state
//------------------------------------------------------------------

bool g_toolCreated = false;

ENUM_RR_DIRECTION g_direction = RR_BUY;
ENUM_MOUSE_MODE   g_mouseMode = MOUSE_NONE;

//------------------------------------------------------------------
// Price levels
//------------------------------------------------------------------

double g_entry = 0.0;
double g_sl    = 0.0;
double g_tp1   = 0.0;
double g_tp2   = 0.0;
double g_tp3   = 0.0;

//------------------------------------------------------------------
// Time range
//------------------------------------------------------------------

datetime g_startTime = 0;
datetime g_endTime   = 0;

//==================================================================
// MOUSE / DOUBLE CLICK STATE
//==================================================================

bool g_leftButtonDown = false;

ulong g_lastPressTick = 0;

int g_lastPressX = -10000;
int g_lastPressY = -10000;

//------------------------------------------------------------------
// Drag state
//------------------------------------------------------------------

bool g_movePending   = false;
bool g_resizePending = false;
bool g_wasDragged    = false;

int g_dragStartX = 0;
int g_dragStartY = 0;

//==================================================================
// MOVE STATE
//==================================================================

datetime g_moveAnchorTime  = 0;
double   g_moveAnchorPrice = 0.0;

double g_moveEntry0 = 0.0;
double g_moveSL0    = 0.0;
double g_moveTP10   = 0.0;
double g_moveTP20   = 0.0;
double g_moveTP30   = 0.0;

datetime g_moveStartTime0 = 0;
datetime g_moveEndTime0   = 0;

//==================================================================
// RESIZE STATE
//==================================================================

double g_resizeStartHandlePrice = 0.0;

//==================================================================
// HANDLE POSITION
//==================================================================

datetime g_handleTime  = 0;
double   g_handlePrice = 0.0;

//==================================================================
// CHART SETTINGS
//==================================================================

bool g_oldMouseScroll = true;
bool g_oldAutoScroll  = true;

//==================================================================
// OBJECT NAMES
//==================================================================

string Prefix()
{
   return g_prefix;
}

string NameSL()
{
   return Prefix() + "_SL";
}

string NameEntry()
{
   return Prefix() + "_ENTRY";
}

string NameTP1()
{
   return Prefix() + "_TP1";
}

string NameTP2()
{
   return Prefix() + "_TP2";
}

string NameTP3()
{
   return Prefix() + "_TP3";
}

string NameHandle()
{
   return Prefix() + "_HANDLE";
}

string NameLabelSL()
{
   return Prefix() + "_LBL_SL";
}

string NameLabelEntry()
{
   return Prefix() + "_LBL_ENTRY";
}

string NameLabelTP1()
{
   return Prefix() + "_LBL_TP1";
}

string NameLabelTP2()
{
   return Prefix() + "_LBL_TP2";
}

string NameLabelTP3()
{
   return Prefix() + "_LBL_TP3";
}

//==================================================================
// NORMALIZE PRICE
//==================================================================

double NormalizePrice(double price)
{
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick>0) price=MathRound(price/tick)*tick;
   return NormalizeDouble(
      price,
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS));
}

//==================================================================
// DELETE TOOL OBJECTS
//==================================================================

void DeleteToolObjects()
{
   g_riskZoneReady=false;g_rewardZoneReady=false;g_widthHandleReady=false;
   g_renderPending=false;g_lastRenderMS=0;g_lastLabelMS=0;
   for(int i=0;i<5;i++) g_cachedLabel[i]="";
   ObjectDelete(g_chartID,Prefix()+"_RISK");
   ObjectDelete(g_chartID,Prefix()+"_REWARD");
   ObjectDelete(g_chartID,Prefix()+"_WIDTH_HANDLE");
   for(int i=0;i<5;i++) ObjectDelete(g_chartID,Prefix()+"_GRAB"+IntegerToString(i));
   ObjectDelete(g_chartID, NameSL());
   ObjectDelete(g_chartID, NameEntry());
   ObjectDelete(g_chartID, NameTP1());
   ObjectDelete(g_chartID, NameTP2());
   ObjectDelete(g_chartID, NameTP3());

   ObjectDelete(g_chartID, NameHandle());

   ObjectDelete(g_chartID, NameLabelSL());
   ObjectDelete(g_chartID, NameLabelEntry());
   ObjectDelete(g_chartID, NameLabelTP1());
   ObjectDelete(g_chartID, NameLabelTP2());
   ObjectDelete(g_chartID, NameLabelTP3());
}

//==================================================================
// TOOL OFF
//==================================================================

void DeleteTool()
{
   g_nativeHandle=-1;
   StopDrag();
   DeleteToolObjects();

   g_toolCreated = false;

   g_mouseMode = MOUSE_NONE;

   g_movePending   = false;
   g_resizePending = false;
   g_wasDragged    = false;

   g_lastPressTick = 0;
   g_lastPressX = -10000;
   g_lastPressY = -10000;

   ChartRedraw(g_chartID);

   Print("RR TOOL OFF");
}

//==================================================================
// GET CLICKED CANDLE
//==================================================================

bool GetClickedCandle(
   datetime clickedTime,
   double &openPrice,
   double &highPrice,
   double &lowPrice,
   double &closePrice,
   datetime &candleTime)
{
   int shift =
      iBarShift(
         _Symbol,
         _Period,
         clickedTime,
         false);

   if(shift < 0)
      return false;

   openPrice =
      iOpen(
         _Symbol,
         _Period,
         shift);

   highPrice =
      iHigh(
         _Symbol,
         _Period,
         shift);

   lowPrice =
      iLow(
         _Symbol,
         _Period,
         shift);

   closePrice =
      iClose(
         _Symbol,
         _Period,
         shift);

   candleTime =
      iTime(
         _Symbol,
         _Period,
         shift);

   if(openPrice <= 0 ||
      highPrice <= 0 ||
      lowPrice <= 0 ||
      closePrice <= 0)
   {
      return false;
   }

   return true;
}

//==================================================================
// TIME RANGE
//==================================================================

void CalculateToolTimeRange(
   datetime candleTime)
{
   g_startTime = candleTime;

   int secondsPerBar =
      PeriodSeconds(_Period);

   if(secondsPerBar <= 0)
      secondsPerBar = 60;

   int shift=iBarShift(_Symbol,_Period,candleTime,false);
   if(shift>=InpWidthBars) g_endTime=iTime(_Symbol,_Period,shift-InpWidthBars);
   else {
      datetime latest=iTime(_Symbol,_Period,0);
      g_endTime=latest+(datetime)((long)secondsPerBar*(InpWidthBars-MathMax(0,shift)));
   }
}

//==================================================================
// TOP / BOTTOM
//==================================================================

double GetToolTop()
{
   return MathMax(
      g_sl,
      MathMax(
         g_tp1,
         MathMax(
            g_tp2,
            g_tp3)));
}

double GetToolBottom()
{
   return MathMin(
      g_sl,
      MathMin(
         g_tp1,
         MathMin(
            g_tp2,
            g_tp3)));
}

//==================================================================
// HANDLE POSITION
//==================================================================

void CalculateHandlePosition(
   datetime &handleTime,
   double &handlePrice)
{
   handleTime=g_startTime+(datetime)((g_endTime-g_startTime)/2);
   handlePrice=GetToolBottom();
}

//==================================================================
// CREATE LINE
//==================================================================

bool CreateLine(
   string name,
   double price,
   color clr)
{
   ObjectDelete(
      g_chartID,
      name);

   if(!ObjectCreate(
      g_chartID,
      name,
      OBJ_TREND,
      0,
      g_startTime,
      price,
      g_endTime,
      price))
   {
      Print(
         "CreateLine ERROR: ",
         name,
         " / ",
         GetLastError());

      return false;
   }

   // Ensure horizontal
   ObjectMove(
      g_chartID,
      name,
      0,
      g_startTime,
      price);

   ObjectMove(
      g_chartID,
      name,
      1,
      g_endTime,
      price);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_COLOR,
      clr);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_STYLE,
      InpLineStyle);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_WIDTH,
      InpLineWidth);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_RAY_LEFT,
      false);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_RAY_RIGHT,
      false);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_SELECTABLE,
      false);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_SELECTED,
      false);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_HIDDEN,
      true);

   return true;
}

//==================================================================
// CREATE LABEL
//==================================================================

bool CreateLabel(
   string name,
   string text,
   double price,
   color clr)
{
   ObjectDelete(
      g_chartID,
      name);

   if(!ObjectCreate(
      g_chartID,
      name,
      OBJ_TEXT,
      0,
      g_endTime,
      price))
   {
      Print(
         "CreateLabel ERROR: ",
         name,
         " / ",
         GetLastError());

      return false;
   }

   ObjectSetString(
      g_chartID,
      name,
      OBJPROP_TEXT,
      text);

   ObjectSetString(
      g_chartID,
      name,
      OBJPROP_FONT,
      "Arial");

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_FONTSIZE,
      9);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_COLOR,
      clr);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_LEFT);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_SELECTABLE,
      false);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_SELECTED,
      false);

   ObjectSetInteger(
      g_chartID,
      name,
      OBJPROP_HIDDEN,
      true);

   return true;
}

//==================================================================
// CREATE HANDLE
//==================================================================

bool CreateHandle()
{
   ObjectDelete(
      g_chartID,
      NameHandle());

   datetime handleTime;
   double handlePrice;

   CalculateHandlePosition(
      handleTime,
      handlePrice);

   if(!ObjectCreate(
      g_chartID,
      NameHandle(),
      OBJ_ARROW,
      0,
      handleTime,
      handlePrice))
   {
      Print(
         "CreateHandle ERROR: ",
         GetLastError());

      return false;
   }

   ObjectSetInteger(
      g_chartID,
      NameHandle(),
      OBJPROP_ARROWCODE,
      159);

   ObjectSetInteger(
      g_chartID,
      NameHandle(),
      OBJPROP_COLOR,
      clrGold);

   ObjectSetInteger(
      g_chartID,
      NameHandle(),
      OBJPROP_WIDTH,
      3);

   ObjectSetInteger(
      g_chartID,
      NameHandle(),
      OBJPROP_ANCHOR,
      ANCHOR_TOP);

   // Pre-selected native handle: click-hold-drag, without chart/body hit-test dragging.
   ObjectSetInteger(g_chartID,NameHandle(),OBJPROP_SELECTABLE,true);
   ObjectSetInteger(g_chartID,NameHandle(),OBJPROP_SELECTED,true);
   ObjectSetInteger(g_chartID,NameHandle(),OBJPROP_ZORDER,1000);
   ObjectSetInteger(g_chartID,NameHandle(),OBJPROP_BACK,false);
   ObjectSetInteger(g_chartID,NameHandle(),OBJPROP_HIDDEN,true);
   ObjectSetString(g_chartID,NameHandle(),OBJPROP_TOOLTIP,"Hold and drag vertically: scale SL and all TPs");

   g_handleTime =
      handleTime;

   g_handlePrice =
      handlePrice;

   return true;
}

//==================================================================
// UPDATE HANDLE
//==================================================================

void UpdateHandle()
{
   if(g_nativeHandle==6) return; // Never reposition an object while MT5 drags it.
   if(!g_toolCreated)
      return;

   datetime handleTime;
   double handlePrice;

   CalculateHandlePosition(
      handleTime,
      handlePrice);

   ObjectMove(
      g_chartID,
      NameHandle(),
      0,
      handleTime,
      handlePrice);

   g_handleTime =
      handleTime;

   g_handlePrice =
      handlePrice;
}

//==================================================================
// UPDATE LABEL
//==================================================================

void UpdateLabel(string name,string text,double price,color clr)
{
   // Labels are created once with the tool. No synchronous ObjectFind per frame.
   ObjectMove(g_chartID,name,0,g_endTime,price);
   int index=0;
   if(name==NameLabelEntry()) index=1;
   else if(name==NameLabelTP1()) index=2;
   else if(name==NameLabelTP2()) index=3;
   else if(name==NameLabelTP3()) index=4;
   bool dragging=g_nativeHandle>=0 || g_mouseMode!=MOUSE_NONE;
   if(dragging && !g_forceLabelText) return;
   if(g_cachedLabel[index]!=text) {
      ObjectSetString(g_chartID,name,OBJPROP_TEXT,text);
      g_cachedLabel[index]=text;
   }
}

//==================================================================
// UPDATE ALL OBJECTS
//==================================================================

void UpdateAllObjects(bool force=false)
{
   if(!g_toolCreated)
      return;

   g_renderPending=true;
   ulong now=GetTickCount64();
   bool dragging=g_nativeHandle>=0 || g_mouseMode!=MOUSE_NONE;
   // Coalesce mouse and timer events into at most one visual frame per 16 ms.
   // Keep the dirty flag so the next timer renders the latest state.
   if(!force && dragging && g_lastRenderMS!=0 && now-g_lastRenderMS<16) return;
   g_lastRenderMS=now;
   g_forceLabelText=force || !dragging || g_lastLabelMS==0 || now-g_lastLabelMS>=80;
   if(g_forceLabelText) g_lastLabelMS=now;
   g_renderPending=false;

   //---------------------------------------------------------------
   // SL
   //---------------------------------------------------------------

   ObjectMove(
      g_chartID,
      NameSL(),
      0,
      g_startTime,
      g_sl);

   ObjectMove(
      g_chartID,
      NameSL(),
      1,
      g_endTime,
      g_sl);

   //---------------------------------------------------------------
   // ENTRY
   //---------------------------------------------------------------

   ObjectMove(
      g_chartID,
      NameEntry(),
      0,
      g_startTime,
      g_entry);

   ObjectMove(
      g_chartID,
      NameEntry(),
      1,
      g_endTime,
      g_entry);

   //---------------------------------------------------------------
   // TP1
   //---------------------------------------------------------------

   ObjectMove(
      g_chartID,
      NameTP1(),
      0,
      g_startTime,
      g_tp1);

   ObjectMove(
      g_chartID,
      NameTP1(),
      1,
      g_endTime,
      g_tp1);

   //---------------------------------------------------------------
   // TP2
   //---------------------------------------------------------------

   ObjectMove(
      g_chartID,
      NameTP2(),
      0,
      g_startTime,
      g_tp2);

   ObjectMove(
      g_chartID,
      NameTP2(),
      1,
      g_endTime,
      g_tp2);

   //---------------------------------------------------------------
   // TP3
   //---------------------------------------------------------------

   ObjectMove(
      g_chartID,
      NameTP3(),
      0,
      g_startTime,
      g_tp3);

   ObjectMove(
      g_chartID,
      NameTP3(),
      1,
      g_endTime,
      g_tp3);

   //---------------------------------------------------------------
   // Labels
   //---------------------------------------------------------------

   UpdateLabel(
      NameLabelSL(),
      LevelLabel("SL",g_sl,false),
      g_sl,
      InpSLColor);

   UpdateLabel(
      NameLabelEntry(),
      EntryLabel(),
      g_entry,
      InpEntryColor);

   UpdateLabel(
      NameLabelTP1(),
      LevelLabel("TP1",g_tp1,true),
      g_tp1,
      InpTPColor);

   UpdateLabel(
      NameLabelTP2(),
      LevelLabel("TP2",g_tp2,true),
      g_tp2,
      InpTPColor);

   UpdateLabel(
      NameLabelTP3(),
      LevelLabel("TP3",g_tp3,true),
      g_tp3,
      InpTPColor);

   //---------------------------------------------------------------
   // Handle
   //---------------------------------------------------------------

   UpdateHandle();
   UpdateExtras();

   ChartRedraw(g_chartID);
}

//==================================================================
// CREATE TOOL
//==================================================================

bool CreateToolAt(
   datetime clickedTime, int forcedDirection=-1)
{
   double openPrice;
   double highPrice;
   double lowPrice;
   double closePrice;

   datetime candleTime;

   //---------------------------------------------------------------
   // Read exact candle
   //---------------------------------------------------------------

   if(!GetClickedCandle(
      clickedTime,
      openPrice,
      highPrice,
      lowPrice,
      closePrice,
      candleTime))
   {
      Print("RR ERROR: Cannot read clicked candle.");
      return false;
   }

   //---------------------------------------------------------------
   // V2.6 CANDLE LOGIC
   //
   // GREEN = BUY
   // RED   = SELL
   // DOJI  = NOTHING
   //---------------------------------------------------------------

   if(forcedDirection>=0) g_direction=(ENUM_RR_DIRECTION)forcedDirection;
   else if(InpTradeSide==ENTRY_LONG_ONLY) g_direction=RR_BUY;
   else if(InpTradeSide==ENTRY_SHORT_ONLY) g_direction=RR_SELL;
   else if(closePrice > openPrice)
   {
      g_direction = RR_BUY;
   }
   else
   if(closePrice < openPrice)
   {
      g_direction = RR_SELL;
   }
   else
   {
      Print("RR: Doji selected - no tool.");
      return false;
   }

   //---------------------------------------------------------------
   // ENTRY = CLOSE
   //---------------------------------------------------------------

   g_entry =
      NormalizePrice(closePrice);

   double risk = 0.0;

   //---------------------------------------------------------------
   // BUY
   //---------------------------------------------------------------

   if(g_direction == RR_BUY)
   {
      // Initial SL = candle LOW

      g_sl =
         NormalizePrice(lowPrice);

      risk =
         g_entry -
         g_sl;

      if(risk <= 0.0)
      {
         Print("RR BUY ERROR: invalid risk.");
         return false;
      }

      double minRisk =
         InpMinRiskPoints * _Point;

      if(risk < minRisk)
      {
         risk = minRisk;

         g_sl =
            NormalizePrice(
               g_entry -
               risk);
      }

      // Initial targets

      g_tp1 =
         NormalizePrice(
            g_entry +
            risk * InpRR1);

      g_tp2 =
         NormalizePrice(
            g_entry +
            risk * InpRR2);

      g_tp3 =
         NormalizePrice(
            g_entry +
            risk * InpRR3);
   }
   else
   {
      //------------------------------------------------------------
      // SELL
      //------------------------------------------------------------

      // Initial SL = candle HIGH

      g_sl =
         NormalizePrice(highPrice);

      risk =
         g_sl -
         g_entry;

      if(risk <= 0.0)
      {
         Print("RR SELL ERROR: invalid risk.");
         return false;
      }

      double minRisk =
         InpMinRiskPoints * _Point;

      if(risk < minRisk)
      {
         risk = minRisk;

         g_sl =
            NormalizePrice(
               g_entry +
               risk);
      }

      // Initial targets

      g_tp1 =
         NormalizePrice(
            g_entry -
            risk * InpRR1);

      g_tp2 =
         NormalizePrice(
            g_entry -
            risk * InpRR2);

      g_tp3 =
         NormalizePrice(
            g_entry -
            risk * InpRR3);
   }

   double sign=g_direction==RR_BUY?1.0:-1.0;
   double gap=MinGap();
   g_sl=NormalizePrice(sign*MathMin(sign*g_sl,sign*g_entry-gap));
   risk=MathAbs(g_entry-g_sl);
   g_tp1=NormalizePrice(sign*MathMax(sign*g_entry+risk*InpRR1,sign*g_entry+gap));
   g_tp2=NormalizePrice(sign*MathMax(sign*g_entry+risk*InpRR2,sign*g_tp1+gap));
   g_tp3=NormalizePrice(sign*MathMax(sign*g_entry+risk*InpRR3,sign*g_tp2+gap));

   //---------------------------------------------------------------
   // Width = 10 candles
   //---------------------------------------------------------------

   CalculateToolTimeRange(
      candleTime);

   //---------------------------------------------------------------
   // Remove old objects
   //---------------------------------------------------------------

   DeleteToolObjects();

   //---------------------------------------------------------------
   // Create lines
   //---------------------------------------------------------------

   bool ok = true;

   ok &= CreateLine(
      NameSL(),
      g_sl,
      InpSLColor);

   ok &= CreateLine(
      NameEntry(),
      g_entry,
      InpEntryColor);

   ok &= CreateLine(
      NameTP1(),
      g_tp1,
      InpTPColor);

   ok &= CreateLine(
      NameTP2(),
      g_tp2,
      InpTPColor);

   ok &= CreateLine(
      NameTP3(),
      g_tp3,
      InpTPColor);

   //---------------------------------------------------------------
   // Create labels
   //---------------------------------------------------------------

   ok &= CreateLabel(
      NameLabelSL(),
      LevelLabel("SL",g_sl,false),
      g_sl,
      InpSLColor);

   ok &= CreateLabel(
      NameLabelEntry(),
      EntryLabel(),
      g_entry,
      InpEntryColor);

   ok &= CreateLabel(
      NameLabelTP1(),
      LevelLabel("TP1",g_tp1,true),
      g_tp1,
      InpTPColor);

   ok &= CreateLabel(
      NameLabelTP2(),
      LevelLabel("TP2",g_tp2,true),
      g_tp2,
      InpTPColor);

   ok &= CreateLabel(
      NameLabelTP3(),
      LevelLabel("TP3",g_tp3,true),
      g_tp3,
      InpTPColor);

   //---------------------------------------------------------------
   // Handle
   //---------------------------------------------------------------

   ok &= CreateHandle();

   if(!ok)
   {
      DeleteToolObjects();
      g_toolCreated = false;
      return false;
   }

   //---------------------------------------------------------------
   // ON
   //---------------------------------------------------------------

   g_toolCreated = true;

   UpdateAllObjects();

   //---------------------------------------------------------------
   // Diagnostics
   //---------------------------------------------------------------

   Print(
      "RR TOOL ON | ",
      (g_direction == RR_BUY ? "BUY" : "SELL"),
      " | O=",
      DoubleToString(openPrice,_Digits),
      " H=",
      DoubleToString(highPrice,_Digits),
      " L=",
      DoubleToString(lowPrice,_Digits),
      " C=",
      DoubleToString(closePrice,_Digits),
      " | Entry=",
      DoubleToString(g_entry,_Digits),
      " | SL=",
      DoubleToString(g_sl,_Digits),
      " | TP1=",
      DoubleToString(g_tp1,_Digits),
      " | TP2=",
      DoubleToString(g_tp2,_Digits),
      " | TP3=",
      DoubleToString(g_tp3,_Digits));

   return true;
}

//==================================================================
// GET MOUSE TIME / PRICE
//==================================================================

bool GetMouseTimePrice(
   int x,
   int y,
   datetime &time,
   double &price)
{
   int window = 0;

   return ChartXYToTimePrice(g_chartID,x,y,window,time,price) && window==0;
}

//==================================================================
// SCREEN HIT TEST
//==================================================================

bool IsInsideToolScreen(
   int x,
   int y)
{
   if(!g_toolCreated)
      return false;

   int x1, y1;
   int x2, y2;

   if(!ChartTimePriceToXY(
      g_chartID,
      0,
      g_startTime,
      GetToolTop(),
      x1,
      y1))
   {
      return false;
   }

   if(!ChartTimePriceToXY(
      g_chartID,
      0,
      g_endTime,
      GetToolBottom(),
      x2,
      y2))
   {
      return false;
   }

   int left =
      MathMin(x1,x2);

   int right =
      MathMax(x1,x2);

   int top =
      MathMin(y1,y2);

   int bottom =
      MathMax(y1,y2);

   const int pad = 12;

   return
      (x >= left-pad &&
       x <= right+pad &&
       y >= top-pad &&
       y <= bottom+pad);
}

//==================================================================
// PRICE / TIME HIT TEST
//==================================================================

bool IsInsideToolPrice(
   datetime mouseTime,
   double mousePrice)
{
   if(!g_toolCreated)
      return false;

   if(mouseTime < g_startTime ||
      mouseTime > g_endTime)
   {
      return false;
   }

   double top =
      GetToolTop();

   double bottom =
      GetToolBottom();

   double tolerance =
      10.0 * _Point;

   if(mousePrice <
      bottom - tolerance)
   {
      return false;
   }

   if(mousePrice >
      top + tolerance)
   {
      return false;
   }

   return true;
}

//==================================================================
// HANDLE HIT TEST
//==================================================================

bool IsMouseOnHandle(
   int x,
   int y)
{
   if(!g_toolCreated)
      return false;

   int hx, hy;

   if(!ChartTimePriceToXY(
      g_chartID,
      0,
      g_handleTime,
      g_handlePrice,
      hx,
      hy))
   {
      return false;
   }

   int dx =
      x - hx;

   int dy =
      y - hy;

   const int radius = 18;

   return
      ((dx*dx + dy*dy) <=
       radius*radius);
}

//==================================================================
// START MOVE
//==================================================================

void StartMove(
   int x,
   int y,
   datetime mouseTime,
   double mousePrice)
{
   g_mouseMode =
      MOUSE_MOVE;

   g_movePending =
      false;

   g_resizePending =
      false;

   g_wasDragged =
      true;

   //---------------------------------------------------------------
   // Anchor
   //---------------------------------------------------------------

   g_moveAnchorTime =
      mouseTime;

   g_moveAnchorPrice =
      mousePrice;

   //---------------------------------------------------------------
   // Save original tool
   //---------------------------------------------------------------

   g_moveEntry0 = g_entry;
   g_moveSL0    = g_sl;
   g_moveTP10   = g_tp1;
   g_moveTP20   = g_tp2;
   g_moveTP30   = g_tp3;

   g_moveStartTime0 =
      g_startTime;

   g_moveEndTime0 =
      g_endTime;

   g_dragStartX = x;
   g_dragStartY = y;

   //---------------------------------------------------------------
   // Disable chart scrolling
   //---------------------------------------------------------------

   LockChart();

   g_lastPressTick = 0;
}

//==================================================================
// MOVE
//==================================================================

void MoveTool(
   datetime currentTime,
   double currentPrice)
{
   if(!g_toolCreated ||
      g_mouseMode != MOUSE_MOVE)
   {
      return;
   }

   //---------------------------------------------------------------
   // Price delta
   //---------------------------------------------------------------

   double priceDelta =
      currentPrice -
      g_moveAnchorPrice;

   g_entry =
      NormalizePrice(
         g_moveEntry0 +
         priceDelta);

   g_sl =
      NormalizePrice(
         g_moveSL0 +
         priceDelta);

   g_tp1 =
      NormalizePrice(
         g_moveTP10 +
         priceDelta);

   g_tp2 =
      NormalizePrice(
         g_moveTP20 +
         priceDelta);

   g_tp3 =
      NormalizePrice(
         g_moveTP30 +
         priceDelta);

   //---------------------------------------------------------------
   // Time delta
   //---------------------------------------------------------------

   long timeDelta =
      (long)currentTime -
      (long)g_moveAnchorTime;

   g_startTime =
      (datetime)(
         (long)g_moveStartTime0 +
         timeDelta);

   g_endTime =
      (datetime)(
         (long)g_moveEndTime0 +
         timeDelta);

   UpdateAllObjects();
}

//==================================================================
// START RESIZE
//==================================================================

void StartResize()
{
   g_mouseMode =
      MOUSE_RESIZE;

   g_resizePending =
      false;

   g_movePending =
      false;

   g_wasDragged =
      true;

   //---------------------------------------------------------------
   // Save the handle position when drag starts
   //---------------------------------------------------------------

   g_resizeStartHandlePrice =
      g_handlePrice;

   //---------------------------------------------------------------
   // Disable chart scroll
   //---------------------------------------------------------------

   LockChart();

   g_lastPressTick = 0;
}

//==================================================================
// RESIZE
//==================================================================

void ResizeTool(double mousePrice)
{
   if(!g_toolCreated || g_mouseMode!=MOUSE_RESIZE) return;
   double value=NormalizePrice(g_editPrice0+mousePrice-g_pressPrice);
   double sign=g_direction==RR_BUY?1.0:-1.0;
   double gap=MinGap();
   if(g_editLevel==0) {
      double v=sign*value;
      v=MathMax(sign*g_sl+gap,MathMin(sign*g_tp1-gap,v));
      g_entry=NormalizePrice(sign*v);
   }
   if(g_editLevel==1) g_sl=NormalizePrice(sign*MathMin(sign*value,sign*g_entry-gap));
   if(g_editLevel>=2 && g_editLevel<=4) {
      double base=g_editPrice0-g_entry;
      if(MathAbs(base)<_Point*0.1) return;
      double factor=(value-g_entry)/base;
      factor=MathMax(factor,MinimumTPScale());
      SetScaledTPs(factor);
   }
   if(g_editLevel==6) {
      double base=g_editPrice0-g_entry;
      if(MathAbs(base)<_Point*0.1) return;
      double factor=MathMax((value-g_entry)/base,MinimumTPScale());
      factor=MathMax(factor,gap/MathAbs(g_scaleSL0-g_entry));
      g_sl=NormalizePrice(g_entry+(g_scaleSL0-g_entry)*factor);
      SetScaledTPs(factor);
   }
   UpdateAllObjects();
}

//==================================================================
// STOP DRAG
//==================================================================

void StopDrag()
{
   g_mouseMode =
      MOUSE_NONE;

   g_movePending =
      false;

   g_resizePending =
      false;

   //---------------------------------------------------------------
   // Restore chart
   //---------------------------------------------------------------

   UnlockChart();
   g_editLevel=-1;

   if(g_toolCreated) UpdateAllObjects(true);
   else ChartRedraw(g_chartID);
}

//==================================================================
// DOUBLE CLICK ACTION
//==================================================================

void ExecuteDoubleClick(
   int x,
   int y,
   datetime mouseTime,
   double mousePrice)
{
   //---------------------------------------------------------------
   // Reset click state
   //---------------------------------------------------------------

   g_lastPressTick = 0;
   g_lastPressX = -10000;
   g_lastPressY = -10000;

   //---------------------------------------------------------------
   // Existing tool
   //---------------------------------------------------------------

   if(g_toolCreated)
   {
      bool inside =
         IsInsideToolPrice(
            mouseTime,
            mousePrice);

      if(!inside)
      {
         inside =
            IsInsideToolScreen(
               x,
               y);
      }

      //------------------------------------------------------------
      // INSIDE = OFF
      //------------------------------------------------------------

      if(inside)
      {
         DeleteTool();
         return;
      }

      //------------------------------------------------------------
      // OUTSIDE = NEW TOOL
      //------------------------------------------------------------

      CreateToolAt(mouseTime);
      return;
   }

   //---------------------------------------------------------------
   // No tool = ON
   //---------------------------------------------------------------

   CreateToolAt(mouseTime);
}

//==================================================================
// REGISTER MOUSE PRESS
//==================================================================

bool IsDoubleClick(
   int x,
   int y,
   ulong now)
{
   if(g_lastPressTick == 0)
      return false;

   ulong elapsed =
      now -
      g_lastPressTick;

   int dx =
      MathAbs(
         x -
         g_lastPressX);

   int dy =
      MathAbs(
         y -
         g_lastPressY);

   return
      (elapsed <=
         (ulong)InpDoubleClickMS &&
       dx <=
         InpDoubleClickPixels &&
       dy <=
         InpDoubleClickPixels);
}

// TradingView-inspired presentation; prices use broker tick size.
double MinGap()
{
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) tick=_Point;
   return MathCeil(MathMax(tick,InpMinRiskPoints*_Point)/tick)*tick;
}
double LevelPrice(int level)
{
   if(level==0) return g_entry;
   if(level==1) return g_sl;
   if(level==2) return g_tp1;
   if(level==3) return g_tp2;
   if(level==4) return g_tp3;
   return g_entry;
}
string EntryLabel()
{
   return (g_direction==RR_BUY?"BUY ENTRY ":"SELL ENTRY ")+DoubleToString(g_entry,_Digits);
}
string LevelLabel(string title,double price,bool target)
{
   double distance=MathAbs(price-g_entry),risk=MathAbs(g_entry-g_sl);
   string rr=target && risk>0?" | "+DoubleToString(distance/risk,2)+"R":"";
   double pct=g_entry!=0?distance/MathAbs(g_entry)*100:0;
   return title+" "+DoubleToString(price,_Digits)+" | "+DoubleToString(distance/_Point,0)+" pt | "+DoubleToString(pct,2)+"%"+rr;
}
void LockChart()
{
   if(g_chartLocked) {
      ulong now=GetTickCount64();
      if(g_lastLockCheckMS!=0 && now-g_lastLockCheckMS<100) return;
      g_lastLockCheckMS=now;
      // Another chart tool may have enabled scrolling since the preceding event.
      if(ChartGetInteger(g_chartID,CHART_MOUSE_SCROLL)!=0) {
         ChartSetInteger(g_chartID,CHART_MOUSE_SCROLL,false);
         ChartGetInteger(g_chartID,CHART_MOUSE_SCROLL);
      }
      return;
   }
   g_oldMouseScroll=(bool)ChartGetInteger(g_chartID,CHART_MOUSE_SCROLL);
   if(!ChartSetInteger(g_chartID,CHART_MOUSE_SCROLL,false)) return;
   // Setters are queued. This synchronous getter waits for the lock to apply.
   if(ChartGetInteger(g_chartID,CHART_MOUSE_SCROLL)==0) {g_chartLocked=true;g_lastLockCheckMS=GetTickCount64();}
}
void BeginDragChartLock()
{
   LockChart();
   if(g_dragChartLocked) return;
   g_oldAutoScroll=(bool)ChartGetInteger(g_chartID,CHART_AUTOSCROLL);
   g_oldScaleFix=(bool)ChartGetInteger(g_chartID,CHART_SCALEFIX);
   g_oldFixedMin=ChartGetDouble(g_chartID,CHART_FIXED_MIN);
   g_oldFixedMax=ChartGetDouble(g_chartID,CHART_FIXED_MAX);
   double low=ChartGetDouble(g_chartID,CHART_PRICE_MIN,0);
   double high=ChartGetDouble(g_chartID,CHART_PRICE_MAX,0);
   g_dragChartLocked=true;
   ChartSetInteger(g_chartID,CHART_AUTOSCROLL,false);
   g_scaleWasChanged=false;
   // Special scale modes already fix the vertical scale; leave those modes alone.
   if(!ChartGetInteger(g_chartID,CHART_SCALEFIX_11) &&
      !ChartGetInteger(g_chartID,CHART_SCALE_PT_PER_BAR) && high>low) {
      g_scaleWasChanged=true;
      ChartSetInteger(g_chartID,CHART_SCALEFIX,true);
      ChartSetDouble(g_chartID,CHART_FIXED_MIN,low);
      ChartSetDouble(g_chartID,CHART_FIXED_MAX,high);
   }
   ChartRedraw(g_chartID);
   ChartGetInteger(g_chartID,CHART_MOUSE_SCROLL); // Flush pending chart commands.
}
void UnlockChart()
{
   if(g_dragChartLocked) {
      if(g_scaleWasChanged) {
         ChartSetDouble(g_chartID,CHART_FIXED_MIN,g_oldFixedMin);
         ChartSetDouble(g_chartID,CHART_FIXED_MAX,g_oldFixedMax);
         ChartSetInteger(g_chartID,CHART_SCALEFIX,g_oldScaleFix);
      }
      ChartSetInteger(g_chartID,CHART_AUTOSCROLL,g_oldAutoScroll);
      g_dragChartLocked=false;
      g_scaleWasChanged=false;
   }
   if(g_chartLocked) {
      ChartSetInteger(g_chartID,CHART_MOUSE_SCROLL,g_oldMouseScroll);
      g_chartLocked=false;
   }
   ChartGetInteger(g_chartID,CHART_MOUSE_SCROLL);
}
void RefreshHoverLock(int x,int y)
{
   if(g_toolCreated && (HitLevel(x,y)>=0 || IsInsideToolScreen(x,y))) LockChart();
   else UnlockChart();
}
void Zone(string suffix,double price,color c)
{
   if(!InpShowZones) return;
   string name=Prefix()+suffix;
   bool ready=suffix=="_RISK"?g_riskZoneReady:g_rewardZoneReady;
   if(!ready) {
      if(!ObjectCreate(g_chartID,name,OBJ_RECTANGLE,0,g_startTime,g_entry,g_endTime,price)) return;
      ObjectSetInteger(g_chartID,name,OBJPROP_COLOR,c);
      ObjectSetInteger(g_chartID,name,OBJPROP_FILL,true);
      ObjectSetInteger(g_chartID,name,OBJPROP_BACK,true);
      ObjectSetInteger(g_chartID,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(g_chartID,name,OBJPROP_HIDDEN,true);
      if(suffix=="_RISK") g_riskZoneReady=true;else g_rewardZoneReady=true;
   }
   ObjectMove(g_chartID,name,0,g_startTime,g_entry);
   ObjectMove(g_chartID,name,1,g_endTime,price);
}
void UpdateExtras()
{
   Zone("_RISK",g_sl,InpRiskZoneColor);
   Zone("_REWARD",g_tp3,InpRewardZoneColor);
   string name=Prefix()+"_WIDTH_HANDLE";
   double center=(GetToolTop()+GetToolBottom())/2.0;
   if(!g_widthHandleReady) {
      if(!ObjectCreate(g_chartID,name,OBJ_ARROW,0,g_endTime,center)) return;
      ObjectSetInteger(g_chartID,name,OBJPROP_ARROWCODE,159);
      ObjectSetInteger(g_chartID,name,OBJPROP_ANCHOR,ANCHOR_TOP);
      ObjectSetInteger(g_chartID,name,OBJPROP_WIDTH,3);
      ObjectSetInteger(g_chartID,name,OBJPROP_COLOR,InpHandleColor);
      ObjectSetInteger(g_chartID,name,OBJPROP_SELECTABLE,true);
      ObjectSetInteger(g_chartID,name,OBJPROP_SELECTED,true);
      ObjectSetInteger(g_chartID,name,OBJPROP_ZORDER,1000);
      ObjectSetInteger(g_chartID,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(g_chartID,name,OBJPROP_BACK,false);
      ObjectSetString(g_chartID,name,OBJPROP_TOOLTIP,"Hold and drag horizontally to resize width");
      g_widthHandleReady=true;
   }
   // Do not touch active native handle coordinates or its selection while dragging.
   if(g_nativeHandle!=5) ObjectMove(g_chartID,name,0,g_endTime,center);
}
bool IsMouseOnWidthHandle(int x,int y)
{
   if(!g_toolCreated) return false;
   int hx,hy;
   if(!ChartTimePriceToXY(g_chartID,0,g_endTime,(GetToolTop()+GetToolBottom())/2.0,hx,hy)) return false;
   int dx=x-hx,dy=y-hy;
   return dx*dx+dy*dy<=324;
}

int HitLevel(int x,int y)
{
   if(IsMouseOnHandle(x,y)) return 6;
   if(IsMouseOnWidthHandle(x,y)) return 5;
   int left,unused,right;
   if(!ChartTimePriceToXY(g_chartID,0,g_startTime,g_entry,left,unused) ||
      !ChartTimePriceToXY(g_chartID,0,g_endTime,g_entry,right,unused)) return -1;
   if(x<MathMin(left,right)-InpHitPixels || x>MathMax(left,right)+InpHitPixels) return -1;
   int best=-1,dist=InpHitPixels+1;
   for(int i=0;i<5;i++) {
      int px,py;
      if(!ChartTimePriceToXY(g_chartID,0,g_startTime,LevelPrice(i),px,py)) continue;
      int d=(int)MathAbs(y-py);
      if(d<dist) {best=i;dist=d;}
   }
   if(best>=0) return best;

   return -1;
}
void EditTool(datetime time,double price,int x)
{
   if(g_editLevel==5) {
      datetime horizontalTime;double unusedPrice;
      if(!GetMouseTimePrice(x,g_widthStartY,horizontalTime,unusedPrice)) return;
      time=horizontalTime;
      g_endTime=(datetime)MathMax((double)(g_startTime+PeriodSeconds(_Period)),
                                (double)((long)g_editEnd0+(long)time-(long)g_pressTime));
      UpdateAllObjects(); return;
   }
   ResizeTool(price);
}

// Snapshots keep TP proportions stable across every mouse event.
double MinimumTPScale()
{
   double gap=MinGap();
   return MathMax(gap/MathAbs(g_scaleTP10-g_entry),
          MathMax(gap/MathAbs(g_scaleTP20-g_scaleTP10),gap/MathAbs(g_scaleTP30-g_scaleTP20)));
}
void SetScaledTPs(double factor)
{
   double sign=g_direction==RR_BUY?1.0:-1.0, gap=MinGap();
   g_tp1=NormalizePrice(g_entry+(g_scaleTP10-g_entry)*factor);
   g_tp2=NormalizePrice(sign*MathMax(sign*(g_entry+(g_scaleTP20-g_entry)*factor),sign*g_tp1+gap));
   g_tp3=NormalizePrice(sign*MathMax(sign*(g_entry+(g_scaleTP30-g_entry)*factor),sign*g_tp2+gap));
}
void ProcessEMA()
{
   if(!InpAutoEMA) return;
   datetime current=iTime(_Symbol,_Period,0);
   if(current==0 || current==g_lastEMABar) return;
   if(g_lastEMABar==0) {g_lastEMABar=current;return;}
   if(BarsCalculated(g_fastEMAHandle)<InpSlowEMA+2 || BarsCalculated(g_slowEMAHandle)<InpSlowEMA+2) return;
   double fast[2],slow[2];
   // CopyBuffer stores the older closed candle first: [0]=shift 2, [1]=shift 1.
   if(CopyBuffer(g_fastEMAHandle,0,1,2,fast)!=2 || CopyBuffer(g_slowEMAHandle,0,1,2,slow)!=2) return;
   if(fast[0]==EMPTY_VALUE || fast[1]==EMPTY_VALUE || slow[0]==EMPTY_VALUE || slow[1]==EMPTY_VALUE) return;
   g_lastEMABar=current;
   if(g_leftButtonDown || g_dragChartLocked || g_nativeHandle>=0) return; // Do not overwrite an active drag.
   bool buy=fast[0]<=slow[0] && fast[1]>slow[1];
   bool sell=fast[0]>=slow[0] && fast[1]<slow[1];
   if(buy && InpTradeSide!=ENTRY_SHORT_ONLY) CreateToolAt(iTime(_Symbol,_Period,1),RR_BUY);
   else if(sell && InpTradeSide!=ENTRY_LONG_ONLY) CreateToolAt(iTime(_Symbol,_Period,1),RR_SELL);
}

// Native dragging reads the actual object coordinates, not a second custom
// mouse transform. This also handles terminals that deliver only OBJECT_DRAG.
void BeginNativeHandle(int kind)
{
   if(g_nativeHandle==kind) return;
   g_nativeHandle=kind;g_nativeChanged=false;g_lastNativePollMS=0;
   g_scaleSL0=g_sl;g_scaleTP10=g_tp1;g_scaleTP20=g_tp2;g_scaleTP30=g_tp3;
   g_nativeBasePrice=GetToolBottom();
   g_nativeLastPrice=g_nativeBasePrice;g_nativeLastTime=g_endTime;
   g_movePending=false;g_resizePending=false;g_mouseMode=MOUSE_NONE;
   g_lastPressTick=0;
   BeginDragChartLock();
}
void PollNativeHandle(bool finalUpdate=false)
{
   if(!g_toolCreated || g_nativeHandle<0) return;
   ulong now=GetTickCount64();
   if(!finalUpdate && g_lastNativePollMS!=0 && now-g_lastNativePollMS<16) return;
   g_lastNativePollMS=now;
   double oldSL=g_sl,oldTP1=g_tp1,oldTP2=g_tp2,oldTP3=g_tp3;
   datetime oldEnd=g_endTime;
   string name=g_nativeHandle==6?NameHandle():Prefix()+"_WIDTH_HANDLE";
   if(g_nativeHandle==5) {
      datetime t=(datetime)ObjectGetInteger(g_chartID,name,OBJPROP_TIME,0);
      if(t==g_nativeLastTime) return;
      g_nativeLastTime=t;
      g_endTime=(datetime)MathMax((double)(g_startTime+MathMax(1,PeriodSeconds(_Period))),(double)t);
   } else {
      double price=ObjectGetDouble(g_chartID,name,OBJPROP_PRICE,0);
      if(MathAbs(price-g_nativeLastPrice)<_Point*0.01) return;
      g_nativeLastPrice=price;
      double base=g_nativeBasePrice-g_entry;
      if(MathAbs(base)<_Point*0.1) return;
      double factor=MathMax((price-g_entry)/base,MinimumTPScale());
      factor=MathMax(factor,MinGap()/MathAbs(g_scaleSL0-g_entry));
      g_sl=NormalizePrice(g_entry+(g_scaleSL0-g_entry)*factor);
      SetScaledTPs(factor);
   }
   if(oldEnd==g_endTime && oldSL==g_sl && oldTP1==g_tp1 && oldTP2==g_tp2 && oldTP3==g_tp3) return;
   g_nativeChanged=true;
   UpdateAllObjects(); // Active handle is intentionally not moved by this update.
}
void FinishNativeHandle()
{
   PollNativeHandle(true);
   g_nativeHandle=-1;
   StopDrag();
   g_leftButtonDown=false;g_lastPressTick=0;
   if(g_toolCreated) UpdateAllObjects(true); // Snap gold to bottom center, white to right center.
}
void OnTimer()
{
   if(!g_toolCreated) return;
   if(g_nativeHandle>=0) {
      PollNativeHandle();
      if(g_renderPending) UpdateAllObjects();
      return;
   }
   if(g_renderPending) UpdateAllObjects();
   if(g_leftButtonDown || g_mouseMode!=MOUSE_NONE) return;
   // Keep native-event fallback, but only poll idle objects at 10 Hz.
   ulong now=GetTickCount64();
   if(g_lastIdlePollMS!=0 && now-g_lastIdlePollMS<100) return;
   g_lastIdlePollMS=now;
   double price=ObjectGetDouble(g_chartID,NameHandle(),OBJPROP_PRICE,0);
   datetime t=(datetime)ObjectGetInteger(g_chartID,Prefix()+"_WIDTH_HANDLE",OBJPROP_TIME,0);
   if(MathAbs(price-GetToolBottom())>_Point*0.01) {BeginNativeHandle(6);PollNativeHandle();}
   else if(t!=g_endTime) {BeginNativeHandle(5);PollNativeHandle();}
}

//==================================================================
// INIT
//==================================================================

int OnInit()
{
   g_chartID =
      ChartID();

   g_oldMouseEvents=(bool)ChartGetInteger(g_chartID,CHART_EVENT_MOUSE_MOVE);
   g_prefix="RR_TOOL_"+IntegerToString(g_chartID)+"_"+IntegerToString((long)GetMicrosecondCount());
   if(InpWidthBars<1 || InpMinRiskPoints<=0 || InpRR1<=0 ||
      InpRR2<=InpRR1 || InpRR3<=InpRR2 || InpDragThreshold<1 ||
      InpHitPixels<1 || InpDoubleClickMS<1 || InpDoubleClickPixels<1 ||
      InpLineWidth<1 || InpLineWidth>5 || InpFastEMA<1 || InpSlowEMA<=InpFastEMA) return INIT_PARAMETERS_INCORRECT;
   if(InpAutoEMA) {
      g_fastEMAHandle=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
      g_slowEMAHandle=iMA(_Symbol,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
      if(g_fastEMAHandle==INVALID_HANDLE || g_slowEMAHandle==INVALID_HANDLE) {
         if(g_fastEMAHandle!=INVALID_HANDLE) IndicatorRelease(g_fastEMAHandle);
         if(g_slowEMAHandle!=INVALID_HANDLE) IndicatorRelease(g_slowEMAHandle);
         return INIT_FAILED;
      }
      g_lastEMABar=iTime(_Symbol,_Period,0);
   }
   g_oldMouseEvents=(bool)ChartGetInteger(g_chartID,CHART_EVENT_MOUSE_MOVE);
   //---------------------------------------------------------------
   // Save chart settings
   //---------------------------------------------------------------

   g_oldMouseScroll =
      (bool)ChartGetInteger(
         g_chartID,
         CHART_MOUSE_SCROLL);

   g_oldAutoScroll =
      (bool)ChartGetInteger(
         g_chartID,
         CHART_AUTOSCROLL);

   //---------------------------------------------------------------
   // Enable mouse events
   //---------------------------------------------------------------

   if(!ChartSetInteger(
      g_chartID,
      CHART_EVENT_MOUSE_MOVE,
      true))
   {
      Print(
         "ERROR enabling CHART_EVENT_MOUSE_MOVE: ",
         GetLastError());

      return INIT_FAILED;
   }

   Print(
      "RR Calculator V3.22 initialized.");

   if(!EventSetMillisecondTimer(16)) return INIT_FAILED;
   return INIT_SUCCEEDED;
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
   ProcessEMA(); // Closed candles only; visual setup, no order execution.

   return rates_total;
}

//==================================================================
// DEINIT
//==================================================================

void OnDeinit(
   const int reason)
{
   EventKillTimer();
   g_nativeHandle=-1;
   StopDrag();
   if(g_fastEMAHandle!=INVALID_HANDLE) IndicatorRelease(g_fastEMAHandle);
   if(g_slowEMAHandle!=INVALID_HANDLE) IndicatorRelease(g_slowEMAHandle);

   DeleteToolObjects();
   ChartSetInteger(g_chartID,CHART_EVENT_MOUSE_MOVE,g_oldMouseEvents);

   Print(
      "RR Calculator V3.22 removed.");
}

//==================================================================
// CHART EVENT
//==================================================================

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if((id==CHARTEVENT_OBJECT_DRAG || id==CHARTEVENT_OBJECT_CHANGE) && g_toolCreated &&
      (sparam==NameHandle() || sparam==Prefix()+"_WIDTH_HANDLE")) {
      if(g_nativeHandle<0) BeginNativeHandle(sparam==NameHandle()?6:5);
      FinishNativeHandle();return;
   }
   if(id==CHARTEVENT_OBJECT_CLICK && g_toolCreated &&
      (sparam==NameHandle() || sparam==Prefix()+"_WIDTH_HANDLE")) {
      ObjectSetInteger(g_chartID,sparam,OBJPROP_SELECTED,true);
      g_lastPressTick=0;return;
   }
   if(id==CHARTEVENT_CHART_CHANGE) {
      if(g_toolCreated && g_nativeHandle<0) UpdateAllObjects();
      return;
   }
   if(id==CHARTEVENT_KEYDOWN && lparam==27) {
      g_nativeHandle=-1;StopDrag();g_leftButtonDown=false;g_lastPressTick=0;
      if(g_toolCreated) UpdateAllObjects();return;
   }
   if(id==CHARTEVENT_KEYDOWN && lparam==46) {
      DeleteTool();g_leftButtonDown=false;return;
   }
   if(id!=CHARTEVENT_MOUSE_MOVE) return;
   int x=(int)lparam,y=(int)dparam;
   bool leftButton=(((uint)StringToInteger(sparam)&1)!=0);
   if(!leftButton) {
      if(g_nativeHandle>=0) FinishNativeHandle();
      if(g_leftButtonDown) {
         bool dragged=g_mouseMode!=MOUSE_NONE;
         StopDrag();
         if(dragged) g_lastPressTick=0;
      }
      g_leftButtonDown=false;
      // Lock on hover, before the next mouse-down starts native chart dragging.
      RefreshHoverLock(x,y);
      return;
   }
   if(g_nativeHandle>=0) {LockChart();PollNativeHandle();return;}
   datetime mouseTime;double mousePrice;
   if(!GetMouseTimePrice(x,y,mouseTime,mousePrice)) return;
   if(!g_leftButtonDown) {
      g_leftButtonDown=true;
      int hit=g_toolCreated?HitLevel(x,y):-1;
      bool handle=(hit==5 || hit==6);
      if(handle) {BeginNativeHandle(hit);return;}
      ulong now=GetTickCount64();
      if(!handle && IsDoubleClick(x,y,now)) {
         ExecuteDoubleClick(x,y,mouseTime,mousePrice);return;
      }
      g_lastPressTick=handle?0:now;
      g_lastPressX=x;g_lastPressY=y;
      if(!g_toolCreated) return;
      g_editLevel=hit;
      if(hit>=0) {
         BeginDragChartLock();
         // Re-read after scale lock; anchor and later drag use the same transform.
         if(!GetMouseTimePrice(x,y,mouseTime,mousePrice)) {StopDrag();return;}
         g_resizePending=true;g_movePending=false;
         g_dragStartX=x;g_dragStartY=y;
         g_widthStartY=y;
         g_pressPrice=mousePrice;g_pressTime=mouseTime;
         g_editEnd0=g_endTime;
         g_editPrice0=hit==6?GetToolBottom():LevelPrice(hit);
         g_scaleSL0=g_sl;g_scaleTP10=g_tp1;g_scaleTP20=g_tp2;g_scaleTP30=g_tp3;
         return;
      }
      if(IsInsideToolScreen(x,y)) {
         BeginDragChartLock();
         if(!GetMouseTimePrice(x,y,mouseTime,mousePrice)) {StopDrag();return;}
         g_movePending=true;g_resizePending=false;
         g_dragStartX=x;g_dragStartY=y;
         g_moveAnchorTime=mouseTime;g_moveAnchorPrice=mousePrice;
      }
      return;
   }
   int dx=(int)MathAbs(x-g_dragStartX),dy=(int)MathAbs(y-g_dragStartY);
   if(g_resizePending && g_mouseMode==MOUSE_NONE) {
      bool threshold=g_editLevel==5?dx>=InpDragThreshold:(dx>=InpDragThreshold || dy>=InpDragThreshold);
      if(threshold) {StartResize();EditTool(mouseTime,mousePrice,x);}
      return;
   }
   if(g_mouseMode==MOUSE_RESIZE) {EditTool(mouseTime,mousePrice,x);return;}
   if(g_movePending && g_mouseMode==MOUSE_NONE) {
      if(dx>=InpDragThreshold || dy>=InpDragThreshold) {
         StartMove(g_dragStartX,g_dragStartY,g_moveAnchorTime,g_moveAnchorPrice);
         MoveTool(mouseTime,mousePrice);
      }
      return;
   }
   if(g_mouseMode==MOUSE_MOVE) MoveTool(mouseTime,mousePrice);
}
//+------------------------------------------------------------------+
