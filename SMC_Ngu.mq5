//+------------------------------------------------------------------+
//|                                      SMC_Ngu.mq5|
//+------------------------------------------------------------------+
#property copyright "PVT_AI"
#property description "SMC_Ngu | PVT_AI | Structure, OB and MTF Supply/Demand"
#property version   "3.10"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//====================================================================
// [1] ENUM & INPUT PARAMETERS
//====================================================================
enum ENUM_MITIGATION {
    MITIGATION_BODY,
    MITIGATION_WICK
};

input group "--- Order Block Settings ---"
input ENUM_MITIGATION InpMitigation = MITIGATION_BODY;
input int InpMaxOB                  = 3;
input bool InpFillOB                = true;
input bool InpOBOnlyStructure       = true;  // true: OB chi xuat hien sau BOS/CHOCH da dong
input double InpOBMinDepartureATR = 0.25; // OB van phai co BOS/CHOCH; loc pha yeu
input double InpOBMaxWidthATR = 2.50;     // Bo OB qua rong; 0=tat
input int InpOBSearchBars           = 30;    // Tim nen nguoc chieu gan nhat truoc pha cau truc
input color InpColorOB_Bull         = C'10,40,15';
input color InpColorOB_Bear         = C'40,10,10';
input color InpColorOB_TextBull     = clrLime;
input color InpColorOB_TextBear     = clrRed;

input group "--- Alert Settings ---"
input bool   InpEnableAlert         = true;
input bool   InpAlertPopup          = true;
input bool   InpAlertPush           = false;
input int    InpAlertCooldownBars   = 5;

//====================================================================
// [2] GLOBAL VARIABLES & STRUCTS
//====================================================================
input group "--- External Market Structure ---"
input bool InpShowStructure         = false; // Stru: cau truc + sweep
input int InpPivotStrength          = 3;     // seed / confirm external extreme; not internal structure
input int InpStructureBars          = 3000;
input int InpBreakBufferPoints      = 0;     // close must exceed level + buffer
input bool InpShowHistory           = false;
input int InpRecentStructures       = 5;
input color InpStructureBull        = clrLimeGreen;
input color InpStructureBear        = clrTomato;
input group "--- Zone borders / Vien vung ---"
input color InpChartBorderColor     = C'101,67,33'; // Khung chart: nau dam
input color InpM15BorderColor       = clrGray;
input color InpH1BorderColor        = clrSteelBlue;
input color InpH4BorderColor        = clrDarkGoldenrod;
input color InpOtherBorderColor     = clrSlateGray;
input group "--- Multi Timeframe ---"
input bool InpShowMTF               = false;
input ENUM_TIMEFRAMES InpTF1        = PERIOD_M15;
input ENUM_TIMEFRAMES InpTF2        = PERIOD_H1;
input ENUM_TIMEFRAMES InpTF3        = PERIOD_H4;
input group "--- Automatic Fibonacci ---"
input bool InpShowFibo              = false;
input ENUM_TIMEFRAMES InpFiboTF     = PERIOD_CURRENT;
input color InpFiboColor            = clrGoldenrod;

input group "--- Liquidity Sweeps / Quet thanh khoan ---"
input int InpSweepBufferPoints      = 0;     // Do vuot muc toi thieu, don vi point
input color InpSweepColor           = clrGold;
input group "--- MTF Order Blocks / OB da khung ---"
input bool InpShowMTFOB = true;
input int InpMaxMTFOBPerSide = 1;      // So OB moi nhat moi chieu / moi khung
input group "--- MTF Supply Demand / Cung cau da khung ---"
input bool InpShowSupplyDemand = true;
input bool InpSDAutoTimeframes = true; // S/D: chart + 2 khung lon hon; rieng voi OB MTF
input bool InpSupplyDemandCurrent = true; // Chi ap dung khi tat AutoTimeframes
input int InpMaxSDPerSide = 2;         // So vung uu tien moi chieu / moi khung
input int InpBaseMaxBars = 4;          // Cum nen nen truoc song pha cau truc
input int InpZoneATRPeriod = 14;
input double InpBaseMaxCandleATR = 1.20;
input double InpBaseMaxWidthATR = 1.50;
input double InpZoneDepartureATR = 0.50;
input ENUM_MITIGATION InpMTFZoneMitigation = MITIGATION_BODY;
input bool InpOnlyFreshMTFZones = false;
input bool InpFillSupplyDemand = true; // To nen S/D current TF; cac khung khac chi vien dash
input color InpDemandColor = clrMediumSeaGreen;
input color InpSupplyColor = clrIndianRed;
bool visibility_dirty=true;
bool ui_obmtf,ui_sd;
struct MTFZone
{
   int slot;
   ENUM_TIMEFRAMES tf;
   int kind;                          // 0 OB; 1 supply/demand base
   int direction;
   datetime source;
   datetime confirmed;
   double top;
   double bottom;
   bool tested;
   bool reversal;
   int reactions,touches;
   double quality;
   bool repeated,departure;
};
MTFZone mtf_zones[];
input group "--- Supply Demand filters / Loc Cung Cau ---"
input bool InpSDDepartureZones = true; // Them vung nen + roi nen manh, khong can cho BOS
input double InpSDDepartureATR = 0.80; // Close cach bien nen toi thieu / ATR truoc nen
input double InpSDDepartureBodyATR = 0.35; // Than nen roi nen toi thieu / ATR
input double InpSDDepartureMaxCandleATR = 3.50; // Loai nen bat thuong qua lon
input bool InpZoneNearestFirst = true; // Giu vung gan gia nhat, cac vung con lai theo uu tien
input bool InpShowSDStatus = true; // Hien tung TF: S/D hop le hoac dang tai du lieu
input bool InpSDRepeatedReactions = true; // Them vung phan ung lap lai, khong bat buoc BOS
input int InpSDLookbackBars = 1200;      // Gioi han quet moi khung, chi nen da dong
input int InpSDMaxAgeBars = 600;         // Tuoi tu lan phan ung xac nhan gan nhat
input int InpSDPivotStrength = 2;        // Pivot tao ung vien; cho du nen ben phai moi dung
input int InpSDMinReactions = 2;         // So phan ung DOC LAP de xac nhan vung lap lai
input int InpSDReactionWait = 8;         // So nen toi da cho bat ra sau cham
input int InpSDMinReactionGap = 3;       // Khoang cach giua hai lan phan ung
input double InpSDReactionATR = 0.50;    // Close roi bien vung / ATR truoc nguon
input double InpSDReactionBodyATR = 0.15;// Than nen phan ung toi thieu / ATR truoc nguon
input double InpSDRearmATR = 0.15;       // Nen phai roi HOAN TOAN vung truoc lan cham moi
input double InpSDMaxSeedATR = 2.50;     // Bo nen tao vung co range qua lon
input double InpSDMaxWidthATR = 1.50;    // Chieu rong toi da vung / ATR
input double InpSDMergeOverlap = 0.50;  // Gop trung cung khung/cung chieu; giu bien vung goc

input group "--- Chart Buttons ---"
input bool InpShowButtons = true;
input int InpStateInstance = 1; // Moi ban SMC tren cung chart dung mot so rieng de giu nut
input int InpButtonX = 12;
input int InpButtonY = 22;
bool ui_all=true,ui_ob=true,ui_structure,ui_fibo,ui_sweeps;
bool ui_mtf,ui_history;
bool ui_force_refresh=false;
bool view_dirty=false;
datetime last_edge_time=0;

string instance_prefix;
datetime structure_bar[7];
int structure_count[7];
int zone_load_state[7],zone_load_count[7]; // 0 idle, 1 loading, 2 ready
double zone_quote[7];
string structure_status[7];
long obj_counter = 0; 
double prev_valid_high = 0;
double prev_valid_low = 0;
double last_tick_price = 0;
datetime prev_live_bar_time = 0;

struct ValidBar {
    double h;
    double l;
    datetime t;
};
ValidBar vb1, vb2, vb3;

struct OrderBlock {
    bool     active;
    int      priority; // Cached per closed bar; touch alerts never rescan rankings per tick
    datetime confirmed_time;
    bool     reversal;
    datetime ob_time;
    double   top;
    double   bottom;
    long     ticket;
    double   fvg_size;
    bool     visual_deleted;
    bool     tested;          // Persistent post-confirmation closed-bar touch
    bool     touch_alerted;
    bool     has_exited;
    int      bars_since_exit;
};

OrderBlock BullOBs[];
OrderBlock BearOBs[];
long ob_ticket_counter = 0;

//====================================================================
// [3] INITIALIZATION & DEINITIALIZATION
//====================================================================
int OnInit()
  {
   if(!MathIsValidNumber(InpOBMinDepartureATR) || InpOBMinDepartureATR<0 || InpOBMinDepartureATR>5 ||
      !MathIsValidNumber(InpOBMaxWidthATR) || InpOBMaxWidthATR<0 || InpOBMaxWidthATR>10 ||
      !MathIsValidNumber(InpSDDepartureATR) || InpSDDepartureATR<0.3 || InpSDDepartureATR>5 ||
      !MathIsValidNumber(InpSDDepartureBodyATR) || InpSDDepartureBodyATR<0.1 || InpSDDepartureBodyATR>3 ||
      !MathIsValidNumber(InpSDDepartureMaxCandleATR) || InpSDDepartureMaxCandleATR<1 || InpSDDepartureMaxCandleATR>10 ||
      InpSDLookbackBars<100 || InpSDLookbackBars>5000 || InpSDMaxAgeBars<20 || InpSDMaxAgeBars>5000 ||
      InpSDPivotStrength<1 || InpSDPivotStrength>10 || InpSDMinReactions<2 || InpSDMinReactions>6 ||
      InpSDReactionWait<1 || InpSDReactionWait>50 || InpSDMinReactionGap<1 || InpSDMinReactionGap>50 ||
      !MathIsValidNumber(InpSDReactionATR) || InpSDReactionATR<=0 || InpSDReactionATR>5 ||
      !MathIsValidNumber(InpSDReactionBodyATR) || InpSDReactionBodyATR<0 || InpSDReactionBodyATR>2 ||
      !MathIsValidNumber(InpSDRearmATR) || InpSDRearmATR<0 || InpSDRearmATR>2 ||
      !MathIsValidNumber(InpSDMaxSeedATR) || InpSDMaxSeedATR<=0 || InpSDMaxSeedATR>10 ||
      !MathIsValidNumber(InpSDMaxWidthATR) || InpSDMaxWidthATR<=0 || InpSDMaxWidthATR>5 ||
      !MathIsValidNumber(InpSDMergeOverlap) || InpSDMergeOverlap<0.1 || InpSDMergeOverlap>1 ||
      !MathIsValidNumber(InpBaseMaxCandleATR) || !MathIsValidNumber(InpBaseMaxWidthATR) ||
      !MathIsValidNumber(InpZoneDepartureATR) || InpStateInstance<1 || InpStateInstance>9999 ||
      InpMaxMTFOBPerSide<0 || InpMaxMTFOBPerSide>10 || InpMaxSDPerSide<0 || InpMaxSDPerSide>10 ||
      InpBaseMaxBars<1 || InpBaseMaxBars>10 || InpZoneATRPeriod<5 || InpZoneATRPeriod>100 ||
      InpBaseMaxCandleATR<=0 || InpBaseMaxWidthATR<=0 || InpZoneDepartureATR<=0 || InpButtonX<0 || InpButtonY<0 || InpMaxOB<0 || InpMaxOB>100 || InpPivotStrength<1 || InpPivotStrength>30 ||
      InpStructureBars<100 || InpStructureBars>50000 || InpBreakBufferPoints<0 ||
      InpRecentStructures<1 || InpRecentStructures>200 || InpAlertCooldownBars<0 ||
      InpOBSearchBars<1 || InpOBSearchBars>500 || InpSweepBufferPoints<0)
      return(INIT_PARAMETERS_INCORRECT);
   instance_prefix="SMC_NGU_"+IntegerToString(ChartID())+"_"+IntegerToString(GetMicrosecondCount())+"_";
   CleanupRetiredButtons();
   ui_structure=InpShowStructure; ui_fibo=InpShowFibo; ui_sweeps=ui_structure;
   ui_mtf=InpShowMTF; ui_history=InpShowHistory;
   ui_obmtf=InpShowMTFOB; ui_sd=InpShowSupplyDemand;
   ui_all=true; ui_ob=true; visibility_dirty=true;
   LoadUiState(); // Runtime choices survive timeframe/symbol reinitialization.
   SaveUiState();
   ArrayInitialize(structure_bar,0);
   ArrayInitialize(structure_count,0);
   ArrayInitialize(zone_load_state,0); ArrayInitialize(zone_load_count,0); ArrayInitialize(zone_quote,0);
   for(int k=0;k<7;k++) structure_status[k]="Waiting for data";
   IndicatorSetString(INDICATOR_SHORTNAME,"SMC_Ngu | PVT_AI 3.10");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   last_tick_price = 0;
   prev_live_bar_time = 0;
   last_edge_time=0; view_dirty=true; ui_force_refresh=false;
   ResetRenderSnapshots();
   DrawButtons();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(reason!=REASON_CHARTCHANGE && reason!=REASON_PARAMETERS && reason!=REASON_RECOMPILE && reason!=REASON_ACCOUNT)
      ClearUiState();
   ResetRenderSnapshots();
   if(instance_prefix!="") ObjectsDeleteAll(0, instance_prefix);
   ArrayFree(BullOBs);
   ArrayFree(BearOBs);
   ArrayFree(mtf_zones);
   ChartRedraw();
  }

