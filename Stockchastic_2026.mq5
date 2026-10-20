//+------------------------------------------------------------------+
//|                                      WatchDog_Indicator_v2_64_DisplayFix.mq5 |
//|                                      Copyright 2026, Advanced Engine |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Advanced Engine"
#property version   "2.64"
#property description "Closed-pivot divergence; exact Stochastic %K endpoints; retry-safe buffers"
#property strict

//--- Indicator window
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   6

//--- Plot 1: Stoch %K
#property indicator_label1  "Stoch %K"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: Stoch %D
#property indicator_label2  "Stoch %D"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: Close Buy
#property indicator_label3  "Close Buy Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrOrangeRed
#property indicator_width3  2

//--- Plot 4: Close Sell
#property indicator_label4  "Close Sell Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLimeGreen
#property indicator_width4  2

//--- Plot 5: Bullish Divergence
#property indicator_label5  "Bullish Regular/Hidden Div"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrDodgerBlue
#property indicator_width5  2

//--- Plot 6: Bearish Divergence
#property indicator_label6  "Bearish Regular/Hidden Div"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrDeepPink
#property indicator_width6  2


//+------------------------------------------------------------------+
//| Stochastic zone mode                                             |
//+------------------------------------------------------------------+
enum ENUM_STOCH_ZONE_MODE
  {
   Crossing = 0,
   Entering = 1,
   Exiting  = 2
  };


//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== POWER ==="
input bool InpEnabled = true; // OFF: no calculation handles, plots or levels
input group "=== HIEN THI / DANH GIA ==="
input bool InpShowHistory = false; // OFF: newest RSI pair per TF, newest Stoch pair/exit
input bool InpHideHiddenDiv = true; // An phan ky an tren ca RSI va Stoch
input bool InpStrengthTooltip = true;
int g_latestSignals[4]={-1,-1,-1,-1};



input group "=== STOCHASTIC PARAMETERS ==="

input int                  InpKPeriod        = 14;
input int                  InpDPeriod        = 3;
input int                  InpSlowing        = 3;
input int                  InpOverSold       = 20;
input int                  InpOverBought     = 80;


input group "=== SIGNAL ACCURACY & REPAINT FILTER ==="

input ENUM_STOCH_ZONE_MODE Stoch_Zone_Mode   = Crossing;
input bool                 InpConfirmOnClose = true; // Exit marks only; divergence always uses closed bars


input group "=== DIVERGENCE ENGINE SETTINGS ==="

input bool   InpEnableDiv      = true;
input int    InpLeftBars       = 2;
input int    InpRightBars      = 2;
input int    InpMinBars        = 1;
input int    InpMaxBars        = 50;
input double InpMinStochDiff   = 1.5;
input double InpMinAtrFilter   = 0.15;


//+------------------------------------------------------------------+
//| INDICATOR BUFFERS                                                |
//+------------------------------------------------------------------+
double KBuffer[];
double DBuffer[];

double CloseBuySignal[];
double CloseSellSignal[];

double BullishDivBuffer[];
double BearishDivBuffer[];

double SignalStrength[];


//+------------------------------------------------------------------+
//| INDICATOR HANDLES                                                |
//+------------------------------------------------------------------+
int stocHandle = INVALID_HANDLE;
int atrHandle  = INVALID_HANDLE;


//+------------------------------------------------------------------+
//| ATR BUFFER                                                       |
//+------------------------------------------------------------------+
double g_atrBuffer[];


// v2.64: retry-safe incremental updates; divergence only on closed candles.
// Buffer indices 0..5 preserved. Divergence appears at confirmation by default.
input group "=== OPTIONAL FILTERS / DISPLAY ==="
input ENUM_STO_PRICE InpPriceField = STO_CLOSECLOSE; // Preserve v2.1 formula
input int InpATRPeriod = 14;
input bool InpNearestPivotOnly = true; // Avoid searching older pivots until a match
input bool InpDivAtConfirmation = true; // false: back-plot at pivot (known later)
input bool InpDivRequireZone = false;
input double InpMinPriceDiffATR = 0.0; // Minimum price difference between pivots
input bool InpCrossUsePreviousZone = false;
double LowPivot[], HighPivot[];
double tmpK[], tmpD[], tmpATR[];
datetime g_first=0, g_last=0;
int g_off_size=-1;
int g_committedBars=0; // Only advance after a complete successful calculation

input group "=== DIVERGENCE LINES ==="
input bool InpDrawDivLines = true;
input bool InpShowRegularDiv = true;
input bool InpShowHiddenDiv = false;
input bool InpLinesOnPrice = true;
input bool InpLinesOnStoch = true; // Exact %K low-to-low / high-to-high endpoints
input int InpMaxLinePairs = 100; // Latest divergence pairs; bounded object count
input color InpRegularBullColor = clrDodgerBlue;
input color InpRegularBearColor = clrDeepPink;
input color InpHiddenBullColor = clrLimeGreen;
input color InpHiddenBearColor = clrOrange;
// Regular solid, hidden dashed. Lines connect pivots but appear only at confirmation.
struct DivPair
  {
   datetime t1,t2,confirmed;
   double p1,p2,k1,k2;
   int kind; // +1 regular bull, -1 regular bear, +2 hidden bull, -2 hidden bear
   bool dirty;
  };
DivPair g_pairs[];
string g_prefix="";
bool g_lines_pending=false;

string PairName(datetime t)
  { return g_prefix+"S_"+IntegerToString((long)t); }

void DeletePairObjects(datetime t)
  {
   if(g_prefix=="") return;
   string name=PairName(t);
   ObjectDelete(0,name+"P"); ObjectDelete(0,name+"K");
  }

void ClearDivLines()
  {
   if(g_prefix!="") ObjectsDeleteAll(0,g_prefix+"S_");
   ArrayFree(g_pairs); g_lines_pending=false; InvalidateMTFView();
  }

void RemovePair(int index)
  {
   int n=ArraySize(g_pairs);
   DeletePairObjects(g_pairs[index].t2);
   for(int j=index;j<n-1;j++) g_pairs[j]=g_pairs[j+1];
   ArrayResize(g_pairs,n-1);
  }

void StorePair(datetime t1,datetime t2,datetime confirmed,
               double p1,double p2,double k1,double k2,int kind)
  {
   if(!InpDrawDivLines || (!InpLinesOnPrice && !InpLinesOnStoch)) return;
   // Endpoints always use the two actual pivots, never the confirmation bar.
   if(kind!=0 && (t1>=t2 || confirmed<t2 || !ValidStoch(k1) || !ValidStoch(k2))) return;
   int n=ArraySize(g_pairs),index=-1;
   for(int j=n-1;j>=0;j--) if(g_pairs[j].t2==t2) { index=j; break; }
   if(kind==0) { if(index>=0) RemovePair(index); return; }
   if(index>=0 && g_pairs[index].t1==t1 && g_pairs[index].kind==kind &&
      g_pairs[index].p1==p1 && g_pairs[index].p2==p2 &&
      g_pairs[index].k1==k1 && g_pairs[index].k2==k2) return;
   if(index<0)
     {
      if(n>=(InpShowHistory?InpMaxLinePairs:1)) { RemovePair(0); n--; }
      index=n; ArrayResize(g_pairs,n+1);
     }
   g_pairs[index].t1=t1; g_pairs[index].t2=t2; g_pairs[index].confirmed=confirmed;
   g_pairs[index].p1=p1; g_pairs[index].p2=p2;
   g_pairs[index].k1=k1; g_pairs[index].k2=k2;
   g_pairs[index].kind=kind; g_pairs[index].dirty=true;
   g_lines_pending=true;
  }

bool DrawSegment(string name,int window,datetime t1,double y1,datetime t2,double y2,
                 color col,ENUM_LINE_STYLE style,string tip)
  {
   int existing=ObjectFind(0,name);
   if(existing>=0 && existing!=window)
     { ObjectDelete(0,name); existing=-1; }
   if(existing>=0)
     {
      if(!ObjectMove(0,name,0,t1,y1) || !ObjectMove(0,name,1,t2,y2)) return false;
     }
   else if(!ObjectCreate(0,name,OBJ_TREND,window,t1,y1,t2,y2)) return false;
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   return true;
  }

void RenderDivLines()
  {
   if(!g_lines_pending || !InpEnabled || !InpDrawDivLines) return;
   int window=InpLinesOnStoch?ChartWindowFind():-1;
   bool pending=false;
   for(int j=0;j<ArraySize(g_pairs);j++)
     {
      if(!g_pairs[j].dirty) continue;
      int kind=g_pairs[j].kind;
      color col=kind==1?InpRegularBullColor:kind==-1?InpRegularBearColor:
                kind==2?InpHiddenBullColor:InpHiddenBearColor;
      ENUM_LINE_STYLE style=(kind==2 || kind==-2)?STYLE_DASH:STYLE_SOLID;
      string tip=(kind==1 || kind==-1)?"Regular divergence":"Hidden divergence";
      tip+=(kind>0?" bullish":" bearish");
      tip+=" | Pivot 1: "+TimeToString(g_pairs[j].t1,TIME_DATE|TIME_MINUTES)+
           " K="+DoubleToString(g_pairs[j].k1,2);
      tip+=" | Pivot 2: "+TimeToString(g_pairs[j].t2,TIME_DATE|TIME_MINUTES)+
           " K="+DoubleToString(g_pairs[j].k2,2);
      tip+=" | Known after candle close: "+TimeToString(g_pairs[j].confirmed,TIME_DATE|TIME_MINUTES);
      tip+=" | Stochastic %K pivot-to-pivot; not an entry order";
      string name=PairName(g_pairs[j].t2);
      bool ok=true;
      if(InpLinesOnPrice) ok=DrawSegment(name+"P",0,g_pairs[j].t1,g_pairs[j].p1,
                                      g_pairs[j].t2,g_pairs[j].p2,col,style,tip);
      if(InpLinesOnStoch)
        {
         if(window<1) ok=false;
         else if(!DrawSegment(name+"K",window,g_pairs[j].t1,g_pairs[j].k1,
                             g_pairs[j].t2,g_pairs[j].k2,col,style,tip)) ok=false;
        }
      g_pairs[j].dirty=!ok; pending=pending || !ok;
     }
   g_lines_pending=pending;
  }

