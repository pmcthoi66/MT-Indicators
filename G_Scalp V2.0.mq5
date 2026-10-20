//+------------------------------------------------------------------+
//| G_Scalp_m5 V2.0 - PVT_AI                                         |
//| EMA9 phát tín hiệu <=160 độ; chuỗi PA gốc xác nhận cùng/ngay sau.    |
//+------------------------------------------------------------------+
#property copyright "PVT_AI"
#property version "2.57"
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input group "01. Entry moi - nen da dong"
input bool InpEnableTrading=false;      // Auto mặc định OFF; vẫn bấm BUY/SELL tay và quản lý SL, BE, TP. Muốn bật Auto thì đổi Input này; không có nút AUTO trên chart.
input ENUM_TIMEFRAMES InpTF=PERIOD_M5;   // Khung tín hiệu, mặc định M5.
input bool InpUseEMA9Entry=true;       // ON: EMA9 phát tín hiệu trước PA; OFF: chỉ dùng chuỗi PA của bản gốc.
input bool InpEMA9AllowNextBar=true;    // Cho PA xác nhận ở nến kế tiếp; OFF chỉ nhận PA ngay trên nến EMA9 phát tín hiệu.
input bool InpEMA9UseCurl=true;         // Nhận EMA9 cuộn lên/xuống; góc cuộn cũng phải <= EntryAngle.
input double InpEMA9EntryAngle=160.0;   // Góc trong <=160 độ: nhận sớm khi EMA9 bắt đầu gấp/cuộn lên BUY, xuống SELL; chuẩn hóa theo ATR.
input int InpEMA9TurnBars=3;            // So hướng trung bình 3 nến EMA9 trước với đoạn vừa đóng.
input double InpEMA9AngleScaleATR=0.10; // Quy đổi góc: 1 nến ngang / 0.1 ATR dọc; không phụ thuộc zoom chart.
input double InpEMA9MinSlopeATR=0.04;   // EMA9 phải tiếp tục theo hướng lệnh >=0.04 ATR/nến khi PA xác nhận.
input double InpEMA9FlatATR=0.03;       // Nhịp trước cuộn được coi gần ngang nếu độ dốc <=0.03 ATR.
input bool InpEMA9FilterChop=true;     // Bỏ EMA9 lên-xuống-lên hoặc xuống-lên-xuống trong đoạn ngắn.
input int InpEMA9ChopBars=6;           // Xét 6 đoạn EMA9 đã đóng; bỏ nếu có ít nhất 2 lần đổi hướng đáng kể.
input double InpEMA9ChopRangeATR=0.50;// Chỉ chặn nhiều lần đảo hướng khi EMA9 cuộn trong vùng rộng <=0.5 ATR.
input bool InpEMA9PullbackRearm=true;  // E1 bị bỏ: xét E2 khi EMA9 tăng dốc lại sau pullback, vẫn cần PA và cực trị rõ.
const int PA_CONFIRM_BARS=2;            // Cố định PA 2 nến xác nhận sau tín hiệu EMA9; không còn lựa chọn PA 3 nến.
input bool InpUsePA2=true;             // PA 2 nến: BUY đỉnh sau thấp hơn; SELL đáy sau cao hơn, tính cả râu.
input bool InpUseEngulfing=true;       // Engulfing tăng xác nhận BUY; Engulfing giảm xác nhận SELL sau khi nến đóng.
input bool InpUseStar=true;            // Morning Star xác nhận BUY; Evening Star xác nhận SELL, nến giữa ở cực trị.
input bool InpUseBreakoutPA=true;      // PA mới: đóng phá cụm hồi; chỉ dùng khi EMA9 bật và phát tín hiệu đúng hướng/góc.
input bool InpUseEMA9ReclaimPA=true;   // PA sớm: BUY đóng trên EMA9 sau nến đóng dưới hoặc bằng EMA9; SELL ngược lại, vẫn cần góc EMA9.
input int InpBreakoutBars=3;           // Cụm hồi gồm 3 nến đã đóng trước nến xác nhận; phá toàn bộ râu của cụm.
input bool InpFilterAlternating=true; // Bỏ 1 xanh/1 đỏ hoặc 2 xanh/2 đỏ lặp lại trước nến xác nhận; không thay TP.
input int InpAlternatingLookback=8;    // Xét tối đa 8 nến trước tín hiệu; chặn từ 4 cụm đổi màu, mỗi cụm 1-2 nến.
input bool InpFilterEntryCandle=true;  // Bỏ nến xác nhận ngược màu, thân nhỏ, hai râu dài hoặc râu ngược hướng quá dài.
input double InpEntryMinBodyATR=0.15;   // Thân nến xác nhận tối thiểu 0.15 ATR.
input double InpEntryOppWickRatio=2.0;  // BUY bỏ râu trên >=2 thân; SELL bỏ râu dưới >=2 thân.
input bool InpRequireEntryExtreme=true;// Chỉ xác nhận PA tại đỉnh/đáy của vùng gần nhất, tính toàn bộ râu.
input int InpEntryExtremeLookback=5;   // Tìm đỉnh/đáy cục bộ trong 3 nến gần nhất, so với 5 nến cũ hơn.
input double InpEntryProminenceATR=0.30;// Nhịp tới cực trị và nhịp bật khỏi cực trị đều phải >=0.3 ATR.
input double InpDojiBodyRatio=0.15;     // Doji: thân <= 15% chiều dài cả râu; bỏ trong và ngay trước chuỗi.
input double InpStarMiddleRatio=0.50;   // Star: thân giữa <= 50% thân đầu; thân cuối >= 50% thân đầu.
input bool InpLog=true;                 // In Entry, TP, SL, dời SL và lý do bỏ lệnh.

input group "01b. Phan tich va setup Entry SL TP1 TP2 TP3"
input bool InpShowEntrySetup=true;      // Chỉ vẽ 5 đường Entry/SL/TP1/TP2/TP3 khi có tín hiệu đã đóng; không chữ, vùng màu hay tự mở lệnh.
input double InpSetupTP1_R=1.0;         // TP1 gợi ý = 1R; R là khoảng cách Entry đến SL của setup.
input double InpSetupTP2_R=2.0;         // TP2 gợi ý = 2R; không tự chốt từng phần tại mức này.
input double InpSetupTP3_R=3.0;         // TP3 gợi ý = 3R; quản lý thoát thực tế vẫn theo SL/BE/TP hiện tại.
input int InpSetupValidSeconds=300;     // Setup hiện trong 5 phút hoặc ẩn khi vào lệnh; chỉ là thời gian hiển thị, không thay SL/BE/TP.
input int InpSetupLineBars=5;           // Đường dài 5 nến theo khung chart đang mở; không đổi khung tín hiệu InpTF.
input bool InpSetupContext=true;        // Đọc bối cảnh mỗi setup trong tooltip các đường và tab Experts; không thêm chữ che nến, không lọc thêm Entry.


input int InpSetupVolumeBars=20;        // Nền tick volume trước 6 nến đã đóng; 4 nến đọc nhịp trước, ưu tiên 2 nến cuối; tối thiểu cần 5 nến nền. Chỉ đọc bối cảnh.
input double InpSetupVolumeHigh=1.5;    // Volume cao từ 1.5 lần nền; không phải điều kiện chặn Entry.
input double InpSetupVolumeLow=0.7;     // Volume thấp dưới 0.7 lần nền; kết hợp vị trí close và biên độ nến.

input group "02. SL theo cau truc va bien dong"
input bool InpAutoScanSL=true;          // Tự quét và gắn SL cho vị thế đang mở chưa có SL; vẫn chạy khi Auto Entry OFF.
input bool InpManageManualPositions=true; // Quản lý cả lệnh tay Magic=0 trên symbol hiện tại bằng SL/BE/TP; không đụng EA khác Magic.
input int InpATRPeriod=14;              // ATR dùng cho đệm SL, giới hạn khoảng cách và bảo vệ lợi nhuận.
input int InpSwingLookback=40;          // Số nến cũ tìm swing đã xác nhận trước Entry.
input int InpSwingStrength=2;           // Mỗi phía swing cần 2 nến đã đóng; không đọc nến tương lai.
input double InpSLBufferATR=0.10;       // Đệm ngoài swing/chuỗi; đệm thực còn xét spread và tick size.
input double InpMinSL_ATR=0.50;         // SL tối thiểu 0.5 ATR từ Entry; chỉ nới ra ngoài mốc bảo vệ.
input double InpMaxSL_ATR=3.00;         // Mốc quá xa thì thử swing khác, rồi cực trị chuỗi; không ép SL vào trong mốc.
input bool InpBreakEven=true;           // Dời SL về Entry khi giá chạy đủ khoảng cách ATR.
input double InpBreakEvenATR=0.60;      // Ngưỡng ATR tối thiểu; BE cần đạt cả ngưỡng này VÀ số R bên dưới, không chỉ chạy đủ ATR.
input double InpBreakEvenMinR=1.0;      // Chỉ về BE khi chạy thuận ít nhất 1R = khoảng cách Entry tới SL ban đầu; 0 dùng riêng ATR như bản cũ.

input group "02b. Thoat som va lua chon TP"
input bool InpTPWickVolume=true;       // TP mới: lệnh dương + râu thoái lui dài hơn thân + volume cao + nến trước có ÍT NHẤT MỘT râu dài hơn thân. ON thay toàn bộ TP cũ.
input bool InpTPWickIntrabar=false;    // OFF: chốt ngay khi nến tín hiệu đóng. ON: xét nến đang chạy, không chờ đóng; mẫu có thể thay đổi theo tick.
input double InpTPWickBodyRatio=1.0;   // Nến tín hiệu: BUY râu trên/SELL râu dưới >1 thân; nến trước: ÍT NHẤT MỘT râu >1 thân. Doji dùng thân tối thiểu 1 tick.
input int InpTPVolumeBars=20;          // Nền tick volume 20 nến đã đóng trước hai nến tín hiệu; không đọc nến tương lai.
input double InpTPVolumeHigh=1.5;      // Volume nến tín hiệu >=1.5 lần nền; không bắt nến trước cũng volume cao. TP mới chỉ đóng khi đang dương.
input bool InpTP2Candles=true;          // ON: TP sau 2 nến không vượt đỉnh BUY/đáy SELL, tính râu; thay TP EMA9, không cần BE. OFF: TP EMA9 cũ.
input bool InpHoldUntilEMA9Cross=false;// Giữ BUY khi close >=EMA9, SELL khi close <=EMA9; tín hiệu thoát phải đóng sang phía đối diện. SL/BE vẫn chạy.
input bool InpExitOppositeBeforeBE=true;// Cắt lỗ sớm 1 nến chỉ khi lệnh đang ÂM và nến ngược màu + EMA9 yếu/đảo hướng; dương/hòa vốn thì giữ theo TP.
input bool InpTPOnlyProfit=true;        // TP theo 2 nến hoặc EMA9 chỉ gửi đóng khi lệnh đang DƯƠNG; OFF khôi phục thoát theo tín hiệu bất kể lời/lỗ. Không chặn SL broker.
input double InpEarlyExitMaxSlopeATR=0.10; // Dốc theo hướng lệnh <=0.10 ATR là yếu; EMA9 đảo hướng cũng được đóng khi nến ngược màu.
input double InpEarlyExitSlopeRatio=0.65; // Hoặc dốc còn <=65% đoạn trước (giảm >=35% và >=0.02 ATR): đóng khi nến ngược màu.
input bool InpTPAfterBE_EMA9=true;      // SL đã về Entry hoặc tốt hơn: chỉ thoát theo EMA9 chuyển ngang/đảo hướng.
input double InpTP_EMA9Angle=170.0;     // Sau BE: thoát khi EMA9 gấp giảm dốc <=170 độ, không đợi đảo chiều hoàn toàn.
input double InpTP_EMA9FlatATR=0.05;    // Sau BE: EMA9 chuyển từ dốc theo lệnh sang ngang, |độ dốc| <=0.05 ATR/nến.

input bool InpTPFastDeceleration=true; // ON: sau BE thoát sớm khi độ dốc EMA9 giảm mạnh so với đoạn liền trước.
input double InpTPDecelerationRatio=0.35; // Giảm ít nhất 35% độ dốc trước và 0.02 ATR; không thoát vì rung nhẹ.
input bool InpTPIntrabar=true;          // Sau BE: xét EMA9 đang chạy theo tick để TP sớm, không đợi đóng nến; OFF chỉ xét EMA9 đã đóng.
input double InpTPPullbackATR=0.15;     // TP theo tick chỉ khi giá hồi >=0.15 ATR lúc Entry từ mức chạy thuận tốt nhất được EA theo dõi.

input group "03. Lich su khi test"
input bool InpShowHistory=false;         // Hiện/ẩn lịch sử khi test; nút Hist ON/OFF trên chart, Inputs luôn dùng được.
input double InpDashboardScale=0.80;    // Dashboard nhỏ một hàng sát mép trên; 1.00 là kích thước gọn mặc định.
input int InpDashboardShiftLeft=0;    // Dịch cả hàng nút sang trái, pixel; 265 px xấp xỉ 7 cm ở tỷ lệ hiển thị 100%.

input group "04. Risk va gui lenh"
input bool InpUseRiskManagement=false; // Tạm OFF để test SL/TP/BE bằng lot cố định; ON khôi phục tính lot theo % equity như bản gốc.
input double InpFixedLot=0.01;         // Lot khi Risk OFF; dưới min broker thì dùng min, trên max thì dùng max, làm tròn theo bước lot.
input double InpRiskPercent=0.5;       // Rủi ro dự kiến mỗi lệnh theo equity; không ép lên lot tối thiểu.
input double InpMaxLot=0.50;            // Trần lot; 0 dùng trần broker.
input double InpCommissionPerLot=0.0;   // Phí cả mở và đóng cho 1 lot, theo tiền tài khoản; nhập phí broker.
input int InpSlippagePoints=30;         // Độ lệch giá yêu cầu, tính theo point.
input int InpRiskReservePoints=30;      // Dự phòng trượt giá SL khi tính lot; không bảo đảm trượt giá thực tế.
input long InpMagic=26101020;           // Mã riêng của V2.0; chỉ quản lý vị thế có symbol và Magic này.

