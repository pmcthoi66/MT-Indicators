// Port of the user-supplied TradingView Stochastic Momentum Index.
// Canvas reproduces vertical alpha gradients; lines remain native buffers.
// Default: original blue/orange lines. EnableMomentumColors is optional.
// No blue zone background. No notes panel.
// Fill mask: between SMI and zero, visible only beyond +/-40 because the
// original Pine gradient is fully transparent between zero and +/-40.
// Alpha is anchored to oscillator VALUE, never to duration or wave area.
// Default opacity is 30% stronger than original: +/-40=0%, +/-80=32.5%, +/-100=48.75%, +/-120=65%.
// Current candle and its gradient update live, as in the original Pine.
// v2: compare completed excursions outside +/-40 (not full price swings).
// A = sum(abs(SMI)-40), in SMI points * bars; not volume or buying power.
// Compare same-side completed regions using peak EXCESS and area, 5% tolerance.
// Truncated first regions are excluded; active region is provisional.
// Divergence uses nearest price pivots and SMI values at those timestamps.
// Default: regular divergence ON, hidden OFF, no extreme-zone requirement.
// ConfirmColorOnClose affects only optional line colours, not the fill.
#property strict
#property version "2.04"
#property indicator_separate_window
#property indicator_buffers 13
#property indicator_plots 6
#property indicator_label1 "SMI"
#property indicator_type1 DRAW_COLOR_LINE
#property indicator_color1 C'0,160,70',C'150,220,160',C'220,50,60',C'245,165,170',C'33,150,243'
#property indicator_width1 2
#property indicator_label2 "SMI-based EMA"
#property indicator_type2 DRAW_LINE
#property indicator_color2 C'255,152,0'
#property indicator_label3 "Bullish SMI divergence (confirmed)"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrLimeGreen
#property indicator_width3 1
#property indicator_label4 "Bearish SMI divergence (confirmed)"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrTomato
#property indicator_width4 1
// Comparison outputs live in the Data Window; no notes drawn in the pane.
// -1 weaker, 0 similar, 1 stronger, 2 mixed; EMPTY until two complete regions.
#property indicator_label5 "Up region comparison (-1/0/1/2)"
#property indicator_type5 DRAW_NONE
#property indicator_label6 "Down region comparison (-1/0/1/2)"
#property indicator_type6 DRAW_NONE
#property indicator_level1 40
#property indicator_level2 -40
#property indicator_level3 0
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DASH
#include <Canvas\Canvas.mqh>
input int LengthK=10;   // %K Length
input int LengthD=3;    // %D Length
input int LengthEMA=3;  // EMA Length
input bool ShowFills=true;
input double FillMaxOpacityPercent=65.0; // At +/-120; 50 restores original Pine intensity
input group "Momentum upgrade"
input bool EnableMomentumColors=false; // false = original blue SMI
input bool ConfirmColorOnClose=true;  // live candle uses preceding closed candle's colour
input double MinSlope=0.5;            // SMI points/bar; hold previous direction below threshold
input color RisingStrength=C'0,160,70';
input color RisingWeakness=C'150,220,160';
input color FallingStrength=C'220,50,60';
input color FallingWeakness=C'245,165,170';
input group "Compare completed colour regions"
input double CompareTolerancePercent=5.0; // Neutral band for peak-excess and area ratios
input group "Price-SMI divergence"
input bool EnableDivergence=true;
input bool ShowHistory=false; // OFF: newest divergence only (both directions combined)
input bool RegularDivergence=true;
input bool HiddenDivergence=false;
input int PivotLeft=2;
input int PivotRight=2; // CLOSED candles to the right of price pivot
input int MinPivotGap=3;
input int MaxPivotGap=80;
input double MinSMIDifference=3.0;
input int DivergenceATRPeriod=14;
input double MinPriceDifferenceATR=0.0; // 0 = no additional ATR filter
input bool RequireExtremeZone=false; // At least one SMI endpoint beyond +/-40
input bool DivergenceOnPrice=true;
input bool DivergenceOnSMI=true;
input int MaxDivergencePairs=40;
// Price pivot endpoints are sampled on the SAME candles in SMI.
// No separate SMI pivot is required. Compare nearest same-side price pivot.
// Markers appear at the closed confirmation candle, not retroactively at pivot.
// Pivot lines connect past endpoints but exist only AFTER confirmation.
// Colour only: calculations, EMA and original gradient remain unchanged.
// Above zero: green strong if rising, pale green if falling.
// Below zero: red strong if falling, pale red if rising.
// MinSlope filters direction changes; it does not accumulate small slopes.
double SMI[],Colors[],Signal[],BullDiv[],BearDiv[],UpComparison[],DownComparison[],N1[],N2[],R1[],R2[],Direction[],DivATR[];
datetime Times[];
CCanvas Canvas;
string Name,Bitmap;
int W=0,H=0,Window=-1,CanvasWindow=-1;
bool Ready=false,Painting=false,NeedsRefresh=false;
string AnalysisPrefix;
int ProcessedClosed=-1,LastLowPivot=-1,LastHighPivot=-1;
int LastVisibleConfirmation=-1;
datetime AnalysisFirst=0,AnalysisLastClosed=0;
struct RegionStats
{
 int side,bars;
 bool partial; // A region cut by the beginning of available history is not comparable.
 double peak,area;
 datetime started,ended;
};
RegionStats ActiveRegion,LastUp,PrevUp,LastDown,PrevDown;
struct DivergencePair
{
 datetime t1,t2,known;
 double p1,p2,s1,s2;
 int kind;
 string regionComparison; // Snapshot at confirmation; never changes with later regions.
};
DivergencePair DivPairs[];
bool AnalysisDirty=true;
void DeleteDivObjects(datetime pivot)
{
 string key=AnalysisPrefix+"D_"+(string)(long)pivot;
 ObjectDelete(0,key+"_P"); ObjectDelete(0,key+"_S");
}
void ResetAnalysis()
{
 ZeroMemory(ActiveRegion); ZeroMemory(LastUp); ZeroMemory(PrevUp);
 ZeroMemory(LastDown); ZeroMemory(PrevDown);
 ProcessedClosed=-1; LastLowPivot=-1; LastHighPivot=-1; LastVisibleConfirmation=-1;
 AnalysisFirst=0; AnalysisLastClosed=0;
 ArrayFree(DivPairs); ObjectsDeleteAll(0,AnalysisPrefix+"D_");
 AnalysisDirty=true;
}
void AddRegionBar(int i)
{
 double value=SMI[i];
 int side=value==EMPTY_VALUE || !MathIsValidNumber(value)?0:(value>40?1:(value< -40?-1:0));
 if(ActiveRegion.side!=0 && side!=ActiveRegion.side)
 {
  if(!ActiveRegion.partial)
  {
   if(ActiveRegion.side>0) { PrevUp=LastUp; LastUp=ActiveRegion; }
   else { PrevDown=LastDown; LastDown=ActiveRegion; }
  }
  ZeroMemory(ActiveRegion);
 }
 if(side==0) return;
 if(ActiveRegion.side==0)
 { ActiveRegion.side=side; ActiveRegion.started=Times[i]; ActiveRegion.partial=i==0 || SMI[i-1]==EMPTY_VALUE; }
 ActiveRegion.bars++;
 ActiveRegion.peak=MathMax(ActiveRegion.peak,MathAbs(value));
 ActiveRegion.area+=MathAbs(value)-40.0;
 ActiveRegion.ended=Times[i];
}
double CompareRegionState(RegionStats &last,RegionStats &previous)
{
 if(last.bars==0 || previous.bars==0 || previous.peak<=40 || previous.area<=0) return EMPTY_VALUE;
 double dp=100*((last.peak-40)/(previous.peak-40)-1);
 double da=100*(last.area/previous.area-1);
 if(dp>CompareTolerancePercent && da>CompareTolerancePercent) return 1;
 if(dp< -CompareTolerancePercent && da< -CompareTolerancePercent) return -1;
 if(MathAbs(dp)<=CompareTolerancePercent && MathAbs(da)<=CompareTolerancePercent) return 0;
 return 2;
}
string CompareRegions(RegionStats &last,RegionStats &previous)
{
 if(last.bars==0) return "waiting for a completed region";
 string out="P="+DoubleToString(last.peak,1)+" N="+(string)last.bars+" A="+DoubleToString(last.area,1);
 if(previous.bars==0) return out+" | need previous region";
 double dp=100*((last.peak-40)/(previous.peak-40)-1);
 double da=100*(last.area/previous.area-1);
 string state="MIXED";
 if(dp>CompareTolerancePercent && da>CompareTolerancePercent) state="STRONGER";
 else if(dp< -CompareTolerancePercent && da< -CompareTolerancePercent) state="WEAKER";
 else if(MathAbs(dp)<=CompareTolerancePercent && MathAbs(da)<=CompareTolerancePercent) state="SIMILAR";
 return out+" | "+state+" (P "+DoubleToString(dp,0)+"%, A "+DoubleToString(da,0)+"%)";
}
bool DivLine(string key,int pane,DivergencePair &pair,bool price)
{
 int existing=ObjectFind(0,key);
 if(existing>=0 && existing!=pane) { ObjectDelete(0,key); existing=-1; }
 double a=price?pair.p1:pair.s1,b=price?pair.p2:pair.s2;
 if(existing<0 && !ObjectCreate(0,key,OBJ_TREND,pane,pair.t1,a,pair.t2,b)) return false;
 if(!ObjectMove(0,key,0,pair.t1,a) || !ObjectMove(0,key,1,pair.t2,b)) return false;
 ObjectSetInteger(0,key,OBJPROP_RAY_LEFT,false); ObjectSetInteger(0,key,OBJPROP_RAY_RIGHT,false);
 ObjectSetInteger(0,key,OBJPROP_COLOR,pair.kind>0?clrLimeGreen:clrTomato);
 ObjectSetInteger(0,key,OBJPROP_STYLE,MathAbs(pair.kind)==2?STYLE_DASH:STYLE_SOLID);
 ObjectSetInteger(0,key,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,key,OBJPROP_HIDDEN,true);
 string tip=(MathAbs(pair.kind)==2?"Hidden":"Regular")+(pair.kind>0?" bullish":" bearish")+" price-SMI divergence";
 tip+=" | Known at "+TimeToString(pair.known,TIME_DATE|TIME_MINUTES);
 tip+=" | SMI "+DoubleToString(pair.s1,2)+" -> "+DoubleToString(pair.s2,2);
 tip+=" | Region: "+pair.regionComparison;
 ObjectSetString(0,key,OBJPROP_TOOLTIP,tip);
 return true;
}
void RenderAnalysis()
{
 if(!AnalysisDirty) return;
 AnalysisDirty=false;
 int pane=ChartWindowFind();
 for(int j=0;j<ArraySize(DivPairs);j++)
 {
  string key=AnalysisPrefix+"D_"+(string)(long)DivPairs[j].t2;
  if(DivergenceOnPrice && !DivLine(key+"_P",0,DivPairs[j],true)) AnalysisDirty=true;
  if(DivergenceOnSMI)
  { if(pane<1 || !DivLine(key+"_S",pane,DivPairs[j],false)) AnalysisDirty=true; }
 }
}
void StoreDivergence(int p,int k,int confirmation,int kind,const double &price[])
{
 int n=ArraySize(DivPairs);
 int limit=ShowHistory?MaxDivergencePairs:1;
 if(n>=limit)
 {
  DeleteDivObjects(DivPairs[0].t2);
  for(int j=1;j<n;j++) DivPairs[j-1]=DivPairs[j];
  n--; ArrayResize(DivPairs,n);
 }
 if(ArrayResize(DivPairs,n+1)!=n+1) { Print("SMI: divergence storage allocation failed"); return; }
 DivPairs[n].t1=Times[p]; DivPairs[n].t2=Times[k];
 DivPairs[n].known=Times[confirmation+1];
 DivPairs[n].p1=price[p]; DivPairs[n].p2=price[k];
 DivPairs[n].s1=SMI[p]; DivPairs[n].s2=SMI[k]; DivPairs[n].kind=kind;
 DivPairs[n].regionComparison=kind>0?CompareRegions(LastDown,PrevDown):CompareRegions(LastUp,PrevUp);
 AnalysisDirty=true;
}
void CheckDivergence(int k,int confirmation,bool isLow,int previous,const double &price[])
{
 if(previous<0 || k-previous<MinPivotGap || k-previous>MaxPivotGap) return;
 if(SMI[previous]==EMPTY_VALUE || SMI[k]==EMPTY_VALUE || !MathIsValidNumber(SMI[previous]) || !MathIsValidNumber(SMI[k])) return;
 double dp=price[k]-price[previous],ds=SMI[k]-SMI[previous];
 if(MathAbs(ds)<MinSMIDifference) return;
 if(MinPriceDifferenceATR>0)
 {
  if(DivATR[k]==EMPTY_VALUE || !MathIsValidNumber(DivATR[k]) || DivATR[k]<=0 || MathAbs(dp)<MinPriceDifferenceATR*DivATR[k]) return;
 }
 if(RequireExtremeZone && (isLow?MathMin(SMI[k],SMI[previous])>=-40:MathMax(SMI[k],SMI[previous])<=40)) return;
 int kind=0;
 if(isLow)
 {
  if(RegularDivergence && dp<0 && ds>0) kind=1;
  else if(HiddenDivergence && dp>0 && ds<0) kind=2;
 }
 else
 {
  if(RegularDivergence && dp>0 && ds<0) kind=-1;
  else if(HiddenDivergence && dp<0 && ds>0) kind=-2;
 }
 if(kind==0) return;
 // Visibility only: detection and pivot calculations always retain full history.
 if(!ShowHistory && LastVisibleConfirmation>=0 && LastVisibleConfirmation<ArraySize(BullDiv))
 {
  BullDiv[LastVisibleConfirmation]=EMPTY_VALUE;
  BearDiv[LastVisibleConfirmation]=EMPTY_VALUE;
 }
 LastVisibleConfirmation=confirmation;
 // Marker on the actual confirmation candle; line endpoints remain price pivots.
 if(kind>0) BullDiv[confirmation]=SMI[confirmation];
 else BearDiv[confirmation]=SMI[confirmation];
 StoreDivergence(previous,k,confirmation,kind,price);
}
void AnalyzeClosed(int total,int prev,const double &high[],const double &low[])
{
 bool reset=prev<=0 || prev>total || AnalysisFirst!=Times[0] || ProcessedClosed>total-2;
 if(!reset && ProcessedClosed>=0 && Times[ProcessedClosed]!=AnalysisLastClosed) reset=true;
 if(reset)
 {
  ResetAnalysis(); ArrayInitialize(BullDiv,EMPTY_VALUE); ArrayInitialize(BearDiv,EMPTY_VALUE);
  ArrayInitialize(UpComparison,EMPTY_VALUE); ArrayInitialize(DownComparison,EMPTY_VALUE);
 }
 BullDiv[total-1]=EMPTY_VALUE; BearDiv[total-1]=EMPTY_VALUE;
 for(int i=ProcessedClosed+1;i<=total-2;i++)
 {
  BullDiv[i]=EMPTY_VALUE; BearDiv[i]=EMPTY_VALUE;
  if(IsStopped()) return;
  AddRegionBar(i);
  UpComparison[i]=CompareRegionState(LastUp,PrevUp);
  DownComparison[i]=CompareRegionState(LastDown,PrevDown);
  int k=i-PivotRight;
  if(EnableDivergence && k>=PivotLeft && SMI[k]!=EMPTY_VALUE)
  {
   bool isLow=true,isHigh=true;
   // Strict comparison on left, allow equal values on right (first of plateau).
   for(int j=1;j<=PivotLeft;j++)
   { if(low[k]>=low[k-j]) isLow=false; if(high[k]<=high[k-j]) isHigh=false; }
   for(int j=1;j<=PivotRight;j++)
   { if(low[k]>low[k+j]) isLow=false; if(high[k]<high[k+j]) isHigh=false; }
   // Outside bars with both pivot types are ambiguous; exclude from pairing.
   if(isLow && !isHigh) { CheckDivergence(k,i,true,LastLowPivot,low); LastLowPivot=k; }
   if(isHigh && !isLow) { CheckDivergence(k,i,false,LastHighPivot,high); LastHighPivot=k; }
  }
  ProcessedClosed=i; AnalysisLastClosed=Times[i];
 }
 UpComparison[total-1]=ProcessedClosed>=0?UpComparison[ProcessedClosed]:EMPTY_VALUE;
 DownComparison[total-1]=ProcessedClosed>=0?DownComparison[ProcessedClosed]:EMPTY_VALUE;
 AnalysisFirst=Times[0];
}