//====================================================================
// RSI14 MTF - Close pivots only, closed bars only (independent of Stoch).
// Vung di ngang la tieu chi dinh luong, khong khang dinh tich luy mua.
//====================================================================
input group "=== RSI CLOSE MTF / PHAN KY ==="
input bool InpRSIMTF = true;
bool g_rsiMTFEnabled=true;
int g_mtfButtonWindow=-1;
input bool InpRSIM15 = true;
input bool InpRSIH1 = true;
input bool InpRSIH4 = true;
input bool InpRSID1 = true;
input bool InpRSIRegular = true;
input bool InpRSIHidden = false;
input int InpRSILeft = 2;
input int InpRSIRight = 2;
input int InpRSIMinGap = 3;
input int InpRSIMaxGap = 80;
input double InpRSIMinDiff = 1.5;
input int InpRSILookback = 600; // Gioi han du lieu moi khung
input int InpRSIPairsPerTF = 3; // So tin hieu gan nhat / khung
input bool InpRSIPriceLines = true;
input bool InpRSIPaneLines = false; // Optional RSI segments: different oscillator, not the Stochastic curve
input bool InpHoverInfoOnly = true; // An chu giai thich; xem so do bang tooltip khi re chuot
input bool InpRSIMeasureText = false;
input bool InpRSIMTFPanel = false;
input group "=== DO DOAN GIUA HAI PIVOT ==="
input bool InpRSIRangeBoxes = true;
input int InpSidewaysMinBars = 5;
input double InpSidewaysMaxRangeATR = 2.0;
input double InpSidewaysMaxEfficiency = 0.35;
// Hieu suat duong di = abs(Close cuoi - Close dau) / tong abs(delta Close).
// Volume: real only if ALL bars have real volume, otherwise tick for ALL.
ENUM_TIMEFRAMES g_mtfTF[4]={PERIOD_M15,PERIOD_H1,PERIOD_H4,PERIOD_D1};
int g_rsiH[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
int g_rsiAtrH[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
datetime g_mtfOpen[4]={0,0,0,0};
int g_mtfBars[4]={0,0,0,0};
int g_mtfWindow=-1;
ulong g_mtfPoll=0;
MqlRates g_mtfRates[];
double g_mtfRSI[],g_mtfATR[];
int g_mtfPivot[];
struct RSIMTFPair
  {
   int previous,current,kind;
  };
RSIMTFPair g_mtfFound[];

//====================================================================
// V2.60: Xac nhan sau phan ky, boi canh tai thoi diem tin hieu,
// va theo doi pha vo / quay lai vung. Tat ca dung nen da dong.
//====================================================================
input group "=== 1. XAC NHAN STOCH SAU PHAN KY RSI ==="
input bool InpConfirmAfterDiv = true;
input int InpConfirmWaitBars = 5; // Tinh tu nen xac nhan pivot, gom nen do
input bool InpCancelOnPivotCloseBreak = true;
input bool InpDrawConfirmTicks = true;
input group "=== 2. BOI CANH H4 / D1 ==="
input bool InpUseHTFContext = true;
input bool InpContextLineColors = true;
input bool InpBlockCounterTrendConfirm = false; // Chi chan dau tick, khong xoa phan ky som
input int InpContextSwingBars = 2;
input group "=== 3. PHA VO VUNG DI NGANG ==="
input bool InpTrackRangeBreaks = true;
input int InpRangeWatchBars = 40;
input int InpFailedBreakWaitBars = 5;
input double InpBreakBufferATR = 0.05;
input bool InpDrawBreakMarks = true;
int g_mtfStochH[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
double g_mtfK[],g_mtfD[];
MqlRates g_ctxH4[],g_ctxD1[];
double g_ctxRSIH4[],g_ctxRSID1[];
datetime g_ctxOpenH4=0,g_ctxOpenD1=0;
bool g_contextDataReady=false;

void FreeContextScratch()
  {
   ArrayFree(g_mtfK); ArrayFree(g_mtfD);
   ArrayFree(g_ctxH4); ArrayFree(g_ctxD1);
   ArrayFree(g_ctxRSIH4); ArrayFree(g_ctxRSID1);
   g_ctxOpenH4=0; g_ctxOpenD1=0; g_contextDataReady=false;
  }
bool CopyContextTF(int slot,MqlRates &rates[],double &rsi[],datetime &currentOpen)
  {
   int total=Bars(_Symbol,g_mtfTF[slot]);
   currentOpen=iTime(_Symbol,g_mtfTF[slot],0);
   if(total<30 || currentOpen==0 || BarsCalculated(g_rsiH[slot])<total) return false;
   int n=MathMin(InpRSILookback,total-1);
   ArraySetAsSeries(rates,false); ArraySetAsSeries(rsi,false);
   if(CopyRates(_Symbol,g_mtfTF[slot],1,n,rates)!=n ||
      CopyBuffer(g_rsiH[slot],0,1,n,rsi)!=n) return false;
   return currentOpen==iTime(_Symbol,g_mtfTF[slot],0) &&
          rates[n-1].time==iTime(_Symbol,g_mtfTF[slot],1);
  }
bool LoadContext()
  {
   if(!InpUseHTFContext) return true;
   bool h4=CopyContextTF(2,g_ctxH4,g_ctxRSIH4,g_ctxOpenH4);
   bool d1=CopyContextTF(3,g_ctxD1,g_ctxRSID1,g_ctxOpenD1);
   if(!h4) { ArrayFree(g_ctxH4); ArrayFree(g_ctxRSIH4); g_ctxOpenH4=0; }
   if(!d1) { ArrayFree(g_ctxD1); ArrayFree(g_ctxRSID1); g_ctxOpenD1=0; }
   return h4 && d1;
  }
// Latest bar fully closed AT decision time; never use a then-live HTF candle.
int ContextClosedIndex(datetime at,const MqlRates &rates[],datetime currentOpen)
  {
   int n=ArraySize(rates); if(n==0) return -1;
   if(at>=currentOpen) return n-1;
   int lo=0,hi=n-1,found=-1;
   while(lo<=hi)
     {
      int mid=(lo+hi)/2;
      if(rates[mid].time<=at) { found=mid; lo=mid+1; }
      else hi=mid-1;
     }
   return found>=1?found-1:-1;
  }
int ContextTrend(datetime at,const MqlRates &rates[],const double &rsi[],datetime currentOpen,bool &ready)
  {
   ready=false;
   int last=ContextClosedIndex(at,rates,currentOpen),w=InpContextSwingBars;
   if(last<14+4*w || last>=ArraySize(rsi) || !ValidStoch(rsi[last])) return 0;
   int high1=-1,high2=-1,low1=-1,low2=-1;
   for(int k=last-w;k>=14+w;k--)
     {
      bool high=true,low=true;
      for(int j=1;j<=w;j++)
        {
         if(rates[k].close<=rates[k-j].close || rates[k].close<rates[k+j].close) high=false;
         if(rates[k].close>=rates[k-j].close || rates[k].close>rates[k+j].close) low=false;
        }
      if(high) { if(high1<0) high1=k; else if(high2<0) high2=k; }
      if(low) { if(low1<0) low1=k; else if(low2<0) low2=k; }
      if(high2>=0 && low2>=0) break;
     }
   if(high2<0 || low2<0) return 0;
   ready=true;
   if(rates[high1].close>rates[high2].close && rates[low1].close>rates[low2].close && rsi[last]>=50) return 1;
   if(rates[high1].close<rates[high2].close && rates[low1].close<rates[low2].close && rsi[last]<=50) return -1;
   return 0;
  }
string ContextDirection(int direction)
  { if(direction>0) return "TĂNG"; if(direction<0) return "GIẢM"; return "TRUNG TÍNH"; }
// 1 aligned, -1 counter, 0 neutral, 2 conflict/unknown, 3 partial alignment.
int ContextRelation(datetime at,int direction,string &description)
  {
   if(!InpUseHTFContext) { description="Bối cảnh OFF"; return 0; }
   bool hReady=false,dReady=false;
   int h=ContextTrend(at,g_ctxH4,g_ctxRSIH4,g_ctxOpenH4,hReady);
   int d=ContextTrend(at,g_ctxD1,g_ctxRSID1,g_ctxOpenD1,dReady);
   if(!hReady || !dReady) { description="Bối cảnh: chưa đủ pivot H4/D1 tại thời điểm này"; return 2; }
   description="H4 "+ContextDirection(h)+" | D1 "+ContextDirection(d);
   int relation=0;
   if(h==direction && d==direction) { relation=1; description+=" | THUẬN H4/D1"; }
   else if(h==-direction && d==-direction) { relation=-1; description+=" | NGƯỢC H4/D1"; }
   else if(h*d<0) { relation=2; description+=" | HAI KHUNG XUNG ĐỘT"; }
   else if((h==direction && d==0) || (d==direction && h==0))
     { relation=3; description+=" | THUẬN MỘT KHUNG"; }
   else if((h==-direction && d==0) || (d==-direction && h==0))
     { relation=-1; description+=" | NGƯỢC MỘT KHUNG"; }
   else description+=" | CHƯA RÕ HƯỚNG";
   return relation;
  }
datetime MTFBarClosedAt(int bar,int total,datetime currentOpen)
  { return bar+1<total?g_mtfRates[bar+1].time:currentOpen; }

// Status: 1 confirmed, 0 pending, -1 expired, -2 pivot invalidated, -3 context blocked.
int FindDivConfirmation(int k,int kind,int total,datetime currentOpen,int &crossBar,string &detail)
  {
   crossBar=-1;
   if(!InpConfirmAfterDiv) { detail="Xác nhận Stochastic OFF"; return 0; }
   int start=k+InpRSIRight,end=MathMin(total-1,start+InpConfirmWaitBars-1);
   int direction=kind>0?1:-1;
   for(int j=start;j<=end;j++)
     {
      if(InpCancelOnPivotCloseBreak && direction*(g_mtfRates[j].close-g_mtfRates[k].close)<0)
        { detail="Hủy chờ: Close phá ngược mức Close của pivot"; return -2; }
      if(j<1 || !ValidStoch(g_mtfK[j-1]) || !ValidStoch(g_mtfD[j-1]) ||
         !ValidStoch(g_mtfK[j]) || !ValidStoch(g_mtfD[j])) continue;
      bool cross=direction>0?(g_mtfK[j-1]<=g_mtfD[j-1] && g_mtfK[j]>g_mtfD[j]):
                             (g_mtfK[j-1]>=g_mtfD[j-1] && g_mtfK[j]<g_mtfD[j]);
      if(!cross) continue;
      string context;
      int relation=ContextRelation(MTFBarClosedAt(j,total,currentOpen),direction,context);
      if(InpUseHTFContext && InpBlockCounterTrendConfirm && relation==-1)
        { detail="Giao cắt bị chặn vì ngược bối cảnh | "+context; return -3; }
      crossBar=j;
      detail="✓ Stochastic %K/%D xác nhận: "+TimeToString(MTFBarClosedAt(j,total,currentOpen),TIME_DATE|TIME_MINUTES);
      detail+="\nBối cảnh tại giao cắt: "+context;
      return 1;
     }
   if(total-1>=start+InpConfirmWaitBars-1)
     { detail="Hết "+IntegerToString(InpConfirmWaitBars)+" nến chờ giao cắt"; return -1; }
   detail="Đang chờ giao cắt Stochastic cùng hướng (tối đa "+IntegerToString(InpConfirmWaitBars)+" nến)";
   return 0;
  }
// Track the FIRST break after zone became knowable, not retrospective pre-confirmation breaks.
void FindRangeEvents(int k,int total,double lo,double hi,double atr,
                     int &breakBar,int &breakDirection,int &failedBar,string &detail)
  {
   breakBar=-1; breakDirection=0; failedBar=-1;
   if(!InpTrackRangeBreaks) { detail="Theo dõi phá vỡ OFF"; return; }
   int start=k+InpRSIRight+1,end=MathMin(total-1,start+InpRangeWatchBars-1);
   double pad=InpBreakBufferATR*atr;
   for(int j=start;j<=end;j++)
     {
      if(g_mtfRates[j].close>hi+pad) { breakBar=j; breakDirection=1; break; }
      if(g_mtfRates[j].close<lo-pad) { breakBar=j; breakDirection=-1; break; }
     }
   if(breakBar<0)
     {
      detail=total-1>=start+InpRangeWatchBars-1?"Hết thời hạn theo dõi vùng":"Vùng: chờ Close phá biên";
      return;
     }
   detail=breakDirection>0?"Phá vỡ TĂNG bằng Close":"Phá vỡ GIẢM bằng Close";
   int returnEnd=MathMin(total-1,breakBar+InpFailedBreakWaitBars);
   for(int j=breakBar+1;j<=returnEnd;j++)
     {
      // Back inside OR through the opposite edge is a failed break.
      if((breakDirection>0 && g_mtfRates[j].close<=hi) ||
         (breakDirection<0 && g_mtfRates[j].close>=lo))
        {
         failedBar=j;
         detail+=" | THẤT BẠI: Close quay vào/xuyên vùng trong "+IntegerToString(j-breakBar)+" nến";
         return;
        }
     }
   if(total-1>=breakBar+InpFailedBreakWaitBars)
      detail+=" | Chưa quay lại trong "+IntegerToString(InpFailedBreakWaitBars)+" nến quan sát";
   else detail+=" | Đang theo dõi khả năng quay lại";
  }
bool DrawEventMark(string name,int window,ENUM_OBJECT type,datetime t,double price,color col,string tip)
  {
   if(!ObjectCreate(0,name,type,window,t,price)) return false;
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   if(type==OBJ_ARROW) ObjectSetInteger(0,name,OBJPROP_ARROWCODE,251);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   return true;
  }

bool MTFEnabled(int slot)
  {
   if(!InpEnabled || !g_rsiMTFEnabled) return false;
   if(slot==0) return InpRSIM15;
   if(slot==1) return InpRSIH1;
   if(slot==2) return InpRSIH4;
   return InpRSID1;
  }
string MTFTag(int slot)
  { if(slot==0) return "M15"; if(slot==1) return "H1"; if(slot==2) return "H4"; return "D1"; }
string MTFPrefix(int slot) { return g_prefix+"R_"+MTFTag(slot)+"_"; }

void FreeMTFScratch()
  {
   ArrayFree(g_mtfRates); ArrayFree(g_mtfRSI); ArrayFree(g_mtfATR);
   ArrayFree(g_mtfPivot); ArrayFree(g_mtfFound);
   ArrayFree(g_mtfK); ArrayFree(g_mtfD);
   // Keep HTF context between scans; readiness must describe retained data.
  }
void InvalidateMTFView()
  { for(int slot=0;slot<4;slot++) { g_mtfOpen[slot]=0; g_mtfBars[slot]=0; } }
void ReleaseMTF()
  {
   g_contextDataReady=false;
   for(int slot=0;slot<4;slot++)
     {
      if(g_rsiH[slot]!=INVALID_HANDLE) IndicatorRelease(g_rsiH[slot]);
      if(g_rsiAtrH[slot]!=INVALID_HANDLE) IndicatorRelease(g_rsiAtrH[slot]);
      if(g_mtfStochH[slot]!=INVALID_HANDLE) IndicatorRelease(g_mtfStochH[slot]);
      g_mtfStochH[slot]=INVALID_HANDLE;
      g_rsiH[slot]=INVALID_HANDLE; g_rsiAtrH[slot]=INVALID_HANDLE;
      if(g_prefix!="") ObjectsDeleteAll(0,MTFPrefix(slot));
     }
   FreeMTFScratch(); FreeContextScratch(); InvalidateMTFView(); g_mtfPoll=0; g_mtfWindow=-1;
  }
bool InitMTF()
  {
   bool requested=false;
   for(int slot=0;slot<4;slot++) if(MTFEnabled(slot)) requested=true;
   if(!requested) return true;
   for(int slot=0;slot<4;slot++)
     {
      bool enabled=MTFEnabled(slot);
      bool context=InpEnabled && g_rsiMTFEnabled && InpUseHTFContext && slot>=2;
      if(!enabled && !context) continue;
      g_rsiH[slot]=iRSI(_Symbol,g_mtfTF[slot],14,PRICE_CLOSE);
      if(enabled) g_rsiAtrH[slot]=iATR(_Symbol,g_mtfTF[slot],14);
      if(enabled && InpConfirmAfterDiv)
         g_mtfStochH[slot]=iStochastic(_Symbol,g_mtfTF[slot],InpKPeriod,InpDPeriod,InpSlowing,MODE_SMA,InpPriceField);
      if(g_rsiH[slot]==INVALID_HANDLE || (enabled && g_rsiAtrH[slot]==INVALID_HANDLE) ||
         (enabled && InpConfirmAfterDiv && g_mtfStochH[slot]==INVALID_HANDLE))
        { ReleaseMTF(); return false; }
     }
   return true;
  }
string RSIKindLabel(int kind)
  {
   if(kind==1) return "THƯỜNG ↑";
   if(kind==-1) return "THƯỜNG ↓";
   if(kind==2) return "ẨN ↑";
   return "ẨN ↓";
  }
color RSIKindColor(int kind)
  {
   if(kind==1) return InpRegularBullColor;
   if(kind==-1) return InpRegularBearColor;
   if(kind==2) return InpHiddenBullColor;
   return InpHiddenBearColor;
  }
void MTFPanel(int slot,int window,string msg,color col)
  {
   if(InpHoverInfoOnly || !InpRSIMTFPanel || window<1) return;
   string name=MTFPrefix(slot)+"panel";
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,window,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,170);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18+slot*17);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TEXT,MTFTag(slot)+" RSI14 | "+msg);
  }
