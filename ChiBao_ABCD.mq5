//+------------------------------------------------------------------+
//|                                             ChiBao_ABCD.mq5      |
//|                    ABCD Nearest Swing -> D Projection            |
//|                                      Version 1.8               |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0
#property version            "1.8"
#property description       "Nearest Confirmed A-B-C -> D Projection + RSI/CCI/WPR Confirmation"

//==================================================================
// INPUTS
//==================================================================

input group "=== ABCD CORE ==="
input int      InpPivotLength      = 5;
input int      InpLookbackBars     = 500;
input double   InpMinABPoints      = 0.0;
input bool     InpUseFibFilter     = false;
input double   InpBCFibMin         = 0.382;
input double   InpBCFibMax         = 0.886;
input double   InpDTargetRatio     = 1.000;
input double   InpDZoneMin         = 0.786;
input double   InpDZoneMax         = 1.618;

input group "=== TIME PROJECTION ==="
input bool     InpProjectTimeByAB  = true;

input group "=== DISPLAY ==="
input bool     InpShowAB            = true;
input bool     InpShowBC            = true;
input bool     InpShowDProjection   = true;
input bool     InpShowDZone         = true;
input bool     InpShowDashboard     = true;
input int      InpLineWidth         = 1;
input color    InpABColor           = clrDodgerBlue;
input color    InpBCColor           = clrOrange;
input color    InpBuyColor          = clrLimeGreen;
input color    InpSellColor         = clrTomato;
input color    InpZoneColor         = clrSilver;

input group "=== SIGNAL v1.8 ==="
input bool     InpUseClosedBarConfirmation = true;
input bool     InpOneSignalPerC            = true;
input bool     InpUseDMinDistance          = true;
input double   InpDMinDistanceAB           = 0.20;
input bool     InpUseDStability             = true;
input double   InpDMaxChangeAB              = 1.00;

input group "=== RSI / CCI / WPR CONFIRMATION v1.8 ==="
input bool     InpUseMomentumConfirmation = true;

input int      InpRSIPeriod    = 14;
input double   InpRSIBuyLevel  = 50.0;
input double   InpRSISellLevel = 50.0;

input int      InpCCIPeriod    = 14;
input double   InpCCIBuyLevel  = 0.0;
input double   InpCCISellLevel = 0.0;

input int      InpWPRPeriod    = 14;
input double   InpWPRBuyLevel  = -50.0;
input double   InpWPRSellLevel = -50.0;

input int      InpMinConfirmScore = 2;

input group "=== DIAGNOSTIC v1.8 ==="
input bool     InpEnableDiagnosticLog = true;

input group "=== ALERT ==="
input bool     InpEnableAlert = true;
input bool     InpEnablePush  = false;

input group "=== BUTTON ==="
input bool     InpStartEnabled = true;
input int      InpButtonX      = 10;
input int      InpButtonY      = 150;
input int      InpButtonWidth  = 90;
input int      InpButtonHeight = 24;

//==================================================================
// CONSTANTS
//==================================================================

#define PREFIX       "ChiBaoABCD18_"
#define BUTTON_NAME  "ChiBaoABCD18_Button"

#define OBJ_AB       PREFIX "AB"
#define OBJ_BC       PREFIX "BC"
#define OBJ_CD       PREFIX "CD"
#define OBJ_DTARGET  PREFIX "D_Target"
#define OBJ_DZONE_L  PREFIX "D_ZoneLow"
#define OBJ_DZONE_H  PREFIX "D_ZoneHigh"
#define OBJ_DARROW   PREFIX "D_Arrow"
#define OBJ_DTEXT    PREFIX "D_Text"
#define OBJ_PANEL    PREFIX "Dashboard"

#define MAX_PIVOTS 200

//==================================================================
// STRUCTURES
//==================================================================

struct PivotPoint
{
   datetime time;
   double   price;
   bool     isHigh;
};

struct ABCPattern
{
   bool valid;

   PivotPoint A;
   PivotPoint B;
   PivotPoint C;

   bool bullish;

   double AB;
   double BC;
   double BCFib;

   double DTarget;
   double DZoneLow;
   double DZoneHigh;

   datetime DTime;
};

//==================================================================
// GLOBALS
//==================================================================

bool g_Enabled = true;

PivotPoint g_Pivots[MAX_PIVOTS];
int g_PivotCount = 0;

ABCPattern g_Pattern;

datetime g_LastAlertC       = 0;
datetime g_LastProcessedBar = 0;
datetime g_LastDiagnosticC  = 0;

double   g_LastAcceptedD  = 0.0;
double   g_LastAcceptedAB = 0.0;
datetime g_LastAcceptedC   = 0;

//------------------------------------------------------------------
// Momentum handles
//------------------------------------------------------------------

int g_RSIHandle = INVALID_HANDLE;
int g_CCIHandle = INVALID_HANDLE;
int g_WPRHandle = INVALID_HANDLE;

//------------------------------------------------------------------
// Current momentum values
//------------------------------------------------------------------

double g_RSI = 0.0;
double g_CCI = 0.0;
double g_WPR = 0.0;

bool g_RSIValid = false;
bool g_CCIValid = false;
bool g_WPRValid = false;

bool g_RSIConfirm = false;
bool g_CCIConfirm = false;
bool g_WPRConfirm = false;

int  g_ConfirmScore = 0;
int  g_ValidMomentumCount = 0;

bool g_MomentumDataReady = false;
bool g_MomentumPass      = false;

//------------------------------------------------------------------
// Separate ABCD confirmation from momentum confirmation
//------------------------------------------------------------------

bool     g_MomentumConfirmed   = false;
datetime g_MomentumConfirmTime = 0;
datetime g_MomentumConfirmC    = 0;

//==================================================================
// FORWARD DECLARATIONS
//==================================================================

void DeleteSignalObjects();
void DeleteDashboard();

bool BuildPivots(
   const double &high[],
   const double &low[],
   const datetime &time[],
   int rates_total
);

bool AddPivot(PivotPoint &p);
bool FindNearestConfirmedABC();
bool CalculateDProjection();

