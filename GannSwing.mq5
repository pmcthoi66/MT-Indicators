//+------------------------------------------------------------------+
//|                                                    GannSwing.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                                 https://mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://mql5.com"
#property version   "1.00"
#property description "Gann Swing indicator"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
//--- plot GannSwing
#property indicator_label1  "Gann Swing"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrSlateGray
#property indicator_style1  STYLE_DOT
#property indicator_width1  1
//--- indicator buffers
double         BufferGS[];
double         BufferUS[];
double         BufferDS[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,BufferGS,INDICATOR_DATA);
   SetIndexBuffer(1,BufferUS,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,BufferDS,INDICATOR_CALCULATIONS);
//--- setting indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME,"Gann Swing");
   IndicatorSetInteger(INDICATOR_DIGITS,Digits());
//--- setting buffer arrays as timeseries
   ArraySetAsSeries(BufferGS,true);
   ArraySetAsSeries(BufferUS,true);
   ArraySetAsSeries(BufferDS,true);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- Установка массивов буферов как таймсерий
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
//--- Проверка и расчёт количества просчитываемых баров
   if(rates_total<5) return 0;
//--- Проверка и расчёт количества просчитываемых баров
   int limit=rates_total-prev_calculated;
   if(limit>0)
     {
      limit=rates_total-4;
      ArrayInitialize(BufferGS,EMPTY_VALUE);
      ArrayInitialize(BufferUS,0);
      ArrayInitialize(BufferDS,0);
     }
//--- Подготовка данных
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      ResetBuffers(i);
      //--- 1.Two consecutive Higher High candles indicate Upswing
      if(high[i]>high[i+1] && high[i+1]>high[i+2])
        {
         BufferUS[i]=1; // Up
        }
      //--- 2.Two consecutive Lower Low candles indicate Downswing
      if(low[i]<low[i+1] && low[i+1]<low[i+2])
        {
         BufferDS[i]=1; // Down
        }
      //--- 4.If the next bar has a higher high and a higher low (or the same low) when
      //--- compared to the previous bar, then the swing line goes up connecting the high of the next bar
      if(BufferUS[i]==0 && high[i]>high[i+1] && low[i]>=low[i+1])
        {
         BufferUS[i]=1; // Up
        }
      //--- 5. If the next bar has a lower high (or same high) and a
      //--- lower low when compared to the previous bar, then the swing line goes down connecting the low of the next bar
      if(BufferDS[i]==0 && high[i]<=high[i+1] && low[i]<low[i+1])
        {
         BufferDS[i]=1; // Down
        }
     }
   int swing_dir=0;
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      if(BufferUS[i]==1)
        {
         if(swing_dir==1)
            BufferGS[i]=high[i];
         else if(swing_dir==-1)
           {
            BufferGS[i]=high[i];
            swing_dir=1;
           }
         else
           {
            swing_dir=1;
            BufferGS[i]=high[i];
           }
        }
      else if(BufferDS[i]==1)
        {
         if(swing_dir==-1)
            BufferGS[i]=low[i];
         else if(swing_dir==1)
           {
            BufferGS[i]=low[i];
            swing_dir=-1;
           }
         else
           {
            swing_dir=-1;
            BufferGS[i]=low[i];
           }
        }
      else
        {
         if(high[i+1]>high[i+2] && low[i+1]<low[i+3])
           {
            if(high[i]>high[i+1] && low[i]>=low[i+1])
              {
               if(swing_dir==-1)
                  BufferGS[i]=low[i];
               else if(swing_dir==1)
                 {
                  BufferGS[i]=low[i];
                  swing_dir=-1;
                 }
              }
            else if(high[i]<=high[i+1] && low[i]<low[i+1])
              {
               if(swing_dir==1)
                  BufferGS[i]=high[i];
               else if(swing_dir==-1)
                 {
                  BufferGS[i]=high[i];
                  swing_dir=1;
                 }
              }
           }
        }
     }

//--- Расчёт индикатора
   int last=0;
   int last_index=0;
   for(int i=limit; i>=0 && !IsStopped(); i--)
     {
      if(BufferGS[i]==high[i])
        {
         if(last==1)
            BufferGS[last_index]=EMPTY_VALUE;
         last=1;
         last_index=i;
        }
      if(BufferGS[i]==low[i])
        {
         if(last==-1)
            BufferGS[last_index]=EMPTY_VALUE;
         last=-1;
         last_index=i;
        }
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetBuffers(const int shift)
  {
   BufferGS[shift]=EMPTY_VALUE;
   BufferUS[shift]=BufferDS[shift]=0;
  }
//+------------------------------------------------------------------+