bool MTFPricePivot(int k,int direction,int total)
  {
   if(k<InpRSILeft || k+InpRSIRight>=total) return false;
   double v=g_mtfRates[k].close;
   for(int j=1;j<=InpRSILeft;j++)
      if(direction*(v-g_mtfRates[k-j].close)>=0.0) return false;
   for(int j=1;j<=InpRSIRight;j++)
      if(direction*(v-g_mtfRates[k+j].close)>0.0) return false;
   return true; // direction +1 = low; -1 = high; earliest equal plateau pivot
  }
int MTFClassify(int p,int k,int direction)
  {
   double price=g_mtfRates[k].close-g_mtfRates[p].close;
   double rsi=g_mtfRSI[k]-g_mtfRSI[p];
   if(!ValidStoch(g_mtfRSI[p]) || !ValidStoch(g_mtfRSI[k])) return 0;
   if(direction==1)
     {
      if(InpRSIRegular && price<0 && rsi>0 && rsi>=InpRSIMinDiff) return 1;
      if(InpRSIHidden && !InpHideHiddenDiv && price>0 && rsi<0 && -rsi>=InpRSIMinDiff) return 2;
     }
   else
     {
      if(InpRSIRegular && price>0 && rsi<0 && -rsi>=InpRSIMinDiff) return -1;
      if(InpRSIHidden && !InpHideHiddenDiv && price<0 && rsi>0 && rsi>=InpRSIMinDiff) return -2;
     }
   return 0;
  }
