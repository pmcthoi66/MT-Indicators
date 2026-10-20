//+------------------------------------------------------------------+
//|                                  WaveTrend_Pro_Dots_MT5.mq5      |
//|  Clone TradingView WaveTrend như ảnh: WT1/WT2 + Histogram +      |
//|  Chấm vàng/cyan Overbought/Oversold + Dấu + Buy/Sell +           |
//|  Divergence đáy với chấm tròn to + trendline cam                |
//|  For XAUUSD 15m                                                  |
//+------------------------------------------------------------------+
#property copyright "Built for PV Thoi - XAUUSD 15m clone"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 12
#property indicator_plots   9

//--- Inputs
input int Inp_ChannelLen = 10;      // WT Channel Length
input int Inp_AverageLen = 21;      // WT Average Length
input int Inp_MALen = 4;            // WT MA for WT2
input int Inp_RsiLen = 14;          // RSI Filter Length
input double Inp_OB1 = 60.0;        // Overbought Level 1 (chấm vàng)
input double Inp_OB2 = 80.0;        // Overbought Level 2 (chấm cyan)
input double Inp_OS1 = -60.0;       // Oversold Level 1
input double Inp_OS2 = -80.0;       // Oversold Level 2
input bool Inp_ShowDivergence = true;

//--- Buffers
double WT1[], WT2[], Hist[], RsiFilter[], MidLine[];
double DotYellow[], DotCyan[], BuyPlus[], SellPlus[];
double DivLowDot[], DivHighDot[], DivTrend[]; // for drawing

// for calc
double ESA[], D[], CI[], TCI[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, WT1, INDICATOR_DATA); 
   SetIndexBuffer(1, WT2, INDICATOR_DATA);
   SetIndexBuffer(2, Hist, INDICATOR_DATA);
   SetIndexBuffer(3, RsiFilter, INDICATOR_DATA);
   SetIndexBuffer(4, MidLine, INDICATOR_DATA);
   
   SetIndexBuffer(5, DotYellow, INDICATOR_DATA);
   SetIndexBuffer(6, DotCyan, INDICATOR_DATA);
   SetIndexBuffer(7, BuyPlus, INDICATOR_DATA);
   SetIndexBuffer(8, SellPlus, INDICATOR_DATA);
   SetIndexBuffer(9, DivLowDot, INDICATOR_DATA);
   SetIndexBuffer(10, DivHighDot, INDICATOR_DATA);
   SetIndexBuffer(11, DivTrend, INDICATOR_DATA);

   SetIndexBuffer(12, ESA, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, D, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, CI, INDICATOR_CALCULATIONS);
   SetIndexBuffer(15, TCI, INDICATOR_CALCULATIONS);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   // Plots style
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_DOT);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
   PlotIndexSetString(0, PLOT_LABEL, "WT1 Fast");

   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_DOT);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrOrange);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetString(1, PLOT_LABEL, "WT2 Slow");

   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
   PlotIndexSetString(2, PLOT_LABEL, "Money Flow Hist");

   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrDarkSeaGreen);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 1);
   PlotIndexSetString(3, PLOT_LABEL, "RSI Filter");

   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrGray);
   PlotIndexSetInteger(4, PLOT_LINE_STYLE, STYLE_DOT);
   PlotIndexSetString(4, PLOT_LABEL, "MidLine");

   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(5, PLOT_ARROW, 159); // dot
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrYellow);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, 3);
   PlotIndexSetString(5, PLOT_LABEL, "OB/OS Yellow");

   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(6, PLOT_ARROW, 159);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, clrCyan);
   PlotIndexSetInteger(6, PLOT_LINE_WIDTH, 3);
   PlotIndexSetString(6, PLOT_LABEL, "OB/OS Cyan");

   PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(7, PLOT_ARROW, 108); // +
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, clrLime);
   PlotIndexSetInteger(7, PLOT_LINE_WIDTH, 4);
   PlotIndexSetString(7, PLOT_LABEL, "Buy +");

   PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(8, PLOT_ARROW, 108);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, 4);
   PlotIndexSetString(8, PLOT_LABEL, "Sell +");

   // Divergence dots handled via objects, buffers for logic only
   IndicatorSetString(INDICATOR_SHORTNAME, "WaveTrend Pro Dots [XAU 15m Clone]");
   IndicatorSetInteger(INDICATOR_LEVELS, 4);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, Inp_OB2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, Inp_OB1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, Inp_OS1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, Inp_OS2);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
