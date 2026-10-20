//+------------------------------------------------------------------+
//| SWIS + Pullback + Reversal Candles v3.10                          |
//| Original SWIS v2.00: OpenAI. Revision: PVT_AI                     |
//+------------------------------------------------------------------+
#property copyright "OpenAI / PVT_AI"
#property version "3.10"
#property strict
#property indicator_chart_window
#property indicator_plots 4
#property indicator_buffers 4
#property indicator_label1 "Bullish SWIS"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrLime
#property indicator_width1 1
#property indicator_label2 "Bearish SWIS"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_width2 1
#property indicator_label3 "BUY Pullback"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrLime
#property indicator_width3 2
#property indicator_label4 "SELL Pullback"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrRed
#property indicator_width4 2

input int SwingStrength = 2;                   // So nen moi ben xac nhan swing
input int LookbackBars = 300;                  // Lich su hien thi va khoi tao
input bool RequireCloseBreak = true;          // SWIS: pha bang gia dong cua
input int ArrowDistancePoints = 80;           // Khoang cach mui ten (point)
input int LineWidth = 1;                       // Do day duong SWIS
input ENUM_LINE_STYLE LineStyle = STYLE_DOT;   // Kieu duong SWIS
input color BullishLineColor = clrLime;        // Mau SWIS tang
input color BearishLineColor = clrRed;         // Mau SWIS giam
input color TextColor = clrWhite;             // Mau chu SWIS
input int TextSize = 7;                        // Co chu
input int TextDistancePoints = 40;            // Chu cach duong (point)
input bool OnlyLatestSWIS = true;             // SWIS doc lap: chi moi nhat; SWIS cua entry luon giu
input bool ShowSWISArrows = true;             // Mui ten pha cau truc
input bool EnableBuySell = true;              // Bat tin hieu pullback BUY/SELL
input bool ShowEntryHistory = false;          // Trang thai HIST ban dau: OFF/ON
input int HistoryButtonX = 12;                // Nut HIST: cach goc tren phai (pixel)
input int HistoryButtonY = 20;                // Nut HIST: cach mep tren (pixel)
input int RecentEntrySignals = 3;             // History OFF: giu so tin hieu nay
input bool ShowEntryText = true;              // Chu BUY/SELL ben mui ten
input int ATRPeriod = 14;                      // ATR SMA, khong tao handle
input double MinPullbackATR = 0.30;            // Do sau hoi toi thieu / ATR tai SWIS
input int MaxPullbackBars = 12;                // Het han sau tung nay nen tu SWIS
input bool RequireLevelRetest = false;        // Bat buoc hoi cham muc SWIS
input double RetestToleranceATR = 0.25;        // Dung sai cham muc SWIS / ATR
input double ExtremeToleranceATR = 0.25;       // Mau nen phai gan cuc tri pullback
input bool UseEngulfing = true;               // Nen nhan chim than nguoc mau
input bool UsePinBar = true;                  // Nen duoi dai dao chieu
input bool UseStar = true;                    // Morning / Evening Star 3 nen
input double PinWickBodyRatio = 2.0;           // Duoi chinh / than toi thieu
input double MinSignalBodyATR = 0.08;          // Bo qua than nen qua nho

// Buffers 0/1 = SWIS, 2/3 = BUY/SELL. Bar 0 is always empty.
double BullSWIS[], BearSWIS[], BuySignal[], SellSignal[];
string prefix = "";
datetime processed = 0;
double swingHigh = 0, swingLow = 0;
datetime highTime = 0, lowTime = 0;
bool highUsed = true, lowUsed = true;
bool historyOn = false;
int renderBars = 0;
string wantedObjects = "";

struct SWISRecord
  {
   int dir;
   datetime from, stamp;
   double level, arrow;
  };
struct EntryRecord
  {
   int dir;
   datetime stamp;
   double price, gap;
   SWISRecord origin;
  };
SWISRecord structures[];
EntryRecord entries[];

void RememberSWIS(const int dir,const datetime from,const datetime stamp,
                  const double level,const double arrow)
  {
   int n=ArraySize(structures);
   if(ArrayResize(structures,n+1,64)<0) return;
   structures[n].dir=dir; structures[n].from=from; structures[n].stamp=stamp;
   structures[n].level=level; structures[n].arrow=arrow;
  }