bool PassDProjectionFilters(
   const double &close[],
   int rates_total
);

bool IsNewClosedBar(const datetime &time[]);

void RegisterAcceptedProjection();

bool GetMomentumConfirmation();
bool PassMomentumConfirmation();

void ResetMomentumConfirmation(datetime cTime);

void LogDiagnostic(
   const double &close[],
   int rates_total
);

void DrawPattern();
void DrawProjection();

void CreateButton();
void UpdateButton();

void UpdateDashboard();
void ClearAllSignals();

datetime AddSecondsSafe(
   datetime baseTime,
   long seconds
);

bool CreateTrendObject(
   string name,
   datetime t1,
   double p1,
   datetime t2,
   double p2,
   color clr,
   int width,
   ENUM_LINE_STYLE style
);

bool CreateHLineObject(
   string name,
   double price,
   color clr,
   int width,
   ENUM_LINE_STYLE style
);

bool CreateArrowObject(
   string name,
   datetime t,
   double price,
   color clr,
   int code
);

bool CreateTextObject(
   string name,
   datetime t,
   double price,
   string text,
   color clr
);

string FormatPrice(double price);
string FormatDateTime(datetime t);

//==================================================================
// INIT
//==================================================================

int OnInit()
{
   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "ABCD v1.8"
   );

   g_Enabled = InpStartEnabled;

   ZeroMemory(g_Pattern);

   g_LastAlertC       = 0;
   g_LastProcessedBar = 0;
   g_LastDiagnosticC  = 0;

   g_LastAcceptedD  = 0.0;
   g_LastAcceptedAB = 0.0;
   g_LastAcceptedC  = 0;

   g_MomentumConfirmed   = false;
   g_MomentumConfirmTime = 0;
   g_MomentumConfirmC    = 0;

   g_RSIHandle = iRSI(
      _Symbol,
      _Period,
      InpRSIPeriod,
      PRICE_CLOSE
   );

   if(g_RSIHandle == INVALID_HANDLE)
   {
      Print(
         "ABCD v1.8 | ERROR: RSI handle"
      );

      return(INIT_FAILED);
   }

   g_CCIHandle = iCCI(
      _Symbol,
      _Period,
      InpCCIPeriod,
      PRICE_TYPICAL
   );

   if(g_CCIHandle == INVALID_HANDLE)
   {
      Print(
         "ABCD v1.8 | ERROR: CCI handle"
      );

      return(INIT_FAILED);
   }

   g_WPRHandle = iWPR(
      _Symbol,
      _Period,
      InpWPRPeriod
   );

   if(g_WPRHandle == INVALID_HANDLE)
   {
      Print(
         "ABCD v1.8 | ERROR: WPR handle"
      );

      return(INIT_FAILED);
   }

   CreateButton();
   UpdateButton();

   if(InpShowDashboard)
      UpdateDashboard();

   ChartRedraw();

   return(INIT_SUCCEEDED);
}

//==================================================================
// DEINIT
//==================================================================

void OnDeinit(const int reason)
{
   DeleteSignalObjects();
   DeleteDashboard();

   ObjectDelete(
      0,
      BUTTON_NAME
   );

   if(g_RSIHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_RSIHandle);
      g_RSIHandle = INVALID_HANDLE;
   }

   if(g_CCIHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_CCIHandle);
      g_CCIHandle = INVALID_HANDLE;
   }

   if(g_WPRHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_WPRHandle);
      g_WPRHandle = INVALID_HANDLE;
   }

   ChartRedraw();
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
   if(rates_total <= InpPivotLength * 2 + 10)
      return(rates_total);

   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);

   CreateButton();
   UpdateButton();

   if(!g_Enabled)
   {
      ClearAllSignals();

      if(InpShowDashboard)
         UpdateDashboard();

      ChartRedraw();

      return(rates_total);
   }

   //===============================================================
   // Closed-bar processing
   //===============================================================

   if(InpUseClosedBarConfirmation)
   {
      if(!IsNewClosedBar(time))
         return(rates_total);
   }

   //===============================================================
   // Rebuild ABCD
   //===============================================================

   DeleteSignalObjects();

   g_Pattern.valid = false;
   g_PivotCount = 0;

   g_RSIValid = false;
   g_CCIValid = false;
   g_WPRValid = false;

   g_RSIConfirm = false;
   g_CCIConfirm = false;
   g_WPRConfirm = false;

   g_ConfirmScore = 0;
   g_ValidMomentumCount = 0;

   g_MomentumDataReady = false;
   g_MomentumPass = false;

   if(!BuildPivots(
         high,
         low,
         time,
         rates_total))
   {
      if(InpShowDashboard)
         UpdateDashboard();

      ChartRedraw();

      return(rates_total);
   }

   if(!FindNearestConfirmedABC())
   {
      if(InpShowDashboard)
         UpdateDashboard();

      ChartRedraw();

      return(rates_total);
   }

   if(!CalculateDProjection())
   {
      if(InpShowDashboard)
         UpdateDashboard();

      ChartRedraw();

      return(rates_total);
   }

   //===============================================================
   // New C detection
   //===============================================================

   bool isNewC =
      (
         g_Pattern.valid &&
         g_Pattern.C.time != g_LastDiagnosticC
      );

   if(isNewC)
   {
      ResetMomentumConfirmation(
         g_Pattern.C.time
      );

      if(InpEnableDiagnosticLog)
      {
         LogDiagnostic(
            close,
            rates_total
         );
      }

      // IMPORTANT:
      // Update this even if diagnostic logging is disabled.
      g_LastDiagnosticC =
         g_Pattern.C.time;
   }

   //===============================================================
   // Momentum from CLOSED BAR [1]
   //===============================================================

   GetMomentumConfirmation();

   //===============================================================
   // Draw pattern
   //===============================================================

   DrawPattern();

   if(InpShowDProjection)
      DrawProjection();

   //===============================================================
   // D filter
   //===============================================================

   bool passDFilter =
      PassDProjectionFilters(
         close,
         rates_total
      );

   //===============================================================
   // Momentum filter
   //===============================================================

   bool passMomentum =
      PassMomentumConfirmation();

   g_MomentumPass =
      passMomentum;

   //===============================================================
   // WAIT -> MOMENTUM CONFIRMED
   //===============================================================

   bool momentumConfirmedNow = false;

   if(
      InpUseMomentumConfirmation &&
      g_Pattern.valid &&
      passMomentum &&
      g_MomentumConfirmC == g_Pattern.C.time &&
      !g_MomentumConfirmed
   )
   {
      g_MomentumConfirmed   = true;
      g_MomentumConfirmTime = time[0];

      momentumConfirmedNow = true;

      if(InpEnableDiagnosticLog)
      {
         Print(
            "ABCD v1.8 | MOMENTUM CONFIRMED LATER"
         );

         Print(
            "C CONFIRMED : ",
            FormatDateTime(
               g_Pattern.C.time
            )
         );

         Print(
            "MOMENTUM    : ",
            FormatDateTime(
               g_MomentumConfirmTime
            ),
            " | Score=",
            IntegerToString(
               g_ConfirmScore
            ),
            "/3"
         );

         Print(
            "SIGNAL      : ",
            passDFilter
            ? "READY"
            : "WAIT | D-FILTER REJECT"
         );
      }
   }

   //===============================================================
   // Momentum filter OFF
   //===============================================================

   if(!InpUseMomentumConfirmation)
   {
      if(
         g_Pattern.valid &&
         g_MomentumConfirmC != g_Pattern.C.time
      )
      {
         g_MomentumConfirmC    = g_Pattern.C.time;
         g_MomentumConfirmed   = true;
         g_MomentumConfirmTime = time[0];

         momentumConfirmedNow = true;
      }
   }

   //===============================================================
   // ALERT
   //===============================================================

   if(
      InpEnableAlert &&
      g_Pattern.valid &&
      passDFilter &&
      passMomentum &&
      momentumConfirmedNow
   )
   {
      bool allowSignal = true;

      if(InpOneSignalPerC)
      {
         if(g_Pattern.C.time == g_LastAlertC)
            allowSignal = false;
      }

      if(allowSignal)
      {
         string direction =
            g_Pattern.bullish
            ? "BUY"
            : "SELL";

         string msg =
            "ABCD v1.8 | " +
            direction +
            " | C=" +
            FormatDateTime(
               g_Pattern.C.time
            ) +
            " | Momentum CONFIRMED=" +
            IntegerToString(
               g_ConfirmScore
            ) +
            "/3 at " +
            FormatDateTime(
               g_MomentumConfirmTime
            ) +
            " | D=" +
            FormatPrice(
               g_Pattern.DTarget
            );

         Alert(msg);

         if(InpEnablePush)
            SendNotification(msg);

         g_LastAlertC =
            g_Pattern.C.time;

         RegisterAcceptedProjection();
      }
   }

   //===============================================================
   // Dashboard
   //===============================================================

   if(InpShowDashboard)
      UpdateDashboard();

   ChartRedraw();

   return(rates_total);
}

