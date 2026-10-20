#property copyright "PV Thoi - Chuan Quy Uoc Goc"
#property version "7.54"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots 4
#property indicator_label1 "FRAMA14"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrGold
#property indicator_width1 1
#property indicator_label2 "EMA21"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrDodgerBlue
#property indicator_width2 1
#property indicator_label3 "BUY"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrLime
#property indicator_width3 1
#property indicator_label4 "SELL"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrRed
#property indicator_width4 1


input int FRAMA_Period = 14; // Fractal Adaptive Moving Average
input int EMA_Slow = 21;
input bool ShowFRAMA = false; // Hien/an duong FRAMA; khong thay doi tin hieu
input bool ShowEMA = false; // Hien/an duong EMA; khong thay doi tin hieu
input bool AllowPullbackEntries = true; // Additional entries only after a new swing and pullback
input int StructureSwingBars = 2; // Closed candles on each side to confirm a swing
input double Pullback_MinATR = 0.30; // Minimum retracement from the new swing
input double StructureBreak_ATR = 0.0; // Close must exceed structure by this ATR margin
input double FRAMA_MinSlopeATR = 0.03; // Flat if one-bar movement <= 3% of ATR(14)
input int FRAMA_MaxBodyCross = 3; // Block after this many consecutive body intersections

// Early-turn entry exception.
input bool EnableSharpPatternEntry = true;
input double SharpTurn_MinLegATR = 0.05; // Both sides of the corner must have meaningful slope
input double SharpTurn_MinDegrees = 60.0; // ATR-normalized turning angle, scale factor 10
input int SharpTurnWindow = 2; // Pattern may complete within this many bars of the turn


// Congestion filter: clustered small bodies near a sideways FRAMA, all entries.
input bool BlockSmallBodyChop = true;
input int ChopLookback = 6;
input int ChopMinSmallBodies = 4;
input int ChopMinTouches = 3;
input double ChopSmallBodyATR = 0.35;
input double ChopMaxFRAMASpanATR = 0.60;
input double ChopBreakoutBodyATR = 0.50;
input double ChopBreakoutBufferATR = 0.10;

// Strong opposing EMA filter.
input bool BlockStrongEMACountertrend = true;
input int EMASlopeBars = 3; // Consecutive closed EMA steps to measure
input double EMAStrongSlopeATR = 0.10; // Average opposing movement per bar / current ATR

// Session starts use broker/server chart time; adjust for your broker and DST.
input bool ShowSessionSeparators = true;
input int SessionHistoryDays = 5;
input int AsiaStartHour = 0;
input int LondonStartHour = 8;
input int NewYorkStartHour = 13;
input color AsiaSessionColor = clrSlateGray; // Asia start: slate grey
input color LondonSessionColor = clrLightSkyBlue; // Europe start: light blue
input color NewYorkSessionColor = clrLightGreen; // America start: light green

double BufFRAMA14[], BufEMA21[], BufBuy[], BufSell[];
int hFrama = INVALID_HANDLE, h21 = INVALID_HANDLE, hatr = INVALID_HANDLE;

// Closed-bar state persists between calculations. Indices shift with new bars.
struct BSSignalState
{
   int structure,structureStart,lastEntryBar,bodyCrossCount,lastSignalDirection,usedTurnBar,pendingDirection,pendingBar;
   double swingHigh,swingLow,protectedHigh,protectedLow,entryPrice,pullbackSwing,pullbackExtreme,pullbackATR,chopZoneHigh,chopZoneLow,pendingPrice,pendingExtreme;
   bool haveHigh,haveLow,entered,pullbackReady,pullbackCandidate,chopZoneActive;
};
BSSignalState signalState;
bool signalStateReady=false;
datetime signalLastOpen=0;
int signalLastRates=0;
string sessionPrefix="";
datetime sessionLastDay=0;
int sessionLastMask=-1;