struct Setup
  {
   int dir;
   datetime started;
   int age;
   double level, protect, atr, peak, trough, pullExtreme;
   bool pulling, touched;
   SWISRecord origin;
  };
Setup setup;

void ResetState()
  {
   processed = 0;
   swingHigh = 0; swingLow = 0;
   highTime = 0; lowTime = 0;
   highUsed = true; lowUsed = true;
   ZeroMemory(setup);
   ArrayFree(structures); ArrayFree(entries);
  }

bool IsPivot(const double &values[], const int j, const bool top)
  {
   for(int k=1; k<=SwingStrength; k++)
      if(top ? (values[j]<=values[j-k] || values[j]<=values[j+k])
             : (values[j]>=values[j-k] || values[j]>=values[j+k]))
         return false;
   return true;
  }

double ATR(const int i, const double &h[], const double &l[], const double &c[])
  {
   double sum = 0;
   for(int k=i; k<i+ATRPeriod; k++)
      sum += MathMax(h[k]-l[k], MathMax(MathAbs(h[k]-c[k+1]),MathAbs(l[k]-c[k+1])));
   return sum/ATRPeriod;
  }

double Body(const int i,const double &o[],const double &c[])
  { return MathAbs(c[i]-o[i]); }

// All patterns end on closed bar i. Forex Star rules do not require gaps.
bool Reversal(const int i,const int dir,const double atr,
              const double &o[],const double &h[],const double &l[],const double &c[],
              int &length)
  {
   length=0;
   double b=Body(i,o,c), r=h[i]-l[i];
   if(r<=0 || b<MinSignalBodyATR*atr) return false;
   bool bullish=dir>0;
   if(bullish ? c[i]<=o[i] : c[i]>=o[i]) return false;
   bool opposite=bullish ? c[i+1]<o[i+1] : c[i+1]>o[i+1];
   if(UseEngulfing && opposite && b>=Body(i+1,o,c) &&
      (bullish ? (o[i]<=c[i+1] && c[i]>=o[i+1]) : (o[i]>=c[i+1] && c[i]<=o[i+1])))
     { length=2; return true; }
   double upper=h[i]-MathMax(o[i],c[i]);
   double lower=MathMin(o[i],c[i])-l[i];
   if(UsePinBar && b/r<=0.40 &&
      (bullish ? (lower>=PinWickBodyRatio*b && upper<=b && (c[i]-l[i])/r>=0.65)
               : (upper>=PinWickBodyRatio*b && lower<=b && (h[i]-c[i])/r>=0.65)))
     { length=1; return true; }
   double first=Body(i+2,o,c), firstRange=h[i+2]-l[i+2];
   if(UseStar && firstRange>0 && first>=0.35*firstRange &&
      Body(i+1,o,c)<=0.50*first && b>=0.35*r &&
      (bullish ? (c[i+2]<o[i+2] && MathMin(o[i+1],c[i+1])<=c[i+2] && c[i]>(o[i+2]+c[i+2])/2)
               : (c[i+2]>o[i+2] && MathMax(o[i+1],c[i+1])>=c[i+2] && c[i]<(o[i+2]+c[i+2])/2)))
     { length=3; return true; }
   return false;
  }