//==================================================================
// CHART EVENT
//==================================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam)
{
   if(
      id == CHARTEVENT_OBJECT_CLICK &&
      sparam == BUTTON_NAME
   )
   {
      g_Enabled = !g_Enabled;

      UpdateButton();

      if(!g_Enabled)
      {
         ClearAllSignals();
      }
      else
      {
         g_PivotCount = 0;
         g_Pattern.valid = false;
         g_LastProcessedBar = 0;
         g_LastDiagnosticC = 0;

         g_MomentumConfirmed   = false;
         g_MomentumConfirmTime = 0;
         g_MomentumConfirmC    = 0;
      }

      if(InpShowDashboard)
         UpdateDashboard();

      ChartRedraw();
   }
}

//==================================================================
// NEW CLOSED BAR
//==================================================================

bool IsNewClosedBar(
   const datetime &time[])
{
   if(time[0] <= 0)
      return(false);

   if(g_LastProcessedBar == 0)
   {
      g_LastProcessedBar = time[0];
      return(true);
   }

   if(time[0] != g_LastProcessedBar)
   {
      g_LastProcessedBar = time[0];
      return(true);
   }

   return(false);
}

//==================================================================
// BUILD PIVOTS
//==================================================================

bool BuildPivots(
   const double &high[],
   const double &low[],
   const datetime &time[],
   int rates_total)
{
   g_PivotCount = 0;

   int L =
      MathMax(
         2,
         InpPivotLength
      );

   int maxBars =
      MathMin(
         rates_total - L - 1,
         InpLookbackBars
      );

   if(maxBars <= L + 1)
      return(false);

   for(
      int i=maxBars;
      i>=L+1;
      i--)
   {
      bool isHigh = true;
      bool isLow  = true;

      for(int j=1; j<=L; j++)
      {
         if(i+j < rates_total)
         {
            if(high[i] <= high[i+j])
               isHigh = false;

            if(low[i] >= low[i+j])
               isLow = false;
         }

         int newerIndex =
            i-j;

         // Bar 0 is NEVER used to confirm a pivot.
         if(newerIndex >= 1)
         {
            if(high[i] <= high[newerIndex])
               isHigh = false;

            if(low[i] >= low[newerIndex])
               isLow = false;
         }
         else
         {
            isHigh = false;
            isLow = false;
         }
      }

      if(isHigh)
      {
         PivotPoint p;

         p.time   = time[i];
         p.price  = high[i];
         p.isHigh = true;

         AddPivot(p);
      }
      else
      if(isLow)
      {
         PivotPoint p;

         p.time   = time[i];
         p.price  = low[i];
         p.isHigh = false;

         AddPivot(p);
      }
   }

   return(
      g_PivotCount >= 3
   );
}

//==================================================================
// ADD PIVOT
//==================================================================