int hATR=INVALID_HANDLE,hEMA9=INVALID_HANDLE;
int hSetupEMA21=INVALID_HANDLE; // Chỉ dùng đọc bối cảnh, độc lập với Entry và TP.
datetime g_confirmTime=0;
bool g_confirmBuy=false;
datetime g_bar=0,g_attemptBar=0,g_exitBar=0,g_exitRetry=0,g_beRetry=0;
datetime g_exitCheckBar=0;             // Chỉ đánh dấu đã xét thoát khi dữ liệu EMA/ATR đầy đủ; thiếu thì thử lại cùng nến.
datetime g_slScanRetry=0;
datetime g_slScanNotice=0;
double g_atr=0.0,g_beEntryATR=0.0;
long g_bePositionID=0;
long g_beRiskPositionID=0;
double g_beInitialRisk=0.0;
long g_tpPositionID=0;
double g_tpPeakMove=0.0;
long g_extremePositionID=0;
datetime g_extremeLastTime=0;
double g_tpExtreme=0.0;
int g_noNewExtremeBars=0;
datetime g_wickTPCheck=0;
ulong g_pending[];
int g_pendingMode[]; // 0: đóng tay/bất kỳ; 1: chỉ cắt lỗ khi âm; 2: chỉ TP khi dương.
bool g_showHistory=true,g_nativeHistory=false;
string g_historyPrefix="",g_historyButton="";
ulong g_historyPoll=0;
bool g_autoTrading=false;
bool g_manualSending=false;           // Khóa trong lúc gửi lệnh tay; không khóa cả nến sau khi vị thế đã đóng.
string g_setupPrefix="",g_setupContext="";
bool g_setupActive=false,g_setupBuy=false;
datetime g_setupBar=0,g_setupPublishedAt=0;
datetime g_analysisBar=0,g_analysisConfirmTime=0;
bool g_analysisConfirmBuy=false;
double g_setupEntry=0.0,g_setupSL=0.0,g_setupTP1=0.0,g_setupTP2=0.0,g_setupTP3=0.0;
string g_panelPrefix="",g_panelMessage="San sang vao lenh tay";
ulong g_panelPoll=0,g_panelRefresh=0;

bool ValidNumber(const double x) { return MathIsValidNumber(x)&&x!=EMPTY_VALUE&&x>0.0; }
bool Tester() { return (bool)MQLInfoInteger(MQL_TESTER); }
bool OwnPosition()
  {
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return false;
   long magic=PositionGetInteger(POSITION_MAGIC);
   return magic==InpMagic||(InpManageManualPositions&&magic==0);
  }
bool AnyPositionOnSymbol()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   return false; // Chỉ một vị thế trên symbol, không mở đối ứng với EA khác hoặc lệnh tay.
  }
void Log(const string text) { if(InpLog) Print("GS2 | ",text); }

bool Doji(const MqlRates &r[],const int i)
  {
   double range=r[i].high-r[i].low;
   return range<=0.0||MathAbs(r[i].close-r[i].open)<=range*InpDojiBodyRatio;
  }
bool Star(const MqlRates &r[],const int end,const bool morning)
  {
   if(end<1||end+2>=ArraySize(r)) return false;
   double first=MathAbs(r[end+2].close-r[end+2].open);
   double middle=MathAbs(r[end+1].close-r[end+1].open);
   double last=MathAbs(r[end].close-r[end].open);
   if(first<=0.0||middle>first*InpStarMiddleRatio||last<first*0.50) return false;
   double midpoint=(r[end+2].open+r[end+2].close)*0.50;
   if(morning)
      return r[end+2].close<r[end+2].open&&r[end].close>r[end].open&&
             r[end+1].low<=MathMin(r[end+2].low,r[end].low)&&r[end].close>midpoint;
   return r[end+2].close>r[end+2].open&&r[end].close<r[end].open&&
          r[end+1].high>=MathMax(r[end+2].high,r[end].high)&&r[end].close<midpoint;
  }
bool PA2Signal(const MqlRates &r[],const bool buy,string &reason)
  {
   reason="";
   if(ArraySize(r)<PA_CONFIRM_BARS+4) { reason="THIEU_NEN"; return false; }
   // BUY: đỉnh nến sau thấp hơn; SELL: đáy nến sau cao hơn; tính cả râu.
   if(buy?r[1].high>=r[2].high:r[1].low<=r[2].low)
     { reason=buy?"PA2_BUY_DINH_SAU_CHUA_THAP_HON":"PA2_SELL_DAY_SAU_CHUA_CAO_HON"; return false; }
   // Khi tắt EMA9, màu nến sau chọn hướng để không tạo đồng thời BUY và SELL.
   if(!InpUseEMA9Entry&&(buy?r[1].close<=r[1].open:r[1].close>=r[1].open)) return false;
   for(int i=1;i<=PA_CONFIRM_BARS+1;i++)
     {
      if(Doji(r,i)) { reason="DOJI_TRONG_HOAC_TRUOC_CHUOI"; return false; }
      if(Star(r,i,true)||Star(r,i,false)) { reason="STAR_TRONG_HOAC_TRUOC_CHUOI"; return false; }
     }
   return true; // Không bắt buộc cùng màu khi EMA9 bật; EMA9 quyết định hướng BUY/SELL.
  }
bool Engulfing(const MqlRates &r[],const bool buy)
  {
   if(ArraySize(r)<3||Doji(r,1)||Doji(r,2)) return false;
   if(buy)
      return r[2].close<r[2].open&&r[1].close>r[1].open&&
             r[1].open<=r[2].close&&r[1].close>=r[2].open;
   return r[2].close>r[2].open&&r[1].close<r[1].open&&
          r[1].open>=r[2].close&&r[1].close<=r[2].open;
  }
bool BreakoutPA(const MqlRates &r[],const bool buy)
  {
   if(!InpUseEMA9Entry||ArraySize(r)<=InpBreakoutBars+2||Doji(r,1)) return false;
   if(buy?r[1].close<=r[1].open:r[1].close>=r[1].open) return false;
   double edge=buy?r[2].high:r[2].low;
   double priorEdge=buy?r[3].high:r[3].low;
   for(int i=2;i<=InpBreakoutBars+1;i++)
     {
      edge=buy?MathMax(edge,r[i].high):MathMin(edge,r[i].low);
      priorEdge=buy?MathMax(priorEdge,r[i+1].high):MathMin(priorEdge,r[i+1].low);
      if(i<InpBreakoutBars+1&&Doji(r,i)&&Doji(r,i+1)) return false;
     }
   // Chỉ lần phá đầu tiên; không đuổi thêm khi nến trước đã đóng phá cụm cũ.
   if(buy?r[2].close>priorEdge:r[2].close<priorEdge) return false;
   return buy?r[1].close>edge:r[1].close<edge;
  }
bool EMA9ReclaimPA(const MqlRates &r[],const bool buy,const double ema,const double priorEMA)
  {
   if(!InpUseEMA9Entry||ArraySize(r)<3||!ValidNumber(ema)||!ValidNumber(priorEMA)||Doji(r,1)) return false;
   if(buy) return r[1].close>r[1].open&&r[1].close>ema&&r[2].close<=priorEMA;
   return r[1].close<r[1].open&&r[1].close<ema&&r[2].close>=priorEMA;
  }
bool EntrySignal(const MqlRates &r[],const bool buy,string &reason,const double ema=0.0,const double priorEMA=0.0)
  {
   reason="";
   if(ArraySize(r)<3) { reason="THIEU_NEN"; return false; }
   if(Doji(r,1)) { reason="DOJI_NEN_XAC_NHAN"; return false; }
   // Xét độc lập: PA2 không đạt không được chặn Engulfing hoặc Star hợp lệ.
   if(InpUseEngulfing&&Engulfing(r,buy))
     { reason=buy?"BULL_ENGULF":"BEAR_ENGULF"; return true; }
   if(InpUseStar&&Star(r,1,buy))
     { reason=buy?"MORNING_STAR":"EVENING_STAR"; return true; }
   if(InpUseBreakoutPA&&BreakoutPA(r,buy)) { reason="PA_PHA_CUM_HOI"; return true; }
   if(InpUseEMA9ReclaimPA&&EMA9ReclaimPA(r,buy,ema,priorEMA)) { reason="PA_DONG_VUOT_LAI_EMA9"; return true; }
   if(InpUsePA2&&PA2Signal(r,buy,reason)) { reason="PA2"; return true; }
   if(reason=="") reason="KHONG_CO_PA2_ENGULF_STAR_CUNG_HUONG";
   return false;
  }
bool ReadEMA9(double &newest,double &previous,double &older,double &oldest,double &priorOldest,double &atr)
  {
   if(hEMA9==INVALID_HANDLE) return false;
   int count=InpEMA9TurnBars+3; double ema[],value[1];
   ArrayResize(ema,count);
   // CopyBuffer: index 0 cũ nhất; index count-1 là EMA của nến vừa đóng.
   if(CopyBuffer(hEMA9,0,1,count,ema)!=count||CopyBuffer(hATR,0,1,1,value)!=1) return false;
   newest=ema[count-1]; previous=ema[count-2]; older=ema[count-3]; oldest=ema[1]; priorOldest=ema[0]; atr=value[0];
   return ValidNumber(newest)&&ValidNumber(previous)&&ValidNumber(older)&&ValidNumber(oldest)&&ValidNumber(priorOldest)&&ValidNumber(atr);
  }
bool EMA9EntryBend(const double newest,const double previous,const double oldest,
                   const double atr,const bool buy,double &inside)
  {
   inside=180.0;
   if(!ValidNumber(newest)||!ValidNumber(previous)||!ValidNumber(oldest)||!ValidNumber(atr)||
      InpEMA9TurnBars<1||InpEMA9AngleScaleATR<=0.0) return false;
   double oldSlope=(previous-oldest)/InpEMA9TurnBars,newSlope=newest-previous;
   double scale=atr*InpEMA9AngleScaleATR;
   double oldAngle=MathArctan(oldSlope/scale)*180.0/3.141592653589793;
   double newAngle=MathArctan(newSlope/scale)*180.0/3.141592653589793;
   double turn=buy?newAngle-oldAngle:oldAngle-newAngle;
   inside=180.0-MathAbs(newAngle-oldAngle);
   return (buy?newSlope>0.0:newSlope<0.0)&&turn>0.0&&inside<=InpEMA9EntryAngle;
  }
bool EMA9CurlBend(const double newest,const double previous,const double oldest,
                  const double atr,const bool buy)
  {
   if(!InpEMA9UseCurl||!ValidNumber(newest)||!ValidNumber(previous)||!ValidNumber(oldest)||
      !ValidNumber(atr)||InpEMA9TurnBars<1) return false;
   double direction=buy?1.0:-1.0;
   double before=direction*(previous-oldest)/InpEMA9TurnBars;
   double now=direction*(newest-previous);
   // Nhịp trước ngược hướng hoặc gần ngang; nhịp mới thoát cuộn và tăng độ dốc đúng hướng.
   return before<=InpEMA9FlatATR*atr&&now>=InpEMA9MinSlopeATR*atr&&now>before;
  }
bool EMA9EntryTrigger(const double newest,const double previous,const double oldest,
                      const double atr,const bool buy,double &angle)
  {
   bool bend=EMA9EntryBend(newest,previous,oldest,atr,buy,angle);
   bool curl=EMA9CurlBend(newest,previous,oldest,atr,buy);
   double before=(buy?1.0:-1.0)*(previous-oldest)/InpEMA9TurnBars;
   return (bend||curl)&&before<=InpEMA9FlatATR*atr&&angle<=InpEMA9EntryAngle&&
          (buy?newest-previous:previous-newest)>=InpEMA9MinSlopeATR*atr;
  }
void ClearEMA9Wait() { g_confirmTime=0; g_confirmBuy=false; }
bool EMA9Choppy(const double &ema[],const double atr)
  {
   int last=0,flips=0;
   double limit=InpEMA9FlatATR*atr;
   if(ArraySize(ema)<2) return true;
   double top=ema[0],bottom=ema[0];
   for(int i=1;i<ArraySize(ema);i++)
     {
      top=MathMax(top,ema[i]); bottom=MathMin(bottom,ema[i]);
      double slope=ema[i]-ema[i-1];
      int side=slope>limit?1:(slope<-limit?-1:0);
      if(side==0) continue; // Đoạn ngang không tự tạo lần đảo hướng.
      if(last!=0&&side!=last) flips++;
      last=side;
     }
   return flips>=2&&top-bottom<=InpEMA9ChopRangeATR*atr;
  }
bool ClearEntryExtreme(const MqlRates &r[],const bool buy,const double atr,const int maxPivot=3)
  {
   if(ArraySize(r)<=maxPivot+InpEntryExtremeLookback) return false;
   // Cực trị phải có nhịp tiến tới và nhịp bật ra; không chỉ là râu nhỏ ở giữa vùng giá.
   for(int pivot=1;pivot<=maxPivot;pivot++)
     {
      double edge=buy?r[pivot].low:r[pivot].high;
      bool local=true,strict=false;
      double approach=0.0;
      for(int j=pivot+1;j<=pivot+InpEntryExtremeLookback;j++)
        {
         double other=buy?r[j].low:r[j].high;
         if(buy?edge>other:edge<other) { local=false; break; }
         if(buy?edge<other:edge>other) strict=true;
         approach=MathMax(approach,buy?r[j].high-edge:edge-r[j].low);
        }
      for(int j=1;j<pivot&&local;j++)
         if(buy?r[j].low<edge:r[j].high>edge) local=false;
      double recovery=buy?r[1].close-edge:edge-r[1].close;
      if(local&&strict&&approach>=InpEntryProminenceATR*atr&&recovery>=InpEntryProminenceATR*atr)
         return true;
     }
   return false;
  }