void Text(const string name,const datetime t,const double price,const string label,const color col)
  {
   wantedObjects+="|"+name+"|";
   if(ObjectFind(0,name)>=0) return;
   if(!ObjectCreate(0,name,OBJ_TEXT,0,t,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,label);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,TextSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void DrawSWIS(const int dir,const datetime from,const datetime to,const double level)
  {

   string id=prefix+"S_"+(string)(long)to;
   string line=id+"_L";
   wantedObjects+="|"+line+"|";
   if(ObjectFind(0,line)<0 && ObjectCreate(0,line,OBJ_TREND,0,from,level,to,level))
     {
      ObjectSetInteger(0,line,OBJPROP_COLOR,dir>0?BullishLineColor:BearishLineColor);
      ObjectSetInteger(0,line,OBJPROP_WIDTH,LineWidth);
      ObjectSetInteger(0,line,OBJPROP_STYLE,LineStyle);
      ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,line,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,line,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,line,OBJPROP_HIDDEN,true);
     }
   Text(id+"_T",from+(to-from)/2,level+dir*TextDistancePoints*_Point,"SWIS",TextColor);
  }

void BeginSetup(const int dir,const int i,const datetime &t[],const double &h[],const double &l[],const double &c[])
  {
   ZeroMemory(setup);
   setup.dir=dir; setup.started=t[i];
   setup.level=dir>0?swingHigh:swingLow;
   setup.protect=dir>0?swingLow:swingHigh;
   setup.atr=ATR(i,h,l,c);
   setup.origin.dir=dir;
   setup.origin.from=dir>0?highTime:lowTime;
   setup.origin.stamp=t[i]; setup.origin.level=setup.level;
   double gap=MathMax(ArrowDistancePoints*_Point,0.10*setup.atr);
   setup.origin.arrow=dir>0?l[i]-gap:h[i]+gap;
   setup.peak=h[i]; setup.trough=l[i];
   setup.pullExtreme=dir>0?h[i]:l[i];
   // Need an already confirmed opposite pivot to protect the structure.
   if(setup.protect<=0 || setup.atr<=0 ||
      (dir>0 ? setup.protect>=setup.level : setup.protect<=setup.level)) setup.dir=0;
  }

void ProcessBar(const int i,const bool draw,const datetime &t[],const double &o[],
                const double &h[],const double &l[],const double &c[])
  {
   if(setup.dir!=0)
     {
      setup.age++;
      if(setup.age>MaxPullbackBars ||
         (setup.dir>0?c[i]<setup.protect:c[i]>setup.protect)) setup.dir=0;
     }
   // At bar i, j has exactly SwingStrength CLOSED newer candles.
   int j=i+SwingStrength;
   if(IsPivot(h,j,true)) { swingHigh=h[j]; highTime=t[j]; highUsed=false; }
   if(IsPivot(l,j,false)) { swingLow=l[j]; lowTime=t[j]; lowUsed=false; }
   bool up=!highUsed && (RequireCloseBreak?c[i]>swingHigh:h[i]>swingHigh);
   bool dn=!lowUsed && (RequireCloseBreak?c[i]<swingLow:l[i]<swingLow);
   if(up) highUsed=true;
   if(dn) lowUsed=true;
   // An outside candle breaking BOTH levels by wick has no unique direction.
   if(up && dn) { setup.dir=0; return; }
   if(up || dn)
     {
      int dir=up?1:-1;
      double swisGap=MathMax(ArrowDistancePoints*_Point,0.10*ATR(i,h,l,c));
      RememberSWIS(dir,up?highTime:lowTime,t[i],up?swingHigh:swingLow,up?l[i]-swisGap:h[i]+swisGap);
      // A same-direction break does not restart an unfinished pullback.
      // Refresh only the impulse extreme; opposite break cancels/replaces it.
      if(setup.dir==dir)
        {
         setup.peak=MathMax(setup.peak,h[i]);
         setup.trough=MathMin(setup.trough,l[i]);
        }
      else BeginSetup(dir,i,t,h,l,c);
      return; // Never enter on the SWIS break candle itself.
     }
   if(setup.dir==0 || !EnableBuySell) return;
   int dir=setup.dir;
   double depth=dir>0?setup.peak-l[i]:h[i]-setup.trough;
   bool retreat=dir>0?(l[i]<l[i+1] || c[i]<o[i]):(h[i]>h[i+1] || c[i]>o[i]);
   if(retreat && depth>=MinPullbackATR*setup.atr) setup.pulling=true;
   if(setup.pulling)
     {
      setup.pullExtreme=dir>0?MathMin(setup.pullExtreme,l[i]):MathMax(setup.pullExtreme,h[i]);
      double tol=RetestToleranceATR*setup.atr;
      if(l[i]<=setup.level+tol && h[i]>=setup.level-tol) setup.touched=true;
      int length=0;
      bool pattern=Reversal(i,dir,setup.atr,o,h,l,c,length);
      // Pattern must start after SWIS, not borrow impulse candles.
      if(pattern && t[i+length-1]>setup.started &&
         (!RequireLevelRetest || setup.touched) &&
         (dir>0?c[i]>setup.level:c[i]<setup.level))
        {
         double extreme=dir>0?l[i]:h[i];
         for(int k=1;k<length;k++) extreme=dir>0?MathMin(extreme,l[i+k]):MathMax(extreme,h[i+k]);
         bool near=dir>0?extreme<=setup.pullExtreme+ExtremeToleranceATR*setup.atr
                       :extreme>=setup.pullExtreme-ExtremeToleranceATR*setup.atr;
         if(near)
           {
            if(draw)
              {
               double gap=MathMax(ArrowDistancePoints*_Point,0.15*setup.atr);
               double price=dir>0?l[i]-gap:h[i]+gap;
               if(dir>0) BuySignal[i]=price; else SellSignal[i]=price;
               int n=ArraySize(entries);
               if(ArrayResize(entries,n+1,64)>=0)
                 {
                  entries[n].dir=dir; entries[n].stamp=t[i];
                  entries[n].price=price; entries[n].gap=gap;
                  entries[n].origin=setup.origin;
                 }
              }
            setup.dir=0; // One entry per setup.
            return;
           }
        }
     }
   setup.peak=MathMax(setup.peak,h[i]); setup.trough=MathMin(setup.trough,l[i]);
  }

void UpdateHistoryButton()
  {
   string name=prefix+"HIST";
   if(ObjectFind(0,name)<0)
     {
      if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0)) return;
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      // X is the distance from the right edge to the LEFT of the button.
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,HistoryButtonX+92);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,HistoryButtonY);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,92);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,22);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrSlateGray);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }
   ObjectSetString(0,name,OBJPROP_TEXT,historyOn?"HIST ON":"HIST OFF");
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,historyOn?clrDarkGreen:clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
  }

