//+------------------------------------------------------------------+
//|                     Trade Assistant V2.1                         |
//|             Compact Dashboard - Fixed Column Layout              |
//+------------------------------------------------------------------+
#property copyright "EarnForex / Tom Balfe / Modified"
#property link      "https://www.earnforex.com/metatrader-indicators/"
#property version   "2.10"
#property strict

#property indicator_separate_window
#property indicator_plots 0

//==================================================================
// INPUTS
//==================================================================

//--- Candle
enum ENUM_CHECK_CANDLE
{
   Current = 0,
   Previous = 1
};

input ENUM_CHECK_CANDLE CheckCandle = Previous;

//--- Stochastic
input int    PercentK     = 8;
input int    PercentD     = 3;
input int    Slowing      = 3;
input double MinStochGap  = 2.0;

//--- RSI
input int    RSIP1        = 14;
input int    RSIP2        = 70;
input double MinRSIGap    = 2.0;

//--- CCI filters
input double CCI_DeadZone = 15.0;
input double CCI_SlopeMin = 5.0;

//--- Confluence
input int MinDirectionalScore = 3;
input bool RequireTrendCCI = false; // Optional: CONF must agree with Trend CCI
input bool RequireRSIMidline = false; // Optional: fast RSI must also cross 50
input bool AlertOnAttach = false; // Avoid historical alerts when attaching
input int UpdateIntervalMs = 500; // Intrabar refresh; closed bars cached per TF

//--- Timeframes
input bool Enable_M1  = false;
input bool Enable_M5  = true;
input bool Enable_M15 = true;
input bool Enable_M30 = true;
input bool Enable_H1  = true;
input bool Enable_H4  = true;
input bool Enable_D1  = true;
input bool Enable_W1  = true;
input bool Enable_MN1 = false;

//--- Alerts
input bool EnableAlerts = false;
input bool AlertOnFullConfluence = true;

//--- Dashboard
input int DashboardX = 5;
input int DashboardY = 20;

input int LabelWidth = 90;     // <<< LABEL COLUMN
input int TFWidth    = 45;     // <<< TIMEFRAME COLUMNS
input int RowHeight  = 13;

input int FontSize = 7;
input string FontName = "Arial";

//==================================================================
// CONSTANTS
//==================================================================

#define TF_COUNT 9

// Signal
#define SIG_SELL -1
#define SIG_NONE  0
#define SIG_BUY   1

//==================================================================
// ARRAYS
//==================================================================

ENUM_TIMEFRAMES TF[TF_COUNT] =
{
   PERIOD_M1,
   PERIOD_M5,
   PERIOD_M15,
   PERIOD_M30,
   PERIOD_H1,
   PERIOD_H4,
   PERIOD_D1,
   PERIOD_W1,
   PERIOD_MN1
};

string TFName[TF_COUNT] =
{
   "M1",
   "M5",
   "M15",
   "M30",
   "H1",
   "H4",
   "D1",
   "W1",
   "MN1"
};

bool TFEnabled[TF_COUNT];

//--- CCI periods
int EntryCCI_Period[TF_COUNT] =
{
   14,14,14,6,6,6,6,5,4
};

int TrendCCI_Period[TF_COUNT] =
{
   100,50,34,14,14,14,14,12,10
};

//==================================================================
// HANDLES
//==================================================================

int myStochastic[TF_COUNT];
int myRSI1[TF_COUNT];
int myRSI2[TF_COUNT];
int myCCIe[TF_COUNT];
int myCCIt[TF_COUNT];

// V2.1: fixed CCI chronological order; atomic snapshots; per-TF caching.
string Prefix;
string RowNames[5] = {"Sto","RSI","Ecc","Tcc","CONF"};
int Window=-1;
bool DashboardReady=false;
bool PaintDirty=false;
ulong LastUpdate=0;
datetime CachedBar[TF_COUNT], LastAlertTime[TF_COUNT];
int CachedBars[TF_COUNT], LastDirection[TF_COUNT];
bool Ready[TF_COUNT], AlertPrimed[TF_COUNT];
string CellText[TF_COUNT][5];
color CellColor[TF_COUNT][5];