bool AlternatingCandles(const MqlRates &r[])
  {
   if(ArraySize(r)<=InpAlternatingLookback+1) return false;
   int last=0,run=0,groups=0;
   // Không tính nến xác nhận r[1]; một lần đổi màu đơn lẻ không phải vùng xen kẽ.
   for(int i=2;i<=InpAlternatingLookback+1;i++)
     {
      if(Doji(r,i)) return false; // Doji được xử lý riêng trong PA, không đếm thành xanh/đỏ.
      int side=r[i].close>r[i].open?1:-1;
      if(side==last) run++;
      else { last=side; run=1; groups++; }
      if(run>2) return false; // Có nhịp 3 nến cùng màu: không phải chuỗi 1-1/2-2 sát tín hiệu.
      if(groups>=4) return true;
     }
   return false;
  }
bool EntryQuality(const MqlRates &r[],const bool buy,const double ema,const double atr,string &reason)
  {
   if(!ValidNumber(atr)||ArraySize(r)<2||(InpUseEMA9Entry&&!ValidNumber(ema))) return false;
   if(InpFilterAlternating&&AlternatingCandles(r))
     { reason="NEN_XANH_DO_XEN_KE_1_1_HOAC_2_2"; return false; }
   if(InpUseEMA9Entry&&(buy?r[1].close<=ema:r[1].close>=ema))
     { reason="DONG_NEN_CHUA_QUA_EMA9_CUNG_HUONG"; return false; }
   if(InpFilterEntryCandle)
     {
      double body=MathAbs(r[1].close-r[1].open);
      double upper=r[1].high-MathMax(r[1].open,r[1].close);
      double lower=MathMin(r[1].open,r[1].close)-r[1].low;
      bool colour=buy?r[1].close>r[1].open:r[1].close<r[1].open;
      if(!colour||Doji(r,1)||body<InpEntryMinBodyATR*atr||
         (upper>=body&&lower>=body)||(buy?upper:lower)>=InpEntryOppWickRatio*body)
        { reason="NEN_XAC_NHAN_NGUOC_MAU_THAN_NHO_HOAC_RAU_DAI"; return false; }
     }
   if(InpRequireEntryExtreme)
     {
      int pivots=InpUseBreakoutPA&&BreakoutPA(r,buy)?MathMax(3,InpBreakoutBars+1):3;
      if(!ClearEntryExtreme(r,buy,atr,pivots))
        { reason="PA_CHUA_CO_DINH_DAY_VA_NHIP_BAT_RO_RANG"; return false; }
     }
   return true;
  }
bool EntryWithEMA9(const MqlRates &r[],bool &buy,string &reason)
  {
   reason="";
   if(ArraySize(r)<PA_CONFIRM_BARS+4) { reason="THIEU_NEN"; ClearEMA9Wait(); return false; }
   if(!InpUseEMA9Entry)
     {
      ClearEMA9Wait(); string sellReason;
      bool b=EntrySignal(r,true,reason),s=EntrySignal(r,false,sellReason);
      if(b&&s) { reason="XUNG_DOT_BUY_SELL"; return false; }
      if(!b&&!s) { if(reason=="") reason=sellReason; return false; }
      buy=b; return EntryQuality(r,buy,0.0,g_atr,reason);
     }
   double newest,previous,older,oldest,priorOldest,atr;
   if(!ReadEMA9(newest,previous,older,oldest,priorOldest,atr))
     { ClearEMA9Wait(); reason="THIEU_DU_LIEU_EMA9"; return false; }
   if(InpEMA9FilterChop)
     {
      double path[]; int count=InpEMA9ChopBars+1;
      if(CopyBuffer(hEMA9,0,1,count,path)!=count)
        { ClearEMA9Wait(); reason="THIEU_DU_LIEU_LOC_EMA9_NHIEU"; return false; }
      for(int i=0;i<count;i++) if(!ValidNumber(path[i]))
        { ClearEMA9Wait(); reason="EMA9_NHIEU_DU_LIEU_KHONG_HOP_LE"; return false; }
      if(EMA9Choppy(path,atr))
        { ClearEMA9Wait(); reason="EMA9_DOI_HUONG_LIEN_TUC_DOAN_NGAN"; return false; }
     }
   bool waiting=InpEMA9AllowNextBar&&g_confirmTime>0&&g_confirmTime==r[2].time&&
                r[1].time-r[2].time==PeriodSeconds(InpTF);
   buy=g_confirmBuy; bool fresh=false;
   for(int side=0;side<2;side++)
     {
      bool direction=(side==0); double angle,priorAngle;
      bool current=EMA9EntryTrigger(newest,previous,oldest,atr,direction,angle);
      bool prior=EMA9EntryTrigger(previous,older,priorOldest,atr,direction,priorAngle);
      if(current&&!prior) { fresh=true; buy=direction; break; }
      double sign=direction?1.0:-1.0;
      // Tín hiệu mới sau pullback: đoạn trước gần ngang/ngược, đoạn mới vượt ngưỡng dốc.
      // Không kéo dài hàng chờ E1 và không nhận tăng tốc giữa một nhịp dốc liên tục.
      if(InpEMA9PullbackRearm&&sign*(previous-older)<=InpEMA9FlatATR*atr&&
         sign*(newest-previous)>=InpEMA9MinSlopeATR*atr&&
         EMA9EntryBend(newest,previous,previous-(previous-older)*InpEMA9TurnBars,atr,direction,angle)&&
         ClearEntryExtreme(r,direction,atr,InpUseBreakoutPA?MathMax(3,InpBreakoutBars+1):3))
        { fresh=true; buy=direction; break; }
     }
   ClearEMA9Wait();
   if(!fresh&&!waiting) return false;
   bool pa=EntrySignal(r,buy,reason,newest,previous);
   double slope=(buy?1.0:-1.0)*(newest-previous);
   bool quality=pa&&EntryQuality(r,buy,newest,atr,reason);
   if(quality&&slope>=InpEMA9MinSlopeATR*atr)
     {
      string timing=buy?(fresh?"EMA9_BUY | PA_CUNG_NEN":"EMA9_BUY | PA_NEN_KE_TIEP"):
                        (fresh?"EMA9_SELL | PA_CUNG_NEN":"EMA9_SELL | PA_NEN_KE_TIEP");
      Log(timing+StringFormat(" | MAU=%s | signal=%s | execute=%s | close=%.3f | EMA9=%.3f | slope/ATR=%.3f",
          reason,TimeToString(r[1].time,TIME_DATE|TIME_MINUTES),TimeToString(r[0].time,TIME_DATE|TIME_MINUTES),
          r[1].close,newest,slope/atr));
      return true;
     }
   if(fresh&&InpEMA9AllowNextBar) { g_confirmTime=r[1].time; g_confirmBuy=buy; }
   if(reason=="") reason=pa?"EMA9_KHONG_CON_DOC_CUNG_HUONG":"PA_CHUA_XAC_NHAN";
   reason=(fresh?"EMA9_CHO_PA | ":"EMA9_HET_HAN | ")+reason;
   return false;
  }
bool ConfirmedSwing(const MqlRates &r[],const int i,const bool buy)
  {
   if(i-InpSwingStrength<1||i+InpSwingStrength>=ArraySize(r)) return false;
   bool strict=false;
   for(int j=1;j<=InpSwingStrength;j++)
     {
      if(buy)
        {
         if(r[i].low>r[i-j].low||r[i].low>r[i+j].low) return false;
         if(r[i].low<r[i-j].low||r[i].low<r[i+j].low) strict=true;
        }
      else
        {
         if(r[i].high<r[i-j].high||r[i].high<r[i+j].high) return false;
         if(r[i].high>r[i-j].high||r[i].high>r[i+j].high) strict=true;
        }
     }
   return strict;
  }
double TickSize()
  {
   double size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return size>0.0?size:SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  }
double RoundStop(const double price,const bool buy)
  {
   double size=TickSize(); if(size<=0.0) return 0.0;
   return NormalizeDouble((buy?MathFloor(price/size):MathCeil(price/size))*size,
                          (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
  }
bool StopsValid(const bool buy,const double sl,const MqlTick &tick,const bool modify=false)
  {
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   long level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(modify) level=(long)MathMax(level,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   double distance=level*point;
   if(!ValidNumber(sl)||point<=0.0||tick.bid<=0.0||tick.ask<=0.0) return false;
   return buy?sl<tick.bid-distance:sl>tick.ask+distance;
  }
double FixedTestVolume(const bool buy,const double entry)
  {
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(!ValidNumber(InpFixedLot)||!ValidNumber(entry)||minimum<=0.0||step<=0.0||maximum<minimum)
     { Log("FIXED_LOT_BLOCK | THONG_SO_LOT_HOAC_GIA_KHONG_HOP_LE"); return 0.0; }
   double requested=MathMax(minimum,MathMin(InpFixedLot,maximum));
   double lot=NormalizeDouble(MathFloor(requested/step+1e-9)*step,8);
   if(lot<minimum-1e-10) lot=NormalizeDouble(MathCeil(minimum/step-1e-9)*step,8);
   if(lot<minimum-1e-10||lot>maximum+1e-10)
     { Log("FIXED_LOT_BLOCK | LOT_KHONG_HOP_LE_VOI_BROKER"); return 0.0; }
   // Risk OFF không xét % equity, trần InpMaxLot, phí và dự phòng SL; vẫn cần đủ margin để broker nhận lệnh.
   double margin=0.0;
   if(!OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,lot,entry,margin)||
      margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     { Log(StringFormat("FIXED_LOT_BLOCK | MARGIN | need=%.2f | free=%.2f | error=%d",margin,AccountInfoDouble(ACCOUNT_MARGIN_FREE),GetLastError())); return 0.0; }
   return lot;
  }
double RiskVolume(const bool buy,const double entry,const double sl)
  {
   if(!InpUseRiskManagement) return FixedTestVolume(buy,entry); // Chỉ đổi cách chọn lot, giữ nguyên toàn bộ SL/BE/TP.
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(minimum<=0.0||step<=0.0||maximum<minimum) { Log("RISK_BLOCK | THONG_SO_VOLUME_KHONG_HOP_LE"); return 0.0; }
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double worstSL=sl+(buy?-1.0:1.0)*InpRiskReservePoints*point,pnl=0.0;
   // Dùng lot tối thiểu hợp lệ của symbol để tính, không giả định broker chấp nhận 1 lot BTC.
   if(worstSL<=0.0||!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,minimum,entry,worstSL,pnl))
     { Log(StringFormat("RISK_BLOCK | CALC_PROFIT_FAILED | %s | error=%d",_Symbol,GetLastError())); return 0.0; }
   double loss=MathAbs(pnl)/minimum+InpCommissionPerLot;
   double budget=AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
   if(loss<=0.0||budget<=0.0||minimum<=0.0||step<=0.0||maximum<minimum) return 0.0;
   if(InpMaxLot>0.0) maximum=MathMin(maximum,InpMaxLot);
   double lot=MathFloor(MathMin(budget/loss,maximum)/step+1e-9)*step;
   lot=NormalizeDouble(lot,8);
   if(lot<minimum-1e-10||lot*loss>budget+1e-7)
     { Log(StringFormat("RISK_BLOCK | LOT_DUOI_MIN_HOAC_VUOT_RISK | budget=%.2f | minLot=%.8f | lossMin=%.2f | rawLot=%.8f | maxLot=%.8f",budget,minimum,minimum*loss,budget/loss,maximum)); return 0.0; }
   double margin=0.0;
   if(!OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,lot,entry,margin)||
      margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     { Log(StringFormat("RISK_BLOCK | MARGIN | need=%.2f | free=%.2f | error=%d",margin,AccountInfoDouble(ACCOUNT_MARGIN_FREE),GetLastError())); return 0.0; }
   return lot;
  }
bool StopCandidate(const bool buy,const double anchor,const double entry,const double atr,
                   const MqlTick &tick,double &sl,double &lot,const bool existing=false,const bool analysis=false)
  {
   if(!ValidNumber(anchor)||!ValidNumber(atr)) return false;
   double buffer=MathMax(InpSLBufferATR*atr,MathMax(1.5*(tick.ask-tick.bid),2.0*TickSize()));
   double raw=buy?anchor-buffer:anchor+buffer;
   raw=buy?MathMin(raw,entry-InpMinSL_ATR*atr):MathMax(raw,entry+InpMinSL_ATR*atr);
   long stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(existing) stopLevel=(long)MathMax(stopLevel,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   double stopDistance=stopLevel*SymbolInfoDouble(_Symbol,SYMBOL_POINT)+TickSize();
   raw=buy?MathMin(raw,tick.bid-stopDistance):MathMax(raw,tick.ask+stopDistance); // Chỉ nới SL ra ngoài cấu trúc để đủ khoảng cách broker.
   sl=RoundStop(raw,buy);
   double risk=buy?entry-sl:sl-entry;
   if(risk+1e-9<InpMinSL_ATR*atr||risk>InpMaxSL_ATR*atr||!StopsValid(buy,sl,tick,existing))
     { Log(StringFormat("SL_BLOCK | %s | SL_ATR=%.3f | limit=%.2f..%.2f | brokerDist=%.8f",_Symbol,risk/atr,InpMinSL_ATR,InpMaxSL_ATR,stopDistance)); return false; }
   // Vị thế đã mở: giữ khối lượng hiện có, không chặn bảo vệ SL vì lot tính cho lệnh mới quá nhỏ.
   lot=analysis?1.0:(existing?PositionGetDouble(POSITION_VOLUME):RiskVolume(buy,entry,sl));
   return lot>0.0;
  }
bool SelectSL(const MqlRates &r[],const bool buy,const MqlTick &tick,
              const double atr,double &sl,double &lot,string &source,const double positionEntry=0.0,const bool analysis=false)
  {
   if(ArraySize(r)<PA_CONFIRM_BARS+1) return false;
   double edge=buy?DBL_MAX:-DBL_MAX,entry=buy?tick.ask:tick.bid;
   bool existing=ValidNumber(positionEntry); // Lệnh cũ: xét khoảng cách SL từ giá hiện tại, không bị Entry xa chặn gắn SL.
   for(int i=1;i<=PA_CONFIRM_BARS;i++) edge=buy?MathMin(edge,r[i].low):MathMax(edge,r[i].high);
   int first=MathMax(PA_CONFIRM_BARS,InpSwingStrength+1);
   int last=MathMin(first+InpSwingLookback-1,ArraySize(r)-InpSwingStrength-1);
   for(int i=first;i<=last;i++)
     {
      if(!ConfirmedSwing(r,i,buy)) continue;
      double anchor=buy?MathMin(edge,r[i].low):MathMax(edge,r[i].high);
      if(StopCandidate(buy,anchor,entry,atr,tick,sl,lot,existing,analysis)) { source="SWING"; return true; }
     }
   if(StopCandidate(buy,edge,entry,atr,tick,sl,lot,existing,analysis)) { source="CUC_TRI_CHUOI"; return true; }
   return false;
  }
void ScanSLNotice(const string reason)
  {
   if(TimeCurrent()-g_slScanNotice<10) return;
   g_slScanNotice=TimeCurrent(); Log("AUTO_SL_CHO | "+_Symbol+" | "+reason);
  }
double BERequiredMove(const bool buy,const double entry,const double sl,const double atr)
  {
   if(!ValidNumber(entry)||!ValidNumber(atr)) return 0.0;
   long id=PositionGetInteger(POSITION_IDENTIFIER);
   if(id!=g_beRiskPositionID) { g_beRiskPositionID=id; g_beInitialRisk=0.0; }
   // Ghi khoảng cách SL lần đầu EA nhìn thấy, giữ cố định ngay cả khi người dùng dời SL sau đó.
   if(g_beInitialRisk<=0.0&&ValidNumber(sl)&&(buy?sl<entry:sl>entry))
      g_beInitialRisk=MathAbs(entry-sl);
   if(InpBreakEvenMinR>0.0&&!ValidNumber(g_beInitialRisk)) return 0.0; // Chưa có SL: phải gắn SL trước, không nhảy thẳng về BE theo ATR.
   return MathMax(InpBreakEvenATR*atr,InpBreakEvenMinR*g_beInitialRisk);
  }
void ScanMissingSL()
  {
   if(!InpAutoScanSL||TimeCurrent()-g_slScanRetry<1||ArraySize(g_pending)>0) return;
   bool missing=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0&&OwnPosition()&&PositionGetDouble(POSITION_SL)<=0.0) { missing=true; break; }
   if(!missing) return; // Không đọc lịch sử/ATR nếu không có lệnh cần gắn SL.
   g_slScanRetry=TimeCurrent();
   MqlTick tick; double value[1];
   if(!SymbolInfoTick(_Symbol,tick)||!ValidNumber(tick.bid)||!ValidNumber(tick.ask)) { ScanSLNotice("CHUA_CO_BID_ASK"); return; }
   if(CopyBuffer(hATR,0,1,1,value)!=1||!ValidNumber(value[0])) { ScanSLNotice("ATR_CHUA_SAN_SANG"); return; }
   int needed=InpSwingLookback+2*InpSwingStrength+PA_CONFIRM_BARS+2;
   MqlRates r[]; ArraySetAsSeries(r,true);
   bool haveRates=CopyRates(_Symbol,InpTF,0,needed,r)==needed;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||!OwnPosition()||PositionGetDouble(POSITION_SL)>0.0) continue;
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN),sl=0.0,lot=0.0; string source="";
      bool selected=false;
      if(InpBreakEven)
        {
         double entryATR=EntryATRForPosition(),move=buy?tick.bid-entry:entry-tick.ask;
         double target=RoundStop(entry,!buy),required=BERequiredMove(buy,entry,0.0,entryATR);
         if(ValidNumber(required)&&move>=required&&StopsValid(buy,target,tick,true))
           { sl=target; source="BE_DA_DU_NGUONG"; selected=true; }
        }
      if(!selected)
        {
         if(!haveRates) { ScanSLNotice("THIEU_LICH_SU_NEN | TF="+EnumToString(InpTF)); continue; }
         selected=SelectSL(r,buy,tick,value[0],sl,lot,source,entry);
        }
      if(!selected||!StopsValid(buy,sl,tick,true))
        { ScanSLNotice(StringFormat("position=%I64u | SL_CHUA_HOP_LE | entry=%.*f | bid=%.*f | ask=%.*f | ATR=%.5f",ticket,_Digits,entry,_Digits,tick.bid,_Digits,tick.ask,value[0])); continue; }
      // Kiểm tra lại đúng ticket và SL trước gửi; không ghi đè SL vừa được người dùng/EA khác đặt.
      if(!PositionSelectByTicket(ticket)||!OwnPosition()||PositionGetDouble(POSITION_SL)>0.0) continue;
      double tp=PositionGetDouble(POSITION_TP);
      bool sent=trade.PositionModify(ticket,sl,tp);
      if(sent&&trade.ResultRetcode()==TRADE_RETCODE_DONE)
        { g_panelMessage=StringFormat("Auto SL #%I64u: %.*f",ticket,_Digits,sl); Log("AUTO_SL_DA_DAT | "+g_panelMessage+" | "+source); }
      else Log(StringFormat("AUTO_SL_LOI | position=%I64u | retcode=%u | %s",ticket,trade.ResultRetcode(),trade.ResultRetcodeDescription()));
     }
  }