//====================================================================
// [4] ORDER BLOCK GRAPHICS RENDERER
//====================================================================
// Fill and outline have separate colors; update both in place.
color ZoneBorderColor(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_CURRENT || tf==(ENUM_TIMEFRAMES)_Period) return InpChartBorderColor;
   if(tf==PERIOD_M15) return InpM15BorderColor;
   if(tf==PERIOD_H1) return InpH1BorderColor;
   if(tf==PERIOD_H4) return InpH4BorderColor;
   return InpOtherBorderColor;
}
void DrawZoneBorder(const string name,datetime left,datetime right,double top,double bottom,
                    ENUM_TIMEFRAMES tf,int kind,color fill_color,bool fill)
{
   string background=name+"_fill";
   if(fill)
   {
      if(ObjectFind(0,background)<0) ObjectCreate(0,background,OBJ_RECTANGLE,0,left,top,right,bottom);
      else { ObjectMove(0,background,0,left,top); ObjectMove(0,background,1,right,bottom); }
      StyleObject(background,fill_color);
      ObjectSetInteger(0,background,OBJPROP_FILL,true);
      ObjectSetInteger(0,background,OBJPROP_BACK,true);
      ObjectSetInteger(0,background,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,background,OBJPROP_WIDTH,1);
   }
   else ObjectDelete(0,background);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ZoneBorderColor(tf));
   ObjectSetInteger(0,name,OBJPROP_FILL,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_STYLE,kind==0?STYLE_DOT:STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
}

void UpdateOBGraphics(const datetime &time[], int current_bar)
  {
   if(!ui_all || !ui_ob) { ObjectsDeleteAll(0,instance_prefix+"OB_"); return; }
   int active_bull = 0;
   int active_bear = 0;
   
   int total_bull = ArraySize(BullOBs);
   for(int i = total_bull - 1; i >= 0; i--)
     {
      string obj_name = instance_prefix+"OB_BULL_" + IntegerToString(BullOBs[i].ticket);
      string lbl_name = obj_name + "_lbl";
      
      if(!BullOBs[i].active || BullOBs[i].priority >= (ui_history?100:InpMaxOB))
        {
         if(!BullOBs[i].visual_deleted)
           {
            ObjectDelete(0, obj_name);
            ObjectDelete(0, lbl_name);
            ObjectDelete(0, obj_name+"_fill");
            BullOBs[i].visual_deleted = true;
           }
         continue;
        }
      
      if(ObjectFind(0, obj_name) < 0)
        {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, BullOBs[i].ob_time, BullOBs[i].top, time[current_bar]+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3, BullOBs[i].bottom);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, InpColorOB_Bull);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_FILL, InpFillOB);
         ObjectSetInteger(0,obj_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,obj_name,OBJPROP_HIDDEN,true);
        }
      else
        {
         ObjectSetInteger(0, obj_name, OBJPROP_TIME, 0, BullOBs[i].ob_time);
         ObjectSetInteger(0, obj_name, OBJPROP_TIME, 1, time[current_bar]+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3);
        }
         
      datetime left=BullOBs[i].ob_time;
      datetime right=time[current_bar]+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3;
      DrawZoneBorder(obj_name,left,right,BullOBs[i].top,BullOBs[i].bottom,(ENUM_TIMEFRAMES)_Period,0,InpColorOB_Bull,InpFillOB);
      string caption=TimeframeLabel((ENUM_TIMEFRAMES)_Period)+" OB↑"+(BullOBs[i].tested?" *":"");
      CenterZoneText(lbl_name,left,right,BullOBs[i].top,BullOBs[i].bottom,caption,InpColorOB_TextBull,7);

      if(InpOBOnlyStructure)
      {
         string info=caption+" | "+(BullOBs[i].reversal?"CHOCH":"BOS")+
            " | Source: "+TimeToString(BullOBs[i].ob_time)+" | Confirmed: "+TimeToString(BullOBs[i].confirmed_time);
         ObjectSetString(0,obj_name,OBJPROP_TOOLTIP,info);
         ObjectSetString(0,lbl_name,OBJPROP_TOOLTIP,info);
      }
      BullOBs[i].visual_deleted=false;
      active_bull++;
     }
   
   int total_bear = ArraySize(BearOBs);
   for(int i = total_bear - 1; i >= 0; i--)
     {
      string obj_name = instance_prefix+"OB_BEAR_" + IntegerToString(BearOBs[i].ticket);
      string lbl_name = obj_name + "_lbl";
      
      if(!BearOBs[i].active || BearOBs[i].priority >= (ui_history?100:InpMaxOB))
        {
         if(!BearOBs[i].visual_deleted)
           {
            ObjectDelete(0, obj_name);
            ObjectDelete(0, lbl_name);
            ObjectDelete(0, obj_name+"_fill");
            BearOBs[i].visual_deleted = true;
           }
         continue;
        }
      
      if(ObjectFind(0, obj_name) < 0)
        {
         ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, BearOBs[i].ob_time, BearOBs[i].top, time[current_bar]+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3, BearOBs[i].bottom);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, InpColorOB_Bear);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, obj_name, OBJPROP_FILL, InpFillOB);
         ObjectSetInteger(0,obj_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,obj_name,OBJPROP_HIDDEN,true);
        }
      else
        {
         ObjectSetInteger(0, obj_name, OBJPROP_TIME, 0, BearOBs[i].ob_time);
         ObjectSetInteger(0, obj_name, OBJPROP_TIME, 1, time[current_bar]+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3);
        }
         
      datetime left=BearOBs[i].ob_time;
      datetime right=time[current_bar]+PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3;
      DrawZoneBorder(obj_name,left,right,BearOBs[i].top,BearOBs[i].bottom,(ENUM_TIMEFRAMES)_Period,0,InpColorOB_Bear,InpFillOB);
      string caption=TimeframeLabel((ENUM_TIMEFRAMES)_Period)+" OB↓"+(BearOBs[i].tested?" *":"");
      CenterZoneText(lbl_name,left,right,BearOBs[i].top,BearOBs[i].bottom,caption,InpColorOB_TextBear,7);

      if(InpOBOnlyStructure)
      {
         string info=caption+" | "+(BearOBs[i].reversal?"CHOCH":"BOS")+
            " | Source: "+TimeToString(BearOBs[i].ob_time)+" | Confirmed: "+TimeToString(BearOBs[i].confirmed_time);
         ObjectSetString(0,obj_name,OBJPROP_TOOLTIP,info);
         ObjectSetString(0,lbl_name,OBJPROP_TOOLTIP,info);
      }
      BearOBs[i].visual_deleted=false;
      active_bear++;
     }
  }

//====================================================================
// [5] MAIN CALCULATION ENGINE
//====================================================================
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
   // All loops are chronological. MT5 does not guarantee input indexing direction.
   ArraySetAsSeries(time,false); ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false); ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false); ArraySetAsSeries(tick_volume,false);
   ArraySetAsSeries(volume,false); ArraySetAsSeries(spread,false);
   if(rates_total < 10) return(0);
   if(!ui_all) return(0);

   int limit;
   if(prev_calculated == 0)
     {
      limit = MathMax(1,rates_total-InpStructureBars-1);
      ClearFeatureObjects();
      DrawButtons();
      obj_counter = 0;
      last_tick_price = 0;
      prev_live_bar_time = 0;
      
      prev_valid_high = high[limit-1];
      prev_valid_low = low[limit-1];
      ArrayInitialize(structure_bar,0);
      ArrayResize(mtf_zones,0);
      ResetRenderSnapshots();
         last_edge_time=0;
      
      ArrayResize(BullOBs, 0);
      ArrayResize(BearOBs, 0);
      
      ob_ticket_counter = 0;
      vb1.t = 0; vb2.t = 0; vb3.t = 0;
     }
   else
     {
      limit = prev_calculated - 1;
     }

   for(int i = limit; !InpOBOnlyStructure && i < rates_total - 1; i++)
     {
      // --- OB MITIGATION CHECK (HISTORY) ---
      int total_bull_obs = ArraySize(BullOBs);
      for(int b = 0; b < total_bull_obs; b++)
        {
         if(!BullOBs[b].active) continue;
         if(low[i]<=BullOBs[b].top && high[i]>=BullOBs[b].bottom) BullOBs[b].tested=true;
         
         if(InpMitigation == MITIGATION_BODY)
           {
            if(close[i] < BullOBs[b].bottom) BullOBs[b].active = false;
           }
         else 
           {
            if(low[i] <= BullOBs[b].top) BullOBs[b].active = false;
           }
        }
        
      int total_bear_obs = ArraySize(BearOBs);
      for(int b = 0; b < total_bear_obs; b++)
        {
         if(!BearOBs[b].active) continue;
         if(low[i]<=BearOBs[b].top && high[i]>=BearOBs[b].bottom) BearOBs[b].tested=true;
         
         if(InpMitigation == MITIGATION_BODY)
           {
            if(close[i] > BearOBs[b].top) BearOBs[b].active = false;
           }
         else 
           {
            if(high[i] >= BearOBs[b].bottom) BearOBs[b].active = false;
           }
        }

      if(high[i] <= prev_valid_high && low[i] >= prev_valid_low) continue;
      
      ValidBar vb0;
      vb0.h = high[i];
      vb0.l = low[i];
      vb0.t = time[i];

      // --- ORDER BLOCK CREATION & OVERLAP LOGIC ---
      if(vb3.t != 0)
        {
         if(vb2.l < vb3.l && vb0.l > vb2.h)
           {
            int size = ArraySize(BullOBs);
            ArrayResize(BullOBs, size + 1, 1000);
            BullOBs[size].active = true; BullOBs[size].priority=0;
            BullOBs[size].confirmed_time=time[i]; BullOBs[size].reversal=false;
            BullOBs[size].ob_time = vb2.t;
            BullOBs[size].top = vb2.h;
            BullOBs[size].bottom = vb2.l;
            BullOBs[size].ticket = ++ob_ticket_counter;
            BullOBs[size].fvg_size = vb0.l - vb2.h;
            BullOBs[size].visual_deleted = false;
            BullOBs[size].tested = false;
            BullOBs[size].touch_alerted = false;
            BullOBs[size].has_exited = true;
            BullOBs[size].bars_since_exit = 999;
            
            if(InpMitigation == MITIGATION_BODY)
              {
               for(int b = 0; b < size; b++)
                 {
                  if(!BullOBs[b].active) continue;
                  
                  if(BullOBs[size].bottom <= BullOBs[b].top && BullOBs[size].top >= BullOBs[b].bottom)
                    {
                     if(BullOBs[size].fvg_size > BullOBs[b].fvg_size)
                       {
                        BullOBs[b].active = false;
                       }
                     else
                       {
                        BullOBs[size].active = false;
                        break;
                       }
                    }
                 }
              }
           }
            
         if(vb2.h > vb3.h && vb0.h < vb2.l)
           {
            int size = ArraySize(BearOBs);
            ArrayResize(BearOBs, size + 1, 1000);
            BearOBs[size].active = true; BearOBs[size].priority=0;
            BearOBs[size].confirmed_time=time[i]; BearOBs[size].reversal=false;
            BearOBs[size].ob_time = vb2.t;
            BearOBs[size].top = vb2.h;
            BearOBs[size].bottom = vb2.l;
            BearOBs[size].ticket = ++ob_ticket_counter;
            BearOBs[size].fvg_size = vb2.l - vb0.h;
            BearOBs[size].visual_deleted = false;
            BearOBs[size].tested = false;
            BearOBs[size].touch_alerted = false;
            BearOBs[size].has_exited = true;
            BearOBs[size].bars_since_exit = 999;
            
            if(InpMitigation == MITIGATION_BODY)
              {
               for(int b = 0; b < size; b++)
                 {
                  if(!BearOBs[b].active) continue;
                  
                  if(BearOBs[size].bottom <= BearOBs[b].top && BearOBs[size].top >= BearOBs[b].bottom)
                    {
                     if(BearOBs[size].fvg_size > BearOBs[b].fvg_size)
                       {
                        BearOBs[b].active = false;
                       }
                     else
                       {
                        BearOBs[size].active = false;
                        break;
                       }
                    }
                 }
              }
           }
        }

      vb3 = vb2;
      vb2 = vb1;
      vb1 = vb0;

      prev_valid_high = high[i];
      prev_valid_low = low[i];
     }

   if(!InpOBOnlyStructure) { CompactOB(BullOBs,true); CompactOB(BearOBs,false); }
   RefreshStructures();
   // --- REAL-TIME LIVE BAR TOUCH ALERTS ---
   if(ui_all && ui_ob && InpEnableAlert && rates_total > 1)
     {
      int live_bar = rates_total - 1;
      double check_price = (SymbolInfoDouble(_Symbol, SYMBOL_BID) > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : close[live_bar];
      if(last_tick_price == 0) last_tick_price = check_price;

      bool is_new_bar = (time[live_bar] != prev_live_bar_time);
      if(is_new_bar) prev_live_bar_time = time[live_bar];

      // 1. Bullish OB Touch Alert Logic
      int total_bull = ArraySize(BullOBs);
      int displayed_bull = 0;
      for(int b = total_bull - 1; b >= 0; b--)
        {
         if(!BullOBs[b].active) continue;
         if(BullOBs[b].priority>=(ui_history?100:InpMaxOB)) continue;
         displayed_bull++;
         
         if(check_price > BullOBs[b].top)
           {
            if(!BullOBs[b].has_exited)
              {
               BullOBs[b].has_exited = true;
               BullOBs[b].bars_since_exit = 0;
              }
            else if(is_new_bar && BullOBs[b].touch_alerted)
              {
               BullOBs[b].bars_since_exit++;
              }
               
            if(BullOBs[b].bars_since_exit >= InpAlertCooldownBars)
              {
               BullOBs[b].touch_alerted = false;
              }
           }
         else if(check_price <= BullOBs[b].top)
           {
            BullOBs[b].has_exited = false;
           }
         
         if(last_tick_price > BullOBs[b].top && check_price <= BullOBs[b].top && check_price >= BullOBs[b].bottom && !BullOBs[b].touch_alerted)
           {
            string msg = StringFormat("Bullish OB Touch at %s [%s, %s]", DoubleToString(BullOBs[b].top, _Digits), _Symbol, TimeframeLabel((ENUM_TIMEFRAMES)_Period));
            if(InpAlertPopup) Alert(msg);
            if(InpAlertPush) SendNotification(msg);
            BullOBs[b].touch_alerted = true;
           }
        }

      // 2. Bearish OB Touch Alert Logic
      int total_bear = ArraySize(BearOBs);
      int displayed_bear = 0;
      for(int b = total_bear - 1; b >= 0; b--)
        {
         if(!BearOBs[b].active) continue;
         if(BearOBs[b].priority>=(ui_history?100:InpMaxOB)) continue;
         displayed_bear++;
         
         if(check_price < BearOBs[b].bottom)
           {
            if(!BearOBs[b].has_exited)
              {
               BearOBs[b].has_exited = true;
               BearOBs[b].bars_since_exit = 0;
              }
            else if(is_new_bar && BearOBs[b].touch_alerted)
              {
               BearOBs[b].bars_since_exit++;
              }
               
            if(BearOBs[b].bars_since_exit >= InpAlertCooldownBars)
              {
               BearOBs[b].touch_alerted = false;
              }
           }
         else if(check_price >= BearOBs[b].bottom)
           {
            BearOBs[b].has_exited = false;
           }
         
         if(last_tick_price < BearOBs[b].bottom && check_price >= BearOBs[b].bottom && check_price <= BearOBs[b].top && !BearOBs[b].touch_alerted)
           {
            string msg = StringFormat("Bearish OB Touch at %s [%s, %s]", DoubleToString(BearOBs[b].bottom, _Digits), _Symbol, TimeframeLabel((ENUM_TIMEFRAMES)_Period));
            if(InpAlertPopup) Alert(msg);
            if(InpAlertPush) SendNotification(msg);
            BearOBs[b].touch_alerted = true;
           }
        }

      last_tick_price = check_price;
     }

   UpdateLiveEdges();
   if(view_dirty) { ChartRedraw(); view_dirty=false; }

   return(rates_total);
  }