// Pine RGB ramp retained. Maximum opacity is adjustable at +/-120.
// Pine v6 red: #F23645. Both sides use the same opacity ramp.
uint Shade(double v)
{
 double t=MathMin(1.0,MathMax(0.0,(MathAbs(v)-40.0)/80.0));
 color c=v>=0? (color)(76|(175<<8)|((int)MathRound(80.0-t)<<16)) : C'242,54,69';
 return ColorToARGB(c,(uchar)MathRound(MathRound(255.0*FillMaxOpacityPercent/100.0)*t));
}
void Paint()
{
 if(!Ready || Painting || IsStopped()) return;
 if(!ShowFills)
 {
  if(W>0) { Canvas.Destroy(); W=0; H=0; CanvasWindow=-1; }
  return;
 }
 Painting=true;
 Window=ChartWindowFind();
 if(Window<1) { NeedsRefresh=true; Painting=false; return; }
 int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,Window);
 int height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,Window);
 if(width<2 || height<2) { NeedsRefresh=true; Painting=false; return; }
 if(width!=W || height!=H || CanvasWindow!=Window || ObjectFind(0,Bitmap)<0)
 {
  Canvas.Destroy(); W=width; H=height;
  if(!Canvas.CreateBitmapLabel(0,Window,Bitmap,0,0,W,H,COLOR_FORMAT_ARGB_NORMALIZE))
  { Print("SMI: canvas creation failed ",GetLastError()); W=0; H=0; Painting=false; return; }
  CanvasWindow=Window;
  ObjectSetInteger(0,Bitmap,OBJPROP_BACK,true);
  ObjectSetInteger(0,Bitmap,OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,Bitmap,OBJPROP_HIDDEN,true);
 }
 Canvas.Erase(0);
 double top=ChartGetDouble(0,CHART_PRICE_MAX,Window);
 double bottom=ChartGetDouble(0,CHART_PRICE_MIN,Window);
 if(top<=bottom) { NeedsRefresh=true; Painting=false; return; }
 int offset=(int)ChartGetInteger(0,CHART_WINDOW_YDISTANCE,Window);
 // Use MT5's actual drawing coordinates, not the total subwindow height.
 // Subwindow borders can make height-based conversion disagree with plot pixels.
 int anchorX,topY,bottomY;
 int count=ArraySize(Times);
 if(count<1 || !ChartTimePriceToXY(0,Window,Times[count-1],top,anchorX,topY) ||
    !ChartTimePriceToXY(0,Window,Times[count-1],bottom,anchorX,bottomY) || bottomY<=topY)
 { NeedsRefresh=true; Painting=false; return; }
 topY-=offset; bottomY-=offset;
 double pixelsPerValue=(double)(bottomY-topY)/(top-bottom);

 uint shades[];
 if(ArrayResize(shades,H)!=H) { NeedsRefresh=true; Painting=false; return; }
 for(int y=0;y<H;y++)
 {
  double v=top-((y+0.5)-topY)/pixelsPerValue;
  // Cache vertical colour ramp once per row. No time-based colour accumulation.
  shades[y]=Shade(v);
 }
 if(ShowFills)
 {
  int first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
  int visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS);
  int begin=MathMax(0,count-2-first),end=MathMin(count-1,count-first+visible+2);
  for(int i=begin;i<end;i++)
  {
   if(SMI[i]==EMPTY_VALUE || SMI[i+1]==EMPTY_VALUE ||
      !MathIsValidNumber(SMI[i]) || !MathIsValidNumber(SMI[i+1])) continue;
   int x0,y0,x1,y1;
   if(!ChartTimePriceToXY(0,Window,Times[i],SMI[i],x0,y0) ||
      !ChartTimePriceToXY(0,Window,Times[i+1],SMI[i+1],x1,y1) || x1<=x0) continue;
   for(int x=MathMax(0,x0);x<MathMin(W,x1);x++)
   {
    double f=((double)x+0.5-x0)/(x1-x0);
    double val=SMI[i]+f*(SMI[i+1]-SMI[i]);
    if(MathAbs(val)<=40) continue;
    double ya=topY+(top-val)*pixelsPerValue;
    double yb=topY+(top-(val>0?40.0:-40.0))*pixelsPerValue;
    int a=MathMax(MathMax(0,topY),(int)MathFloor(MathMin(ya,yb)));
    int b=MathMin(MathMin(H-1,bottomY),(int)MathFloor(MathMax(ya,yb)));
    for(int y=a;y<=b;y++)
    {
     // Fractional edge coverage avoids jagged gaps at the SMI boundary.
     double coverage=MathMax(0.0,MathMin((double)y+1,MathMax(ya,yb))-MathMax((double)y,MathMin(ya,yb)));
     uint shade=shades[y];
     uint alpha=(uint)MathRound((shade>>24)*coverage);
     shade=(shade&0x00FFFFFF)|(alpha<<24);
     Canvas.PixelSet(x,y,shade);
    }
   }
  }
 }
 Canvas.Update(false); Painting=false;
}
int OnInit()
{
 if(!MathIsValidNumber(FillMaxOpacityPercent) || FillMaxOpacityPercent<0 || FillMaxOpacityPercent>100) return INIT_PARAMETERS_INCORRECT;
 if(PivotLeft<1 || PivotLeft>1000 || PivotRight<1 || PivotRight>1000 ||
    MinPivotGap<1 || MaxPivotGap<MinPivotGap || MaxPivotGap>100000 ||
    MaxDivergencePairs<1 || MaxDivergencePairs>500 || DivergenceATRPeriod<1 || DivergenceATRPeriod>10000 ||
    !MathIsValidNumber(CompareTolerancePercent) || CompareTolerancePercent<0 ||
    !MathIsValidNumber(MinSMIDifference) || MinSMIDifference<0 ||
    !MathIsValidNumber(MinPriceDifferenceATR) || MinPriceDifferenceATR<0) return INIT_PARAMETERS_INCORRECT;
 if(!MathIsValidNumber(MinSlope) || MinSlope<0) return INIT_PARAMETERS_INCORRECT;
 if(LengthK<1 || LengthK>15000 || LengthD<1 || LengthD>4999 || LengthEMA<1 || LengthEMA>4999) return INIT_PARAMETERS_INCORRECT;
 bool bufferOK=true;
 bufferOK=SetIndexBuffer(0,SMI,INDICATOR_DATA) && bufferOK;
 bufferOK=SetIndexBuffer(1,Colors,INDICATOR_COLOR_INDEX) && bufferOK;
 bufferOK=SetIndexBuffer(2,Signal,INDICATOR_DATA) && bufferOK;
 bufferOK=SetIndexBuffer(3,BullDiv,INDICATOR_DATA) && bufferOK; bufferOK=SetIndexBuffer(4,BearDiv,INDICATOR_DATA) && bufferOK;
 bufferOK=SetIndexBuffer(5,UpComparison,INDICATOR_DATA) && bufferOK; bufferOK=SetIndexBuffer(6,DownComparison,INDICATOR_DATA) && bufferOK;
 bufferOK=SetIndexBuffer(7,N1,INDICATOR_CALCULATIONS) && bufferOK; bufferOK=SetIndexBuffer(8,N2,INDICATOR_CALCULATIONS) && bufferOK;
 bufferOK=SetIndexBuffer(9,R1,INDICATOR_CALCULATIONS) && bufferOK; bufferOK=SetIndexBuffer(10,R2,INDICATOR_CALCULATIONS) && bufferOK;
 bufferOK=SetIndexBuffer(11,Direction,INDICATOR_CALCULATIONS) && bufferOK; bufferOK=SetIndexBuffer(12,DivATR,INDICATOR_CALCULATIONS) && bufferOK;
 if(!bufferOK) { Print("SMI: buffer registration failed ",GetLastError()); return INIT_FAILED; }
 ArraySetAsSeries(UpComparison,false); ArraySetAsSeries(DownComparison,false);
 PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,EMPTY_VALUE); PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 PlotIndexSetInteger(4,PLOT_SHOW_DATA,true); PlotIndexSetInteger(5,PLOT_SHOW_DATA,true);
 ArraySetAsSeries(BullDiv,false); ArraySetAsSeries(BearDiv,false); ArraySetAsSeries(DivATR,false);
 PlotIndexSetInteger(2,PLOT_ARROW,233); PlotIndexSetInteger(3,PLOT_ARROW,234);
 PlotIndexSetInteger(2,PLOT_ARROW_SHIFT,8); PlotIndexSetInteger(3,PLOT_ARROW_SHIFT,-8);
 PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,EMPTY_VALUE); PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 ArraySetAsSeries(Colors,false); ArraySetAsSeries(Direction,false);
 PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,5);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,RisingStrength);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,RisingWeakness);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,2,FallingStrength);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,3,FallingWeakness);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,4,C'33,150,243');
 ArraySetAsSeries(SMI,false); ArraySetAsSeries(Signal,false);
 ArraySetAsSeries(N1,false); ArraySetAsSeries(N2,false); ArraySetAsSeries(R1,false); ArraySetAsSeries(R2,false);
 Name="Stoch MI Waves Div 2.04 ("+(string)LengthK+","+(string)LengthD+","+(string)LengthEMA+")";
 AnalysisPrefix="SMI_WD_"+(string)GetMicrosecondCount()+"_";
 Bitmap=AnalysisPrefix+"Fill";
 Ready=false; Painting=false; W=0; H=0; CanvasWindow=-1;
 ResetAnalysis();
 IndicatorSetString(INDICATOR_SHORTNAME,Name); IndicatorSetInteger(INDICATOR_DIGITS,3);
 PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE); PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 if(!EventSetMillisecondTimer(250)) { Print("SMI: timer creation failed ",GetLastError()); return INIT_FAILED; }
 return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { EventKillTimer(); Canvas.Destroy(); if(AnalysisPrefix!="") ObjectsDeleteAll(0,AnalysisPrefix); }
