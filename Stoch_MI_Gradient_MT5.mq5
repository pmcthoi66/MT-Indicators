// Port of the user-supplied TradingView Stochastic Momentum Index.
// Canvas reproduces vertical alpha gradients; lines remain native buffers.
// Default: original blue/orange lines. EnableMomentumColors is optional.
// Fill mask: between SMI and zero, visible only beyond +/-40 because the
// original Pine gradient is fully transparent between zero and +/-40.
// Alpha is anchored to oscillator VALUE, never to duration or wave area.
// +40/-40: 0 opacity; +80/-80: 25%; +100/-100: 37.5%; +/-120: 50%.
// Current candle and its gradient update live, as in the original Pine.
// ConfirmColorOnClose affects only optional line colours, not the fill.
#property strict
#property version "1.12"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots 2
#property indicator_label1 "SMI"
#property indicator_type1 DRAW_COLOR_LINE
#property indicator_color1 C'0,160,70',C'150,220,160',C'220,50,60',C'245,165,170',C'33,150,243'
#property indicator_width1 2
#property indicator_label2 "SMI-based EMA"
#property indicator_type2 DRAW_LINE
#property indicator_color2 C'255,152,0'
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
input group "Momentum upgrade"
input bool EnableMomentumColors=false; // false = original blue SMI
input bool ConfirmColorOnClose=true;  // live candle uses preceding closed candle's colour
input double MinSlope=0.5;            // SMI points/bar; hold previous direction below threshold
input color RisingStrength=C'0,160,70';
input color RisingWeakness=C'150,220,160';
input color FallingStrength=C'220,50,60';
input color FallingWeakness=C'245,165,170';
// Colour only: calculations, EMA and original gradient remain unchanged.
// Above zero: green strong if rising, pale green if falling.
// Below zero: red strong if falling, pale red if rising.
// MinSlope filters direction changes; it does not accumulate small slopes.
double SMI[],Colors[],Signal[],N1[],N2[],R1[],R2[],Direction[];
datetime Times[];
CCanvas Canvas;
string Name,Bitmap;
int W=0,H=0,Window=-1,CanvasWindow=-1;
bool Ready=false,Painting=false,NeedsRefresh=false;
uint Blend(uint under,uint over)
{
 double a=(double)(over>>24)/255.0;
 int r,g,b;
 // under has alpha too; combine in straight-alpha space.
 double ua=(double)(under>>24)/255.0, outa=a+ua*(1-a);
 if(outa<=0) return 0;
 r=(int)MathRound((((over>>16)&255)*a+((under>>16)&255)*ua*(1-a))/outa);
 g=(int)MathRound((((over>>8)&255)*a+((under>>8)&255)*ua*(1-a))/outa);
 b=(int)MathRound(((over&255)*a+(under&255)*ua*(1-a))/outa);
 return ((uint)MathRound(outa*255)<<24)|((uint)r<<16)|((uint)g<<8)|(uint)b;
}
// Pine: green #4CAF50 at +40 (transparent), #4CAF4F at +120 (50%).
// Pine v6 red: #F23645 at -40 (transparent) and -120 (50%).
uint Shade(double v)
{
 double t=MathMin(1.0,MathMax(0.0,(MathAbs(v)-40.0)/80.0));
 color c=v>=0? (color)(76|(175<<8)|((int)MathRound(80.0-t)<<16)) : C'242,54,69';
 return ColorToARGB(c,(uchar)MathRound(128.0*t));
}
void Paint()
{
 if(!Ready || Painting) return;
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

 uint rows[],shades[]; ArrayResize(rows,H); ArrayResize(shades,H);
 for(int y=0;y<H;y++)
 {
  double v=top-((y+0.5)-topY)/pixelsPerValue;
  // Cache vertical colour ramp once per row. No time-based colour accumulation.
  shades[y]=Shade(v);
  double zoneTop=topY+(top-40.0)*pixelsPerValue;
  double zoneBottom=topY+(top+40.0)*pixelsPerValue;
  double coverage=MathMax(0.0,MathMin((double)y+1,zoneBottom)-MathMax((double)y,zoneTop));
  rows[y]=(y>=topY && y<=bottomY)?ColorToARGB(C'33,150,243',(uchar)MathRound(26.0*coverage)):0;
  if(ShowFills && rows[y]!=0) Canvas.LineHorizontal(0,W-1,y,rows[y]);
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
   y0-=offset; y1-=offset;
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
     Canvas.PixelSet(x,y,Blend(rows[y],shade));
    }
   }
  }
 }
 Canvas.Update(false); Painting=false;
}
int OnInit()
{
 if(!MathIsValidNumber(MinSlope) || MinSlope<0) return INIT_PARAMETERS_INCORRECT;
 if(LengthK<1 || LengthK>15000 || LengthD<1 || LengthD>4999 || LengthEMA<1 || LengthEMA>4999) return INIT_PARAMETERS_INCORRECT;
 SetIndexBuffer(0,SMI,INDICATOR_DATA);
 SetIndexBuffer(1,Colors,INDICATOR_COLOR_INDEX);
 SetIndexBuffer(2,Signal,INDICATOR_DATA);
 SetIndexBuffer(3,N1,INDICATOR_CALCULATIONS); SetIndexBuffer(4,N2,INDICATOR_CALCULATIONS);
 SetIndexBuffer(5,R1,INDICATOR_CALCULATIONS); SetIndexBuffer(6,R2,INDICATOR_CALCULATIONS);
 SetIndexBuffer(7,Direction,INDICATOR_CALCULATIONS);
 ArraySetAsSeries(Colors,false); ArraySetAsSeries(Direction,false);
 PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,5);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,RisingStrength);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,RisingWeakness);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,2,FallingStrength);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,3,FallingWeakness);
 PlotIndexSetInteger(0,PLOT_LINE_COLOR,4,C'33,150,243');
 ArraySetAsSeries(SMI,false); ArraySetAsSeries(Signal,false);
 ArraySetAsSeries(N1,false); ArraySetAsSeries(N2,false); ArraySetAsSeries(R1,false); ArraySetAsSeries(R2,false);
 Name="Stoch MI Momentum 1.12 ("+(string)LengthK+","+(string)LengthD+","+(string)LengthEMA+")";
 Bitmap="SMI_Momentum_"+(string)GetMicrosecondCount();
 IndicatorSetString(INDICATOR_SHORTNAME,Name); IndicatorSetInteger(INDICATOR_DIGITS,3);
 PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE); PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 if(!EventSetMillisecondTimer(250)) { Print("SMI: timer creation failed ",GetLastError()); return INIT_FAILED; }
 return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { EventKillTimer(); Canvas.Destroy(); }
void OnTimer()
{
 if(Ready && (NeedsRefresh || W==0))
 {
  NeedsRefresh=false;
  Paint();
  ChartRedraw();
 }
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{ if(id==CHARTEVENT_CHART_CHANGE) { NeedsRefresh=true; Paint(); } }
int OnCalculate(const int total,const int prev,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
 if(total<1) return 0;
 ArraySetAsSeries(time,false); ArraySetAsSeries(high,false); ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
 ArrayResize(Times,total);
 int start=(prev<=0 || prev>total)?0:prev-1;
 double ad=2.0/(LengthD+1),ae=2.0/(LengthEMA+1);
 for(int i=start;i<total;i++)
 {
  Times[i]=time[i];
  double hh=high[i],ll=low[i];
  for(int j=MathMax(0,i-LengthK+1);j<i;j++) { hh=MathMax(hh,high[j]); ll=MathMin(ll,low[j]); }
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
 Ready=true; NeedsRefresh=true; Paint(); return total;
}