void QueueExit(const ulong ticket,const int mode=0)
  {
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i]==ticket) { if(mode==0) g_pendingMode[i]=0; return; } // Nút DONG luôn được ưu tiên.
   int n=ArraySize(g_pending); ArrayResize(g_pending,n+1); ArrayResize(g_pendingMode,n+1);
   g_pending[n]=ticket; g_pendingMode[n]=mode;
  }
void RemoveExit(const int i)
  {
   int n=ArraySize(g_pending);
   for(int j=i;j<n-1;j++) { g_pending[j]=g_pending[j+1]; g_pendingMode[j]=g_pendingMode[j+1]; }
   ArrayResize(g_pending,n-1); ArrayResize(g_pendingMode,n-1);
  }
void RetryExits()
  {
   if(ArraySize(g_pending)==0||TimeCurrent()-g_exitRetry<2) return;
   g_exitRetry=TimeCurrent();
   for(int i=ArraySize(g_pending)-1;i>=0;i--)
     {
      ulong ticket=g_pending[i];
      if(!PositionSelectByTicket(ticket)||!OwnPosition()) { RemoveExit(i); continue; }
      double profit=PositionGetDouble(POSITION_PROFIT);
      if((g_pendingMode[i]==1&&profit>=0.0)||(g_pendingMode[i]==2&&profit<=0.0))
        { Log(StringFormat("HUY_THOAT_CHO | position=%I64u | mode=%d | profit=%.2f",ticket,g_pendingMode[i],profit)); RemoveExit(i); continue; }
      bool sent=trade.PositionClose(ticket); uint code=trade.ResultRetcode();
      if(sent&&code==TRADE_RETCODE_DONE&&!PositionSelectByTicket(ticket)) RemoveExit(i);
      else if(!sent||(code!=TRADE_RETCODE_DONE&&code!=TRADE_RETCODE_DONE_PARTIAL))
         Log("DONG_THAT_BAI_SE_THU_LAI | "+trade.ResultRetcodeDescription());
     }
  }
bool EMA9ExitAfterBE(const double newest,const double previous,const double older,
                      const double oldest,const double atr,const bool buy,string &reason)
  {
   reason="";
   if(!ValidNumber(newest)||!ValidNumber(previous)||!ValidNumber(older)||
      !ValidNumber(oldest)||!ValidNumber(atr)) return false;
   double side=buy?1.0:-1.0,now=side*(newest-previous),prior=side*(previous-older);
   double limit=InpTP_EMA9FlatATR*atr;
   double before=side*(previous-oldest)/InpEMA9TurnBars;
   if((prior>limit||before>limit)&&MathAbs(now)<=limit) { reason="EMA9_CHUYEN_NGANG"; return true; }
   if(now<-limit) { reason="EMA9_DAO_HUONG"; return true; }
   if(InpTPFastDeceleration&&prior>limit&&prior-now>=MathMax(prior*InpTPDecelerationRatio,0.02*atr))
     { reason="EMA9_GIAM_DOC_SOM_SO_VOI_DOAN_TRUOC"; return true; }
   double scale=atr*InpEMA9AngleScaleATR;
   double oldAngle=MathArctan(before/scale)*180.0/3.141592653589793;
   double newAngle=MathArctan(now/scale)*180.0/3.141592653589793;
   double inside=180.0-MathAbs(newAngle-oldAngle);
   if(before>limit&&before-now>=limit&&oldAngle>newAngle&&inside<=InpTP_EMA9Angle)
     { reason="EMA9_GAP_GIAM_DOC"; return true; }
   return false;
  }
bool StopAtBreakEven(const bool buy,const double sl,const double entry)
  {
   if(!ValidNumber(sl)||!ValidNumber(entry)) return false;
   return buy?sl>=entry:sl<=entry; // Chỉ xét SL thực tế broker đã chấp nhận; SL tốt hơn Entry cũng thuộc pha sau BE.
  }
bool OppositeCandleWeakEMA(const MqlRates &r[],const bool buy,const double newest,
                         const double previous,const double older,const double atr)
  {
   if(ArraySize(r)<2||!ValidNumber(newest)||!ValidNumber(previous)||!ValidNumber(older)||!ValidNumber(atr)) return false;
   bool opposite=buy?r[1].close<r[1].open:r[1].close>r[1].open;
   double directedSlope=(buy?1.0:-1.0)*(newest-previous);
   double priorSlope=(buy?1.0:-1.0)*(previous-older);
   bool weak=directedSlope<=InpEarlyExitMaxSlopeATR*atr;
   bool fading=priorSlope>InpEarlyExitMaxSlopeATR*atr&&directedSlope<=priorSlope*InpEarlyExitSlopeRatio&&priorSlope-directedSlope>=0.02*atr;
   return opposite&&(weak||fading);
  }
void AdvanceTPExtreme(const MqlRates &bar,const bool buy,double &edge,int &waiting)
  {
   double current=buy?bar.high:bar.low;
   if(!ValidNumber(edge)||(buy?current>edge:current<edge))
     { edge=current; waiting=0; } // Đỉnh/đáy mới: đặt lại đếm, chính nến tạo cực trị không được tính.
   else waiting++; // Bằng đỉnh/đáy cũ cũng là không vượt, xét toàn bộ râu.
  }
bool TwoCandleExtremeExit(const MqlRates &r[],const bool buy,bool &ready,string &reason)
  {
   ready=false; reason="";
   if(ArraySize(r)<3) return false;
   long id=PositionGetInteger(POSITION_IDENTIFIER);
   if(g_extremePositionID!=id||
      (g_extremeLastTime!=r[1].time&&g_extremeLastTime!=r[2].time))
     {
      int count=iBarShift(_Symbol,InpTF,(datetime)PositionGetInteger(POSITION_TIME),false);
      if(count<1) return false;
      MqlRates history[]; ArraySetAsSeries(history,false);
      if(CopyRates(_Symbol,InpTF,1,count,history)!=count||history[count-1].time!=r[1].time) return false;
      g_tpExtreme=0.0; g_noNewExtremeBars=0;
      for(int j=0;j<count;j++) AdvanceTPExtreme(history[j],buy,g_tpExtreme,g_noNewExtremeBars);
      g_extremePositionID=id; g_extremeLastTime=r[1].time;
     }
   else if(g_extremeLastTime!=r[1].time)
     {
      AdvanceTPExtreme(r[1],buy,g_tpExtreme,g_noNewExtremeBars);
      g_extremeLastTime=r[1].time;
     }
   ready=true;
   if(g_noNewExtremeBars<2) return false;
   reason=StringFormat("TP_2_NEN_KHONG_VUOT_%s | muc=%.*f | nen_sau=%d",buy?"DINH":"DAY",_Digits,g_tpExtreme,g_noNewExtremeBars);
   return true;
  }
bool WickVolumeTP(const MqlRates &r[],const bool buy,const int start,bool &ready,string &reason)
  {
   ready=false; reason="";
   if(start<0||start>1||ArraySize(r)<start+InpTPVolumeBars+2) return false;
   ready=true;
   if(r[start].time-r[start+1].time!=PeriodSeconds(InpTF)) return false;
   double range=r[start].high-r[start].low,priorRange=r[start+1].high-r[start+1].low;
   if(range<=0.0||priorRange<=0.0) return false;
   double body=MathMax(MathAbs(r[start].close-r[start].open),TickSize());
   double priorBody=MathMax(MathAbs(r[start+1].close-r[start+1].open),TickSize());
   double wick=buy?r[start].high-MathMax(r[start].open,r[start].close):MathMin(r[start].open,r[start].close)-r[start].low;
   double priorUpper=r[start+1].high-MathMax(r[start+1].open,r[start+1].close);
   double priorLower=MathMin(r[start+1].open,r[start+1].close)-r[start+1].low;
   if(wick<=InpTPWickBodyRatio*body||MathMax(priorUpper,priorLower)<=InpTPWickBodyRatio*priorBody) return false;
   double total=0.0;
   for(int i=start+2;i<start+2+InpTPVolumeBars;i++) total+=(double)r[i].tick_volume;
   if(total<=0.0) { ready=false; return false; }
   double relative=(double)r[start].tick_volume/(total/InpTPVolumeBars);
   if(relative<InpTPVolumeHigh) return false;
   reason=StringFormat("TP_RAU_%s_VOLUME_CAO | wick/body=%.2f | priorUpper=%.2f | priorLower=%.2f | V=%.2fx | %s",buy?"TREN":"DUOI",wick/body,priorUpper/priorBody,priorLower/priorBody,relative,start==0?"NEN_DANG_CHAY":"NEN_DA_DONG");
   return true;
  }
