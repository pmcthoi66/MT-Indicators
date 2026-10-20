// GannSwing_Clear: independent implementation, NOT recovered EX5 source.
// Reference: https://vn.tradingview.com/script/2QUxfCFB/ (protected source).
// Independent directional Gann-style bars + optional ATR reversal filter.
// This is not an exact port of the protected TradingView indicator.
// Only CLOSED candles are processed. Confirmed pivots never move during
// continuous operation. Changing settings / replacing history rebuilds them.
// Default fast ABC: track C until a CLOSED directional reversal candle.
// InpFastStructure=false restores confirmation by a CLOSED break of B.
// Up: A=peak, B=trough, C=peak. Down is symmetric.
// Entry target is C ONLY: SELL at confirmed C peak, BUY at confirmed C trough.
// Updating the next B anchor never emits an entry, including live preview.
// Rolling lifecycle: confirmed C -> new A only on a CLOSED directional pullback.
// Old B remains until a NEW pullback B is confirmed by the Gann turn rule.
// InpUseABC=false restores the previous Gann-confirmation entry engine.
// Buffers 1/2 mark the historical extreme, NOT an entry available at that time.
// Buffers 3/4 give the peak/trough price on the actual confirmation candle.
#property strict
#property version "2.23"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots 7
#property indicator_label1 "Confirmed swing"
#property indicator_type1 DRAW_SECTION
#property indicator_color1 clrSlateGray
#property indicator_style1 STYLE_DOT
#property indicator_width1 1
#property indicator_label2 "Confirmed peak"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrTomato
#property indicator_width2 2
#property indicator_label3 "Confirmed trough"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrLimeGreen
#property indicator_width3 2
#property indicator_label4 "Peak confirmed NOW"
#property indicator_type4 DRAW_NONE
#property indicator_label5 "Trough confirmed NOW"
#property indicator_type5 DRAW_NONE
#property indicator_label6 "BUY (closed-bar confirmation)"
#property indicator_type6 DRAW_ARROW
#property indicator_color6 clrLimeGreen
#property indicator_width6 2
#property indicator_label7 "SELL (closed-bar confirmation)"
#property indicator_type7 DRAW_ARROW
#property indicator_color7 clrTomato
#property indicator_width7 2

input bool   InpLiveDirection=true;     // Mui ten SOM tam tren nen dang chay; co the mat truoc dong nen
input bool   InpFastStructure=true;     // Nhan huong sau 1 nen doi huong; OFF = cho gia DONG pha B
input bool   InpUseABC=true;            // ABC: khoa A/B, xac nhan C khi gia DONG pha B
input int    InpKeepWaves=2;            // Giu 2 song da xac nhan; khi C xong tam hien 3 song
input int    InpStructureBreakPoints=0; // Khoang gia DONG vuot B (points)
input bool   InpShowEntries=true;       // Bat/tat mui ten BUY/SELL tai nen xac nhan
input bool   InpFilterEntryWave=false;   // Chi dung khi InpUseABC=false
input int    InpMinEntryWaveBars=3;     // Khoang cach 2 cuc tri >= 3 nen, khong cho them sau cuc tri
input double InpMinEntryWaveATR=1.20;   // Bien do song >= 1.2 ATR tai cuc tri vua xac nhan
input double InpEntryGapATR=0.20;       // Khoang cach mui ten voi nen, theo ATR
input bool   InpEnabled=true;           // Bat/tat toan bo chi bao
input int    InpTurnBars=1;             // Gann: tim A/B ban dau, hoac che do cu
input bool   InpUseATRFilter=false;      // Loc song nho bang ATR
input int    InpATRPeriod=14;           // Chu ky ATR
input double InpReversalATR=0.8;        // Gia dong dao chieu >= ATR tai cuc tri
input int    InpMinReversalPoints=0;    // Khoang dao chieu toi thieu (points)
input bool   InpShowHistory=false;       // Hien thi lich su
input int    InpRecentPivots=6;         // So dinh/day khi tat lich su
input bool   InpShowProvisional=true;   // Net dut + diem TAM, co the di chuyen
input bool   InpShowLabels=true;        // Nhan DINH / DAY + gia
input int    InpLabelCount=6;           // Chi gan nhan cho cac diem gan nhat
input int    InpInitialBars=10000;      // So nen khoi tao; nen moi xu ly tang dan
input color  InpLineColor=clrSlateGray;
input color  InpPeakColor=clrTomato;
input color  InpTroughColor=clrLimeGreen;
input color  InpTemporaryColor=clrSilver;