string StrengthLabel(int p,int k,int kind,double atr,int relation,int confirmStatus,
                     int crossBar,int breakBar,int breakDirection,int failedBar,int total)
  {
   int points=0;
   double rsiDiff=MathAbs(g_mtfRSI[k]-g_mtfRSI[p]);
   if(rsiDiff>=3.0) points++;
   if(rsiDiff>=6.0) points++;
   if(atr>0 && MathAbs(g_mtfRates[k].close-g_mtfRates[p].close)>=0.15*atr) points++;
   if(InpUseHTFContext)
     { if(relation==1) points+=2; else if(relation==3) points++;
       else if(relation==-1) points-=2; else if(relation==2) points--; }
   if(confirmStatus==1)
     {
      points+=2;
      // Momentum expansion within the first two CLOSED bars after the crossover.
      if(crossBar>=0)
        {
         int end=MathMin(total-1,crossBar+2),direction=kind>0?1:-1;
         double initial=direction*(g_mtfK[crossBar]-g_mtfD[crossBar]);
         double gap=direction*(g_mtfK[end]-g_mtfD[end]);
         if(gap>=3.0 && gap>initial) points++;
        }
     }
   else if(confirmStatus==-1) points--;
   else if(confirmStatus==-2 || confirmStatus==-3) points-=2;
   if(breakBar>=0)
     {
      if(breakDirection!=(kind>0?1:-1)) points-=2;
      else if(failedBar<0 && total-1>=breakBar+2) points+=2;
     }
   // Failure or opposing context is not upgraded merely by oscillator amplitude.
   if(failedBar>=0 || (breakBar>=0 && breakDirection!=(kind>0?1:-1)) || confirmStatus==-2 || confirmStatus==-3 ||
      (InpUseHTFContext && relation==-1)) return "YẾU";
   bool aligned=!InpUseHTFContext || relation==1 || relation==3;
   if(points>=6 && confirmStatus==1 && aligned) return "MẠNH";
   return points>=3?"VỪA":"YẾU";
  }

bool DrawMTFPair(int slot,int window,RSIMTFPair &pair,datetime currentOpen,int total)
  {
   int p=pair.previous,k=pair.current,kind=pair.kind;
   double lo=g_mtfRates[p].close,hi=lo,path=0,atrSum=0;
   int atrCount=0,n=k-p+1;
   long real=0,tick=0; bool allReal=true;
   for(int j=p;j<=k;j++)
     {
      lo=MathMin(lo,g_mtfRates[j].close); hi=MathMax(hi,g_mtfRates[j].close);
      real+=g_mtfRates[j].real_volume; tick+=g_mtfRates[j].tick_volume;
      if(g_mtfRates[j].real_volume<=0) allReal=false;
      if(j>p) path+=MathAbs(g_mtfRates[j].close-g_mtfRates[j-1].close);
      double atr=g_mtfATR[j];
      if(atr!=EMPTY_VALUE && MathIsValidNumber(atr) && atr>0) { atrSum+=atr; atrCount++; }
     }
   double span=hi-lo,avgATR=atrCount>0?atrSum/atrCount:0;
   double efficiency=path>0?MathAbs(g_mtfRates[k].close-g_mtfRates[p].close)/path:0;
   bool sideways=n>=InpSidewaysMinBars && atrCount==n && avgATR>0 &&
                 span<=InpSidewaysMaxRangeATR*avgATR && efficiency<=InpSidewaysMaxEfficiency;
   long seconds=(long)(g_mtfRates[k].time-g_mtfRates[p].time);
   datetime confirmed=k+InpRSIRight+1<total?g_mtfRates[k+InpRSIRight+1].time:currentOpen;
   string title=MTFTag(slot)+" RSI "+RSIKindLabel(kind);
   string duration=seconds<86400?DoubleToString(seconds/3600.0,1)+"h":DoubleToString(seconds/86400.0,1)+"d";
   string info=title+" | "+IntegerToString(n)+" nến | "+duration+" | Range "+DoubleToString(span,_Digits);
   if(sideways) info+=" | ĐI NGANG";
   string tip=info+"\nClose "+DoubleToString(g_mtfRates[p].close,_Digits)+" → "+DoubleToString(g_mtfRates[k].close,_Digits);
   tip+="\nRSI14 "+DoubleToString(g_mtfRSI[p],2)+" → "+DoubleToString(g_mtfRSI[k],2);
   tip+=" | ΔRSI "+DoubleToString(g_mtfRSI[k]-g_mtfRSI[p],2);
   tip+="\nVolume "+IntegerToString(allReal?real:tick)+(allReal?" real":" tick");
   tip+="\nRange/ATR "+(avgATR>0?DoubleToString(span/avgATR,2):"N/A");
   tip+=" | Path efficiency "+DoubleToString(efficiency,2);
   tip+="\nXác nhận: "+TimeToString(confirmed,TIME_DATE|TIME_MINUTES);
   tip+="\nSố nến gồm cả hai pivot; thời gian là khoảng cách giữa hai pivot.";
   tip+="\nĐi ngang hẹp không tự xác nhận tích lũy hoặc hướng phá vỡ.";
   string name=MTFPrefix(slot)+IntegerToString((long)g_mtfRates[k].time);
   string context,confirmDetail,rangeDetail;
   int relation=ContextRelation(confirmed,kind>0?1:-1,context);
   tip+="\nBối cảnh lúc phân kỳ được biết: "+context;
   int crossBar=-1;
   int confirmStatus=FindDivConfirmation(k,kind,total,currentOpen,crossBar,confirmDetail);
   tip+="\n"+confirmDetail;
   int breakBar=-1,breakDirection=0,failedBar=-1;
   if(sideways)
     {
      FindRangeEvents(k,total,lo,hi,avgATR,breakBar,breakDirection,failedBar,rangeDetail);
      tip+="\n"+rangeDetail;
      if(breakBar>=0) tip+="\nPhá vỡ được biết: "+TimeToString(MTFBarClosedAt(breakBar,total,currentOpen),TIME_DATE|TIME_MINUTES);
      if(failedBar>=0) tip+="\nThất bại được biết: "+TimeToString(MTFBarClosedAt(failedBar,total,currentOpen),TIME_DATE|TIME_MINUTES);
     }
   if(InpStrengthTooltip)
     {
      string strength=StrengthLabel(p,k,kind,avgATR,relation,confirmStatus,crossBar,
                                    breakBar,breakDirection,failedBar,total);
      tip="Độ mạnh: "+strength+"\n"+tip;
      tip+="\nĐánh giá mức xác nhận đến nến đã đóng gần nhất; không phải xác suất thắng.";
     }
   color col=RSIKindColor(kind);
   if(InpUseHTFContext && InpContextLineColors)
     { if(relation==-1) col=clrSlateGray; else if(relation==2) col=clrGold; }
   ENUM_LINE_STYLE style=(kind==2 || kind==-2)?STYLE_DASH:STYLE_SOLID;
   bool ok=true;
   if(InpRSIPriceLines)
      ok=DrawSegment(name+"P",0,g_mtfRates[p].time,g_mtfRates[p].close,
                     g_mtfRates[k].time,g_mtfRates[k].close,col,style,tip);
   if(InpRSIPaneLines)
     {
      if(window<1) ok=false;
      else if(!DrawSegment(name+"R",window,g_mtfRates[p].time,g_mtfRSI[p],
                          g_mtfRates[k].time,g_mtfRSI[k],col,style,tip)) ok=false;
     }
   if(!InpHoverInfoOnly && InpRSIMeasureText)
     {
      if(ObjectCreate(0,name+"T",OBJ_TEXT,0,g_mtfRates[k].time,g_mtfRates[k].close))
        {
         ObjectSetInteger(0,name+"T",OBJPROP_COLOR,col);
         ObjectSetInteger(0,name+"T",OBJPROP_FONTSIZE,8);
         ObjectSetInteger(0,name+"T",OBJPROP_ANCHOR,kind>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0,name+"T",OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name+"T",OBJPROP_HIDDEN,true);
         ObjectSetString(0,name+"T",OBJPROP_TEXT,info);
         ObjectSetString(0,name+"T",OBJPROP_TOOLTIP,tip);
        }
      else ok=false;
     }
   if(InpRSIRangeBoxes && sideways)
     {
      int boxEnd=k;
      if(InpTrackRangeBreaks)
        {
         boxEnd=MathMin(total-1,k+InpRSIRight+InpRangeWatchBars);
         if(breakBar>=0) boxEnd=MathMin(total-1,breakBar+InpFailedBreakWaitBars);
         if(failedBar>=0) boxEnd=failedBar;
        }
      if(ObjectCreate(0,name+"B",OBJ_RECTANGLE,0,g_mtfRates[p].time,hi,g_mtfRates[boxEnd].time,lo))
        {
         ObjectSetInteger(0,name+"B",OBJPROP_COLOR,col);
         ObjectSetInteger(0,name+"B",OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,name+"B",OBJPROP_FILL,false);
         ObjectSetInteger(0,name+"B",OBJPROP_BACK,true);
         ObjectSetInteger(0,name+"B",OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name+"B",OBJPROP_HIDDEN,true);
         ObjectSetString(0,name+"B",OBJPROP_TOOLTIP,tip);
        }
      else ok=false;
     }
   if(InpDrawConfirmTicks && confirmStatus==1 && crossBar>=0)
     {
      color tickColor=kind>0?clrLimeGreen:clrTomato;
      if(!DrawEventMark(name+"C",0,OBJ_ARROW_CHECK,g_mtfRates[crossBar].time,
                        g_mtfRates[crossBar].close,tickColor,tip)) ok=false;
      if(InpRSIPaneLines && window>=1 &&
         !DrawEventMark(name+"c",window,OBJ_ARROW_CHECK,g_mtfRates[crossBar].time,
                        g_mtfK[crossBar],tickColor,tip)) ok=false;
     }
   if(InpDrawBreakMarks && sideways && breakBar>=0)
     {
      ENUM_OBJECT arrow=breakDirection>0?OBJ_ARROW_UP:OBJ_ARROW_DOWN;
      if(!DrawEventMark(name+"X",0,arrow,g_mtfRates[breakBar].time,
                        g_mtfRates[breakBar].close,breakDirection>0?clrLimeGreen:clrTomato,tip)) ok=false;
      if(failedBar>=0 && !DrawEventMark(name+"F",0,OBJ_ARROW,g_mtfRates[failedBar].time,
                                      g_mtfRates[failedBar].close,clrGold,tip)) ok=false;
     }
   return ok;
  }
