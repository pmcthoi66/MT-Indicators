// Exact signal-rule port of the Pine v5 C7CB source supplied as an image.
// Candle 1 = shift 2; candle 2 = shift 1; candle 3 = signal candle.
// Candle 0 (shift 3) is declared in Pine but unused by its signal rules.
// Deliberately preserve asymmetric high/low comparisons from the source.
#property strict
#property version "1.73"
#property indicator_chart_window
#property indicator_buffers 28
#property indicator_plots 10
#property indicator_label1 "C7cb_up"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrLimeGreen
#property indicator_width1 1
#property indicator_label2 "C7cb_down"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_width2 1

#property indicator_label3 "Confirmed Buy"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrLimeGreen
#property indicator_width3 1
#property indicator_label4 "Confirmed Sell"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrOrangeRed
#property indicator_width4 1

#property indicator_label5 "Signal 1 HH Buy"
#property indicator_type5 DRAW_ARROW
#property indicator_color5 clrAqua
#property indicator_width5 1
#property indicator_label6 "Signal 1 LL Sell"
#property indicator_type6 DRAW_ARROW
#property indicator_color6 clrMagenta
#property indicator_width6 1
#property indicator_label7 "Signal 2 HL Buy"
#property indicator_type7 DRAW_ARROW
#property indicator_color7 clrAqua
#property indicator_width7 1
#property indicator_label8 "Signal 2 LH Sell"
#property indicator_type8 DRAW_ARROW
#property indicator_color8 clrMagenta
#property indicator_width8 1
#property indicator_label9 "Wick Retest Buy"
#property indicator_type9 DRAW_ARROW
#property indicator_color9 clrDodgerBlue
#property indicator_width9 1
#property indicator_label10 "Wick Retest Sell"
#property indicator_type10 DRAW_ARROW
#property indicator_color10 clrOrange
#property indicator_width10 1
input bool InpShowEntryContext=true; // Đọc bối cảnh; không thay đổi tín hiệu gốc
input int InpContextKeep=1; // Chú thích 1..10 entry gần nhất, gộp cùng nến/cùng hướng
input int InpContextTrendBars=40; // Cửa sổ cấu trúc, chỉ dùng nến trước entry
input int InpContextSwingStrength=2; // Pivot phải có đủ nến xác nhận trước entry
input int InpContextLegBars=5; // So N nến ngay trước với N nến trước đó
input double InpContextWeakeningRatio=0.75; // Lực thân ngược giảm ít nhất 25%
input bool InpMTF_M15=true; // OFF: không đọc/tính M15
input bool InpMTF_H1=true; // OFF: không đọc/tính H1
input bool InpMTF_H4=true; // OFF: không đọc/tính H4
input bool InpMTF_D1=true; // OFF: không đọc/tính D1
input bool InpMTFZones=true; // Vùng cung/cầu trên các TF đang bật
input bool InpMTFKeyLevels=true; // Đỉnh/đáy pivot đã xác nhận + H/L nến TF vừa đóng
input int InpMTFLookback=150; // 30..250 nến mỗi TF
input int InpContextFollowBars=3; // Chỉ theo dõi nến đóng sau entry; độc lập xác nhận tín hiệu gốc
input int InpContextFontSize=7;
input bool InpContextHoverOnly=true; // Chỉ hiện dấu ⓘ; rê chuột để đọc bối cảnh
input bool InpCompactContext=true; // Một câu ngắn ngay cạnh entry, không dùng bảng
input double InpContextFarZoneATR=1.0; // Từ khoảng cách này ghi "xa vùng"
input bool InpUseSupplyDemandContext=true;
input bool InpUseKeyLevelContext=true;
input bool InpDrawContextLevels=true; // Chỉ vẽ vùng/mốc của entry mới nhất, tối đa 6 object
input int InpZoneLookback=150; // Tìm vùng trên khung chart, tối đa 250 nến trước entry
input double InpZoneDepartureATR=1.0; // Rời vùng pivot >= 1 ATR để công nhận vùng
input double InpZoneNearATR=0.25; // Khoảng cách tối đa để coi entry gần vùng/mốc
input double InpZoneInvalidATR=0.05; // Đóng xuyên biên xa thêm 0.05 ATR: vùng hết hiệu lực

input bool InpWickEarlyReaction=true; // Bao tai nen dong phan ung sau retest, khong doi pha ca cum
input bool InpGroupArrowsByRegion=false; // Mot bao dau + mot HL/LH cho moi vung, tick CB giu rieng
input double InpRegionDepartureATR=1.0; // Gia phai roi vung it nhat 1 ATR de mo chu ky moi
input double InpRegionNewExtremeATR=0.5; // Dinh/day moi cach vung cu it nhat 0.5 ATR
input bool InpWickOnRetestAllowed=true; // Rau tu choi o nen dau HOAC nen thu lai
input bool InpUseWickRetest=false; // Mac dinh tat nhom bo loc bo sung; chi dung bo loc C7CB goc
input bool InpWickRetestVolumeFilter=true; // Volume nen pha >= 0.8 EMA20 theo he so chung
input int InpWickRetestMaxBars=5; // Cum toi da 5 nen, toi thieu 3
input int InpWickExtremeLookback=3; // Nen rau tai cuc tri cua N nen truoc
input double InpWickMinRatio=0.35; // Rau tu choi >= 35% bien do nen
input double InpWickRetestTolerance=0.35; // Vung thu lai = 35% bien do nen rau
input double InpWickMaxSweep=0.25; // Cho phep quet qua cuc tri toi da 25% bien do
input bool InpUseStars=true; // Morning/Evening Star, high-volume signal candle
input bool InpUseEngulfing=true; // Body engulfing, high-volume signal candle
input double InpPatternHighVolumeFactor=1.0; // >=1.0 * SMA20 volume (includes signal candle)
input double InpStarSmallBodyFactor=0.5; // Middle body <= 50% of first body
input double InpStarPenetration=0.5; // Third close crosses 50% of first body
input bool InpUseC7CB=true; // Bat/tat rieng logic C7CB
input bool InpUseStructure12=false; // Mac dinh tat nhom bo loc bo sung; chi dung bo loc C7CB goc
input int InpStructureAnchorLookback=10; // Diem 1: cuc tri so voi N nen truoc
input int InpStructureATRPeriod=14;
input double InpStructureMinMoveATR=0.80; // Nhip bat/hoi toi thieu tu diem 1
input int InpStructureSwingBars=1; // 1: xac nhan diem 2 bang nen dong ke tiep
input int InpStructureMaxWait=20; // So nen toi da tu diem 1 den diem 2
input bool InpStructureVolumeEMAFilter=true; // Bo mui ten HL/LH neu volume nen xac nhan duoi nguong EMA20
input bool InpStructureVolumeFilter=false; // Volume hoi yeu va phuc hoi: tuy chon
input bool InpDebugSummary=false; // Full history diagnostics only when requested
input bool InpDebugNewBars=false; // Tam bat de kiem tra moi nen dong; tat sau khi chan doan
input bool InpEnabled=true; // OFF: hide drawings and stop signal calculations
input bool InpShowHistory=true; // false: only the newest five signal marks
input bool InpFilterLowVolumeDoji=true; // Loai CB khi vua than nho/doji vua volume thap
input double InpDojiMaxBodyRatio=0.25; // Than <= 25% bien do nen: nen than nho/doji
input bool InpRejectConsecutiveDojis=true; // Bo tin hieu neu nen truoc va nen tin hieu deu la doji
input double InpOriginalVolumeMinRisePercent=0.0; // Muc tang toi thieu cho nhanh volume tang dan
input int InpVolumeAveragePeriod=20; // SMA volume cua N nen truoc, khong gom nen CB
input bool InpUseRealVolume=false; // true: real volume; fallback tick neu thieu du lieu
input bool InpUseCBVolumeEMAFilter=false; // Bo loc EMA rieng tuy chon; volume 3 nen co dieu kien rieng
input double InpVolumeEMAThresholdFactor=0.80; // Nguong volume = he so * EMA; 1.0 chat, 0.8 noi
input int InpCBVolumeEMAPeriod=20; // EMA20 volume, khong phai EMA gia
input double InpThreeBarHighVolumeFactor=1.0; // Neu volume khong tang: ca 3 nen >= he so * EMA20
input bool InpUseWideLowVolumeEntry=true; // Them mau 3 bien do tang dan, volume nen 3 thap nhat
input double InpWideLowVolumeWickBodyFactor=1.0; // Rau tu choi nen 3 phai dai hon than theo he so
input bool InpFilterEarlyTicks=false; // false: giu tick som, khong chan bang cum volume
input bool InpUseVolumeCluster=true; // Loc CB bang cum gia/volume suy yeu
input bool InpStrictVolumeFilter=false; // false: loc nhe; true: dieu kien chat v1.30
input int InpVolumeClusterBars=5; // Cum 3..5 nen, gom nen CB
input double InpMinVolumeDecline=0.05; // Do giam fitted / volume trung binh >= 5%
input bool InpConfirmVolumeRecovery=true; // Xac nhan can volume phuc hoi va nen dung huong
input double InpRecoveryVolumeFactor=1.0; // Volume xac nhan >= TB cum CB * he so
input bool InpEnableConfirmation=true;
input int InpConfirmationBars=3; // Maximum number of subsequent candles
input bool InpInvalidateOnOppositeClose=true;
input bool InpEnableConfirmationAlerts=true;
input bool InpEnablePush=false;
input bool InpClosedBarsOnly=false; // false matches Pine live-bar behavior
input int InpArrowOffsetPixels=12;
input color InpUpColor=clrLimeGreen;
input color InpDownColor=C'255,0,4';
double DisplayUp[],DisplayDown[],DisplayBuy[],DisplaySell[],DisplayStructBuy[],DisplayStructSell[];
double WickBuy[],WickSell[],DisplayWickBuy[],DisplayWickSell[];
int GroupProcessed=-1;
int RegionFirst[2],RegionSecond[2];
double RegionPrice[2],RegionScale[2];
bool RegionDeparted[2];
int WickProcessed=-1,LastWickBuy=-1,LastWickSell=-1;
double RetestBuy[],RetestSell[],DisplayRetestBuy[],DisplayRetestSell[];
double StructBuy[],StructSell[],StructureATR[],TickVolumeEMA[],RealVolumeEMA[];
int StructProcessed=-1;
double SwingHigh=0,SwingLow=0;
int SwingHighIndex=-1,SwingLowIndex=-1,LastBrokenHigh=-1,LastBrokenLow=-1;
int BuySetup=-1,SellSetup=-1,BuyBase=-1,SellBase=-1;
double BuyProtected=0,SellProtected=0;
bool BuyPeak=false,SellTrough=false;
double Up[],Down[],ConfirmedBuy[],ConfirmedSell[];
double StrongWideWick[];
int ShownIndex[5],ShownType[5],ShownCount=0;
datetime FirstTime=0;
double PendingDirection[],PendingHigh[],PendingLow[],PendingIndex[];
datetime LastClosed=0;
string Prefix;
int ContextBars[],ContextTypes[],ContextCount=0;
string ContextNames[10],ContextTexts[10],ContextTips[10];
datetime ContextTimes[10];
double ContextPrices[10];
int ContextDirections[10];
bool ContextLive[10];
string ContextBaseTips[10];
datetime ContextStatusStamp[10];

// Cache only completed broker-calendar periods; invalidated on chart rebuild.
datetime KeyCacheStart[12],KeyCacheEnd[12];
double KeyCacheHigh[12],KeyCacheLow[12];
bool KeyCacheKnown[12];
int KeyCacheNext=0;
bool LevelCreated[6];
datetime LevelStart[6],LevelEnd[6];
double LevelLow[6],LevelHigh[6];
struct EntryMarketContext
{
   bool demand,supply;
   double demandLow,demandHigh,supplyLow,supplyHigh;
   int demandBar,supplyBar,demandTouches,supplyTouches;
   double keys[4]; bool keyKnown[4];
   datetime keyStart[4],keyEnd[4];
};

// Cache tối đa 10 entry x 4 TF, không có indicator handle/buffer bổ sung.
struct MTFContextCache
{
   bool ready;
   datetime lastClosed;
   int count;
   double lo[250],hi[250],scale[250];
   int side[250]; // 1=cầu, -1=cung
   bool hasPH,hasPL;
   double ph,pl,lastHigh,lastLow;
};
MTFContextCache MTFCache[40];
void ResetMTFContextCache()
{
   for(int k=0;k<40;k++) { MTFCache[k].ready=false;MTFCache[k].lastClosed=0;MTFCache[k].count=0; }
}

void ResetEntryContextCache()
{
   ResetMTFContextCache();
   KeyCacheNext=0;
   for(int k=0;k<12;k++) { KeyCacheStart[k]=0; KeyCacheEnd[k]=0; KeyCacheKnown[k]=false; }
   for(int k=0;k<6;k++) { LevelCreated[k]=false; LevelStart[k]=0; LevelEnd[k]=0; LevelLow[k]=0; LevelHigh[k]=0; }
   ContextCount=0; ArrayFree(ContextBars); ArrayFree(ContextTypes);
   for(int k=0;k<10;k++)
   {
      ContextNames[k]=""; ContextTexts[k]=""; ContextTips[k]="";
      ContextBaseTips[k]=""; ContextStatusStamp[k]=0;
      ContextTimes[k]=0; ContextPrices[k]=0; ContextDirections[k]=0; ContextLive[k]=false;
   }
}
// Sparse indexes: ordered by bar, then type. No recurring history scan.
int RecentBars[],RecentTypes[],StrongBars[];
int RecentCount=0,StrongCount=0;
string StrongNames[5];
datetime StrongTimes[5];
double StrongPrices[5];
int StrongDirections[5];
bool StrongSlotValid[5];

void ResetDisplayCache()
{
   ResetEntryContextCache();
   RecentCount=0; StrongCount=0;
   ArrayFree(RecentBars); ArrayFree(RecentTypes); ArrayFree(StrongBars);
   for(int k=0;k<5;k++)
   {
      StrongNames[k]=""; StrongTimes[k]=0; StrongPrices[k]=0;
      StrongDirections[k]=0; StrongSlotValid[k]=false;
   }
}
bool AppendIndex(int &data[],const int pos,const int value)
{
   if(ArraySize(data)<=pos && ArrayResize(data,pos+1,1024)<=pos)
      return false;
   data[pos]=value;
   return true;
}
double MarkValue(const int i,const int type)
{
   switch(type)
   {
      case 0:return Up[i]; case 1:return Down[i];
      case 2:return ConfirmedBuy[i]; case 3:return ConfirmedSell[i];
      case 4:return StructBuy[i]; case 5:return StructSell[i];
      case 6:return RetestBuy[i]; case 7:return RetestSell[i];
      case 8:return WickBuy[i]; case 9:return WickSell[i];
   }
   return EMPTY_VALUE;
}
bool MarkEnabled(const int type)
{
   if(type<=3) return InpUseC7CB;
   if(type<=7) return InpUseStructure12;
   return InpUseWickRetest;
}
void TrimDisplayCache(const int start)
{
   while(RecentCount>0 && RecentBars[RecentCount-1]>=start) RecentCount--;
   while(StrongCount>0 && StrongBars[StrongCount-1]>=start) StrongCount--;
   while(ContextCount>0 && ContextBars[ContextCount-1]>=start) ContextCount--;
}
bool IndexDisplayBar(const int i)
{
   if(InpShowEntryContext)
      for(int type=0;type<10;type++)
         if(MarkEnabled(type) && MarkValue(i,type)!=EMPTY_VALUE)
         {
            if(!AppendIndex(ContextBars,ContextCount,i) ||
               !AppendIndex(ContextTypes,ContextCount,type)) return false;
            ContextCount++;
         }
   if(!InpShowHistory)
      for(int type=0;type<10;type++)
         if(MarkEnabled(type) && MarkValue(i,type)!=EMPTY_VALUE)
         {
            if(!AppendIndex(RecentBars,RecentCount,i) ||
               !AppendIndex(RecentTypes,RecentCount,type)) return false;
            RecentCount++;
         }
   if(StrongWideWick[i]!=EMPTY_VALUE && (Up[i]!=EMPTY_VALUE || Down[i]!=EMPTY_VALUE))
   {
      if(!AppendIndex(StrongBars,StrongCount,i)) return false;
      StrongCount++;
   }
   return true;
}