bool AddPivot(
   PivotPoint &p)
{
   if(g_PivotCount <= 0)
   {
      if(g_PivotCount < MAX_PIVOTS)
      {
         g_Pivots[g_PivotCount++] = p;
         return(true);
      }

      return(false);
   }

   int last =
      g_PivotCount - 1;

   if(
      g_Pivots[last].isHigh ==
      p.isHigh
   )
   {
      if(p.isHigh)
      {
         if(
            p.price >
            g_Pivots[last].price
         )
         {
            g_Pivots[last] = p;
         }
      }
      else
      {
         if(
            p.price <
            g_Pivots[last].price
         )
         {
            g_Pivots[last] = p;
         }
      }

      return(true);
   }

   if(g_PivotCount < MAX_PIVOTS)
   {
      g_Pivots[g_PivotCount++] = p;
      return(true);
   }

   return(false);
}

//==================================================================
// FIND ABC
//==================================================================

bool FindNearestConfirmedABC()
{
   g_Pattern.valid = false;

   if(g_PivotCount < 3)
      return(false);

   PivotPoint A =
      g_Pivots[g_PivotCount-3];

   PivotPoint B =
      g_Pivots[g_PivotCount-2];

   PivotPoint C =
      g_Pivots[g_PivotCount-1];

   if(
      A.time >= B.time ||
      B.time >= C.time
   )
      return(false);

   bool bullish =
      (
         !A.isHigh &&
         B.isHigh &&
         !C.isHigh
      );

   bool bearish =
      (
         A.isHigh &&
         !B.isHigh &&
         C.isHigh
      );

   if(!bullish && !bearish)
      return(false);

   double AB =
      MathAbs(
         B.price -
         A.price
      );

   if(AB <= 0.0)
      return(false);

   if(
      InpMinABPoints > 0.0 &&
      AB < InpMinABPoints * _Point
   )
      return(false);

   double BC =
      MathAbs(
         C.price -
         B.price
      );

   if(BC <= 0.0)
      return(false);

   double BCFib =
      BC / AB;

   if(InpUseFibFilter)
   {
      if(
         BCFib < InpBCFibMin ||
         BCFib > InpBCFibMax
      )
         return(false);
   }

   g_Pattern.A =
      A;

   g_Pattern.B =
      B;

   g_Pattern.C =
      C;

   g_Pattern.bullish =
      bullish;

   g_Pattern.AB =
      AB;

   g_Pattern.BC =
      BC;

   g_Pattern.BCFib =
      BCFib;

   g_Pattern.valid =
      true;

   return(true);
}

//==================================================================
// CALCULATE D
//==================================================================

bool CalculateDProjection()
{
   if(!g_Pattern.valid)
      return(false);

   double AB =
      g_Pattern.AB;

   if(AB <= 0.0)
      return(false);

   if(g_Pattern.bullish)
   {
      g_Pattern.DTarget =
         g_Pattern.C.price +
         AB * InpDTargetRatio;

      g_Pattern.DZoneLow =
         g_Pattern.C.price +
         AB * InpDZoneMin;

      g_Pattern.DZoneHigh =
         g_Pattern.C.price +
         AB * InpDZoneMax;
   }
   else
   {
      g_Pattern.DTarget =
         g_Pattern.C.price -
         AB * InpDTargetRatio;

      g_Pattern.DZoneLow =
         g_Pattern.C.price -
         AB * InpDZoneMax;

      g_Pattern.DZoneHigh =
         g_Pattern.C.price -
         AB * InpDZoneMin;
   }

   long abSeconds =
      (long)g_Pattern.B.time -
      (long)g_Pattern.A.time;

   if(abSeconds <= 0)
      abSeconds =
         PeriodSeconds(_Period);

   if(abSeconds <= 0)
      abSeconds = 60;

   datetime currentTime =
      iTime(
         _Symbol,
         _Period,
         0
      );

   if(currentTime <= 0)
      currentTime =
         TimeCurrent();

   if(InpProjectTimeByAB)
   {
      datetime projected =
         AddSecondsSafe(
            g_Pattern.C.time,
            abSeconds
         );

      if(projected <= currentTime)
      {
         projected =
            AddSecondsSafe(
               currentTime,
               abSeconds
            );
      }

      g_Pattern.DTime =
         projected;
   }
   else
   {
      g_Pattern.DTime =
         AddSecondsSafe(
            currentTime,
            abSeconds
         );
   }

   return(true);
}

//==================================================================
// RESET MOMENTUM STATE
//==================================================================

void ResetMomentumConfirmation(
   datetime cTime)
{
   g_MomentumConfirmed   = false;
   g_MomentumConfirmTime = 0;
   g_MomentumConfirmC    = cTime;
}

//==================================================================
// GET MOMENTUM
//==================================================================
//
// Values are taken ONLY from CLOSED BAR [1].
//
// v1.8:
// - Missing data is DATA WAIT.
// - Missing data is NOT counted as NO.
// - Score counts only valid indicators.
// - Momentum cannot PASS until all 3 indicators are available.
//
//==================================================================