//+------------------------------------------------------------------+
// Structure history is a bounded replay window, not an all-time structure seed.
// Closed-bar external structure. A protected opposite level is promoted ONLY
// at a close-based BOS. Confirmed minor pivots never change the trend.
// Swing labels use pivot time; BOS/CHOCH labels use confirmation time.
struct StructureBreak
{
   int from;
   int to;
   double price;
   int direction;
   bool reversal;
};

struct LiquiditySweep
{
   int source;
   int bar;
   double level;
   int direction; // +1 high swept; -1 low swept; does NOT mean a trade signal
};
struct RenderSnapshot
{
   bool valid;
   MqlRates rates[];
   StructureBreak events[];
   LiquiditySweep sweeps[];
   ENUM_TIMEFRAMES tf;
   int trend,origin,extreme,hi,lo;
   double origin_price;
   bool ready;
};
RenderSnapshot render_cache[2]; // chart + optional separate Fibo TF

void CheckSweep(LiquiditySweep &sweeps[],const MqlRates &r[],int i,int source,double level,int direction)
{
   if(source<0 || i<=source) return;
   double buffer=InpSweepBufferPoints*_Point;
   bool swept=direction==1?(r[i].high>level+buffer && r[i].close<=level):
                            (r[i].low<level-buffer && r[i].close>=level);
   if(!swept) return;
   // One mark per external source / side. No marks on internal pivots.
   int n=ArraySize(sweeps);
   for(int k=n-1;k>=0;k--)
      if(sweeps[k].source==source && sweeps[k].direction==direction && sweeps[k].level==level) return;
   int cap=400;
   if(n>=cap) { for(int k=1;k<n;k++) sweeps[k-1]=sweeps[k]; n--; }
   ArrayResize(sweeps,n+1);
   sweeps[n].source=source; sweeps[n].bar=i; sweeps[n].level=level; sweeps[n].direction=direction;
}



void RestoreOBState(OrderBlock &ob,const OrderBlock &old[])
{
   for(int k=0;k<ArraySize(old);k++)
      if(old[k].ob_time==ob.ob_time && old[k].confirmed_time==ob.confirmed_time)
      {
         ob.tested=ob.tested || old[k].tested;
         ob.touch_alerted=old[k].touch_alerted;
         ob.has_exited=old[k].has_exited;
         ob.bars_since_exit=old[k].bars_since_exit;
         return;
      }
}
void BuildStructureOB(const MqlRates &r[],const StructureBreak &events[])
{
   OrderBlock bulls[],bears[];
   datetime used_bull[],used_bear[];
   int count=ArraySize(r);
   if(count>0) { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); zone_quote[0]=bid>0?bid:r[count-1].close; }
   for(int e=0;e<ArraySize(events);e++)
   {
      StructureBreak br=events[e];
      int source=-1;
      int first=MathMax(0,br.to-InpOBSearchBars);
      for(int k=br.to-1;k>=first;k--)
      {
         bool opposite=br.direction==1?r[k].close<r[k].open:r[k].close>r[k].open;
         if(opposite) { source=k; break; }
      }
      if(source<0) continue; // Never substitute a same-direction candle.
      double top=r[source].high,bottom=r[source].low;
      if(br.direction==1?r[br.to].close<=top:r[br.to].close>=bottom) continue;
      if(!OBDepartureOK(r,source,br.to,br.direction,top,bottom)) continue;
      bool valid=true;
      // Reject source candles already breached distally before confirmation.
      for(int k=source+1;k<=br.to;k++)
         if(br.direction==1?r[k].close<bottom:r[k].close>top) { valid=false; break; }
      if(!valid) continue;
      bool duplicate=false;
      if(br.direction==1)
      {
         for(int k=0;k<ArraySize(used_bull);k++) if(used_bull[k]==r[source].time) { duplicate=true; break; }
         if(!duplicate) { int n=ArraySize(used_bull); ArrayResize(used_bull,n+1); used_bull[n]=r[source].time; }
      }
      else
      {
         for(int k=0;k<ArraySize(used_bear);k++) if(used_bear[k]==r[source].time) { duplicate=true; break; }
         if(!duplicate) { int n=ArraySize(used_bear); ArrayResize(used_bear,n+1); used_bear[n]=r[source].time; }
      }
      if(duplicate) continue; // A mitigated source cannot be reactivated by a later BOS.
      // Confirm first; the visual extends back to its source candle.
      bool tested=false;
      for(int k=br.to+1;k<count;k++)
      {
         if(r[k].high>=bottom && r[k].low<=top) tested=true;
         bool invalid=false;
         if(InpMitigation==MITIGATION_BODY) invalid=br.direction==1?r[k].close<bottom:r[k].close>top;
         else invalid=br.direction==1?r[k].low<=top:r[k].high>=bottom;
         if(invalid) { valid=false; break; }
      }
      if(!valid) continue;
      OrderBlock ob;
      ob.active=true; ob.priority=0; ob.ob_time=r[source].time; ob.confirmed_time=br.to+1<count?r[br.to+1].time:iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
      ob.reversal=br.reversal; ob.top=top; ob.bottom=bottom;
      ob.ticket=(long)r[br.to].time; ob.fvg_size=0; ob.visual_deleted=false;
      ob.tested=tested; ob.touch_alerted=false; ob.has_exited=true; ob.bars_since_exit=999;
      if(br.direction==1)
      {
         RestoreOBState(ob,BullOBs);
         int n=ArraySize(bulls); ArrayResize(bulls,n+1); bulls[n]=ob;
      }
      else
      {
         RestoreOBState(ob,BearOBs);
         int n=ArraySize(bears); ArrayResize(bears,n+1); bears[n]=ob;
      }
   }
   PruneOBObjects(BullOBs,bulls,true); PruneOBObjects(BearOBs,bears,false);
   ArrayResize(BullOBs,ArraySize(bulls)); ArrayResize(BearOBs,ArraySize(bears));
   for(int k=0;k<ArraySize(bulls);k++) BullOBs[k]=bulls[k];
   for(int k=0;k<ArraySize(bears);k++) BearOBs[k]=bears[k];
   CompactOB(BullOBs,true); CompactOB(BearOBs,false);
}

void PruneOBObjects(const OrderBlock &old[],const OrderBlock &next[],bool bull)
{
   for(int k=0;k<ArraySize(old);k++)
   {
      bool keep=false;
      for(int j=0;j<ArraySize(next);j++)
         if(old[k].ticket==next[j].ticket && old[k].ob_time==next[j].ob_time) { keep=true; break; }
      if(keep) continue;
      string name=instance_prefix+(bull?"OB_BULL_":"OB_BEAR_")+IntegerToString(old[k].ticket);
      ObjectDelete(0,name); ObjectDelete(0,name+"_lbl"); ObjectDelete(0,name+"_fill");
   }
}
void CompactOB(OrderBlock &blocks[],const bool bull)
{
   int keep=0;
   for(int i=ArraySize(blocks)-1;i>=0;i--)
   {
      if(blocks[i].active && keep<(InpMaxOB>0?100:0)) { keep++; continue; }
      string name=instance_prefix+(bull?"OB_BULL_":"OB_BEAR_")+IntegerToString(blocks[i].ticket);
      ObjectDelete(0,name); ObjectDelete(0,name+"_lbl"); ObjectDelete(0,name+"_fill");
      blocks[i].active=false;
   }
   int write=0;
   for(int i=0;i<ArraySize(blocks);i++)
      if(blocks[i].active) blocks[write++]=blocks[i];
   ArrayResize(blocks,write);
}