void OnTimer()
{
 RenderAnalysis();
 if(Ready && (NeedsRefresh || (ShowFills && W==0)))
 {
  NeedsRefresh=false;
  Paint();
  ChartRedraw();
 }
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{ if(id==CHARTEVENT_CHART_CHANGE) { NeedsRefresh=true; AnalysisDirty=true; } }
int OnCalculate(const int total,const int prev,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
 if(total<1) return 0;
 ArraySetAsSeries(time,false); ArraySetAsSeries(high,false); ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
 int oldSize=ArraySize(Times);
 bool reset=prev<=0 || prev>total || oldSize!=prev;
 if(!reset && oldSize>0 && (Times[0]!=time[0] || Times[oldSize-1]!=time[oldSize-1])) reset=true;
 if(ArrayResize(Times,total)!=total) { Ready=false; Print("SMI: time array allocation failed"); return 0; }
 int start=reset?0:prev-1;
 // Monotonic queues make the initial highest/lowest calculation O(bars),
 // rather than O(bars*LengthK). Rebuild the last window on each tick so
 // the live candle can move in either direction without stale extrema.
 int highQueue[],lowQueue[];
 if(ArrayResize(highQueue,LengthK)!=LengthK || ArrayResize(lowQueue,LengthK)!=LengthK)
 { Ready=false; Print("SMI: extrema allocation failed"); return 0; }
 int highHead=0,highCount=0,lowHead=0,lowCount=0;
 int warmStart=MathMax(0,start-LengthK+1);
 double ad=2.0/(LengthD+1),ae=2.0/(LengthEMA+1);
 for(int i=warmStart;i<total;i++)
 {
  if(IsStopped()) return 0;
  // BEGIN EXTREMA QUEUE
  while(highCount>0 && highQueue[highHead]<=i-LengthK)
  { highHead=(highHead+1)%LengthK; highCount--; }
  while(lowCount>0 && lowQueue[lowHead]<=i-LengthK)
  { lowHead=(lowHead+1)%LengthK; lowCount--; }
  while(highCount>0 && high[highQueue[(highHead+highCount-1)%LengthK]]<=high[i]) highCount--;
  while(lowCount>0 && low[lowQueue[(lowHead+lowCount-1)%LengthK]]>=low[i]) lowCount--;
  highQueue[(highHead+highCount)%LengthK]=i; highCount++;
  lowQueue[(lowHead+lowCount)%LengthK]=i; lowCount++;
  // END EXTREMA QUEUE
  if(i<start) continue;
  Times[i]=time[i];
  if(i<DivergenceATRPeriod-1) DivATR[i]=EMPTY_VALUE;
  else
  {
   double tr=MathMax(high[i]-low[i],i>0?MathMax(MathAbs(high[i]-close[i-1]),MathAbs(low[i]-close[i-1])):0);
   if(i==DivergenceATRPeriod-1)
   {
    double sum=0;
    for(int j=0;j<=i;j++) sum+=MathMax(high[j]-low[j],j>0?MathMax(MathAbs(high[j]-close[j-1]),MathAbs(low[j]-close[j-1])):0);
    DivATR[i]=sum/DivergenceATRPeriod;
   }
   else DivATR[i]=(DivATR[i-1]*(DivergenceATRPeriod-1)+tr)/DivergenceATRPeriod;
  }
  double hh=high[highQueue[highHead]],ll=low[lowQueue[lowHead]];
  double n=close[i]-(hh+ll)/2.0,r=hh-ll;
  N1[i]=i==0?n:ad*n+(1-ad)*N1[i-1];
  N2[i]=i==0?N1[i]:ad*N1[i]+(1-ad)*N2[i-1];
  R1[i]=i==0?r:ad*r+(1-ad)*R1[i-1];
  R2[i]=i==0?R1[i]:ad*R1[i]+(1-ad)*R2[i-1];
  SMI[i]=R2[i]==0?EMPTY_VALUE:200*N2[i]/R2[i];
  Signal[i]=SMI[i]==EMPTY_VALUE?(i==0?EMPTY_VALUE:Signal[i-1]):
             (i==0 || Signal[i-1]==EMPTY_VALUE?SMI[i]:ae*SMI[i]+(1-ae)*Signal[i-1]);
  Direction[i]=i>0?Direction[i-1]:0;
  if(i>0 && SMI[i]!=EMPTY_VALUE && SMI[i-1]!=EMPTY_VALUE)
  {
   double change=SMI[i]-SMI[i-1];
   if(change>0 && change>=MinSlope) Direction[i]=1;
   else if(change<0 && -change>=MinSlope) Direction[i]=-1;
  }
  int ref=(ConfirmColorOnClose && i==total-1 && i>0)?i-1:i;
  Colors[i]=4;
  if(EnableMomentumColors && SMI[ref]!=EMPTY_VALUE && Direction[ref]!=0)
   Colors[i]=SMI[ref]>=0?(Direction[ref]>0?0:1):(Direction[ref]<0?2:3);

 }
 AnalyzeClosed(total,reset?0:prev,high,low);
 if(IsStopped()) return 0;
 Ready=true; NeedsRefresh=true; return total;
}