int OnInit()
{
   if(!MathIsValidNumber(InpContextFarZoneATR) || InpContextFarZoneATR<=InpZoneNearATR)
      return INIT_PARAMETERS_INCORRECT;
   if(InpZoneLookback<20 || InpZoneLookback>250 || !MathIsValidNumber(InpZoneDepartureATR) ||
      InpZoneDepartureATR<=0 || !MathIsValidNumber(InpZoneNearATR) || InpZoneNearATR<=0 ||
      !MathIsValidNumber(InpZoneInvalidATR) || InpZoneInvalidATR<0)
      return INIT_PARAMETERS_INCORRECT;
   if(InpMTFLookback<30 || InpMTFLookback>250 || InpContextFollowBars<1 || InpContextFollowBars>10 || InpContextKeep<1 || InpContextKeep>10 || InpContextTrendBars<12 || InpContextTrendBars>200 ||
      InpContextSwingStrength<1 || InpContextSwingStrength>5 ||
      InpContextTrendBars<2*InpContextSwingStrength+5 ||
      InpContextLegBars<2 || InpContextLegBars>10 || !MathIsValidNumber(InpContextWeakeningRatio) || InpContextWeakeningRatio<=0 ||
      InpContextWeakeningRatio>=1 || InpContextFontSize<6 || InpContextFontSize>14)
      return INIT_PARAMETERS_INCORRECT;
   if(InpPatternHighVolumeFactor<1.0 || InpStarSmallBodyFactor<=0.0 ||
      InpStarSmallBodyFactor>0.5 || InpStarPenetration<0.5 || InpStarPenetration>1.0)
      return INIT_PARAMETERS_INCORRECT;
   if(InpArrowOffsetPixels<0 || InpConfirmationBars<1 || InpVolumeAveragePeriod<1 ||
      InpDojiMaxBodyRatio<0.0 || InpDojiMaxBodyRatio>1.0 || InpVolumeClusterBars<3 || InpVolumeClusterBars>5 ||
      InpMinVolumeDecline<0.0 || InpRecoveryVolumeFactor<=0.0 || InpStructureSwingBars<1 || InpStructureSwingBars>10 ||
      InpStructureMaxWait<2 || InpStructureAnchorLookback<2 ||
      InpStructureATRPeriod<2 || InpStructureMinMoveATR<=0.0 ||
      InpRegionDepartureATR<=0 || InpRegionNewExtremeATR<=0 || InpWickRetestMaxBars<3 || InpWickRetestMaxBars>20 || InpWickExtremeLookback<1 ||
      InpWickMinRatio<=0 || InpWickMinRatio>=1 || InpWickRetestTolerance<0 || InpWickMaxSweep<0 ||
      InpCBVolumeEMAPeriod<1 || InpVolumeEMAThresholdFactor<=0.0 || InpThreeBarHighVolumeFactor<=0.0 ||
      InpWideLowVolumeWickBodyFactor<=0.0 ||
      InpOriginalVolumeMinRisePercent<0.0) return INIT_PARAMETERS_INCORRECT;
   SetIndexBuffer(0,DisplayUp,INDICATOR_DATA);
   SetIndexBuffer(1,DisplayDown,INDICATOR_DATA);
   SetIndexBuffer(2,DisplayBuy,INDICATOR_DATA);
   SetIndexBuffer(3,DisplaySell,INDICATOR_DATA);
   SetIndexBuffer(14,Up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(15,Down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(16,ConfirmedBuy,INDICATOR_CALCULATIONS);
   SetIndexBuffer(17,ConfirmedSell,INDICATOR_CALCULATIONS);
   SetIndexBuffer(10,PendingDirection,INDICATOR_CALCULATIONS);
   SetIndexBuffer(11,PendingHigh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(12,PendingLow,INDICATOR_CALCULATIONS);
   SetIndexBuffer(13,PendingIndex,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,DisplayStructBuy,INDICATOR_DATA);
   SetIndexBuffer(5,DisplayStructSell,INDICATOR_DATA);
   SetIndexBuffer(18,StructBuy,INDICATOR_CALCULATIONS);
   SetIndexBuffer(19,StructSell,INDICATOR_CALCULATIONS);
   SetIndexBuffer(20,StructureATR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(21,TickVolumeEMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(22,RealVolumeEMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,DisplayRetestBuy,INDICATOR_DATA);
   SetIndexBuffer(7,DisplayRetestSell,INDICATOR_DATA);
   SetIndexBuffer(23,RetestBuy,INDICATOR_CALCULATIONS);
   SetIndexBuffer(24,RetestSell,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,DisplayWickBuy,INDICATOR_DATA); SetIndexBuffer(9,DisplayWickSell,INDICATOR_DATA);
   SetIndexBuffer(25,WickBuy,INDICATOR_CALCULATIONS); SetIndexBuffer(26,WickSell,INDICATOR_CALCULATIONS);
   SetIndexBuffer(27,StrongWideWick,INDICATOR_CALCULATIONS);
   ArraySetAsSeries(Up,false); ArraySetAsSeries(Down,false);
   for(int p=0;p<10;p++)
   {
      PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
      PlotIndexSetInteger(p,PLOT_DRAW_BEGIN,2);
   }
   PlotIndexSetInteger(0,PLOT_ARROW,252); // Wingdings check mark
   PlotIndexSetInteger(1,PLOT_ARROW,252);
   PlotIndexSetInteger(0,PLOT_ARROW_SHIFT,InpArrowOffsetPixels);
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,-InpArrowOffsetPixels);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,InpUpColor);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,InpDownColor);
   PlotIndexSetInteger(2,PLOT_ARROW,233);
   PlotIndexSetInteger(3,PLOT_ARROW,234);
   PlotIndexSetInteger(2,PLOT_ARROW_SHIFT,InpArrowOffsetPixels+16);
   PlotIndexSetInteger(3,PLOT_ARROW_SHIFT,-InpArrowOffsetPixels-16);
   PlotIndexSetInteger(4,PLOT_ARROW,233); PlotIndexSetInteger(5,PLOT_ARROW,234);
   PlotIndexSetInteger(4,PLOT_ARROW_SHIFT,InpArrowOffsetPixels+30);
   PlotIndexSetInteger(5,PLOT_ARROW_SHIFT,-InpArrowOffsetPixels-30);
   PlotIndexSetInteger(6,PLOT_ARROW,241); PlotIndexSetInteger(7,PLOT_ARROW,242);
   PlotIndexSetInteger(6,PLOT_ARROW_SHIFT,InpArrowOffsetPixels+30);
   PlotIndexSetInteger(7,PLOT_ARROW_SHIFT,-InpArrowOffsetPixels-30);
   PlotIndexSetInteger(8,PLOT_ARROW,233); PlotIndexSetInteger(9,PLOT_ARROW,234);
   PlotIndexSetInteger(8,PLOT_ARROW_SHIFT,InpArrowOffsetPixels+44);
   PlotIndexSetInteger(9,PLOT_ARROW_SHIFT,-InpArrowOffsetPixels-44);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"C7CB v1.73 Original Filter");
   Prefix="C7CB_"+IntegerToString((long)GetMicrosecondCount())+"_";
   LastClosed=0; FirstTime=0; ShownCount=0;
   ResetDisplayCache();
   // Keep the original C7CB marks visible; added modules are shown only when enabled.
   if(!InpUseStructure12)
      for(int p=4;p<8;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
   if(!InpUseWickRetest)
      for(int p=8;p<10;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
   if(!InpEnabled)
      for(int p=0;p<10;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   // Guard against failed initialization: an empty prefix would delete unrelated objects.
   if(Prefix!="")
   {
      ResetLastError();
      ObjectsDeleteAll(0,Prefix,0,-1);
      int error=GetLastError();
      if(error!=0) PrintFormat("C7CB cleanup error %d",error);
   }
   ResetDisplayCache();
   ResetStructure();
   LastClosed=0; FirstTime=0; ShownCount=0; Prefix="";
   // Bound indicator buffers belong to the MT5 runtime; do not ArrayFree them.
   ChartRedraw(0);
}
void PutMark(const int i,const int type,const double value)
{
   if(type==0) DisplayUp[i]=value;
   else if(type==1) DisplayDown[i]=value;
   else if(type==2) DisplayBuy[i]=value;
   else if(type==3) DisplaySell[i]=value;
   else if(type==4) DisplayStructBuy[i]=value; else if(type==5) DisplayStructSell[i]=value;
   else if(type==6) DisplayRetestBuy[i]=value; else if(type==7) DisplayRetestSell[i]=value;
   else if(type==8) DisplayWickBuy[i]=value; else DisplayWickSell[i]=value;
}
void RefreshRecent(const int count,const datetime &time[],const double &low[],const double &high[])
{
   for(int k=0;k<ShownCount;k++)
      if(ShownIndex[k]>=0 && ShownIndex[k]<count)
         PutMark(ShownIndex[k],ShownType[k],EMPTY_VALUE);
   ShownCount=0;
   for(int p=RecentCount-1;p>=0 && ShownCount<5;p--)
   {
      int i=RecentBars[p],type=RecentTypes[p];
      if(i<2 || i>=count) continue;
      double value=MarkValue(i,type);
      if(value==EMPTY_VALUE) continue;
      PutMark(i,type,value);
      ShownIndex[ShownCount]=i; ShownType[ShownCount]=type; ShownCount++;
   }
}
// A bounded five-slot object pool: retain unchanged objects, move changed ones.
void RefreshStrongWideWickMarks(const int count,const datetime &time[],const double &low[],const double &high[])
{
   if(Prefix=="") return;
   for(int slot=0;slot<5;slot++)
   {
      int p=StrongCount-1-slot;
      string name=Prefix+"3W_SLOT_"+IntegerToString(slot);
      if(p<0)
      {
         if(StrongNames[slot]!="")
         {
            if(ObjectDelete(0,StrongNames[slot]))
            { StrongNames[slot]=""; StrongSlotValid[slot]=false; }
         }
         continue;
      }
      int i=StrongBars[p];
      if(i<2 || i>=count) continue;
      bool buy=Up[i]!=EMPTY_VALUE;
      int direction=buy?1:-1;
      double range=MathMax(high[i]-low[i],10.0*_Point);
      double price=buy?low[i]-0.30*range:high[i]+0.30*range;
      bool fresh=StrongNames[slot]=="";
      bool ok=true;
      if(fresh)
      {
         ResetLastError();
         if(!ObjectCreate(0,name,OBJ_TEXT,0,time[i],price))
         { PrintFormat("C7CB create mark error %d",GetLastError()); continue; }
         StrongNames[slot]=name;
         if(!ObjectSetString(0,name,OBJPROP_TEXT,"3 RÂU")) ok=false;
         if(!ObjectSetString(0,name,OBJPROP_TOOLTIP,"Cả 3 nến đều có râu dài cùng hướng")) ok=false;
         if(!ObjectSetString(0,name,OBJPROP_FONT,"Arial")) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_COLOR,clrGold)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_HIDDEN,true)) ok=false;
         if(!ok)
         {
            PrintFormat("C7CB configure mark error %d",GetLastError());
            ObjectDelete(0,name); StrongNames[slot]=""; StrongSlotValid[slot]=false;
            continue;
         }
      }
      if(fresh || !StrongSlotValid[slot] || StrongTimes[slot]!=time[i] || StrongPrices[slot]!=price)
         if(!ObjectMove(0,name,0,time[i],price)) ok=false;
      if(fresh || !StrongSlotValid[slot] || StrongDirections[slot]!=direction)
         if(!ObjectSetInteger(0,name,OBJPROP_ANCHOR,buy?ANCHOR_UPPER:ANCHOR_LOWER)) ok=false;
      if(ok)
      {
         StrongTimes[slot]=time[i]; StrongPrices[slot]=price;
         StrongDirections[slot]=direction; StrongSlotValid[slot]=true;
      }
      else StrongSlotValid[slot]=false;
   }
}

// Context never changes the signal buffers. Every measurement is causal.
// Pivot confirmation stops at i-1. Momentum excludes the entry candle.
int ContextTrend(const int i,const double &high[],const double &low[])
{
   int strength=InpContextSwingStrength;
   int first=MathMax(strength,i-InpContextTrendBars);
   double h1=0,h2=0,l1=0,l2=0; int nh=0,nl=0;
   for(int j=i-1-strength;j>=first && (nh<2 || nl<2);j--)
   {
      bool ph=true,pl=true;
      for(int k=1;k<=strength;k++)
      {
         if(high[j]<=high[j-k] || high[j]<high[j+k]) ph=false;
         if(low[j]>=low[j-k] || low[j]>low[j+k]) pl=false;
      }
      if(ph && pl) continue; // Outside pivots do not define two directions at once.
      if(ph && nh<2) { if(nh==0) h1=high[j]; else h2=high[j]; nh++; }
      if(pl && nl<2) { if(nl==0) l1=low[j]; else l2=low[j]; nl++; }
   }
   if(nh<2 || nl<2) return 0;
   if(h1>h2 && l1>l2) return 1;
   if(h1<h2 && l1<l2) return -1;
   return 0;
}
double ContextATR(const int i,const double &high[],const double &low[],const double &close[])
{
   if(i<15) return 0;
   double sum=0;
   for(int k=i-14;k<i;k++)
      sum+=MathMax(high[k]-low[k],MathMax(MathAbs(high[k]-close[k-1]),MathAbs(low[k]-close[k-1])));
   return sum/14.0; // Simple average of 14 prior true ranges; no new ATR handle/buffer.
}

datetime ContextDayStart(const datetime stamp)
{
   MqlDateTime dt={};
   if(!TimeToStruct(stamp,dt)) return 0;
   dt.hour=0; dt.min=0; dt.sec=0;
   return StructToTime(dt);
}
datetime ContextWeekStart(const datetime stamp)
{
   MqlDateTime dt={};
   if(!TimeToStruct(stamp,dt)) return 0;
   return ContextDayStart(stamp)-(datetime)(((dt.day_of_week+6)%7)*86400);
}
int ContextTimeLowerBound(const datetime &time[],const int end,const datetime target)
{
   int lo=0,hi=end;
   while(lo<hi) { int mid=(lo+hi)/2; if(time[mid]<target) lo=mid+1; else hi=mid; }
   return lo;
}
bool ContextPeriodRange(const datetime from,const datetime until,const int entry,
                        const datetime &time[],const double &high[],const double &low[],
                        double &periodHigh,double &periodLow)
{
   if(entry<=0 || from<=0 || until<=from || time[0]>from || time[entry]<until) return false;
   // Larger-than-D1 bars cannot reconstruct broker day/week extremes accurately.
   if(PeriodSeconds(_Period)>86400) return false;
   for(int k=0;k<12;k++)
      if(KeyCacheStart[k]==from && KeyCacheEnd[k]==until)
      { periodHigh=KeyCacheHigh[k]; periodLow=KeyCacheLow[k]; return KeyCacheKnown[k]; }
   int first=ContextTimeLowerBound(time,entry,from);
   int last=ContextTimeLowerBound(time,entry,until);
   bool known=first<last;
   periodHigh=0;periodLow=0;
   if(known)
   {
      periodHigh=high[first];periodLow=low[first];
      for(int k=first+1;k<last;k++) { periodHigh=MathMax(periodHigh,high[k]); periodLow=MathMin(periodLow,low[k]); }
   }
   int slot=KeyCacheNext;KeyCacheNext=(KeyCacheNext+1)%12;
   KeyCacheStart[slot]=from;KeyCacheEnd[slot]=until;
   KeyCacheHigh[slot]=periodHigh;KeyCacheLow[slot]=periodLow;KeyCacheKnown[slot]=known;
   return known;
}
void FindEntryKeyLevels(const int i,const datetime &time[],const double &high[],const double &low[],
                        EntryMarketContext &market)
{
   datetime today=ContextDayStart(time[i]);
   int prior=ContextTimeLowerBound(time,i,today)-1;
   // Previous available broker trading day: Friday is used when Monday follows a weekend.
   if(prior>=0)
   {
      datetime day=ContextDayStart(time[prior]);double ph=0,pl=0;
      bool known=ContextPeriodRange(day,day+86400,i,time,high,low,ph,pl);
      market.keys[0]=ph;market.keys[1]=pl;
      market.keyKnown[0]=market.keyKnown[1]=known;
      market.keyStart[0]=market.keyStart[1]=day;
      market.keyEnd[0]=market.keyEnd[1]=day+86400;
   }
   datetime week=ContextWeekStart(time[i]),priorWeek=week-7*86400;
   double wh=0,wl=0;
   bool known=ContextPeriodRange(priorWeek,week,i,time,high,low,wh,wl);
   market.keys[2]=wh;market.keys[3]=wl;
   market.keyKnown[2]=market.keyKnown[3]=known;
   market.keyStart[2]=market.keyStart[3]=priorWeek;
   market.keyEnd[2]=market.keyEnd[3]=week;
}
double EntryBandDistance(const double lo,const double hi,const double candleLow,const double candleHigh)
{
   if(candleHigh<lo) return lo-candleHigh;
   if(candleLow>hi) return candleLow-hi;
   return 0;
}
void FindEntryZones(const int i,const double &open[],const double &high[],const double &low[],
                    const double &close[],const double atr,EntryMarketContext &market)
{
   int strength=InpContextSwingStrength;
   int first=MathMax(15,i-InpZoneLookback),length=i-first;
   if(length<=strength) return;
   // Suffix extrema make close-invalidation checks O(1) per zone, not a nested history scan.
   double suffixMin[251],suffixMax[251];
   suffixMin[length]=EMPTY_VALUE;suffixMax[length]=-EMPTY_VALUE;
   for(int k=i-1;k>=first;k--)
   { suffixMin[k-first]=MathMin(close[k],suffixMin[k-first+1]); suffixMax[k-first]=MathMax(close[k],suffixMax[k-first+1]); }
   double bestDemand=EMPTY_VALUE,bestSupply=EMPTY_VALUE;
   for(int p=i-1-strength;p>=MathMax(first,strength);p--)
   {
      bool ph=true,pl=true;
      for(int k=1;k<=strength;k++)
      {
         if(high[p]<=high[p-k] || high[p]<high[p+k]) ph=false;
         if(low[p]>=low[p-k] || low[p]>low[p+k]) pl=false;
      }
      if(ph==pl) continue;
      double scale=ContextATR(p,high,low,close);
      if(scale<=0) continue;
      int born=p+strength;
      double gap=InpZoneInvalidATR*scale;
      if(pl)
      {
         double distal=low[p],proximal=MathMax(open[p],close[p]);
         if(proximal<=distal || close[born]-proximal<InpZoneDepartureATR*scale ||
            suffixMin[born+1-first]<distal-gap || close[i]<distal-gap) continue;
         double distance=EntryBandDistance(distal,proximal,close[i],close[i]);
         if(distance<bestDemand)
         { bestDemand=distance;market.demand=true;market.demandLow=distal;market.demandHigh=proximal;market.demandBar=p; }
      }
      if(ph)
      {
         double distal=high[p],proximal=MathMin(open[p],close[p]);
         if(distal<=proximal || proximal-close[born]<InpZoneDepartureATR*scale ||
            suffixMax[born+1-first]>distal+gap || close[i]>distal+gap) continue;
         double distance=EntryBandDistance(proximal,distal,close[i],close[i]);
         if(distance<bestSupply)
         { bestSupply=distance;market.supply=true;market.supplyLow=proximal;market.supplyHigh=distal;market.supplyBar=p; }
      }
   }
   // Count retest bars only for the two selected zones, after their confirmation.
   if(market.demand)
      for(int k=market.demandBar+strength+1;k<i;k++)
         if(low[k]<=market.demandHigh && high[k]>=market.demandLow) market.demandTouches++;
   if(market.supply)
      for(int k=market.supplyBar+strength+1;k<i;k++)
         if(high[k]>=market.supplyLow && low[k]<=market.supplyHigh) market.supplyTouches++;
}
string ContextLevelName(const int slot)
{
   if(slot==0) return "DEMAND";if(slot==1) return "SUPPLY";
   if(slot==2) return "PDH";if(slot==3) return "PDL";if(slot==4) return "PWH";return "PWL";
}
void ClearContextLevelDrawings()
{
   for(int k=0;k<6;k++)
      if(LevelCreated[k] && ObjectDelete(0,Prefix+"CONTEXT_LEVEL_"+ContextLevelName(k))) LevelCreated[k]=false;
}
void RenderContextLevels(const int i,const datetime &time[],const EntryMarketContext &market)
{
   if(!InpDrawContextLevels) return;
   int seconds=PeriodSeconds(_Period);if(seconds<=0) seconds=60;
   datetime until=time[i]+(datetime)(5*seconds);
   for(int slot=0;slot<6;slot++)
   {
      bool valid=slot==0 ? market.demand : slot==1 ? market.supply : market.keyKnown[slot-2];
      string name=Prefix+"CONTEXT_LEVEL_"+ContextLevelName(slot);
      if(!valid)
      {
         if(LevelCreated[slot] && ObjectDelete(0,name)) LevelCreated[slot]=false;
         continue;
      }
      datetime from=slot==0?time[market.demandBar]:slot==1?time[market.supplyBar]:market.keyEnd[slot-2];
      double lo=slot==0?market.demandLow:slot==1?market.supplyLow:market.keys[slot-2];
      double hi=slot==0?market.demandHigh:slot==1?market.supplyHigh:lo;
      bool fresh=!LevelCreated[slot],ok=true;
      if(fresh)
      {
         if(!ObjectCreate(0,name,slot<2?OBJ_RECTANGLE:OBJ_TREND,0,from,hi,until,lo)) continue;
         LevelCreated[slot]=true;
         if(!ObjectSetInteger(0,name,OBJPROP_COLOR,slot==0?clrSeaGreen:slot==1?clrIndianRed:clrSlateGray)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_BACK,true)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_HIDDEN,true)) ok=false;
         if(slot<2) { if(!ObjectSetInteger(0,name,OBJPROP_FILL,false)) ok=false; }
         else
         {
            if(!ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false)) ok=false;
            if(!ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false)) ok=false;
            if(!ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT)) ok=false;
         }
      }
      if(fresh || LevelStart[slot]!=from || LevelEnd[slot]!=until || LevelLow[slot]!=lo || LevelHigh[slot]!=hi)
      {
         if(!ObjectMove(0,name,0,from,hi) || !ObjectMove(0,name,1,until,lo)) ok=false;
         if(!ObjectSetString(0,name,OBJPROP_TOOLTIP,ContextLevelName(slot)+" | "+DoubleToString(lo,_Digits)+
                            (slot<2?" – "+DoubleToString(hi,_Digits):"")+" | Bối cảnh entry "+TimeToString(time[i],TIME_DATE|TIME_MINUTES))) ok=false;
      }
      if(ok) { LevelStart[slot]=from;LevelEnd[slot]=until;LevelLow[slot]=lo;LevelHigh[slot]=hi; }
      else { ObjectDelete(0,name);LevelCreated[slot]=false; }
   }
}