bool PivotHigh(const MqlRates &r[],const int j,const int strength)
{
   for(int k=1;k<=strength;k++)
      if(r[j].high<=r[j-k].high || r[j].high<r[j+k].high) return false;
   return true;
}
bool PivotLow(const MqlRates &r[],const int j,const int strength)
{
   for(int k=1;k<=strength;k++)
      if(r[j].low>=r[j-k].low || r[j].low>r[j+k].low) return false;
   return true;
}
int Lowest(const MqlRates &r[],int a,const int b)
{
   int best=a;
   for(int k=a+1;k<=b;k++) if(r[k].low<r[best].low) best=k;
   return best;
}
int Highest(const MqlRates &r[],int a,const int b)
{
   int best=a;
   for(int k=a+1;k<=b;k++) if(r[k].high>r[best].high) best=k;
   return best;
}
void AddBreak(StructureBreak &events[],int a,int b,double price,int direction,bool reversal)
{
   int n=ArraySize(events);
   // Bound replay storage as well as chart object count.
   int cap=400; // OB replay needs older breaks even with chart history off
   if(n>=cap) { for(int k=1;k<n;k++) events[k-1]=events[k]; n--; }
   ArrayResize(events,n+1);
   events[n].from=a; events[n].to=b; events[n].price=price;
   events[n].direction=direction; events[n].reversal=reversal;
}

void StyleObject(const string name,const color c)
{
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
void Line(const string name,datetime a,double pa,datetime b,double pb,color c,int style=STYLE_SOLID)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,a,pa,b,pb);
   else { ObjectMove(0,name,0,a,pa); ObjectMove(0,name,1,b,pb); }
   StyleObject(name,c);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
}
void TextAt(const string name,datetime t,double p,const string text,color c)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,p);
   else ObjectMove(0,name,0,t,p);
   StyleObject(name,c);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,6);
}
void Panel(const string name,const int row,const string text,color c)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   StyleObject(name,c);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,20+row*18);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,7);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void DrawFibo(const MqlRates &r[],int origin,int extreme,double start,double end)
{
   string name=instance_prefix+"FIBO";
   if(origin<0 || extreme<=origin || start==end) { ObjectDelete(0,name); return; }
   // MT5 level 0 is at second anchor: 0=end, 100=impulse origin.
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_FIBO,0,r[origin].time,start,r[extreme].time,end);
   else { ObjectMove(0,name,0,r[origin].time,start); ObjectMove(0,name,1,r[extreme].time,end); }
   StyleObject(name,InpFiboColor);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
   double levels[]={0.0,0.236,0.382,0.5,0.618,0.786,1.0,-0.272,-0.618};
   ObjectSetInteger(0,name,OBJPROP_LEVELS,ArraySize(levels));
   for(int k=0;k<ArraySize(levels);k++)
   {
      ObjectSetDouble(0,name,OBJPROP_LEVELVALUE,k,levels[k]);
      ObjectSetInteger(0,name,OBJPROP_LEVELCOLOR,k,InpFiboColor);
      ObjectSetInteger(0,name,OBJPROP_LEVELSTYLE,k,STYLE_DOT);
      ObjectSetString(0,name,OBJPROP_LEVELTEXT,k,(levels[k]<0?"Ext "+DoubleToString((1.0-levels[k])*100,1):DoubleToString(levels[k]*100,1))+"%  %$");
   }
}

bool ComputeStructure(ENUM_TIMEFRAMES tf,int slot,bool draw,bool fibo)
{
   if(tf==PERIOD_CURRENT) tf=(ENUM_TIMEFRAMES)_Period;
   if(slot>0 && slot<4 && !UniqueZoneSlot(tf,slot))
   {
      int previous=tf==(ENUM_TIMEFRAMES)_Period?0:(slot>1 && tf==ZoneTimeframe(InpTF1)?1:2);
      structure_status[slot]=structure_status[previous];
      zone_load_state[slot]=zone_load_state[previous]; zone_load_count[slot]=zone_load_count[previous];
      return true;
   }
   datetime latest=iTime(_Symbol,tf,1);
   int available=MathMax(0,Bars(_Symbol,tf)-1);
   int wanted=MathMin(available,InpStructureBars);
   if(!ui_force_refresh && latest!=0 && structure_bar[slot]==latest && structure_count[slot]==wanted) return true;
   MqlRates r[]; ArraySetAsSeries(r,false);
   int count=CopyRates(_Symbol,tf,1,InpStructureBars,r); // never include live candle
   int s=InpPivotStrength;
   int required=MathMax(2*s+10,ui_sd && (InpSDAutoTimeframes?IsSDTimeframe(tf):(slot!=4))?2*InpSDPivotStrength+10:0);
   if(count<required)
   {
      zone_load_state[slot]=1; zone_load_count[slot]=MathMax(0,count);
      structure_bar[slot]=0; structure_count[slot]=0;
      if(slot==0 || slot==4)
      { int cache=slot==0?0:1; render_cache[cache].valid=false; ArrayFree(render_cache[cache].rates); ArrayFree(render_cache[cache].events); ArrayFree(render_cache[cache].sweeps); }
      structure_status[slot]=TimeframeLabel(tf)+" | Waiting for closed bars";
      if(slot!=4) ClearZoneSlot(slot);
      if(slot==0) { ArrayFree(BullOBs); ArrayFree(BearOBs); ObjectsDeleteAll(0,instance_prefix+"OB_"); zone_quote[0]=0; }
      if(slot==4) ObjectDelete(0,instance_prefix+"FIBO");
      // No cached success: retry once per second when MT5 finishes loading.
      return false;
   }
   if(!ui_force_refresh && structure_bar[slot]==r[count-1].time && structure_count[slot]==count) return true;
   zone_load_state[slot]=2; zone_load_count[slot]=count;
   StructureBreak events[]; LiquiditySweep sweeps[];
   int hi=-1,lo=-1,trend=0,extreme=-1,origin=-1;
   double origin_price=0;
   bool ready=false;
   double buffer=InpBreakBufferPoints*_Point;
   for(int i=2*s;i<count;i++)
   {
      int j=i-s;
      bool ph=PivotHigh(r,j,s),pl=PivotLow(r,j,s);
      if(trend==0)
      {
         if(ph) hi=j;
         if(pl) lo=j;
         if(hi<0 || lo<0) continue;
         if(r[i].close>r[hi].high+buffer)
         {
            origin=Lowest(r,MathMin(hi,lo),i-1); lo=origin;
            origin_price=r[lo].low;
            AddBreak(events,hi,i,r[hi].high,1,false);
            trend=1; extreme=Highest(r,origin,i); ready=false;
         }
         else if(r[i].close<r[lo].low-buffer)
         {
            origin=Highest(r,MathMin(hi,lo),i-1); hi=origin;
            origin_price=r[hi].high;
            AddBreak(events,lo,i,r[lo].low,-1,false);
            trend=-1; extreme=Lowest(r,origin,i); ready=false;
         }
         continue;
      }
      if(slot==0 && ui_sweeps)
      {
         if(trend==1)
         {
            CheckSweep(sweeps,r,i,lo,r[lo].low,-1);
            if(ready) CheckSweep(sweeps,r,i,hi,r[hi].high,1);
         }
         else
         {
            CheckSweep(sweeps,r,i,hi,r[hi].high,1);
            if(ready) CheckSweep(sweeps,r,i,lo,r[lo].low,-1);
         }
      }
      if(trend==1)
      {
         // Protected low remains locked throughout all internal pullbacks.
         if(r[i].close<r[lo].low-buffer)
         {
            AddBreak(events,lo,i,r[lo].low,-1,true);

            hi=extreme; origin=hi; origin_price=r[hi].high;
            trend=-1; extreme=Lowest(r,origin,i); ready=false;
            continue;
         }
         if(ready && r[i].close>r[hi].high+buffer)
         {
            AddBreak(events,hi,i,r[hi].high,1,false);
            // Structural HL = lowest pullback AFTER the broken external high.
            int candidate=Lowest(r,hi+1,i-1);
            if(r[candidate].low>r[lo].low && candidate>extreme)
            {


               lo=candidate; origin=lo; origin_price=r[lo].low;
            }
            extreme=Highest(r,origin,i); ready=false;
         }
         else
         {
            if(r[i].high>r[extreme].high) extreme=i;
            if(!ready && ph && j==extreme && j>origin) { hi=j; ready=true; }
         }
      }
      else
      {
         if(r[i].close>r[hi].high+buffer)
         {
            AddBreak(events,hi,i,r[hi].high,1,true);

            lo=extreme; origin=lo; origin_price=r[lo].low;
            trend=1; extreme=Highest(r,origin,i); ready=false;
            continue;
         }
         if(ready && r[i].close<r[lo].low-buffer)
         {
            AddBreak(events,lo,i,r[lo].low,-1,false);
            int candidate=Highest(r,lo+1,i-1);
            if(r[candidate].high<r[hi].high && candidate>extreme)
            {


               hi=candidate; origin=hi; origin_price=r[hi].high;
            }
            extreme=Lowest(r,origin,i); ready=false;
         }
         else
         {
            if(r[i].low<r[extreme].low) extreme=i;
            if(!ready && pl && j==extreme && j>origin) { lo=j; ready=true; }
         }
      }
   }
   if(slot==0 && InpOBOnlyStructure) BuildStructureOB(r,events);
   if(slot!=4) BuildMTFZones(r,events,tf,slot);
   if(slot==0) UpdateOBPriorities();
   string tag=TimeframeLabel(tf);
   structure_status[slot]=tag+" | "+(trend==1?"UP":trend==-1?"DOWN":"RANGE / no break");
   if(trend!=0) structure_status[slot]+=" | Protected "+(trend==1?"L ":"H ")+DoubleToString(trend==1?r[lo].low:r[hi].high,_Digits);
   SaveRenderSnapshot(slot,r,events,sweeps,tf,trend,origin,extreme,hi,lo,origin_price,ready);
   RenderPayload(r,events,sweeps,tf,trend,origin,extreme,hi,lo,origin_price,ready,draw,fibo,true);
   view_dirty=true;
   structure_bar[slot]=r[count-1].time; structure_count[slot]=count;
   return true;
}
void RefreshStructures(bool force=false)
{
   // Throttle failed CopyRates retries, and avoid history scans on every tick.
   static ulong last_check=0;
   ulong now=GetTickCount64();
   if(!ui_all) { ui_force_refresh=false; return; }
   if(!force && last_check!=0 && now-last_check<1000) return;
   if(visibility_dirty) { ApplyVisibility(); visibility_dirty=false; }
   ui_force_refresh=false;
   last_check=now;
   ENUM_TIMEFRAMES chart_tf=(ENUM_TIMEFRAMES)_Period;
   ENUM_TIMEFRAMES ft=InpFiboTF==PERIOD_CURRENT?chart_tf:InpFiboTF;
   bool visuals=ui_all && (ui_structure || ui_sweeps);
   if(ui_all)
      ComputeStructure(chart_tf,0,visuals,ui_all && ui_fibo && ft==chart_tf);
   if(ui_fibo && ft!=chart_tf) ComputeStructure(ft,4,false,true);
   if(ui_all)
   {
      if(ui_obmtf || ui_sd || ui_mtf)
      {
         ENUM_TIMEFRAMES configured[]={InpTF1,InpTF2,InpTF3};
         for(int k=0;k<3;k++)
         {
            ENUM_TIMEFRAMES tf=ZoneTimeframe(configured[k]);
            if(ui_obmtf || ui_mtf || (ui_sd && (!InpSDAutoTimeframes || IsSDTimeframe(tf))))
               ComputeStructure(tf,k+1,false,false);
            else ClearZoneSlot(k+1);
         }
      }
      if(ui_sd && InpSDAutoTimeframes)
      {
         for(int k=0;k<2;k++)
         {
            ENUM_TIMEFRAMES tf=SDHigherTimeframe(k);
            if(tf!=PERIOD_CURRENT && !ConfiguredTimeframe(tf)) ComputeStructure(tf,k+5,false,false);
            else ClearZoneSlot(k+5);
         }
      }
      else { ClearZoneSlot(5); ClearZoneSlot(6); }
      for(int k=0;ui_mtf && k<4;k++) Panel(instance_prefix+"MTF_"+IntegerToString(k),k,structure_status[k],clrSilver);
   }
   RefreshZoneQuotes();
   DrawSDStatus();
   ui_force_refresh=false;
}