int OnInit()
{
   signalStateReady=false; signalLastOpen=0; signalLastRates=0;
   sessionLastDay=0; sessionLastMask=-1;
   if(SessionHistoryDays<1 || SessionHistoryDays>30 ||
      AsiaStartHour<0 || AsiaStartHour>23 || LondonStartHour<0 || LondonStartHour>23 ||
      NewYorkStartHour<0 || NewYorkStartHour>23) return INIT_PARAMETERS_INCORRECT;
   if(FRAMA_Period < 2 || EMA_Slow < 1 ||
      !MathIsValidNumber(FRAMA_MinSlopeATR) || FRAMA_MinSlopeATR < 0.0 ||
      FRAMA_MaxBodyCross < 2 || StructureSwingBars < 1 || StructureSwingBars > 100 ||
      !MathIsValidNumber(Pullback_MinATR) || Pullback_MinATR <= 0.0 ||
      !MathIsValidNumber(StructureBreak_ATR) || StructureBreak_ATR < 0.0) return(INIT_PARAMETERS_INCORRECT);
   if(!MathIsValidNumber(SharpTurn_MinLegATR) || SharpTurn_MinLegATR<=0.0 ||
      !MathIsValidNumber(SharpTurn_MinDegrees) || SharpTurn_MinDegrees<=0.0 ||
      SharpTurn_MinDegrees>=180.0 || SharpTurnWindow<0 || SharpTurnWindow>10)
      return INIT_PARAMETERS_INCORRECT;
   if(ChopLookback<3 || ChopLookback>100 ||
      ChopMinSmallBodies<2 || ChopMinSmallBodies>ChopLookback ||
      ChopMinTouches<2 || ChopMinTouches>ChopMinSmallBodies ||
      !MathIsValidNumber(ChopSmallBodyATR) || ChopSmallBodyATR<=0.0 ||
      !MathIsValidNumber(ChopMaxFRAMASpanATR) || ChopMaxFRAMASpanATR<=0.0 ||
      !MathIsValidNumber(ChopBreakoutBodyATR) || ChopBreakoutBodyATR<=ChopSmallBodyATR ||
      !MathIsValidNumber(ChopBreakoutBufferATR) || ChopBreakoutBufferATR<0.0)
      return INIT_PARAMETERS_INCORRECT;
   if(EMASlopeBars<1 || EMASlopeBars>100 || !MathIsValidNumber(EMAStrongSlopeATR) ||
      EMAStrongSlopeATR<=0.0) return INIT_PARAMETERS_INCORRECT;
   sessionPrefix=StringFormat("BS_SESSION_%I64d_%I64u_",ChartID(),GetMicrosecondCount());
   if(ShowSessionSeparators && !EventSetTimer(2)) return INIT_FAILED;
   hFrama = iFrAMA(_Symbol,_Period,FRAMA_Period,0,PRICE_CLOSE);
   h21 = iMA(_Symbol,_Period,EMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   hatr = iATR(_Symbol,_Period,14);
   if(hFrama == INVALID_HANDLE || h21 == INVALID_HANDLE || hatr == INVALID_HANDLE)
      return(INIT_FAILED);
   IndicatorSetString(INDICATOR_SHORTNAME,StringFormat("BuySell v7.54 | FRAMA(%d) + EMA(%d)",FRAMA_Period,EMA_Slow));
   PlotIndexSetString(0,PLOT_LABEL,StringFormat("FRAMA%d",FRAMA_Period));
   SetIndexBuffer(0,BufFRAMA14,INDICATOR_DATA);
   SetIndexBuffer(1,BufEMA21,INDICATOR_DATA);
   SetIndexBuffer(2,BufBuy,INDICATOR_DATA);
   SetIndexBuffer(3,BufSell,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,ShowFRAMA ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,ShowEMA ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(0,PLOT_SHOW_DATA,ShowFRAMA);
   PlotIndexSetInteger(1,PLOT_SHOW_DATA,ShowEMA);
   PlotIndexSetInteger(2,PLOT_ARROW,233);
   PlotIndexSetInteger(3,PLOT_ARROW,234);
   ArraySetAsSeries(BufFRAMA14,true); ArraySetAsSeries(BufEMA21,true);
   ArraySetAsSeries(BufBuy,true); ArraySetAsSeries(BufSell,true);
   UpdateSessionSeparators();
   ChartRedraw(0);
   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &o[],const double &h[],
                const double &l[],const double &c[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   int warmup = MathMax(EMASlopeBars+2,MathMax(ChopLookback+2,MathMax(SharpTurnWindow+3,MathMax(2*StructureSwingBars+2,MathMax(30,MathMax(FRAMA_Period,EMA_Slow))))));
   if(rates_total < MathMax(50,warmup+2)) return(0);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(o,true); ArraySetAsSeries(h,true);
   ArraySetAsSeries(l,true); ArraySetAsSeries(c,true);
   bool rebuild=!signalStateReady || prev_calculated==0 ||
                prev_calculated!=signalLastRates || rates_total<signalLastRates;
   int added=0;
   if(!rebuild && time[0]!=signalLastOpen)
   {
      added=rates_total-signalLastRates;
      // Covers a fixed-size chart history and more than one newly closed bar.
      if(added<=0 || added>=rates_total || time[added]!=signalLastOpen)
      {
         added=0;
         while(added<rates_total && time[added]>signalLastOpen) added++;
         if(added>=rates_total || time[added]!=signalLastOpen) rebuild=true;
      }
   }
   else if(!rebuild && rates_total!=signalLastRates) rebuild=true;

   double frama[],ema21[],atr[];
   ArraySetAsSeries(frama,true); ArraySetAsSeries(ema21,true); ArraySetAsSeries(atr,true);
   // Intrabar ticks update only the live lines. No closed signal state is replayed.
   if(!rebuild && added==0)
   {
      if(CopyBuffer(hFrama,0,0,1,frama)!=1 || CopyBuffer(h21,0,0,1,ema21)!=1)
         return prev_calculated;
      BufFRAMA14[0]=frama[0]; BufEMA21[0]=ema21[0];
      BufBuy[0]=EMPTY_VALUE; BufSell[0]=EMPTY_VALUE;
      return rates_total;
   }
   int start=rebuild ? rates_total-warmup : added;
   // The oldest new bar needs pivot wings, pattern, angle and chop lookbacks.
   int count=rebuild ? rates_total : MathMin(rates_total,start+warmup);
   if(start<1 || start+warmup>rates_total) { signalStateReady=false; return 0; }
   if(CopyBuffer(hFrama,0,0,count,frama)!=count ||
      CopyBuffer(h21,0,0,count,ema21)!=count ||
      CopyBuffer(hatr,0,0,count,atr)!=count) return prev_calculated;
   int lineStart=rebuild ? rates_total-1 : added;
   for(int i=lineStart;i>=0;i--){ BufFRAMA14[i]=frama[i]; BufEMA21[i]=ema21[i]; }

   // Rebuild once; otherwise resume chronologically from the last closed candle.
   int structure = 0, structureStart = rates_total;
   double swingHigh = 0.0, swingLow = 0.0;
   bool haveHigh = false, haveLow = false;
   double protectedHigh = 0.0, protectedLow = 0.0;
   int lastEntryBar = rates_total;
   bool entered = false, pullbackReady = false;
   double entryPrice = 0.0;
   bool pullbackCandidate = false;
   double pullbackSwing = 0.0, pullbackExtreme = 0.0, pullbackATR = 0.0;
   int bodyCrossCount = 0;
   bool chopZoneActive=false;
   double chopZoneHigh=0.0,chopZoneLow=0.0;
   // Direction of the most recently emitted entry, including pre-BOS exceptions.
   // It survives structure changes and is retained between closed candles.
   int lastSignalDirection = 0;
   int usedTurnBar = rates_total;
   // An early entry anticipates a reversal without rewriting market structure.
   int pendingDirection = 0, pendingBar = rates_total;
   double pendingPrice = 0.0, pendingExtreme = 0.0;
   if(!rebuild)
   {
      structure=signalState.structure;
      structureStart=signalState.structureStart + added;
      lastEntryBar=signalState.lastEntryBar + added;
      bodyCrossCount=signalState.bodyCrossCount;
      lastSignalDirection=signalState.lastSignalDirection;
      usedTurnBar=signalState.usedTurnBar + added;
      pendingDirection=signalState.pendingDirection;
      pendingBar=signalState.pendingBar + added;
      swingHigh=signalState.swingHigh;
      swingLow=signalState.swingLow;
      protectedHigh=signalState.protectedHigh;
      protectedLow=signalState.protectedLow;
      entryPrice=signalState.entryPrice;
      pullbackSwing=signalState.pullbackSwing;
      pullbackExtreme=signalState.pullbackExtreme;
      pullbackATR=signalState.pullbackATR;
      chopZoneHigh=signalState.chopZoneHigh;
      chopZoneLow=signalState.chopZoneLow;
      pendingPrice=signalState.pendingPrice;
      pendingExtreme=signalState.pendingExtreme;
      haveHigh=signalState.haveHigh;
      haveLow=signalState.haveLow;
      entered=signalState.entered;
      pullbackReady=signalState.pullbackReady;
      pullbackCandidate=signalState.pullbackCandidate;
      chopZoneActive=signalState.chopZoneActive;
   }
   else
   {
      ArrayInitialize(BufBuy,EMPTY_VALUE);
      ArrayInitialize(BufSell,EMPTY_VALUE);
   }
   for(int i=start;i>=0;i--)
   {
      BufBuy[i]=EMPTY_VALUE; BufSell[i]=EMPTY_VALUE;
   }

   for(int i=start; i>=1; i--)
   {
      BufBuy[i]=EMPTY_VALUE; BufSell[i]=EMPTY_VALUE;

      // Only closed bars (i >= 1). Positive/negative slope gives BUY/SELL.
      if(!MathIsValidNumber(frama[i]) || !MathIsValidNumber(frama[i+1]) ||
         frama[i] == EMPTY_VALUE || frama[i+1] == EMPTY_VALUE ||
         !MathIsValidNumber(atr[i]) || atr[i] == EMPTY_VALUE || atr[i] <= 0.0)
      {

         bodyCrossCount = 0;
         continue;
      }

      double delta = frama[i]-frama[i+1];
      double flatLimit = MathMax(_Point*0.1,atr[i]*FRAMA_MinSlopeATR);
      int direction = (delta > flatLimit) ? 1 : ((delta < -flatLimit) ? -1 : 0);

      // Closed-candle patterns are used only for entry conditions.
      int patternBars=0;
      int pattern=CandleReversalDirection(i,o,c,h,l,atr,patternBars);

      // Count consecutive candles whose real body contains the FRAMA value.
      // Wick-only touches do not count. No future candles are used.
      bool bodyCross = frama[i] >= MathMin(o[i],c[i]) &&
                       frama[i] <= MathMax(o[i],c[i]);
      if(bodyCross) bodyCrossCount++;
      else bodyCrossCount = 0;

      bool entryInChop=UpdateSmallBodyZone(i,o,c,frama,atr,chopZoneActive,chopZoneHigh,chopZoneLow);

      // The pivot p becomes known only now, after SwingBars CLOSED candles.
      int p = i+StructureSwingBars;
      bool pivotHigh = true, pivotLow = true;
      for(int k=1; k<=StructureSwingBars; k++)
      {
         if(h[p] <= h[p+k] || h[p] < h[p-k]) pivotHigh = false;
         if(l[p] >= l[p+k] || l[p] > l[p-k]) pivotLow = false;
      }
      if(pivotHigh)
      {
         swingHigh = h[p]; haveHigh = true;
         // A lower confirmed high tightens bearish reversal protection.
         if(structure == -1 && p < structureStart && swingHigh < protectedHigh)
            protectedHigh = swingHigh;
      }
      if(pivotLow)
      {
         swingLow = l[p]; haveLow = true;
         // A higher confirmed low tightens bullish reversal protection.
         if(structure == 1 && p < structureStart && swingLow > protectedLow)
            protectedLow = swingLow;
      }

      double margin = atr[i]*StructureBreak_ATR;
      int nextStructure = structure;
      if(structure == 0 && haveHigh && haveLow)
      {
         if(c[i] > swingHigh+margin) nextStructure = 1;
         else if(c[i] < swingLow-margin) nextStructure = -1;
      }
      else if(structure == 1 && c[i] < protectedLow-margin)
         nextStructure = -1;
      else if(structure == -1 && c[i] > protectedHigh+margin)
         nextStructure = 1;

      if(nextStructure != structure)
      {
         structure = nextStructure;
         structureStart = i;
         protectedLow = swingLow;
         protectedHigh = swingHigh;
         // A prior early entry is already the first entry of this new regime.
         entered = (pendingDirection == structure);
         if(entered)
         {
            lastEntryBar = pendingBar;
            entryPrice = pendingPrice;
         }
         pendingDirection = 0;
         pullbackReady = false;
         pullbackCandidate = false;
      }

      // A continuation entry needs a NEW favorable swing after the last entry.
      // Include the candles used to confirm that swing in retracement depth.
      if(entered && AllowPullbackEntries && p < lastEntryBar)
      {
         if(structure == 1 && pivotHigh && h[p] > entryPrice)
         {
            double trough = l[i];
            for(int j=p-1; j>=i; j--) trough = MathMin(trough,l[j]);
            pullbackCandidate = true;
            pullbackSwing = h[p]; pullbackExtreme = trough; pullbackATR = atr[i];
         }
         else if(structure == -1 && pivotLow && l[p] < entryPrice)
         {
            double peak = h[i];
            for(int j=p-1; j>=i; j--) peak = MathMax(peak,h[j]);
            pullbackCandidate = true;
            pullbackSwing = l[p]; pullbackExtreme = peak; pullbackATR = atr[i];
         }
      }

      // Keep tracking a deeper pullback after the swing confirmation candle.
      if(pullbackCandidate)
      {
         if(structure == 1)
         {
            pullbackExtreme = MathMin(pullbackExtreme,l[i]);
            if(pullbackSwing-pullbackExtreme >= pullbackATR*Pullback_MinATR)
               pullbackReady = true;
         }
         else if(structure == -1)
         {
            pullbackExtreme = MathMax(pullbackExtreme,h[i]);
            if(pullbackExtreme-pullbackSwing >= pullbackATR*Pullback_MinATR)
               pullbackReady = true;
         }
      }

      // Invalidate the anticipatory setup only after its pattern extreme breaks.
      if((pendingDirection==1 && c[i]<pendingExtreme) ||
         (pendingDirection==-1 && c[i]>pendingExtreme)) pendingDirection=0;

      int turnBar=-1;
      if(EnableSharpPatternEntry && pattern!=0 && pattern==direction &&
         EntryCloseSide(direction,c[i],ema21[i],frama[i]))
         turnBar=SharpFRAMATurn(i,pattern,frama,atr);
      bool early=turnBar>=0 && turnBar!=usedTurnBar &&
                 bodyCrossCount<FRAMA_MaxBodyCross && pendingDirection!=direction;
      int signal=early ? direction : structure;
      if(!early && (structure==0 || direction!=structure ||
                    bodyCrossCount>=FRAMA_MaxBodyCross)) continue;
      // While an early opposite setup is intact, generic old-trend entries wait.
      if(!early && pendingDirection!=0 && pendingDirection!=structure) continue;

      // Having one SELL in a bearish regime does not make every close below
      // FRAMA+EMA an entry. Additional signals STILL require a fresh pullback.
      bool continuation=(signal==structure && entered);
      if(continuation)
      {
         if(!AllowPullbackEntries || !pullbackReady || !pullbackCandidate) continue;
         // A sharp corner + reversal pattern allows earlier pullback resumption.
         if(!early)
         {
            if(structure==1 && (c[i]<=h[i+1] || c[i]<=o[i])) continue;
            if(structure==-1 && (c[i]>=l[i+1] || c[i]>=o[i])) continue;
         }
      }

      // Opposing sharp EMA movement blocks entry.
      if(!EMAAllowsEntry(i,signal,ema21,atr)) continue;

      // Congestion blocks ALL entries, including sharp-pattern exceptions.
      if(entryInChop) continue;

      // Hard gate based on the LAST actual entry, not the current structure.
      // A pullback/pattern cannot override it while close remains beyond BOTH MAs.
      if(lastSignalDirection==-1 && signal==-1 &&
         c[i]<frama[i] && c[i]<ema21[i]) continue;
      if(lastSignalDirection==1 && signal==1 &&
         c[i]>frama[i] && c[i]>ema21[i]) continue;

      if(signal==1) BufBuy[i]=l[i]-atr[i]*0.6;
      else BufSell[i]=h[i]+atr[i]*0.6;
      lastSignalDirection=signal; // Update ONLY after the arrow has been emitted.
      if(early) usedTurnBar=turnBar;
      if(signal!=structure)
      {
         // Preserve the pre-BOS setup boundary for entry-state invalidation.
         double anchor=signal==1 ? l[i] : h[i];
         for(int k=1;k<patternBars;k++)
            anchor=signal==1 ? MathMin(anchor,l[i+k]) : MathMax(anchor,h[i+k]);
         pendingDirection=signal;
         pendingBar=i; pendingPrice=c[i]; pendingExtreme=anchor;
         continue;
      }
      entered = true;
      entryPrice = c[i];
      lastEntryBar = i;
      pullbackReady = false;
      pullbackCandidate = false;
   }
   signalState.structure=structure;
   signalState.structureStart=structureStart;
   signalState.lastEntryBar=lastEntryBar;
   signalState.bodyCrossCount=bodyCrossCount;
   signalState.lastSignalDirection=lastSignalDirection;
   signalState.usedTurnBar=usedTurnBar;
   signalState.pendingDirection=pendingDirection;
   signalState.pendingBar=pendingBar;
   signalState.swingHigh=swingHigh;
   signalState.swingLow=swingLow;
   signalState.protectedHigh=protectedHigh;
   signalState.protectedLow=protectedLow;
   signalState.entryPrice=entryPrice;
   signalState.pullbackSwing=pullbackSwing;
   signalState.pullbackExtreme=pullbackExtreme;
   signalState.pullbackATR=pullbackATR;
   signalState.chopZoneHigh=chopZoneHigh;
   signalState.chopZoneLow=chopZoneLow;
   signalState.pendingPrice=pendingPrice;
   signalState.pendingExtreme=pendingExtreme;
   signalState.haveHigh=haveHigh;
   signalState.haveLow=haveLow;
   signalState.entered=entered;
   signalState.pullbackReady=pullbackReady;
   signalState.pullbackCandidate=pullbackCandidate;
   signalState.chopZoneActive=chopZoneActive;
   signalLastOpen=time[0]; signalLastRates=rates_total; signalStateReady=true;
   return(rates_total);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(sessionPrefix!="") ObjectsDeleteAll(0,sessionPrefix,0,-1);
   if(hFrama != INVALID_HANDLE) IndicatorRelease(hFrama);
   if(h21 != INVALID_HANDLE) IndicatorRelease(h21);
   if(hatr != INVALID_HANDLE) IndicatorRelease(hatr);
}

// Draw only when the server day or a session-start boundary changes.
// Fixed slot names bound the object count to 3 * SessionHistoryDays.
void UpdateSessionSeparators()
{
   if(!ShowSessionSeparators || sessionPrefix=="") return;
   datetime now=TimeCurrent();
   if(now<=0) return;
   MqlDateTime dt;
   if(!TimeToStruct(now,dt)) return;
   int currentHour=dt.hour;
   dt.hour=0; dt.min=0; dt.sec=0;
   datetime day=StructToTime(dt);
   int hours[3];
   hours[0]=AsiaStartHour; hours[1]=LondonStartHour; hours[2]=NewYorkStartHour;
   int mask=0;
   for(int s=0;s<3;s++) if(currentHour>=hours[s]) mask|=(1<<s);
   if(day==sessionLastDay && mask==sessionLastMask) return;
   color colors[3];
   colors[0]=AsiaSessionColor; colors[1]=LondonSessionColor; colors[2]=NewYorkSessionColor;
   string labels[3];
   labels[0]="Asia"; labels[1]="London"; labels[2]="New York";
   for(int d=0;d<SessionHistoryDays;d++)
   {
      datetime base=day-d*86400;
      MqlDateTime date;
      if(!TimeToStruct(base,date)) continue;
      for(int s=0;s<3;s++)
      {
         string name=sessionPrefix+IntegerToString(d)+"_"+IntegerToString(s);
         datetime at=base+hours[s]*3600;
         if(date.day_of_week==0 || date.day_of_week==6 || at>now)
         {
            ObjectDelete(0,name);
            continue;
         }
         if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_VLINE,0,at,0)) continue;
         ObjectMove(0,name,0,at,0);
         ObjectSetInteger(0,name,OBJPROP_COLOR,colors[s]);
         ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,name,OBJPROP_BACK,true);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
         ObjectSetString(0,name,OBJPROP_TOOLTIP,labels[s]+" | Server "+TimeToString(at,TIME_DATE|TIME_MINUTES));
      }
   }
   sessionLastDay=day; sessionLastMask=mask;
   ChartRedraw(0);
}