string DescribeEntryZone(const bool exists,const bool support,const bool demand,
                         const double lo,const double hi,const double entryClose,
                         const double atr,const int touches)
{
   string role=support?"HỖ TRỢ ":"CẢN ";role+=demand?"CẦU":"CUNG";
   if(!exists) return role+": chưa thấy vùng hợp lệ trong "+IntegerToString(InpZoneLookback)+" nến";
   string band=DoubleToString(lo,_Digits)+"–"+DoubleToString(hi,_Digits);
   double distance=EntryBandDistance(lo,hi,entryClose,entryClose);
   string location=entryClose>=lo && entryClose<=hi ? "ENTRY TRONG VÙNG" :
                   "cách entry "+DoubleToString(distance,_Digits)+" giá / "+DoubleToString(distance/atr,2)+" ATR";
   if((demand && entryClose<lo) || (!demand && entryClose>hi))
      location="đang xuyên biên nhẹ, chưa giữ/vượt dứt khoát";
   else if(distance>0 && distance<=InpZoneNearATR*atr) location+=" (GẦN)";
   return role+" "+band+" | "+location+" | chạm "+IntegerToString(touches)+" nến";
}

string CompactZonePosition(const bool exists,const bool demand,const double lo,const double hi,
                           const double entryClose,const double atr)
{
   string zone=demand?"cầu":"cung";
   if(!exists) return "chưa rõ "+zone;
   if(entryClose>=lo && entryClose<=hi) return "trong "+zone;
   double distance=EntryBandDistance(lo,hi,entryClose,entryClose)/atr;
   if((demand && entryClose<lo) || (!demand && entryClose>hi)) return "xuyên nhẹ "+zone;
   if(distance<=InpZoneNearATR) return "sát "+zone;
   if(distance>=InpContextFarZoneATR) return "xa "+zone;
   return (entryClose>hi?"trên ":"dưới ")+zone;
}
string CompactEntryDescription(const int i,const int direction,const bool live,
                               const double &open[],const double &high[],const double &low[],const double &close[],
                               const long &tick_volume[],const long &volume[],const bool real,
                               const double atr,const EntryMarketContext &market)
{
   int red=0,green=0,lower=0,upper=0;
   double bodySum=0,rangeSum=0,nowVolume=0,beforeVolume=0;
   bool known=true;
   for(int k=i-6;k<i;k++)
   {
      double v=(double)(real?volume[k]:tick_volume[k]);
      if(v<=0) known=false;
      if(k<i-3) { beforeVolume+=v;continue; }
      nowVolume+=v;
      if(close[k]<open[k]) red++;else if(close[k]>open[k]) green++;
      double body=MathAbs(close[k]-open[k]),range=high[k]-low[k];
      bodySum+=body;rangeSum+=range;
      double down=MathMin(open[k],close[k])-low[k],up=high[k]-MathMax(open[k],close[k]);
      if(range>0 && down>=body && down/range>=0.35) lower++;
      if(range>0 && up>=body && up/range>=0.35) upper++;
   }
   string tone=red==3?"3 đỏ":green==3?"3 xanh":red>green?"đa số đỏ":green>red?"đa số xanh":"đan xen/doji";
   double bodyRatio=rangeSum>0?bodySum/rangeSum:0;
   string shape=bodyRatio<=0.35?"thân ngắn":bodyRatio>=0.60?"thân dài":"thân vừa";
   string wick="";
   if(lower>upper) wick=lower>=2?", râu dưới dài":", có râu dưới dài";
   else if(upper>lower) wick=upper>=2?", râu trên dài":", có râu trên dài";
   else if(lower>0) wick=", râu trên/dưới dài";
   string vol="vol chưa rõ";
   if(known && beforeVolume>0)
   {
      double change=100.0*(nowVolume/beforeVolume-1.0),size=MathAbs(change);
      if(size<=5.0) vol="vol ngang";
      else vol=(change>0?"vol tăng":"vol giảm")+(size<=20.0?" nhẹ":size>50.0?" mạnh":"");
   }
   string zones="";
   if(InpUseSupplyDemandContext)
      zones=" | "+CompactZonePosition(market.demand,true,market.demandLow,market.demandHigh,close[i],atr)+", "+
                 CompactZonePosition(market.supply,false,market.supplyLow,market.supplyHigh,close[i],atr);
   string side=direction>0?"BUY":"SELL";
   return side+" | "+tone+" "+shape+wick+"; "+vol+zones+(live?" (LIVE)":"");
}
// MTF: mọi nến nguồn phải kết thúc không muộn hơn thời điểm entry đóng.
// Lưu ứng viên vùng một lần mỗi nến TF đóng; chọn vùng gần entry theo giá chart.
bool MTFEnabled(const int tf)
{
   if(tf==0) return InpMTF_M15;
   if(tf==1) return InpMTF_H1;
   if(tf==2) return InpMTF_H4;
   return InpMTF_D1;
}
ENUM_TIMEFRAMES MTFPeriod(const int tf)
{
   if(tf==0) return PERIOD_M15;
   if(tf==1) return PERIOD_H1;
   if(tf==2) return PERIOD_H4;
   return PERIOD_D1;
}
string MTFName(const int tf)
{
   if(tf==0) return "M15";
   if(tf==1) return "H1";
   if(tf==2) return "H4";
   return "D1";
}
double MTFAtr(const int p,const MqlRates &r[])
{
   if(p<15) return 0;
   double sum=0;
   for(int j=p-14;j<p;j++)
      sum+=MathMax(r[j].high-r[j].low,MathMax(MathAbs(r[j].high-r[j-1].close),MathAbs(r[j].low-r[j-1].close)));
   return sum/14.0;
}
bool LoadMTFContext(const int cache,const ENUM_TIMEFRAMES tf,const datetime cutoff)
{
   int seconds=PeriodSeconds(tf);
   int shift=iBarShift(_Symbol,tf,cutoff-1,false);
   if(shift<0 || seconds<=0) return false;
   datetime opened=iTime(_Symbol,tf,shift);
   if(opened<=0) return false;
   if(opened+seconds>cutoff) shift++;
   // shift 0 là nến đang chạy tại hiện tại, tuyệt đối không dùng OHLC hoàn chỉnh của nó.
   if(shift<1) shift=1;
   datetime last=iTime(_Symbol,tf,shift);
   if(last<=0 || last+seconds>cutoff) return false;
   if(MTFCache[cache].ready && MTFCache[cache].lastClosed==last) return true;
   MTFCache[cache].ready=false;
   MqlRates r[];
   ArraySetAsSeries(r,false);
   int needed=InpMTFLookback+20;
   int copied=CopyRates(_Symbol,tf,shift,needed,r);
   // Nếu lịch sử đang tải thì thử lại ở lần cập nhật nến chart sau, không chặn bằng Sleep.
   if(copied!=needed) return false;
   int end=copied-1;
   if(r[end].time!=last || r[end].time+seconds>cutoff) return false;
   MTFCache[cache].count=0;
   MTFCache[cache].hasPH=false;MTFCache[cache].hasPL=false;
   MTFCache[cache].lastHigh=r[end].high;MTFCache[cache].lastLow=r[end].low;
   int strength=InpContextSwingStrength,first=MathMax(15,copied-InpMTFLookback);
   double mn[271],mx[271];
   mn[copied]=EMPTY_VALUE;mx[copied]=-EMPTY_VALUE;
   for(int k=end;k>=first;k--)
   { mn[k]=MathMin(r[k].close,mn[k+1]);mx[k]=MathMax(r[k].close,mx[k+1]); }
   for(int p=end-strength;p>=first;p--)
   {
      bool ph=true,pl=true;
      for(int k=1;k<=strength;k++)
      {
         if(r[p].high<=r[p-k].high || r[p].high<r[p+k].high) ph=false;
         if(r[p].low>=r[p-k].low || r[p].low>r[p+k].low) pl=false;
      }
      if(ph==pl) continue;
      if(ph && !MTFCache[cache].hasPH) { MTFCache[cache].hasPH=true;MTFCache[cache].ph=r[p].high; }
      if(pl && !MTFCache[cache].hasPL) { MTFCache[cache].hasPL=true;MTFCache[cache].pl=r[p].low; }
      if(!InpMTFZones) continue;
      double atr=MTFAtr(p,r);
      if(atr<=0) continue;
      int born=p+strength;
      double lo=pl?r[p].low:MathMin(r[p].open,r[p].close);
      double hi=pl?MathMax(r[p].open,r[p].close):r[p].high;
      if(hi<=lo) continue;
      bool departure=pl?r[born].close-hi>=InpZoneDepartureATR*atr:lo-r[born].close>=InpZoneDepartureATR*atr;
      bool invalid=pl?mn[born+1]<lo-InpZoneInvalidATR*atr:mx[born+1]>hi+InpZoneInvalidATR*atr;
      if(!departure || invalid) continue;
      int n=MTFCache[cache].count;
      if(n>=250) break;
      MTFCache[cache].lo[n]=lo;MTFCache[cache].hi[n]=hi;MTFCache[cache].scale[n]=atr;
      MTFCache[cache].side[n]=pl?1:-1;MTFCache[cache].count++;
   }
   MTFCache[cache].lastClosed=last;MTFCache[cache].ready=true;
   return true;
}
string MTFDistanceText(const double distance,const double atr)
{
   return DoubleToString(distance,_Digits)+" giá / "+DoubleToString(distance/atr,2)+" ATR chart";
}
string BuildMTFTooltip(const int slot,const int i,const int count,const int direction,
                       const datetime &time[],const double &high[],const double &low[],const double &close[])
{
   if(!InpMTFZones && !InpMTFKeyLevels) return "";
   double atr=ContextATR(i,high,low,close);
   if(atr<=0) return "\nMTF: chưa đủ ATR chart.";
   datetime cutoff=i==count-1?TimeCurrent():time[i]+PeriodSeconds(_Period);
   // Không lấy nến chart tiếp theo để kéo thời điểm entry qua kỳ nghỉ/gap.
   if(cutoff>TimeCurrent()) cutoff=TimeCurrent();
   string rows="",summary="";
   double bestSupport=EMPTY_VALUE,bestObstacle=EMPTY_VALUE;
   string support="",obstacle="";
   int active=0;
   for(int tf=0;tf<4;tf++)
   {
      if(!MTFEnabled(tf)) continue; // OFF: không iBarShift, CopyRates hoặc tính vùng.
      active++;
      int cache=slot*4+tf;
      string name=MTFName(tf);
      if(!LoadMTFContext(cache,MTFPeriod(tf),cutoff))
      { rows+="\n"+name+": thiếu lịch sử/đang tải dữ liệu.";continue; }
      int demand=-1,supply=-1;double dd=EMPTY_VALUE,sd=EMPTY_VALUE;
      if(InpMTFZones)
      {
         for(int n=0;n<MTFCache[cache].count;n++)
         {
            double lo=MTFCache[cache].lo[n],hi=MTFCache[cache].hi[n];
            double tolerance=InpZoneInvalidATR*MTFCache[cache].scale[n];
            int side=MTFCache[cache].side[n];
            if(side>0 && close[i]<lo-tolerance) continue;
            if(side<0 && close[i]>hi+tolerance) continue;
            double d=EntryBandDistance(lo,hi,close[i],close[i]);
            if(side>0 && d<dd) { dd=d;demand=n; }
            if(side<0 && d<sd) { sd=d;supply=n; }
         }
         rows+="\n"+name+" — ";
         for(int side=0;side<2;side++)
         {
            int n=side==0?demand:supply;double d=side==0?dd:sd;
            string label=side==0?"cầu ":"cung ";
            if(side==1) rows+="; ";
            if(n<0) { rows+=label+"chưa thấy vùng hợp lệ";continue; }
            rows+=label+DoubleToString(MTFCache[cache].lo[n],_Digits)+"–"+DoubleToString(MTFCache[cache].hi[n],_Digits)+
                  " ("+(d==0?"trong vùng":d<=InpZoneNearATR*atr?"gần vùng":"cách "+MTFDistanceText(d,atr))+")";
            bool supporting=(direction>0 && side==0) || (direction<0 && side==1);
            if(supporting && d<bestSupport) { bestSupport=d;support=label+name; }
            if(!supporting && d<bestObstacle) { bestObstacle=d;obstacle=label+name; }
         }
      }
      if(InpMTFKeyLevels)
      {
         rows+="\n"+name+" key: H/L nến đã đóng "+DoubleToString(MTFCache[cache].lastHigh,_Digits)+" / "+
                DoubleToString(MTFCache[cache].lastLow,_Digits)+"; pivot H/L "+
                (MTFCache[cache].hasPH?DoubleToString(MTFCache[cache].ph,_Digits):"chưa có")+" / "+
                (MTFCache[cache].hasPL?DoubleToString(MTFCache[cache].pl,_Digits):"chưa có")+".";
         double levels[4];
         levels[0]=MTFCache[cache].lastHigh;levels[1]=MTFCache[cache].lastLow;
         levels[2]=MTFCache[cache].ph;levels[3]=MTFCache[cache].pl;
         double above=EMPTY_VALUE,below=EMPTY_VALUE;
         for(int k=0;k<4;k++)
         {
            if(k==2 && !MTFCache[cache].hasPH) continue;
            if(k==3 && !MTFCache[cache].hasPL) continue;
            double delta=levels[k]-close[i];
            if(delta>=0 && delta<above) above=delta;
            if(delta<=0 && -delta<below) below=-delta;
         }
         rows+="\n"+name+" key gần: trên "+(above<EMPTY_VALUE?MTFDistanceText(above,atr):"chưa có")+
               "; dưới "+(below<EMPTY_VALUE?MTFDistanceText(below,atr):"chưa có")+".";
      }
   }
   if(active==0) return "";
   if(support!="") summary+="\nMTF hỗ trợ entry: "+support+" — "+MTFDistanceText(bestSupport,atr)+".";
   if(obstacle!="") summary+="\nMTF cản đối diện: "+obstacle+" — "+MTFDistanceText(bestObstacle,atr)+".";
   return "\nMTF tại thời điểm tín hiệu (chỉ nến nguồn đã đóng):"+summary+rows;
}

