//+------------------------------------------------------------------+
//| Volume_Profile_V2_5.mq5 - cached calculation / unified screen UI   |
//| Range: candle opens in [Start, Finish). Current candle excluded.  |
//| Drag gold dot: horizontal = range shift; vertical = display shift |
//| Volumes are spread equally over touched rows, as in V2.4.         |
//+------------------------------------------------------------------+
#property strict
#property version "2.52"
#property indicator_chart_window
#property indicator_plots 0

input bool InpEnabled=true; // OFF: no timer, objects or saved state
input ENUM_TIMEFRAMES InpTimeframe=PERIOD_CURRENT;
input int InpCurrentDayHours=48;
input int InpRows=100;
input bool InpPinVP=false;
input ENUM_APPLIED_VOLUME InpVolumeType=VOLUME_REAL;
input double InpValueAreaPct=70.0;
input double InpWidthRatio=0.25;
input bool InpShowVPFinish=false;
input color InpProfileColor=clrDarkSlateGray;
input color InpHVNColor=clrTomato;
input color InpLVNColor=clrOlive;
input int InpBorderWidth=1;
input bool InpShowHVN=true;
input bool InpShowLVN=true;
input int InpNodeLookback=2;
input double InpHVNFactor=1.30;
input double InpLVNFactor=0.70;
input color InpPOCColor=clrRed;
input color InpVAHColor=clrDodgerBlue;
input color InpVALColor=clrDodgerBlue;
input int InpPOCWidth=1;
input int InpVAWidth=1;
input color InpBoundaryColor=clrSilver;
input color InpHandleColor=clrGold;
input bool InpDrawBehindPrice=true;
// New UI options
input bool InpKeepVisibleAtLeft=true;
input bool InpAdaptiveWidth=true;
input int InpMaxWidthPixels=280;
input double InpLowerTFWidthScale=0.50; // Extra reduction for M1-M15
input int InpLowerTFMaxWidthPixels=100;
input bool InpShowInfo=false;
input bool InpShowPriceLabels=true;
input color InpTextColor=clrSilver;
input int InpRefreshMilliseconds=150;
input string InpInstanceID="Main"; // Unique for each instance on one chart

string P,G;
string known_names[];
bool row_created[];
color row_colors[];
bool active=false,mouse_setting_changed=false;
datetime last_chart_bar=0;
datetime start_time=0,finish_time=0,last_bar=0;
double low_price=0,high_price=0,poc=0,vah=0,val=0;
double price_offset=0,volumes[],maximum=0,average=0;
int used_bars=0,anchor_x=-100,anchor_y=-100;
bool data_dirty=true,view_dirty=true,valid=false,following=true;
bool dragging=false,left_down=false,saved_scroll=true,saved_move=false;
bool mouse_locked=false;
int previous_first=-1,previous_visible=-1,previous_scale=-1;
datetime previous_left=0;
int drag_x=0,drag_y=0;
datetime drag_time=0,drag_start=0,drag_finish=0;
double drag_price=0,drag_offset=0;
ulong last_retry=0;

ENUM_TIMEFRAMES TF(){return InpTimeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:InpTimeframe;}
string N(string suffix){return P+suffix;}
void Save()
{
   if(!InpPinVP || start_time<=0 || finish_time<=start_time) return;
   GlobalVariableSet(G+"S",(double)start_time);
   GlobalVariableSet(G+"F",(double)finish_time);
   GlobalVariableSet(G+"O",price_offset);
}
bool Load()
{
   if(!InpPinVP || !GlobalVariableCheck(G+"S") || !GlobalVariableCheck(G+"F")) return false;
   start_time=(datetime)GlobalVariableGet(G+"S");
   finish_time=(datetime)GlobalVariableGet(G+"F");
   if(GlobalVariableCheck(G+"O")) price_offset=GlobalVariableGet(G+"O");
   return start_time>0 && finish_time>start_time && MathIsValidNumber(price_offset);
}
bool InitializeRange()
{
   datetime now=iTime(_Symbol,TF(),0);
   if(now<=0) return false;
   datetime target=(datetime)((long)now-(long)InpCurrentDayHours*3600);
   int shift=iBarShift(_Symbol,TF(),target,false);
   if(shift<0) return false;
   datetime first=iTime(_Symbol,TF(),shift);
   if(first<=0 || first>=now) return false;
   start_time=first; finish_time=now; last_bar=now;
   return true;
}
void Invalidate(){data_dirty=true;view_dirty=true;valid=false;last_retry=0;}