void OnTimer()
{
   UpdateSessionSeparators();
}

// BUY is blocked only by a sustained strong downward EMA; SELL is symmetric.
// Uses bar i and older closed bars, without waiting for future confirmation.
bool EMAAllowsEntry(const int i,const int direction,const double &ema[],const double &atr[])
{
   if(!BlockStrongEMACountertrend) return true;
   if(direction!=1 && direction!=-1) return false;
   if(!MathIsValidNumber(atr[i]) || atr[i]==EMPTY_VALUE || atr[i]<=0.0) return false;
   bool allOpposing=true;
   for(int k=0;k<EMASlopeBars;k++)
   {
      int p=i+k;
      if(!MathIsValidNumber(ema[p]) || !MathIsValidNumber(ema[p+1]) ||
         ema[p]==EMPTY_VALUE || ema[p+1]==EMPTY_VALUE) return false;
      if(direction*(ema[p]-ema[p+1])>=0.0) allOpposing=false;
   }
   double opposing=-direction*(ema[i]-ema[i+EMASlopeBars])/(EMASlopeBars*atr[i]);
   return !(allOpposing && opposing>=EMAStrongSlopeATR);
}

// Strict closing-price comparison; equality is not above/below.
// A missing MA must never pass a SELL comparison against EMPTY_VALUE.
bool EntryCloseSide(const int direction,const double close,const double ema,const double frama)
{
   if(!MathIsValidNumber(close) || close==EMPTY_VALUE) return false;
   bool haveEMA=MathIsValidNumber(ema) && ema!=EMPTY_VALUE;
   bool haveFRAMA=MathIsValidNumber(frama) && frama!=EMPTY_VALUE;
   if(direction==1) return (haveEMA && close>ema) || (haveFRAMA && close>frama);
   if(direction==-1) return (haveEMA && close<ema) || (haveFRAMA && close<frama);
   return false;
}