bool CheckExits(const MqlRates &r[])
  {
   if(ArraySize(r)<3) return false;
   bool read=false,emaReady=false,complete=true;
   double newest=0.0,previous=0.0,older=0.0,oldest=0.0,priorOldest=0.0,atr=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i); if(ticket==0||!OwnPosition()) continue;
      bool buy=((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(r[1].time+PeriodSeconds(InpTF)<=(datetime)PositionGetInteger(POSITION_TIME)) continue;
      bool be=StopAtBreakEven(buy,PositionGetDouble(POSITION_SL),PositionGetDouble(POSITION_PRICE_OPEN));
      bool exit=false,lossOnlyExit=false; string reason="";
      double profit=PositionGetDouble(POSITION_PROFIT);
      if(InpExitOppositeBeforeBE&&profit<0.0)
        {
         bool opposite=buy?r[1].close<r[1].open:r[1].close>r[1].open;
         if(opposite&&!read) { emaReady=ReadEMA9(newest,previous,older,oldest,priorOldest,atr); read=true; }
         if(opposite&&!emaReady) complete=false; // Chưa có EMA: không bỏ qua nến này, OnTick sẽ thử lại.
         if(emaReady) exit=OppositeCandleWeakEMA(r,buy,newest,previous,older,atr);
         if(opposite&&emaReady&&!exit)
            Log(StringFormat("GIU_LENH | position=%I64u | signal=%s | EMA9_slope_ATR=%.3f | prior=%.3f | limit=%.3f",ticket,TimeToString(r[1].time,TIME_DATE|TIME_MINUTES),(buy?1.0:-1.0)*(newest-previous)/atr,(buy?1.0:-1.0)*(previous-older)/atr,InpEarlyExitMaxSlopeATR));
         lossOnlyExit=exit;
         reason="CAT_LO_1_NEN_NGUOC_MAU_VA_EMA9_YEU_HOAC_DAO_HUONG";
        }
      if(!exit&&InpTPWickVolume&&!InpTPWickIntrabar&&profit>0.0)
        {
         bool ready=false;
         exit=WickVolumeTP(r,buy,1,ready,reason);
         if(!ready) complete=false;
        }
      if(!exit&&!InpTPWickVolume&&InpTP2Candles)
        {
         bool ready=false;
         exit=TwoCandleExtremeExit(r,buy,ready,reason);
         if(!ready) complete=false;
        }
      if(!exit&&!InpTPWickVolume&&!InpTP2Candles&&be&&InpTPAfterBE_EMA9)
        {
         if(!read) { emaReady=ReadEMA9(newest,previous,older,oldest,priorOldest,atr); read=true; }
         if(!emaReady) complete=false;
         if(emaReady&&InpHoldUntilEMA9Cross&&(buy?r[1].close>=newest:r[1].close<=newest)) continue;
         if(emaReady) exit=EMA9ExitAfterBE(newest,previous,older,oldest,atr,buy,reason);
        }
      if(exit&&!lossOnlyExit&&InpTPOnlyProfit&&profit<=0.0) exit=false; // Không gọi TP cho lệnh âm/hòa vốn.
      if(exit)
        {
         QueueExit(ticket,lossOnlyExit?1:((InpTPWickVolume||InpTPOnlyProfit)?2:0)); g_exitBar=r[0].time;
         Log(StringFormat("THOAT_%s | position=%I64u | signal=%s | %s",buy?"BUY":"SELL",ticket,TimeToString(r[1].time,TIME_DATE|TIME_MINUTES),reason));
        }
     }
   return complete;
  }
void CheckWickIntrabarTP(const datetime bar)
  {
   if(!InpTPWickIntrabar||ArraySize(g_pending)>0||TimeCurrent()==g_wickTPCheck) return;
   bool profitable=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0&&OwnPosition()&&PositionGetDouble(POSITION_PROFIT)>0.0) { profitable=true; break; }
   if(!profitable) return;
   g_wickTPCheck=TimeCurrent(); // Giới hạn đọc nến một lần/giây để tester nhẹ hơn.
   MqlRates r[]; ArraySetAsSeries(r,true); int count=InpTPVolumeBars+2;
   if(CopyRates(_Symbol,InpTF,0,count,r)!=count||r[0].time!=bar) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i); if(ticket==0||!OwnPosition()||PositionGetDouble(POSITION_PROFIT)<=0.0) continue;
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY,ready=false; string reason="";
      if(!WickVolumeTP(r,buy,0,ready,reason)) continue;
      QueueExit(ticket,2); g_exitBar=bar; ClearEMA9Wait();
      Log(StringFormat("TP_RAU_THEO_TICK_%s | position=%I64u | %s",buy?"BUY":"SELL",ticket,reason));
     }
  }
void CheckIntrabarTP(const datetime bar)
  {
   if(InpTPWickVolume) { CheckWickIntrabarTP(bar); return; }
   if(InpTP2Candles||!InpTPIntrabar||!InpTPAfterBE_EMA9||ArraySize(g_pending)>0) return;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   bool found=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i); if(ticket==0||!OwnPosition()) continue;
      found=true;
      bool buy=((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      long id=PositionGetInteger(POSITION_IDENTIFIER);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double move=buy?tick.bid-entry:entry-tick.ask;
      if(g_tpPositionID!=id) { g_tpPositionID=id; g_tpPeakMove=MathMax(0.0,move); }
      g_tpPeakMove=MathMax(g_tpPeakMove,move);
      if(InpTPOnlyProfit&&PositionGetDouble(POSITION_PROFIT)<=0.0) continue;
      if(!StopAtBreakEven(buy,PositionGetDouble(POSITION_SL),entry)) continue;
      double entryATR=EntryATRForPosition();
      if(!ValidNumber(entryATR)||g_tpPeakMove-move<InpTPPullbackATR*entryATR) continue;
      int count=InpEMA9TurnBars+2; double ema[],value[1]; ArrayResize(ema,count);
      // EMA[0] của CopyBuffer là cũ nhất; cuối mảng là EMA9 nến đang chạy.
      if(CopyBuffer(hEMA9,0,0,count,ema)!=count||CopyBuffer(hATR,0,1,1,value)!=1) continue;
      double newest=ema[count-1];
      if(InpHoldUntilEMA9Cross&&(buy?tick.bid>=newest:tick.bid<=newest)) continue;
      string reason="";
      if(!EMA9ExitAfterBE(newest,ema[count-2],ema[count-3],ema[0],value[0],buy,reason)) continue;
      QueueExit(ticket,InpTPOnlyProfit?2:0); g_exitBar=bar; ClearEMA9Wait();
      Log(StringFormat("TP_THEO_TICK_%s | position=%I64u | %s | hoi=%.3f ATR_ENTRY",buy?"BUY":"SELL",ticket,reason,(g_tpPeakMove-move)/entryATR));
     }
   if(!found) { g_tpPositionID=0; g_tpPeakMove=0.0; }
  }
double EntryATRForPosition()
  {
   long id=PositionGetInteger(POSITION_IDENTIFIER);
   if(id==g_bePositionID&&ValidNumber(g_beEntryATR)) return g_beEntryATR;
   datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
   int shift=iBarShift(_Symbol,InpTF,opened,false);
   if(shift<0) return 0.0;
   double value[1];
   if(CopyBuffer(hATR,0,shift+1,1,value)!=1||!ValidNumber(value[0])) return 0.0;
   g_bePositionID=id; g_beEntryATR=value[0];
   return g_beEntryATR; // Tái dựng được sau khi khởi động lại, không dùng ATR hiện tại để nới ngưỡng BE.
  }
void BreakEven()
  {
   if(!InpBreakEven||TimeCurrent()-g_beRetry<1||ArraySize(g_pending)>0) return;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i); if(ticket==0||!OwnPosition()) continue;
      bool buy=((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN),old=PositionGetDouble(POSITION_SL);
      if(old<=0.0||(buy?old>=entry:old<=entry)) continue;
      double move=buy?tick.bid-entry:entry-tick.ask;
      double entryATR=EntryATRForPosition();
      if(!ValidNumber(entryATR)) { g_beRetry=TimeCurrent(); continue; }
      double required=BERequiredMove(buy,entry,old,entryATR);
      if(!ValidNumber(required)||move<required) continue;
      // Làm tròn về phía lợi nhuận để SL không nằm dưới/trên giá Entry do tick size.
      double target=RoundStop(entry,!buy);
      if(!StopsValid(buy,target,tick,true)||(buy?target<=old:target>=old))
        { g_beRetry=TimeCurrent(); Log("BE_CHO_BROKER | DA_DU_NGUONG_NHUNG_STOP_CHUA_HOP_LE"); continue; }
      double freeze=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      if((buy?tick.bid-old:old-tick.ask)<=freeze)
        { g_beRetry=TimeCurrent(); Log("BE_CHO_BROKER | SL_DANG_TRONG_VUNG_FREEZE"); continue; }
      g_beRetry=TimeCurrent();
      if(trade.PositionModify(ticket,target,PositionGetDouble(POSITION_TP))&&trade.ResultRetcode()==TRADE_RETCODE_DONE)
         Log(StringFormat("SL_VE_ENTRY | position=%I64u | SL=%.*f | move=%.3f | required=%.3f | initialR=%.3f",ticket,_Digits,target,move,required,g_beInitialRisk));
      else Log("DOI_SL_THAT_BAI | "+trade.ResultRetcodeDescription());
     }
  }
string BarKey()
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(_Symbol);i++) hash=(hash^(uint)StringGetCharacter(_Symbol,i))*16777619;
   return StringFormat("GS2_BAR_%I64d_%08X",AccountInfoInteger(ACCOUNT_LOGIN),hash); // Khóa chung theo tài khoản/symbol, không tách Magic.
  }
bool CanEnter(const datetime bar)
  {
   if(g_attemptBar==bar||g_exitBar==bar||AnyPositionOnSymbol()) return false;
   if(!HistorySelect(bar,TimeCurrent())) return false;
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue;
      long type=HistoryDealGetInteger(deal,DEAL_TYPE);
      if(type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL) return false;
     }
   if(!Tester()&&GlobalVariableCheck(BarKey())&&GlobalVariableGet(BarKey())>=bar) return false;
   return true;
  }
bool ClaimBar(const datetime bar)
  {
   if(bar<=0||iTime(_Symbol,InpTF,0)!=bar||!CanEnter(bar)) return false;
   if(!Tester())
     {
      string key=BarKey();
      if(!GlobalVariableCheck(key)&&!GlobalVariableTemp(key)) return false;
      double previous=GlobalVariableGet(key);
      if(previous>=bar||TimeCurrent()<bar||!GlobalVariableSetOnCondition(key,(double)TimeCurrent(),previous)) return false;
     }
   g_attemptBar=bar; return true; // Một lần gửi Entry mỗi nến, kể cả bị broker từ chối.
  }
bool SymbolEntryAllowed(const bool buy)
  {
   string reason="";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED)) reason="BAT_ALGO_TRADING";
   else if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)||!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) reason="TAI_KHOAN_KHONG_CHO_PHEP_EA_GIAO_DICH";
   else
     {
      ENUM_SYMBOL_TRADE_MODE mode=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
      if(mode==SYMBOL_TRADE_MODE_DISABLED) reason="SYMBOL_DANG_TAT_GIAO_DICH";
      else if(mode==SYMBOL_TRADE_MODE_CLOSEONLY) reason="SYMBOL_CHI_CHO_DONG_LENH";
      else if((buy&&mode==SYMBOL_TRADE_MODE_SHORTONLY)||(!buy&&mode==SYMBOL_TRADE_MODE_LONGONLY)) reason="BROKER_KHONG_CHO_HUONG_LENH_NAY";
      else if((SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE)&SYMBOL_ORDER_MARKET)==0) reason="SYMBOL_KHONG_HO_TRO_LENH_MARKET";
      else if((SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE)&SYMBOL_ORDER_SL)==0) reason="SYMBOL_KHONG_HO_TRO_SL";
     }
   if(reason=="") return true;
   g_panelMessage="Chan: "+reason; Log("SYMBOL_ENTRY_BLOCK | "+_Symbol+" | "+reason); return false;
  }
bool BuildSetupLevels(const bool buy,const double entry,const double sl,double &tp1,double &tp2,double &tp3)
  {
   if(!ValidNumber(entry)||!ValidNumber(sl)||(buy?sl>=entry:sl<=entry)) return false;
   double risk=MathAbs(entry-sl),side=buy?1.0:-1.0;
   tp1=RoundStop(entry+side*risk*InpSetupTP1_R,!buy);
   tp2=RoundStop(entry+side*risk*InpSetupTP2_R,!buy);
   tp3=RoundStop(entry+side*risk*InpSetupTP3_R,!buy);
   return ValidNumber(tp1)&&ValidNumber(tp2)&&ValidNumber(tp3)&&
          (buy?(tp1>entry&&tp2>tp1&&tp3>tp2):(tp1<entry&&tp2<tp1&&tp3<tp2));
  }
void ClearEntrySetup()
  {
   g_setupActive=false; g_setupBar=0; g_setupPublishedAt=0;
   if(VisualChart()&&g_setupPrefix!="") { ObjectsDeleteAll(0,g_setupPrefix); ChartRedraw(0); }
  }
datetime SetupClock()
  {
   // Tester dùng thời gian mô phỏng; chart thật dùng đồng hồ để vẫn ẩn khi không có tick mới.
   return MQLInfoInteger(MQL_TESTER)?TimeCurrent():TimeLocal();
  }
bool SetupStillValid()
  {
   if(!g_setupActive||!InpShowEntrySetup) return false;
   long age=(long)(SetupClock()-g_setupPublishedAt);
   return age>=0&&age<InpSetupValidSeconds;
  }