void DisplaySWIS(const SWISRecord &r)
  {
   DrawSWIS(r.dir,r.from,r.stamp,r.level);
   int bar=iBarShift(_Symbol,_Period,r.stamp,true);
   if(ShowSWISArrows && bar>=1 && bar<=renderBars)
     { if(r.dir>0) BullSWIS[bar]=r.arrow; else BearSWIS[bar]=r.arrow; }
  }

void RenderHistory()
  {
   UpdateHistoryButton();
   if(renderBars<1) return;
   datetime cutoff=iTime(_Symbol,_Period,renderBars);
   if(cutoff<=0) return;
   // Prune cached data only by age, NEVER because the history is hidden.
   int count=0;
   for(int k=0;k<ArraySize(entries);k++)
      if(entries[k].stamp>=cutoff) { entries[count]=entries[k]; count++; }
   ArrayResize(entries,count);
   count=0;
   for(int k=0;k<ArraySize(structures);k++)
      if(structures[k].stamp>=cutoff) { structures[count]=structures[k]; count++; }
   ArrayResize(structures,count);
   for(int i=0;i<=renderBars;i++)
     { BullSWIS[i]=EMPTY_VALUE; BearSWIS[i]=EMPTY_VALUE; BuySignal[i]=EMPTY_VALUE; SellSignal[i]=EMPTY_VALUE; }
   wantedObjects="|"+prefix+"HIST|";
   int size=ArraySize(structures);
   int first=(historyOn && !OnlyLatestSWIS)?0:MathMax(0,size-1);
   for(int k=first;k<size;k++) DisplaySWIS(structures[k]);
   size=ArraySize(entries);
   first=historyOn?0:MathMax(0,size-RecentEntrySignals);
   for(int k=first;k<size;k++)
     {
      int bar=iBarShift(_Symbol,_Period,entries[k].stamp,true);
      if(bar<1 || bar>renderBars) continue;
      if(entries[k].dir>0) BuySignal[bar]=entries[k].price;
      else SellSignal[bar]=entries[k].price;
      // The exact originating SWIS is copied with the entry, even when
      // a newer independent SWIS has appeared or the break predates cutoff.
      DisplaySWIS(entries[k].origin);
      if(ShowEntryText)
         Text(prefix+"E_"+(string)(long)entries[k].stamp,entries[k].stamp,
              entries[k].price-entries[k].dir*entries[k].gap,
              entries[k].dir>0?"BUY":"SELL",entries[k].dir>0?clrLime:clrRed);
     }
   // Reuse wanted objects; delete only hidden/expired objects of this instance.
   for(int k=ObjectsTotal(0,0,-1)-1;k>=0;k--)
     {
      string name=ObjectName(0,k,0,-1);
      if(StringFind(name,prefix)==0 && StringFind(wantedObjects,"|"+name+"|")<0)
         ObjectDelete(0,name);
     }
   wantedObjects="";
   ChartRedraw(0);
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==prefix+"HIST")
     {
      historyOn=!historyOn;
      RenderHistory(); // Immediate toggle; no new tick or candle required.
     }
  }