string TimeframeLabel(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_CURRENT) tf=(ENUM_TIMEFRAMES)_Period;
   string label=EnumToString(tf);
   StringReplace(label,"PERIOD_","");
   return label;
}
void ClearFeatureObjects()
{
   ObjectsDeleteAll(0,instance_prefix+"OB_");
   ObjectsDeleteAll(0,instance_prefix+"STRUCT_");
   ObjectDelete(0,instance_prefix+"FIBO");
   ObjectsDeleteAll(0,instance_prefix+"MTF_");
   ObjectsDeleteAll(0,instance_prefix+"ZONE_");
   ObjectDelete(0,instance_prefix+"SD_STATUS");
}
void Button(const string key,const string caption,const bool enabled,const int index)
{
   string name=instance_prefix+"BTN_"+key;
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);
   }
   int chart_width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int count=ui_all?7:1,gap=3;
   int margin=MathMax(8,InpButtonX);
   int width=MathMax(1,MathMin(80,(chart_width-2*margin-(count-1)*gap)/count));
   int total=count*width+(count-1)*gap;
   int left=MathMax(0,(chart_width-total)/2);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,left+index*(width+gap));
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,InpButtonY);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,22);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,enabled && (ui_all || key=="ALL")?clrDarkGreen:clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrGray);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,6);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   bool effective=enabled && (ui_all || key=="ALL");
   bool paused=key=="SD" && enabled && !ui_all;
   ObjectSetString(0,name,OBJPROP_TEXT,caption+(paused?" PAUSE":effective?" ON":" OFF"));
   if(paused) ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrDarkGoldenrod);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,key=="ALL"?"Bat/tat toan bo hien thi va canh bao; giu lua chon":
      key=="STR"?"Cau truc BOS/CHOCH + quet thanh khoan cung bat/tat":
      key=="OBMTF"?"ON: OB chart + cac khung MTF. OFF: chi OB khung chart":
      key=="HIST"?"Lich su: cau truc, sweep va OB/cung/cau con hieu luc trong cua so du lieu":
      key=="SD"?"S/D Auto: khung chart + 2 khung lon hon. H1/H4/D1; D1/W1/MN1. Khong tat OB. PAUSE = ALL OFF":
      "Click de bat/tat "+caption);
}
// Remove retired feature buttons from this project's legacy chart prefixes only.
void CleanupRetiredButtons()
{
   string legacy="SMC_"+IntegerToString(ChartID())+"_";
   string current="SMC_NGU_"+IntegerToString(ChartID())+"_";
   for(int k=ObjectsTotal(0)-1;k>=0;k--)
   {
      string name=ObjectName(0,k);
      if(StringFind(name,legacy)!=0 && StringFind(name,current)!=0) continue;
      int at=StringFind(name,"BTN_");
      if(at<0) continue;
      string key=StringSubstr(name,at+4);
      if(key=="WAV" || key=="WAVE" || key=="PWR" || key=="POW" || key=="POWER" ||
         key=="SIG" || key=="BS" || key=="B_S" || key=="VOL") ObjectDelete(0,name);
   }
}
void DrawButtons()
{
   if(!ui_all)
   {
      // ALL OFF leaves exactly one indicator object: the centered ALL button.
      ObjectsDeleteAll(0,instance_prefix);
      Button("ALL","ALL",false,0);
      return;
   }
   if(!InpShowButtons) { ObjectsDeleteAll(0,instance_prefix+"BTN_"); return; }
   for(int k=ObjectsTotal(0)-1;k>=0;k--)
   {
      string name=ObjectName(0,k),prefix=instance_prefix+"BTN_";
      if(StringFind(name,prefix)!=0) continue;
      string key=StringSubstr(name,StringLen(prefix));
      if(key!="ALL" && key!="HIST" && key!="OBMTF" && key!="STR" && key!="FIB" && key!="MTF" && key!="SD")
         ObjectDelete(0,name);
   }
   Button("ALL","ALL",ui_all,0);
   Button("HIST","Hist",ui_history,1);
   Button("OBMTF","OB MTF",ui_obmtf,2);
   Button("STR","Stru",ui_structure,3);
   Button("FIB","Fibo",ui_fibo,4);
   Button("MTF","MTF",ui_mtf,5);
   Button("SD","S/D",ui_sd,6);
}
void RedrawOBNow()
{
   datetime t[]; ArraySetAsSeries(t,false);
   if(CopyTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0,1,t)==1) UpdateOBGraphics(t,0);
}
// Temporary per-chart state. Written at each click, not in OnDeinit: old/new
// indicator instances can receive reinitialization events in different orders.
string UiStateKey()
{
   return "SMC_NGU_UI_"+IntegerToString(ChartID())+"_"+IntegerToString(InpStateInstance);
}
int UiDefaultMask()
{
   return 1+(InpShowHistory?8:0)+(InpShowMTFOB?16:0)+(InpShowStructure?32:0)+
      (InpShowFibo?64:0)+(InpShowMTF?128:0)+(InpShowSupplyDemand?256:0);
}
int UiCurrentMask()
{
   return (ui_all?1:0)+(ui_history?8:0)+(ui_obmtf?16:0)+(ui_structure?32:0)+
      (ui_fibo?64:0)+(ui_mtf?128:0)+(ui_sd?256:0);
}
void ApplyUiMask(int mask)
{
   ui_all=(mask&1)!=0; ui_history=(mask&8)!=0; ui_obmtf=(mask&16)!=0;
   ui_structure=(mask&32)!=0; ui_fibo=(mask&64)!=0; ui_mtf=(mask&128)!=0;
   ui_sd=(mask&256)!=0; ui_sweeps=ui_structure; ui_ob=true;
}
void LoadUiState()
{
   string key=UiStateKey();
   if(!GlobalVariableCheck(key) || !GlobalVariableCheck(key+"_D")) return;
   double saved=GlobalVariableGet(key),defaults=GlobalVariableGet(key+"_D");
   if(saved<0 || saved>511 || defaults<0 || defaults>511) return;
   int changed=((int)defaults)^UiDefaultMask();
   // Explicitly changed Inputs win only for their own switches.
   int mask=(((int)saved)&(~changed)) | (UiDefaultMask()&changed);
   ApplyUiMask(mask);
}
void SaveUiState()
{
   string key=UiStateKey();
   if(GlobalVariableTemp(key)) GlobalVariableSet(key,UiCurrentMask());
   if(GlobalVariableTemp(key+"_D")) GlobalVariableSet(key+"_D",UiDefaultMask());
}
void ClearUiState()
{
   string key=UiStateKey();
   GlobalVariableDel(key); GlobalVariableDel(key+"_D");
}
bool ToggleFeature(const string key)
{
   if(key=="ALL") { ui_all=!ui_all; return true; }
   bool enable;
   if(key=="STR") { enable=!(ui_all && ui_structure); ui_structure=enable; ui_sweeps=enable; }
   else if(key=="FIB") { enable=!(ui_all && ui_fibo); ui_fibo=enable; }
   else if(key=="MTF") { enable=!(ui_all && ui_mtf); ui_mtf=enable; }
   else if(key=="HIST") { enable=!(ui_all && ui_history); ui_history=enable; }
   else if(key=="OBMTF") { enable=!(ui_all && ui_obmtf); ui_obmtf=enable; ui_ob=true; }
   else if(key=="SD") { enable=!(ui_all && ui_sd); ui_sd=enable; }
   else return false;
   if(enable) ui_all=true;
   return true;
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE) { DrawButtons(); ChartRedraw(); return; }
   if(id!=CHARTEVENT_OBJECT_CLICK || StringFind(sparam,instance_prefix+"BTN_")!=0) return;
   string key=StringSubstr(sparam,StringLen(instance_prefix+"BTN_"));
   if(!ui_all && key!="ALL") return; // Ignore queued clicks from buttons just hidden.
   bool was_all=ui_all;
   if(!ToggleFeature(key)) return;
   SaveUiState();
   if((key=="SD" && !ui_sd) || (key=="OBMTF" && !ui_obmtf))
   {
      int kind=key=="SD"?1:0,write=0;
      for(int k=0;k<ArraySize(mtf_zones);k++)
         if(mtf_zones[k].kind!=kind) mtf_zones[write++]=mtf_zones[k];
      ArrayResize(mtf_zones,write);
   }
   if(key=="STR" && !ui_sweeps) ArrayFree(render_cache[0].sweeps);
   if(key=="FIB" && !ui_fibo)
   {
      render_cache[1].valid=false; ArrayFree(render_cache[1].rates);
      ArrayFree(render_cache[1].events); ArrayFree(render_cache[1].sweeps); structure_bar[4]=0;
   }
   if(key=="ALL" || key=="OBMTF") last_tick_price=0;
   if(key=="SD" || key=="OBMTF" || key=="MTF" || key=="STR" || (!was_all && ui_all))
      ArrayInitialize(structure_bar,0); // Rebuild on timer; no market scan in click handler.
   if(!ui_all)
   {
      ResetRenderSnapshots(); ArrayFree(mtf_zones); ArrayFree(BullOBs); ArrayFree(BearOBs);
      ArrayInitialize(structure_bar,0); ArrayInitialize(structure_count,0);
   }
   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   visibility_dirty=true;
   if(key=="HIST") ObjectsDeleteAll(0,instance_prefix+"STRUCT_");
   RenderCachedView(!was_all && ui_all?"ALL":key);
   DrawButtons();
   ChartRedraw();
   view_dirty=false;
}
void OnTimer()
{
   RefreshStructures();
   UpdateLiveEdges();
   if(view_dirty) { ChartRedraw(); view_dirty=false; }
}

ENUM_TIMEFRAMES ZoneTimeframe(ENUM_TIMEFRAMES tf)
{
   return tf==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:tf;
}
// The standard analysis ladder, rather than every MT5 intermediate timeframe.
ENUM_TIMEFRAMES SDHigherTimeframe(int offset)
{
   ENUM_TIMEFRAMES ladder[]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_H1,PERIOD_H4,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   int current=PeriodSeconds((ENUM_TIMEFRAMES)_Period),found=0;
   for(int k=0;k<ArraySize(ladder);k++)
      if(PeriodSeconds(ladder[k])>current)
      {
         if(found==offset) return ladder[k];
         found++;
      }
   return PERIOD_CURRENT; // No fabricated higher TF beyond MN1.
}
bool IsSDTimeframe(ENUM_TIMEFRAMES tf)
{
   tf=ZoneTimeframe(tf);
   if(tf==(ENUM_TIMEFRAMES)_Period) return true;
   ENUM_TIMEFRAMES first=SDHigherTimeframe(0),second=SDHigherTimeframe(1);
   return (first!=PERIOD_CURRENT && tf==first) || (second!=PERIOD_CURRENT && tf==second);
}
bool ConfiguredTimeframe(ENUM_TIMEFRAMES tf)
{
   return tf==ZoneTimeframe(InpTF1) || tf==ZoneTimeframe(InpTF2) || tf==ZoneTimeframe(InpTF3);
}
bool UniqueZoneSlot(ENUM_TIMEFRAMES tf,int slot)
{
   tf=ZoneTimeframe(tf);
   if(slot==0) return true;
   if(tf==(ENUM_TIMEFRAMES)_Period) return false;
   if(slot>=5) return true; // SD-only extra slots; configured TFs are reused by refresh.
   if(slot>1 && tf==ZoneTimeframe(InpTF1)) return false;
   if(slot>2 && tf==ZoneTimeframe(InpTF2)) return false;
   return true;
}
void ClearZoneSlot(int slot)
{
   int write=0;
   for(int k=0;k<ArraySize(mtf_zones);k++)
      if(mtf_zones[k].slot!=slot) mtf_zones[write++]=mtf_zones[k];
   ArrayResize(mtf_zones,write);
   ObjectsDeleteAll(0,instance_prefix+"ZONE_"+IntegerToString(slot)+"_");
}
double ZoneATR(const MqlRates &r[],int before)
{
   int first=MathMax(1,before-InpZoneATRPeriod);
   if(before-first<5) return 0;
   double value=0;
   for(int k=first;k<before;k++)
      value+=MathMax(r[k].high-r[k].low,MathMax(MathAbs(r[k].high-r[k-1].close),MathAbs(r[k].low-r[k-1].close)));
   return value/(before-first);
}
bool ZoneStillValid(const MqlRates &r[],int break_bar,double top,double bottom,int direction,bool &tested)
{
   tested=false;
   for(int k=break_bar+1;k<ArraySize(r);k++)
   {
      bool overlap=r[k].low<=top && r[k].high>=bottom;
      if(overlap) tested=true;
      bool invalid=InpMTFZoneMitigation==MITIGATION_BODY?
         (direction==1?r[k].close<bottom:r[k].close>top):
         (direction==1?r[k].low<=top:r[k].high>=bottom);
      if(invalid) return false;
   }
   return !InpOnlyFreshMTFZones || !tested;
}
void SaveMTFZone(ENUM_TIMEFRAMES tf,int slot,int kind,int direction,datetime source,
                 datetime confirmed,double top,double bottom,bool tested,bool reversal)
{
   if(top<=bottom || confirmed<=source) return;
   // One source per type/side/TF: repeated BOS does not duplicate the rectangle.
   for(int k=0;k<ArraySize(mtf_zones);k++)
      if(mtf_zones[k].slot==slot && mtf_zones[k].kind==kind &&
         mtf_zones[k].direction==direction && mtf_zones[k].source==source) return;
   int n=ArraySize(mtf_zones); ArrayResize(mtf_zones,n+1);
   mtf_zones[n].tf=tf; mtf_zones[n].slot=slot; mtf_zones[n].kind=kind;
   mtf_zones[n].direction=direction; mtf_zones[n].source=source;
   mtf_zones[n].confirmed=confirmed; mtf_zones[n].top=top; mtf_zones[n].bottom=bottom;
   mtf_zones[n].tested=tested; mtf_zones[n].reversal=reversal;
   mtf_zones[n].reactions=0; mtf_zones[n].touches=0; mtf_zones[n].quality=0; mtf_zones[n].repeated=false; mtf_zones[n].departure=false;
}





