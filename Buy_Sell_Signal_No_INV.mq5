// Revision 1.01: avoid synchronous per-history-bar chart scans.
// Faithful calculation port of the supplied Pine v6 Buy Sell Signal.
// Indicator only: does not place orders. Current candle is recalculated from
// the preceding closed candle, reproducing Pine's ordinary var rollback.
#property strict
#property version "1.02"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 2
#property indicator_type1 DRAW_LINE
#property indicator_type2 DRAW_LINE
#property indicator_label1 "Fast EMA"
#property indicator_label2 "Slow EMA"
input int emaFastLen=5;
input int emaSlowLen=13;
input int atrLen=14;
input double atrMultSL=0.5;
input double riskReward=3.0;
input bool confirmCandle=true; // Candle colour confirmation, NOT bar-close confirmation
input group "EMAs"
input bool showEmaFastLabel=true;
input color emaFastColor=C'0,128,0';
input bool showEmaSlowLabel=true;
input color emaSlowColor=C'255,152,0';
input group "Alerts (MT5 delivery settings)"
input bool PopupAlerts=false;
input bool PushAlerts=false;
input bool EmailAlerts=false;
input bool AlertsOnClosedBar=false;
double Fast[],Slow[];
struct BarState {
 double entry,sl,tp,atr,trsum;
 int side;
 string flags;
 bool hadTable;
 double tableEntry,tableSL,tableTP;
};
BarState State[];
string Prefix;
datetime AlertTime=0;
int AlertMask=0;
bool FirstCalculation=true;
bool ObjectErrorReported=false;
string TPObjects[];
color PineGreen=C'0,128,0';
void Common(string n) {
 ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
 ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void Text(string id,datetime t,double y,string s,color c,bool above,int size=9) {
 string n=Prefix+id;
 if(!ObjectCreate(0,n,OBJ_TEXT,0,t,y) && !ObjectErrorReported) {
  Print("BSS 1.02: ObjectCreate failed, error=",GetLastError()," name=",n);
  ObjectErrorReported=true;
 }
 ObjectMove(0,n,0,t,y);
 ObjectSetString(0,n,OBJPROP_TEXT,s);
 ObjectSetString(0,n,OBJPROP_FONT,"Arial");
 ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
 ObjectSetInteger(0,n,OBJPROP_COLOR,c);
 ObjectSetInteger(0,n,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER);
 Common(n);
}
void Level(string id,datetime a,datetime b,double price,color c,int width,ENUM_LINE_STYLE style) {
 string n=Prefix+"L_"+id;
 if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TREND,0,a,price,b,price);
 ObjectMove(0,n,0,a,price); ObjectMove(0,n,1,b,price);
 ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
 ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,false);
 ObjectSetInteger(0,n,OBJPROP_COLOR,c);
 ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
 ObjectSetInteger(0,n,OBJPROP_STYLE,style); Common(n);
}
void Cell(int row,int col,string text,color c) {
 string n=Prefix+"T_"+(string)row+"_"+(string)col;
 if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
 ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
 ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
 ObjectSetInteger(0,n,OBJPROP_XDISTANCE,col==0?116:12);
 ObjectSetInteger(0,n,OBJPROP_YDISTANCE,16+row*20);
 ObjectSetInteger(0,n,OBJPROP_COLOR,c);
 ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9);
 ObjectSetString(0,n,OBJPROP_FONT,"Arial");
 ObjectSetString(0,n,OBJPROP_TEXT,text); Common(n);
}
// Pine's for 1 to floor(RR)-1 descends for RR in [1,2), yielding 1,0.
// Preserve this source behaviour, even though TP0 is unusual.
int TPCount() { int end=(int)MathFloor(riskReward)-1; return end>=1?end:2; }
int TPMultiple(int k) { return ((int)MathFloor(riskReward)-1>=1)?k+1:1-k; }
double TPPrice(BarState &s,int k) { return s.entry+s.side*MathAbs(s.entry-s.sl)*TPMultiple(k); }
void Notify(datetime t,int mask,double price) {
 if(t!=AlertTime) { AlertTime=t; AlertMask=0; }
 int fresh=mask & (~AlertMask); AlertMask|=mask;
 string names[5]={"BUY Signal","SELL Signal","Final Take Profit","Stop Loss","Entry Invalidated"};
 for(int k=0;k<5;k++) if((fresh & (1<<k))!=0) {
  string msg=names[k]+" | "+_Symbol+" | "+EnumToString(_Period)+" | Price: "+DoubleToString(price,_Digits);
  if(PopupAlerts) Alert(msg);
  if(PushAlerts) SendNotification(msg);
  if(EmailAlerts) SendMail("Buy Sell Signal",msg);
 }
}
int OnInit() {
 if(emaFastLen<1 || emaSlowLen<1 || atrLen<1 || atrMultSL<0.1 || riskReward<1.0 || !MathIsValidNumber(riskReward)) return INIT_PARAMETERS_INCORRECT;
 Prefix="BSS_"+(string)ChartID()+"_"+(string)GetMicrosecondCount()+"_";
 ResetLastError();
 if(!SetIndexBuffer(0,Fast,INDICATOR_DATA) || !SetIndexBuffer(1,Slow,INDICATOR_DATA)) {
  Print("BSS 1.02: SetIndexBuffer failed, error=",GetLastError());
  return INIT_FAILED;
 }
 ArraySetAsSeries(Fast,false); ArraySetAsSeries(Slow,false);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,emaFastColor);
 PlotIndexSetInteger(1,PLOT_LINE_COLOR,emaSlowColor);
 PlotIndexSetInteger(0,PLOT_DRAW_TYPE,showEmaFastLabel?DRAW_LINE:DRAW_NONE);
 PlotIndexSetInteger(1,PLOT_DRAW_TYPE,showEmaSlowLabel?DRAW_LINE:DRAW_NONE);
 IndicatorSetString(INDICATOR_SHORTNAME,"Buy Sell Signal 1.02");
 IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
 PlotIndexSetInteger(0,PLOT_LINE_WIDTH,1); PlotIndexSetInteger(1,PLOT_LINE_WIDTH,1);
 PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,0); PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,0);
 PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE); PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 Cell(0,0,"BSS 1.02:",clrWhite); Cell(0,1,"Waiting for data",clrYellow);
 Print("BSS 1.02: INIT OK | ",_Symbol," | ",EnumToString(_Period));
 ChartRedraw();
 return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { ObjectsDeleteAll(0,Prefix); }