bool ScanMTF(int slot,int window,datetime currentOpen,int totalBars)
  {
   int count=MathMin(InpRSILookback,totalBars-1);
   int minimum=14+InpRSILeft+InpRSIRight+InpRSIMinGap+2;
   if(count<minimum) return false;
   ArraySetAsSeries(g_mtfRates,false); ArraySetAsSeries(g_mtfRSI,false);
   ArraySetAsSeries(g_mtfATR,false); ArraySetAsSeries(g_mtfK,false); ArraySetAsSeries(g_mtfD,false);
   // CopyRates/CopyBuffer shift 1 excludes the live candle of THIS timeframe.
   if(CopyRates(_Symbol,g_mtfTF[slot],1,count,g_mtfRates)!=count) return false;
   if(BarsCalculated(g_rsiH[slot])<totalBars || BarsCalculated(g_rsiAtrH[slot])<totalBars) return false;
   if(CopyBuffer(g_rsiH[slot],0,1,count,g_mtfRSI)!=count ||
      CopyBuffer(g_rsiAtrH[slot],0,1,count,g_mtfATR)!=count) return false;
   if(InpConfirmAfterDiv)
     {
      if(BarsCalculated(g_mtfStochH[slot])<totalBars ||
         CopyBuffer(g_mtfStochH[slot],0,1,count,g_mtfK)!=count ||
         CopyBuffer(g_mtfStochH[slot],1,1,count,g_mtfD)!=count) return false;
      ArraySetAsSeries(g_mtfK,false); ArraySetAsSeries(g_mtfD,false);
     }
   if(iTime(_Symbol,g_mtfTF[slot],0)!=currentOpen ||
      g_mtfRates[count-1].time!=iTime(_Symbol,g_mtfTF[slot],1)) return false;
   ArraySetAsSeries(g_mtfRates,false); ArraySetAsSeries(g_mtfRSI,false); ArraySetAsSeries(g_mtfATR,false);
   for(int j=14;j<count;j++)
     {
      if(!ValidStoch(g_mtfRSI[j]) || !ValidATR(g_mtfATR[j])) return false;
      if(InpConfirmAfterDiv && j>=InpKPeriod+InpSlowing+InpDPeriod-3 &&
         (!ValidStoch(g_mtfK[j]) || !ValidStoch(g_mtfD[j]))) return false;
     }
   ArrayResize(g_mtfPivot,count); ArrayInitialize(g_mtfPivot,0);
   ArrayResize(g_mtfFound,0);
   int first=14+InpRSILeft,end=count-1-InpRSIRight;
   for(int k=first;k<=end;k++)
     {
      if(MTFPricePivot(k,1,count)) g_mtfPivot[k]=1;
      else if(MTFPricePivot(k,-1,count)) g_mtfPivot[k]=-1;
     }
   // Newest signals first, nearest eligible price pivot, no cherry-picking older matches.
   for(int k=end;k>=first && ArraySize(g_mtfFound)<(InpShowHistory?InpRSIPairsPerTF:1);k--)
     {
      int direction=g_mtfPivot[k]; if(direction==0) continue;
      int lower=MathMax(first,k-InpRSIMaxGap);
      for(int p=k-InpRSIMinGap;p>=lower;p--)
        {
         if(g_mtfPivot[p]!=direction) continue;
         int kind=MTFClassify(p,k,direction);
         if(kind!=0)
           {
            int n=ArraySize(g_mtfFound); ArrayResize(g_mtfFound,n+1);
            g_mtfFound[n].previous=p; g_mtfFound[n].current=k; g_mtfFound[n].kind=kind;
           }
         break;
        }
     }
   ObjectsDeleteAll(0,MTFPrefix(slot)); // Only this TF and this instance, once per TF close
   bool ok=true;
   for(int j=ArraySize(g_mtfFound)-1;j>=0;j--)
      if(!DrawMTFPair(slot,window,g_mtfFound[j],currentOpen,count)) ok=false;
   string status=ArraySize(g_mtfFound)>0?RSIKindLabel(g_mtfFound[0].kind)+" "+
                 TimeToString(g_mtfRates[g_mtfFound[0].current].time,TIME_DATE|TIME_MINUTES):"Không có phân kỳ trong đoạn quét";
   color col=ArraySize(g_mtfFound)>0?RSIKindColor(g_mtfFound[0].kind):clrSilver;
   MTFPanel(slot,window,status,col);
   return ok && (InpHoverInfoOnly || !InpRSIMTFPanel || window>=1);
  }
void UpdateMTF()
  {
   if(!InpEnabled || !g_rsiMTFEnabled) return;
   bool requested=false;
   for(int check=0;check<4;check++) if(MTFEnabled(check)) requested=true;
   if(!requested) return;
   ulong now=GetTickCount64();
   if(g_mtfPoll!=0 && now-g_mtfPoll<1500) return;
   g_mtfPoll=now;
   int window=ChartWindowFind();
   if(window!=g_mtfWindow) { InvalidateMTFView(); g_mtfWindow=window; }
   bool contextChanged=InpUseHTFContext &&
      (iTime(_Symbol,PERIOD_H4,0)!=g_ctxOpenH4 || iTime(_Symbol,PERIOD_D1,0)!=g_ctxOpenD1);
   bool needed=InpUseHTFContext && (!g_contextDataReady || contextChanged);
   for(int check=0;check<4;check++)
      if(MTFEnabled(check) && (iTime(_Symbol,g_mtfTF[check],0)!=g_mtfOpen[check] ||
                              Bars(_Symbol,g_mtfTF[check])!=g_mtfBars[check])) needed=true;
   if(!needed) return;
   bool contextReady=LoadContext();
   if((contextChanged && contextReady) || contextReady!=g_contextDataReady) InvalidateMTFView();
   g_contextDataReady=contextReady;
   // Missing HTF data must not hide divergence; label it unknown and retry.
   for(int slot=0;slot<4;slot++)
     {
      if(!MTFEnabled(slot)) continue;
      datetime currentOpen=iTime(_Symbol,g_mtfTF[slot],0);
      int total=Bars(_Symbol,g_mtfTF[slot]);
      if(currentOpen==0 || total<2) { MTFPanel(slot,window,"Chờ dữ liệu",clrSilver); continue; }
      if(currentOpen==g_mtfOpen[slot] && total==g_mtfBars[slot]) continue;
      if(ScanMTF(slot,window,currentOpen,total))
        { g_mtfOpen[slot]=currentOpen; g_mtfBars[slot]=total; }
      else MTFPanel(slot,window,"Chờ dữ liệu / xác nhận",clrSilver);
     }
   FreeMTFScratch(); // Release per-TF scratch; retain cached H4/D1 context
  }