string ClosedVolumeContext(const MqlRates &r[],const bool buy,const double atr)
  {
   if(ArraySize(r)<12||!ValidNumber(atr)) return "Volume: chua du nen da dong de doc boi canh\n";
   int count=MathMin(InpSetupVolumeBars,ArraySize(r)-7);
   double sum=0.0;
   for(int i=7;i<count+7;i++) sum+=(double)r[i].tick_volume; // Không trộn 6 nến được phân tích vào nền so sánh.
   if(count<5||sum<=0.0) return "Tick volume: nen so sanh chua san sang\n";
   double average=sum/count;
   string detail="";
   string note=StringFormat("GIA + TICK VOLUME: 6 nen da dong, nen %d nen truoc do\n",count);
   for(int i=6;i>=1;i--) // Đọc theo thời gian: cũ -> mới; tuyệt đối không dùng nến [0].
     {
      double relative=(double)r[i].tick_volume/average,range=r[i].high-r[i].low;
      string level=relative>=InpSetupVolumeHigh?"CAO":(relative<InpSetupVolumeLow?"THAP":"binh thuong");
      string reading="chua co dau hieu noi bat";
      if(range>0.0)
        {
         double body=MathAbs(r[i].close-r[i].open),closePos=(r[i].close-r[i].low)/range;
         double upper=r[i].high-MathMax(r[i].open,r[i].close),lower=MathMin(r[i].open,r[i].close)-r[i].low;
         bool high=relative>=InpSetupVolumeHigh,low=relative<InpSetupVolumeLow;
         if(high&&upper>=0.4*range&&closePos<=0.4) reading="tu choi gia cao, ap luc ban; can xac nhan";
         else if(high&&lower>=0.4*range&&closePos>=0.6) reading="tu choi gia thap, phan ung cau; can xac nhan";
         else if(high&&(range<0.6*atr||body<=0.3*range)) reading="nhieu hoat dong, tien trien nho: nghi hap thu/tranh chap";
         else if(high&&range>=atr&&closePos>=0.7&&r[i].close>r[i].open) reading="nen tang rong, close cao: luc day len";
         else if(high&&range>=atr&&closePos<=0.3&&r[i].close<r[i].open) reading="nen giam rong, close thap: luc day xuong";
         else if(low&&range<0.7*atr&&r[i].close>r[i].open) reading="nen tang hep, hoat dong thap: cau chua ro";
         else if(low&&range<0.7*atr&&r[i].close<r[i].open) reading="nen giam hep, hoat dong thap: cung chua ro";
         detail+=StringFormat("Nen [%d] %s | V %.2fx %s | bien %.2f ATR | close %.0f%%: %s\n",i,r[i].close>r[i].open?"tang":(r[i].close<r[i].open?"giam":"doji"),relative,level,range/atr,100.0*closePos,reading);
        }
      else detail+=StringFormat("Nen [%d] V %.2fx %s | bien do khong hop le\n",i,relative,level);
     }
   double priorMove=(r[3].close-r[6].open)/atr;
   int priorDirection=priorMove>0.3?1:(priorMove<-0.3?-1:0);
   double earlyPush=priorDirection*(r[5].close-r[6].open)/atr;
   double latePush=priorDirection*(r[3].close-r[4].open)/atr;
   double earlyRange=((r[6].high-r[6].low)+(r[5].high-r[5].low))/(2.0*atr);
   double lateRange=((r[4].high-r[4].low)+(r[3].high-r[3].low))/(2.0*atr);
   double earlyVolume=((double)r[6].tick_volume+(double)r[5].tick_volume)/2.0;
   double lateVolume=((double)r[4].tick_volume+(double)r[3].tick_volume)/2.0;
   bool weakening=priorDirection!=0&&earlyPush>=0.2&&
                 (latePush<=0.65*earlyPush||lateRange<=0.70*earlyRange);
   bool effortPoor=weakening&&lateVolume>=0.90*earlyVolume&&latePush<=0.65*earlyPush;
   string prior=priorDirection>0?"NHIP TANG":(priorDirection<0?"NHIP GIAM":"NHIP TRUOC CHUA RO HUONG");
   string force=priorDirection==0?"chua du co so so luc":(weakening?"DA GIAM LUC":"CHUA THAY GIAM LUC RO");
   note+=StringFormat("4 nen truoc [6..3]: %s | %s | tien %.2f -> %.2f ATR | bien %.2f -> %.2f ATR\n",prior,force,earlyPush,latePush,earlyRange,lateRange);
   if(effortPoor) note+="Volume con cao nhung gia tien it: nghi hap thu/can tro, khong tu dong ket luan dao chieu\n";
   else if(earlyVolume>0.0&&lateVolume<0.75*earlyVolume) note+="Hoat dong volume nhip truoc giam; can doi chieu gia, khong coi volume giam la dao chieu\n";
   double side=buy?1.0:-1.0,progress=side*(r[1].close-r[2].open)/atr;
   double finalVolume=((double)r[1].tick_volume+(double)r[2].tick_volume)/(2.0*average);
   double range=r[1].high-r[1].low,closePos=range>0.0?(r[1].close-r[1].low)/range:0.5;
   double opposedWick=buy?r[1].high-MathMax(r[1].open,r[1].close):MathMin(r[1].open,r[1].close)-r[1].low;
   bool adverseRejection=range>0.0&&opposedWick>=0.4*range&&(buy?closePos<=0.55:closePos>=0.45)&&
                         (double)r[1].tick_volume>=InpSetupVolumeHigh*average;
   bool priceConfirms=range>0.0&&progress>=0.3&&side*(r[1].close-r[1].open)>0.0&&
                      side*(r[1].close-r[2].close)>0.0&&(buy?closePos>=0.65:closePos<=0.35)&&!adverseRejection;
   bool volumeSupports=finalVolume>=InpSetupVolumeLow;
   string verdict;
   if(adverseRejection) verdict="2 NEN CUOI CHUA UNG HO: rau nguoc huong + volume cao";
   else if(!priceConfirms) verdict="2 NEN CUOI CHUA XAC NHAN LUC DAY THEO SETUP";
   else if(!volumeSupports) verdict="2 NEN CUOI XAC NHAN GIA, NHUNG VOLUME YEU";
   else if(priorDirection!=0&&side*priorDirection<0.0)
      verdict=weakening?"2 NEN CUOI UNG HO DAO CHIEU, NHIP TRUOC DA GIAM LUC":"2 NEN CUOI UNG HO NHUNG CON NGUOC NHIP TRUOC CHUA GIAM LUC RO";
   else verdict=weakening?"2 NEN CUOI DAY TRO LAI SAU NHIP TRUOC GIAM LUC":"2 NEN CUOI UNG HO HUONG SETUP";
   note+=StringFormat("UU TIEN 2 NEN CUOI [2..1]: tien %.2f ATR | V %.2fx | %s\n",progress,finalVolume,verdict);
   note+="CHI TIET 6 NEN (cu -> moi):\n"+detail;
   return note;
  }
string DescribeSetup(const MqlRates &r[],const bool buy,const string pattern,const double atr,
                     const double entry,const double sl,const string source)
  {
   if(!InpSetupContext||ArraySize(r)<3||!ValidNumber(atr)) return "";
   double side=buy?1.0:-1.0,risk=MathAbs(entry-sl);
   string note=StringFormat("%s | %s | TF %s\nPA: %s\n",buy?"BUY":"SELL",TimeToString(r[1].time,TIME_DATE|TIME_MINUTES),EnumToString(InpTF),pattern);
   double ema9[2],ema21[2];
   if(hEMA9!=INVALID_HANDLE&&CopyBuffer(hEMA9,0,1,2,ema9)==2&&ValidNumber(ema9[0])&&ValidNumber(ema9[1]))
     {
      double slope=(ema9[1]-ema9[0])/atr;
      string direction=MathAbs(slope)<=InpEMA9FlatATR?"ngang":(slope>0.0?"huong len":"huong xuong");
      note+=StringFormat("EMA9 %s | doc %.3f ATR/nen | close %s EMA9\n",direction,slope,r[1].close>=ema9[1]?"tren":"duoi");
     }
   else note+="EMA9: du lieu chua san sang\n";
   if(hSetupEMA21!=INVALID_HANDLE&&CopyBuffer(hSetupEMA21,0,1,2,ema21)==2&&ValidNumber(ema21[0])&&ValidNumber(ema21[1]))
     {
      double slope=side*(ema21[1]-ema21[0])/atr;
      string trend=(slope>0.03&&side*(r[1].close-ema21[1])>0.0)?"THUAN EMA21":(slope<-0.03?"NGUOC EMA21 - can theo doi dao chieu":"EMA21 NGANG/CHUA RO HUONG");
      note+=StringFormat("Boi canh: %s | close cach EMA21 %.2f ATR\n",trend,MathAbs(r[1].close-ema21[1])/atr);
     }
   else note+="EMA21: du lieu chua san sang\n";
   int pivots=InpUseBreakoutPA?MathMax(3,InpBreakoutBars+1):3;
   bool extreme=ClearEntryExtreme(r,buy,atr,pivots);
   note+=StringFormat("%s cuc bo: %s\nSL %s | khoang SL %.2f ATR\n",buy?"Day":"Dinh",extreme?"co nhip tien toi va bat ra ro":"chua dat tieu chi cuc tri",source,risk/atr);
   double obstacle=0.0;
   int last=MathMin(InpSwingLookback+InpSwingStrength+1,ArraySize(r)-InpSwingStrength-1);
   for(int i=InpSwingStrength+1;i<=last;i++)
     {
      if(!ConfirmedSwing(r,i,!buy)) continue;
      double level=buy?r[i].high:r[i].low;
      if(side*(level-entry)<=0.0) continue;
      if(obstacle==0.0||side*(level-obstacle)<0.0) obstacle=level;
     }
   if(ValidNumber(obstacle)&&risk>0.0)
     {
      double room=side*(obstacle-entry)/risk;
      note+=StringFormat("%s swing gan nhat %.*f | khoang trong %.2fR%s\n",buy?"Khang cu":"Ho tro",_Digits,obstacle,room,room<InpSetupTP1_R?" - CO MOC CAN TRUOC TP1":"");
     }
   else note+="Chua tim thay moc can swing phia truoc trong vung da quet\n";
   note+=ClosedVolumeContext(r,buy,atr);
   note+="Boi canh tham khao, khong phai du bao chac chan; khong thay doi lenh.";
   return note;
  }
void ResizeSetupLines()
  {
   if(!g_setupActive||!VisualChart()) return;
   int seconds=PeriodSeconds((ENUM_TIMEFRAMES)_Period); if(seconds<=0) seconds=PeriodSeconds(InpTF);
   datetime end=g_setupBar+(datetime)(seconds*InpSetupLineBars);
   string keys[]={"ENTRY","SL","TP1","TP2","TP3"};
   double prices[]={g_setupEntry,g_setupSL,g_setupTP1,g_setupTP2,g_setupTP3};
   for(int i=0;i<5;i++) if(ObjectFind(0,g_setupPrefix+keys[i])>=0) ObjectMove(0,g_setupPrefix+keys[i],1,end,prices[i]);
   ChartRedraw(0);
  }
void SetupPriceLine(const string key,const double price,const color lineColor,const string text)
  {
   int seconds=PeriodSeconds((ENUM_TIMEFRAMES)_Period); if(seconds<=0) seconds=PeriodSeconds(InpTF);
   datetime end=g_setupBar+(datetime)(seconds*InpSetupLineBars);
   string name=g_setupPrefix+key;
   if(ObjectCreate(0,name,OBJ_TREND,0,g_setupBar,price,end,price))
     {
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false); ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,text+(g_setupContext!=""?"\n"+g_setupContext:""));
     }
  }

bool PublishEntrySetup(const MqlRates &r[],const bool buy,const string pattern,const double atr)
  {
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)||!ValidNumber(tick.bid)||!ValidNumber(tick.ask)||tick.ask<tick.bid) return false;
   double sl=0.0,lot=0.0,tp1=0.0,tp2=0.0,tp3=0.0; string source="";
   // Phân tích không cần lot khả thi để vẽ; khi bấm gửi vẫn kiểm tra rủi ro và margin đầy đủ.
   if(!SelectSL(r,buy,tick,atr,sl,lot,source,0.0,true)) { Log("SETUP_BLOCK | KHONG_CO_SL_CAU_TRUC_HOP_LE"); return false; }
   double entry=buy?tick.ask:tick.bid;
   if(!BuildSetupLevels(buy,entry,sl,tp1,tp2,tp3)) return false;
   ClearEntrySetup();
   g_setupActive=true; g_setupBuy=buy; g_setupBar=r[0].time; g_setupPublishedAt=SetupClock();
   g_setupEntry=entry; g_setupSL=sl; g_setupTP1=tp1; g_setupTP2=tp2; g_setupTP3=tp3;
   g_setupContext=DescribeSetup(r,buy,pattern,atr,entry,sl,source);
   if(VisualChart())
     {
      string side=buy?"BUY":"SELL";
      SetupPriceLine("ENTRY",entry,clrDodgerBlue,StringFormat("%s Entry %.*f",side,_Digits,entry));
      SetupPriceLine("SL",sl,clrTomato,StringFormat("SL %.*f",_Digits,sl));
      SetupPriceLine("TP1",tp1,clrLimeGreen,StringFormat("TP1 %.*f (%.1fR)",_Digits,tp1,InpSetupTP1_R));
      SetupPriceLine("TP2",tp2,clrSeaGreen,StringFormat("TP2 %.*f (%.1fR)",_Digits,tp2,InpSetupTP2_R));
      SetupPriceLine("TP3",tp3,clrGreen,StringFormat("TP3 %.*f (%.1fR)",_Digits,tp3,InpSetupTP3_R));
      ChartRedraw(0);
     }
   g_panelMessage=buy?"Setup BUY: Entry SL TP1 TP2 TP3":"Setup SELL: Entry SL TP1 TP2 TP3";
   if(g_setupContext!="") Log("SETUP_BOI_CANH | "+g_setupContext);
   Log(StringFormat("SETUP_%s | signal=%s | %s | Entry=%.*f | SL=%.*f | TP1=%.*f | TP2=%.*f | TP3=%.*f | SL=%s",buy?"BUY":"SELL",TimeToString(r[1].time,TIME_DATE|TIME_MINUTES),pattern,_Digits,entry,_Digits,sl,_Digits,tp1,_Digits,tp2,_Digits,tp3,source));
   return true;
  }