// Buffer order for iCustom: 0=line, 1=peak, 2=trough,
// 3=peak confirmation, 4=trough confirmation,
// 5=BUY arrow price, 6=SELL arrow price. EMPTY_VALUE = no event.
// Entry arrows are drawn on the CLOSED confirmation candle; available from
// the first tick of the following candle. Arrow Y is a drawing coordinate,
// NOT an execution price. No orders are sent by this indicator.
double Swing[],Peaks[],Troughs[],PeakNow[],TroughNow[],BuyEntries[],SellEntries[];
struct Pivot { int confirmation_index; int index; datetime at; datetime confirmed; double price; int kind; };
Pivot recent[];
string prefix;
int direction=0,turns=0,extreme_index=-1,opposite_index=-1,processed=-1,atr_count=0;
double extreme=0,opposite=0,extreme_atr=0,opposite_atr=0,atr=0;
datetime oldest=0,last_closed=0;
bool abc_seeded=false,abc_armed=false,abc_bootstrap=false;
int abc_direction=0,abc_event_index=-1;
int abc_c_turns=0;
double abc_c_atr=0;
int abc_phase=0,abc_seed_count=0,abc_b_turns=0; // 0=find C, 1=C fixed, 2=wait new B
Pivot abc_lead,warmup_origin;
double abc_tail_atr=0,abc_pending_atr=0;
Pivot abc_a,abc_b,abc_c,abc_tail,abc_event_a,abc_event_b,abc_event_c;
Pivot abc_points[];
int abc_entries[],abc_rendered[];

void CleanObjects() { if(prefix!="") ObjectsDeleteAll(0,prefix); }
void ResetState()
{
   direction=0; turns=0; extreme_index=-1; opposite_index=-1;
   processed=-1; atr=0; atr_count=0; oldest=0; last_closed=0;
   ArrayResize(recent,0); CleanObjects();
   abc_seeded=false; abc_armed=false; abc_bootstrap=false; abc_direction=0; abc_event_index=-1;
   abc_c.index=-1; abc_tail.index=-1; warmup_origin.index=-1; abc_phase=0; abc_seed_count=0; abc_b_turns=0;
   abc_tail_atr=0; abc_pending_atr=0; abc_c_turns=0; abc_c_atr=0;
   ArrayResize(abc_points,0); ArrayResize(abc_entries,0); ArrayResize(abc_rendered,0);
   ArrayInitialize(Swing,EMPTY_VALUE); ArrayInitialize(Peaks,EMPTY_VALUE);
   ArrayInitialize(Troughs,EMPTY_VALUE); ArrayInitialize(PeakNow,EMPTY_VALUE);
   ArrayInitialize(TroughNow,EMPTY_VALUE);
   ArrayInitialize(BuyEntries,EMPTY_VALUE); ArrayInitialize(SellEntries,EMPTY_VALUE);
}

int OnInit()
{
   if(InpKeepWaves<2 || InpKeepWaves>100 || InpStructureBreakPoints<0 || InpTurnBars<1 || InpTurnBars>20 || InpATRPeriod<1 || InpReversalATR<0 ||
      InpMinReversalPoints<0 || InpRecentPivots<2 || InpRecentPivots>100 ||
      InpMinEntryWaveBars<1 || InpMinEntryWaveATR<0 || InpEntryGapATR<0 || InpLabelCount<0 || InpLabelCount>100 || InpInitialBars<100)
      return INIT_PARAMETERS_INCORRECT;
   prefix="GS_Clear_"+IntegerToString(ChartID())+"_"+
          IntegerToString((long)GetMicrosecondCount())+"_";
   SetIndexBuffer(0,Swing,INDICATOR_DATA);
   SetIndexBuffer(1,Peaks,INDICATOR_DATA);
   SetIndexBuffer(2,Troughs,INDICATOR_DATA);
   SetIndexBuffer(3,PeakNow,INDICATOR_DATA);
   SetIndexBuffer(4,TroughNow,INDICATOR_DATA);
   SetIndexBuffer(5,BuyEntries,INDICATOR_DATA);
   SetIndexBuffer(6,SellEntries,INDICATOR_DATA);
   ArraySetAsSeries(Swing,false); ArraySetAsSeries(Peaks,false);
   ArraySetAsSeries(Troughs,false); ArraySetAsSeries(PeakNow,false);
   ArraySetAsSeries(TroughNow,false);
   ArraySetAsSeries(BuyEntries,false); ArraySetAsSeries(SellEntries,false);
   for(int p=0;p<7;p++) PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,InpUseABC?clrSlateGray:InpLineColor);
   PlotIndexSetInteger(0,PLOT_LINE_STYLE,STYLE_DOT);
   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,1);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,InpPeakColor);
   PlotIndexSetInteger(2,PLOT_LINE_COLOR,InpTroughColor);
   // Circles mark historical extremes; ONLY entry plots use directional arrows.
   PlotIndexSetInteger(1,PLOT_ARROW,159);
   PlotIndexSetInteger(2,PLOT_ARROW,159);
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,0);
   PlotIndexSetInteger(2,PLOT_ARROW_SHIFT,0);
   PlotIndexSetInteger(5,PLOT_ARROW,233);
   PlotIndexSetInteger(6,PLOT_ARROW,234);
   PlotIndexSetInteger(5,PLOT_LINE_COLOR,InpTroughColor);
   PlotIndexSetInteger(6,PLOT_LINE_COLOR,InpPeakColor);
   PlotIndexSetInteger(5,PLOT_ARROW_SHIFT,0);
   PlotIndexSetInteger(6,PLOT_ARROW_SHIFT,0);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,InpFastStructure?"Gann Swing Clear ABC FAST":"Gann Swing Clear ABC STRUCTURE");
   return INIT_SUCCEEDED;
}