// A single CopyRates snapshot provides both the range and volumes.
// Difference array makes accumulation O(bars + rows), rather than O(bars*rows).
bool CalculateProfile()
{
   MqlRates rates[];
   int count=CopyRates(_Symbol,TF(),start_time,(datetime)((long)finish_time-1),rates);
   if(count<=0 || !SeriesInfoInteger(_Symbol,TF(),SERIES_SYNCHRONIZED)) return false;
   low_price=DBL_MAX;high_price=-DBL_MAX;used_bars=0;
   for(int i=0;i<count;i++)
   {
      if(rates[i].time<start_time || rates[i].time>=finish_time ||
         !MathIsValidNumber(rates[i].low) || !MathIsValidNumber(rates[i].high) || rates[i].high<rates[i].low) continue;
      if(!MathIsValidNumber(rates[i].low) || !MathIsValidNumber(rates[i].high)) continue;
      low_price=MathMin(low_price,rates[i].low);
      high_price=MathMax(high_price,rates[i].high);used_bars++;
   }
   if(used_bars==0) return false;
   if(high_price<=low_price)
   {
      double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(step<=0) step=_Point;
      if(step<=0) return false;
      low_price-=step*0.5;high_price+=step*0.5;
   }
   double row=(high_price-low_price)/InpRows;
   double diff[];ArrayResize(diff,InpRows+1);ArrayInitialize(diff,0.0);
   int occupancy[];ArrayResize(occupancy,InpRows+1);ArrayInitialize(occupancy,0);
   ArrayResize(volumes,InpRows);
   for(int i=0;i<count;i++)
   {
      if(rates[i].time<start_time || rates[i].time>=finish_time) continue;
      double v=(InpVolumeType==VOLUME_REAL && rates[i].real_volume>0)?
               (double)rates[i].real_volume:(double)rates[i].tick_volume;
      if(v<=0) continue;
      int a=(int)MathFloor((rates[i].low-low_price)/row);
      int b=(int)MathFloor((rates[i].high-low_price)/row);
      a=MathMax(0,MathMin(InpRows-1,a));b=MathMax(a,MathMin(InpRows-1,b));
      double share=v/(b-a+1);diff[a]+=share;diff[b+1]-=share;occupancy[a]++;occupancy[b+1]--;
   }
   double running=0,total=0;maximum=0;int peak=-1,nonzero=0,covered=0;
   for(int r=0;r<InpRows;r++)
   {
      running+=diff[r];covered+=occupancy[r];volumes[r]=covered>0?MathMax(0.0,running):0.0;total+=volumes[r];
      if(volumes[r]>0) nonzero++;
      if(volumes[r]>maximum){maximum=volumes[r];peak=r;}
   }
   if(peak<0 || total<=0) return false;
   average=nonzero>0?total/nonzero:0;
   poc=low_price+(peak+0.5)*row;
   int upper=peak,lower=peak;double accumulated=volumes[peak];
   double target=total*InpValueAreaPct/100.0;
   while(accumulated<target && (upper+1<InpRows || lower>0))
   {
      double up=upper+1<InpRows?volumes[upper+1]:-1;
      double down=lower>0?volumes[lower-1]:-1;
      if(up>=down) accumulated+=volumes[++upper];
      else accumulated+=volumes[--lower];
   }
   val=low_price+lower*row;vah=low_price+(upper+1)*row;
   ArrayResize(row_colors,InpRows);
   for(int r=0;r<InpRows;r++) row_colors[r]=RowColor(r);
   valid=true;data_dirty=false;view_dirty=true;return true;
}
color RowColor(int r)
{
   if(volumes[r]<=0) return InpProfileColor;
   bool hvn=InpShowHVN && volumes[r]>=average*InpHVNFactor;
   bool lvn=InpShowLVN && volumes[r]<=average*InpLVNFactor;
   bool neighbor=false;
   for(int k=1;k<=InpNodeLookback;k++)
   {
      int a=r-k,b=r+k;
      if(a>=0){neighbor=true;if(volumes[r]<volumes[a]) hvn=false;if(volumes[r]>volumes[a]) lvn=false;}
      if(b<InpRows){neighbor=true;if(volumes[r]<volumes[b]) hvn=false;if(volumes[r]>volumes[b]) lvn=false;}
   }
   if(hvn) return InpHVNColor;
   if(lvn && neighbor) return InpLVNColor;
   return InpProfileColor;
}
void Hide(string suffix){ObjectSetInteger(0,N(suffix),OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);}
void Base(string name,ENUM_OBJECT type)
{
   bool known=false;
   int row_index=-1;
   string row_prefix=P+"row ";
   if(StringFind(name,row_prefix)==0)
   {
      row_index=(int)StringToInteger(StringSubstr(name,StringLen(row_prefix)));
      if(row_index>=0 && row_index<ArraySize(row_created)) known=row_created[row_index];
   }
   else for(int i=0;i<ArraySize(known_names);i++) if(known_names[i]==name){known=true;break;}
   if(!known)
   {
      if(!ObjectCreate(0,name,type,0,0,0)) return;
      if(row_index>=0 && row_index<ArraySize(row_created)) row_created[row_index]=true;
      else {int n=ArraySize(known_names);ArrayResize(known_names,n+1);known_names[n]=name;}
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,InpDrawBehindPrice);
   }
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
}
void Box(string suffix,int x,int y,int w,int h,color c,bool filled,int border=1)
{
   string name=N(suffix);Base(name,OBJ_RECTANGLE_LABEL);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,MathMax(1,w));ObjectSetInteger(0,name,OBJPROP_YSIZE,MathMax(1,h));
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_WIDTH,border);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,filled?c:clrNONE);
}
void Text(string suffix,int x,int y,string text,color c,int size=9,string font="Consolas")
{
   string name=N(suffix);Base(name,OBJ_LABEL);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,name,OBJPROP_FONT,font);ObjectSetString(0,name,OBJPROP_TEXT,text);
}
bool XY(datetime t,double price,int &x,int &y){return ChartTimePriceToXY(0,0,t,price,x,y);}
void Horizontal(string suffix,int x1,int x2,double price,color c,int width,int chart_w,int chart_h)
{
   int dummy=0,y=0;
   if(!XY(iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0),price+price_offset,dummy,y) ||
      y<0 || y>=chart_h){Hide(suffix);Hide(suffix+" text");return;}
   int a=MathMax(0,MathMin(x1,x2)),b=MathMin(chart_w-1,MathMax(x1,x2));
   if(b<a){Hide(suffix);Hide(suffix+" text");return;}
   Box(suffix,a,y,b-a+1,width,c,true);
   if(InpShowPriceLabels)
      Text(suffix+" text",MathMax(4,MathMin(chart_w-140,b+5)),MathMax(0,y-13),
           suffix+" "+DoubleToString(price,_Digits),c);
   else Hide(suffix+" text");
}
double WidthRatio()
{
   double ratio=InpWidthRatio;
   if(InpAdaptiveWidth)
   {
      switch(TF())
      {
         case PERIOD_M1:ratio*=0.05;break;case PERIOD_M2:ratio*=0.20;break;
         case PERIOD_M3:ratio*=0.35;break;case PERIOD_M5:ratio*=0.30;break;
         case PERIOD_M10:ratio*=0.20;break;case PERIOD_M15:ratio*=0.70;break;
         case PERIOD_M20:ratio*=0.80;break;case PERIOD_M30:ratio*=0.85;break;
         default:break;
      }
   }
   int seconds=PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds>0 && seconds<=900) ratio*=InpLowerTFWidthScale;
   return MathMax(0.001,MathMin(1.0,ratio));
}
void ClearView()
{
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,P)==0) ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
   }
   anchor_x=-100;anchor_y=-100;
}
void Draw()
{
   if(!valid){ClearView();if(InpShowInfo) Text("info",12,24,"VP 2.5 | Waiting for data / empty range",InpTextColor);ChartRedraw();view_dirty=false;return;}
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   int xs=0,xf=0,unused=0;
   if(cw<20 || ch<20 || !XY(start_time,poc+price_offset,xs,unused) ||
      !XY(finish_time,poc+price_offset,xf,unused)) return;
   int offset=InpKeepVisibleAtLeft && xs<4?4-xs:0;
   int origin=xs+offset,end=xf+offset;
   int width=(int)MathRound(MathAbs((double)xf-xs)*WidthRatio());
   int cap=InpMaxWidthPixels;
   int seconds=PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds>0 && seconds<=900) cap=MathMin(cap,InpLowerTFMaxWidthPixels);
   width=MathMax(1,MathMin(cap,width));
   width=MathMin(width,MathMax(1,cw-origin-4));
   double row=(high_price-low_price)/InpRows;
   for(int r=0;r<InpRows;r++)
   {
      string suffix="row "+IntegerToString(r);int yt=0,yb=0,dummy=0;
      if(volumes[r]<=0 || origin>=cw || !XY(start_time,low_price+(r+1)*row+price_offset,dummy,yt) ||
         !XY(start_time,low_price+r*row+price_offset,dummy,yb)){Hide(suffix);continue;}
      int top=MathMax(0,MathMin(yt,yb)),bottom=MathMin(ch-1,MathMax(yt,yb));
      if(bottom<top){Hide(suffix);continue;}
      int w=MathMax(1,(int)MathRound(volumes[r]/maximum*width));
      Box(suffix,origin,top,w,MathMax(1,bottom-top),row_colors[r],false,InpBorderWidth);
   }
   if(origin>=0 && origin<cw) Box("Start",origin,0,1,ch,InpBoundaryColor,true);else Hide("Start");
   if(InpShowVPFinish && end>=0 && end<cw) Box("Finish",end,0,1,ch,InpBoundaryColor,true);else Hide("Finish");
   int current_x=0;
   if(XY(iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0),poc+price_offset,current_x,unused))
   {
      Horizontal("POC",origin,current_x,poc,InpPOCColor,InpPOCWidth,cw,ch);
      Horizontal("VAH",origin,current_x,vah,InpVAHColor,InpVAWidth,cw,ch);
      Horizontal("VAL",origin,current_x,val,InpVALColor,InpVAWidth,cw,ch);
   }
   else {Hide("POC");Hide("POC text");Hide("VAH");Hide("VAH text");Hide("VAL");Hide("VAL text");}
   int ay=0;
   if(XY(start_time,(low_price+high_price)*0.5+price_offset,unused,ay) && origin>=0 && origin<cw)
   {
      anchor_x=origin;anchor_y=MathMax(10,MathMin(ch-12,ay));
      Text("anchor",anchor_x-5,anchor_y-7,CharToString(159),InpHandleColor,12,"Wingdings");
      ObjectSetString(0,N("anchor"),OBJPROP_TOOLTIP,"Drag: time range / vertical display offset");
   }
   else {Hide("anchor");anchor_x=-100;anchor_y=-100;}
   if(InpShowInfo)
   {
      string status=InpPinVP?"PIN":(following?"LIVE":"MANUAL");
      string info="VP 2.5 | "+status+" | "+EnumToString(TF())+" | "+IntegerToString(used_bars)+" bars";
      string range_text=TimeToString(start_time,TIME_DATE|TIME_MINUTES)+" -> "+TimeToString(finish_time,TIME_DATE|TIME_MINUTES)+" [exclusive]";
      if(price_offset!=0) Text("offset",12,56,"Display offset: "+DoubleToString(price_offset,_Digits)+" | labels show source prices",InpTextColor);
      else Hide("offset");
      Text("info",12,24,info,InpTextColor);
      Text("range",12,40,range_text,InpTextColor);
   }
   else {Hide("info");Hide("range");Hide("offset");}
   view_dirty=false;ChartRedraw(0);
}