void DrawMTFButton(bool force=false)
  {
   if(!InpEnabled || g_prefix=="") return;
   int window=ChartWindowFind(); if(window<1) return;
   if(!force && window==g_mtfButtonWindow) return;
   string name=g_prefix+"UI_MTF";
   if(window!=g_mtfButtonWindow) ObjectDelete(0,name);
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_BUTTON,window,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,92);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,6);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,84);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,22);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,g_rsiMTFEnabled?clrDarkGreen:clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrSlateGray);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,10);
   ObjectSetString(0,name,OBJPROP_TEXT,g_rsiMTFEnabled?"MTF ON":"MTF OFF");
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"Bật/tắt RSI M15/H1/H4/D1; giữ Stochastic hiện tại");
   g_mtfButtonWindow=window;
  }
void OnTimer() { DrawMTFButton(); UpdateMTF(); RenderDivLines(); }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(!InpEnabled) return;
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==g_prefix+"UI_MTF")
     {
      g_rsiMTFEnabled=!g_rsiMTFEnabled;
      if(!g_rsiMTFEnabled) ReleaseMTF();
      else
        {
         if(!InitMTF())
           { g_rsiMTFEnabled=false; Print("WatchDog: cannot enable MTF handles"); }
         else { InvalidateMTFView(); g_mtfPoll=0; UpdateMTF(); }
        }
      DrawMTFButton(true); ChartRedraw();
     }
   else if(id==CHARTEVENT_CHART_CHANGE)
     {
      DrawMTFButton(true);
      for(int j=0;j<ArraySize(g_pairs);j++) g_pairs[j].dirty=true;
      g_lines_pending=ArraySize(g_pairs)>0;
      RenderDivLines();
     }
  }

void FreeScratch()
  {
   ArrayFree(tmpK); ArrayFree(tmpD); ArrayFree(tmpATR);
  }

void ReleaseResources()
  {
   EventKillTimer();
   ReleaseMTF();
   if(g_prefix!="") ObjectDelete(0,g_prefix+"UI_MTF");
   g_mtfButtonWindow=-1;
   if(stocHandle!=INVALID_HANDLE) IndicatorRelease(stocHandle);
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   stocHandle=INVALID_HANDLE; atrHandle=INVALID_HANDLE;
   FreeScratch(); ClearDivLines(); g_first=0; g_last=0; g_committedBars=0;
  }

void ClearBuffers()
  {
   ArrayInitialize(KBuffer,EMPTY_VALUE); ArrayInitialize(DBuffer,EMPTY_VALUE);
   ArrayInitialize(CloseBuySignal,EMPTY_VALUE); ArrayInitialize(CloseSellSignal,EMPTY_VALUE);
   ArrayInitialize(BullishDivBuffer,EMPTY_VALUE); ArrayInitialize(BearishDivBuffer,EMPTY_VALUE);
   ArrayInitialize(SignalStrength,0.0); ArrayInitialize(g_atrBuffer,EMPTY_VALUE);
   ArrayInitialize(LowPivot,0.0); ArrayInitialize(HighPivot,0.0);
  }


int UpdateLatestSignal(const double &buffer[],int previous,int start,int total)
  {
   bool lost=previous>=total || (previous>=0 && buffer[previous]==EMPTY_VALUE);
   int latest=lost?-1:previous;
   if(lost) start=0;
   for(int j=MathMax(0,start);j<total;j++)
      if(buffer[j]!=EMPTY_VALUE && MathIsValidNumber(buffer[j])) latest=j;
   return latest;
  }
void ApplySignalHistory(int total,int start,bool reset)
  {
   int warm=InpKPeriod+InpSlowing+InpDPeriod-3;
   if(InpShowHistory)
     { for(int plot=2;plot<6;plot++) PlotIndexSetInteger(plot,PLOT_DRAW_BEGIN,warm); return; }
   if(reset) { for(int j=0;j<4;j++) g_latestSignals[j]=-1; start=0; }
   g_latestSignals[0]=UpdateLatestSignal(CloseBuySignal,g_latestSignals[0],start,total);
   g_latestSignals[1]=UpdateLatestSignal(CloseSellSignal,g_latestSignals[1],start,total);
   g_latestSignals[2]=UpdateLatestSignal(BullishDivBuffer,g_latestSignals[2],start,total);
   g_latestSignals[3]=UpdateLatestSignal(BearishDivBuffer,g_latestSignals[3],start,total);
   int exit=MathMax(g_latestSignals[0],g_latestSignals[1]);
   int div=MathMax(g_latestSignals[2],g_latestSignals[3]);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,exit>=0?exit:total);
   PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,exit>=0?exit:total);
   PlotIndexSetInteger(4,PLOT_DRAW_BEGIN,div>=0?div:total);
   PlotIndexSetInteger(5,PLOT_DRAW_BEGIN,div>=0?div:total);
   // Presentation only: retain calculation buffers for EA/data-window consumers.
  }

int OnInit()
  {
   g_rsiMTFEnabled=InpRSIMTF;
   g_prefix="WD264_"+IntegerToString(ChartID())+"_"+IntegerToString((long)GetMicrosecondCount())+"_";
   if(InpConfirmWaitBars<1 || InpConfirmWaitBars>50 ||
      InpContextSwingBars<1 || InpContextSwingBars>10 ||
      InpRangeWatchBars<1 || InpRangeWatchBars>300 ||
      InpFailedBreakWaitBars<1 || InpFailedBreakWaitBars>50 ||
      !MathIsValidNumber(InpBreakBufferATR) || InpBreakBufferATR<0 || InpBreakBufferATR>2)
      return INIT_PARAMETERS_INCORRECT;
   if(InpRSILeft<1 || InpRSILeft>20 || InpRSIRight<1 || InpRSIRight>20 ||
      InpRSIMinGap<1 || InpRSIMaxGap<InpRSIMinGap || InpRSIMaxGap>500 ||
      InpRSILookback<14+InpRSILeft+InpRSIRight+InpRSIMaxGap+2 || InpRSILookback>5000 ||
      InpRSIPairsPerTF<1 || InpRSIPairsPerTF>20 || InpSidewaysMinBars<2 ||
      !MathIsValidNumber(InpRSIMinDiff) || InpRSIMinDiff<0 ||
      !MathIsValidNumber(InpSidewaysMaxRangeATR) || InpSidewaysMaxRangeATR<=0 ||
      !MathIsValidNumber(InpSidewaysMaxEfficiency) || InpSidewaysMaxEfficiency<0 || InpSidewaysMaxEfficiency>1)
      return INIT_PARAMETERS_INCORRECT;
   if(InpMaxLinePairs<1 || InpMaxLinePairs>1000 || InpKPeriod<1 || InpDPeriod<1 || InpSlowing<1 || InpATRPeriod<1 ||
      InpLeftBars<1 || InpRightBars<1 || InpMinBars<1 || InpMaxBars<InpMinBars ||
      InpOverSold<0 || InpOverBought>100 || InpOverSold>=InpOverBought ||
      !MathIsValidNumber(InpMinStochDiff) || InpMinStochDiff<0 ||
      !MathIsValidNumber(InpMinAtrFilter) || InpMinAtrFilter<0 ||
      !MathIsValidNumber(InpMinPriceDiffATR) || InpMinPriceDiffATR<0 ||
      InpKPeriod>100000 || InpDPeriod>100000 || InpSlowing>100000 ||
      InpATRPeriod>100000 || InpLeftBars>10000 || InpRightBars>10000 || InpMaxBars>100000)
      return INIT_PARAMETERS_INCORRECT;
   SetIndexBuffer(7,g_atrBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,LowPivot,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,HighPivot,INDICATOR_CALCULATIONS);
   ArraySetAsSeries(LowPivot,false);
   ArraySetAsSeries(HighPivot,false);
   //--- Map buffers
   SetIndexBuffer(0,KBuffer,          INDICATOR_DATA);
   SetIndexBuffer(1,DBuffer,          INDICATOR_DATA);
   SetIndexBuffer(2,CloseBuySignal,   INDICATOR_DATA);
   SetIndexBuffer(3,CloseSellSignal,  INDICATOR_DATA);
   SetIndexBuffer(4,BullishDivBuffer, INDICATOR_DATA);
   SetIndexBuffer(5,BearishDivBuffer, INDICATOR_DATA);
   SetIndexBuffer(6,SignalStrength,   INDICATOR_CALCULATIONS);


   //--- Force normal indexing
   ArraySetAsSeries(KBuffer,false);
   ArraySetAsSeries(DBuffer,false);

   ArraySetAsSeries(CloseBuySignal,false);
   ArraySetAsSeries(CloseSellSignal,false);

   ArraySetAsSeries(BullishDivBuffer,false);
   ArraySetAsSeries(BearishDivBuffer,false);

   ArraySetAsSeries(SignalStrength,false);
   ArraySetAsSeries(g_atrBuffer,false);


   //--- Arrow symbols
   PlotIndexSetInteger(2,PLOT_ARROW,251);
   PlotIndexSetInteger(3,PLOT_ARROW,251);

   PlotIndexSetInteger(4,PLOT_ARROW,233);
   PlotIndexSetInteger(5,PLOT_ARROW,234);


   //--- Empty values
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,EMPTY_VALUE);


   // Settings changes reinitialize the indicator, releasing the old instance first.
   if(!InpEnabled)
     {
      ReleaseResources();
      for(int plot=0;plot<6;plot++)
        {
         PlotIndexSetInteger(plot,PLOT_DRAW_TYPE,DRAW_NONE);
         PlotIndexSetInteger(plot,PLOT_SHOW_DATA,false);
        }
      IndicatorSetInteger(INDICATOR_LEVELS,0);
      IndicatorSetString(INDICATOR_SHORTNAME,"WatchDog OFF");
      ClearBuffers();
      return INIT_SUCCEEDED;
     }
   //--- Stochastic levels
   IndicatorSetInteger(INDICATOR_LEVELS,2);

   IndicatorSetDouble(
      INDICATOR_LEVELVALUE,
      0,
      InpOverSold
      );

   IndicatorSetDouble(
      INDICATOR_LEVELVALUE,
      1,
      InpOverBought
      );


   //--- Stochastic handle
   stocHandle=iStochastic(
      _Symbol,
      PERIOD_CURRENT,
      InpKPeriod,
      InpDPeriod,
      InpSlowing,
      MODE_SMA,
      InpPriceField
      );


   //--- ATR handle
   if(InpEnableDiv) atrHandle=iATR(
      _Symbol,
      PERIOD_CURRENT,
      InpATRPeriod
      );


   if(stocHandle==INVALID_HANDLE ||
      (InpEnableDiv && atrHandle==INVALID_HANDLE))
     {
      Print("WatchDog v2.64: Failed to create Stochastic or ATR handle.");
      if(stocHandle!=INVALID_HANDLE) IndicatorRelease(stocHandle);
      if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
      stocHandle=INVALID_HANDLE; atrHandle=INVALID_HANDLE;
      return(INIT_FAILED);
     }


   int warm=InpKPeriod+InpSlowing+InpDPeriod-3;
   for(int plot=0;plot<6;plot++)
     {
      PlotIndexSetInteger(plot,PLOT_DRAW_BEGIN,warm);
      PlotIndexSetDouble(plot,PLOT_EMPTY_VALUE,EMPTY_VALUE);
     }
   IndicatorSetDouble(INDICATOR_MINIMUM,0.0);
   IndicatorSetDouble(INDICATOR_MAXIMUM,100.0);
   //--- Short name
   IndicatorSetString(
      INDICATOR_SHORTNAME,
      StringFormat(
         "WatchDog Pro v2.64(%d,%d,%d)",
         InpKPeriod,
         InpDPeriod,
         InpSlowing
         )
      );


   if(!InitMTF()) { ReleaseResources(); Print("WatchDog v2.64: RSI MTF init failed"); return INIT_FAILED; }
   if(!EventSetTimer(2)) { ReleaseResources(); return INIT_FAILED; }
   DrawMTFButton();
   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ReleaseResources();
   // Delete only objects bearing this instance prefix; free line records and scratch.
   // MT5 owns the bound buffers and removes plots/subwindow on detachment.
  }