// Đọc nỗ lực và kết quả riêng biệt; SMA20 luôn loại nến đang xét.
string EffortResultContext(const int i,const int direction,const double &open[],const double &high[],
                          const double &low[],const double &close[],const long &ticks[],const long &volume[],
                          const double atr,const EntryMarketContext &market)
{
   int n=InpContextLegBars,first=i-n;
   if(first<20 || atr<=0) return "Nhịp trước: chưa đủ dữ liệu MA20 và nhịp nến.";
   bool real=UseRealWindow(first-20,i,volume),known=true;
   double earlyBody=0,lateBody=0,earlyMove=0,lateMove=0,earlyVol=0,lateVol=0;
   int ne=0,nl=0,rejections=0,stalls=0;
   int legdir=close[i-1]>close[first-1]?1:close[i-1]<close[first-1]?-1:0;
   int oppose=-direction;
   for(int k=first;k<i;k++)
   {
      double avg=0;
      for(int j=k-20;j<k;j++)
      {
         double v=(double)(real?volume[j]:ticks[j]);
         if(v<=0) known=false;
         avg+=v;
      }
      double v=(double)(real?volume[k]:ticks[k]);
      if(v<=0) known=false;
      double rv=avg>0?v/(avg/20.0):0;
      double body=MathMax(0.0,oppose*(close[k]-open[k]));
      double move=MathMax(0.0,oppose*(close[k]-close[k-1]));
      bool recent=k>=first+n/2;
      if(recent) { lateBody+=body;lateMove+=move;lateVol+=rv;nl++; }
      else { earlyBody+=body;earlyMove+=move;earlyVol+=rv;ne++; }
      double range=high[k]-low[k];
      if(range<=0) continue;
      double loc=(close[k]-low[k])/range;
      double wick=direction>0?MathMin(open[k],close[k])-low[k]:high[k]-MathMax(open[k],close[k]);
      bool rejected=wick/range>=0.35 && (direction>0?loc>=0.60:loc<=0.40);
      if(rejected) rejections++;
      double advance=direction>0?MathMax(0.0,low[k-1]-low[k]):MathMax(0.0,high[k]-high[k-1]);
      if(rv>=1.3 && advance<=0.15*atr && rejected) stalls++;
   }
   double eb=earlyBody/MathMax(1,ne),lb=lateBody/MathMax(1,nl);
   double em=earlyMove/MathMax(1,ne),lm=lateMove/MathMax(1,nl);
   double ev=earlyVol/MathMax(1,ne),lv=lateVol/MathMax(1,nl);
   bool weak=legdir==oppose && eb>0 && em>0 && lb<=eb*InpContextWeakeningRatio && lm<=em*InpContextWeakeningRatio;
   double near=InpZoneNearATR*atr;
   bool atZone=direction>0?market.demand && EntryBandDistance(market.demandLow,market.demandHigh,low[i],high[i])<=near:
                                market.supply && EntryBandDistance(market.supplyLow,market.supplyHigh,low[i],high[i])<=near;
   bool atKey=false;
   for(int k=0;k<4;k++) if(market.keyKnown[k])
      if(EntryBandDistance(market.keys[k],market.keys[k],low[i],high[i])<=near &&
         (direction>0?close[i]>=market.keys[k]:close[i]<=market.keys[k])) atKey=true;
   string force="chưa đủ bằng chứng suy yếu";
   if(weak && known && lv<ev*0.9) force=direction>0?"áp lực bán giảm":"áp lực mua giảm";
   else if(weak) force="thân và mức tiến giá ngược hướng thu hẹp";
   if(known && legdir==oppose && stalls>=2 && rejections>=2)
      force=(atZone || atKey)?(direction>0?"có dấu hiệu hấp thụ bán tại hỗ trợ":"có dấu hiệu hấp thụ mua tại kháng cự"):
                              "volume cao nhưng giá tiến ít, có râu từ chối; chưa có vị trí hỗ trợ xác nhận";
   string result="BC-Yếu | Nhịp trước: "+(legdir>0?"Tăng":legdir<0?"Giảm":"Đi ngang")+
                 " ("+IntegerToString(n)+" nến); "+force+".";
   result+="\nLực nhịp: thân ngược/ATR "+DoubleToString(eb/atr,2)+" → "+DoubleToString(lb/atr,2)+
           "; tiến Close ngược/ATR "+DoubleToString(em/atr,2)+" → "+DoubleToString(lm/atr,2)+".";
   result+="\nVolume nhịp / MA20 trước mỗi nến: "+(known?DoubleToString(ev,2)+" → "+DoubleToString(lv,2):"thiếu dữ liệu")+".";
   double r=high[i]-low[i],b=MathAbs(close[i]-open[i]);
   double loc=r>0?(close[i]-low[i])/r:0.5;
   double wl=MathMin(open[i],close[i])-low[i],wu=high[i]-MathMax(open[i],close[i]);
   double avg=0;bool entryKnown=true;
   for(int j=i-20;j<i;j++) { double v=(double)(real?volume[j]:ticks[j]);if(v<=0) entryKnown=false;avg+=v; }
   double cur=(double)(real?volume[i]:ticks[i]);if(cur<=0) entryKnown=false;
   result+="\nNến tín hiệu: "+(r<=0?"biên độ bằng 0":b/r<=0.25?"thân nhỏ":b/r>=0.6?"thân dài":"thân vừa")+
           "; đóng "+(loc>=0.75?"gần đỉnh":loc<=0.25?"gần đáy":"giữa nến")+
           "; râu dưới/trên "+DoubleToString(r>0?100*wl/r:0,0)+"%/"+DoubleToString(r>0?100*wu/r:0,0)+"%.";
   result+="\nVolume tín hiệu / MA20 trước: "+(entryKnown && avg>0?DoubleToString(cur/(avg/20.0),2):"thiếu dữ liệu")+
           " | "+(real?"real volume":"tick volume")+".";
   return result;
}
// Xác nhận tooltip độc lập với buffer ConfirmedBuy/Sell. Chỉ xét nến đã đóng.
// Sau khi xác nhận/phủ nhận thì giữ nguyên kết quả của cửa sổ theo dõi.
string ContextFollowStatus(const int i,const int direction,const int count,const double &high[],
                           const double &low[],const double &close[])
{
   if(i>=count-1) return "Trạng thái: Chưa xác nhận — nến tín hiệu đang chạy.";
   int last=MathMin(count-2,i+InpContextFollowBars);
   for(int j=i+1;j<=last;j++)
   {
      bool invalid=direction>0?close[j]<low[i]:close[j]>high[i];
      bool confirmed=direction>0?close[j]>high[i]:close[j]<low[i];
      if(invalid) return "Trạng thái: Bị phủ nhận — đóng xuyên biên bảo vệ tại nến +"+IntegerToString(j-i)+".";
      if(confirmed) return "Trạng thái: Đã xác nhận — đóng vượt biên tín hiệu tại nến +"+IntegerToString(j-i)+".";
   }
   return "Trạng thái: Chưa xác nhận ("+IntegerToString(MathMax(0,last-i))+"/"+IntegerToString(InpContextFollowBars)+" nến đóng).";
}