bool GetMomentumConfirmation()
{
   g_RSIValid = false;
   g_CCIValid = false;
   g_WPRValid = false;

   g_RSIConfirm = false;
   g_CCIConfirm = false;
   g_WPRConfirm = false;

   g_ConfirmScore = 0;
   g_ValidMomentumCount = 0;

   g_MomentumDataReady = false;
   g_MomentumPass = false;

   if(!g_Pattern.valid)
      return(false);

   if(!InpUseMomentumConfirmation)
   {
      g_MomentumDataReady = true;
      g_MomentumPass = true;

      return(true);
   }

   if(
      g_RSIHandle == INVALID_HANDLE ||
      g_CCIHandle == INVALID_HANDLE ||
      g_WPRHandle == INVALID_HANDLE
   )
   {
      return(false);
   }

   // Static arrays:
   // DO NOT use ArraySetAsSeries().
   double rsiBuffer[1];
   double cciBuffer[1];
   double wprBuffer[1];

   //===============================================================
   // RSI
   //===============================================================

   if(
      CopyBuffer(
         g_RSIHandle,
         0,
         1,
         1,
         rsiBuffer
      ) == 1
   )
   {
      if(
         rsiBuffer[0] != EMPTY_VALUE &&
         MathIsValidNumber(rsiBuffer[0])
      )
      {
         g_RSI =
            rsiBuffer[0];

         g_RSIValid =
            true;

         g_ValidMomentumCount++;
      }
   }

   //===============================================================
   // CCI
   //===============================================================

   if(
      CopyBuffer(
         g_CCIHandle,
         0,
         1,
         1,
         cciBuffer
      ) == 1
   )
   {
      if(
         cciBuffer[0] != EMPTY_VALUE &&
         MathIsValidNumber(cciBuffer[0])
      )
      {
         g_CCI =
            cciBuffer[0];

         g_CCIValid =
            true;

         g_ValidMomentumCount++;
      }
   }

   //===============================================================
   // WPR
   //===============================================================

   if(
      CopyBuffer(
         g_WPRHandle,
         0,
         1,
         1,
         wprBuffer
      ) == 1
   )
   {
      if(
         wprBuffer[0] != EMPTY_VALUE &&
         MathIsValidNumber(wprBuffer[0])
      )
      {
         g_WPR =
            wprBuffer[0];

         g_WPRValid =
            true;

         g_ValidMomentumCount++;
      }
   }

   //===============================================================
   // RSI condition
   //===============================================================

   if(g_RSIValid)
   {
      if(g_Pattern.bullish)
      {
         g_RSIConfirm =
            g_RSI >= InpRSIBuyLevel;
      }
      else
      {
         g_RSIConfirm =
            g_RSI <= InpRSISellLevel;
      }
   }

   //===============================================================
   // CCI condition
   //===============================================================

   if(g_CCIValid)
   {
      if(g_Pattern.bullish)
      {
         g_CCIConfirm =
            g_CCI >= InpCCIBuyLevel;
      }
      else
      {
         g_CCIConfirm =
            g_CCI <= InpCCISellLevel;
      }
   }

   //===============================================================
   // WPR condition
   //===============================================================

   if(g_WPRValid)
   {
      if(g_Pattern.bullish)
      {
         g_WPRConfirm =
            g_WPR >= InpWPRBuyLevel;
      }
      else
      {
         g_WPRConfirm =
            g_WPR <= InpWPRSellLevel;
      }
   }

   //===============================================================
   // Score ONLY valid indicators
   //===============================================================

   if(
      g_RSIValid &&
      g_RSIConfirm
   )
   {
      g_ConfirmScore++;
   }

   if(
      g_CCIValid &&
      g_CCIConfirm
   )
   {
      g_ConfirmScore++;
   }

   if(
      g_WPRValid &&
      g_WPRConfirm
   )
   {
      g_ConfirmScore++;
   }

   //===============================================================
   // ALL 3 must be available before momentum can PASS
   //===============================================================

   g_MomentumDataReady =
      (
         g_ValidMomentumCount == 3
      );

   int required =
      MathMax(
         1,
         MathMin(
            3,
            InpMinConfirmScore
         )
      );

   if(g_MomentumDataReady)
   {
      g_MomentumPass =
         (
            g_ConfirmScore >= required
         );
   }
   else
   {
      g_MomentumPass =
         false;
   }

   return(true);
}

//==================================================================
// PASS MOMENTUM
//==================================================================

bool PassMomentumConfirmation()
{
   if(!g_Pattern.valid)
      return(false);

   if(!InpUseMomentumConfirmation)
      return(true);

   //===============================================================
   // IMPORTANT v1.8
   //
   // Do NOT allow partial data to confirm momentum.
   //===============================================================

   if(!g_MomentumDataReady)
      return(false);

   int required =
      MathMax(
         1,
         MathMin(
            3,
            InpMinConfirmScore
         )
      );

   return(
      g_ConfirmScore >= required
   );
}

//==================================================================
// D FILTER
//==================================================================

bool PassDProjectionFilters(
   const double &close[],
   int rates_total)
{
   if(
      !g_Pattern.valid ||
      rates_total < 2
   )
      return(false);

   double referencePrice =
      close[1];

   if(referencePrice <= 0.0)
      return(false);

   if(g_Pattern.AB <= 0.0)
      return(false);

   if(InpUseDMinDistance)
   {
      double distance =
         MathAbs(
            g_Pattern.DTarget -
            referencePrice
         );

      double minimum =
         g_Pattern.AB *
         MathMax(
            0.0,
            InpDMinDistanceAB
         );

      if(distance < minimum)
         return(false);
   }

   // D Stability intentionally NOT used as rejection.
   return(true);
}

//==================================================================
// REGISTER ACCEPTED
//==================================================================

void RegisterAcceptedProjection()
{
   g_LastAcceptedD =
      g_Pattern.DTarget;

   g_LastAcceptedAB =
      g_Pattern.AB;

   g_LastAcceptedC =
      g_Pattern.C.time;
}

//==================================================================
// DIAGNOSTIC
//==================================================================