void ConfirmPivot(const int kind,const int index,const double price,
                  const int now,const datetime &time[],const double entry_marker)
{
   if(index<0 || index>=now) return;
   if(InpUseABC) { SeedABC(kind,index,price,now,time); return; }
   int n=ArraySize(recent);
   if(n>0 && index<=recent[n-1].index) return;
   Swing[index]=price;
   if(kind>0) { Peaks[index]=price; PeakNow[now]=price; }
   else       { Troughs[index]=price; TroughNow[now]=price; }
   bool wave_ok=true;
   if(InpFilterEntryWave)
   {
      // Measure the completed wave BEFORE adding its endpoint. The first pivot
      // has no preceding wave, so it cannot qualify. No extra confirmation delay.
      wave_ok=false;
      if(n>0)
      {
         int wave_bars=index-recent[n-1].index;
         double wave_range=MathAbs(price-recent[n-1].price);
         double required=InpMinEntryWaveATR*MathMax(extreme_atr,_Point);
         wave_ok=(wave_bars>=InpMinEntryWaveBars && wave_range>=required);
      }
   }
   if(InpShowEntries && wave_ok)
   {
      if(kind>0) SellEntries[now]=entry_marker;
      else       BuyEntries[now]=entry_marker;
   }
   ArrayResize(recent,n+1);
   recent[n].confirmation_index=now; recent[n].index=index; recent[n].at=time[index];
   recent[n].confirmed=time[now]; recent[n].price=price; recent[n].kind=kind;
   int keep=(InpShowHistory ? MathMax(1,InpLabelCount) : InpRecentPivots);
   if(n+1>keep)
   {
      if(!InpShowHistory)
      {
         int old=recent[0].index;
         Swing[old]=EMPTY_VALUE; Peaks[old]=EMPTY_VALUE; Troughs[old]=EMPTY_VALUE;
         int old_entry=recent[0].confirmation_index;
         BuyEntries[old_entry]=EMPTY_VALUE; SellEntries[old_entry]=EMPTY_VALUE;
         // Event buffers 3/4 retain causal events regardless of display history.
      }
      for(int k=1;k<=n;k++) recent[k-1]=recent[k];
      ArrayResize(recent,n);
   }
}

// ABC mode locks A/B. Internal Gann pivots only initialize the first A/B pair.
void AddABCPivot(const Pivot &p)
{
   int n=ArraySize(abc_points);
   ArrayResize(abc_points,n+1); abc_points[n]=p;
   Swing[p.index]=p.price;
   if(p.kind>0) Peaks[p.index]=p.price; else Troughs[p.index]=p.price;
   TrimABCPivots(InpKeepWaves+(abc_phase==1?2:1));
}

void TrimABCPivots(const int keep)
{
   while(ArraySize(abc_points)>keep)
   {
      int n=ArraySize(abc_points);
      if(!InpShowHistory)
      { int old=abc_points[0].index; Swing[old]=Peaks[old]=Troughs[old]=EMPTY_VALUE; }
      for(int k=1;k<n;k++) abc_points[k-1]=abc_points[k];
      ArrayResize(abc_points,n-1);
   }
}