void BuildEntryContext(const int i,const int direction,const bool live,const datetime &time[],
                       const double &open[],const double &high[],const double &low[],const double &close[],
                       const long &tick_volume[],const long &volume[],
                       string &caption,string &tip,color &ink,const bool latest=false)
{
   string side=direction>0 ? "BUY" : "SELL";
   caption=side+" | chờ dữ liệu"; tip="Chưa đủ lịch sử để đọc bối cảnh."; ink=clrSilver;
   int leg=InpContextLegBars;
   if(i<MathMax(20,MathMax(2*leg,InpContextTrendBars))) return;
   double atr=ContextATR(i,high,low,close);
   if(atr<=0) return;
   int trend=ContextTrend(i,high,low);
   bool aligned=trend==direction;
   string trendText=trend==0 ? "Cấu trúc chưa rõ/đi ngang" : aligned ? "Thuận xu hướng" : "Ngược xu hướng";
   // One volume source for the complete price/momentum comparison window.
   int first=i-MathMax(19,2*leg);
   bool real=UseRealWindow(first,i,volume);
   double oldCounter=0,newCounter=0,oldVolume=0,newVolume=0;
   double oldRange=0,newRange=0,priorSigned=0;
   int oldOpposite=0,newOpposite=0,recentUp=0,recentDown=0,recentDoji=0;
   bool momentumVolumeKnown=true;
   for(int k=i-2*leg;k<i;k++)
   {
      double v=(double)(real?volume[k]:tick_volume[k]);
      if(v<=0) momentumVolumeKnown=false;
      double counter=MathMax(0.0,-direction*(close[k]-open[k]));
      bool recent=k>=i-leg;
      if(recent)
      {
         newCounter+=counter; newRange+=high[k]-low[k];
         priorSigned+=close[k]-open[k];
         if(close[k]>open[k]) recentUp++;else if(close[k]<open[k]) recentDown++;else recentDoji++;
         if(counter>0) { newOpposite++; newVolume+=v; }
      }
      else
      {
         oldCounter+=counter; oldRange+=high[k]-low[k];
         if(counter>0) { oldOpposite++; oldVolume+=v; }
      }
   }
   bool comparable=oldCounter>0;
   bool weakening=comparable && newCounter<=oldCounter*InpContextWeakeningRatio;
   bool volumeFading=momentumVolumeKnown && oldOpposite>0 && (newOpposite==0 ||
                     newVolume/newOpposite<oldVolume/oldOpposite);
   string momentum=!comparable ? "Chưa có nhịp ngược đủ rõ để so sánh" :
                   weakening ? "Lực thân nến ngược đã giảm" : "Lực thân nến ngược chưa giảm đủ";
   double signedPressure=direction*priorSigned/(leg*atr);
   string force=signedPressure>0.10 ? "Các thân nến gần nhất nghiêng cùng hướng entry" :
                signedPressure<-0.10 ? "Các thân nến gần nhất còn nghiêng ngược entry" : "Lực thân nến gần nhất cân bằng/yếu";
   string opposite=direction>0?"GIẢM":"TĂNG";
   string priceBias=priorSigned/(leg*atr)>0.10?"TĂNG":priorSigned/(leg*atr)<-0.10?"GIẢM":"CÂN BẰNG/YẾU";
   string forceDetail=IntegerToString(leg)+" nến trước: T"+IntegerToString(recentUp)+"/G"+IntegerToString(recentDown)+
                      "/D"+IntegerToString(recentDoji)+" | lực thân "+priceBias+
                      (signedPressure>0.10?" (cùng entry)":signedPressure<-0.10?" (ngược entry)":"");
   string legDetail="Nhịp "+opposite+" trước "+side+": ";
   if(!comparable) legDetail+="chưa có nhịp ngược rõ để so sánh";
   else
   {
      double change=100.0*(newCounter/oldCounter-1.0);
      if(change<0) legDetail+="yếu đi "+DoubleToString(-change,0)+"% theo tổng thân nến"+(weakening?" (ĐÃ GIẢM LỰC)":" (chưa đủ ngưỡng)");
      else legDetail+="không yếu đi"+(change>0?", tăng "+DoubleToString(change,0)+"% theo tổng thân":" như nhịp trước");
   }
   string volumeDetail="Vol nến "+opposite+": ";
   if(!momentumVolumeKnown) volumeDetail+="thiếu dữ liệu";
   else if(newOpposite==0) volumeDetail+="không còn nến ngược trong nhóm gần nhất";
   else if(oldOpposite==0 || oldVolume<=0) volumeDetail+="chưa có nhóm trước để so sánh";
   else
   {
      double change=100.0*((newVolume/newOpposite)/(oldVolume/oldOpposite)-1.0);
      volumeDetail+=MathAbs(change)<0.05 ? "gần như không đổi" : (change<0?"giảm ":"tăng ")+DoubleToString(MathAbs(change),0)+"% bình quân/nến";
   }
   string candleRows[3];
   for(int back=3;back>=1;back--)
   {
      int k=i-back;
      double candleRange=high[k]-low[k],candleBody=MathAbs(close[k]-open[k]);
      double bodyRatio=candleRange>0?candleBody/candleRange:0;
      double closeLocation=candleRange>0?(close[k]-low[k])/candleRange:0.5;
      string candleSide=close[k]>open[k]?"TĂNG":close[k]<open[k]?"GIẢM":"DOJI";
      bool solid=bodyRatio>=0.60 && (close[k]>open[k]?closeLocation>=0.75:closeLocation<=0.25);
      string shape=solid?"thân mạnh":bodyRatio<=0.25?"thân nhỏ/yếu":"thân vừa";
      double v=(double)(real?volume[k]:tick_volume[k]);
      double previous=(double)(real?volume[k-1]:tick_volume[k-1]);
      string volText="vol thiếu dữ liệu";
      if(v>0 && previous>0)
      {
         double change=100.0*(v/previous-1.0);
         volText="vol "+IntegerToString((long)v)+(change>0?" (+":change<0?" (":" (")+DoubleToString(change,0)+"%)";
      }
      candleRows[3-back]="Nến -"+IntegerToString(back)+": "+candleSide+" "+shape+" | thân "+DoubleToString(bodyRatio*100,0)+"% nến | "+volText;
   }
   double range=high[i]-low[i],body=MathAbs(close[i]-open[i]);
   double location=range>0 ? (close[i]-low[i])/range : 0.5;
   double wick=direction>0 ? MathMin(open[i],close[i])-low[i] : high[i]-MathMax(open[i],close[i]);
   bool rejection=range>0 && wick>=body && wick/range>=0.35 &&
                  (direction>0 ? location>=0.60 : location<=0.40);
   bool directional=direction*(close[i]-open[i])>0;
   bool engulf=directional && direction*(close[i-1]-open[i-1])<0 &&
               (direction>0 ? (open[i]<=close[i-1] && close[i]>=open[i-1] &&
                               (open[i]<close[i-1] || close[i]>open[i-1])) :
                              (open[i]>=close[i-1] && close[i]<=open[i-1] &&
                               (open[i]>close[i-1] || close[i]<open[i-1])));
   double firstBody=MathAbs(close[i-2]-open[i-2]);
   double middleBody=MathAbs(close[i-1]-open[i-1]);
   bool star=firstBody>0 && middleBody<=InpStarSmallBodyFactor*firstBody && directional &&
             direction*(close[i-2]-open[i-2])<0;
   if(star)
      star=direction>0 ? (MathMax(open[i-1],close[i-1])<=close[i-2]+InpStarSmallBodyFactor*firstBody &&
                          low[i-1]<=low[i-2] && close[i]>MathMax(open[i-1],close[i-1]) &&
                          close[i]>=close[i-2]+InpStarPenetration*firstBody) :
                         (MathMin(open[i-1],close[i-1])>=close[i-2]-InpStarSmallBodyFactor*firstBody &&
                          high[i-1]>=high[i-2] && close[i]<MathMin(open[i-1],close[i-1]) &&
                          close[i]<=close[i-2]-InpStarPenetration*firstBody);
   bool breakStart=directional && (direction>0 ? close[i]>high[i-1] : close[i]<low[i-1]);
   double sum=0; bool known=true;
   for(int k=i-19;k<=i;k++)
   {
      double v=(double)(real?volume[k]:tick_volume[k]);
      if(v<=0) known=false;
      sum+=v;
   }
   double current=(double)(real?volume[i]:tick_volume[i]);
   double ratio=known && sum>0 ? current/(sum/20.0) : 0;
   bool highVolume=known && ratio>=InpPatternHighVolumeFactor;
   bool priceStart=rejection || engulf || star || breakStart;
   EntryMarketContext market={};
   if(InpUseSupplyDemandContext) FindEntryZones(i,open,high,low,close,atr,market);
   if(InpUseKeyLevelContext) FindEntryKeyLevels(i,time,high,low,market);
   double near=InpZoneNearATR*atr;
   bool nearDemand=market.demand && EntryBandDistance(market.demandLow,market.demandHigh,low[i],high[i])<=near;
   bool nearSupply=market.supply && EntryBandDistance(market.supplyLow,market.supplyHigh,low[i],high[i])<=near;
   bool zoneAligned=direction>0 ? nearDemand && !nearSupply : nearSupply && !nearDemand;
   bool keyReaction=false,keyObstacle=false;
   string keyDetails="";
   for(int k=0;k<4;k++)
   {
      string key=ContextLevelName(k+2);
      if(!market.keyKnown[k]) { keyDetails+=key+": thiếu dữ liệu; ";continue; }
      double level=market.keys[k];
      bool reaction=direction>0 ? low[i]<=level+near && close[i]>level+InpZoneInvalidATR*atr :
                                 high[i]>=level-near && close[i]<level-InpZoneInvalidATR*atr;
      // A reaction must occur close to the actual band, not anywhere beyond a distant level.
      reaction=reaction && EntryBandDistance(level,level,low[i],high[i])<=near;
      bool obstacle=direction>0 ? level>close[i] && level-close[i]<=near : level<close[i] && close[i]-level<=near;
      keyReaction=keyReaction || reaction;keyObstacle=keyObstacle || obstacle;
      keyDetails+=key+" "+DoubleToString(level,_Digits)+(reaction?" (vượt/lấy lại thuận hướng)":obstacle?" (cản gần)":"")+"; ";
   }
   int total=3+(InpUseSupplyDemandContext?1:0)+(InpUseKeyLevelContext?1:0);
   int score=(aligned?1:0)+(weakening?1:0)+(priceStart && highVolume?1:0)+
             (InpUseSupplyDemandContext && zoneAligned?1:0)+(InpUseKeyLevelContext && keyReaction && !keyObstacle?1:0);
   caption=side+" | "+IntegerToString(score)+"/"+IntegerToString(total)+(live?" LIVE":"");
   if(InpCompactContext)
      caption=CompactEntryDescription(i,direction,live,open,high,low,close,tick_volume,volume,real,atr,market);
   ink=live?clrSilver:score==total?clrLimeGreen:score>=total-1?clrGold:clrDarkGray;
   if(latest) RenderContextLevels(i,time,market);
   string signs="";
   if(rejection) signs+="Râu từ chối; ";
   if(engulf) signs+="Engulfing; ";
   if(star) signs+="Star; ";
   if(breakStart) signs+="Đóng vượt biên nến trước; ";
   if(signs=="") signs="Chưa thấy dấu hiệu khởi động trong nhóm kiểm tra";
   tip=caption+"\n"+side+" — bối cảnh tại nến entry"+(live?" (nến đang chạy, chưa cố định)":" (nến đã đóng)");
   tip+="\n1. Xu hướng: "+trendText+". Dùng 2 đỉnh và 2 đáy pivot đã xác nhận trước entry.";
   tip+="\n2. "+forceDetail+".\n   "+candleRows[0]+"\n   "+candleRows[1]+"\n   "+candleRows[2]+"\n   "+legDetail+".\n   "+volumeDetail+".";
   tip+="\n   So "+IntegerToString(leg)+" nến gần nhất với "+IntegerToString(leg)+" nến trước đó: thân ngược/ATR "+
         DoubleToString(newCounter/(leg*atr),2)+" / "+DoubleToString(oldCounter/(leg*atr),2)+".";
   tip+="\n   Biên độ TB/ATR: "+DoubleToString(newRange/(leg*atr),2)+" / "+DoubleToString(oldRange/(leg*atr),2)+".";
   tip+="\n   Volume nến ngược: "+(!momentumVolumeKnown ? "thiếu dữ liệu" : volumeFading ? "giảm hoặc không còn nến ngược" : "chưa thấy giảm rõ");
   tip+="\n3. Dấu hiệu bắt đầu: "+signs;
   tip+="\n   Volume entry / SMA20 (gồm entry): "+(known?DoubleToString(ratio,2):"thiếu dữ liệu")+
         (highVolume?" — đạt ngưỡng":" — chưa đạt ngưỡng");
   string supportLine=direction>0 ? DescribeEntryZone(market.demand,true,true,market.demandLow,market.demandHigh,close[i],atr,market.demandTouches) :
                                    DescribeEntryZone(market.supply,true,false,market.supplyLow,market.supplyHigh,close[i],atr,market.supplyTouches);
   string obstacleLine=direction>0 ? DescribeEntryZone(market.supply,false,false,market.supplyLow,market.supplyHigh,close[i],atr,market.supplyTouches) :
                                     DescribeEntryZone(market.demand,false,true,market.demandLow,market.demandHigh,close[i],atr,market.demandTouches);
   if(!InpUseSupplyDemandContext) { supportLine="Cung/cầu: đang tắt";obstacleLine=""; }
   if(InpUseSupplyDemandContext) tip+="\n4. Cung/cầu tại đóng cửa entry:\n   "+supportLine+"\n   "+obstacleLine;
   if(InpUseKeyLevelContext)
      tip+="\n5. Key level (giờ broker): "+keyDetails+(keyObstacle?"Có cản gần theo hướng entry.":keyReaction?"Có phản ứng thuận tại mốc.":"Chưa phản ứng rõ tại mốc.");
   string keyAbove="Key trên entry: chưa thấy mốc/thiếu dữ liệu",keyBelow="Key dưới entry: chưa thấy mốc/thiếu dữ liệu";
   double above=EMPTY_VALUE,below=EMPTY_VALUE;
   for(int k=0;k<4;k++) if(market.keyKnown[k])
   {
      double delta=market.keys[k]-close[i];
      string detail=ContextLevelName(k+2)+" "+DoubleToString(market.keys[k],_Digits)+" | cách entry "+
                    DoubleToString(MathAbs(delta),_Digits)+" giá / "+DoubleToString(MathAbs(delta)/atr,2)+" ATR";
      if(delta>=0 && delta<above) { above=delta;keyAbove="Key trên: "+detail; }
      if(delta<=0 && -delta<below) { below=-delta;keyBelow="Key dưới: "+detail; }
   }
   if(!InpUseKeyLevelContext) { keyAbove="Key level: đang tắt";keyBelow=""; }
   tip+="\nTiếp diễn cần quan sát: nến sau đóng "+(direction>0?"trên đỉnh entry":"dưới đáy entry")+".";
   tip+="\nVô hiệu tham khảo: đóng "+(direction>0?"dưới đáy entry":"trên đỉnh entry")+".";
   tip=side+" | "+(live?"Nến đang chạy":"Bối cảnh cố định khi đóng nến")+"\n"+
       EffortResultContext(i,direction,open,high,low,close,tick_volume,volume,atr,market)+
       "\nVị trí: "+supportLine+"; "+obstacleLine+
       (InpUseKeyLevelContext?"\nMốc giá: "+keyDetails:"")+"\nDấu hiệu bắt đầu: "+signs+
       "\nXác nhận: đóng "+(direction>0?"trên đỉnh":"dưới đáy")+" tín hiệu; bảo vệ: "+
       DoubleToString(direction>0?low[i]:high[i],_Digits)+
       "\nLực là suy luận OHLCV; trạng thái tooltip độc lập xác nhận tín hiệu gốc.";
}
void RefreshEntryContexts(const int count,const datetime &time[],const double &open[],const double &high[],
                          const double &low[],const double &close[],const long &tick_volume[],const long &volume[])
{
   if(!InpShowEntryContext || Prefix=="") return;
   int selectedBars[10],selectedTypes[10],selectedCount=0;
   int candidates=InpShowHistory?ContextCount:ShownCount;
   for(int p=0;p<candidates && selectedCount<InpContextKeep;p++)
   {
      int index=ContextCount-1-p;
      int i=InpShowHistory?ContextBars[index]:ShownIndex[p];
      int type=InpShowHistory?ContextTypes[index]:ShownType[p];
      int direction=(type%2==0)?1:-1;
      if(i<2 || i>=count || MarkValue(i,type)==EMPTY_VALUE) continue;
      bool duplicate=false;
      for(int k=0;k<selectedCount;k++)
         if(selectedBars[k]==i && ((selectedTypes[k]%2==0)?1:-1)==direction) duplicate=true;
      if(duplicate) continue;
      selectedBars[selectedCount]=i;selectedTypes[selectedCount]=type;selectedCount++;
   }
   if(selectedCount==0) ClearContextLevelDrawings();
   for(int slot=0;slot<10;slot++)
   {
      if(slot>=selectedCount)
      {
         if(ContextNames[slot]!="" && ObjectDelete(0,ContextNames[slot])) ContextNames[slot]="";
         continue;
      }
      int i=selectedBars[slot],direction=selectedTypes[slot]%2==0?1:-1;
      bool live=i==count-1;
      bool fresh=ContextNames[slot]=="";
      bool same=!fresh && ContextTimes[slot]==time[i] && ContextDirections[slot]==direction;
      datetime statusStamp=count>=2?time[count-2]:0;
      bool frozen=same && !live && !ContextLive[slot];
      if(frozen && ContextStatusStamp[slot]==statusStamp) continue;
      double atr=ContextATR(i,high,low,close);
      double gap=MathMax(25*_Point,MathMax(atr,high[i]-low[i])*0.55);
      double price=direction>0?low[i]-gap:high[i]+gap;
      string name=Prefix+"ENTRY_CTX_"+IntegerToString(slot),caption,tip;
      color ink;
      if(frozen) { tip=ContextBaseTips[slot];caption=ContextTexts[slot];ink=clrSilver; }
      else
      {
         BuildEntryContext(i,direction,live,time,open,high,low,close,tick_volume,volume,caption,tip,ink,slot==0);
         ContextBaseTips[slot]=tip;
      }
      tip+=BuildMTFTooltip(slot,i,count,direction,time,high,low,close);
      tip+="\n"+ContextFollowStatus(i,direction,count,high,low,close);
      string displayText=InpContextHoverOnly?"ⓘ":caption;
      bool ok=true;
      if(fresh)
      {
         if(!ObjectCreate(0,name,OBJ_TEXT,0,time[i],price)) continue;
         ContextNames[slot]=name;
         if(!ObjectSetString(0,name,OBJPROP_FONT,"Arial")) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpContextHoverOnly?MathMax(8,InpContextFontSize):InpContextFontSize)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false)) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_HIDDEN,true)) ok=false;
      }
      if(fresh || ContextTimes[slot]!=time[i] || ContextPrices[slot]!=price)
         if(!ObjectMove(0,name,0,time[i],price)) ok=false;
      if(fresh || ContextTexts[slot]!=displayText)
         if(!ObjectSetString(0,name,OBJPROP_TEXT,displayText)) ok=false;
      if(fresh || ContextTips[slot]!=tip)
         if(!ObjectSetString(0,name,OBJPROP_TOOLTIP,tip)) ok=false;
      if(!ObjectSetInteger(0,name,OBJPROP_COLOR,InpContextHoverOnly?clrSilver:ink)) ok=false;
      if(!ObjectSetInteger(0,name,OBJPROP_ANCHOR,direction>0?ANCHOR_UPPER:ANCHOR_LOWER)) ok=false;
      if(ok)
      {
         ContextTimes[slot]=time[i];ContextPrices[slot]=price;ContextDirections[slot]=direction;
         ContextTexts[slot]=displayText;ContextTips[slot]=tip;ContextLive[slot]=live;ContextStatusStamp[slot]=statusStamp;
      }
      else
      {
         ObjectDelete(0,name);ContextNames[slot]="";
      }
   }
}