void LogDiagnostic(
   const double &close[],
   int rates_total)
{
   if(
      !g_Pattern.valid ||
      rates_total < 2
   )
      return;

   string direction =
      g_Pattern.bullish
      ? "BUY"
      : "SELL";

   double referencePrice =
      close[1];

   double dFromC =
      g_Pattern.DTarget -
      g_Pattern.C.price;

   double dFromClose =
      g_Pattern.DTarget -
      referencePrice;

   double absDFromClose =
      MathAbs(
         dFromClose
      );

   double minDistance =
      g_Pattern.AB *
      MathMax(
         0.0,
         InpDMinDistanceAB
      );

   bool distancePass = true;

   if(InpUseDMinDistance)
   {
      distancePass =
         absDFromClose >= minDistance;
   }

   int required =
      MathMax(
         1,
         MathMin(
            3,
            InpMinConfirmScore
         )
      );

   Print(
      "============================================================"
   );

   Print(
      "ABCD v1.8 | NEW C CONFIRMED"
   );

   Print(
      "C CONFIRMED : ",
      FormatDateTime(
         g_Pattern.C.time
      )
   );

   Print(
      "Direction   : ",
      direction
   );

   Print(
      "A           : ",
      FormatDateTime(
         g_Pattern.A.time
      ),
      " | ",
      FormatPrice(
         g_Pattern.A.price
      )
   );

   Print(
      "B           : ",
      FormatDateTime(
         g_Pattern.B.time
      ),
      " | ",
      FormatPrice(
         g_Pattern.B.price
      )
   );

   Print(
      "C           : ",
      FormatDateTime(
         g_Pattern.C.time
      ),
      " | ",
      FormatPrice(
         g_Pattern.C.price
      )
   );

   Print(
      "AB          : ",
      FormatPrice(
         g_Pattern.AB
      )
   );

   Print(
      "BC          : ",
      FormatPrice(
         g_Pattern.BC
      )
   );

   Print(
      "BC/AB       : ",
      DoubleToString(
         g_Pattern.BCFib * 100.0,
         2
      ),
      "%"
   );

   Print(
      "D           : ",
      FormatPrice(
         g_Pattern.DTarget
      )
   );

   Print(
      "D-C         : ",
      FormatPrice(
         dFromC
      )
   );

   Print(
      "D-Close     : ",
      FormatPrice(
         dFromClose
      )
   );

   Print(
      "|D-Close|   : ",
      FormatPrice(
         absDFromClose
      )
   );

   if(InpUseDMinDistance)
   {
      Print(
         "D-MinDist   : ",
         FormatPrice(
            minDistance
         ),
         " (",
         DoubleToString(
            InpDMinDistanceAB,
            2
         ),
         " x AB) | ",
         distancePass
         ? "PASS"
         : "REJECT"
      );
   }
   else
   {
      Print(
         "D-MinDist   : OFF"
      );
   }

   Print(
      "------------------------------------------------------------"
   );

   //===============================================================
   // MOMENTUM DIAGNOSTIC
   //===============================================================

   if(InpUseMomentumConfirmation)
   {
      // RSI
      if(g_RSIValid)
      {
         Print(
            "RSI         : ",
            DoubleToString(
               g_RSI,
               2
            ),
            " | ",
            g_RSIConfirm
            ? "PASS"
            : "NO"
         );
      }
      else
      {
         Print(
            "RSI         : DATA WAIT"
         );
      }

      // CCI
      if(g_CCIValid)
      {
         Print(
            "CCI         : ",
            DoubleToString(
               g_CCI,
               2
            ),
            " | ",
            g_CCIConfirm
            ? "PASS"
            : "NO"
         );
      }
      else
      {
         Print(
            "CCI         : DATA WAIT"
         );
      }

      // WPR
      if(g_WPRValid)
      {
         Print(
            "WPR         : ",
            DoubleToString(
               g_WPR,
               2
            ),
            " | ",
            g_WPRConfirm
            ? "PASS"
            : "NO"
         );
      }
      else
      {
         Print(
            "WPR         : DATA WAIT"
         );
      }

      //============================================================
      // Momentum status
      //============================================================

      if(!g_MomentumDataReady)
      {
         Print(
            "MOMENTUM    : DATA WAIT | Available ",
            IntegerToString(
               g_ValidMomentumCount
            ),
            "/3"
         );
      }
      else
      {
         Print(
            "MOMENTUM    : ",
            IntegerToString(
               g_ConfirmScore
            ),
            "/3 | REQUIRED >= ",
            IntegerToString(
               required
            )
         );
      }

      Print(
         "ABCD STATUS : C CONFIRMED at ",
         FormatDateTime(
            g_Pattern.C.time
         )
      );

      if(!g_MomentumDataReady)
      {
         Print(
            "MOM STATUS  : DATA WAIT"
         );
      }
      else
      {
         Print(
            "MOM STATUS  : WAITING FOR CONFIRMATION"
         );
      }
   }
   else
   {
      Print(
         "MOMENTUM    : OFF"
      );
   }

   Print(
      "------------------------------------------------------------"
   );

   Print(
      "D-FILTER    : ",
      distancePass
      ? "PASS"
      : "REJECT"
   );

   if(!InpUseMomentumConfirmation)
   {
      Print(
         "SIGNAL      : READY | Momentum filter OFF"
      );
   }
   else
   if(!g_MomentumDataReady)
   {
      Print(
         "SIGNAL      : WAIT | Momentum data unavailable"
      );
   }
   else
   {
      Print(
         "MOMENTUM    : ",
         g_ConfirmScore,
         "/3"
      );

      if(g_MomentumPass)
      {
         Print(
            "SIGNAL      : READY | Momentum confirmed"
         );
      }
      else
      {
         Print(
            "SIGNAL      : WAIT | Momentum confirmation insufficient"
         );
      }
   }

   Print(
      "============================================================"
   );
}

//==================================================================
// DRAW PATTERN
//==================================================================

void DrawPattern()
{
   if(!g_Pattern.valid)
      return;

   if(InpShowAB)
   {
      CreateTrendObject(
         OBJ_AB,
         g_Pattern.A.time,
         g_Pattern.A.price,
         g_Pattern.B.time,
         g_Pattern.B.price,
         InpABColor,
         InpLineWidth,
         STYLE_SOLID
      );
   }

   if(InpShowBC)
   {
      CreateTrendObject(
         OBJ_BC,
         g_Pattern.B.time,
         g_Pattern.B.price,
         g_Pattern.C.time,
         g_Pattern.C.price,
         InpBCColor,
         InpLineWidth,
         STYLE_SOLID
      );
   }
}

//==================================================================
// DRAW D
//==================================================================