int ABCBarDirection(const int i,const double &high[],const double &low[],const double &close[])
{
   if(high[i]>high[i-1] && low[i]<low[i-1])
      return(close[i]>close[i-1]?1:(close[i]<close[i-1]?-1:0));
   if(high[i]>high[i-1] && low[i]>=low[i-1]) return 1;
   if(low[i]<low[i-1] && high[i]<=high[i-1]) return -1;
   return 0;
}

void InitABCFromB(const int now,const double &high[],const double &low[],const datetime &time[])
{
   abc_c.index=-1; abc_tail.index=-1; abc_c_turns=0; abc_c_atr=atr;
   for(int k=abc_b.index+1;k<=now;k++)
   {
      if(abc_c.index<0 || (abc_direction>0?high[k]>abc_c.price:low[k]<abc_c.price))
      {
         abc_c.index=k; abc_c.at=time[k]; abc_c.kind=abc_direction;
         abc_c.price=(abc_direction>0?high[k]:low[k]); abc_tail.index=-1;
      }
      else if(k>abc_c.index && (abc_tail.index<0 || (abc_direction>0?low[k]<abc_tail.price:high[k]>abc_tail.price)))
      {
         abc_tail.index=k; abc_tail.at=time[k]; abc_tail.kind=-abc_direction;
         abc_tail.price=(abc_direction>0?low[k]:high[k]); abc_tail_atr=atr;
      }
   }
}

// After confirmed C: only C -> A. Keep the OLD B until the new pullback fixes B.
void TrackABCEntry(const int i)
{
   int n=ArraySize(abc_entries); ArrayResize(abc_entries,n+1); abc_entries[n]=i;
   if(n+1>InpKeepWaves)
   {
      if(!InpShowHistory)
         BuyEntries[abc_entries[0]]=SellEntries[abc_entries[0]]=EMPTY_VALUE;
      for(int k=1;k<=n;k++) abc_entries[k-1]=abc_entries[k];
      ArrayResize(abc_entries,n);
   }
}

void ProcessNewB(const int i,const double &high[],const double &low[],
                 const double &close[],const datetime &time[])
{
   int seek=-abc_direction;
   if(i<=abc_a.index) return;
   if(abc_c.index<0 || (seek>0?high[i]>abc_c.price:low[i]<abc_c.price))
   {
      abc_c.index=i; abc_c.at=time[i]; abc_c.kind=seek;
      abc_c.price=(seek>0?high[i]:low[i]); abc_pending_atr=atr; abc_b_turns=0;
      return;
   }
   int bar=ABCBarDirection(i,high,low,close);
   if(bar==-seek) abc_b_turns++;
   else if(bar==seek) abc_b_turns=0;
   double need=InpMinReversalPoints*_Point;
   if(InpUseATRFilter) need=MathMax(need,InpReversalATR*abc_pending_atr);
   double retreat=(seek>0?abc_c.price-close[i]:close[i]-abc_c.price);
   if(abc_b_turns<InpTurnBars || retreat<need || i<=abc_c.index) return;
   abc_c.confirmed=time[i]; abc_c.confirmation_index=i;
   abc_b=abc_c; // Replace B ONLY now; its old label moves, no duplicate B.
   abc_phase=0; AddABCPivot(abc_b);
   // B is an anchor update ONLY. No entry/event is emitted for B.
   InitABCFromB(i,high,low,time);
}

void SeedABC(const int kind,const int index,const double price,
             const int now,const datetime &time[])
{
   Pivot p; p.index=index; p.price=price; p.kind=kind;
   p.at=time[index]; p.confirmed=time[now]; p.confirmation_index=now;
   // Initial history pass collects the MOST RECENT Gann pivots, rather than
   // locking the oldest A/B pair thousands of candles off-screen.
   int n=ArraySize(abc_points);
   if(n>0 && index<=abc_points[n-1].index) return;
   AddABCPivot(p);
   n=ArraySize(abc_points); abc_seed_count=n;
   if(abc_bootstrap || n<2) return;
   abc_a=abc_points[n-2]; abc_b=abc_points[n-1];
   if(n>=3) abc_lead=abc_points[n-3];
   abc_direction=-abc_b.kind; abc_armed=true; abc_seeded=true; abc_phase=0;
   abc_c.index=-1; abc_tail.index=-1;
}