// Chart indices belong to the chart timeframe, never the calculation TF.
void TrackChart()
{
   int first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR,0);
   int visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS,0);
   int scale=(int)ChartGetInteger(0,CHART_SCALE,0);
   datetime left=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,first);
   if(first<0 || visible<=0 || left<=0) return;
   if(previous_first>=0 && !dragging && !InpPinVP &&
      visible==previous_visible && scale==previous_scale &&
      first!=previous_first && previous_left>0)
   {
      // A new candle increments the first visible index without changing
      // the actual left-edge candle. Do not mistake that for user scroll.
      long delta=(long)left-(long)previous_left;
      if(delta!=0 && start_time>0)
      {
         datetime ns=(datetime)((long)start_time+delta);
         datetime nf=(datetime)((long)finish_time+delta);
         if(ns>0 && nf>ns){start_time=ns;finish_time=nf;following=false;Invalidate();}
      }
   }
   previous_first=first;previous_visible=visible;previous_scale=scale;previous_left=left;
}
void ReleaseMouse()
{
   if(mouse_locked){ChartSetInteger(0,CHART_MOUSE_SCROLL,saved_scroll);mouse_locked=false;}
   dragging=false;Save();
}
void Mouse(int x,int y,bool pressed)
{
   if(!left_down && pressed && MathAbs(x-anchor_x)<=12 && MathAbs(y-anchor_y)<=12)
   {
      int window=0;datetime t=0;double price=0;
      if(ChartXYToTimePrice(0,x,y,window,t,price) && window==0 && start_time>0)
      {
         dragging=true;drag_x=x;drag_y=y;drag_time=t;drag_price=price;
         drag_start=start_time;drag_finish=finish_time;drag_offset=price_offset;
         saved_scroll=(bool)ChartGetInteger(0,CHART_MOUSE_SCROLL);
         ChartSetInteger(0,CHART_MOUSE_SCROLL,false);mouse_locked=true;following=false;
      }
   }
   if(dragging && pressed)
   {
      int window=0;datetime t=0;double price=0;
      if(ChartXYToTimePrice(0,x,y,window,t,price) && window==0)
      {
         // Snap temporal movement to the working TF's candle opens.
         datetime candidate=(datetime)((long)drag_start+(long)t-(long)drag_time);
         int shift=iBarShift(_Symbol,TF(),candidate,false);
         if(shift>=0)
         {
            datetime ns=iTime(_Symbol,TF(),shift);
            datetime nf=(datetime)((long)ns+(long)drag_finish-(long)drag_start);
            if(ns>0 && nf>ns && ns!=start_time){start_time=ns;finish_time=nf;Invalidate();}
         }
         price_offset=drag_offset+price-drag_price;view_dirty=true;
      }
   }
   if(dragging && !pressed) ReleaseMouse();
   left_down=pressed;
}
void Refresh()
{
   if(!active) return;
   if(start_time<=0 || finish_time<=start_time)
   {
      if(last_retry && GetTickCount64()-last_retry<1000) return;
      last_retry=GetTickCount64();
      if(!InitializeRange()){if(view_dirty) Draw();return;}
      Invalidate();
   }
   datetime now=iTime(_Symbol,TF(),0);
   if(now>0 && now!=last_bar)
   {
      if(!InpPinVP && following && !dragging)
      {
         long duration=(long)finish_time-(long)start_time;
         finish_time=now;start_time=(datetime)((long)now-duration);Invalidate();
      }
      // POC display must advance even for PIN / manual historical ranges.
      last_bar=now;view_dirty=true;
   }
   datetime chart_bar=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   if(chart_bar>0 && chart_bar!=last_chart_bar){last_chart_bar=chart_bar;view_dirty=true;}
   if(data_dirty && (!last_retry || GetTickCount64()-last_retry>=1000))
   {
      last_retry=GetTickCount64();
      if(!CalculateProfile()) {valid=false;view_dirty=true;}
   }
   if(view_dirty) Draw();
}
int OnInit()
{
   // Explicit reset is required after remove, Inputs and timeframe reinit.
   active=false;valid=false;data_dirty=true;view_dirty=true;
   following=true;dragging=false;left_down=false;mouse_locked=false;
   mouse_setting_changed=false;last_retry=0;last_bar=0;last_chart_bar=0;
   previous_first=-1;previous_visible=-1;previous_scale=-1;previous_left=0;
   anchor_x=-100;anchor_y=-100;
   start_time=0;finish_time=0;price_offset=0;
   ArrayFree(volumes);ArrayFree(row_colors);ArrayFree(known_names);ArrayFree(row_created);
   P="VP25 "+InpInstanceID+" ";
   G="VP25_"+IntegerToString(ChartID())+"_"+_Symbol+"_"+InpInstanceID+"_";
   if(StringLen(InpInstanceID)==0 || StringLen(G)>60 || StringLen(P)>40){P="";G="";return INIT_PARAMETERS_INCORRECT;}
   if(!InpEnabled)
   {
      ObjectsDeleteAll(0,P);DeleteState();ChartRedraw(0);return INIT_SUCCEEDED;
   }
   if(InpLowerTFWidthScale<=0 || InpLowerTFWidthScale>1 || InpLowerTFMaxWidthPixels<1 ||
      InpCurrentDayHours<1 || InpRows<10 || InpRows>2000 ||
      InpValueAreaPct<=0 || InpValueAreaPct>100 || InpWidthRatio<=0 || InpWidthRatio>1 ||
      InpNodeLookback<1 || InpNodeLookback>InpRows || InpHVNFactor<=0 || InpLVNFactor<0 ||
      InpBorderWidth<1 || InpPOCWidth<1 || InpVAWidth<1 || InpMaxWidthPixels<1 ||
      InpRefreshMilliseconds<50 || InpRefreshMilliseconds>5000 || StringLen(InpInstanceID)==0)
      return INIT_PARAMETERS_INCORRECT;
   P="VP25 "+InpInstanceID+" ";
   G="VP25_"+IntegerToString(ChartID())+"_"+_Symbol+"_"+InpInstanceID+"_";
   if(StringLen(G)>60 || StringLen(P)>40) return INIT_PARAMETERS_INCORRECT;
   IndicatorSetString(INDICATOR_SHORTNAME,"Volume Profile V2.5.2 ["+InpInstanceID+"]");
   ArrayResize(row_created,InpRows);ArrayInitialize(row_created,false);
   saved_move=(bool)ChartGetInteger(0,CHART_EVENT_MOUSE_MOVE);
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);mouse_setting_changed=true;
   if(!Load())
   {
      start_time=0;finish_time=0;price_offset=0;InitializeRange();
      if(!InpPinVP){GlobalVariableDel(G+"S");GlobalVariableDel(G+"F");GlobalVariableDel(G+"O");}
   }
   following=!InpPinVP;
   last_bar=iTime(_Symbol,TF(),0);
   TrackChart();
   if(!EventSetMillisecondTimer(InpRefreshMilliseconds))
   {
      ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,saved_move);return INIT_FAILED;
   }
   active=true;
   Invalidate();
   return INIT_SUCCEEDED;
}
void DeleteState()
{
   if(StringLen(G)==0) return;
   GlobalVariableDel(G+"S");GlobalVariableDel(G+"F");GlobalVariableDel(G+"O");
}
void OnDeinit(const int reason)
{
   active=false;EventKillTimer();
   if(mouse_locked){ChartSetInteger(0,CHART_MOUSE_SCROLL,saved_scroll);mouse_locked=false;}
   dragging=false;left_down=false;
   // Preserve PIN only for a genuine reinitialization, not remove/OFF/close.
   if(InpEnabled && InpPinVP &&
      (reason==REASON_CHARTCHANGE || reason==REASON_PARAMETERS || reason==REASON_RECOMPILE))
      Save();
   else DeleteState();
   if(mouse_setting_changed) ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,saved_move);
   if(StringLen(P)>0) ObjectsDeleteAll(0,P);
   ArrayFree(volumes);ArrayFree(row_colors);ArrayFree(known_names);ArrayFree(row_created);
   valid=false;data_dirty=false;view_dirty=false;
   start_time=0;finish_time=0;price_offset=0;anchor_x=-100;anchor_y=-100;
   ChartRedraw(0);
}
void OnTimer(){Refresh();}
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   if(!active) return rates_total;
   // History reload or broker correction invalidates the cached snapshot.
   if(prev_calculated==0) Invalidate();
   // If a manually selected range includes the live bar, refresh its volume
   // at most once per second (timer throttles expensive calculation).
   datetime now=iTime(_Symbol,TF(),0);
   if(now>0 && start_time<=now && finish_time>now) data_dirty=true;
   return rates_total;
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(!active) return;
   if(id==CHARTEVENT_CHART_CHANGE){TrackChart();view_dirty=true;return;}
   if(id==CHARTEVENT_MOUSE_MOVE)
      Mouse((int)lparam,(int)dparam,((int)StringToInteger(sparam)&1)!=0);
}