// Gap-free candle patterns for continuously quoted markets. Only closed candles.
int CandleReversalDirection(const int i,const double &o[],const double &c[],
                            const double &h[],const double &l[],const double &a[],int &patternBars)
{
   patternBars=0;
   double body=MathAbs(c[i]-o[i]),prevBody=MathAbs(c[i+1]-o[i+1]);
   double eps=_Point*0.1;
   bool bullEngulf=c[i]>o[i] && c[i+1]<o[i+1] && body>eps && prevBody>eps &&
                   o[i]<=c[i+1]+eps && c[i]>=o[i+1]-eps && body>=prevBody;
   bool bearEngulf=c[i]<o[i] && c[i+1]>o[i+1] && body>eps && prevBody>eps &&
                   o[i]>=c[i+1]-eps && c[i]<=o[i+1]+eps && body>=prevBody;
   double firstBody=MathAbs(c[i+2]-o[i+2]);
   double middleBody=MathAbs(c[i+1]-o[i+1]);
   double firstMid=(o[i+2]+c[i+2])*0.5;
   bool largeFirst=firstBody>=a[i+2]*0.30 && firstBody>eps;
   bool smallMiddle=middleBody<=firstBody*0.50;
   bool strongLast=body>=a[i]*0.25;
   bool morning=largeFirst && smallMiddle && strongLast &&
                c[i+2]<o[i+2] && c[i]>o[i] && c[i]>firstMid &&
                MathMax(o[i+1],c[i+1])<=firstMid && l[i+1]<=l[i+2];
   bool evening=largeFirst && smallMiddle && strongLast &&
                c[i+2]>o[i+2] && c[i]<o[i] && c[i]<firstMid &&
                MathMin(o[i+1],c[i+1])>=firstMid && h[i+1]>=h[i+2];
   if(bullEngulf) { patternBars=2; return 1; }
   if(bearEngulf) { patternBars=2; return -1; }
   if(morning) { patternBars=3; return 1; }
   if(evening) { patternBars=3; return -1; }
   return 0;
}