double EMA_Smooth(double price, double prev, int len)
{
   double k = 2.0/(len+1.0);
   return price*k + prev*(1.0-k);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   if(rates_total < Inp_ChannelLen + Inp_AverageLen + 50) return(0);
   
   int start = prev_calculated==0 ? 0 : prev_calculated-1;
   
   // we need hlc3
   for(int i=start; i<rates_total; i++)
   {
      double ap = (iClose(_Symbol,_Period,i) + iHigh(_Symbol,_Period,i) + iLow(_Symbol,_Period,i))/3.0;
      if(i==0)
      {
         ESA[i]=ap;
         D[i]=0;
         CI[i]=0;
         TCI[i]=0;
         WT1[i]=0;
         WT2[i]=0;
         continue;
      }
      ESA[i] = EMA_Smooth(ap, ESA[i-1], Inp_ChannelLen);
      double d_raw = MathAbs(ap - ESA[i]);
      D[i] = EMA_Smooth(d_raw, D[i-1], Inp_ChannelLen);
      if(D[i]==0) D[i]=0.001;
      CI[i] = (ap - ESA[i])/(0.015*D[i]);
      TCI[i] = EMA_Smooth(CI[i], TCI[i-1], Inp_AverageLen);
      WT1[i] = TCI[i];
   }
   // WT2 SMA
   for(int i=start; i<rates_total; i++)
   {
      double sum=0;
      int cnt=0;
      for(int k=0;k<Inp_MALen;k++)
      {
         if(i-k>=0){ sum+=WT1[i-k]; cnt++; }
      }
      WT2[i] = cnt>0 ? sum/cnt : WT1[i];
      Hist[i] = WT1[i] - WT2[i];
      
      // RSI Filter for green line
      RsiFilter[i] = iRSI(_Symbol,_Period,Inp_RsiLen,PRICE_CLOSE,i);
      MidLine[i] = 0; // zero line for hist coloring handled by color buffer - simplified
      
      // reset signals
      DotYellow[i]=EMPTY_VALUE;
      DotCyan[i]=EMPTY_VALUE;
      BuyPlus[i]=EMPTY_VALUE;
      SellPlus[i]=EMPTY_VALUE;
      DivLowDot[i]=EMPTY_VALUE;
      
      // Overbought / Oversold dots
      if(WT1[i] > Inp_OB1 && WT1[i] < Inp_OB2) DotYellow[i]=WT1[i];
      if(WT1[i] >= Inp_OB2) DotCyan[i]=WT1[i];
      if(WT1[i] < Inp_OS1 && WT1[i] > Inp_OS2) DotYellow[i]=WT1[i];
      if(WT1[i] <= Inp_OS2) DotCyan[i]=WT1[i];

      // Buy + : WT1 cross up WT2 in oversold
      if(i>1 && WT1[i-1] < WT2[i-1] && WT1[i] > WT2[i] && WT1[i] < Inp_OS1)
         BuyPlus[i]=WT1[i]-5;
      // Sell + : WT1 cross down WT2 in overbought
      if(i>1 && WT1[i-1] > WT2[i-1] && WT1[i] < WT2[i] && WT1[i] > Inp_OB1)
         SellPlus[i]=WT1[i]+5;
   }
   
   //--- Simple divergence detection (nối 2 đáy gần nhất)
   if(Inp_ShowDivergence)
   {
      // Xóa object cũ
      for(int i=ObjectsTotal(0,0,OBJ_TREND)-1;i>=0;i--)
      {
         string name=ObjectName(0,i,0,OBJ_TREND);
         if(StringFind(name,"WTDIV_")==0) ObjectDelete(0,name);
      }
      for(int i=ObjectsTotal(0,0,OBJ_ARROW)-1;i>=0;i--)
      {
         string name=ObjectName(0,i,0,OBJ_ARROW);
         if(StringFind(name,"WTDIV_DOT")==0) ObjectDelete(0,name);
      }
      // Tìm 2 đáy WT1 trong 150 nến gần nhất
      int lows[];
      ArrayResize(lows,0);
      for(int i=rates_total-10; i>rates_total-200 && i>10; i--)
      {
         if(WT1[i] < WT1[i-1] && WT1[i] < WT1[i+1] && WT1[i] < -20)
         {
            ArrayResize(lows, ArraySize(lows)+1);
            lows[ArraySize(lows)-1]=i;
            if(ArraySize(lows)>=2) break;
         }
      }
      if(ArraySize(lows)>=2)
      {
         int idx1=lows[0], idx2=lows[1];
         datetime t1=iTime(_Symbol,_Period,idx1);
         datetime t2=iTime(_Symbol,_Period,idx2);
         double p1=WT1[idx1], p2=WT1[idx2];
         string trendName="WTDIV_"+TimeToString(TimeCurrent());
         ObjectCreate(0,trendName,OBJ_TREND,ChartWindowFind(),t2,p2,t1,p1);
         ObjectSetInteger(0,trendName,OBJPROP_COLOR,clrOrange);
         ObjectSetInteger(0,trendName,OBJPROP_WIDTH,2);
         ObjectSetInteger(0,trendName,OBJPROP_RAY_RIGHT,false);
         // Vẽ 2 chấm tròn to xanh dương
         string dot1="WTDIV_DOT_1_"+trendName;
         string dot2="WTDIV_DOT_2_"+trendName;
         ObjectCreate(0,dot1,OBJ_ARROW,ChartWindowFind(),t1,p1);
         ObjectSetInteger(0,dot1,OBJPROP_ARROWCODE,159);
         ObjectSetInteger(0,dot1,OBJPROP_COLOR,clrDodgerBlue);
         ObjectSetInteger(0,dot1,OBJPROP_WIDTH,6);
         ObjectCreate(0,dot2,OBJ_ARROW,ChartWindowFind(),t2,p2);
         ObjectSetInteger(0,dot2,OBJPROP_ARROWCODE,159);
         ObjectSetInteger(0,dot2,OBJPROP_COLOR,clrDodgerBlue);
         ObjectSetInteger(0,dot2,OBJPROP_WIDTH,6);
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