int OnCalculate(const int total,const int previous,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[]) {
 bool diagnostic=FirstCalculation || previous==0;
 if(diagnostic) Print("BSS 1.02: CALCULATE BEGIN | bars=",total," previous=",previous,
                      " fast_buffer=",ArraySize(Fast)," slow_buffer=",ArraySize(Slow));
 if(total<1) return 0;
 ArraySetAsSeries(Fast,false); ArraySetAsSeries(Slow,false);
 ArraySetAsSeries(time,false); ArraySetAsSeries(open,false); ArraySetAsSeries(high,false);
 ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
 bool reset=previous<=0 || previous>total || ArraySize(State)<previous;
 if(reset) { ObjectsDeleteAll(0,Prefix); ArrayResize(State,0); ArrayResize(TPObjects,0); }
 if(ArrayResize(State,total)!=total) {
  Print("BSS 1.02: state allocation failed | bars=",total," error=",GetLastError());
  Cell(0,1,"Memory error",clrRed); return 0;
 }
 int start=reset?0:MathMax(0,previous-1);
 double af=2.0/(emaFastLen+1.0),as=2.0/(emaSlowLen+1.0);
 for(int i=start;i<total && !IsStopped();i++) {
  if(diagnostic && i>0 && i%25000==0) Print("BSS 1.02: calculating ",i,"/",total);
  BarState s; ZeroMemory(s);
  if(i>0) s=State[i-1];
  Fast[i]=i==0?close[i]:af*close[i]+(1-af)*Fast[i-1];
  Slow[i]=i==0?close[i]:as*close[i]+(1-as)*Slow[i-1];
  double tr=i==0?high[i]-low[i]:MathMax(high[i]-low[i],MathMax(MathAbs(high[i]-close[i-1]),MathAbs(low[i]-close[i-1])));
  if(i<atrLen) { s.trsum+=tr; s.atr=i==atrLen-1?s.trsum/atrLen:EMPTY_VALUE; }
  else s.atr=(State[i-1].atr*(atrLen-1)+tr)/atrLen;
  bool bull=Fast[i]>Slow[i],bear=Fast[i]<Slow[i];
  bool priorBull=i>0 && Fast[i-1]>Slow[i-1];
  bool change=bull!=priorBull;
  bool buy=bull && change && (!confirmCandle || close[i]>open[i]);
  bool sell=bear && change && (!confirmCandle || close[i]<open[i]);
  bool finalHit=false,slHit=false,inv=false,showBuy=false,showSell=false;
  int invalidSide=0;
  if(s.side!=0) {
   if(s.tp!=EMPTY_VALUE && (s.side==1?high[i]>=s.tp:low[i]<=s.tp)) { finalHit=true; s.side=0; }
   else if(s.sl!=EMPTY_VALUE && (s.side==1?low[i]<=s.sl:high[i]>=s.sl)) { slHit=true; s.side=0; }
  }
  int count=TPCount();
  if(s.side!=0) for(int k=0;k<count;k++) {
   if(StringSubstr(s.flags,k,1)=="0" && s.sl!=EMPTY_VALUE && (s.side==1?high[i]>=TPPrice(s,k):low[i]<=TPPrice(s,k)))
    s.flags=StringSubstr(s.flags,0,k)+"1"+StringSubstr(s.flags,k+1);
  }
  int newSide=buy?1:(sell?-1:0);
  if(newSide!=0 && s.side!=newSide) {
   if(s.side!=0) { inv=true; invalidSide=s.side; }
   s.side=newSide; s.entry=close[i];
   s.sl=s.atr==EMPTY_VALUE?EMPTY_VALUE:(newSide==1?low[i]-s.atr*atrMultSL:high[i]+s.atr*atrMultSL);
   s.tp=s.sl==EMPTY_VALUE?EMPTY_VALUE:s.entry+newSide*MathAbs(s.entry-s.sl)*riskReward;
   s.flags=""; for(int k=0;k<count;k++) s.flags+="0";
   showBuy=newSide==1; showSell=newSide==-1;
  }
  string key="B_"+(string)(long)time[i]+"_";
  // Delete only this recalculated bar's transient shapes (Pine rollback).
  if(!reset) {
   ObjectDelete(0,Prefix+key+"BUY"); ObjectDelete(0,Prefix+key+"SELL");
   ObjectDelete(0,Prefix+key+"BUY_LETTER"); ObjectDelete(0,Prefix+key+"SELL_LETTER");
   ObjectDelete(0,Prefix+key+"FINAL"); ObjectDelete(0,Prefix+key+"SL");
   ObjectDelete(0,Prefix+key+"INV");
   for(int k=0;k<count;k++) ObjectDelete(0,Prefix+key+"TP"+(string)k);
  }
  double gap=MathMax((high[i]-low[i])*0.12,10*_Point);
  if(showBuy) {
   Text(key+"BUY",time[i],low[i],"▲",clrLime,false);
   Text(key+"BUY_LETTER",time[i],low[i],"B",clrLime,true,8);
  }
  if(showSell) {
   Text(key+"SELL",time[i],high[i],"▼",clrRed,true);
   Text(key+"SELL_LETTER",time[i],high[i]+gap,"S",clrRed,true,8);
  }
  if(finalHit) Text(key+"FINAL",time[i],high[i]+2*gap,"● TP",clrLime,true);
  if(slHit) Text(key+"SL",time[i],low[i]-2*gap,"× SL",clrRed,false);
  // Invalidation labels hidden; trade state and alerts remain unchanged.
  if(s.side!=0) for(int k=0;k<count;k++) if(StringSubstr(s.flags,k,1)=="1") {
   string tpName=Prefix+key+"TP"+(string)k;
   Text(key+"TP"+(string)k,time[i],high[i]+(4+k)*gap,"TP"+(string)(k+1),PineGreen,true,8);
   bool tracked=false;
   for(int j=0;j<ArraySize(TPObjects);j++) if(TPObjects[j]==tpName) { tracked=true; break; }
   if(!tracked) {
    int n=ArraySize(TPObjects);
    if(n>=50) {
     ObjectDelete(0,TPObjects[0]);
     for(int j=1;j<n;j++) TPObjects[j-1]=TPObjects[j];
     TPObjects[n-1]=tpName;
    } else { ArrayResize(TPObjects,n+1); TPObjects[n]=tpName; }
   }
   s.flags=StringSubstr(s.flags,0,k)+"2"+StringSubstr(s.flags,k+1);
  }
  if(s.side!=0) { s.hadTable=true; s.tableEntry=s.entry; s.tableSL=s.sl; s.tableTP=s.tp; }
  State[i]=s;
  int mask=(showBuy?1:0)|(showSell?2:0)|(finalHit?4:0)|(slHit?8:0)|(inv?16:0);
  if(!reset && i==(AlertsOnClosedBar?total-2:total-1)) Notify(time[i],mask,close[i]);
 }
 BarState last=State[total-1];
 if(last.side==0 || last.sl==EMPTY_VALUE) ObjectsDeleteAll(0,Prefix+"L_");
 int sec=PeriodSeconds(_Period); if(sec<=0) sec=60;
 datetime now=time[total-1],next=now+sec;
 if(last.side!=0) {
  datetime left=total>10?time[total-11]:now-10*sec;
  Level("Entry",left,now+10*sec,last.entry,clrWhite,1,STYLE_DASH);
  if(last.sl!=EMPTY_VALUE) {
   Level("SL",now,next,last.sl,clrRed,2,STYLE_SOLID);
   Level("Final",now,next,last.tp,PineGreen,2,STYLE_SOLID);
   color bg=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   int r=(int)(0.4*0+0.6*(bg&255));
   int g=(int)(0.4*128+0.6*((bg>>8)&255));
   int b=(int)(0.4*0+0.6*((bg>>16)&255));
   color soft=(color)(r|(g<<8)|(b<<16));
   for(int k=0;k<TPCount();k++) Level("TP"+(string)k,now,next,TPPrice(last,k),soft,1,STYLE_DOT);
  }
 }
 Cell(0,0,"Status:",clrWhite);
 Cell(0,1,last.side==1?"LONG":last.side==-1?"SHORT":"No Position",last.side!=0?clrYellow:clrGray);
 // Original table does not clear the preceding position's rows on exit.
 if(last.hadTable) {
  Cell(1,0,"Entry:",clrWhite); Cell(1,1,DoubleToString(last.tableEntry,2),clrWhite);
  Cell(2,0,"Stop Loss:",clrWhite); Cell(2,1,last.tableSL==EMPTY_VALUE?"NaN":DoubleToString(last.tableSL,2),clrRed);
  Cell(3,0,"Take Profit:",clrWhite); Cell(3,1,last.tableTP==EMPTY_VALUE?"NaN":DoubleToString(last.tableTP,2),PineGreen);
  Cell(4,0,"R:R:",clrWhite); Cell(4,1,last.tableSL==EMPTY_VALUE?"NaN:1":DoubleToString(riskReward,2)+":1",C'255,152,0');
 }
 if(diagnostic) {
  Print("BSS 1.02: CALCULATE OK | last=",TimeToString(time[total-1]),
        " close=",close[total-1]," fast=",Fast[total-1]," slow=",Slow[total-1],
        " fast_visible=",showEmaFastLabel," slow_visible=",showEmaSlowLabel);
  FirstCalculation=false;
 }
 ChartRedraw(); return total;
}