int SharpFRAMATurn(const int i,const int desired,const double &f[],const double &a[])
{
   for(int k=0;k<=SharpTurnWindow;k++)
   {
      int p=i+k;
      if(f[p]==EMPTY_VALUE || f[p+1]==EMPTY_VALUE || f[p+2]==EMPTY_VALUE ||
         !MathIsValidNumber(f[p]) || !MathIsValidNumber(f[p+1]) ||
         !MathIsValidNumber(f[p+2]) || !MathIsValidNumber(a[p]) ||
         !MathIsValidNumber(a[p+1]) || a[p]<=0.0 || a[p+1]<=0.0 ||
         a[p]==EMPTY_VALUE || a[p+1]==EMPTY_VALUE) continue;
      double before=(f[p+1]-f[p+2])/a[p+1];
      double after=(f[p]-f[p+1])/a[p];
      if((desired==1 && !(before<=-SharpTurn_MinLegATR && after>=SharpTurn_MinLegATR)) ||
         (desired==-1 && !(before>=SharpTurn_MinLegATR && after<=-SharpTurn_MinLegATR))) continue;
      double turn=(MathArctan(MathAbs(before)*10.0)+MathArctan(MathAbs(after)*10.0))*180.0/3.141592653589793;
      if(turn>=SharpTurn_MinDegrees) return p;
   }
   return -1;
}