void DrawProjection()
{
   if(!g_Pattern.valid)
      return;

   color signalColor =
      g_Pattern.bullish
      ? InpBuyColor
      : InpSellColor;

   CreateTrendObject(
      OBJ_CD,
      g_Pattern.C.time,
      g_Pattern.C.price,
      g_Pattern.DTime,
      g_Pattern.DTarget,
      signalColor,
      InpLineWidth,
      STYLE_DOT
   );

   CreateHLineObject(
      OBJ_DTARGET,
      g_Pattern.DTarget,
      signalColor,
      InpLineWidth,
      STYLE_SOLID
   );

   if(InpShowDZone)
   {
      CreateHLineObject(
         OBJ_DZONE_L,
         g_Pattern.DZoneLow,
         InpZoneColor,
         InpLineWidth,
         STYLE_DOT
      );

      CreateHLineObject(
         OBJ_DZONE_H,
         g_Pattern.DZoneHigh,
         InpZoneColor,
         InpLineWidth,
         STYLE_DOT
      );
   }

   CreateArrowObject(
      OBJ_DARROW,
      g_Pattern.DTime,
      g_Pattern.DTarget,
      signalColor,
      g_Pattern.bullish
      ? 233
      : 234
   );

   string txt =
      (
         g_Pattern.bullish
         ? "BUY D"
         : "SELL D"
      ) +
      "\n" +
      FormatPrice(
         g_Pattern.DTarget
      );

   CreateTextObject(
      OBJ_DTEXT,
      g_Pattern.DTime,
      g_Pattern.DTarget,
      txt,
      signalColor
   );
}

//==================================================================
// BUTTON
//==================================================================

void CreateButton()
{
   if(ObjectFind(0,BUTTON_NAME) < 0)
   {
      if(!ObjectCreate(
            0,
            BUTTON_NAME,
            OBJ_BUTTON,
            0,
            0,
            0
         ))
         return;
   }

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_XDISTANCE,
      InpButtonX
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_YDISTANCE,
      InpButtonY
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_XSIZE,
      InpButtonWidth
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_YSIZE,
      InpButtonHeight
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_FONTSIZE,
      9
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_HIDDEN,
      true
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_ZORDER,
      100
   );

   ObjectSetString(
      0,
      BUTTON_NAME,
      OBJPROP_FONT,
      "Arial"
   );

   UpdateButton();
}

//==================================================================
// UPDATE BUTTON
//==================================================================

void UpdateButton()
{
   if(ObjectFind(0,BUTTON_NAME) < 0)
   {
      CreateButton();
      return;
   }

   ObjectSetString(
      0,
      BUTTON_NAME,
      OBJPROP_TEXT,
      g_Enabled
      ? "ABCD: ON"
      : "ABCD: OFF"
   );

   ObjectSetInteger(
      0,
      BUTTON_NAME,
      OBJPROP_STATE,
      false
   );
}

//==================================================================
// DASHBOARD
//==================================================================