int OnInit()
  {
   if(SwingStrength<1 || SwingStrength>100 || LookbackBars<20 || LookbackBars>10000 ||
      ATRPeriod<2 || ATRPeriod>500 || MaxPullbackBars<1 || RecentEntrySignals<1 ||
      HistoryButtonX<0 || HistoryButtonY<0 || ArrowDistancePoints<0 || TextDistancePoints<0 || TextSize<1 || LineWidth<1 || LineWidth>5 ||
      MinPullbackATR<=0 || RetestToleranceATR<0 || ExtremeToleranceATR<0 ||
      PinWickBodyRatio<1 || MinSignalBodyATR<0 ||
      (EnableBuySell && !UseEngulfing && !UsePinBar && !UseStar)) return INIT_PARAMETERS_INCORRECT;
   SetIndexBuffer(0,BullSWIS,INDICATOR_DATA); SetIndexBuffer(1,BearSWIS,INDICATOR_DATA);
   SetIndexBuffer(2,BuySignal,INDICATOR_DATA); SetIndexBuffer(3,SellSignal,INDICATOR_DATA);
   ArraySetAsSeries(BullSWIS,true); ArraySetAsSeries(BearSWIS,true);
   ArraySetAsSeries(BuySignal,true); ArraySetAsSeries(SellSignal,true);
   for(int k=0;k<4;k++) PlotIndexSetDouble(k,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(0,PLOT_ARROW,233); PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetInteger(2,PLOT_ARROW,241); PlotIndexSetInteger(3,PLOT_ARROW,242);
   IndicatorSetString(INDICATOR_SHORTNAME,"SWIS Pullback Candles 3.10");
   prefix="SWIS_PB_"+(string)GetMicrosecondCount()+"_";
   ResetState();
   historyOn=ShowEntryHistory;
   UpdateHistoryButton();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(prefix!="") ObjectsDeleteAll(0,prefix);
   ResetState(); renderBars=0; wantedObjects=""; ChartRedraw(0);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   ArraySetAsSeries(time,true); ArraySetAsSeries(open,true); ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true); ArraySetAsSeries(close,true);
   int reserve=MathMax(2*SwingStrength,MathMax(ATRPeriod,2))+2;
   if(rates_total<=reserve+2) return 0;
   bool reset=prev_calculated==0 || processed==0 || processed>time[1];
   if(!reset && processed==time[1]) return rates_total;
   int start=0;
   if(!reset)
     {
      // Locate unprocessed closed candles; also handles several missed bars.
      while(start+1<rates_total && time[start+1]>processed) start++;
      if(start+1>=rates_total || time[start+1]!=processed) reset=true;
     }
   if(reset)
     {
      ArrayInitialize(BullSWIS,EMPTY_VALUE); ArrayInitialize(BearSWIS,EMPTY_VALUE);
      ArrayInitialize(BuySignal,EMPTY_VALUE); ArrayInitialize(SellSignal,EMPTY_VALUE);
      ObjectsDeleteAll(0,prefix); ResetState();
      start=MathMin(LookbackBars+MaxPullbackBars+reserve,rates_total-reserve-1);
     }
   else
     {
      // Clear newly shifted slots and the expired edge only, not entire buffers.
      int edge=MathMin(rates_total-1,LookbackBars+start);
      for(int i=LookbackBars+1;i<=edge;i++)
        { BullSWIS[i]=EMPTY_VALUE; BearSWIS[i]=EMPTY_VALUE; BuySignal[i]=EMPTY_VALUE; SellSignal[i]=EMPTY_VALUE; }
     }
   for(int i=start;i>=1;i--)
     {
      BullSWIS[i]=EMPTY_VALUE; BearSWIS[i]=EMPTY_VALUE; BuySignal[i]=EMPTY_VALUE; SellSignal[i]=EMPTY_VALUE;
      if(i+reserve<rates_total) ProcessBar(i,i<=LookbackBars,time,open,high,low,close);
      processed=time[i];
     }
   BullSWIS[0]=EMPTY_VALUE; BearSWIS[0]=EMPTY_VALUE; BuySignal[0]=EMPTY_VALUE; SellSignal[0]=EMPTY_VALUE;
   renderBars=MathMin(LookbackBars,rates_total-1);
   RenderHistory();
   return rates_total;
  }
//+------------------------------------------------------------------+