// Rolling small-body congestion filter with a latched zone. Only closed bars.
bool UpdateSmallBodyZone(const int i,const double &o[],const double &c[],
                         const double &f[],const double &a[],
                         bool &active,double &zoneHigh,double &zoneLow)
{
   if(!BlockSmallBodyChop) { active=false; return false; }
   double body=MathAbs(c[i]-o[i]);
   double slope=f[i]-f[i+1];
   // Check escape against the PREVIOUS zone before rolling-window detection.
   // A single tiny candle missing FRAMA cannot unlock the zone.
   bool escapeUp=active && body>=a[i]*ChopBreakoutBodyATR && c[i]>o[i] &&
                 c[i]>zoneHigh+a[i]*ChopBreakoutBufferATR &&
                 c[i]>f[i] && slope>a[i]*FRAMA_MinSlopeATR;
   bool escapeDown=active && body>=a[i]*ChopBreakoutBodyATR && c[i]<o[i] &&
                   c[i]<zoneLow-a[i]*ChopBreakoutBufferATR &&
                   c[i]<f[i] && slope<-a[i]*FRAMA_MinSlopeATR;
   if(escapeUp || escapeDown) { active=false; return false; }

   int small=0,touches=0;
   double hi=-DBL_MAX,lo=DBL_MAX,fhi=-DBL_MAX,flo=DBL_MAX;
   for(int k=0;k<ChopLookback;k++)
   {
      int p=i+k;
      if(f[p]==EMPTY_VALUE || a[p]==EMPTY_VALUE || a[p]<=0.0 ||
         !MathIsValidNumber(f[p]) || !MathIsValidNumber(a[p])) continue;
      fhi=MathMax(fhi,f[p]); flo=MathMin(flo,f[p]);
      double top=MathMax(o[p],c[p]),bottom=MathMin(o[p],c[p]);
      if(top-bottom>a[p]*ChopSmallBodyATR) continue;
      small++;
      // Small margin prevents a tiny non-touch from resetting a congestion cluster.
      if(f[p]>=bottom-a[p]*0.10 && f[p]<=top+a[p]*0.10)
      {
         touches++;
         hi=MathMax(hi,top); lo=MathMin(lo,bottom);
      }
   }
   bool congestion=small>=ChopMinSmallBodies && touches>=ChopMinTouches &&
                   fhi-flo<=a[i]*ChopMaxFRAMASpanATR;
   if(congestion)
   {
      if(!active) { zoneHigh=hi; zoneLow=lo; }
      else { zoneHigh=MathMax(zoneHigh,hi); zoneLow=MathMin(zoneLow,lo); }
      active=true;
   }
   return active;
}