void ProcessABC(const int i,const double &high[],const double &low[],
                const double &close[],const datetime &time[])
{
   if(!abc_armed || i<=abc_b.index) return;
   if(abc_phase==1)
   {
      if(i<=abc_event_index) return;
      // A new candle alone must not roll C -> A. Wait for an actual
      // directional pullback away from the completed C extreme.
      int bar=ABCBarDirection(i,high,low,close);
      // Preserve EVERY closed opposite extreme while C is displayed.
      // The C confirmation candle may already contain the deepest pullback.
      if(abc_tail.index<0 || (abc_direction>0?low[i]<abc_tail.price:high[i]>abc_tail.price))
      {
         abc_tail.index=i; abc_tail.at=time[i]; abc_tail.kind=-abc_direction;
         abc_tail.price=(abc_direction>0?low[i]:high[i]); abc_tail_atr=atr;
      }
      bool pullback=(bar==-abc_direction &&
                     (abc_direction>0?close[i]<abc_event_c.price:close[i]>abc_event_c.price));
      // If the pullback already turns back, hand it to ProcessNewB NOW;
      // waiting for another opposite bar would skip B and the following C.
      bool rebound=(bar==abc_direction && abc_tail.index<i);
      if(!pullback && !rebound) return;
      abc_a=abc_event_c; // C -> A, same direction; do NOT rotate old B -> A.
      abc_c=abc_tail; abc_pending_atr=abc_tail_atr; abc_tail.index=-1;
      abc_phase=2; abc_b_turns=0; TrimABCPivots(InpKeepWaves+1);
   }
   if(abc_phase==2) { ProcessNewB(i,high,low,close,time); return; }
   bool extended=(abc_c.index<0 ||
                 (abc_direction>0?high[i]>abc_c.price:low[i]<abc_c.price));
   if(extended)
   {
      abc_c.index=i; abc_c.at=time[i]; abc_c.kind=abc_direction;
      abc_c.price=(abc_direction>0?high[i]:low[i]); abc_c_turns=0; abc_c_atr=atr;
      // Opposite tail starts AFTER the C candle; no assumed intrabar ordering.
      abc_tail.index=-1;
   }
   else if(i>abc_c.index && (abc_tail.index<0 ||
           (abc_direction>0?low[i]<abc_tail.price:high[i]>abc_tail.price)))
   {
      abc_tail.index=i; abc_tail.at=time[i]; abc_tail.kind=-abc_direction;
      abc_tail.price=(abc_direction>0?low[i]:high[i]); abc_tail_atr=atr;
   }
   double gap=InpStructureBreakPoints*_Point;
   bool broken=(abc_direction>0?close[i]<abc_b.price-gap:close[i]>abc_b.price+gap);
   if(InpFastStructure)
   {
      int bar=ABCBarDirection(i,high,low,close);
      if(!extended && bar==-abc_direction) abc_c_turns++;
      else if(bar==abc_direction) abc_c_turns=0;
      double need=InpMinReversalPoints*_Point;
      if(InpUseATRFilter) need=MathMax(need,InpReversalATR*abc_c_atr);
      double retreat=(abc_direction>0?abc_c.price-close[i]:close[i]-abc_c.price);
      broken=(!extended && i>abc_c.index && abc_c_turns>=InpTurnBars && retreat>=need);
   }
   if(!broken || abc_c.index<=abc_b.index) return;
   abc_c.confirmed=time[i]; abc_c.confirmation_index=i;
   abc_event_a=abc_a; abc_event_b=abc_b; abc_event_c=abc_c; abc_event_index=i;
   abc_phase=1; AddABCPivot(abc_c);
   double marker_gap=MathMax(10*_Point,InpEntryGapATR*atr);
   if(abc_direction>0)
   {
      PeakNow[i]=abc_c.price;
      if(InpShowEntries) SellEntries[i]=high[i]+marker_gap;
   }
   else
   {
      TroughNow[i]=abc_c.price;
      if(InpShowEntries) BuyEntries[i]=low[i]-marker_gap;
   }
   TrackABCEntry(i);
   // Keep completed A-B-C visible on this confirmation candle. The next
   // closed pullback candle rolls only C -> A and starts searching a NEW B.
}

