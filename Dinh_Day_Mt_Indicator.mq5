//+------------------------------------------------------------------+
//| Fractal ZigZag + Break B1 B2 Filter Secondary |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int InpLeftRight = 2; // Nen xac nhan dinh day nho
input int InpMajorLeftRight = 3; // Nen xac nhan dinh day LON de loc break thu cap
input int InpLookback = 500;
input int InpLineWidth = 2;
input color InpUpColor = clrDeepSkyBlue;
input color InpDnColor = clrOrange;
input color InpBreakColor = clrDodgerBlue;
input bool InpFilterSecondary = true;
input double InpMinBreakATR = 0.5; // Break nho hon 0.8 ATR se bi coi la thu cap va bo

int hATR;
struct Pt { datetime t; double p; int type; int idx; };

int OnInit()
{
   hATR = iATR(_Symbol, PERIOD_CURRENT, 14);
   return hATR==INVALID_HANDLE?INIT_FAILED:INIT_SUCCEEDED;
}
void OnDeinit(const int r){ ObjectsDeleteAll(0,"FractalLine_"); ObjectsDeleteAll(0,"Break_"); ObjectsDeleteAll(0,"B_"); IndicatorRelease(hATR); }

bool IsSwing(const double &h[], const double &l[], int i, int lr, int &type, double &price)
{
   bool isHigh=true, isLow=true;
   for(int k=1;k<=lr;k++)
   {
      if(h[i] <= h[i-k] || h[i] <= h[i+k]) isHigh=false;
      if(l[i] >= l[i-k] || l[i] >= l[i+k]) isLow=false;
   }
   if(isHigh){ type=1; price=h[i]; return true; }
   if(isLow){ type=-1; price=l[i]; return true; }
   return false;
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
{
   if(rates_total < InpLookback) return rates_total;
   ObjectsDeleteAll(0,"FractalLine_"); ObjectsDeleteAll(0,"Break_"); ObjectsDeleteAll(0,"B_");
   ArraySetAsSeries(time,true); ArraySetAsSeries(high,true); ArraySetAsSeries(low,true); ArraySetAsSeries(close,true);

   double atr[]; ArraySetAsSeries(atr,true);
   CopyBuffer(hATR,0,0,InpLookback,atr);

   // 1. Tim dinh day nho (de ve zigzag)
   Pt raw[]; int rc=0;
   for(int i=InpLookback-1; i>=InpLeftRight; i--)
   {
      int tp; double pr; if(!IsSwing(high,low,i,InpLeftRight,tp,pr)) continue;
      ArrayResize(raw,rc+1); raw[rc].t=time[i]; raw[rc].p=pr; raw[rc].type=tp; raw[rc].idx=i; rc++;
   }
   Pt seq[]; int sc=0;
   for(int i=0;i<rc;i++)
   {
      if(sc==0){ ArrayResize(seq,1); seq[0]=raw[i]; sc=1; continue; }
      if(raw[i].type!=seq[sc-1].type){ ArrayResize(seq,sc+1); seq[sc]=raw[i]; sc++; }
      else
      {
         if(raw[i].type==1 && raw[i].p > seq[sc-1].p) seq[sc-1]=raw[i];
         if(raw[i].type==-1 && raw[i].p < seq[sc-1].p) seq[sc-1]=raw[i];
      }
   }

   // 2. Tim dinh day LON de loc break thu cap
   Pt majorRaw[]; int mrc=0;
   for(int i=InpLookback-1; i>=InpMajorLeftRight; i--)
   {
      int tp; double pr; if(!IsSwing(high,low,i,InpMajorLeftRight,tp,pr)) continue;
      ArrayResize(majorRaw,mrc+1); majorRaw[mrc].t=time[i]; majorRaw[mrc].p=pr; majorRaw[mrc].type=tp; majorRaw[mrc].idx=i; mrc++;
   }

   // Ve zigzag chinh
   for(int k=0;k<sc-1;k++)
   {
      string zName="FractalLine_"+IntegerToString(k);
      ObjectCreate(0,zName,OBJ_TREND,0,seq[k].t,seq[k].p,seq[k+1].t,seq[k+1].p);
      ObjectSetInteger(0,zName,OBJPROP_COLOR,(seq[k+1].p>seq[k].p)?InpUpColor:InpDnColor);
      ObjectSetInteger(0,zName,OBJPROP_WIDTH,InpLineWidth);
      ObjectSetInteger(0,zName,OBJPROP_RAY_RIGHT,false);
   }

   // 3. Tim Break va loc thu cap
   int breakCount=0; int lastDir=0;
   for(int k=2;k<sc;k++)
   {
      bool isBreakUp = (seq[k].type==1 && seq[k].p > seq[k-2].p);
      bool isBreakDn = (seq[k].type==-1 && seq[k].p < seq[k-2].p);
      if(!isBreakUp &&!isBreakDn) continue;

      // --- LOC BREAK THU CAP ---
      if(InpFilterSecondary)
      {
         // a) Break qua nho so voi ATR
         double breakSize = MathAbs(seq[k].p - seq[k-2].p);
         double curAtr = atr[seq[k].idx];
         if(breakSize < curAtr * InpMinBreakATR) continue;

         // b) Break khong phai o cau truc lon (khong trung voi dinh day lon)
         bool isMajorBreak=false;
         for(int m=0;m<mrc;m++)
         {
            if(majorRaw[m].type==seq[k].type && MathAbs(majorRaw[m].idx - seq[k].idx) <= 2)
            { isMajorBreak=true; break; }
         }
         if(!isMajorBreak) continue; // Bo break thu cap
      }

      int dir=isBreakUp?1:-1;
      if(dir!=lastDir){ breakCount=1; lastDir=dir; } else { breakCount++; }

      string bLine="Break_"+IntegerToString(k);
      ObjectCreate(0,bLine,OBJ_TREND,0,seq[k-2].t,seq[k-2].p,seq[k].t,seq[k-2].p);
      ObjectSetInteger(0,bLine,OBJPROP_COLOR,InpBreakColor);
      ObjectSetInteger(0,bLine,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,bLine,OBJPROP_WIDTH,1);

            if(breakCount==1 || breakCount==2)
      {
         string label="B_"+IntegerToString(k);
         string txt = (breakCount==1?"B1-$":"B2-$");

         // Dua sang ben trai cua duong break
         datetime leftT = seq[k-2].t;
         // Cong them 1-2 nen cho de nhin, khong de ngay dinh
         datetime labelT = leftT + (seq[k].t - leftT)/8;

         ObjectCreate(0,label,OBJ_TEXT,0,labelT,seq[k-2].p);
         ObjectSetString(0,label,OBJPROP_TEXT,txt);

         // B1-$ mau do, B2-$ mau trang
         color txtColor = (breakCount==1? clrRed : clrWhite);
         ObjectSetInteger(0,label,OBJPROP_COLOR,txtColor);

         ObjectSetInteger(0,label,OBJPROP_FONTSIZE,9);
         ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
      }
   }
   return rates_total;
}