void UpdateDashboard()
{
   if(!InpShowDashboard)
   {
      DeleteDashboard();
      return;
   }

   if(ObjectFind(0,OBJ_PANEL) < 0)
   {
      ObjectCreate(
         0,
         OBJ_PANEL,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_XDISTANCE,
      InpButtonX
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_YDISTANCE,
      InpButtonY +
      InpButtonHeight +
      8
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_FONTSIZE,
      8
   );

   ObjectSetString(
      0,
      OBJ_PANEL,
      OBJPROP_FONT,
      "Consolas"
   );

   ObjectSetInteger(
      0,
      OBJ_PANEL,
      OBJPROP_COLOR,
      clrWhite
   );

   string text;

   //===============================================================
   // OFF
   //===============================================================

   if(!g_Enabled)
   {
      text =
         "ABCD v1.8\n"
         "STATUS : OFF";

      ObjectSetString(
         0,
         OBJ_PANEL,
         OBJPROP_TEXT,
         text
      );

      return;
   }

   //===============================================================
   // WAIT ABC
   //===============================================================

   if(!g_Pattern.valid)
   {
      text =
         "ABCD v1.8\n"
         "STATUS : ON\n"
         "PHASE  : WAIT ABC\n"
         "PIVOTS : " +
         IntegerToString(
            g_PivotCount
         );

      ObjectSetString(
         0,
         OBJ_PANEL,
         OBJPROP_TEXT,
         text
      );

      return;
   }

   string direction =
      g_Pattern.bullish
      ? "BUY / L-H-L"
      : "SELL / H-L-H";

   string fibStatus =
      InpUseFibFilter
      ?
      (
         g_Pattern.BCFib >= InpBCFibMin &&
         g_Pattern.BCFib <= InpBCFibMax
         ? "PASS"
         : "REJECT"
      )
      : "OFF";

   //===============================================================
   // Momentum status
   //===============================================================

   string momentumStatus;

   if(!InpUseMomentumConfirmation)
   {
      momentumStatus =
         "OFF";
   }
   else
   if(g_MomentumConfirmed)
   {
      momentumStatus =
         "CONFIRMED " +
         IntegerToString(
            g_ConfirmScore
         ) +
         "/3";
   }
   else
   if(!g_MomentumDataReady)
   {
      momentumStatus =
         "DATA WAIT " +
         IntegerToString(
            g_ValidMomentumCount
         ) +
         "/3";
   }
   else
   {
      momentumStatus =
         "WAIT " +
         IntegerToString(
            g_ConfirmScore
         ) +
         "/3";
   }

   //===============================================================
   // RSI display
   //===============================================================

   string rsiDisplay;

   if(g_RSIValid)
   {
      rsiDisplay =
         DoubleToString(
            g_RSI,
            1
         ) +
         " [" +
         (
            g_RSIConfirm
            ? "PASS"
            : "NO"
         ) +
         "]";
   }
   else
   {
      rsiDisplay =
         "DATA WAIT";
   }

   //===============================================================
   // CCI display
   //===============================================================

   string cciDisplay;

   if(g_CCIValid)
   {
      cciDisplay =
         DoubleToString(
            g_CCI,
            1
         ) +
         " [" +
         (
            g_CCIConfirm
            ? "PASS"
            : "NO"
         ) +
         "]";
   }
   else
   {
      cciDisplay =
         "DATA WAIT";
   }

   //===============================================================
   // WPR display
   //===============================================================

   string wprDisplay;

   if(g_WPRValid)
   {
      wprDisplay =
         DoubleToString(
            g_WPR,
            1
         ) +
         " [" +
         (
            g_WPRConfirm
            ? "PASS"
            : "NO"
         ) +
         "]";
   }
   else
   {
      wprDisplay =
         "DATA WAIT";
   }

   //===============================================================
   // Dashboard
   //===============================================================

   text =
      "ABCD v1.8\n"
      "STATUS : ON\n"
      "TYPE   : " +
      direction +
      "\n"
      "\n"
      "C CONF : " +
      FormatDateTime(
         g_Pattern.C.time
      ) +
      "\n"
      "\n"
      "A      : " +
      FormatPrice(
         g_Pattern.A.price
      ) +
      "\n"
      "B      : " +
      FormatPrice(
         g_Pattern.B.price
      ) +
      "\n"
      "C      : " +
      FormatPrice(
         g_Pattern.C.price
      ) +
      "\n"
      "\n"
      "AB     : " +
      FormatPrice(
         g_Pattern.AB
      ) +
      "\n"
      "BC     : " +
      FormatPrice(
         g_Pattern.BC
      ) +
      "\n"
      "BC/AB  : " +
      DoubleToString(
         g_Pattern.BCFib * 100.0,
         1
      ) +
      "% [" +
      fibStatus +
      "]\n"
      "\n"
      "D      : " +
      FormatPrice(
         g_Pattern.DTarget
      ) +
      "\n"
      "ZONE   : " +
      FormatPrice(
         g_Pattern.DZoneLow
      ) +
      " - " +
      FormatPrice(
         g_Pattern.DZoneHigh
      ) +
      "\n"
      "D TIME : " +
      FormatDateTime(
         g_Pattern.DTime
      ) +
      "\n"
      "\n"
      "RSI    : " +
      rsiDisplay +
      "\n"
      "CCI    : " +
      cciDisplay +
      "\n"
      "WPR    : " +
      wprDisplay +
      "\n"
      "MOM    : " +
      momentumStatus;

   if(g_MomentumConfirmed)
   {
      text +=
         "\nMOM TIME: " +
         FormatDateTime(
            g_MomentumConfirmTime
         );
   }

   ObjectSetString(
      0,
      OBJ_PANEL,
      OBJPROP_TEXT,
      text
   );
}

//==================================================================
// CLEAR
//==================================================================

void ClearAllSignals()
{
   DeleteSignalObjects();

   g_Pattern.valid = false;

   g_RSIValid = false;
   g_CCIValid = false;
   g_WPRValid = false;

   g_RSIConfirm = false;
   g_CCIConfirm = false;
   g_WPRConfirm = false;

   g_ConfirmScore = 0;
   g_ValidMomentumCount = 0;

   g_MomentumDataReady = false;
   g_MomentumPass = false;

   g_MomentumConfirmed   = false;
   g_MomentumConfirmTime = 0;
   g_MomentumConfirmC    = 0;
}

//==================================================================
// DELETE OBJECTS
//==================================================================

void DeleteSignalObjects()
{
   string names[] =
   {
      OBJ_AB,
      OBJ_BC,
      OBJ_CD,
      OBJ_DTARGET,
      OBJ_DZONE_L,
      OBJ_DZONE_H,
      OBJ_DARROW,
      OBJ_DTEXT
   };

   for(
      int i=0;
      i<ArraySize(names);
      i++
   )
   {
      ObjectDelete(
         0,
         names[i]
      );
   }
}

//==================================================================
// DELETE DASHBOARD
//==================================================================

void DeleteDashboard()
{
   ObjectDelete(
      0,
      OBJ_PANEL
   );
}

//==================================================================
// OBJECT HELPERS
//==================================================================

bool CreateTrendObject(
   string name,
   datetime t1,
   double p1,
   datetime t2,
   double p2,
   color clr,
   int width,
   ENUM_LINE_STYLE style)
{
   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_TREND,
            0,
            t1,
            p1,
            t2,
            p2
         ))
         return(false);
   }
   else
   {
      ObjectMove(
         0,
         name,
         0,
         t1,
         p1
      );

      ObjectMove(
         0,
         name,
         1,
         t2,
         p2
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      MathMax(
         1,
         width
      )
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      style
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_RAY_RIGHT,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_RAY_LEFT,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   return(true);
}

//==================================================================
// HLINE
//==================================================================

bool CreateHLineObject(
   string name,
   double price,
   color clr,
   int width,
   ENUM_LINE_STYLE style)
{
   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_HLINE,
            0,
            0,
            price
         ))
         return(false);
   }

   ObjectSetDouble(
      0,
      name,
      OBJPROP_PRICE,
      price
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      MathMax(
         1,
         width
      )
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      style
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   return(true);
}

//==================================================================
// ARROW
//==================================================================

bool CreateArrowObject(
   string name,
   datetime t,
   double price,
   color clr,
   int code)
{
   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_ARROW,
            0,
            t,
            price
         ))
         return(false);
   }
   else
   {
      ObjectMove(
         0,
         name,
         0,
         t,
         price
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ARROWCODE,
      code
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      1
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_CENTER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   return(true);
}

//==================================================================
// TEXT
//==================================================================

bool CreateTextObject(
   string name,
   datetime t,
   double price,
   string text,
   color clr)
{
   if(ObjectFind(0,name) < 0)
   {
      if(!ObjectCreate(
            0,
            name,
            OBJ_TEXT,
            0,
            t,
            price
         ))
         return(false);
   }
   else
   {
      ObjectMove(
         0,
         name,
         0,
         t,
         price
      );
   }

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      8
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_LEFT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   return(true);
}

//==================================================================
// UTILITY
//==================================================================

datetime AddSecondsSafe(
   datetime baseTime,
   long seconds)
{
   long result =
      (long)baseTime +
      seconds;

   if(result < 0)
      result =
         (long)baseTime;

   return(
      (datetime)result
   );
}

//==================================================================
// FORMAT PRICE
//==================================================================

string FormatPrice(
   double price)
{
   int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );

   return(
      DoubleToString(
         price,
         digits
      )
   );
}

//==================================================================
// FORMAT DATETIME
//==================================================================

string FormatDateTime(
   datetime t)
{
   if(t <= 0)
      return("--");

   return(
      TimeToString(
         t,
         TIME_DATE |
         TIME_MINUTES
      )
   );
}
//+------------------------------------------------------------------+