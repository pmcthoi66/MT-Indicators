// Experimental swing-volume variant, not a byte-for-byte Pine port.
// CLOSED BARS ONLY. A pivot is drawn back at its extreme AFTER confirmation.
// Active-wave colors/totals may be reassigned up to the last confirmed pivot.
// Each bar's entire volume belongs to exactly one wave; pivot bar belongs to old wave.
#property strict
#property version "2.00"
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots 6
#property indicator_type1 DRAW_COLOR_HISTOGRAM
#property indicator_color1 clrMediumSeaGreen,clrLightCoral,clrGray
#property indicator_width1 1
#property indicator_label1 "Wave volume"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrWhite
#property indicator_label2 "Confirmed end (known later)"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrGold
#property indicator_label3 "Candidate extreme (movable)"
#property indicator_type4 DRAW_NONE
#property indicator_label4 "Wave total"
#property indicator_type5 DRAW_NONE
#property indicator_label5 "Wave bars"
#property indicator_type6 DRAW_NONE
#property indicator_label6 "Mean per bar"

enum SW_PRICE { SW_HIGH_LOW=0, SW_CLOSE=1 };
enum SW_VOLUME { SW_REAL_THEN_TICK=0, SW_TICK=1 };
input int InpATRPeriod=14;
input double InpReversalATR=1.0; // Smaller = more, shorter waves
input SW_PRICE InpExtremeSource=SW_HIGH_LOW;
input SW_VOLUME InpVolumeSource=SW_REAL_THEN_TICK;
input bool InpNormalize=false;
input bool InpOscillating=false;
input bool InpShowCandidate=true;
input bool InpShowPanel=true;
input color InpUpColor=clrMediumSeaGreen;
input color InpDownColor=clrLightCoral;
input color InpTextColor=clrSilver;
input int InpFontSize=9;

double Wave[],Colors[],Ends[],Candidate[],Total[],Count[],Mean[],Atr[],TrSum[],Prefix[];
int Last=-1,WaveStart=-1,ExtremeIndex=-1,Dir=0,CandidateIndex=-1;
double ExtremePrice=0.0,ExtremeStep=0.0,Anchor=0.0;
datetime FirstTime=0,LastTime=0;
string Name,ObjPrefix,LastText[3];

int OnInit()
{
   if(InpATRPeriod<1 || InpATRPeriod>1000000 ||
      !MathIsValidNumber(InpReversalATR) || InpReversalATR<=0.0)
      return INIT_PARAMETERS_INCORRECT;
   SetIndexBuffer(0,Wave,INDICATOR_DATA);
   SetIndexBuffer(1,Colors,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,Ends,INDICATOR_DATA);
   SetIndexBuffer(3,Candidate,INDICATOR_DATA);
   SetIndexBuffer(4,Total,INDICATOR_DATA);
   SetIndexBuffer(5,Count,INDICATOR_DATA);
   SetIndexBuffer(6,Mean,INDICATOR_DATA);
   SetIndexBuffer(7,Atr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,TrSum,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,Prefix,INDICATOR_CALCULATIONS);
   ArraySetAsSeries(Wave,false); ArraySetAsSeries(Colors,false);
   ArraySetAsSeries(Ends,false); ArraySetAsSeries(Candidate,false);
   ArraySetAsSeries(Total,false); ArraySetAsSeries(Count,false);
   ArraySetAsSeries(Mean,false); ArraySetAsSeries(Atr,false);
   ArraySetAsSeries(TrSum,false); ArraySetAsSeries(Prefix,false);
   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,3);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,InpUpColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,InpDownColor);
   PlotIndexSetInteger(1,PLOT_ARROW,159);
   PlotIndexSetInteger(2,PLOT_ARROW,161);
   for(int p=0;p<6;p++) PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(1,PLOT_SHOW_DATA,false);
   PlotIndexSetInteger(2,PLOT_SHOW_DATA,false);
   ObjPrefix="WWVS_"+IntegerToString(ChartID())+"_"+IntegerToString((long)GetMicrosecondCount())+"_";
   Name="WWV Swing TEST #"+IntegerToString((long)GetMicrosecondCount());
   IndicatorSetString(INDICATOR_SHORTNAME,Name);
   IndicatorSetInteger(INDICATOR_DIGITS,2);
   if(!InpOscillating) IndicatorSetDouble(INDICATOR_MINIMUM,0.0);
   return INIT_SUCCEEDED;
}

