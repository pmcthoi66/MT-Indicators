//+------------------------------------------------------------------+
//| Candle countdown clock - optimized revision 1.10                 |
//| Original: Opengates Success International Org.                   |
//+------------------------------------------------------------------+
#property copyright "2003-2026, Opengates Success International Org."
#property link      "https://www.ffxmvdashboards.com/store"
#property version   "1.10"
#property description "Candle countdown clock - lightweight timer update"
#property indicator_chart_window
#property indicator_plots 0

input color textColor = clrLime; // Mau chu
input int   fontSize  = 9;      // Co chu (> 0)
input int   x_offset  = 120;     // Khoang cach ngang tu goc (pixel)
input int   y_offset  = 2;       // Khoang cach doc tu goc (pixel)

// Keep original input names and corner values for existing presets.
enum MyCorner
  {
   TopLeft     = 0,
   BottomLeft  = 1,
   BottomRight = 2,
   TopRight    = 3
  };
input MyCorner corner = TopRight; // Goc hien thi

string   labelName = "";
string   lastText  = "";
datetime barOpen   = 0;
datetime barClose  = 0;
int      periodSec = 0;

// Calculate only on a new candle, not on every timer event.
void SetBar(const datetime opened)
  {
   if(opened <= 0 || opened == barOpen)
      return;
   barOpen = opened;
   if(_Period == PERIOD_MN1)
     {
      // A calendar month is not a fixed number of seconds.
      MqlDateTime dt = {};
      if(!TimeToStruct(opened, dt))
        {
         barClose = 0;
         return;
        }
      dt.day = 1;
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      dt.mon++;
      if(dt.mon > 12)
        {
         dt.mon = 1;
         dt.year++;
        }
      barClose = StructToTime(dt);
     }
   else
      barClose = opened + periodSec;
  }

bool CreateLabel()
  {
   if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
      return false;
   bool ok = true;
   if(!ObjectSetInteger(0, labelName, OBJPROP_CORNER, corner)) ok = false;
   // Preserve the original text anchor and pixel positioning.
   if(!ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, x_offset)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y_offset)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, fontSize)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_COLOR, textColor)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_SELECTED, false)) ok = false;
   if(!ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true)) ok = false;
   if(!ObjectSetString(0, labelName, OBJPROP_FONT, "Arial")) ok = false;
   if(!ObjectSetString(0, labelName, OBJPROP_TOOLTIP, "\n")) ok = false;
   return ok;
  }

void UpdateClock()
  {
   string display;
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) && !MQLInfoInteger(MQL_TESTER))
      display = "Disconnected";
   else if(barClose <= 0)
      display = "Waiting for data";
   else
     {
      // Estimated server time keeps advancing between quotes.
      // It depends on the computer clock; keep Windows time synchronized.
      datetime now = TimeTradeServer();
      if(now <= 0) now = TimeCurrent();
      if(now <= 0)
         display = "Waiting for time";
      else
        {
         long remaining = (long)(barClose - now);
         if(remaining < 0) remaining = 0;
         int hours   = (int)(remaining / 3600);
         int minutes = (int)((remaining % 3600) / 60);
         int seconds = (int)(remaining % 60);
         display = StringFormat("%02dh %02dm %02ds", hours, minutes, seconds);
        }
     }
   if(display == lastText)
      return;
   if(ObjectSetString(0, labelName, OBJPROP_TEXT, display))
     {
      lastText = display;
      ChartRedraw(0);
     }
  }

int OnInit()
  {
   if(fontSize <= 0 || x_offset < 0 || y_offset < 0)
      return INIT_PARAMETERS_INCORRECT;
   periodSec = PeriodSeconds(_Period);
   if(periodSec <= 0)
      return INIT_FAILED;
   // Each instance owns exactly one label; do not delete other copies.
   string prefix = "CandleCountdownClock_" + (string)GetMicrosecondCount();
   labelName = prefix;
   int suffix = 0;
   while(ObjectFind(0, labelName) >= 0)
      labelName = prefix + "_" + (string)(++suffix);
   ResetLastError();
   if(!CreateLabel())
     {
      PrintFormat("Countdown: cannot create label, error %d", GetLastError());
      ObjectDelete(0, labelName);
      return INIT_FAILED;
     }
   IndicatorSetString(INDICATOR_SHORTNAME, "Clock v1.10");
   SetBar(iTime(_Symbol, _Period, 0)); // Initial data request only.
   ResetLastError();
   if(!EventSetTimer(1))
     {
      PrintFormat("Countdown: cannot start timer, error %d", GetLastError());
      ObjectDelete(0, labelName);
      return INIT_FAILED;
     }
   UpdateClock();
   return INIT_SUCCEEDED;
  }

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
   if(rates_total <= 0) return 0;
   // Use the existing chart data; no history scan or per-tick iTime call.
   datetime opened = time[ArrayGetAsSeries(time) ? 0 : rates_total - 1];
   if(opened != barOpen || prev_calculated == 0)
     {
      SetBar(opened);
      UpdateClock();
     }
   return rates_total;
  }

void OnTimer()
  {
   // Retry only while initial history is unavailable.
   if(barOpen <= 0) SetBar(iTime(_Symbol, _Period, 0));
   UpdateClock();
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(labelName != "") ObjectDelete(0, labelName);
   lastText = "";
   barOpen = 0;
   barClose = 0;
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