bool ValidStoch(double v)
  { return v!=EMPTY_VALUE && MathIsValidNumber(v) && v>=0.0 && v<=100.0; }

bool ValidATR(double v)
  { return v!=EMPTY_VALUE && MathIsValidNumber(v) && v>=0.0; }

void ClearNewCells(int from,int total)
  {
   for(int b=MathMax(0,from);b<total;b++)
     {
      KBuffer[b]=EMPTY_VALUE; DBuffer[b]=EMPTY_VALUE;
      CloseBuySignal[b]=EMPTY_VALUE; CloseSellSignal[b]=EMPTY_VALUE;
      BullishDivBuffer[b]=EMPTY_VALUE; BearishDivBuffer[b]=EMPTY_VALUE;
      SignalStrength[b]=0.0; g_atrBuffer[b]=EMPTY_VALUE;
      LowPivot[b]=0.0; HighPivot[b]=0.0;
     }
  }

int OnCalculate(const int rates_total,const int prev_calculated,
 const datetime &time[],const double &open[],const double &high[],const double &low[],
 const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(!InpEnabled)
     {
      // Clear newly allocated buffer slots once per size change; no per-tick scan.
      if(prev_calculated==0 || g_off_size!=rates_total)
        { ClearBuffers(); g_off_size=rates_total; }
      return rates_total;
     }
   ArraySetAsSeries(time,false); ArraySetAsSeries(high,false); ArraySetAsSeries(low,false);
   if(rates_total<1) return 0;
   bool reset=prev_calculated<=0 || prev_calculated>rates_total ||
              g_committedBars<=0 || g_committedBars>rates_total || g_first!=time[0];
   if(!reset && (time[g_committedBars-1]!=g_last ||
                (g_committedBars==rates_total && g_last!=time[rates_total-1]))) reset=true;
   int committed=reset?0:g_committedBars;
   // Never trust newly allocated MT5 buffer cells, including on a retry.
   if(reset)
     {
      ClearBuffers(); ClearDivLines();
      g_committedBars=0; g_first=0; g_last=0;
     }
   else ClearNewCells(committed,rates_total);
   DrawMTFButton(); UpdateMTF();
   int warm=InpKPeriod+InpSlowing+InpDPeriod-3;
   if(rates_total<warm+2) return 0;
   bool newBars=reset || committed!=rates_total;
   bool scanSignals=newBars || !InpConfirmOnClose;
   if(BarsCalculated(stocHandle)<rates_total) return committed;
   int count=reset?rates_total:MathMin(rates_total,MathMax(1,rates_total-committed+1));
   ArraySetAsSeries(tmpK,false); ArraySetAsSeries(tmpD,false); ArraySetAsSeries(tmpATR,false);
   if(CopyBuffer(stocHandle,0,0,count,tmpK)!=count ||
      CopyBuffer(stocHandle,1,0,count,tmpD)!=count) return committed;
   // Publish the oscillator independently of ATR and divergence data.
   // A hole in old history must not suppress every valid candle on the chart.
   int offset=rates_total-count;
   for(int j=0;j<count;j++)
     {
      int b=offset+j;
      KBuffer[b]=(b>=warm && ValidStoch(tmpK[j]))?tmpK[j]:EMPTY_VALUE;
      DBuffer[b]=(b>=warm && ValidStoch(tmpD[j]))?tmpD[j]:EMPTY_VALUE;
     }
   if(InpEnableDiv && newBars)
     {
      if(BarsCalculated(atrHandle)<rates_total ||
         CopyBuffer(atrHandle,0,0,count,tmpATR)!=count)
         return committed>0?committed:rates_total; // Keep K/D visible, retry signals.
      for(int j=0;j<count;j++)
         g_atrBuffer[offset+j]=ValidATR(tmpATR[j])?tmpATR[j]:EMPTY_VALUE;
     }
   // Only the newly CLOSED frontier can delay signal commitment.
   // Older gaps remain EMPTY; pivot validators reject windows crossing a gap.
   int frontier=reset?rates_total-2:MathMax(warm,committed-1);
   for(int b=frontier;b<rates_total-1;b++)
     {
      if(!ValidStoch(KBuffer[b]) || !ValidStoch(DBuffer[b]) ||
         (InpEnableDiv && newBars && !ValidATR(g_atrBuffer[b])))
         return committed>0?committed:rates_total;
     }
   if(reset) FreeScratch(); // Do not retain full-history staging arrays
   int start=reset?warm+1:MathMax(warm+1,committed-1);
   int last=InpConfirmOnClose?rates_total-2:rates_total-1;
   CloseBuySignal[rates_total-1]=EMPTY_VALUE; CloseSellSignal[rates_total-1]=EMPTY_VALUE;
   if(scanSignals)
   for(int i=start;i<=last;i++)
     {
      CloseBuySignal[i]=EMPTY_VALUE; CloseSellSignal[i]=EMPTY_VALUE;
      double k0=KBuffer[i-1],k1=KBuffer[i],d0=DBuffer[i-1],d1=DBuffer[i];
      if(!ValidStoch(k0)||!ValidStoch(k1)||!ValidStoch(d0)||!ValidStoch(d1)) continue;
      bool buy=false,sell=false;
      if(Stoch_Zone_Mode==Crossing)
        {
         bool ob=k1>=InpOverBought || d1>=InpOverBought;
         bool os=k1<=InpOverSold || d1<=InpOverSold;
         if(InpCrossUsePreviousZone)
           { ob=ob || k0>=InpOverBought || d0>=InpOverBought;
             os=os || k0<=InpOverSold || d0<=InpOverSold; }
         buy=k0>=d0 && k1<d1 && ob;
         sell=k0<=d0 && k1>d1 && os;
        }
      else if(Stoch_Zone_Mode==Entering)
        { buy=d0<=InpOverBought && d1>InpOverBought;
          sell=d0>=InpOverSold && d1<InpOverSold; }
      else
        { buy=d0>=InpOverBought && d1<InpOverBought;
          sell=d0<=InpOverSold && d1>InpOverSold; }
      if(buy) CloseBuySignal[i]=d1;
      if(sell) CloseSellSignal[i]=d1;
     }
   if(InpEnableDiv && newBars)
     {
      int pivotFirst=MathMax(warm+InpLeftBars,InpATRPeriod);
      int first=reset?pivotFirst:MathMax(pivotFirst,committed-1-InpRightBars);
      int end=rates_total-2-InpRightBars; // Divergence NEVER uses the live candle
      // Cache each pivot once; previous candidates must already be confirmed.
      for(int k=first;k<=end;k++)
        {
         double atr=g_atrBuffer[k];
         LowPivot[k]=0.0; HighPivot[k]=0.0;
         if(atr==EMPTY_VALUE || !MathIsValidNumber(atr) || atr<=0 || !ValidStoch(KBuffer[k])) continue;
         LowPivot[k]=(IsPriceSwingLow(k,low,InpLeftBars,InpRightBars,atr,InpMinAtrFilter) &&
                      IsStochSwingLow(k,KBuffer,InpLeftBars,InpRightBars))?1.0:0.0;
         HighPivot[k]=(IsPriceSwingHigh(k,high,InpLeftBars,InpRightBars,atr,InpMinAtrFilter) &&
                       IsStochSwingHigh(k,KBuffer,InpLeftBars,InpRightBars))?1.0:0.0;
        }
      for(int k=first;k<=end;k++)
        {
         int target=InpDivAtConfirmation?k+InpRightBars:k;
         BullishDivBuffer[target]=EMPTY_VALUE; BearishDivBuffer[target]=EMPTY_VALUE;
         SignalStrength[target]=0.0;
         bool bull=false,bear=false;
         int bullPrev=-1,bearPrev=-1,bullKind=0,bearKind=0;
         int lower=MathMax(pivotFirst,k-InpMaxBars);
         if(LowPivot[k]>0.0)
         for(int p=k-InpMinBars;p>=lower;p--)
           {
            if(LowPivot[p]==0.0) continue;
            bool zone=!InpDivRequireZone || MathMin(KBuffer[p],KBuffer[k])<=InpOverSold;
            bool distance=MathAbs(low[p]-low[k])>=InpMinPriceDiffATR*g_atrBuffer[k];
            bool regular=InpShowRegularDiv && low[k]<low[p] && KBuffer[k]>KBuffer[p] &&
                         KBuffer[k]-KBuffer[p]>=InpMinStochDiff;
            bool hidden=InpShowHiddenDiv && !InpHideHiddenDiv && low[k]>low[p] && KBuffer[k]<KBuffer[p] &&
                        KBuffer[p]-KBuffer[k]>=InpMinStochDiff;
            if(zone && distance && (regular || hidden))
              { bull=true; bullPrev=p; bullKind=regular?1:2; }
            if(bull || InpNearestPivotOnly) break;
           }
         if(HighPivot[k]>0.0)
         for(int p=k-InpMinBars;p>=lower;p--)
           {
            if(HighPivot[p]==0.0) continue;
            bool zone=!InpDivRequireZone || MathMax(KBuffer[p],KBuffer[k])>=InpOverBought;
            bool distance=MathAbs(high[k]-high[p])>=InpMinPriceDiffATR*g_atrBuffer[k];
            bool regular=InpShowRegularDiv && high[k]>high[p] && KBuffer[k]<KBuffer[p] &&
                         KBuffer[p]-KBuffer[k]>=InpMinStochDiff;
            bool hidden=InpShowHiddenDiv && !InpHideHiddenDiv && high[k]<high[p] && KBuffer[k]>KBuffer[p] &&
                        KBuffer[k]-KBuffer[p]>=InpMinStochDiff;
            if(zone && distance && (regular || hidden))
              { bear=true; bearPrev=p; bearKind=regular?-1:-2; }
            if(bear || InpNearestPivotOnly) break;
           }
         int kind=bull && !bear?bullKind:bear && !bull?bearKind:0;
         int previous=kind>0?bullPrev:bearPrev;
         if(kind!=0)
           StorePair(time[previous],time[k],
                     time[k+InpRightBars+1],
                     kind>0?low[previous]:high[previous],kind>0?low[k]:high[k],
                     KBuffer[previous],KBuffer[k],kind);
         else StorePair(0,time[k],0,0,0,0,0,0);
         // Ambiguous outside bars: do not arbitrarily favor bullish signals.
         if(bull && !bear) { BullishDivBuffer[target]=MathMax(KBuffer[k]-3.0,1.0); SignalStrength[target]=(double)bullKind; }
         if(bear && !bull) { BearishDivBuffer[target]=MathMin(KBuffer[k]+3.0,99.0); SignalStrength[target]=(double)bearKind; }
        }
      // Remove provisional lines invalidated by an intrabar pivot change.
      for(int j=ArraySize(g_pairs)-1;j>=0;j--)
         if(end<0 || g_pairs[j].t2>time[end]) RemovePair(j);
      // Clear only unconfirmed frontier; protects already confirmed history.
      for(int k=MathMax(pivotFirst,end+1);k<rates_total;k++)
        {
         LowPivot[k]=0.0; HighPivot[k]=0.0;
         int target=InpDivAtConfirmation?k+InpRightBars:k;
         if(target<rates_total)
           { BullishDivBuffer[target]=EMPTY_VALUE; BearishDivBuffer[target]=EMPTY_VALUE; SignalStrength[target]=0.0; }
        }
     }
   if(scanSignals) ApplySignalHistory(rates_total,MathMax(0,committed-InpRightBars-3),reset);
   RenderDivLines();
   g_first=time[0]; g_last=time[rates_total-1]; g_committedBars=rates_total;
   return rates_total;
  }