void UpdateEntryAnalysis(const datetime bar)
  {
   if(!InpShowEntrySetup) return;
   if(g_setupActive&&!SetupStillValid()) ClearEntrySetup();
   if(AnyPositionOnSymbol()) { if(g_setupActive) ClearEntrySetup(); g_analysisConfirmTime=0; return; }
   if(bar==g_analysisBar) return;
   double value[1];
   if(CopyBuffer(hATR,0,1,1,value)!=1||!ValidNumber(value[0])) return;
   int needed=MathMax(InpEntryExtremeLookback+MathMax(3,InpBreakoutBars+1)+1,InpSwingLookback+2*InpSwingStrength+PA_CONFIRM_BARS+2);
   needed=MathMax(needed,InpAlternatingLookback+2);
   if(InpSetupContext) needed=MathMax(needed,InpSetupVolumeBars+7);
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,needed,r)!=needed||r[0].time!=bar||iTime(_Symbol,InpTF,0)!=bar) return;
   if(r[0].time-r[1].time>PeriodSeconds(InpTF))
     { g_analysisBar=bar; g_analysisConfirmTime=0; return; }
   // Hàng chờ xác nhận của phân tích tách khỏi Auto Entry; trả lại toàn bộ trạng thái giao dịch sau khi đọc tín hiệu.
   datetime savedConfirm=g_confirmTime; bool savedBuy=g_confirmBuy; double savedATR=g_atr;
   g_confirmTime=g_analysisConfirmTime; g_confirmBuy=g_analysisConfirmBuy; g_atr=value[0];
   bool buy=false; string pattern="";
   bool signal=EntryWithEMA9(r,buy,pattern);
   g_analysisConfirmTime=g_confirmTime; g_analysisConfirmBuy=g_confirmBuy;
   g_confirmTime=savedConfirm; g_confirmBuy=savedBuy; g_atr=savedATR;
   g_analysisBar=bar;
   if(signal) PublishEntrySetup(r,buy,pattern,value[0]); // Chỉ vẽ, tuyệt đối không gọi SendEntry từ phân tích.
  }
void SendEntry(const MqlRates &r[],const bool buy,const bool manual=false)
  {
   if(manual)
      for(int i=ArraySize(g_pending)-1;i>=0;i--)
         if(!PositionSelectByTicket(g_pending[i])||!OwnPosition()) RemoveExit(i); // Vị thế đã đóng: xóa yêu cầu thoát cũ ngay.
   if(ArraySize(r)<3||ArraySize(g_pending)>0||AnyPositionOnSymbol()||g_manualSending||(!manual&&!CanEnter(r[0].time)))
     { g_panelMessage=manual?"Chan: con vi the/dang gui hoac dong":"Chan: co lenh/da giao dich tren nen"; Log(manual?"CHAN_LENH_TAY | VI_THE_HOAC_YEU_CAU_CHUA_XONG":"CHAN_ENTRY | NEN_DA_CO_GIAO_DICH_HOAC_VI_THE_CHUA_DONG"); return; }
   if(!SymbolEntryAllowed(buy)) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||!ValidNumber(tick.bid)||!ValidNumber(tick.ask)||tick.ask<tick.bid)
     { g_panelMessage="Cho: chua co gia Bid/Ask hop le"; Log("SYMBOL_ENTRY_BLOCK | CHUA_CO_BID_ASK | "+_Symbol); return; }
   double sl=0.0,lot=0.0; string source="";
   if(!SelectSL(r,buy,tick,g_atr,sl,lot,source)) { g_panelMessage="Chan: SL/lot vuot gioi han rui ro"; Log("BO_LENH | KHONG_CO_SL_PHU_HOP_ATR_RUI_RO_LOT"); return; }
   if((!manual&&!ClaimBar(r[0].time))||AnyPositionOnSymbol()) return;
   if(manual) g_manualSending=true;
   string comment=manual?(buy?"GS2 MANUAL BUY":"GS2 MANUAL SELL"):(buy?"GS2 OPEN BUY":"GS2 OPEN SELL");
   trade.SetTypeFillingBySymbol(_Symbol); // FOK/IOC/RETURN theo broker của đúng symbol trước mỗi lần gửi.
   bool sent=buy?trade.Buy(lot,_Symbol,0.0,sl,0.0,comment):trade.Sell(lot,_Symbol,0.0,sl,0.0,comment);
   uint code=trade.ResultRetcode();
   if(manual) g_manualSending=false; // Gửi đồng bộ: từ đây vị thế thực tế quyết định có được mở tiếp hay không.
   if(sent&&(code==TRADE_RETCODE_DONE||code==TRADE_RETCODE_DONE_PARTIAL))
     {
      g_panelMessage=StringFormat("%s %.2f lot | SL %.*f",buy?"BUY":"SELL",lot,_Digits,sl);
      Log(StringFormat("%s | lot=%.8f | SL=%.*f | nguon=%s | SL/ATR=%.2f | BE_distance=%.3f",
          comment,lot,_Digits,sl,source,MathAbs((buy?tick.ask:tick.bid)-sl)/g_atr,InpBreakEvenATR*g_atr));
     }
   else { g_panelMessage="Loi: "+trade.ResultRetcodeDescription(); Log(StringFormat("GUI_LENH_THAT_BAI | %s | retcode=%u | error=%d | %s",_Symbol,code,GetLastError(),trade.ResultRetcodeDescription())); }
  }
int PanelSize(const int size) { return (int)MathRound(size*InpDashboardScale); }
void PanelButton(const string suffix,const string text,const int x,const int y,const int width,const color background)
  {
   string name=g_panelPrefix+suffix;
   if(ObjectFind(0,name)<0&&!ObjectCreate(0,name,OBJ_BUTTON,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,PanelSize(280-x)+InpDashboardShiftLeft);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,PanelSize(8+y));
   ObjectSetInteger(0,name,OBJPROP_XSIZE,PanelSize(width));
   ObjectSetInteger(0,name,OBJPROP_YSIZE,PanelSize(22));
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,PanelSize(9));
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,10);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
  }
void UpdateDashboard(const bool force=false)
  {
   if(!VisualChart()||g_panelPrefix=="") return;
   ulong now=GetTickCount64(); if(!force&&now-g_panelRefresh<1000) return; g_panelRefresh=now;
   PanelButton("BUY","BUY",0,0,50,clrDarkGreen);
   PanelButton("SELL","SELL",56,0,50,clrMaroon);
   PanelButton("CLOSE","DONG",112,0,74,clrDimGray);
   UpdateHistoryButton();
   string mode=InpUseRiskManagement?StringFormat("Risk ON %.2f%%",InpRiskPercent):StringFormat("Risk OFF | Lot %.8f",InpFixedLot);
   string info=StringFormat("%s | %s | BE %.2f ATR | TP %s | %s",_Symbol,mode,InpBreakEvenATR,InpTPWickVolume?(InpTPWickIntrabar?"rau+volume tick":"rau+volume dong nen"):(InpTP2Candles?"2 nen":"EMA9"),g_panelMessage);
   ObjectSetString(0,g_panelPrefix+"BUY",OBJPROP_TOOLTIP,"Mua tay, SL theo cau truc; lot theo che do Risk ON/OFF. "+info);
   ObjectSetString(0,g_panelPrefix+"SELL",OBJPROP_TOOLTIP,"Ban tay, SL theo cau truc; lot theo che do Risk ON/OFF. "+info);
   ObjectSetString(0,g_panelPrefix+"CLOSE",OBJPROP_TOOLTIP,"Dong vi the EA va lenh tay neu bat InpManageManualPositions; khong dong EA Magic khac. "+info);
   ChartRedraw(0);
  }
void ManualEntry(const bool buy)
  {
   double value[1];
   if(CopyBuffer(hATR,0,1,1,value)!=1||!ValidNumber(value[0]))
     { g_panelMessage="Cho: chua co ATR"; Log("MANUAL_BLOCK | ATR_CHUA_SAN_SANG | "+_Symbol); return; }
   int needed=InpSwingLookback+2*InpSwingStrength+PA_CONFIRM_BARS+2;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,needed,r)!=needed||r[0].time!=iTime(_Symbol,InpTF,0))
     { g_panelMessage="Cho: chua du nen tinh SL"; Log("MANUAL_BLOCK | THIEU_LICH_SU_NEN | "+_Symbol); return; }
   g_atr=value[0];
   SendEntry(r,buy,true); // Lệnh tay qua SL/lot/risk, chỉ một vị thế; đã đóng thì được mở lại dù vẫn cùng nến.
  }
void HandlePanelAction(const string name)
  {
   if(name!=g_panelPrefix+"BUY"&&name!=g_panelPrefix+"SELL"&&name!=g_panelPrefix+"CLOSE") return;
   if(!VisualChart()||ObjectFind(0,name)<0||!ObjectGetInteger(0,name,OBJPROP_STATE)) return;
   ObjectSetInteger(0,name,OBJPROP_STATE,false); // Reset trước khi gửi: không gửi trùng giữa event và polling.
   if(name==g_panelPrefix+"BUY") ManualEntry(true);
   else if(name==g_panelPrefix+"SELL") ManualEntry(false);
   else if(name==g_panelPrefix+"CLOSE")
     {
      int n=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
        { ulong ticket=PositionGetTicket(i); if(ticket>0&&OwnPosition()) { QueueExit(ticket); n++; } }
      if(n>0) { g_exitBar=iTime(_Symbol,InpTF,0); ClearEMA9Wait(); g_exitRetry=0; RetryExits(); g_panelMessage="Da yeu cau dong lenh EA"; }
      else g_panelMessage="Khong co lenh cua EA de dong";
     }
   Log("DASHBOARD | "+g_panelMessage);
   UpdateDashboard(true);
  }
void PollDashboard()
  {
   if(!VisualChart()||g_panelPrefix=="") return;
   ulong now=GetTickCount64(); if(now-g_panelPoll<200) return; g_panelPoll=now;
   HandlePanelAction(g_panelPrefix+"BUY");
   HandlePanelAction(g_panelPrefix+"SELL"); HandlePanelAction(g_panelPrefix+"CLOSE");
   UpdateDashboard();
  }
void OnTimer()
  {
   PollHistoryButton(); PollDashboard(); ScanMissingSL(); BreakEven(); RetryExits();
   if(g_setupActive&&(!SetupStillValid()||AnyPositionOnSymbol())) ClearEntrySetup();
  }
bool VisualChart()
  { return !(bool)MQLInfoInteger(MQL_TESTER)||(bool)MQLInfoInteger(MQL_VISUAL_MODE); }
string DealRole(const long type,const long entry)
  {
   if(entry==DEAL_ENTRY_IN) return type==DEAL_TYPE_BUY?"OPEN BUY":"OPEN SELL";
   if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY) return type==DEAL_TYPE_SELL?"CLOSE BUY":"CLOSE SELL";
   return "REVERSE";
  }
void DrawDeal(const ulong ticket)
  {
   if(!VisualChart()||!g_showHistory||g_historyPrefix=="") return;
   if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol||
      (long)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=InpMagic) return;
   long type=HistoryDealGetInteger(ticket,DEAL_TYPE),entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
   if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL) return;
   datetime when=(datetime)HistoryDealGetInteger(ticket,DEAL_TIME);
   double price=HistoryDealGetDouble(ticket,DEAL_PRICE);
   if(when<=0||price<=0.0) return;
   string name=g_historyPrefix+StringFormat("%I64u",ticket);
   if(ObjectFind(0,name)>=0) return;
   if(!ObjectCreate(0,name,OBJ_TEXT,0,when,price)) return;
   string role=DealRole(type,entry);
   ObjectSetString(0,name,OBJPROP_TEXT,role);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,entry==DEAL_ENTRY_IN?(type==DEAL_TYPE_BUY?clrLimeGreen:clrTomato):clrSilver);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,type==DEAL_TYPE_BUY?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,StringFormat("#%I64u | %s | %s | price=%.*f | lot=%.4f | P/L=%.2f",ticket,
      role,TimeToString(when,TIME_DATE|TIME_SECONDS),_Digits,price,HistoryDealGetDouble(ticket,DEAL_VOLUME),
      HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_COMMISSION)+HistoryDealGetDouble(ticket,DEAL_SWAP)));
  }
void RestoreHistory()
  {
   if(!VisualChart()||!g_showHistory||!HistorySelect(0,TimeCurrent())) return;
   for(int i=0;i<HistoryDealsTotal();i++)
     { ulong ticket=HistoryDealGetTicket(i); if(ticket>0) DrawDeal(ticket); }
  }
void UpdateHistoryButton()
  {
   if(!VisualChart()||g_historyButton=="") return;
   if(ObjectFind(0,g_historyButton)<0)
     {
      if(!ObjectCreate(0,g_historyButton,OBJ_BUTTON,0,0,0)) return;
      ObjectSetInteger(0,g_historyButton,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,g_historyButton,OBJPROP_XDISTANCE,PanelSize(88)+InpDashboardShiftLeft);
      ObjectSetInteger(0,g_historyButton,OBJPROP_YDISTANCE,PanelSize(8));
      ObjectSetInteger(0,g_historyButton,OBJPROP_XSIZE,PanelSize(76));
      ObjectSetInteger(0,g_historyButton,OBJPROP_YSIZE,PanelSize(22));
      ObjectSetInteger(0,g_historyButton,OBJPROP_FONTSIZE,PanelSize(9));
      ObjectSetInteger(0,g_historyButton,OBJPROP_ZORDER,10);
      ObjectSetInteger(0,g_historyButton,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,g_historyButton,OBJPROP_SELECTABLE,false);
     }
   ObjectSetString(0,g_historyButton,OBJPROP_TEXT,g_showHistory?"Hist":"Hist");
   ObjectSetString(0,g_historyButton,OBJPROP_TOOLTIP,"Hien/an lich su lenh; khong doi quy tac giao dich");
   ObjectSetInteger(0,g_historyButton,OBJPROP_BGCOLOR,g_showHistory?clrDarkGreen:clrDimGray);
   ObjectSetInteger(0,g_historyButton,OBJPROP_STATE,false);
  }
void ToggleHistory()
  {
   g_showHistory=!g_showHistory;
   ChartSetInteger(0,CHART_SHOW_TRADE_HISTORY,g_showHistory);
   if(g_showHistory) RestoreHistory();
   else ObjectsDeleteAll(0,g_historyPrefix);
   UpdateHistoryButton(); ChartRedraw(0);
  }
void PollHistoryButton()
  {
   if(!VisualChart()||g_historyButton=="") return;
   ulong now=GetTickCount64();
   if(now-g_historyPoll<200) return; // Giới hạn đọc nút theo thời gian thực, không tạo timer làm chậm tester.
   g_historyPoll=now;
   if(ObjectFind(0,g_historyButton)>=0&&ObjectGetInteger(0,g_historyButton,OBJPROP_STATE)) ToggleHistory();
  }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_CHART_CHANGE) { ResizeSetupLines(); return; }
   if(id==CHARTEVENT_OBJECT_CLICK&&sparam==g_historyButton&&
      ObjectGetInteger(0,g_historyButton,OBJPROP_STATE)) ToggleHistory();
   else if(id==CHARTEVENT_OBJECT_CLICK) HandlePanelAction(sparam);
  }