// Show honest provisional geometry during startup; never manufacture entries.
void DrawABCWarmup(const datetime &time[])
{
   int n=ArraySize(abc_points);
   int idx=extreme_index;
   if(idx<0) return;
   if(InpShowLabels)
      TextAt("ABC_warmup",time[idx],extreme,"DANG TIM A/B",InpTemporaryColor,
             direction>0,"Waiting for at least two confirmed Gann pivots");
   string name=prefix+"ABC_leg";
   if(!InpShowProvisional) { ObjectDelete(0,name); return; }
   int start=-1; double price=0;
   if(n>0) { start=abc_points[n-1].index; price=abc_points[n-1].price; }
   else if(warmup_origin.index>=0) { start=warmup_origin.index; price=warmup_origin.price; }
   if(start<0 || start>=idx) { ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,time[start],price,time[idx],extreme);
   else { ObjectMove(0,name,0,time[start],price); ObjectMove(0,name,1,time[idx],extreme); }
   ObjectSetInteger(0,name,OBJPROP_COLOR,InpTemporaryColor);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawABC(const datetime &time[])
{
   if(!abc_armed) { DrawABCWarmup(time); return; }
   ObjectDelete(0,prefix+"ABC_warmup");
   if(!InpShowHistory)
   {
      for(int k=0;k<ArraySize(abc_rendered);k++)
      {
         int idx=abc_rendered[k]; Swing[idx]=Peaks[idx]=Troughs[idx]=EMPTY_VALUE;
      }
      int n=ArraySize(abc_points);
      int count=MathMin(n,abc_phase==1?InpKeepWaves+2:InpKeepWaves+1);
      ArrayResize(abc_rendered,count);
      for(int k=0;k<count;k++)
      {
         Pivot p=abc_points[n-count+k]; abc_rendered[k]=p.index;
         Swing[p.index]=p.price;
         if(p.kind>0) Peaks[p.index]=p.price; else Troughs[p.index]=p.price;
      }
   }
   Pivot a=abc_a,b=abc_b,c=abc_c;
   if(abc_phase==1) { a=abc_event_a; b=abc_event_b; c=abc_event_c; }
   if(InpShowLabels)
   {
      double pad=MathMax(_Point*10,atr*0.12);
      TextAt("ABC_A",a.at,a.price+(a.kind>0?pad:-pad),"A",
             a.kind>0?InpPeakColor:InpTroughColor,a.kind>0,"Locked structure anchor A");
      TextAt("ABC_B",b.at,b.price+(b.kind>0?pad:-pad),"B",
             b.kind>0?InpPeakColor:InpTroughColor,b.kind>0,InpFastStructure?"Fast: next directional bar confirms the extreme":"Close must break B to confirm C");
      if(abc_phase==2)
      {
         ObjectDelete(0,prefix+"ABC_C");
         if(c.index>=0 && InpShowProvisional)
            TextAt("ABC_pending_B",c.at,c.price+(c.kind>0?pad:-pad),"B?",InpTemporaryColor,
                   c.kind>0,"New pullback B pending; old B remains until confirmation");
         else ObjectDelete(0,prefix+"ABC_pending_B");
      }
      else if(c.index>=0 && (abc_phase==1 || InpShowProvisional))
         TextAt("ABC_C",c.at,c.price+(c.kind>0?pad:-pad),abc_phase==1?"C":"C?",
                abc_phase==1?(c.kind>0?InpPeakColor:InpTroughColor):InpTemporaryColor,c.kind>0,
                abc_phase==1?(InpFastStructure?"C fixed by a CLOSED directional reversal":"C confirmed by a CLOSED candle breaking B"):(InpFastStructure?"C pending directional reversal":"Unconfirmed C; can move until B breaks"));
      else ObjectDelete(0,prefix+"ABC_C");
      if(abc_phase!=2) ObjectDelete(0,prefix+"ABC_pending_B");
   }
   if(abc_phase==2) b=a; // New pullback starts at NEW A, never at old B.
   string name=prefix+"ABC_leg";
   if(abc_phase==1 || !InpShowProvisional || c.index<0 || c.index<=b.index)
   { ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,b.at,b.price,c.at,c.price);
   else { ObjectMove(0,name,0,b.at,b.price); ObjectMove(0,name,1,c.at,c.price); }
   ObjectSetInteger(0,name,OBJPROP_COLOR,InpTemporaryColor);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void TextAt(const string suffix,const datetime at,const double price,
            const string text,const color col,const bool peak,const string tooltip)
{
   string name=prefix+suffix;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,at,price);
   else ObjectMove(0,name,0,at,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,peak?ANCHOR_LOWER:ANCHOR_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawExtras(const datetime &time[])
{
   if(InpUseABC) { DrawABC(time); return; }
   int n=ArraySize(recent),count=(InpShowLabels?MathMin(InpLabelCount,n):0);
   for(int j=0;j<count;j++)
   {
      int k=n-count+j;
      bool peak=recent[k].kind>0;
      double pad=MathMax(_Point*10,atr*0.12);
      string title=(peak?"DINH ":"DAY ")+DoubleToString(recent[k].price,_Digits);
      TextAt("label_"+IntegerToString(j),recent[k].at,
             recent[k].price+(peak?pad:-pad),title,
             peak?InpPeakColor:InpTroughColor,peak,
             "Confirmed after candle "+TimeToString(recent[k].confirmed,TIME_DATE|TIME_MINUTES)+
             " closed. Extreme marker is NOT an earlier entry signal.");
   }
   // Labels are bounded; no historical text objects per candle.
   for(int j=count;j<MathMax(InpLabelCount,InpRecentPivots);j++)
      ObjectDelete(0,prefix+"label_"+IntegerToString(j));
   if(!InpShowProvisional || direction==0 || extreme_index<0)
   {
      ObjectDelete(0,prefix+"temp"); ObjectDelete(0,prefix+"leg"); return;
   }
   bool peak=direction>0;
   double pad=MathMax(_Point*10,atr*0.12);
   TextAt("temp",time[extreme_index],extreme+(peak?pad:-pad),
          peak?"DINH TAM":"DAY TAM",InpTemporaryColor,peak,
          "Unconfirmed; can move on the next CLOSED candle.");
   if(n>0 && time[extreme_index]>recent[n-1].at)
   {
      string name=prefix+"leg";
      if(ObjectFind(0,name)<0)
         ObjectCreate(0,name,OBJ_TREND,0,recent[n-1].at,recent[n-1].price,
                      time[extreme_index],extreme);
      else
      {
         ObjectMove(0,name,0,recent[n-1].at,recent[n-1].price);
         ObjectMove(0,name,1,time[extreme_index],extreme);
      }
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpTemporaryColor);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   else ObjectDelete(0,prefix+"leg");
}

// Live preview is an OBJECT only, never a historical/EA confirmation event.
void DrawLiveDirection(const int rates_total,const datetime &time[],const double &high[],
                       const double &low[],const double &close[])
{
   string name=prefix+"EARLY";
   if(!InpEnabled || !InpFastStructure || !InpUseABC || !InpLiveDirection || !InpShowEntries || !abc_armed || abc_phase!=0)
   { ObjectDelete(0,name); return; }
   int i=rates_total-1,seek=abc_direction,count=abc_c_turns;
   double threshold_atr=abc_c_atr;
   Pivot p=abc_c;
   if(p.index<0 || p.index>=i || ABCBarDirection(i,high,low,close)!=-seek ||
      (seek>0?high[i]>p.price:low[i]<p.price))
   { ObjectDelete(0,name); return; }
   double need=InpMinReversalPoints*_Point;
   if(InpUseATRFilter) need=MathMax(need,InpReversalATR*threshold_atr);
   double retreat=(seek>0?p.price-close[i]:close[i]-p.price);
   if(count+1<InpTurnBars || retreat<need) { ObjectDelete(0,name); return; }
   bool buy=(seek<0);
   double pad=MathMax(10*_Point,InpEntryGapATR*atr);
   double y=(buy?low[i]-pad:high[i]+pad);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,time[i],y);
   else ObjectMove(0,name,0,time[i],y);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,buy?233:234);
   ObjectSetInteger(0,name,OBJPROP_COLOR,buy?InpTroughColor:InpPeakColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"EARLY live preview; may disappear before candle close. Not a confirmed entry.");
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   ArraySetAsSeries(time,false); ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
   if(rates_total<3) return 0;
   if(!InpEnabled)
   {
      if(prev_calculated==0) ResetState();
      else for(int j=MathMax(0,prev_calculated-1);j<rates_total;j++)
         Swing[j]=Peaks[j]=Troughs[j]=PeakNow[j]=TroughNow[j]=BuyEntries[j]=SellEntries[j]=EMPTY_VALUE;
      return rates_total;
   }
   bool reset=(prev_calculated==0 || processed<0 || prev_calculated>rates_total ||
               oldest!=time[0]);
   if(!reset && (processed>=rates_total-1 || time[processed]!=last_closed)) reset=true;
   if(reset)
   {
      ResetState(); oldest=time[0]; abc_bootstrap=InpUseABC;
   }
   // Explicitly initialize newly allocated positions, including the live candle.
   int clear_from=reset?rates_total:MathMax(0,prev_calculated-1);
   for(int j=clear_from;j<rates_total;j++)
      Swing[j]=Peaks[j]=Troughs[j]=PeakNow[j]=TroughNow[j]=BuyEntries[j]=SellEntries[j]=EMPTY_VALUE;
   int end=rates_total-2; // NEVER process bar 0 / the live candle
   if(!reset && processed==end)
   { DrawLiveDirection(rates_total,time,high,low,close); return rates_total; }
   int begin=reset?MathMax(1,end-InpInitialBars+1):processed+1;
   for(int i=begin;i<=end;i++)
   {
      double tr=MathMax(high[i]-low[i],MathMax(MathAbs(high[i]-close[i-1]),
                                             MathAbs(low[i]-close[i-1])));
      atr_count++;
      if(atr_count<=InpATRPeriod) atr+=(tr-atr)/atr_count;
      else atr=(atr*(InpATRPeriod-1)+tr)/InpATRPeriod;
      if(InpUseABC && abc_armed && !abc_bootstrap)
      { ProcessABC(i,high,low,close,time); continue; }
      // Inside bars ignored. Outside bars use CLOSE to choose direction;
      // a bar extending the candidate cannot also confirm that candidate.
      bool outside=(high[i]>high[i-1] && low[i]<low[i-1]);
      int bar=0;
      if(outside) bar=(close[i]>close[i-1]?1:(close[i]<close[i-1]?-1:0));
      else if(high[i]>high[i-1] && low[i]>=low[i-1]) bar=1;
      else if(low[i]<low[i-1] && high[i]<=high[i-1]) bar=-1;
      if(direction==0)
      {
         if(bar==0) continue;
         if(InpUseABC && warmup_origin.index<0)
         {
            warmup_origin.index=i-1; warmup_origin.at=time[i-1];
            warmup_origin.price=(bar>0?low[i-1]:high[i-1]); warmup_origin.kind=-bar;
         }
         direction=bar; extreme=(bar>0?high[i]:low[i]); extreme_index=i;
         extreme_atr=atr; opposite=(bar>0?low[i]:high[i]); opposite_index=i; opposite_atr=atr;
         continue;
      }
      bool extended=(direction>0?high[i]>=extreme:low[i]<=extreme);
      if(extended)
      {
         extreme=(direction>0?high[i]:low[i]); extreme_index=i; extreme_atr=atr;
         opposite=(direction>0?low[i]:high[i]); opposite_index=i; opposite_atr=atr; turns=0;
         continue;
      }
      // Track the opposite extreme AFTER the candidate, not merely at confirmation.
      if(opposite_index==extreme_index ||
         (direction>0?low[i]<=opposite:high[i]>=opposite))
      { opposite=(direction>0?low[i]:high[i]); opposite_index=i; opposite_atr=atr; }
      if(bar==-direction) turns++;
      else if(bar==direction) turns=0;
      double need=InpMinReversalPoints*_Point;
      if(InpUseATRFilter) need=MathMax(need,InpReversalATR*extreme_atr);
      double retreat=(direction>0?extreme-close[i]:close[i]-extreme);
      if(turns>=InpTurnBars && retreat>=need && i>extreme_index &&
         opposite_index>extreme_index)
      {
         double entry_gap=MathMax(10*_Point,InpEntryGapATR*atr);
         double marker=(direction>0?high[i]+entry_gap:low[i]-entry_gap);
         ConfirmPivot(direction,extreme_index,extreme,i,time,marker);
         if(InpUseABC && abc_armed && !abc_bootstrap)
         {
            InitABCFromB(i,high,low,time);
            ProcessABC(i,high,low,close,time);
         }
         direction=-direction; extreme=opposite; extreme_index=opposite_index;
         // Use ATR from the opposite extreme candle, not a future candle.
         extreme_atr=opposite_atr; turns=0;
         opposite=(direction>0?low[i]:high[i]); opposite_index=i; opposite_atr=atr;
      }
   }
   if(abc_bootstrap)
   {
      abc_bootstrap=false;
      int n=ArraySize(abc_points);
      if(n>=2)
      {
         abc_a=abc_points[n-2]; abc_b=abc_points[n-1];
         if(n>=3) abc_lead=abc_points[n-3];
         abc_direction=-abc_b.kind; abc_armed=true; abc_seeded=true; abc_phase=0;
         InitABCFromB(end,high,low,time);
         ProcessABC(end,high,low,close,time);
      }
   }
   processed=end; last_closed=time[end];
   DrawExtras(time);
   DrawLiveDirection(rates_total,time,high,low,close);
   return rates_total;
}

void OnDeinit(const int reason)
{
   CleanObjects(); ArrayFree(recent); ArrayFree(abc_points);
   ArrayFree(abc_entries); ArrayFree(abc_rendered); ChartRedraw(0);
   // MT5 owns and releases indicator buffers. No timers or indicator handles.
}