//+------------------------------------------------------------------+
//| PRICE SWING LOW                                                  |
//+------------------------------------------------------------------+
bool IsPriceSwingLow(
   int index,
   const double &low[],
   int left,
   int right,
   double atr,
   double minAtrFilter
   )
  {
   int size=ArraySize(low);


   if(index<0 ||
      index>=size)
      return(false);


   if(index-left<0)
      return(false);


   if(index+right>=size)
      return(false);


   //--- Left side
   for(int i=1;i<=left;i++)
     {
      if(low[index]>=low[index-i])
         return(false);
     }


   //--- Right side
   for(int i=1;i<=right;i++)
     {
      if(low[index]>low[index+i])
         return(false);
     }


   //--- ATR filter
   if(
      minAtrFilter>0.0 &&
      atr>0.0 &&
      index>0
      )
     {
      double move=
         low[index-1]-low[index];


      if(move<
         minAtrFilter*atr)
         return(false);
     }


   return(true);
  }


//+------------------------------------------------------------------+
//| PRICE SWING HIGH                                                 |
//+------------------------------------------------------------------+
bool IsPriceSwingHigh(
   int index,
   const double &high[],
   int left,
   int right,
   double atr,
   double minAtrFilter
   )
  {
   int size=ArraySize(high);


   if(index<0 ||
      index>=size)
      return(false);


   if(index-left<0)
      return(false);


   if(index+right>=size)
      return(false);


   //--- Left side
   for(int i=1;i<=left;i++)
     {
      if(high[index]<=high[index-i])
         return(false);
     }


   //--- Right side
   for(int i=1;i<=right;i++)
     {
      if(high[index]<high[index+i])
         return(false);
     }


   //--- ATR filter
   if(
      minAtrFilter>0.0 &&
      atr>0.0 &&
      index>0
      )
     {
      double move=
         high[index]-high[index-1];


      if(move<
         minAtrFilter*atr)
         return(false);
     }


   return(true);
  }


//+------------------------------------------------------------------+
//| STOCHASTIC SWING LOW                                             |
//+------------------------------------------------------------------+
bool IsStochSwingLow(
   int index,
   const double &stoch[],
   int left,
   int right
   )
  {
   int size=ArraySize(stoch);


   if(index<0 ||
      index>=size)
      return(false);


   if(index-left<0)
      return(false);


   if(index+right>=size)
      return(false);


   //--- Left side
   for(int i=1;i<=left;i++)
     {
      if(!ValidStoch(stoch[index-i]) || stoch[index]>=stoch[index-i])
         return(false);
     }


   //--- Right side
   for(int i=1;i<=right;i++)
     {
      if(!ValidStoch(stoch[index+i]) || stoch[index]>stoch[index+i])
         return(false);
     }


   return(true);
  }


//+------------------------------------------------------------------+
//| STOCHASTIC SWING HIGH                                            |
//+------------------------------------------------------------------+
bool IsStochSwingHigh(
   int index,
   const double &stoch[],
   int left,
   int right
   )
  {
   int size=ArraySize(stoch);


   if(index<0 ||
      index>=size)
      return(false);


   if(index-left<0)
      return(false);


   if(index+right>=size)
      return(false);


   //--- Left side
   for(int i=1;i<=left;i++)
     {
      if(!ValidStoch(stoch[index-i]) || stoch[index]<=stoch[index-i])
         return(false);
     }


   //--- Right side
   for(int i=1;i<=right;i++)
     {
      if(!ValidStoch(stoch[index+i]) || stoch[index]<stoch[index+i])
         return(false);
     }


   return(true);
  }

//+------------------------------------------------------------------+