struct SDCandidate
{
   int source,confirmed_bar,direction,last_reaction,pending_since,reactions,touches;
   double top,bottom,atr,penetration;
   bool valid,armed,pending,structural,reversal,departure,visited;
};
void BuildZoneATRCache(const MqlRates &r[],double &atr[])
{
   int count=ArraySize(r); ArrayResize(atr,count);
   double prefix[]; ArrayResize(prefix,count+1); prefix[0]=0;
   for(int k=0;k<count;k++)
   {
      double tr=r[k].high-r[k].low;
      if(k>0) tr=MathMax(tr,MathMax(MathAbs(r[k].high-r[k-1].close),MathAbs(r[k].low-r[k-1].close)));
      prefix[k+1]=prefix[k]+tr;
      int first=MathMax(1,k-InpZoneATRPeriod);
      atr[k]=k-first>=5?(prefix[k]-prefix[first])/(k-first):0;
   }
}
bool SDReaction(const SDCandidate &z,const MqlRates &c)
{
   double distance=z.direction==1?c.close-z.top:z.bottom-c.close;
   return distance>=InpSDReactionATR*z.atr && z.direction*(c.close-c.open)>=InpSDReactionBodyATR*z.atr &&
      c.high-c.low<=(z.departure?InpSDDepartureMaxCandleATR:InpSDMaxSeedATR)*z.atr;
}
void AddSDCandidate(SDCandidate &zones[],const MqlRates &r[],int source,int bar,int direction,
                    double top,double bottom,double atr,int origin,bool reversal)
{
   if(atr<=0 || top<=bottom || top-bottom>InpSDMaxWidthATR*atr) return;
   for(int k=0;k<ArraySize(zones);k++)
   {
      if(!zones[k].valid || zones[k].direction!=direction) continue;
      double overlap=MathMin(top,zones[k].top)-MathMax(bottom,zones[k].bottom);
      double width=MathMin(top-bottom,zones[k].top-zones[k].bottom);
      if(overlap>=InpSDMergeOverlap*width)
      {
         // Existing seed must not suppress later BOS/departure evidence. Bounds stay fixed.
         SDCandidate evidence=zones[k];
         if(origin==2) evidence.departure=true;
         if(origin>0 && SDReaction(evidence,r[bar]))
         {
            if(origin==1) { zones[k].structural=true; zones[k].departure=false; }
            else if(!zones[k].structural) zones[k].departure=true;
            if(zones[k].reactions==0) { zones[k].reactions=1; zones[k].last_reaction=bar; zones[k].pending=false; }
            if(zones[k].confirmed_bar<0) zones[k].confirmed_bar=bar;
         }
         return; // Same overlapping seed never creates another reaction episode.
      }
   }
   SDCandidate z;
   z.source=source; z.confirmed_bar=-1; z.direction=direction; z.last_reaction=bar;
   z.pending_since=bar; z.reactions=0; z.touches=0; z.top=top; z.bottom=bottom;
   z.atr=atr; z.penetration=0; z.visited=false; z.valid=true; z.armed=false; z.pending=true;
   z.structural=origin==1; z.departure=origin==2; z.reversal=reversal;
   if(SDReaction(z,r[bar]))
   { z.reactions=1; if(origin>0) z.confirmed_bar=bar; z.pending=false; }
   int n=ArraySize(zones),target=-1;
   for(int k=0;k<n;k++) if(!zones[k].valid) { target=k; break; }
   if(target<0)
   {
      if(n>=128)
      {
         // Retain established reaction zones ahead of old unconfirmed candidates.
         int oldest=-1;
         for(int k=0;k<n;k++) if(zones[k].confirmed_bar<0 &&
            (oldest<0 || zones[k].last_reaction<zones[oldest].last_reaction)) oldest=k;
         if(oldest<0)
         {
            if(origin==0) return; // An unconfirmed pivot cannot displace an established zone.
            double lowest=0;
            for(int k=0;k<n;k++)
            {
               double away=MathMax(0.0,zones[k].direction==1?r[bar].close-zones[k].top:zones[k].bottom-r[bar].close)/zones[k].atr;
               double score=(zones[k].structural?2.0:zones[k].departure?1.5:0.0)+0.75*MathMin(4,zones[k].reactions)-
                  0.8*zones[k].penetration-0.5*(bar-zones[k].last_reaction)/InpSDMaxAgeBars-0.2*MathMin(10.0,away);
               if(oldest<0 || score<lowest) { oldest=k; lowest=score; }
            }
         }
         target=oldest;
      }
      else { target=n; ArrayResize(zones,n+1); }
   }
   zones[target]=z;
}
void StepSDCandidate(SDCandidate &z,const MqlRates &r[],int bar)
{
   if(!z.valid) return;
   MqlRates c=r[bar];
   if(bar-z.last_reaction>InpSDMaxAgeBars) { z.valid=false; return; }
   bool overlap=c.low<=z.top && c.high>=z.bottom;
   bool invalid=z.direction==1?c.close<z.bottom:c.close>z.top;
   if(z.reactions>0 && InpMTFZoneMitigation==MITIGATION_WICK && overlap) invalid=true;
   if(invalid) { z.valid=false; return; }
   if(z.reactions>0 && overlap)
   {
      z.visited=true; // Tested status is independent of the gap used to count separate reactions.
      if(InpOnlyFreshMTFZones) { z.valid=false; return; }
   }
   if(z.armed && overlap && bar-z.last_reaction>=InpSDMinReactionGap)
   {
      z.touches++; z.pending=true; z.pending_since=bar; z.armed=false;
      if(InpOnlyFreshMTFZones) { z.valid=false; return; }
   }
   if(z.pending)
   {
      if(overlap)
      {
         double depth=z.direction==1?(z.top-c.low)/(z.top-z.bottom):(c.high-z.bottom)/(z.top-z.bottom);
         z.penetration=MathMax(z.penetration,MathMin(1.0,MathMax(0.0,depth)));
      }
      if(bar-z.pending_since>InpSDReactionWait)
      {
         z.pending=false;
         if(z.reactions==0) z.valid=false;
      }
      else if(SDReaction(z,c))
      {
         z.reactions++; z.last_reaction=bar;
         if(z.confirmed_bar<0 && z.reactions>=((z.structural || z.departure)?1:InpSDMinReactions)) z.confirmed_bar=bar;
         z.pending=false;
         return; // A reaction candle never rearms its own episode.
      }
   }
   if(!z.pending && z.reactions>0)
   {
      bool away=z.direction==1?c.low>z.top+InpSDRearmATR*z.atr:c.high<z.bottom-InpSDRearmATR*z.atr;
      if(away && bar-z.last_reaction>=InpSDMinReactionGap) z.armed=true;
   }
}
bool SDStructureBase(const MqlRates &r[],const double &atr[],const StructureBreak &br,
                     int &base,double &top,double &bottom,double &value)
{
   int source=-1;
   for(int k=br.to-1;k>=MathMax(0,br.to-InpOBSearchBars);k--)
      if(br.direction==1?r[k].close<r[k].open:r[k].close>r[k].open) { source=k; break; }
   if(source<0 || atr[source]<=0) return false;
   value=atr[source]; top=r[source].high; bottom=r[source].low; base=source;
   if(top-bottom>InpBaseMaxCandleATR*value) return false;
   for(int k=source-1;k>=MathMax(0,source-InpBaseMaxBars+1);k--)
   {
      double nt=MathMax(top,r[k].high),nb=MathMin(bottom,r[k].low);
      if(r[k].high-r[k].low>InpBaseMaxCandleATR*value || nt-nb>InpBaseMaxWidthATR*value ||
         r[k].high<bottom || r[k].low>top) break;
      top=nt; bottom=nb; base=k;
   }
   if(top-bottom>InpBaseMaxWidthATR*value) return false;
   for(int k=source+1;k<=br.to;k++)
      if(br.direction==1?r[k].close<bottom:r[k].close>top) return false;
   return (br.direction==1?r[br.to].close-top:bottom-r[br.to].close)>=InpZoneDepartureATR*value;
}
void BuildSupplyDemand(const MqlRates &r[],const StructureBreak &events[],ENUM_TIMEFRAMES tf,int slot)
{
   int count=ArraySize(r),strength=InpSDPivotStrength;
   if(count<2*strength+10) return;
   double atr[]; BuildZoneATRCache(r,atr);
   SDCandidate zones[];
   int first=MathMax(2*strength,count-InpSDLookbackBars),event=0;
   while(event<ArraySize(events) && events[event].to<first) event++;
   for(int bar=first;bar<count;bar++)
   {
      for(int k=0;k<ArraySize(zones);k++) StepSDCandidate(zones[k],r,bar);
      while(event<ArraySize(events) && events[event].to==bar)
      {
         StructureBreak br=events[event++]; int base=0; double top=0,bottom=0,value=0;
         if(SDStructureBase(r,atr,br,base,top,bottom,value))
            AddSDCandidate(zones,r,base,bar,br.direction,top,bottom,value,true,br.reversal);
      }
      if(InpSDDepartureZones)
      {
         int base=0; double top=0,bottom=0,value=0;
         int direction=r[bar].close>r[bar].open?1:r[bar].close<r[bar].open?-1:0;
         if(direction!=0 && SDDepartureBase(r,atr,bar,direction,base,top,bottom,value))
            AddSDCandidate(zones,r,base,bar,direction,top,bottom,value,2,false);
      }
      if(!InpSDRepeatedReactions) continue;
      int pivot=bar-strength;
      if(atr[pivot]<=0 || r[pivot].high-r[pivot].low>InpSDMaxSeedATR*atr[pivot]) continue;
      for(int direction=-1;direction<=1;direction+=2)
      {
         if(!(direction==1?PivotLow(r,pivot,strength):PivotHigh(r,pivot,strength))) continue;
         double top=direction==1?MathMin(r[pivot].open,r[pivot].close):r[pivot].high;
         double bottom=direction==1?r[pivot].low:MathMax(r[pivot].open,r[pivot].close);
         double minimum=MathMax(2*_Point,0.05*atr[pivot]);
         if(top-bottom<minimum) { if(direction==1) top=bottom+minimum; else bottom=top-minimum; }
         bool held=true;
         for(int j=pivot+1;j<=bar;j++)
            if(direction==1?r[j].close<bottom:r[j].close>top) { held=false; break; }
         if(held)
         {
            int origin=0;
            if(InpSDDepartureZones)
            {
               int first=MathMax(0,pivot-3);
               double hurdle=direction==1?r[Highest(r,first,bar-1)].high:r[Lowest(r,first,bar-1)].low;
               double distance=direction==1?r[bar].close-top:bottom-r[bar].close;
               bool local_break=direction==1?r[bar].close>hurdle:r[bar].close<hurdle;
               if(local_break && distance>=InpSDDepartureATR*atr[pivot] &&
                  direction*(r[bar].close-r[bar].open)>=InpSDDepartureBodyATR*atr[pivot] &&
                  r[bar].high-r[bar].low<=InpSDDepartureMaxCandleATR*atr[pivot]) origin=2;
            }
            AddSDCandidate(zones,r,pivot,bar,direction,top,bottom,atr[pivot],origin,false);
         }
      }
   }
   for(int k=0;k<ArraySize(zones);k++)
   {
      SDCandidate z=zones[k];
      if(!z.valid || z.reactions<((z.structural || z.departure)?1:InpSDMinReactions) || z.confirmed_bar<0) continue;
      datetime confirmed=z.confirmed_bar+1<count?r[z.confirmed_bar+1].time:iTime(_Symbol,tf,0);
      if(confirmed<=r[z.confirmed_bar].time) continue;
      int n=ArraySize(mtf_zones);
      SaveMTFZone(tf,slot,1,z.direction,r[z.source].time,confirmed,z.top,z.bottom,z.visited,z.reversal);
      if(ArraySize(mtf_zones)==n) continue;
      mtf_zones[n].reactions=z.reactions; mtf_zones[n].touches=z.touches; mtf_zones[n].repeated=!z.structural && !z.departure; mtf_zones[n].departure=z.departure;
      double distance=MathMax(0.0,z.direction==1?r[count-1].close-z.top:z.bottom-r[count-1].close)/z.atr;
      int failed=MathMax(0,z.touches-MathMax(0,z.reactions-1));
      mtf_zones[n].quality=(z.structural?2.0:z.departure?1.5:0.0)+0.75*MathMin(4,z.reactions)+(!z.visited?0.5:0.0)-
         0.8*z.penetration-0.5*failed-0.5*(count-1-z.last_reaction)/InpSDMaxAgeBars-0.1*MathMin(10.0,distance);
   }
}