int OnInit()
  {
   double values[]={InpTPWickBodyRatio,InpTPVolumeHigh,InpSetupVolumeHigh,InpSetupVolumeLow,InpEMA9ChopRangeATR,InpEntryProminenceATR,InpEntryMinBodyATR,InpEntryOppWickRatio,InpTP_EMA9Angle,InpTP_EMA9FlatATR,InpEMA9EntryAngle,InpEMA9AngleScaleATR,InpEMA9MinSlopeATR,InpEMA9FlatATR,InpDojiBodyRatio,InpStarMiddleRatio,InpSLBufferATR,InpMinSL_ATR,InpMaxSL_ATR,
                    InpSetupTP1_R,InpSetupTP2_R,InpSetupTP3_R,InpFixedLot,InpDashboardScale,InpEarlyExitSlopeRatio,InpTPPullbackATR,InpEarlyExitMaxSlopeATR,InpTPDecelerationRatio,InpBreakEvenATR,InpBreakEvenMinR,InpRiskPercent,InpMaxLot,InpCommissionPerLot};
   for(int i=0;i<ArraySize(values);i++) if(!MathIsValidNumber(values[i])) return INIT_PARAMETERS_INCORRECT;
   if(InpTPWickBodyRatio<1.0||InpTPVolumeBars<5||InpTPVolumeBars>200||InpTPVolumeHigh<=1.0||InpAlternatingLookback<4||InpAlternatingLookback>20||InpBreakoutBars<2||InpBreakoutBars>6||InpEMA9ChopRangeATR<=0.0||InpEntryProminenceATR<=0.0||InpEMA9ChopBars<3||InpEMA9ChopBars>20||InpEntryMinBodyATR<=0.0||InpEntryOppWickRatio<=0.0||InpEntryExtremeLookback<2||InpEntryExtremeLookback>40||InpTP_EMA9Angle<=0.0||InpTP_EMA9Angle>=180.0||InpTP_EMA9FlatATR<=0.0||InpEMA9EntryAngle<=0.0||InpEMA9EntryAngle>=180.0||InpEMA9TurnBars<1||InpEMA9TurnBars>10||
      InpEMA9AngleScaleATR<=0.0||InpEMA9MinSlopeATR<=0.0||InpEMA9FlatATR<=0.0||InpDojiBodyRatio<0.0||InpDojiBodyRatio>=1.0||
      InpStarMiddleRatio<=0.0||InpStarMiddleRatio>=1.0||InpATRPeriod<2||InpSwingLookback<1||
      InpSwingLookback>500||InpSwingStrength<1||InpSwingStrength>10||InpSLBufferATR<0.0||
      InpMinSL_ATR<=0.0||InpMaxSL_ATR<InpMinSL_ATR||InpBreakEvenATR<=0.0||InpBreakEvenMinR<0.0||
      InpEarlyExitSlopeRatio<=0.0||InpEarlyExitSlopeRatio>=1.0||InpTPPullbackATR<=0.0||InpEarlyExitMaxSlopeATR<=0.0||InpTPDecelerationRatio<=0.0||InpTPDecelerationRatio>=1.0||
      InpSetupVolumeBars<5||InpSetupVolumeBars>200||InpSetupVolumeLow<=0.0||InpSetupVolumeLow>=1.0||InpSetupVolumeHigh<=1.0||InpSetupTP1_R<=0.0||InpSetupTP2_R<=InpSetupTP1_R||InpSetupTP3_R<=InpSetupTP2_R||InpSetupValidSeconds<1||InpSetupValidSeconds>86400||InpSetupLineBars<1||InpSetupLineBars>100||
      InpDashboardShiftLeft<0||InpDashboardShiftLeft>10000||InpDashboardScale<0.8||InpDashboardScale>2.0||(InpUseRiskManagement&&(InpRiskPercent<=0.0||InpRiskPercent>100.0))||(!InpUseRiskManagement&&InpFixedLot<=0.0)||InpMaxLot<0.0||InpCommissionPerLot<0.0||
      InpSlippagePoints<0||InpRiskReservePoints<0||InpMagic<=0||PeriodSeconds(InpTF)<=0)
      return INIT_PARAMETERS_INCORRECT;
   hATR=iATR(_Symbol,InpTF,InpATRPeriod); if(hATR==INVALID_HANDLE) return INIT_FAILED;
   if(InpUseEMA9Entry||InpTPAfterBE_EMA9||InpHoldUntilEMA9Cross||InpExitOppositeBeforeBE)
     {
      hEMA9=iMA(_Symbol,InpTF,9,0,MODE_EMA,PRICE_CLOSE);
      if(hEMA9==INVALID_HANDLE) { IndicatorRelease(hATR); hATR=INVALID_HANDLE; return INIT_FAILED; }
     }
   if(InpSetupContext) hSetupEMA21=iMA(_Symbol,InpTF,21,0,MODE_EMA,PRICE_CLOSE);
   ClearEMA9Wait();
   trade.SetExpertMagicNumber((ulong)InpMagic); trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol); trade.SetAsyncMode(false);
   g_bar=iTime(_Symbol,InpTF,0); g_attemptBar=0; g_exitBar=0; g_exitRetry=0; g_beRetry=0; g_atr=0.0; g_beEntryATR=0.0; g_bePositionID=0;
   g_beRiskPositionID=0; g_beInitialRisk=0.0;
   g_slScanRetry=0; g_slScanNotice=0;
   g_tpPositionID=0; g_tpPeakMove=0.0;
   g_exitCheckBar=0; g_wickTPCheck=0;
   g_extremePositionID=0; g_extremeLastTime=0; g_tpExtreme=0.0; g_noNewExtremeBars=0;
   g_autoTrading=InpEnableTrading; g_manualSending=false; g_panelPoll=0; g_panelRefresh=0;
   g_setupPrefix=StringFormat("GS2_%I64d_%I64d_SETUP_",ChartID(),InpMagic);
   g_setupActive=false; g_setupBar=0; g_setupPublishedAt=0; g_analysisBar=g_bar; g_analysisConfirmTime=0; g_analysisConfirmBuy=false;
   g_panelMessage=g_autoTrading?"Auto bat: cho tin hieu moi":"Auto tat: vao lenh bang BUY/SELL";
   g_panelPrefix=StringFormat("GS2_%I64d_%I64d_PANEL_",ChartID(),InpMagic);
   ArrayResize(g_pending,0); ArrayResize(g_pendingMode,0);
   g_showHistory=InpShowHistory;
   g_historyPrefix=StringFormat("GS2_%I64d_%I64d_D_",ChartID(),InpMagic);
   g_historyButton=StringFormat("GS2_%I64d_%I64d_HIST",ChartID(),InpMagic);
   if(VisualChart())
     {
      g_nativeHistory=(bool)ChartGetInteger(0,CHART_SHOW_TRADE_HISTORY);
      ChartSetInteger(0,CHART_SHOW_TRADE_HISTORY,g_showHistory);
      ObjectsDeleteAll(0,g_historyPrefix); UpdateHistoryButton(); RestoreHistory(); ChartRedraw(0);
      UpdateDashboard(true); EventSetMillisecondTimer(250);
      ObjectsDeleteAll(0,g_setupPrefix);
     }
   Log(StringFormat("G_Scalp_m5 V2.0 build 2.57 | %s | %s | AUTO=%s | AutoSL=%s | manual=%s",_Symbol,EnumToString(InpTF),g_autoTrading?"ON":"OFF",InpAutoScanSL?"ON":"OFF",InpManageManualPositions?"ON":"OFF"));
   Log(StringFormat("SYMBOL | %s | minLot=%.8f | step=%.8f | maxLot=%.8f | tickSize=%.8f | stopPoints=%I64d | tradeMode=%I64d",_Symbol,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),TickSize(),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE)));
   Log(StringFormat("CONFIG | chartTF=%s | signalTF=%s | EMA9_angle=%.1f | BE=%.2f ATR_AT_ENTRY",
                    EnumToString((ENUM_TIMEFRAMES)_Period),EnumToString(InpTF),InpEMA9EntryAngle,InpBreakEvenATR));
   Log(StringFormat("BE_CONFIG | can_dat_ca %.2f ATR va %.2f R | initialR=Entry-SL ban dau",InpBreakEvenATR,InpBreakEvenMinR));
   Log(StringFormat("RISK_MODE | %s | fixedLot=%.8f | riskPct=%.2f",InpUseRiskManagement?"ON":"OFF_TEST",InpFixedLot,InpRiskPercent));
   Log(StringFormat("SETUP_ANALYSIS | %s | TP=%.1fR/%.1fR/%.1fR | hide=%d giay hoac sau Entry",InpShowEntrySetup?"ON":"OFF",InpSetupTP1_R,InpSetupTP2_R,InpSetupTP3_R,InpSetupValidSeconds));
   return INIT_SUCCEEDED;
  }
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);
   hATR=INVALID_HANDLE;
   if(hEMA9!=INVALID_HANDLE) IndicatorRelease(hEMA9);
   hEMA9=INVALID_HANDLE; ClearEMA9Wait(); ArrayResize(g_pending,0); ArrayResize(g_pendingMode,0);
   if(hSetupEMA21!=INVALID_HANDLE) IndicatorRelease(hSetupEMA21);
   hSetupEMA21=INVALID_HANDLE;
   ClearEntrySetup();
   if(VisualChart()&&g_historyPrefix!="")
     {
      ObjectsDeleteAll(0,g_historyPrefix); ObjectDelete(0,g_historyButton);
      ObjectsDeleteAll(0,g_panelPrefix);
      ChartSetInteger(0,CHART_SHOW_TRADE_HISTORY,g_nativeHistory); ChartRedraw(0);
     }
  }
void OnTick()
  {
   if(g_setupActive&&!SetupStillValid()) ClearEntrySetup();
   PollHistoryButton();
   PollDashboard();
   RetryExits();
   datetime bar=iTime(_Symbol,InpTF,0);
   if(bar<=0) return;
   ScanMissingSL(); // Quét lệnh thiếu SL độc lập với Auto Entry và xử lý theo tick.
   BreakEven(); // Bảo vệ BE trên mọi tick, trước khi đánh giá TP của nến mới.
   CheckIntrabarTP(bar); RetryExits(); // TP theo EMA9 đang chạy trước chặn xử lý lặp nến.
   if(g_exitCheckBar!=bar&&ArraySize(g_pending)==0)
     {
      MqlRates closed[]; ArraySetAsSeries(closed,true);
      int exitBars=InpTPWickVolume&&!InpTPWickIntrabar?InpTPVolumeBars+3:3;
      if(CopyRates(_Symbol,InpTF,0,exitBars,closed)!=exitBars||closed[0].time!=bar) return;
      if(!CheckExits(closed)) return; // Dữ liệu chưa sẵn sàng: thử lại tick kế tiếp, không đánh dấu đã xét.
      g_exitCheckBar=bar; RetryExits();
     }
   UpdateEntryAnalysis(bar); // Phân tích riêng sau quản lý SL/BE/TP; Auto OFF vẫn vẽ setup, không gửi lệnh.
   if(bar==g_bar) return;
   double value[1];
   if(CopyBuffer(hATR,0,1,1,value)==1&&ValidNumber(value[0])) g_atr=value[0];
   else g_atr=0.0;
   g_bar=bar; // Chỉ xét Entry một lần ở nến mới; không đuổi theo tín hiệu chậm.
   BreakEven();
   if(!g_autoTrading||g_exitBar==bar||ArraySize(g_pending)>0||!ValidNumber(g_atr)||!CanEnter(bar)) { ClearEMA9Wait(); return; }
   int needed=MathMax(InpEntryExtremeLookback+MathMax(3,InpBreakoutBars+1)+1,InpSwingLookback+2*InpSwingStrength+PA_CONFIRM_BARS+2);
   needed=MathMax(needed,InpAlternatingLookback+2);
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,InpTF,0,needed,r)!=needed||r[0].time!=bar||iTime(_Symbol,InpTF,0)!=bar) { ClearEMA9Wait(); return; }
   if(r[0].time-r[1].time>PeriodSeconds(InpTF)) { ClearEMA9Wait(); Log("BO_LENH | TIN_HIEU_TRUOC_KHOANG_NGHI"); return; }
   bool buy=false; string reason;
   if(EntryWithEMA9(r,buy,reason)) SendEntry(r,buy);
   else if(reason!="") Log("BO_CHUOI | "+reason);
  }
void LockDealBar(const datetime when,const long entry)
  {
   if(when<=0) return;
   int shift=iBarShift(_Symbol,InpTF,when,false);
   datetime bar=shift>=0?iTime(_Symbol,InpTF,shift):iTime(_Symbol,InpTF,0);
   if(bar<=0) return;
   if(entry==DEAL_ENTRY_IN||entry==DEAL_ENTRY_INOUT)
      g_attemptBar=(datetime)MathMax(g_attemptBar,bar);
   if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY||entry==DEAL_ENTRY_INOUT)
     {
      g_exitBar=(datetime)MathMax(g_exitBar,bar);
      ClearEMA9Wait(); // Sau SL/TP/đóng tay, không dùng lại tín hiệu đã chờ để mở lại cùng nến.
     }
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||trans.deal==0||!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol) return;
   long type=HistoryDealGetInteger(trans.deal,DEAL_TYPE),entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL) return;
   if(g_setupActive&&(entry==DEAL_ENTRY_IN||entry==DEAL_ENTRY_INOUT)) ClearEntrySetup();
   LockDealBar((datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME),entry);
   // Khóa Entry theo symbol; chỉ vẽ và quản lý SL/TP cho Magic của EA này.
   if((long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagic) return;
   string role=DealRole(type,entry);
   Log(StringFormat("DEAL #%I64u | %s | position=%I64d",trans.deal,role,HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID)));
   if(VisualChart()&&g_showHistory) { DrawDeal(trans.deal); ChartRedraw(0); }
  }