bool RejectLowVolumeDoji(const int i,const double &open[],const double &high[],
                         const double &low[],const double &close[],
                         const long &tick_volume[],const long &volume[])
{
   double range=high[i]-low[i];
   double body=MathAbs(close[i]-open[i]);
   bool doji=(range<=0.0 || body<=InpDojiMaxBodyRatio*range);
   if(InpRejectConsecutiveDojis && doji && i>0)
   {
      double previousRange=high[i-1]-low[i-1];
      double previousBody=MathAbs(close[i-1]-open[i-1]);
      bool previousDoji=(previousRange<=0.0 || previousBody<=InpDojiMaxBodyRatio*previousRange);
      if(previousDoji) return true;
   }
   if(!InpFilterLowVolumeDoji) return false;
   if(!doji || i<InpVolumeAveragePeriod) return false;
   // Use one volume source for the complete comparison window.
   bool real=InpUseRealVolume && volume[i]>0;
   if(real)
      for(int k=i-InpVolumeAveragePeriod;k<i;k++)
         if(volume[k]<=0) { real=false; break; }
   double sum=0.0;
   for(int k=i-InpVolumeAveragePeriod;k<i;k++)
   {
      long v=real?volume[k]:tick_volume[k];
      if(v<=0) return false; // Unknown data: do not pretend it is low volume.
      sum+=(double)v;
   }
   double average=sum/InpVolumeAveragePeriod;
   long current=real?volume[i]:tick_volume[i];
   return current>0 && (double)current<average;
}
// One consistent volume source per comparison; no extra buffers or handles.
bool UseRealWindow(const int first,const int last,const long &volume[])
{
   if(!InpUseRealVolume) return false;
   for(int k=first;k<=last;k++) if(volume[k]<=0) return false;
   return true;
}
bool OriginalVolumePatternPass(const int i,const long &tick_volume[],const long &volume[])
{
   if(i<2) return false;
   bool real=UseRealWindow(i-2,i,volume);
   if(real)
      for(int k=i-2;k<=i;k++)
         if(RealVolumeEMA[k]==EMPTY_VALUE) { real=false; break; }
   double v1=(double)(real?volume[i-2]:tick_volume[i-2]);
   double v2=(double)(real?volume[i-1]:tick_volume[i-1]);
   double v3=(double)(real?volume[i]:tick_volume[i]);
   if(v1<=0.0 || v2<=0.0 || v3<=0.0) return false;
   double signalEMA=real?RealVolumeEMA[i]:TickVolumeEMA[i];
   // Never draw the signal mark when candle 3 volume is below EMA20.
   if(signalEMA==EMPTY_VALUE || signalEMA<=0.0 || v3<signalEMA) return false;
   double factor=1.0+InpOriginalVolumeMinRisePercent/100.0;
   bool rising=(v2>v1 && v3>v2 && v3>v1 &&
                v2>=v1*factor && v3>=v2*factor);
   if(rising) return true;
   for(int k=i-2;k<=i;k++)
   {
      double baseline=real?RealVolumeEMA[k]:TickVolumeEMA[k];
      double current=(double)(real?volume[k]:tick_volume[k]);
      if(baseline==EMPTY_VALUE || baseline<=0.0 ||
         current<InpThreeBarHighVolumeFactor*baseline) return false;
   }
   return true;
}
void OriginalC7CBPattern(const int i,const double &open[],const double &high[],
                         const double &low[],const double &close[],bool &buy,bool &sell)
{
   buy=false; sell=false;
   if(i<2) return;
   int n1=i-2,n2=i-1;
   bool red1=close[n1]<open[n1],green1=close[n1]>open[n1];
   bool red2=close[n2]<open[n2],green2=close[n2]>open[n2];
   bool red3=close[i]<open[i],green3=close[i]>open[i];
   // Keep original same-color patterns and add R-G-G / G-R-G, plus sell mirrors.
   bool buyColors=(red1 && red2 && red3) || (red1 && green2 && green3) ||
                  (green1 && red2 && green3);
   bool sellColors=(green1 && green2 && green3) || (green1 && red2 && red3) ||
                   (red1 && green2 && red3);
   buy=buyColors &&
       high[i]<high[n2] && high[n2]<high[n1] && low[i]<low[n1] && low[n2]<low[n1];
   sell=sellColors &&
        high[i]>high[n1] && high[n2]>high[n1] && low[i]>low[n2] && low[n2]>low[n1];
}
void C7CBSignalPattern(const int i,const double &open[],const double &high[],const double &low[],
                       const double &close[],const long &tick_volume[],const long &volume[],
                       bool &buy,bool &sell,bool &allThreeWicks)
{
   allThreeWicks=false;
   OriginalC7CBPattern(i,open,high,low,close,buy,sell);
   if(!InpUseWideLowVolumeEntry || buy || sell || i<2) return;
   double range1=high[i-2]-low[i-2];
   double range2=high[i-1]-low[i-1];
   double range3=high[i]-low[i];
   if(range1<=0.0 || range2<=range1 || range3<=range2) return;
   bool real=UseRealWindow(i-2,i,volume);
   double v1=(double)(real?volume[i-2]:tick_volume[i-2]);
   double v2=(double)(real?volume[i-1]:tick_volume[i-1]);
   double v3=(double)(real?volume[i]:tick_volume[i]);
   if(v1<=0.0 || v2<=0.0 || v3<=0.0 || v3>=v1 || v3>=v2) return;
   // Direction follows candle 3; require a rejection wick longer than its body.
   double body1=MathAbs(close[i-2]-open[i-2]),body2=MathAbs(close[i-1]-open[i-1]);
   double body3=MathAbs(close[i]-open[i]);
   double lower1=MathMin(open[i-2],close[i-2])-low[i-2];
   double lower2=MathMin(open[i-1],close[i-1])-low[i-1];
   double lower3=MathMin(open[i],close[i])-low[i];
   double upper1=high[i-2]-MathMax(open[i-2],close[i-2]);
   double upper2=high[i-1]-MathMax(open[i-1],close[i-1]);
   double upper3=high[i]-MathMax(open[i],close[i]);
   bool buyWick3=lower3>InpWideLowVolumeWickBodyFactor*body3;
   bool sellWick3=upper3>InpWideLowVolumeWickBodyFactor*body3;
   buy=close[i]>open[i] && buyWick3;
   sell=close[i]<open[i] && sellWick3;
   // Candle 3's directional wick is mandatory. Three aligned long wicks get a gold "3 WICK" marker.
   if(buy) allThreeWicks=buyWick3 && lower1>InpWideLowVolumeWickBodyFactor*body1 &&
                                  lower2>InpWideLowVolumeWickBodyFactor*body2;
   else if(sell) allThreeWicks=sellWick3 && upper1>InpWideLowVolumeWickBodyFactor*body1 &&
                                      upper2>InpWideLowVolumeWickBodyFactor*body2;
}
// Forex-friendly stars: no mandatory gap; middle body must sit near the
// first candle's extreme. Engulfing compares real bodies, not complete ranges.
void HighVolumeReversal(const int i,const double &open[],const double &high[],
                        const double &low[],const double &close[],
                        const long &tick_volume[],const long &volume[],
                        bool &buy,bool &sell)
{
   buy=false; sell=false;
   if(i<2 || (!InpUseStars && !InpUseEngulfing)) return;
   // Standard SMA20: the signal candle plus the previous 19 candles.
   // One source throughout the window; real volume falls back to tick volume.
   const int maPeriod=20;
   if(i<maPeriod-1) return;
   bool real=UseRealWindow(i-maPeriod+1,i,volume);
   double sum=0.0;
   for(int k=i-maPeriod+1;k<=i;k++)
   {
      double v=(double)(real?volume[k]:tick_volume[k]);
      if(v<=0.0) return; // Insufficient volume data: no signal.
      sum+=v;
   }
   double baseline=sum/maPeriod;
   double current=(double)(real?volume[i]:tick_volume[i]);
   if(current<InpPatternHighVolumeFactor*baseline) return;
   if(InpUseEngulfing)
   {
      bool bull=close[i-1]<open[i-1] && close[i]>open[i] &&
                open[i]<=close[i-1] && close[i]>=open[i-1] &&
                (open[i]<close[i-1] || close[i]>open[i-1]);
      bool bear=close[i-1]>open[i-1] && close[i]<open[i] &&
                open[i]>=close[i-1] && close[i]<=open[i-1] &&
                (open[i]>close[i-1] || close[i]<open[i-1]);
      buy=bull; sell=bear;
   }
   if(InpUseStars)
   {
      int a=i-2,b=i-1;
      double body=MathAbs(close[a]-open[a]);
      double middle=MathAbs(close[b]-open[b]);
      bool small=body>0.0 && middle<=InpStarSmallBodyFactor*body;
      double upperMiddle=MathMax(open[b],close[b]);
      double lowerMiddle=MathMin(open[b],close[b]);
      bool morning=small && close[a]<open[a] && close[i]>open[i] &&
                   upperMiddle<=close[a]+InpStarSmallBodyFactor*body &&
                   low[b]<=low[a] && close[i]>upperMiddle &&
                   close[i]>=close[a]+InpStarPenetration*body;
      bool evening=small && close[a]>open[a] && close[i]<open[i] &&
                   lowerMiddle>=close[a]-InpStarSmallBodyFactor*body &&
                   high[b]>=high[a] && close[i]<lowerMiddle &&
                   close[i]<=close[a]-InpStarPenetration*body;
      buy=buy || morning; sell=sell || evening;
   }
}
// SMA seed, then standard EMA alpha=2/(N+1). Missing volume resets its own EMA.
double NextVolumeEMA(const int i,const long &values[],const double &ema[])
{
   int n=InpCBVolumeEMAPeriod;
   if(i<n-1 || values[i]<=0) return EMPTY_VALUE;
   if(i>0 && ema[i-1]!=EMPTY_VALUE)
      return ema[i-1]+2.0/(n+1.0)*((double)values[i]-ema[i-1]);
   double sum=0.0;
   for(int k=i-n+1;k<=i;k++)
   {
      if(values[k]<=0) return EMPTY_VALUE;
      sum+=(double)values[k];
   }
   return sum/n;
}
bool VolumeEMAPass(const int i,const long &tick_volume[],const long &volume[])
{
   bool real=InpUseRealVolume && RealVolumeEMA[i]!=EMPTY_VALUE && volume[i]>0;
   double baseline=real?RealVolumeEMA[i]:TickVolumeEMA[i];
   double current=(double)(real?volume[i]:tick_volume[i]);
   return baseline!=EMPTY_VALUE && current>0.0 && current>=InpVolumeEMAThresholdFactor*baseline;
}
bool ClusterPass(const int i,const bool buy,const double &close[],
                 const long &tick_volume[],const long &volume[])
{
   if(!InpUseVolumeCluster) return true;
   // Relaxed mode retains high-volume CB, as requested, before testing weakening.
   if(!InpStrictVolumeFilter && i>=InpVolumeAveragePeriod)
   {
      bool realAverage=UseRealWindow(i-InpVolumeAveragePeriod,i,volume);
      double baseline=0.0;
      bool valid=true;
      for(int k=i-InpVolumeAveragePeriod;k<i;k++)
      {
         double v=(double)(realAverage?volume[k]:tick_volume[k]);
         if(v<=0.0) { valid=false; break; }
         baseline+=v;
      }
      double current=(double)(realAverage?volume[i]:tick_volume[i]);
      if(valid && current>0.0 && current>=baseline/InpVolumeAveragePeriod) return true;
   }
   int n=InpVolumeClusterBars,first=i-n+1;
   if(first<0) return false;
   bool real=UseRealWindow(first,i,volume);
   double center=(n-1)/2.0,denominator=0.0,priceSlope=0.0,volSlope=0.0,sum=0.0;
   for(int j=0;j<n;j++)
   {
      double v=(double)(real?volume[first+j]:tick_volume[first+j]);
      if(v<=0.0) return false;
      double x=j-center;
      denominator+=x*x;
      priceSlope+=x*(close[first+j]-close[first]);
      volSlope+=x*v; sum+=v;
   }
   priceSlope/=denominator; volSlope/=denominator;
   double mean=sum/n;
   double decline=-volSlope*(n-1)/mean;
   // CB Buy: old downward move loses volume. CB Sell: old upward move loses volume.
   bool weakening=volSlope<0.0 && decline>=InpMinVolumeDecline;
   if(!InpStrictVolumeFilter) return weakening;
   return (buy?priceSlope<0.0:priceSlope>0.0) && weakening;
}
bool RecoveryPass(const int i,const int origin,const int direction,
                  const double &open[],const double &close[],
                  const long &tick_volume[],const long &volume[])
{
   if(!InpConfirmVolumeRecovery) return true;
   int n=InpVolumeClusterBars;
   int first=origin-n+1;
   if(first<0 || i<=origin) return false;
   if(direction==1 && close[i]<=open[i]) return false;
   if(direction==-1 && close[i]>=open[i]) return false;
   bool real=UseRealWindow(first,i,volume);
   double sum=0.0;
   for(int k=first;k<=origin;k++)
   {
      double v=(double)(real?volume[k]:tick_volume[k]);
      if(v<=0.0) return false;
      sum+=v;
   }
   double current=(double)(real?volume[i]:tick_volume[i]);
   double previous=(double)(real?volume[i-1]:tick_volume[i-1]);
   if(previous<=0.0 || current<=0.0) return false;
   bool rising=current>previous;
   bool aboveCluster=current>=InpRecoveryVolumeFactor*sum/n;
   return InpStrictVolumeFilter?(rising && aboveCluster):(rising || aboveCluster);
}
void ResetStructure()
{
   GroupProcessed=-1;
   for(int d=0;d<2;d++) { RegionFirst[d]=-1; RegionSecond[d]=-1; RegionPrice[d]=0; RegionScale[d]=0; RegionDeparted[d]=false; }
   WickProcessed=-1; LastWickBuy=-1; LastWickSell=-1;
   StructProcessed=-1; SwingHigh=0; SwingLow=0;
   SwingHighIndex=-1; SwingLowIndex=-1; LastBrokenHigh=-1; LastBrokenLow=-1;
   BuySetup=-1; SellSetup=-1; BuyBase=-1; SellBase=-1;
   BuyProtected=0; SellProtected=0; BuyPeak=false; SellTrough=false;
}
bool StructureVolumePass(const int anchor,const int pivot,const int reaction,
                         const long &tick_volume[],const long &volume[])
{
   if(InpStructureVolumeEMAFilter && !VolumeEMAPass(reaction,tick_volume,volume)) return false;
   if(!InpStructureVolumeFilter) return true;
   bool real=UseRealWindow(anchor,reaction,volume);
   double v1=(double)(real?volume[anchor]:tick_volume[anchor]);
   double v2=(double)(real?volume[pivot]:tick_volume[pivot]);
   double vr=(double)(real?volume[reaction]:tick_volume[reaction]);
   return v1>0 && v2>0 && vr>0 && v2<v1 && vr>v2;
}
void StructureBar(const int i,const double &open[],const double &high[],const double &low[],
                  const double &close[],const long &tick_volume[],const long &volume[])
{
   if(i<=StructProcessed) return;
   StructProcessed=i;
   int strength=InpStructureSwingBars,pivot=i-strength;
   if(pivot<strength) return;
   if(BuySetup>=0 && (low[i]<=BuyProtected || i-BuySetup>InpStructureMaxWait)) BuySetup=-1;
   if(SellSetup>=0 && (high[i]>=SellProtected || i-SellSetup>InpStructureMaxWait)) SellSetup=-1;
   bool ph=true,pl=true;
   for(int k=1;k<=strength;k++)
   {
      if(high[pivot]<=high[pivot-k] || high[pivot]<=high[pivot+k]) ph=false;
      if(low[pivot]>=low[pivot-k] || low[pivot]>=low[pivot+k]) pl=false;
   }
   if(ph && pl) { ph=false; pl=false; }
   // Signal 2: first pullback after a confirmed peak/trough of signal 1.
   if(ph && BuySetup>=0 && pivot>=BuySetup) BuyPeak=true;
   if(pl && SellSetup>=0 && pivot>=SellSetup) SellTrough=true;
   if(pl && BuySetup>=0 && BuyPeak && pivot>BuySetup)
   {
      if(low[pivot]>BuyProtected && close[i]>open[i] && close[i]>close[pivot] &&
         StructureVolumePass(BuyBase,pivot,i,tick_volume,volume)) RetestBuy[i]=low[i];
      BuySetup=-1; // Consume the first HL, including failed reaction/volume.
   }
   if(ph && SellSetup>=0 && SellTrough && pivot>SellSetup)
   {
      if(high[pivot]<SellProtected && close[i]<open[i] && close[i]<close[pivot] &&
         StructureVolumePass(SellBase,pivot,i,tick_volume,volume)) RetestSell[i]=high[i];
      SellSetup=-1;
   }
   bool majorHigh=ph && pivot>=InpStructureAnchorLookback;
   bool majorLow=pl && pivot>=InpStructureAnchorLookback;
   if(majorHigh || majorLow)
      for(int k=pivot-InpStructureAnchorLookback;k<pivot;k++)
      {
         if(high[pivot]<=high[k]) majorHigh=false;
         if(low[pivot]>=low[k]) majorLow=false;
      }
   if(majorHigh) { SwingHigh=high[pivot]; SwingHighIndex=pivot; }
   if(majorLow) { SwingLow=low[pivot]; SwingLowIndex=pivot; }
   // Signal 1 occurs on the breakout close, without waiting for a subsequent HL/LH.
   if(SwingHighIndex>=0 && SwingLowIndex>=0 && LastBrokenHigh!=SwingHighIndex &&
      close[i]>SwingHigh && close[i-1]<=SwingHigh)
   {
      LastBrokenHigh=SwingHighIndex;
      SellSetup=-1;
      bool move=StructureATR[SwingLowIndex]!=EMPTY_VALUE &&
                close[i]-SwingLow>=InpStructureMinMoveATR*StructureATR[SwingLowIndex];
      bool vol=!InpStructureVolumeEMAFilter || VolumeEMAPass(i,tick_volume,volume);
      if(move && low[i]>SwingLow && vol)
      {
         StructBuy[i]=low[i]; BuySetup=i; BuyBase=SwingLowIndex;
         BuyProtected=SwingLow; BuyPeak=false;
      }
   }
   if(SwingLowIndex>=0 && SwingHighIndex>=0 && LastBrokenLow!=SwingLowIndex &&
      close[i]<SwingLow && close[i-1]>=SwingLow)
   {
      LastBrokenLow=SwingLowIndex;
      BuySetup=-1;
      bool move=StructureATR[SwingHighIndex]!=EMPTY_VALUE &&
                SwingHigh-close[i]>=InpStructureMinMoveATR*StructureATR[SwingHighIndex];
      bool vol=!InpStructureVolumeEMAFilter || VolumeEMAPass(i,tick_volume,volume);
      if(move && high[i]<SwingHigh && vol)
      {
         StructSell[i]=high[i]; SellSetup=i; SellBase=SwingHighIndex;
         SellProtected=SwingHigh; SellTrough=false;
      }
   }
}
// Causal 3..N candle pattern; evaluate only once per closed bar.
void WickRetestBar(const int i,const double &open[],const double &high[],const double &low[],
                   const double &close[],const long &tick_volume[],const long &volume[])
{
   if(i<=WickProcessed) return;
   WickProcessed=i;
   bool vol=!InpWickRetestVolumeFilter || VolumeEMAPass(i,tick_volume,volume);
   bool doji=RejectLowVolumeDoji(i,open,high,low,close,tick_volume,volume);
   for(int a=i-2;a>=MathMax(InpWickExtremeLookback,i-InpWickRetestMaxBars+1);a--)
   {
      double range=high[a]-low[a];
      if(range<=0) continue;
      bool wickBottom=MathMin(open[a],close[a])-low[a]>=InpWickMinRatio*range;
      bool wickTop=high[a]-MathMax(open[a],close[a])>=InpWickMinRatio*range;
      bool bottom=true,top=true;
      for(int k=a-InpWickExtremeLookback;k<a;k++)
      {
         if(low[a]>low[k]) bottom=false;
         if(high[a]<high[k]) top=false;
      }
      double ceiling=high[a+1],floor=low[a+1];
      for(int b=a+1;b<i;b++)
      {
         ceiling=MathMax(ceiling,high[b]); floor=MathMin(floor,low[b]);
         // A retest can sweep slightly; it must still be followed by a closing breakout.
         double retestRange=high[b]-low[b];
         bool lowerWick=wickBottom || (InpWickOnRetestAllowed && retestRange>0 &&
                        MathMin(open[b],close[b])-low[b]>=InpWickMinRatio*retestRange);
         bool upperWick=wickTop || (InpWickOnRetestAllowed && retestRange>0 &&
                        high[b]-MathMax(open[b],close[b])>=InpWickMinRatio*retestRange);
         bool buy=bottom && lowerWick && a>LastWickBuy && low[b]<=low[a]+InpWickRetestTolerance*range &&
                  low[b]>=low[a]-InpWickMaxSweep*range && ceiling-low[a]>=0.5*range &&
                  close[i]>open[i] && (InpWickEarlyReaction?
                  (b==i-1 && close[i]>close[b] && close[i]>MathMax(open[b],close[b])):
                  (close[i]>ceiling && close[i-1]<=ceiling));
         bool sell=top && upperWick && a>LastWickSell && high[b]>=high[a]-InpWickRetestTolerance*range &&
                   high[b]<=high[a]+InpWickMaxSweep*range && high[a]-floor>=0.5*range &&
                   close[i]<open[i] && (InpWickEarlyReaction?
                   (b==i-1 && close[i]<close[b] && close[i]<MathMin(open[b],close[b])):
                   (close[i]<floor && close[i-1]>=floor));
         // The final close must break ALL candles after the retest as well.
         for(int k=b+1;!InpWickEarlyReaction && k<i;k++)
         {
            if(close[i]<=high[k]) buy=false;
            if(close[i]>=low[k]) sell=false;
         }
         for(int k=a+1;k<=i;k++)
         {
            if(low[k]<low[a]-InpWickMaxSweep*range) buy=false;
            if(high[k]>high[a]+InpWickMaxSweep*range) sell=false;
         }
         if(buy) { LastWickBuy=a; if(vol && !doji) WickBuy[i]=low[i]; }
         if(sell) { LastWickSell=a; if(vol && !doji) WickSell[i]=high[i]; }
      }
   }
}
// Shared arrow gate: a region is reopened only after departure AND a new confirmed extreme.
void GroupArrowBar(const int i,const double &high[],const double &low[],const double &close[])
{
   if(!InpGroupArrowsByRegion || i<=GroupProcessed) return;
   GroupProcessed=i;
   int strength=InpStructureSwingBars,pivot=i-strength;
   for(int d=0;d<2;d++)
   {
      if(RegionFirst[d]>=0)
      {
         if((d==0?close[i]-RegionPrice[d]:RegionPrice[d]-close[i])>=
            InpRegionDepartureATR*RegionScale[d]) RegionDeparted[d]=true;
         bool extreme=pivot>=strength && pivot>=InpStructureAnchorLookback && pivot>RegionFirst[d];
         if(extreme)
         {
            for(int k=1;k<=strength;k++)
               if(d==0?(low[pivot]>=low[pivot-k] || low[pivot]>=low[pivot+k]):
                        (high[pivot]<=high[pivot-k] || high[pivot]<=high[pivot+k])) extreme=false;
            for(int k=pivot-InpStructureAnchorLookback;k<pivot;k++)
               if(d==0?low[pivot]>low[k]:high[pivot]<high[k]) extreme=false;
         }
         double candidate=pivot>=0?(d==0?low[pivot]:high[pivot]):0;
         if(extreme && RegionDeparted[d] && MathAbs(candidate-RegionPrice[d])>=
            InpRegionNewExtremeATR*RegionScale[d])
         { RegionFirst[d]=-1; RegionSecond[d]=-1; RegionDeparted[d]=false; }
      }
      bool wick=(d==0?WickBuy[i]:WickSell[i])!=EMPTY_VALUE;
      bool structure=(d==0?StructBuy[i]:StructSell[i])!=EMPTY_VALUE;
      bool confirmed=(d==0?ConfirmedBuy[i]:ConfirmedSell[i])!=EMPTY_VALUE;
      bool second=(d==0?RetestBuy[i]:RetestSell[i])!=EMPTY_VALUE;
      bool keepWick=false,keepStructure=false,keepConfirmed=false,keepSecond=false;
      if(RegionFirst[d]<0 && (wick || structure || confirmed))
      {
         // Same-bar preference: specific wick setup, then structure, then CB confirmation.
         keepWick=wick; keepStructure=!wick && structure; keepConfirmed=!wick && !structure && confirmed;
         RegionFirst[d]=i; RegionSecond[d]=-1; RegionDeparted[d]=false;
         int first=MathMax(0,i-InpStructureAnchorLookback);
         RegionPrice[d]=d==0?low[first]:high[first];
         for(int k=first+1;k<=i;k++) RegionPrice[d]=d==0?MathMin(RegionPrice[d],low[k]):MathMax(RegionPrice[d],high[k]);
         double scale=StructureATR[i];
         RegionScale[d]=(scale!=EMPTY_VALUE && scale>0)?scale:MathMax(high[i]-low[i],_Point);
      }
      if(second && RegionFirst[d]>=0 && i>RegionFirst[d] && RegionSecond[d]<0)
      { keepSecond=true; RegionSecond[d]=i; }
      if(d==0)
      {
         if(!keepWick) WickBuy[i]=EMPTY_VALUE;
         if(!keepStructure) StructBuy[i]=EMPTY_VALUE;
         if(!keepConfirmed) ConfirmedBuy[i]=EMPTY_VALUE;
         if(!keepSecond) RetestBuy[i]=EMPTY_VALUE;
      }
      else
      {
         if(!keepWick) WickSell[i]=EMPTY_VALUE;
         if(!keepStructure) StructSell[i]=EMPTY_VALUE;
         if(!keepConfirmed) ConfirmedSell[i]=EMPTY_VALUE;
         if(!keepSecond) RetestSell[i]=EMPTY_VALUE;
      }
   }
}
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   if(rates_total<1) return 0;
   ArraySetAsSeries(time,false); ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false); ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
   ArraySetAsSeries(tick_volume,false); ArraySetAsSeries(volume,false);
   bool reset=prev_calculated<=0 || prev_calculated>rates_total || FirstTime!=time[0];
   FirstTime=time[0];
   bool changed=reset;
   if(reset)
   {
      ArrayInitialize(DisplayUp,EMPTY_VALUE); ArrayInitialize(DisplayDown,EMPTY_VALUE);
      ArrayInitialize(DisplayBuy,EMPTY_VALUE); ArrayInitialize(DisplaySell,EMPTY_VALUE);
      ShownCount=0;
      ArrayInitialize(DisplayStructBuy,EMPTY_VALUE); ArrayInitialize(DisplayStructSell,EMPTY_VALUE);
      ArrayInitialize(StructBuy,EMPTY_VALUE); ArrayInitialize(StructSell,EMPTY_VALUE);
      ArrayInitialize(StructureATR,EMPTY_VALUE);
      ArrayInitialize(TickVolumeEMA,EMPTY_VALUE); ArrayInitialize(RealVolumeEMA,EMPTY_VALUE);
      ArrayInitialize(RetestBuy,EMPTY_VALUE); ArrayInitialize(RetestSell,EMPTY_VALUE);
      ArrayInitialize(DisplayRetestBuy,EMPTY_VALUE); ArrayInitialize(DisplayRetestSell,EMPTY_VALUE);
      ArrayInitialize(WickBuy,EMPTY_VALUE); ArrayInitialize(WickSell,EMPTY_VALUE);
      ArrayInitialize(DisplayWickBuy,EMPTY_VALUE); ArrayInitialize(DisplayWickSell,EMPTY_VALUE);
      ResetDisplayCache();
      ResetStructure();
      ArrayInitialize(Up,EMPTY_VALUE); ArrayInitialize(Down,EMPTY_VALUE);
      ArrayInitialize(StrongWideWick,EMPTY_VALUE);
      ArrayInitialize(ConfirmedBuy,EMPTY_VALUE); ArrayInitialize(ConfirmedSell,EMPTY_VALUE);
      ArrayInitialize(PendingDirection,0); ArrayInitialize(PendingHigh,0);
      ArrayInitialize(PendingLow,0); ArrayInitialize(PendingIndex,0);
      if(Prefix!="") ObjectsDeleteAll(0,Prefix,0,-1);
   }
   else
   {
      // MT5 may grow buffers without initializing their new cells.
      for(int i=prev_calculated;i<rates_total;i++)
      {
         DisplayStructBuy[i]=EMPTY_VALUE; DisplayStructSell[i]=EMPTY_VALUE;
         StructureATR[i]=EMPTY_VALUE;
         TickVolumeEMA[i]=EMPTY_VALUE; RealVolumeEMA[i]=EMPTY_VALUE;
         WickBuy[i]=EMPTY_VALUE; WickSell[i]=EMPTY_VALUE;
         DisplayWickBuy[i]=EMPTY_VALUE; DisplayWickSell[i]=EMPTY_VALUE;
         RetestBuy[i]=EMPTY_VALUE; RetestSell[i]=EMPTY_VALUE;
         DisplayRetestBuy[i]=EMPTY_VALUE; DisplayRetestSell[i]=EMPTY_VALUE;
         StructBuy[i]=EMPTY_VALUE; StructSell[i]=EMPTY_VALUE;
         DisplayUp[i]=EMPTY_VALUE; DisplayDown[i]=EMPTY_VALUE;
         DisplayBuy[i]=EMPTY_VALUE; DisplaySell[i]=EMPTY_VALUE;
         Up[i]=EMPTY_VALUE; Down[i]=EMPTY_VALUE;
         StrongWideWick[i]=EMPTY_VALUE;
         ConfirmedBuy[i]=EMPTY_VALUE; ConfirmedSell[i]=EMPTY_VALUE;
         PendingDirection[i]=0; PendingHigh[i]=0; PendingLow[i]=0; PendingIndex[i]=0;
      }
   }
   if(!InpEnabled) return rates_total;
   int start=reset?2:MathMax(2,prev_calculated-1);
   TrimDisplayCache(start);
   // Calculate from zero on rebuild so EMA1/EMA2 periods also work correctly.
   if(InpUseC7CB ||
      (InpUseStructure12 && InpStructureVolumeEMAFilter) ||
      (InpUseWickRetest && InpWickRetestVolumeFilter))
      for(int j=reset?0:start;j<rates_total;j++)
      {
         TickVolumeEMA[j]=NextVolumeEMA(j,tick_volume,TickVolumeEMA);
         if(InpUseRealVolume) RealVolumeEMA[j]=NextVolumeEMA(j,volume,RealVolumeEMA);
      }
   for(int i=start;i<rates_total;i++)
   {
      double oldUp=Up[i],oldDown=Down[i],oldBuy=ConfirmedBuy[i],oldSell=ConfirmedSell[i];
      double oldStrongWick=StrongWideWick[i];
      ConfirmedBuy[i]=EMPTY_VALUE; ConfirmedSell[i]=EMPTY_VALUE;
      StrongWideWick[i]=EMPTY_VALUE;
      int direction=(int)PendingDirection[i-1];
      double triggerHigh=PendingHigh[i-1],triggerLow=PendingLow[i-1];
      int origin=(int)PendingIndex[i-1];
      bool closed=(i<rates_total-1);
      // Only closed CB candles arm the confirmation engine. No future-bar lookahead.
      if(InpUseC7CB && closed && direction!=0 && InpEnableConfirmation)
      {
         if(i-origin>InpConfirmationBars) direction=0;
         else if(InpInvalidateOnOppositeClose &&
                 ((direction==1 && close[i]<triggerLow) ||
                  (direction==-1 && close[i]>triggerHigh))) direction=0;
         else if(direction==1 && close[i]>triggerHigh &&
                 RecoveryPass(i,origin,direction,open,close,tick_volume,volume))
         { ConfirmedBuy[i]=low[i]; direction=0; }
         else if(direction==-1 && close[i]<triggerLow &&
                 RecoveryPass(i,origin,direction,open,close,tick_volume,volume))
         { ConfirmedSell[i]=high[i]; direction=0; }
      }
      int n1=i-2,n2=i-1;
      bool allowed=InpUseC7CB && !(InpClosedBarsOnly && i==rates_total-1);
      bool buy=false,sell=false,allThreeWicks=false;
      if(allowed) C7CBSignalPattern(i,open,high,low,close,tick_volume,volume,buy,sell,allThreeWicks);
      // Reject before arming confirmation: rejected CB cannot replace the pending setup.
      // Low volume alone or doji alone is not sufficient to reject a signal.
      if((buy || sell) && RejectLowVolumeDoji(i,open,high,low,close,tick_volume,volume))
      { buy=false; sell=false; }
      // Volume qualifies when it rises across all 3 candles OR all 3 are high vs EMA20.
      if((buy || sell) && !OriginalVolumePatternPass(i,tick_volume,volume))
      { buy=false; sell=false; }
      if((buy || sell) && InpUseCBVolumeEMAFilter && !VolumeEMAPass(i,tick_volume,volume))
      { buy=false; sell=false; }
      // Added reversal branch: high volume is mandatory regardless of the
      // optional legacy EMA filter. Existing C7CB keeps its original filters.
      if(!buy && !sell) allThreeWicks=false;
      bool reversalBuy=false,reversalSell=false;
      if(allowed)
         HighVolumeReversal(i,open,high,low,close,tick_volume,volume,reversalBuy,reversalSell);
      if((reversalBuy || reversalSell) &&
         RejectLowVolumeDoji(i,open,high,low,close,tick_volume,volume))
      { reversalBuy=false; reversalSell=false; }
      buy=buy || reversalBuy; sell=sell || reversalSell;
      // Contradictory families must not arm an arbitrary direction.
      if(buy && sell) { buy=false; sell=false; allThreeWicks=false; }
      if(InpFilterEarlyTicks && buy && !ClusterPass(i,true,close,tick_volume,volume)) buy=false;
      if(InpFilterEarlyTicks && sell && !ClusterPass(i,false,close,tick_volume,volume)) sell=false;
      if((buy || sell) && allThreeWicks) StrongWideWick[i]=1.0;
      if(oldStrongWick!=StrongWideWick[i]) changed=true;
      Up[i]=buy?low[i]:EMPTY_VALUE;
      Down[i]=sell?high[i]:EMPTY_VALUE;
      // Newest closed CB replaces any older pending CB, in either direction.
      // Check the existing setup first so same-bar confirmation is not lost.
      if(closed && InpEnableConfirmation && (buy || sell))
      { direction=buy?1:-1; triggerHigh=high[i]; triggerLow=low[i]; origin=i; }
      PendingDirection[i]=direction;
      PendingHigh[i]=triggerHigh; PendingLow[i]=triggerLow; PendingIndex[i]=origin;
      if((InpUseStructure12 || InpGroupArrowsByRegion) && i>=InpStructureATRPeriod)
      {
         double tr=MathMax(high[i]-low[i],MathMax(MathAbs(high[i]-close[i-1]),MathAbs(low[i]-close[i-1])));
         if(i==InpStructureATRPeriod)
         {
            double total=0;
            for(int k=1;k<=InpStructureATRPeriod;k++)
               total+=MathMax(high[k]-low[k],MathMax(MathAbs(high[k]-close[k-1]),MathAbs(low[k]-close[k-1])));
            StructureATR[i]=total/InpStructureATRPeriod;
         }
         else StructureATR[i]=(StructureATR[i-1]*(InpStructureATRPeriod-1)+tr)/InpStructureATRPeriod;
      }
      double oldWickBuy=WickBuy[i],oldWickSell=WickSell[i];
      if(InpUseWickRetest && closed) WickRetestBar(i,open,high,low,close,tick_volume,volume);

      double oldRetestBuy=RetestBuy[i],oldRetestSell=RetestSell[i];
      double oldStructBuy=StructBuy[i],oldStructSell=StructSell[i];
      if(InpUseStructure12 && closed) StructureBar(i,open,high,low,close,tick_volume,volume);
      if(closed) GroupArrowBar(i,high,low,close);
      if(oldWickBuy!=WickBuy[i] || oldWickSell!=WickSell[i]) changed=true;
      if(oldRetestBuy!=RetestBuy[i] || oldRetestSell!=RetestSell[i]) changed=true;
      if(oldStructBuy!=StructBuy[i] || oldStructSell!=StructSell[i]) changed=true;
      bool upChanged=(oldUp!=Up[i]),downChanged=(oldDown!=Down[i]);
      if(upChanged || downChanged || oldBuy!=ConfirmedBuy[i] || oldSell!=ConfirmedSell[i]) changed=true;
      if(!IndexDisplayBar(i))
      {
         Print("C7CB: display index allocation failed; rebuild on next event");
         return 0;
      }
      if(InpShowHistory)
      {
         DisplayWickBuy[i]=WickBuy[i]; DisplayWickSell[i]=WickSell[i];
         DisplayRetestBuy[i]=RetestBuy[i]; DisplayRetestSell[i]=RetestSell[i];
         DisplayStructBuy[i]=StructBuy[i]; DisplayStructSell[i]=StructSell[i];
         DisplayUp[i]=Up[i]; DisplayDown[i]=Down[i];
         DisplayBuy[i]=ConfirmedBuy[i]; DisplaySell[i]=ConfirmedSell[i];


      }
   }
   if(!InpShowHistory && changed) RefreshRecent(rates_total,time,low,high);
   RefreshStrongWideWickMarks(rates_total,time,low,high);
   RefreshEntryContexts(rates_total,time,open,high,low,close,tick_volume,volume);
   if(reset && InpDebugSummary)
   {
      int cbCount=0,confirmedCount=0,structureCount=0,retestCount=0,wickCount=0,lastSignal=-1;
      int rawCBCount=0,volumeRisePassCount=0,volumeRiseBlockedCount=0;
      for(int k=2;k<rates_total;k++)
      {
         if(InpUseC7CB && k<rates_total-1)
         {
            bool rawBuy=false,rawSell=false,rawAllThreeWicks=false;
            C7CBSignalPattern(k,open,high,low,close,tick_volume,volume,rawBuy,rawSell,rawAllThreeWicks);
            if(rawBuy || rawSell)
            {
               rawCBCount++;
               if(OriginalVolumePatternPass(k,tick_volume,volume)) volumeRisePassCount++;
               else volumeRiseBlockedCount++;
            }
         }
         if(Up[k]!=EMPTY_VALUE || Down[k]!=EMPTY_VALUE) { cbCount++; lastSignal=k; }
         if(ConfirmedBuy[k]!=EMPTY_VALUE || ConfirmedSell[k]!=EMPTY_VALUE)
         { confirmedCount++; lastSignal=k; }
         if(StructBuy[k]!=EMPTY_VALUE || StructSell[k]!=EMPTY_VALUE) { structureCount++; lastSignal=k; }
         if(RetestBuy[k]!=EMPTY_VALUE || RetestSell[k]!=EMPTY_VALUE) { retestCount++; lastSignal=k; }
         if(WickBuy[k]!=EMPTY_VALUE || WickSell[k]!=EMPTY_VALUE) { wickCount++; lastSignal=k; }
      }
      string last=lastSignal>=0?TimeToString(time[lastSignal],TIME_DATE|TIME_MINUTES):"NONE";
      PrintFormat("C7CB v1.73 | bars=%d raw3=%d vol3_pass=%d vol3_block=%d CB=%d confirmed=%d structure=%d retest=%d wick=%d group=%s history=%s latest=%s",
                  rates_total,rawCBCount,volumeRisePassCount,volumeRiseBlockedCount,cbCount,confirmedCount,structureCount,retestCount,wickCount,InpGroupArrowsByRegion?"ON":"OFF",InpShowHistory?"ON":"last5",last);
   }
   int c=rates_total-2;
   if(c>=0)
   {
      if(reset || LastClosed==0) LastClosed=time[c];
      else if(time[c]>LastClosed)
      {
         LastClosed=time[c];
         if(InpDebugNewBars && c>=2)
         {
            bool rawBuy=false,rawSell=false;
            bool rawAllThreeWicks=false;
            C7CBSignalPattern(c,open,high,low,close,tick_volume,volume,rawBuy,rawSell,rawAllThreeWicks);
            bool rejected=(rawBuy || rawSell) && RejectLowVolumeDoji(c,open,high,low,close,tick_volume,volume);
            bool volumeRejected=(rawBuy || rawSell) && InpUseCBVolumeEMAFilter && !VolumeEMAPass(c,tick_volume,volume);
            bool volumeRiseRejected=(rawBuy || rawSell) && !OriginalVolumePatternPass(c,tick_volume,volume);
            string raw=rawBuy?"BUY":(rawSell?"SELL":"NONE");
            string accepted=Up[c]!=EMPTY_VALUE?"BUY":(Down[c]!=EMPTY_VALUE?"SELL":"NONE");
            string confirmed=ConfirmedBuy[c]!=EMPTY_VALUE?"BUY":(ConfirmedSell[c]!=EMPTY_VALUE?"SELL":"NONE");
            PrintFormat("C7CB LIVE | closed=%s raw=%s doji_block=%s volume_ema_block=%s volume3_block=%s tick=%s confirmed=%s pending=%d",
                        TimeToString(time[c],TIME_DATE|TIME_MINUTES),raw,rejected?"YES":"NO",volumeRejected?"YES":"NO",volumeRiseRejected?"YES":"NO",accepted,confirmed,(int)PendingDirection[c]);
         }
         if(StructBuy[c]!=EMPTY_VALUE || StructSell[c]!=EMPTY_VALUE)
         {
            string msg=StringFormat("C7CB SIGNAL 1 HH/LL %s | %s %s | %s",StructBuy[c]!=EMPTY_VALUE?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(msg);
            if(InpEnablePush) SendNotification(msg);
         }
         if(RetestBuy[c]!=EMPTY_VALUE || RetestSell[c]!=EMPTY_VALUE)
         {
            string msg=StringFormat("C7CB SIGNAL 2 HL/LH %s | %s %s | %s",RetestBuy[c]!=EMPTY_VALUE?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(msg);
            if(InpEnablePush) SendNotification(msg);
         }
         if(WickBuy[c]!=EMPTY_VALUE || WickSell[c]!=EMPTY_VALUE)
         {
            string msg=StringFormat("C7CB WICK RETEST %s | %s %s | %s",WickBuy[c]!=EMPTY_VALUE?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(msg);
            if(InpEnablePush) SendNotification(msg);
         }
         string side="";
         if(ConfirmedBuy[c]!=EMPTY_VALUE) side="BUY";
         if(ConfirmedSell[c]!=EMPTY_VALUE) side="SELL";
         if(side!="")
         {
            string message=StringFormat("C7CB CONFIRMED %s | %s %s | %s",side,_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(message);
            if(InpEnablePush) SendNotification(message);
         }
      }
   }
   return rates_total;
}