bool OBDepartureOK(const MqlRates &r[],int source,int bar,int direction,double top,double bottom)
{
   double atr=ZoneATR(r,source);
   if(atr<=0) return InpOBMinDepartureATR==0 && InpOBMaxWidthATR==0;
   if(InpOBMaxWidthATR>0 && top-bottom>InpOBMaxWidthATR*atr) return false;
   return (direction==1?r[bar].close-top:bottom-r[bar].close)>=InpOBMinDepartureATR*atr;
}
// Compact base immediately before an objectively strong closed departure.
bool SDDepartureBase(const MqlRates &r[],const double &atr[],int bar,int direction,
                     int &base,double &top,double &bottom,double &value)
{
   if(bar<2) return false;
   int end=bar-1; value=atr[end];
   if(value<=0 || direction*(r[bar].close-r[bar].open)<InpSDDepartureBodyATR*value ||
      r[bar].high-r[bar].low>InpSDDepartureMaxCandleATR*value) return false;
   double span=r[end].high-r[end].low;
   if(span<=0 || span>InpBaseMaxCandleATR*value ||
      (MathAbs(r[end].close-r[end].open)>0.5*span && span>0.8*value)) return false;
   base=end; top=r[end].high; bottom=r[end].low;
   for(int k=end-1;k>=MathMax(0,end-InpBaseMaxBars+1);k--)
   {
      double width=r[k].high-r[k].low,nt=MathMax(top,r[k].high),nb=MathMin(bottom,r[k].low);
      if(width<=0 || width>InpBaseMaxCandleATR*value || nt-nb>InpBaseMaxWidthATR*value ||
         r[k].high<bottom || r[k].low>top ||
         (MathAbs(r[k].close-r[k].open)>0.5*width && width>0.8*value)) break;
      top=nt; bottom=nb; base=k;
   }
   if(top-bottom>MathMin(InpSDMaxWidthATR,InpBaseMaxWidthATR)*value) return false;
   // Depart BOTH the selected base and recent prices, avoiding continuation noise inside a range.
   int reference=MathMax(0,base-3);
   double hurdle=direction==1?r[Highest(r,reference,end)].high:r[Lowest(r,reference,end)].low;
   double close=r[bar].close;
   return (direction==1?close-top:bottom-close)>=InpSDDepartureATR*value &&
      (direction==1?close>hurdle:close<hurdle);
}
int NearestZone(int index)
{
   if(!InpZoneNearestFirst) return -1;
   MTFZone z=mtf_zones[index]; double quote=zone_quote[z.slot];
   if(quote<=0) return -1;
   int best=-1; double distance=0;
   for(int k=0;k<ArraySize(mtf_zones);k++)
   {
      MTFZone other=mtf_zones[k];
      if(other.slot!=z.slot || other.kind!=z.kind || other.direction!=z.direction) continue;
      if(other.direction==1?other.bottom>quote:other.top<quote) continue;
      double d=MathMax(0.0,other.direction==1?quote-other.top:other.bottom-quote);
      if(best<0 || d<distance || (d==distance && other.confirmed>mtf_zones[best].confirmed))
      { best=k; distance=d; }
   }
   return best;
}
int OBPriorityRank(const OrderBlock &blocks[],int index,int direction)
{
   int nearest=-1,rank=0; double distance=0,quote=zone_quote[0];
   if(InpZoneNearestFirst && quote>0)
   for(int k=0;k<ArraySize(blocks);k++)
   {
      if(!blocks[k].active || (direction==1?blocks[k].bottom>quote:blocks[k].top<quote)) continue;
      double d=MathMax(0.0,direction==1?quote-blocks[k].top:blocks[k].bottom-quote);
      if(nearest<0 || d<distance || (d==distance && blocks[k].confirmed_time>blocks[nearest].confirmed_time))
      { nearest=k; distance=d; }
   }
   if(index==nearest) return 0;
   if(nearest>=0) rank=1;
   for(int k=0;k<ArraySize(blocks);k++)
      if(k!=index && k!=nearest && blocks[k].active &&
         (blocks[k].confirmed_time>blocks[index].confirmed_time ||
          (blocks[k].confirmed_time==blocks[index].confirmed_time && k>index))) rank++;
   return rank;
}

void RefreshZoneQuotes()
{
   // Called by the one-second refresh only; region detection stays on closed bars.
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid<=0) return;
   bool changed=false;
   for(int k=0;k<7;k++) { if(zone_quote[k]!=bid) changed=true; zone_quote[k]=bid; }
   if(changed) { UpdateOBPriorities(); view_dirty=true; }
}
void UpdateOBPriorities()
{
   for(int k=0;k<ArraySize(BullOBs);k++) BullOBs[k].priority=OBPriorityRank(BullOBs,k,1);
   for(int k=0;k<ArraySize(BearOBs);k++) BearOBs[k].priority=OBPriorityRank(BearOBs,k,-1);
}
int ZoneRank(int index)
{
   MTFZone z=mtf_zones[index]; int rank=0,nearest=NearestZone(index);
   if(index==nearest) return 0;
   if(nearest>=0) rank=1;
   for(int k=0;k<ArraySize(mtf_zones);k++)
   {
      MTFZone other=mtf_zones[k];
      if(k==index || k==nearest || other.slot!=z.slot || other.kind!=z.kind || other.direction!=z.direction) continue;
      bool better=z.kind==1?(other.quality>z.quality || (other.quality==z.quality && other.confirmed>z.confirmed)):
                           other.confirmed>z.confirmed;
      if(better || (other.quality==z.quality && other.confirmed==z.confirmed && k>index)) rank++;
   }
   return rank;
}
string ZoneConfluence(int index)
{
   MTFZone z=mtf_zones[index]; string result="";
   ENUM_TIMEFRAMES used[];
   for(int k=0;k<ArraySize(mtf_zones);k++)
   {
      MTFZone other=mtf_zones[k];
      if(k==index || other.kind!=1 || other.direction!=z.direction || other.tf==z.tf) continue;
      double overlap=MathMin(z.top,other.top)-MathMax(z.bottom,other.bottom);
      if(overlap<=0) continue;
      bool seen=false;
      for(int j=0;j<ArraySize(used);j++) if(used[j]==other.tf) seen=true;
      if(seen) continue;
      int n=ArraySize(used); ArrayResize(used,n+1); used[n]=other.tf;
      result+=(result==""?"":",")+TimeframeLabel(other.tf);
   }
   return result==""?"none":result;
}

void BuildMTFZones(const MqlRates &r[],const StructureBreak &events[],ENUM_TIMEFRAMES tf,int slot)
{
   ClearZoneSlot(slot);
   if(!UniqueZoneSlot(tf,slot)) return;
   int count=ArraySize(r);
   if(count>0) { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); zone_quote[slot]=bid>0?bid:r[count-1].close; }
   if(slot>0 && slot<4 && ui_obmtf && InpMaxMTFOBPerSide>0)
   {
      datetime used_bull[],used_bear[];
      for(int e=0;e<ArraySize(events);e++)
      {
         StructureBreak br=events[e];
         int source=-1,first=MathMax(0,br.to-InpOBSearchBars);
         for(int k=br.to-1;k>=first;k--)
            if(br.direction==1?r[k].close<r[k].open:r[k].close>r[k].open) { source=k; break; }
         if(source<0) continue;
         double top=r[source].high,bottom=r[source].low;
         if(br.direction==1?r[br.to].close<=top:r[br.to].close>=bottom) continue;
      if(!OBDepartureOK(r,source,br.to,br.direction,top,bottom)) continue;
         bool valid=true;
         for(int k=source+1;k<=br.to;k++)
            if(br.direction==1?r[k].close<bottom:r[k].close>top) { valid=false; break; }
         if(!valid) continue;
         bool seen=br.direction==1?RememberZoneSource(used_bull,r[source].time):RememberZoneSource(used_bear,r[source].time);
         datetime confirmed=br.to+1<count?r[br.to+1].time:iTime(_Symbol,tf,0);
         bool tested=false;
         if(!seen && confirmed>r[br.to].time && ZoneStillValid(r,br.to,top,bottom,br.direction,tested))
            SaveMTFZone(tf,slot,0,br.direction,r[source].time,confirmed,top,bottom,tested,br.reversal);
      }
   }
   if(ui_sd && (InpSDAutoTimeframes?IsSDTimeframe(tf):(slot>0 || InpSupplyDemandCurrent)) && InpMaxSDPerSide>0)
      BuildSupplyDemand(r,events,tf,slot);
   LimitZoneSlot(slot);
}
bool RememberZoneSource(datetime &used[],datetime source)
{
   for(int k=0;k<ArraySize(used);k++) if(used[k]==source) return true;
   int n=ArraySize(used); ArrayResize(used,n+1); used[n]=source;
   return false;
}
void LimitZoneSlot(int slot)
{
   bool remove[]; ArrayResize(remove,ArraySize(mtf_zones)); ArrayInitialize(remove,false);
   for(int k=0;k<ArraySize(mtf_zones);k++)
      if(mtf_zones[k].slot==slot && ZoneRank(k)>=10) remove[k]=true;
   int write=0;
   for(int k=0;k<ArraySize(mtf_zones);k++) if(!remove[k]) mtf_zones[write++]=mtf_zones[k];
   ArrayResize(mtf_zones,write);
}
void DrawMTFZones()
{
   if(!ui_all || (!ui_obmtf && !ui_sd)) { ObjectsDeleteAll(0,instance_prefix+"ZONE_"); return; }
   datetime end=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   if(end<=0) return;
   end+=PeriodSeconds((ENUM_TIMEFRAMES)_Period)*3;
   for(int k=ArraySize(mtf_zones)-1;k>=0;k--)
   {
      MTFZone z=mtf_zones[k];
      string name=instance_prefix+"ZONE_"+IntegerToString(z.slot)+"_"+IntegerToString(z.kind)+"_"+
         IntegerToString(z.direction)+"_"+IntegerToString((long)z.source);
      int cap=ui_history?10:(z.kind==0?InpMaxMTFOBPerSide:InpMaxSDPerSide);
      bool visible=(z.kind==0?ui_obmtf:ui_sd) && ZoneRank(k)<cap;
      if(!visible)
      {
         ObjectDelete(0,name); ObjectDelete(0,name+"_t"); ObjectDelete(0,name+"_fill");
         continue;
      }
      color c=z.kind==0?(z.direction==1?InpColorOB_TextBull:InpColorOB_TextBear):
                       (z.direction==1?InpDemandColor:InpSupplyColor);
      datetime finish=end;
      if(finish<=z.source) finish=z.source+PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(ObjectFind(0,name)<0)
         ObjectCreate(0,name,OBJ_RECTANGLE,0,z.source,z.top,finish,z.bottom);
      else { ObjectMove(0,name,0,z.source,z.top); ObjectMove(0,name,1,finish,z.bottom); }
      StyleObject(name,c);
      color background=z.direction==1?InpColorOB_Bull:InpColorOB_Bear;
      DrawZoneBorder(name,z.source,finish,z.top,z.bottom,z.tf,z.kind,background,z.kind==1 && InpFillSupplyDemand && z.tf==(ENUM_TIMEFRAMES)_Period);
      string tag=TimeframeLabel(z.tf)+" "+(z.kind==0?(z.direction==1?"OB↑":"OB↓"):(z.direction==1?"CẦU":"CUNG"));
      string text=tag+(z.tested?" *":"");
      CenterZoneText(name+"_t",z.source,finish,z.top,z.bottom,text,c,6);
      string info=tag+" | "+(z.kind==1?(z.repeated?"REACTION ZONE":z.departure?"DEPARTURE ORIGIN":"STRUCTURE BASE"):(z.reversal?"CHOCH":"BOS"))+
         " | "+(z.tested?"TESTED":"FRESH")+" | Source: "+TimeToString(z.source)+" | Confirmed: "+TimeToString(z.confirmed);
      if(z.kind==1) info+=" | Reactions: "+IntegerToString(z.reactions)+" | Revisits: "+IntegerToString(z.touches)+
         " | Priority: "+DoubleToString(z.quality,2)+" | TF overlap: "+ZoneConfluence(k)+
         " | Repeated tests do not guarantee a stronger zone";
      ObjectSetString(0,name,OBJPROP_TOOLTIP,info);
      ObjectSetString(0,name+"_t",OBJPROP_TOOLTIP,info);
   }
}