color SignalColor(int signal)
{
   if(signal>0) return clrLimeGreen;
   if(signal<0) return clrTomato;
   return clrSilver;
}
string SignalText(int signal)
{
   if(signal>0) return "B";
   if(signal<0) return "S";
   return "-";
}
int Direction(double gap,double minimum)
{
   if(gap>0 && gap>=minimum) return SIG_BUY;
   if(gap<0 && gap<=-minimum) return SIG_SELL;
   return SIG_NONE;
}
void ReleaseHandles()
{
   for(int i=0;i<TF_COUNT;i++)
   {
      if(myStochastic[i]!=INVALID_HANDLE) IndicatorRelease(myStochastic[i]);
      if(myRSI1[i]!=INVALID_HANDLE) IndicatorRelease(myRSI1[i]);
      if(myRSI2[i]!=INVALID_HANDLE) IndicatorRelease(myRSI2[i]);
      if(myCCIe[i]!=INVALID_HANDLE) IndicatorRelease(myCCIe[i]);
      if(myCCIt[i]!=INVALID_HANDLE) IndicatorRelease(myCCIt[i]);
   }
}
bool Label(string name,string text,int x,int y,color colour)
{
   if(!ObjectCreate(0,name,OBJ_LABEL,Window,0,0)) return false;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,FontSize);
   ObjectSetString(0,name,OBJPROP_FONT,FontName);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   return true;
}
string CellName(int i,int r)
{
   return Prefix+"SIG_"+IntegerToString(r)+"_"+IntegerToString(i);
}
bool CreateDashboard()
{
   Window=ChartWindowFind();
   if(Window<1) return false; // Retry later; never draw in another subwindow.
   ObjectsDeleteAll(0,Prefix);
   bool ok=true;
   for(int r=0;r<5;r++)
      if(!Label(Prefix+"ROW_"+IntegerToString(r),RowNames[r],DashboardX,
                DashboardY+(r+1)*RowHeight,clrWhite)) ok=false;
   int col=0;
   for(int i=0;i<TF_COUNT;i++)
   {
      if(!TFEnabled[i]) continue;
      int x=DashboardX+LabelWidth+col*TFWidth;
      if(!Label(Prefix+"HEADER_"+IntegerToString(i),TFName[i],x,DashboardY,clrWhite)) ok=false;
      for(int r=0;r<5;r++)
      {
         CellText[i][r]="...";
         CellColor[i][r]=clrDarkGray;
         if(!Label(CellName(i,r),"...",x,DashboardY+(r+1)*RowHeight,clrDarkGray)) ok=false;
      }
      col++;
   }
   PaintDirty=true;
   return ok;
}
void Cell(int i,int r,string text,color colour)
{
   if(CellText[i][r]!=text)
   {
      ObjectSetString(0,CellName(i,r),OBJPROP_TEXT,text);
      CellText[i][r]=text;
      PaintDirty=true;
   }
   if(CellColor[i][r]!=colour)
   {
      ObjectSetInteger(0,CellName(i,r),OBJPROP_COLOR,colour);
      CellColor[i][r]=colour;
      PaintDirty=true;
   }
}
bool ReadOne(int handle,int buffer,int shift,double &value)
{
   double data[1];
   if(CopyBuffer(handle,buffer,shift,1,data)!=1) return false;
   value=data[0];
   return value!=EMPTY_VALUE && MathIsValidNumber(value);
}
bool ReadCCI(int handle,int shift,int &signal)
{
   double data[2]; // Static array: CopyBuffer writes oldest first.
   if(CopyBuffer(handle,0,shift,2,data)!=2) return false;
   if(data[0]==EMPTY_VALUE || data[1]==EMPTY_VALUE ||
      !MathIsValidNumber(data[0]) || !MathIsValidNumber(data[1])) return false;
   double current=data[1], slope=data[1]-data[0];
   signal=SIG_NONE;
   if(current>CCI_DeadZone && slope>0 && slope>=CCI_SlopeMin) signal=SIG_BUY;
   if(current<-CCI_DeadZone && slope<0 && slope<=-CCI_SlopeMin) signal=SIG_SELL;
   return true;
}
bool Snapshot(int i,int shift,int &sto,int &rsi,int &ecc,int &tcc)
{
   int required=MathMax(MathMax(RSIP1,RSIP2),MathMax(EntryCCI_Period[i],TrendCCI_Period[i]));
   required=MathMax(required,PercentK+PercentD+Slowing)+shift+2;
   int handles[5];
   handles[0]=myStochastic[i]; handles[1]=myRSI1[i]; handles[2]=myRSI2[i];
   handles[3]=myCCIe[i]; handles[4]=myCCIt[i];
   for(int h=0;h<5;h++)
      if(BarsCalculated(handles[h])<required || BarsCalculated(handles[h])<Bars(_Symbol,TF[i])) return false;
   double k,d,fast,slow;
   if(!ReadOne(myStochastic[i],0,shift,k) || !ReadOne(myStochastic[i],1,shift,d) ||
      !ReadOne(myRSI1[i],0,shift,fast) || !ReadOne(myRSI2[i],0,shift,slow) ||
      !ReadCCI(myCCIe[i],shift,ecc) || !ReadCCI(myCCIt[i],shift,tcc)) return false;
   sto=Direction(k-d,MinStochGap);
   rsi=Direction(fast-slow,MinRSIGap);
   if(RequireRSIMidline && ((rsi>0 && fast<=50) || (rsi<0 && fast>=50))) rsi=SIG_NONE;
   return true;
}
void CheckAlert(int i,int score,int conf,datetime bar)
{
   int candidate=conf;
   if(AlertOnFullConfluence && MathAbs(score)!=4) candidate=SIG_NONE;
   bool first=!AlertPrimed[i];
   if(EnableAlerts && candidate!=SIG_NONE && candidate!=LastDirection[i] &&
      bar!=LastAlertTime[i] && (!first || AlertOnAttach))
   {
      LastAlertTime[i]=bar;
      Alert("Trade Assistant V2.1 | ",_Symbol," | ",TFName[i]," | ",
            candidate>0?"BUY":"SELL"," | SCORE ",score,"/4 | ",
            CheckCandle==Previous?"CLOSED":"LIVE");
   }
   AlertPrimed[i]=true;
   LastDirection[i]=candidate;
}
void UpdateDashboard(bool force=false)
{
   ulong now=GetTickCount64();
   if(!force && LastUpdate!=0 && now-LastUpdate<(ulong)UpdateIntervalMs) return;
   LastUpdate=now;
   if(!DashboardReady)
   {
      DashboardReady=CreateDashboard();
      if(!DashboardReady) return;
      force=true;
   }
   int shift=CheckCandle==Previous?1:0;
   for(int i=0;i<TF_COUNT;i++)
   {
      if(!TFEnabled[i]) continue;
      datetime bar=iTime(_Symbol,TF[i],shift);
      int count=Bars(_Symbol,TF[i]);
      bool synced=(bool)SeriesInfoInteger(_Symbol,TF[i],SERIES_SYNCHRONIZED);
      if(!force && synced && bar>0 && CheckCandle==Previous && Ready[i] &&
         CachedBar[i]==bar && CachedBars[i]==count) continue;
      int sto=0,rsi=0,ecc=0,tcc=0;
      bool valid=synced && bar>0 && Snapshot(i,shift,sto,rsi,ecc,tcc);
      // Reject a snapshot spanning a bar rollover.
      if(valid && iTime(_Symbol,TF[i],shift)!=bar) valid=false;
      if(!valid)
      {
         Ready[i]=false;
         for(int r=0;r<5;r++) Cell(i,r,"...",clrDarkGray);
         continue;
      }
      Ready[i]=true; CachedBar[i]=bar; CachedBars[i]=count;
      int score=sto+rsi+ecc+tcc;
      int conf=Direction(score,MinDirectionalScore);
      if(RequireTrendCCI && conf!=tcc) conf=SIG_NONE;
      Cell(i,0,SignalText(sto),SignalColor(sto));
      Cell(i,1,SignalText(rsi),SignalColor(rsi));
      Cell(i,2,SignalText(ecc),SignalColor(ecc));
      Cell(i,3,SignalText(tcc),SignalColor(tcc));
      color colour=SignalColor(conf);
      if(conf>0 && score==4) colour=clrLime;
      if(conf<0 && score==-4) colour=clrRed;
      Cell(i,4,SignalText(conf),colour);
      CheckAlert(i,score,conf,bar);
   }
   if(PaintDirty) { ChartRedraw(); PaintDirty=false; }
}
int OnInit()
{
   for(int i=0;i<TF_COUNT;i++)
   {
      myStochastic[i]=INVALID_HANDLE; myRSI1[i]=INVALID_HANDLE;
      myRSI2[i]=INVALID_HANDLE; myCCIe[i]=INVALID_HANDLE; myCCIt[i]=INVALID_HANDLE;
   }
   if(PercentK<1 || PercentD<1 || Slowing<1 || RSIP1<1 || RSIP2<1 ||
      MinStochGap<0 || MinRSIGap<0 || CCI_DeadZone<0 || CCI_SlopeMin<0 ||
      MinDirectionalScore<1 || MinDirectionalScore>4 || UpdateIntervalMs<100 ||
      DashboardX<0 || DashboardY<0 || LabelWidth<1 || TFWidth<1 || RowHeight<1 || FontSize<1)
      return INIT_PARAMETERS_INCORRECT;
   Prefix="TA_V21_"+IntegerToString(ChartID())+"_"+IntegerToString((long)GetMicrosecondCount())+"_";
   IndicatorSetString(INDICATOR_SHORTNAME,"Trade Assistant V2.1");
   TFEnabled[0]=Enable_M1; TFEnabled[1]=Enable_M5; TFEnabled[2]=Enable_M15;
   TFEnabled[3]=Enable_M30; TFEnabled[4]=Enable_H1; TFEnabled[5]=Enable_H4;
   TFEnabled[6]=Enable_D1; TFEnabled[7]=Enable_W1; TFEnabled[8]=Enable_MN1;
   bool any=false;
   for(int i=0;i<TF_COUNT;i++)
   {
      if(!TFEnabled[i]) continue;
      any=true;
      myStochastic[i]=iStochastic(_Symbol,TF[i],PercentK,PercentD,Slowing,MODE_SMA,STO_LOWHIGH);
      myRSI1[i]=iRSI(_Symbol,TF[i],RSIP1,PRICE_CLOSE);
      myRSI2[i]=iRSI(_Symbol,TF[i],RSIP2,PRICE_CLOSE);
      myCCIe[i]=iCCI(_Symbol,TF[i],EntryCCI_Period[i],PRICE_TYPICAL);
      myCCIt[i]=iCCI(_Symbol,TF[i],TrendCCI_Period[i],PRICE_TYPICAL);
      if(myStochastic[i]==INVALID_HANDLE || myRSI1[i]==INVALID_HANDLE ||
         myRSI2[i]==INVALID_HANDLE || myCCIe[i]==INVALID_HANDLE || myCCIt[i]==INVALID_HANDLE)
      {
         Print("Trade Assistant: handle creation failed for ",TFName[i]," error ",GetLastError());
         ReleaseHandles(); return INIT_FAILED;
      }
   }
   if(!any) return INIT_PARAMETERS_INCORRECT;
   if(!EventSetMillisecondTimer(UpdateIntervalMs)) { ReleaseHandles(); return INIT_FAILED; }
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(Prefix!="") ObjectsDeleteAll(0,Prefix);
   ReleaseHandles();
}
void OnTimer() { UpdateDashboard(); }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE && DashboardReady)
   {
      int actual=ChartWindowFind();
      if(actual!=Window) { DashboardReady=false; UpdateDashboard(true); }
   }
}
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
{
   UpdateDashboard(prev_calculated==0);
   return rates_total;
}