double Upper(const int i,const double &high[],const double &close[])
{ return InpExtremeSource==SW_CLOSE?close[i]:high[i]; }
double Lower(const int i,const double &low[],const double &close[])
{ return InpExtremeSource==SW_CLOSE?close[i]:low[i]; }
double StepAt(const int i)
{ return MathMax(_Point,Atr[i]*InpReversalATR); }

void Paint(const int first,const int last,const int direction)
{
   double base=first>0?Prefix[first-1]:0.0;
   for(int j=first;j<=last;j++)
   {
      Total[j]=Prefix[j]-base;
      Count[j]=j-first+1;
      Mean[j]=Total[j]/Count[j];
      double value=InpNormalize?Mean[j]:Total[j];
      Wave[j]=InpOscillating && direction<0?-value:value;
      Colors[j]=direction>0?0:(direction<0?1:2);
   }
}

void ScanExtreme(const int first,const int last,const double &high[],
                 const double &low[],const double &close[])
{
   ExtremeIndex=first;
   ExtremePrice=Dir>0?Upper(first,high,close):Lower(first,low,close);
   ExtremeStep=StepAt(first);
   for(int j=first+1;j<=last;j++)
   {
      double value=Dir>0?Upper(j,high,close):Lower(j,low,close);
      if((Dir>0 && value>=ExtremePrice) || (Dir<0 && value<=ExtremePrice))
      { ExtremeIndex=j; ExtremePrice=value; ExtremeStep=StepAt(j); }
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   ArraySetAsSeries(time,false); ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
   ArraySetAsSeries(tick_volume,false); ArraySetAsSeries(volume,false);
   int end=rates_total-2; // Never use live bar to confirm a swing.
   bool reset=prev_calculated==0 || prev_calculated>rates_total || Last>end;
   if(!reset && Last>=0)
      reset=time[0]!=FirstTime || time[Last]!=LastTime;
   if(reset)
   {
      ArrayInitialize(Wave,EMPTY_VALUE); ArrayInitialize(Colors,2.0);
      ArrayInitialize(Ends,EMPTY_VALUE); ArrayInitialize(Candidate,EMPTY_VALUE);
      ArrayInitialize(Total,EMPTY_VALUE); ArrayInitialize(Count,EMPTY_VALUE);
      ArrayInitialize(Mean,EMPTY_VALUE); ArrayInitialize(Atr,EMPTY_VALUE);
      ArrayInitialize(TrSum,0.0); ArrayInitialize(Prefix,0.0);
      Last=-1; WaveStart=-1; Dir=0; ExtremeIndex=-1; CandidateIndex=-1;
   }
   if(rates_total>0)
   {
      int live=rates_total-1;
      Wave[live]=EMPTY_VALUE; Ends[live]=EMPTY_VALUE; Candidate[live]=EMPTY_VALUE;
      Total[live]=EMPTY_VALUE; Count[live]=EMPTY_VALUE; Mean[live]=EMPTY_VALUE;
   }
   if(end<0) return rates_total;
   bool advanced=Last<end;
   if(advanced && CandidateIndex>=0)
   { Candidate[CandidateIndex]=EMPTY_VALUE; CandidateIndex=-1; }
   for(int i=Last+1;i<=end;i++)
   {
      Ends[i]=EMPTY_VALUE; Candidate[i]=EMPTY_VALUE;
      Wave[i]=EMPTY_VALUE; Total[i]=EMPTY_VALUE; Count[i]=EMPTY_VALUE; Mean[i]=EMPTY_VALUE;
      double tr=high[i]-low[i];
      if(i>0) tr=MathMax(tr,MathMax(MathAbs(high[i]-close[i-1]),MathAbs(low[i]-close[i-1])));
      TrSum[i]=(i>0?TrSum[i-1]:0.0)+tr;
      double raw=InpVolumeSource==SW_REAL_THEN_TICK && volume[i]>0?(double)volume[i]:(double)tick_volume[i];
      Prefix[i]=(i>0?Prefix[i-1]:0.0)+raw;
      Atr[i]=EMPTY_VALUE;
      if(i<InpATRPeriod-1) continue;
      if(i==InpATRPeriod-1) Atr[i]=TrSum[i]/InpATRPeriod;
      else Atr[i]=(Atr[i-1]*(InpATRPeriod-1)+tr)/InpATRPeriod;
      if(WaveStart<0)
      {
         WaveStart=i; Anchor=close[i]; ExtremeIndex=i;
         ExtremePrice=Anchor; ExtremeStep=StepAt(i);
         continue;
      }
      if(Dir==0)
      {
         if(close[i]>=Anchor+ExtremeStep) Dir=1;
         else if(close[i]<=Anchor-ExtremeStep) Dir=-1;
         if(Dir!=0) ScanExtreme(WaveStart,i,high,low,close);
         continue;
      }
      double value=Dir>0?Upper(i,high,close):Lower(i,low,close);
      if((Dir>0 && value>=ExtremePrice) || (Dir<0 && value<=ExtremePrice))
      { ExtremeIndex=i; ExtremePrice=value; ExtremeStep=StepAt(i); }
      // Require a later closed bar: intrabar high/low order is unknown.
      bool reversal=i>ExtremeIndex &&
         ((Dir>0 && close[i]<=ExtremePrice-ExtremeStep) ||
          (Dir<0 && close[i]>=ExtremePrice+ExtremeStep));
      if(reversal)
      {
         int pivot=ExtremeIndex;
         Paint(WaveStart,pivot,Dir);
         Ends[pivot]=Wave[pivot];
         // Pivot bar belongs to old wave. The next bar starts the new wave.
         WaveStart=pivot+1; Dir=-Dir;
         ScanExtreme(WaveStart,i,high,low,close);
      }
   }
   if(advanced && WaveStart>=0)
   {
      Paint(WaveStart,end,Dir);
      if(InpShowCandidate && Dir!=0)
      { CandidateIndex=ExtremeIndex; Candidate[CandidateIndex]=Wave[CandidateIndex]; }
   }
   Last=end; FirstTime=time[0]; LastTime=time[end];
   UpdatePanel(end);
   return rates_total;
}

void UpdatePanel(const int i)
{
   if(!InpShowPanel) return;
   int win=ChartWindowFind(0,Name);
   if(win<0) return;
   string side=Dir>0?"TANG":(Dir<0?"GIAM":"CHO HUONG");
   string lines[3];
   lines[0]="TEST | Song "+side+" | chi nen da dong | ATR x"+DoubleToString(InpReversalATR,2);
   lines[1]=WaveStart<0?"Dang cho du du lieu ATR":
      "Vol: "+DoubleToString(Total[i],0)+" | "+DoubleToString(Count[i],0)+" nen | TB: "+DoubleToString(Mean[i],1);
   lines[2]="Trang: da xac nhan (ve lui) | Vang: cuc tri tam";
   for(int k=0;k<3;k++)
   {
      string obj=ObjPrefix+IntegerToString(k);
      bool exists=ObjectFind(0,obj)>=0;
      if(!exists)
      {
         if(!ObjectCreate(0,obj,OBJ_LABEL,win,0,0)) continue;
         ObjectSetInteger(0,obj,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,obj,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,8);
         ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,20+k*(MathMax(7,InpFontSize)+8));
         ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,MathMax(7,InpFontSize));
         ObjectSetString(0,obj,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,obj,OBJPROP_COLOR,InpTextColor);
         ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
         ObjectSetString(0,obj,OBJPROP_TOOLTIP,"Xac nhan sau khi nen dong dao chieu du nguong. Mau va volume song chua xac nhan co the phan bo lai. Khong phai tin hieu Buy/Sell.");
      }
      if(!exists || LastText[k]!=lines[k])
      { ObjectSetString(0,obj,OBJPROP_TEXT,lines[k]); LastText[k]=lines[k]; }
   }
}
void OnDeinit(const int reason)
{
   if(StringLen(ObjPrefix)>0) ObjectsDeleteAll(0,ObjPrefix);
}