// Idempotent cleanup runs before the refresh cache/throttle, so OFF never
// depends on new market data being available.
void ApplyVisibility()
{
   if(!ui_all) { ClearFeatureObjects(); return; }
   if(!ui_sd) ObjectDelete(0,instance_prefix+"SD_STATUS");
   if(!ui_ob) ObjectsDeleteAll(0,instance_prefix+"OB_");
   if(!ui_fibo) ObjectDelete(0,instance_prefix+"FIBO");
   if(!ui_mtf) ObjectsDeleteAll(0,instance_prefix+"MTF_");
   string prefix=instance_prefix+"STRUCT_";
   if(!ui_structure)
   {
      ObjectsDeleteAll(0,prefix+"B_");
      ObjectsDeleteAll(0,prefix+"PROTECTED");
      ObjectsDeleteAll(0,prefix+"TARGET");
      ObjectDelete(0,prefix+"ORIGIN"); ObjectDelete(0,prefix+"EXTREME");
   }
   if(!ui_sweeps) ObjectsDeleteAll(0,prefix+"SW_");
   // Remove one MTF zone type independently without relying on a successful replay.
   if(!ui_obmtf || !ui_sd)
   for(int k=ObjectsTotal(0)-1;k>=0;k--)
   {
      string name=ObjectName(0,k);
      string zone_prefix=instance_prefix+"ZONE_";
      if(StringFind(name,zone_prefix)!=0) continue;
      string fields[];
      int parts=StringSplit(StringSubstr(name,StringLen(zone_prefix)),'_',fields);
      if(parts<2) continue;
      if((fields[1]=="0" && !ui_obmtf) || (fields[1]=="1" && !ui_sd)) ObjectDelete(0,name);
   }
}

void ResetRenderSnapshots()
{
   for(int k=0;k<2;k++)
   {
      render_cache[k].valid=false;
      ArrayFree(render_cache[k].rates); ArrayFree(render_cache[k].events);
      ArrayFree(render_cache[k].sweeps);
   }
}
void SaveRenderSnapshot(int slot,const MqlRates &r[],const StructureBreak &events[],
                        const LiquiditySweep &sweeps[],ENUM_TIMEFRAMES tf,int trend,
                        int origin,int extreme,int hi,int lo,double origin_price,bool ready)
{
   if(slot!=0 && slot!=4) return;
   int k=slot==0?0:1;
   ArrayResize(render_cache[k].rates,ArraySize(r)); ArrayResize(render_cache[k].events,ArraySize(events));
   ArrayResize(render_cache[k].sweeps,ArraySize(sweeps));
   ArrayCopy(render_cache[k].rates,r); ArrayCopy(render_cache[k].events,events);
   ArrayCopy(render_cache[k].sweeps,sweeps);
   render_cache[k].tf=tf; render_cache[k].trend=trend; render_cache[k].origin=origin;
   render_cache[k].extreme=extreme; render_cache[k].hi=hi; render_cache[k].lo=lo;
   render_cache[k].origin_price=origin_price; render_cache[k].ready=ready;
   render_cache[k].valid=true;
}
void RenderPayload(const MqlRates &r[],const StructureBreak &events[],
                    const LiquiditySweep &sweeps[],ENUM_TIMEFRAMES tf,
                    int trend,int origin,int extreme,int hi,int lo,double origin_price,
                    bool ready,bool draw,bool fibo,bool reset,const string section="ALL")
{
   int count=ArraySize(r);
   if(count<1) return;
   string tag=TimeframeLabel(tf);
   bool paint_structure=section=="ALL" || section=="STR" || section=="HIST";
   bool paint_sweeps=section=="ALL" || section=="STR" || section=="HIST";
   if(fibo)
   {
      if(trend!=0) DrawFibo(r,origin,extreme,origin_price,trend==1?r[extreme].high:r[extreme].low);
      else ObjectDelete(0,instance_prefix+"FIBO");
   }
   if(draw)
   {
      string prefix=instance_prefix+"STRUCT_";
      // Replay happens only once per closed bar; bound visuals to retained events.
      if(reset) ObjectsDeleteAll(0,prefix);
      for(int k=ui_history?0:MathMax(0,ArraySize(events)-InpRecentStructures); paint_structure && ui_structure && k<ArraySize(events);k++)
      {
         StructureBreak e=events[k];
         string name=prefix+"B_"+IntegerToString(k);
         color c=e.direction==1?InpStructureBull:InpStructureBear;
         Line(name,r[e.from].time,e.price,r[e.to].time,e.price,c,STYLE_DASH);
         CenterZoneText(name+"_t",r[e.from].time,r[e.to].time,e.price,e.price,tag+" "+(e.reversal?"CHOCH":"BOS")+(e.direction==1?"↑":"↓"),c,6);
      }
      for(int k=ui_history?0:MathMax(0,ArraySize(sweeps)-InpRecentStructures); paint_sweeps && ui_sweeps && k<ArraySize(sweeps);k++)
      {
         LiquiditySweep sw=sweeps[k];
         string name=prefix+"SW_"+IntegerToString(k);
         Line(name,r[sw.source].time,sw.level,r[sw.bar].time,sw.level,InpSweepColor,STYLE_DOT);
         CenterZoneText(name+"_t",r[sw.source].time,r[sw.bar].time,sw.level,sw.level,
                sw.direction==1?"SWEEP H":"SWEEP L",InpSweepColor,6);
      }
      if(trend!=0)
      {
         if(paint_structure && ui_structure)
         {
         double level=trend==1?r[lo].low:r[hi].high;
         datetime level_time=trend==1?r[lo].time:r[hi].time;
         color c=trend==1?InpStructureBull:InpStructureBear;
         Line(prefix+"PROTECTED",level_time,level,r[count-1].time+PeriodSeconds(tf),level,c);
         TextAt(prefix+"PROTECTED_t",r[count-1].time,level,trend==1?"Protected low":"Protected high",c);
         TextAt(prefix+"ORIGIN",r[origin].time,origin_price,trend==1?"L / HL":"H / LH",c);
         TextAt(prefix+"EXTREME",r[extreme].time,trend==1?r[extreme].high:r[extreme].low,(trend==1?"H":"L")+(ready?" confirmed":" developing"),c);
         if(ready)
         {
            int target=trend==1?hi:lo;
            double price=trend==1?r[hi].high:r[lo].low;
            Line(prefix+"TARGET",r[target].time,price,r[count-1].time+PeriodSeconds(tf),price,c,STYLE_DOT);
         }
      }
      }
   }
}
void RenderSnapshotView(const RenderSnapshot &snapshot,bool draw,bool fibo,const string section="ALL")
{
   if(!snapshot.valid) return;
   RenderPayload(snapshot.rates,snapshot.events,snapshot.sweeps,
      snapshot.tf,snapshot.trend,snapshot.origin,snapshot.extreme,snapshot.hi,snapshot.lo,
      snapshot.origin_price,snapshot.ready,draw,fibo,false,section);
}
void RenderCachedView(const string key="ALL")
{
   ApplyVisibility(); visibility_dirty=false;
   if(!ui_all) { view_dirty=true; return; }
   ENUM_TIMEFRAMES chart_tf=(ENUM_TIMEFRAMES)_Period;
   ENUM_TIMEFRAMES ft=ZoneTimeframe(InpFiboTF);
   bool draw=key=="ALL" || key=="STR" || key=="HIST";
   bool fibo=key=="ALL" || key=="FIB";
   if(draw || fibo) RenderSnapshotView(render_cache[0],draw && (ui_structure || ui_sweeps),fibo && ui_fibo && ft==chart_tf,key);
   if(fibo && ui_fibo && ft!=chart_tf) RenderSnapshotView(render_cache[1],false,true,key);
   if((key=="ALL" || key=="MTF") && ui_mtf)
      for(int k=0;k<4;k++) Panel(instance_prefix+"MTF_"+IntegerToString(k),k,structure_status[k],clrSilver);
   if(key=="ALL" || key=="OBMTF" || key=="HIST") RedrawOBNow();
   if(key=="ALL" || key=="OBMTF" || key=="SD" || key=="HIST") DrawMTFZones();
   DrawSDStatus();
   view_dirty=true;
}
void UpdateLiveEdges()
{
   if(!ui_all) return;
   datetime current=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   if(!view_dirty && current==last_edge_time) return;
   last_edge_time=current;
   RedrawOBNow();
   DrawMTFZones();
   DrawSDStatus();
   view_dirty=true;
}

void CenterZoneText(const string name,datetime left,datetime right,double top,double bottom,
                    const string text,color c,int font_size=6)
{
   datetime middle=left+(right-left)/2;
   double price=(top+bottom)*0.5;
   TextAt(name,middle,price,text,c);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
}



int SDTimeframeSlot(ENUM_TIMEFRAMES tf)
{
   if(tf==(ENUM_TIMEFRAMES)_Period) return 0;
   if(tf==ZoneTimeframe(InpTF1)) return 1;
   if(tf==ZoneTimeframe(InpTF2)) return 2;
   if(tf==ZoneTimeframe(InpTF3)) return 3;
   if(tf==SDHigherTimeframe(0)) return 5;
   if(tf==SDHigherTimeframe(1)) return 6;
   return -1;
}
void DrawSDStatus()
{
   string name=instance_prefix+"SD_STATUS";
   if(!ui_all || !ui_sd || !InpShowSDStatus) { ObjectDelete(0,name); return; }
   ENUM_TIMEFRAMES frames[];
   if(InpSDAutoTimeframes)
   {
      ArrayResize(frames,1); frames[0]=(ENUM_TIMEFRAMES)_Period;
      for(int k=0;k<2;k++) { ENUM_TIMEFRAMES tf=SDHigherTimeframe(k); if(tf!=PERIOD_CURRENT) { int n=ArraySize(frames); ArrayResize(frames,n+1); frames[n]=tf; } }
   }
   else
   {
      ENUM_TIMEFRAMES configured[]={(ENUM_TIMEFRAMES)_Period,ZoneTimeframe(InpTF1),ZoneTimeframe(InpTF2),ZoneTimeframe(InpTF3)};
      for(int k=0;k<4;k++)
      {
         if(k==0 && !InpSupplyDemandCurrent) continue;
         bool seen=false; for(int j=0;j<ArraySize(frames);j++) if(frames[j]==configured[k]) seen=true;
         if(!seen) { int n=ArraySize(frames); ArrayResize(frames,n+1); frames[n]=configured[k]; }
      }
   }
   string text="S/D "; bool loading=false;
   for(int j=0;j<ArraySize(frames);j++)
   {
      int slot=SDTimeframeSlot(frames[j]),supply=0,demand=0;
      string item=TimeframeLabel(frames[j])+" ";
      if(slot<0 || zone_load_state[slot]!=2)
      { item+="LOAD "+IntegerToString(slot<0?0:zone_load_count[slot])+"/"+IntegerToString(MathMax(2*InpPivotStrength+10,2*InpSDPivotStrength+10)); loading=true; }
      else
      {
         for(int k=0;k<ArraySize(mtf_zones);k++)
            if(mtf_zones[k].tf==frames[j] && mtf_zones[k].kind==1 && ZoneRank(k)<(ui_history?10:InpMaxSDPerSide))
            { if(mtf_zones[k].direction==1) demand++; else supply++; }
         item+="S"+IntegerToString(supply)+"/D"+IntegerToString(demand);
      }
      text+=(j==0?"":" | ")+item;
   }
   string old=ObjectFind(0,name)>=0?ObjectGetString(0,name,OBJPROP_TEXT):"";
   Panel(name,ui_mtf?4:0,text,loading?clrGold:clrSilver);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"LOAD: khung chua du nen dong, tu thu tai lai. S0/D0: da tai du lieu nhung chua co vung hop le. Vung da pha, qua cu, qua rong hoac dep nhung chua xac nhan se khong ve.");
   if(old!=text) view_dirty=true;
}
