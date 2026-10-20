// C7CB L COMPACT v2.37: L engine only; causal forecasts; 600-bar startup.
#property strict
#property version "2.37"
#property indicator_chart_window
#property indicator_buffers 38
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
input group "MTF — DU BAO M30 / H1"
input string InpForecastConfig=""; // Internal: keep empty on chart
input bool InpForecastWorker=false; // Internal: keep FALSE on chart
input bool InpForecastM30=true;
input bool InpForecastH1=true;
input group "00 — L FORECAST / DU BAO CO DIEU KIEN"
input int InpStartupBars=600; // 500..700 closed bars on attach / history reset
input bool InpLForecast=true;
input int InpForecastLookback=80; // 30..200, closed bars only
input int InpForecastLife=12; // bars after publication, never extended
input int InpForecastMinScore=65; // heuristic points, NOT win probability
input bool InpSmartScoreFilter=false; // optional extra filter for actual L
input int InpSmartMinScore=60;

input group "01 — CHUNG / LICH SU ENTRY / CANH BAO"
input bool InpNewLimitSetup=true; // L: vùng chờ limit, không phải lệnh đã khớp
input bool InpNewAlerts=true;
input bool InpEnabled=true; // OFF: hide drawings and stop signal calculations
input bool InpShowHistory=false; // false: only the newest five signal marks
input bool InpUseRealVolume=false; // true: real volume; fallback tick neu thieu du lieu
input int InpArrowOffsetPixels=12;
input color InpUpColor=clrLimeGreen;
input color InpDownColor=C'255,0,4';

input group "02 — HIEN THI WYCKOFF / HISTORY / CO CHU"
input bool InpProEventMarks=true; // Sự kiện Wyckoff: chữ nhỏ + tam giác
input bool InpWyHistory=false; // Lịch sử Wy riêng; OFF chỉ giữ InpWyKeepEvents sự kiện
input int InpWyKeepEvents=5; // History OFF: giữ N sự kiện gần nhất, giảm object và bộ nhớ vẽ
input int InpWyFontSize=7;
input int InpWyBCFontSize=7; // Cỡ chữ riêng BC; các nhãn khác giữ InpWyFontSize
input bool InpWyStandaloneClimax=true; // SC/BC mờ khi chưa xác nhận; KHÔNG tự xác nhận chuỗi hoặc đổi entry

input group "03 — HIEN THI S-D / KEYLEVEL / MAU SAC"
input bool InpShowLiveLevels=true; // Chỉ bản đồ S/D và key còn hiệu lực HIỆN TẠI
input bool InpLiveChartLevels=true;
input bool InpLiveMTFLevels=true; // Theo từng công tắc M15/H1/H4/D1
input bool InpLiveClosedBarKeys=false; // OFF: bỏ H/L nến TF vừa đóng, chỉ giữ pivot/key cấu trúc
input int InpLiveFontSize=7;
input int InpLiveLabelOffsetBars=10; // Chữ TF ở bên trái nến 0, theo số nến của TF chart
input int InpLiveMaxLabels=18; // Giới hạn tên trên chart; chi tiết nằm trong tooltip vùng
input int InpLivePerSide=1; // Mỗi nguồn: N vùng/mốc gần nhất cho mỗi hướng
input color InpLiveDemandColor=clrDarkGreen;
input color InpLiveSupplyColor=clrMaroon;
input color InpLiveSupportColor=clrSeaGreen;
input color InpLiveResistanceColor=clrIndianRed;

input group "04 — TF BOI CANH: M15 / H1 / H4 / D1"
input bool InpMTF_M15=true; // OFF: không đọc/tính M15
input bool InpMTF_H1=true; // OFF: không đọc/tính H1
input bool InpMTF_H4=true; // OFF: không đọc/tính H4
input bool InpMTF_D1=true; // OFF: không đọc/tính D1
input bool InpMTFZones=true; // Vùng cung/cầu trên các TF đang bật
input bool InpMTFKeyLevels=true; // Đỉnh/đáy pivot đã xác nhận + H/L nến TF vừa đóng
input int InpMTFLookback=150; // 30..250 nến mỗi TF

input group "05 — WYCKOFF / ELLIOTT: BAT-TAT VA NHAN DIEN"
input bool InpProEnabled=true;
input bool InpProWyckoff=true;
input bool InpProElliott=true;
input bool InpProFilterWy=false; // OFF: chỉ đọc, không chặn L
input bool InpProFilterEW=false; // OFF: chỉ đọc, không chặn L
input double InpProClimaxRV=1.5;
input double InpProApproachATR=0.8;
input double InpProARatr=1.0;
input int InpProWyMaxBars=200;
input int InpProTestBars=12;
input int InpProEWStrength=2;
input int InpProEWStrengthMajor=5;
input double InpProEWMinATR=0.5;
input double InpProEWMinATRMajor=1.2;

input group "06 — QUYEN HUONG NHIP / SOS-SOW"
input bool InpImpulseControl=true; // Nhịp Close hiệu quả chi phối L trước khi đủ chuỗi Wyckoff
input double InpImpulseMoveATR=1.2;
input double InpImpulseEfficiency=0.65;
input double InpImpulseFailureATR=0.10;
input bool InpImpulseLocationReversal=true; // Ngoại lệ tại vùng lớn: hai Close + phủ nhận nến đi vào
input bool InpWyDirectionalControl=true; // SOS/SOW xác nhận chi phối L; OFF để đối chiếu
input double InpWyFailureATR=0.35; // Hai Close mất mốc phá biên mới giải khóa hướng cũ
input bool InpWyLPSLocation=true; // Tạo ứng viên L ở lần test đầu sau SOS/SOW

input group "07 — L: VI TRI / VOLUME / CAU TRUC / CHON UNG VIEN"
input bool InpLArbitrate=true; // Chọn một ứng viên tốt nhất mỗi hướng trên nến đóng
input bool InpLCycleLock=true; // Không phát lại cùng vùng trước khi có nhịp rời vùng độc lập
input double InpLCycleDepartureATR=1.0;
input bool InpLLocationMajorOnly=true; // Nhánh vị trí chart: cực trị 20 nến hoặc rời vùng >= 2 ATR
input bool InpLLocationEntry=true; // Nhánh L tại S/D hoặc key level đã biết trước khi giá chạm
input bool InpLLocationChart=true;
input bool InpLLocationMTF=true; // Dùng M15/H1/H4/D1 theo các công tắc TF hiện có
input double InpLLocationNearATR=0.25;
input double InpLLocationDepartureATR=1.0;
input int InpLLocationWaitBars=6;
input bool InpLLocationLowVolTest=true; // Chỉ ngoại lệ MA20 khi test vùng có dừng lực + hai Close giữ
input bool InpLVolumeLock=true; // L: volume nến XÁC NHẬN >= MA20 của 20 nến trước
input double InpLMinRelativeVolume=1.0; // 1.0 = MA20; không bắt volume nến quét/test
input bool InpLSellLocationCounter=true; // Sell tại vùng: ngoại lệ SOS có hai Close + mất hiệu quả, không xóa quyền Buy
input bool InpLSellTop=true; // Chỉ Sell: đỉnh mất hiệu quả + Close từ chối; Buy không đổi
input int InpSellTopWaitBars=6;
input double InpSellTopPriorMoveATR=1.0;
input bool InpLStructureTurn=true; // Nhịp phá cấu trúc + lần hồi đầu; không chờ đủ HH/HL/LH/LL mới
input double InpTurnMinMoveATR=1.0;
input int InpTurnWaitBars=10;
input bool InpLContinuation=true; // Sinh L tại HL/LH, không cần quét đáy/đỉnh 20 nến
input bool InpLRangeTest=true; // Sinh L tại mép biên đã có test tách biệt
input bool InpLContinuationRequireBreak=true; // Nhịp đẩy phải vượt đỉnh/đáy đối ứng trước bằng Close
input double InpLContinuationPushATR=0.8;
input double InpLContinuationMaxRetrace=0.75;
input int InpLContinuationPullBars=2;
input bool InpLRespectFlow=true; // L xét đỉnh/đáy trước, mép biên, phá cấu trúc và lực Close
input double InpLRangeEdgeFraction=0.25; // Chỉ xét L tại 25% sát mép khi đi ngang
input double InpLSwingToleranceATR=0.15; // Dung sai HH/HL, LH/LL và phá mốc
input double InpLFlowMoveATR=0.8;
input double InpLFlowEfficiency=0.60;
input double InpLReversalCloseATR=0.35;
input int InpLFlowWaitBars=3;

input group "08 — L: KIET SUC"
input bool InpProExhaustionL=true; // Nhánh riêng; OFF trả về đúng lõi L cũ
input double InpProExhaustMoveATR=0.8;

input group "09 — L: GIOI HAN NHIP / DO SAU HOI"
input double InpLMinPullbackATR=0.3;
input int InpLMaxWaveBars=100;
input int InpLMaxPullbackBars=8; // Đọc hồi trước phản ứng Close đầu tiên

input group "10 — L: QUET / PHAN UNG / VUNG CHO / HUY"
input int InpNewSweepBars=20; // Cực trị đã biết trước cú quét, không cần pivot tương lai
input int InpNewReactionBars=3; // Tối đa số nến để lấy lại mốc sau cú quét
input int InpNewLimitLife=10; // Hết hạn lệnh chờ sau N nến
input double InpNewMinPriorMoveATR=0.7;
input double InpNewReactionATR=0.35;
input double InpNewZoneMaxATR=0.6;
input double InpNewStopBufferATR=0.1;
input double InpNewCancelRunATR=3.0; // Chạy quá xa khỏi vùng mà chưa hồi: hủy chờ

input group "11 — TOOLTIP / DOC NHIP / BOI CANH ENTRY"
input bool InpShowEntryContext=true; // Đọc bối cảnh; không thay đổi tín hiệu gốc
input int InpContextKeep=1; // Chú thích 1..10 entry gần nhất, gộp cùng nến/cùng hướng
input int InpContextTrendBars=40; // Cửa sổ cấu trúc, chỉ dùng nến trước entry
input int InpContextSwingStrength=2; // Pivot phải có đủ nến xác nhận trước entry
input int InpContextLegBars=5; // So N nến ngay trước với N nến trước đó
input double InpContextWeakeningRatio=0.75; // Lực thân ngược giảm ít nhất 25%
input bool InpPivotMarketReader=true; // Bộ đọc nền-nhịp-lực-volume, chỉ quan sát; không thêm chặn entry
input int InpReaderPivotLookback=500; // 60..2000: giới hạn tìm pivot; không cắt nhịp còn trong giới hạn
input bool InpReaderLiveTooltip=true; // Một dấu BC ở nến vừa đóng, hover đọc thị trường hiện tại
input bool InpContextDebugDetails=false; // OFF: tooltip 4 dòng; ON: đầy đủ số liệu chẩn đoán
input int InpContextFollowBars=3; // Chỉ theo dõi nến đóng sau entry; độc lập xác nhận tín hiệu gốc
input int InpContextFontSize=6;
input double InpContextFarZoneATR=1.0; // Từ khoảng cách này ghi "xa vùng"

input group "12 — S-D / KEYLEVEL: DU LIEU BOI CANH"
input int InpZoneLookback=150; // Tìm vùng trên khung chart, tối đa 250 nến trước entry
input double InpZoneDepartureATR=1.0; // Rời vùng pivot >= 1 ATR để công nhận vùng
input double InpZoneNearATR=0.25; // Khoảng cách tối đa để coi entry gần vùng/mốc
input double InpZoneInvalidATR=0.05; // Đóng xuyên biên xa thêm 0.05 ATR: vùng hết hiệu lực

input group "13 — CHAT LUONG ENTRY / CHUYEN LUC"
input int InpQualityLookback=20; // 12..40 nến; chia đợt theo biến động Close
input double InpQualityPullbackATR=1.0; // Hồi đủ ATR mới tách nhịp chính; hồi nhỏ không đặt lại gốc
input double InpQualityMaxRiskATR=2.0; // Khoảng bảo vệ cấu trúc tối đa/ATR
input double InpQualityMaxExtensionATR=2.5; // Khoảng chạy từ đầu đợt/ATR
input double InpQualityMinRoomRisk=1.2; // Khoảng trống tới vùng đối diện / khoảng bảo vệ

input group "14 — CHAN DOAN: MAC DINH OFF"
input int InpLDiagnosticsBars=300; // Giới hạn log ở N nến cuối, tránh tràn Experts
input bool InpLDiagnostics=false; // Log lý do từng nhánh tại đóng nến; mặc định OFF
input bool InpDebugNewBars=false; // Tam bat de kiem tra moi nen dong; tat sau khi chan doan

input group "15 — LEGACY C7CB: TUONG THICH BO CU"
input bool InpUseWickRetest=false; // Mac dinh tat nhom bo loc bo sung; chi dung bo loc C7CB goc
input bool InpUseC7CB=false; // Bat/tat rieng logic C7CB
input bool InpUseStructure12=false; // Mac dinh tat nhom bo loc bo sung; chi dung bo loc C7CB goc
input bool InpEnablePush=false;


bool cfg_InpForecastM30;
bool cfg_InpForecastH1;
int cfg_InpStartupBars;
bool cfg_InpLForecast;
int cfg_InpForecastLookback;
int cfg_InpForecastLife;
int cfg_InpForecastMinScore;
bool cfg_InpSmartScoreFilter;
int cfg_InpSmartMinScore;
bool cfg_InpNewLimitSetup;
bool cfg_InpNewAlerts;
bool cfg_InpEnabled;
bool cfg_InpShowHistory;
bool cfg_InpUseRealVolume;
int cfg_InpArrowOffsetPixels;
color cfg_InpUpColor;
color cfg_InpDownColor;
bool cfg_InpProEventMarks;
bool cfg_InpWyHistory;
int cfg_InpWyKeepEvents;
int cfg_InpWyFontSize;
int cfg_InpWyBCFontSize;
bool cfg_InpWyStandaloneClimax;
bool cfg_InpShowLiveLevels;
bool cfg_InpLiveChartLevels;
bool cfg_InpLiveMTFLevels;
bool cfg_InpLiveClosedBarKeys;
int cfg_InpLiveFontSize;
int cfg_InpLiveLabelOffsetBars;
int cfg_InpLiveMaxLabels;
int cfg_InpLivePerSide;
color cfg_InpLiveDemandColor;
color cfg_InpLiveSupplyColor;
color cfg_InpLiveSupportColor;
color cfg_InpLiveResistanceColor;
bool cfg_InpMTF_M15;
bool cfg_InpMTF_H1;
bool cfg_InpMTF_H4;
bool cfg_InpMTF_D1;
bool cfg_InpMTFZones;
bool cfg_InpMTFKeyLevels;
int cfg_InpMTFLookback;
bool cfg_InpProEnabled;
bool cfg_InpProWyckoff;
bool cfg_InpProElliott;
bool cfg_InpProFilterWy;
bool cfg_InpProFilterEW;
double cfg_InpProClimaxRV;
double cfg_InpProApproachATR;
double cfg_InpProARatr;
int cfg_InpProWyMaxBars;
int cfg_InpProTestBars;
int cfg_InpProEWStrength;
int cfg_InpProEWStrengthMajor;
double cfg_InpProEWMinATR;
double cfg_InpProEWMinATRMajor;
bool cfg_InpImpulseControl;
double cfg_InpImpulseMoveATR;
double cfg_InpImpulseEfficiency;
double cfg_InpImpulseFailureATR;
bool cfg_InpImpulseLocationReversal;
bool cfg_InpWyDirectionalControl;
double cfg_InpWyFailureATR;
bool cfg_InpWyLPSLocation;
bool cfg_InpLArbitrate;
bool cfg_InpLCycleLock;
double cfg_InpLCycleDepartureATR;
bool cfg_InpLLocationMajorOnly;
bool cfg_InpLLocationEntry;
bool cfg_InpLLocationChart;
bool cfg_InpLLocationMTF;
double cfg_InpLLocationNearATR;
double cfg_InpLLocationDepartureATR;
int cfg_InpLLocationWaitBars;
bool cfg_InpLLocationLowVolTest;
bool cfg_InpLVolumeLock;
double cfg_InpLMinRelativeVolume;
bool cfg_InpLSellLocationCounter;
bool cfg_InpLSellTop;
int cfg_InpSellTopWaitBars;
double cfg_InpSellTopPriorMoveATR;
bool cfg_InpLStructureTurn;
double cfg_InpTurnMinMoveATR;
int cfg_InpTurnWaitBars;
bool cfg_InpLContinuation;
bool cfg_InpLRangeTest;
bool cfg_InpLContinuationRequireBreak;
double cfg_InpLContinuationPushATR;
double cfg_InpLContinuationMaxRetrace;
int cfg_InpLContinuationPullBars;
bool cfg_InpLRespectFlow;
double cfg_InpLRangeEdgeFraction;
double cfg_InpLSwingToleranceATR;
double cfg_InpLFlowMoveATR;
double cfg_InpLFlowEfficiency;
double cfg_InpLReversalCloseATR;
int cfg_InpLFlowWaitBars;
bool cfg_InpProExhaustionL;
double cfg_InpProExhaustMoveATR;
double cfg_InpLMinPullbackATR;
int cfg_InpLMaxWaveBars;
int cfg_InpLMaxPullbackBars;
int cfg_InpNewSweepBars;
int cfg_InpNewReactionBars;
int cfg_InpNewLimitLife;
double cfg_InpNewMinPriorMoveATR;
double cfg_InpNewReactionATR;
double cfg_InpNewZoneMaxATR;
double cfg_InpNewStopBufferATR;
double cfg_InpNewCancelRunATR;
bool cfg_InpShowEntryContext;
int cfg_InpContextKeep;
int cfg_InpContextTrendBars;
int cfg_InpContextSwingStrength;
int cfg_InpContextLegBars;
double cfg_InpContextWeakeningRatio;
bool cfg_InpPivotMarketReader;
int cfg_InpReaderPivotLookback;
bool cfg_InpReaderLiveTooltip;
bool cfg_InpContextDebugDetails;
int cfg_InpContextFollowBars;
int cfg_InpContextFontSize;
double cfg_InpContextFarZoneATR;
int cfg_InpZoneLookback;
double cfg_InpZoneDepartureATR;
double cfg_InpZoneNearATR;
double cfg_InpZoneInvalidATR;
int cfg_InpQualityLookback;
double cfg_InpQualityPullbackATR;
double cfg_InpQualityMaxRiskATR;
double cfg_InpQualityMaxExtensionATR;
double cfg_InpQualityMinRoomRisk;
int cfg_InpLDiagnosticsBars;
bool cfg_InpLDiagnostics;
bool cfg_InpDebugNewBars;
bool cfg_InpUseWickRetest;
bool cfg_InpUseC7CB;
bool cfg_InpUseStructure12;
bool cfg_InpEnablePush;
bool InitializeForecastConfig()
{
   cfg_InpForecastM30=InpForecastM30;
   cfg_InpForecastH1=InpForecastH1;
   cfg_InpStartupBars=InpStartupBars;
   cfg_InpLForecast=InpLForecast;
   cfg_InpForecastLookback=InpForecastLookback;
   cfg_InpForecastLife=InpForecastLife;
   cfg_InpForecastMinScore=InpForecastMinScore;
   cfg_InpSmartScoreFilter=InpSmartScoreFilter;
   cfg_InpSmartMinScore=InpSmartMinScore;
   cfg_InpNewLimitSetup=InpNewLimitSetup;
   cfg_InpNewAlerts=InpNewAlerts;
   cfg_InpEnabled=InpEnabled;
   cfg_InpShowHistory=InpShowHistory;
   cfg_InpUseRealVolume=InpUseRealVolume;
   cfg_InpArrowOffsetPixels=InpArrowOffsetPixels;
   cfg_InpUpColor=InpUpColor;
   cfg_InpDownColor=InpDownColor;
   cfg_InpProEventMarks=InpProEventMarks;
   cfg_InpWyHistory=InpWyHistory;
   cfg_InpWyKeepEvents=InpWyKeepEvents;
   cfg_InpWyFontSize=InpWyFontSize;
   cfg_InpWyBCFontSize=InpWyBCFontSize;
   cfg_InpWyStandaloneClimax=InpWyStandaloneClimax;
   cfg_InpShowLiveLevels=InpShowLiveLevels;
   cfg_InpLiveChartLevels=InpLiveChartLevels;
   cfg_InpLiveMTFLevels=InpLiveMTFLevels;
   cfg_InpLiveClosedBarKeys=InpLiveClosedBarKeys;
   cfg_InpLiveFontSize=InpLiveFontSize;
   cfg_InpLiveLabelOffsetBars=InpLiveLabelOffsetBars;
   cfg_InpLiveMaxLabels=InpLiveMaxLabels;
   cfg_InpLivePerSide=InpLivePerSide;
   cfg_InpLiveDemandColor=InpLiveDemandColor;
   cfg_InpLiveSupplyColor=InpLiveSupplyColor;
   cfg_InpLiveSupportColor=InpLiveSupportColor;
   cfg_InpLiveResistanceColor=InpLiveResistanceColor;
   cfg_InpMTF_M15=InpMTF_M15;
   cfg_InpMTF_H1=InpMTF_H1;
   cfg_InpMTF_H4=InpMTF_H4;
   cfg_InpMTF_D1=InpMTF_D1;
   cfg_InpMTFZones=InpMTFZones;
   cfg_InpMTFKeyLevels=InpMTFKeyLevels;
   cfg_InpMTFLookback=InpMTFLookback;
   cfg_InpProEnabled=InpProEnabled;
   cfg_InpProWyckoff=InpProWyckoff;
   cfg_InpProElliott=InpProElliott;
   cfg_InpProFilterWy=InpProFilterWy;
   cfg_InpProFilterEW=InpProFilterEW;
   cfg_InpProClimaxRV=InpProClimaxRV;
   cfg_InpProApproachATR=InpProApproachATR;
   cfg_InpProARatr=InpProARatr;
   cfg_InpProWyMaxBars=InpProWyMaxBars;
   cfg_InpProTestBars=InpProTestBars;
   cfg_InpProEWStrength=InpProEWStrength;
   cfg_InpProEWStrengthMajor=InpProEWStrengthMajor;
   cfg_InpProEWMinATR=InpProEWMinATR;
   cfg_InpProEWMinATRMajor=InpProEWMinATRMajor;
   cfg_InpImpulseControl=InpImpulseControl;
   cfg_InpImpulseMoveATR=InpImpulseMoveATR;
   cfg_InpImpulseEfficiency=InpImpulseEfficiency;
   cfg_InpImpulseFailureATR=InpImpulseFailureATR;
   cfg_InpImpulseLocationReversal=InpImpulseLocationReversal;
   cfg_InpWyDirectionalControl=InpWyDirectionalControl;
   cfg_InpWyFailureATR=InpWyFailureATR;
   cfg_InpWyLPSLocation=InpWyLPSLocation;
   cfg_InpLArbitrate=InpLArbitrate;
   cfg_InpLCycleLock=InpLCycleLock;
   cfg_InpLCycleDepartureATR=InpLCycleDepartureATR;
   cfg_InpLLocationMajorOnly=InpLLocationMajorOnly;
   cfg_InpLLocationEntry=InpLLocationEntry;
   cfg_InpLLocationChart=InpLLocationChart;
   cfg_InpLLocationMTF=InpLLocationMTF;
   cfg_InpLLocationNearATR=InpLLocationNearATR;
   cfg_InpLLocationDepartureATR=InpLLocationDepartureATR;
   cfg_InpLLocationWaitBars=InpLLocationWaitBars;
   cfg_InpLLocationLowVolTest=InpLLocationLowVolTest;
   cfg_InpLVolumeLock=InpLVolumeLock;
   cfg_InpLMinRelativeVolume=InpLMinRelativeVolume;
   cfg_InpLSellLocationCounter=InpLSellLocationCounter;
   cfg_InpLSellTop=InpLSellTop;
   cfg_InpSellTopWaitBars=InpSellTopWaitBars;
   cfg_InpSellTopPriorMoveATR=InpSellTopPriorMoveATR;
   cfg_InpLStructureTurn=InpLStructureTurn;
   cfg_InpTurnMinMoveATR=InpTurnMinMoveATR;
   cfg_InpTurnWaitBars=InpTurnWaitBars;
   cfg_InpLContinuation=InpLContinuation;
   cfg_InpLRangeTest=InpLRangeTest;
   cfg_InpLContinuationRequireBreak=InpLContinuationRequireBreak;
   cfg_InpLContinuationPushATR=InpLContinuationPushATR;
   cfg_InpLContinuationMaxRetrace=InpLContinuationMaxRetrace;
   cfg_InpLContinuationPullBars=InpLContinuationPullBars;
   cfg_InpLRespectFlow=InpLRespectFlow;
   cfg_InpLRangeEdgeFraction=InpLRangeEdgeFraction;
   cfg_InpLSwingToleranceATR=InpLSwingToleranceATR;
   cfg_InpLFlowMoveATR=InpLFlowMoveATR;
   cfg_InpLFlowEfficiency=InpLFlowEfficiency;
   cfg_InpLReversalCloseATR=InpLReversalCloseATR;
   cfg_InpLFlowWaitBars=InpLFlowWaitBars;
   cfg_InpProExhaustionL=InpProExhaustionL;
   cfg_InpProExhaustMoveATR=InpProExhaustMoveATR;
   cfg_InpLMinPullbackATR=InpLMinPullbackATR;
   cfg_InpLMaxWaveBars=InpLMaxWaveBars;
   cfg_InpLMaxPullbackBars=InpLMaxPullbackBars;
   cfg_InpNewSweepBars=InpNewSweepBars;
   cfg_InpNewReactionBars=InpNewReactionBars;
   cfg_InpNewLimitLife=InpNewLimitLife;
   cfg_InpNewMinPriorMoveATR=InpNewMinPriorMoveATR;
   cfg_InpNewReactionATR=InpNewReactionATR;
   cfg_InpNewZoneMaxATR=InpNewZoneMaxATR;
   cfg_InpNewStopBufferATR=InpNewStopBufferATR;
   cfg_InpNewCancelRunATR=InpNewCancelRunATR;
   cfg_InpShowEntryContext=InpShowEntryContext;
   cfg_InpContextKeep=InpContextKeep;
   cfg_InpContextTrendBars=InpContextTrendBars;
   cfg_InpContextSwingStrength=InpContextSwingStrength;
   cfg_InpContextLegBars=InpContextLegBars;
   cfg_InpContextWeakeningRatio=InpContextWeakeningRatio;
   cfg_InpPivotMarketReader=InpPivotMarketReader;
   cfg_InpReaderPivotLookback=InpReaderPivotLookback;
   cfg_InpReaderLiveTooltip=InpReaderLiveTooltip;
   cfg_InpContextDebugDetails=InpContextDebugDetails;
   cfg_InpContextFollowBars=InpContextFollowBars;
   cfg_InpContextFontSize=InpContextFontSize;
   cfg_InpContextFarZoneATR=InpContextFarZoneATR;
   cfg_InpZoneLookback=InpZoneLookback;
   cfg_InpZoneDepartureATR=InpZoneDepartureATR;
   cfg_InpZoneNearATR=InpZoneNearATR;
   cfg_InpZoneInvalidATR=InpZoneInvalidATR;
   cfg_InpQualityLookback=InpQualityLookback;
   cfg_InpQualityPullbackATR=InpQualityPullbackATR;
   cfg_InpQualityMaxRiskATR=InpQualityMaxRiskATR;
   cfg_InpQualityMaxExtensionATR=InpQualityMaxExtensionATR;
   cfg_InpQualityMinRoomRisk=InpQualityMinRoomRisk;
   cfg_InpLDiagnosticsBars=InpLDiagnosticsBars;
   cfg_InpLDiagnostics=InpLDiagnostics;
   cfg_InpDebugNewBars=InpDebugNewBars;
   cfg_InpUseWickRetest=InpUseWickRetest;
   cfg_InpUseC7CB=InpUseC7CB;
   cfg_InpUseStructure12=InpUseStructure12;
   cfg_InpEnablePush=InpEnablePush;
   if(!InpForecastWorker)return true;
   string fields[];
   if(StringSplit(InpForecastConfig,124,fields)!=139)return false;
   cfg_InpForecastM30=(bool)(StringToInteger(fields[0])!=0);
   cfg_InpForecastH1=(bool)(StringToInteger(fields[1])!=0);
   cfg_InpStartupBars=(int)StringToInteger(fields[2]);
   cfg_InpLForecast=(bool)(StringToInteger(fields[3])!=0);
   cfg_InpForecastLookback=(int)StringToInteger(fields[4]);
   cfg_InpForecastLife=(int)StringToInteger(fields[5]);
   cfg_InpForecastMinScore=(int)StringToInteger(fields[6]);
   cfg_InpSmartScoreFilter=(bool)(StringToInteger(fields[7])!=0);
   cfg_InpSmartMinScore=(int)StringToInteger(fields[8]);
   cfg_InpNewLimitSetup=(bool)(StringToInteger(fields[9])!=0);
   cfg_InpNewAlerts=(bool)(StringToInteger(fields[10])!=0);
   cfg_InpEnabled=(bool)(StringToInteger(fields[11])!=0);
   cfg_InpShowHistory=(bool)(StringToInteger(fields[12])!=0);
   cfg_InpUseRealVolume=(bool)(StringToInteger(fields[13])!=0);
   cfg_InpArrowOffsetPixels=(int)StringToInteger(fields[14]);
   cfg_InpUpColor=(color)StringToInteger(fields[15]);
   cfg_InpDownColor=(color)StringToInteger(fields[16]);
   cfg_InpProEventMarks=(bool)(StringToInteger(fields[17])!=0);
   cfg_InpWyHistory=(bool)(StringToInteger(fields[18])!=0);
   cfg_InpWyKeepEvents=(int)StringToInteger(fields[19]);
   cfg_InpWyFontSize=(int)StringToInteger(fields[20]);
   cfg_InpWyBCFontSize=(int)StringToInteger(fields[21]);
   cfg_InpWyStandaloneClimax=(bool)(StringToInteger(fields[22])!=0);
   cfg_InpShowLiveLevels=(bool)(StringToInteger(fields[23])!=0);
   cfg_InpLiveChartLevels=(bool)(StringToInteger(fields[24])!=0);
   cfg_InpLiveMTFLevels=(bool)(StringToInteger(fields[25])!=0);
   cfg_InpLiveClosedBarKeys=(bool)(StringToInteger(fields[26])!=0);
   cfg_InpLiveFontSize=(int)StringToInteger(fields[27]);
   cfg_InpLiveLabelOffsetBars=(int)StringToInteger(fields[28]);
   cfg_InpLiveMaxLabels=(int)StringToInteger(fields[29]);
   cfg_InpLivePerSide=(int)StringToInteger(fields[30]);
   cfg_InpLiveDemandColor=(color)StringToInteger(fields[31]);
   cfg_InpLiveSupplyColor=(color)StringToInteger(fields[32]);
   cfg_InpLiveSupportColor=(color)StringToInteger(fields[33]);
   cfg_InpLiveResistanceColor=(color)StringToInteger(fields[34]);
   cfg_InpMTF_M15=(bool)(StringToInteger(fields[35])!=0);
   cfg_InpMTF_H1=(bool)(StringToInteger(fields[36])!=0);
   cfg_InpMTF_H4=(bool)(StringToInteger(fields[37])!=0);
   cfg_InpMTF_D1=(bool)(StringToInteger(fields[38])!=0);
   cfg_InpMTFZones=(bool)(StringToInteger(fields[39])!=0);
   cfg_InpMTFKeyLevels=(bool)(StringToInteger(fields[40])!=0);
   cfg_InpMTFLookback=(int)StringToInteger(fields[41]);
   cfg_InpProEnabled=(bool)(StringToInteger(fields[42])!=0);
   cfg_InpProWyckoff=(bool)(StringToInteger(fields[43])!=0);
   cfg_InpProElliott=(bool)(StringToInteger(fields[44])!=0);
   cfg_InpProFilterWy=(bool)(StringToInteger(fields[45])!=0);
   cfg_InpProFilterEW=(bool)(StringToInteger(fields[46])!=0);
   cfg_InpProClimaxRV=StringToDouble(fields[47]);
   cfg_InpProApproachATR=StringToDouble(fields[48]);
   cfg_InpProARatr=StringToDouble(fields[49]);
   cfg_InpProWyMaxBars=(int)StringToInteger(fields[50]);
   cfg_InpProTestBars=(int)StringToInteger(fields[51]);
   cfg_InpProEWStrength=(int)StringToInteger(fields[52]);
   cfg_InpProEWStrengthMajor=(int)StringToInteger(fields[53]);
   cfg_InpProEWMinATR=StringToDouble(fields[54]);
   cfg_InpProEWMinATRMajor=StringToDouble(fields[55]);
   cfg_InpImpulseControl=(bool)(StringToInteger(fields[56])!=0);
   cfg_InpImpulseMoveATR=StringToDouble(fields[57]);
   cfg_InpImpulseEfficiency=StringToDouble(fields[58]);
   cfg_InpImpulseFailureATR=StringToDouble(fields[59]);
   cfg_InpImpulseLocationReversal=(bool)(StringToInteger(fields[60])!=0);
   cfg_InpWyDirectionalControl=(bool)(StringToInteger(fields[61])!=0);
   cfg_InpWyFailureATR=StringToDouble(fields[62]);
   cfg_InpWyLPSLocation=(bool)(StringToInteger(fields[63])!=0);
   cfg_InpLArbitrate=(bool)(StringToInteger(fields[64])!=0);
   cfg_InpLCycleLock=(bool)(StringToInteger(fields[65])!=0);
   cfg_InpLCycleDepartureATR=StringToDouble(fields[66]);
   cfg_InpLLocationMajorOnly=(bool)(StringToInteger(fields[67])!=0);
   cfg_InpLLocationEntry=(bool)(StringToInteger(fields[68])!=0);
   cfg_InpLLocationChart=(bool)(StringToInteger(fields[69])!=0);
   cfg_InpLLocationMTF=(bool)(StringToInteger(fields[70])!=0);
   cfg_InpLLocationNearATR=StringToDouble(fields[71]);
   cfg_InpLLocationDepartureATR=StringToDouble(fields[72]);
   cfg_InpLLocationWaitBars=(int)StringToInteger(fields[73]);
   cfg_InpLLocationLowVolTest=(bool)(StringToInteger(fields[74])!=0);
   cfg_InpLVolumeLock=(bool)(StringToInteger(fields[75])!=0);
   cfg_InpLMinRelativeVolume=StringToDouble(fields[76]);
   cfg_InpLSellLocationCounter=(bool)(StringToInteger(fields[77])!=0);
   cfg_InpLSellTop=(bool)(StringToInteger(fields[78])!=0);
   cfg_InpSellTopWaitBars=(int)StringToInteger(fields[79]);
   cfg_InpSellTopPriorMoveATR=StringToDouble(fields[80]);
   cfg_InpLStructureTurn=(bool)(StringToInteger(fields[81])!=0);
   cfg_InpTurnMinMoveATR=StringToDouble(fields[82]);
   cfg_InpTurnWaitBars=(int)StringToInteger(fields[83]);
   cfg_InpLContinuation=(bool)(StringToInteger(fields[84])!=0);
   cfg_InpLRangeTest=(bool)(StringToInteger(fields[85])!=0);
   cfg_InpLContinuationRequireBreak=(bool)(StringToInteger(fields[86])!=0);
   cfg_InpLContinuationPushATR=StringToDouble(fields[87]);
   cfg_InpLContinuationMaxRetrace=StringToDouble(fields[88]);
   cfg_InpLContinuationPullBars=(int)StringToInteger(fields[89]);
   cfg_InpLRespectFlow=(bool)(StringToInteger(fields[90])!=0);
   cfg_InpLRangeEdgeFraction=StringToDouble(fields[91]);
   cfg_InpLSwingToleranceATR=StringToDouble(fields[92]);
   cfg_InpLFlowMoveATR=StringToDouble(fields[93]);
   cfg_InpLFlowEfficiency=StringToDouble(fields[94]);
   cfg_InpLReversalCloseATR=StringToDouble(fields[95]);
   cfg_InpLFlowWaitBars=(int)StringToInteger(fields[96]);
   cfg_InpProExhaustionL=(bool)(StringToInteger(fields[97])!=0);
   cfg_InpProExhaustMoveATR=StringToDouble(fields[98]);
   cfg_InpLMinPullbackATR=StringToDouble(fields[99]);
   cfg_InpLMaxWaveBars=(int)StringToInteger(fields[100]);
   cfg_InpLMaxPullbackBars=(int)StringToInteger(fields[101]);
   cfg_InpNewSweepBars=(int)StringToInteger(fields[102]);
   cfg_InpNewReactionBars=(int)StringToInteger(fields[103]);
   cfg_InpNewLimitLife=(int)StringToInteger(fields[104]);
   cfg_InpNewMinPriorMoveATR=StringToDouble(fields[105]);
   cfg_InpNewReactionATR=StringToDouble(fields[106]);
   cfg_InpNewZoneMaxATR=StringToDouble(fields[107]);
   cfg_InpNewStopBufferATR=StringToDouble(fields[108]);
   cfg_InpNewCancelRunATR=StringToDouble(fields[109]);
   cfg_InpShowEntryContext=(bool)(StringToInteger(fields[110])!=0);
   cfg_InpContextKeep=(int)StringToInteger(fields[111]);
   cfg_InpContextTrendBars=(int)StringToInteger(fields[112]);
   cfg_InpContextSwingStrength=(int)StringToInteger(fields[113]);
   cfg_InpContextLegBars=(int)StringToInteger(fields[114]);
   cfg_InpContextWeakeningRatio=StringToDouble(fields[115]);
   cfg_InpPivotMarketReader=(bool)(StringToInteger(fields[116])!=0);
   cfg_InpReaderPivotLookback=(int)StringToInteger(fields[117]);
   cfg_InpReaderLiveTooltip=(bool)(StringToInteger(fields[118])!=0);
   cfg_InpContextDebugDetails=(bool)(StringToInteger(fields[119])!=0);
   cfg_InpContextFollowBars=(int)StringToInteger(fields[120]);
   cfg_InpContextFontSize=(int)StringToInteger(fields[121]);
   cfg_InpContextFarZoneATR=StringToDouble(fields[122]);
   cfg_InpZoneLookback=(int)StringToInteger(fields[123]);
   cfg_InpZoneDepartureATR=StringToDouble(fields[124]);
   cfg_InpZoneNearATR=StringToDouble(fields[125]);
   cfg_InpZoneInvalidATR=StringToDouble(fields[126]);
   cfg_InpQualityLookback=(int)StringToInteger(fields[127]);
   cfg_InpQualityPullbackATR=StringToDouble(fields[128]);
   cfg_InpQualityMaxRiskATR=StringToDouble(fields[129]);
   cfg_InpQualityMaxExtensionATR=StringToDouble(fields[130]);
   cfg_InpQualityMinRoomRisk=StringToDouble(fields[131]);
   cfg_InpLDiagnosticsBars=(int)StringToInteger(fields[132]);
   cfg_InpLDiagnostics=(bool)(StringToInteger(fields[133])!=0);
   cfg_InpDebugNewBars=(bool)(StringToInteger(fields[134])!=0);
   cfg_InpUseWickRetest=(bool)(StringToInteger(fields[135])!=0);
   cfg_InpUseC7CB=(bool)(StringToInteger(fields[136])!=0);
   cfg_InpUseStructure12=(bool)(StringToInteger(fields[137])!=0);
   cfg_InpEnablePush=(bool)(StringToInteger(fields[138])!=0);
   return true;
}
#define InpForecastM30 cfg_InpForecastM30
#define InpForecastH1 cfg_InpForecastH1
#define InpStartupBars cfg_InpStartupBars
#define InpLForecast cfg_InpLForecast
#define InpForecastLookback cfg_InpForecastLookback
#define InpForecastLife cfg_InpForecastLife
#define InpForecastMinScore cfg_InpForecastMinScore
#define InpSmartScoreFilter cfg_InpSmartScoreFilter
#define InpSmartMinScore cfg_InpSmartMinScore
#define InpNewLimitSetup cfg_InpNewLimitSetup
#define InpNewAlerts cfg_InpNewAlerts
#define InpEnabled cfg_InpEnabled
#define InpShowHistory cfg_InpShowHistory
#define InpUseRealVolume cfg_InpUseRealVolume
#define InpArrowOffsetPixels cfg_InpArrowOffsetPixels
#define InpUpColor cfg_InpUpColor
#define InpDownColor cfg_InpDownColor
#define InpProEventMarks cfg_InpProEventMarks
#define InpWyHistory cfg_InpWyHistory
#define InpWyKeepEvents cfg_InpWyKeepEvents
#define InpWyFontSize cfg_InpWyFontSize
#define InpWyBCFontSize cfg_InpWyBCFontSize
#define InpWyStandaloneClimax cfg_InpWyStandaloneClimax
#define InpShowLiveLevels cfg_InpShowLiveLevels
#define InpLiveChartLevels cfg_InpLiveChartLevels
#define InpLiveMTFLevels cfg_InpLiveMTFLevels
#define InpLiveClosedBarKeys cfg_InpLiveClosedBarKeys
#define InpLiveFontSize cfg_InpLiveFontSize
#define InpLiveLabelOffsetBars cfg_InpLiveLabelOffsetBars
#define InpLiveMaxLabels cfg_InpLiveMaxLabels
#define InpLivePerSide cfg_InpLivePerSide
#define InpLiveDemandColor cfg_InpLiveDemandColor
#define InpLiveSupplyColor cfg_InpLiveSupplyColor
#define InpLiveSupportColor cfg_InpLiveSupportColor
#define InpLiveResistanceColor cfg_InpLiveResistanceColor
#define InpMTF_M15 cfg_InpMTF_M15
#define InpMTF_H1 cfg_InpMTF_H1
#define InpMTF_H4 cfg_InpMTF_H4
#define InpMTF_D1 cfg_InpMTF_D1
#define InpMTFZones cfg_InpMTFZones
#define InpMTFKeyLevels cfg_InpMTFKeyLevels
#define InpMTFLookback cfg_InpMTFLookback
#define InpProEnabled cfg_InpProEnabled
#define InpProWyckoff cfg_InpProWyckoff
#define InpProElliott cfg_InpProElliott
#define InpProFilterWy cfg_InpProFilterWy
#define InpProFilterEW cfg_InpProFilterEW
#define InpProClimaxRV cfg_InpProClimaxRV
#define InpProApproachATR cfg_InpProApproachATR
#define InpProARatr cfg_InpProARatr
#define InpProWyMaxBars cfg_InpProWyMaxBars
#define InpProTestBars cfg_InpProTestBars
#define InpProEWStrength cfg_InpProEWStrength
#define InpProEWStrengthMajor cfg_InpProEWStrengthMajor
#define InpProEWMinATR cfg_InpProEWMinATR
#define InpProEWMinATRMajor cfg_InpProEWMinATRMajor
#define InpImpulseControl cfg_InpImpulseControl
#define InpImpulseMoveATR cfg_InpImpulseMoveATR
#define InpImpulseEfficiency cfg_InpImpulseEfficiency
#define InpImpulseFailureATR cfg_InpImpulseFailureATR
#define InpImpulseLocationReversal cfg_InpImpulseLocationReversal
#define InpWyDirectionalControl cfg_InpWyDirectionalControl
#define InpWyFailureATR cfg_InpWyFailureATR
#define InpWyLPSLocation cfg_InpWyLPSLocation
#define InpLArbitrate cfg_InpLArbitrate
#define InpLCycleLock cfg_InpLCycleLock
#define InpLCycleDepartureATR cfg_InpLCycleDepartureATR
#define InpLLocationMajorOnly cfg_InpLLocationMajorOnly
#define InpLLocationEntry cfg_InpLLocationEntry
#define InpLLocationChart cfg_InpLLocationChart
#define InpLLocationMTF cfg_InpLLocationMTF
#define InpLLocationNearATR cfg_InpLLocationNearATR
#define InpLLocationDepartureATR cfg_InpLLocationDepartureATR
#define InpLLocationWaitBars cfg_InpLLocationWaitBars
#define InpLLocationLowVolTest cfg_InpLLocationLowVolTest
#define InpLVolumeLock cfg_InpLVolumeLock
#define InpLMinRelativeVolume cfg_InpLMinRelativeVolume
#define InpLSellLocationCounter cfg_InpLSellLocationCounter
#define InpLSellTop cfg_InpLSellTop
#define InpSellTopWaitBars cfg_InpSellTopWaitBars
#define InpSellTopPriorMoveATR cfg_InpSellTopPriorMoveATR
#define InpLStructureTurn cfg_InpLStructureTurn
#define InpTurnMinMoveATR cfg_InpTurnMinMoveATR
#define InpTurnWaitBars cfg_InpTurnWaitBars
#define InpLContinuation cfg_InpLContinuation
#define InpLRangeTest cfg_InpLRangeTest
#define InpLContinuationRequireBreak cfg_InpLContinuationRequireBreak
#define InpLContinuationPushATR cfg_InpLContinuationPushATR
#define InpLContinuationMaxRetrace cfg_InpLContinuationMaxRetrace
#define InpLContinuationPullBars cfg_InpLContinuationPullBars
#define InpLRespectFlow cfg_InpLRespectFlow
#define InpLRangeEdgeFraction cfg_InpLRangeEdgeFraction
#define InpLSwingToleranceATR cfg_InpLSwingToleranceATR
#define InpLFlowMoveATR cfg_InpLFlowMoveATR
#define InpLFlowEfficiency cfg_InpLFlowEfficiency
#define InpLReversalCloseATR cfg_InpLReversalCloseATR
#define InpLFlowWaitBars cfg_InpLFlowWaitBars
#define InpProExhaustionL cfg_InpProExhaustionL
#define InpProExhaustMoveATR cfg_InpProExhaustMoveATR
#define InpLMinPullbackATR cfg_InpLMinPullbackATR
#define InpLMaxWaveBars cfg_InpLMaxWaveBars
#define InpLMaxPullbackBars cfg_InpLMaxPullbackBars
#define InpNewSweepBars cfg_InpNewSweepBars
#define InpNewReactionBars cfg_InpNewReactionBars
#define InpNewLimitLife cfg_InpNewLimitLife
#define InpNewMinPriorMoveATR cfg_InpNewMinPriorMoveATR
#define InpNewReactionATR cfg_InpNewReactionATR
#define InpNewZoneMaxATR cfg_InpNewZoneMaxATR
#define InpNewStopBufferATR cfg_InpNewStopBufferATR
#define InpNewCancelRunATR cfg_InpNewCancelRunATR
#define InpShowEntryContext cfg_InpShowEntryContext
#define InpContextKeep cfg_InpContextKeep
#define InpContextTrendBars cfg_InpContextTrendBars
#define InpContextSwingStrength cfg_InpContextSwingStrength
#define InpContextLegBars cfg_InpContextLegBars
#define InpContextWeakeningRatio cfg_InpContextWeakeningRatio
#define InpPivotMarketReader cfg_InpPivotMarketReader
#define InpReaderPivotLookback cfg_InpReaderPivotLookback
#define InpReaderLiveTooltip cfg_InpReaderLiveTooltip
#define InpContextDebugDetails cfg_InpContextDebugDetails
#define InpContextFollowBars cfg_InpContextFollowBars
#define InpContextFontSize cfg_InpContextFontSize
#define InpContextFarZoneATR cfg_InpContextFarZoneATR
#define InpZoneLookback cfg_InpZoneLookback
#define InpZoneDepartureATR cfg_InpZoneDepartureATR
#define InpZoneNearATR cfg_InpZoneNearATR
#define InpZoneInvalidATR cfg_InpZoneInvalidATR
#define InpQualityLookback cfg_InpQualityLookback
#define InpQualityPullbackATR cfg_InpQualityPullbackATR
#define InpQualityMaxRiskATR cfg_InpQualityMaxRiskATR
#define InpQualityMaxExtensionATR cfg_InpQualityMaxExtensionATR
#define InpQualityMinRoomRisk cfg_InpQualityMinRoomRisk
#define InpLDiagnosticsBars cfg_InpLDiagnosticsBars
#define InpLDiagnostics cfg_InpLDiagnostics
#define InpDebugNewBars cfg_InpDebugNewBars
#define InpUseWickRetest cfg_InpUseWickRetest
#define InpUseC7CB cfg_InpUseC7CB
#define InpUseStructure12 cfg_InpUseStructure12
#define InpEnablePush cfg_InpEnablePush

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
datetime ReaderLastClosed=0;
int ContextBars[],ContextTypes[],ContextCount=0;
string ContextNames[10],ContextTexts[10],ContextTips[10];
datetime ContextTimes[10];
double ContextPrices[10];
int ContextDirections[10];
bool ContextLive[10];
string ContextBaseTips[10];
datetime ContextStatusStamp[10];
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
struct MTFContextCache
{
   bool ready;
   datetime lastClosed;
   int count;
   double lo[250],hi[250],scale[250];
   datetime origin[250],phTime,plTime,lastTime;
   int side[250]; // 1=cầu, -1=cung
   bool hasPH,hasPL;
   double ph,pl,lastHigh,lastLow;
};
MTFContextCache MTFCache[48];
ulong MTFQueryEpoch=0,MTFSuccessEpoch[48];
datetime MTFSuccessCutoff[48];
void ResetMTFContextCache()
{
   for(int k=0;k<48;k++) { MTFCache[k].ready=false;MTFCache[k].lastClosed=0;MTFCache[k].count=0;MTFSuccessEpoch[k]=0;MTFSuccessCutoff[k]=0; }
}

void ResetEntryContextCache()
{
   ReaderLastClosed=0;
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
   return type<=3;
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
bool LiveSDOn=false,LiveKLOn=false;
int LiveSnapshotCount=0;
double LiveSnapshotATR=0,LiveSnapshotClose=0,LiveSnapshotPrevious=0;
datetime LiveSnapshotCutoff=0,LiveOriginTime[256];
void RefreshLevelButtons()
{
   if(InpForecastWorker)return;
   if(Prefix=="" || !InpEnabled) return;
   for(int k=0;k<2;k++)
   {
      string name=Prefix+(k==0?"BTN_SD":"BTN_KL");bool on=k==0?LiveSDOn:LiveKLOn;
      if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_BUTTON,0,0,0)) continue;
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,98-k*48);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,42);ObjectSetInteger(0,name,OBJPROP_YSIZE,20);
      ObjectSetString(0,name,OBJPROP_TEXT,k==0?"SD":"KL");ObjectSetString(0,name,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(0,name,OBJPROP_COLOR,on?clrWhite:clrSilver);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,on?clrSeaGreen:clrDimGray);
      ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,on?clrSeaGreen:clrGray);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,(k==0?"S/D":"Keylevel")+(on?" ON — bấm để ẩn":" OFF — bấm để hiện"));
   }
}
bool IndicatorStopping=false,NewRenderDeferred=false;
bool DeleteOwnedChartObjects(const string owned)
{
   if(owned=="") return true; // Empty-prefix bulk deletion would wipe unrelated objects.
   ResetLastError();
   ObjectsDeleteAll(0,owned,-1,-1); // All subwindows and object types, this instance only.
   int total=ObjectsTotal(0,-1,-1);
   for(int n=total-1;n>=0;n--)
   {
      string name=ObjectName(0,n,-1,-1);
      if(StringFind(name,owned)==0) ObjectDelete(0,name);
   }
   total=ObjectsTotal(0,-1,-1); // Synchronous verification after queued ObjectDelete calls.
   int remaining=0;
   for(int n=0;n<total;n++)
      if(StringFind(ObjectName(0,n,-1,-1),owned)==0) remaining++;
   if(remaining>0) Print("C7CB cleanup incomplete | objects=",remaining," | prefix=",owned," | error=",GetLastError());
   return remaining==0;
}


double FX0[],FX1[],FX2[],FX3[],FX4[],FX5[],FX6[],FX7[],FX8[],FX9[];
int ForecastHandles[2]={INVALID_HANDLE,INVALID_HANDLE};
datetime ForecastReadStamp[2]={0,0};
int CreateForecastHandle(const ENUM_TIMEFRAMES tf)
{
   string path=MQLInfoString(MQL_PROGRAM_PATH);
   int pos=StringFind(path,"\\Indicators\\");
   if(pos<0) return INVALID_HANDLE;
   path=StringSubstr(path,pos+12);
   int ext=StringFind(path,".ex5");if(ext>=0)path=StringSubstr(path,0,ext);
   string packed="";
   packed+=IntegerToString((long)InpForecastM30)+"|";
   packed+=IntegerToString((long)InpForecastH1)+"|";
   packed+=IntegerToString((long)InpStartupBars)+"|";
   packed+="1"+"|";
   packed+=IntegerToString((long)InpForecastLookback)+"|";
   packed+=IntegerToString((long)InpForecastLife)+"|";
   packed+=IntegerToString((long)InpForecastMinScore)+"|";
   packed+=IntegerToString((long)InpSmartScoreFilter)+"|";
   packed+=IntegerToString((long)InpSmartMinScore)+"|";
   packed+=IntegerToString((long)InpNewLimitSetup)+"|";
   packed+=IntegerToString((long)InpNewAlerts)+"|";
   packed+=IntegerToString((long)InpEnabled)+"|";
   packed+=IntegerToString((long)InpShowHistory)+"|";
   packed+=IntegerToString((long)InpUseRealVolume)+"|";
   packed+=IntegerToString((long)InpArrowOffsetPixels)+"|";
   packed+=IntegerToString((long)InpUpColor)+"|";
   packed+=IntegerToString((long)InpDownColor)+"|";
   packed+=IntegerToString((long)InpProEventMarks)+"|";
   packed+=IntegerToString((long)InpWyHistory)+"|";
   packed+=IntegerToString((long)InpWyKeepEvents)+"|";
   packed+=IntegerToString((long)InpWyFontSize)+"|";
   packed+=IntegerToString((long)InpWyBCFontSize)+"|";
   packed+=IntegerToString((long)InpWyStandaloneClimax)+"|";
   packed+=IntegerToString((long)InpShowLiveLevels)+"|";
   packed+=IntegerToString((long)InpLiveChartLevels)+"|";
   packed+=IntegerToString((long)InpLiveMTFLevels)+"|";
   packed+=IntegerToString((long)InpLiveClosedBarKeys)+"|";
   packed+=IntegerToString((long)InpLiveFontSize)+"|";
   packed+=IntegerToString((long)InpLiveLabelOffsetBars)+"|";
   packed+=IntegerToString((long)InpLiveMaxLabels)+"|";
   packed+=IntegerToString((long)InpLivePerSide)+"|";
   packed+=IntegerToString((long)InpLiveDemandColor)+"|";
   packed+=IntegerToString((long)InpLiveSupplyColor)+"|";
   packed+=IntegerToString((long)InpLiveSupportColor)+"|";
   packed+=IntegerToString((long)InpLiveResistanceColor)+"|";
   packed+=IntegerToString((long)InpMTF_M15)+"|";
   packed+=IntegerToString((long)InpMTF_H1)+"|";
   packed+=IntegerToString((long)InpMTF_H4)+"|";
   packed+=IntegerToString((long)InpMTF_D1)+"|";
   packed+=IntegerToString((long)InpMTFZones)+"|";
   packed+=IntegerToString((long)InpMTFKeyLevels)+"|";
   packed+=IntegerToString((long)InpMTFLookback)+"|";
   packed+=IntegerToString((long)InpProEnabled)+"|";
   packed+=IntegerToString((long)InpProWyckoff)+"|";
   packed+=IntegerToString((long)InpProElliott)+"|";
   packed+=IntegerToString((long)InpProFilterWy)+"|";
   packed+=IntegerToString((long)InpProFilterEW)+"|";
   packed+=DoubleToString(InpProClimaxRV,16)+"|";
   packed+=DoubleToString(InpProApproachATR,16)+"|";
   packed+=DoubleToString(InpProARatr,16)+"|";
   packed+=IntegerToString((long)InpProWyMaxBars)+"|";
   packed+=IntegerToString((long)InpProTestBars)+"|";
   packed+=IntegerToString((long)InpProEWStrength)+"|";
   packed+=IntegerToString((long)InpProEWStrengthMajor)+"|";
   packed+=DoubleToString(InpProEWMinATR,16)+"|";
   packed+=DoubleToString(InpProEWMinATRMajor,16)+"|";
   packed+=IntegerToString((long)InpImpulseControl)+"|";
   packed+=DoubleToString(InpImpulseMoveATR,16)+"|";
   packed+=DoubleToString(InpImpulseEfficiency,16)+"|";
   packed+=DoubleToString(InpImpulseFailureATR,16)+"|";
   packed+=IntegerToString((long)InpImpulseLocationReversal)+"|";
   packed+=IntegerToString((long)InpWyDirectionalControl)+"|";
   packed+=DoubleToString(InpWyFailureATR,16)+"|";
   packed+=IntegerToString((long)InpWyLPSLocation)+"|";
   packed+=IntegerToString((long)InpLArbitrate)+"|";
   packed+=IntegerToString((long)InpLCycleLock)+"|";
   packed+=DoubleToString(InpLCycleDepartureATR,16)+"|";
   packed+=IntegerToString((long)InpLLocationMajorOnly)+"|";
   packed+=IntegerToString((long)InpLLocationEntry)+"|";
   packed+=IntegerToString((long)InpLLocationChart)+"|";
   packed+=IntegerToString((long)InpLLocationMTF)+"|";
   packed+=DoubleToString(InpLLocationNearATR,16)+"|";
   packed+=DoubleToString(InpLLocationDepartureATR,16)+"|";
   packed+=IntegerToString((long)InpLLocationWaitBars)+"|";
   packed+=IntegerToString((long)InpLLocationLowVolTest)+"|";
   packed+=IntegerToString((long)InpLVolumeLock)+"|";
   packed+=DoubleToString(InpLMinRelativeVolume,16)+"|";
   packed+=IntegerToString((long)InpLSellLocationCounter)+"|";
   packed+=IntegerToString((long)InpLSellTop)+"|";
   packed+=IntegerToString((long)InpSellTopWaitBars)+"|";
   packed+=DoubleToString(InpSellTopPriorMoveATR,16)+"|";
   packed+=IntegerToString((long)InpLStructureTurn)+"|";
   packed+=DoubleToString(InpTurnMinMoveATR,16)+"|";
   packed+=IntegerToString((long)InpTurnWaitBars)+"|";
   packed+=IntegerToString((long)InpLContinuation)+"|";
   packed+=IntegerToString((long)InpLRangeTest)+"|";
   packed+=IntegerToString((long)InpLContinuationRequireBreak)+"|";
   packed+=DoubleToString(InpLContinuationPushATR,16)+"|";
   packed+=DoubleToString(InpLContinuationMaxRetrace,16)+"|";
   packed+=IntegerToString((long)InpLContinuationPullBars)+"|";
   packed+=IntegerToString((long)InpLRespectFlow)+"|";
   packed+=DoubleToString(InpLRangeEdgeFraction,16)+"|";
   packed+=DoubleToString(InpLSwingToleranceATR,16)+"|";
   packed+=DoubleToString(InpLFlowMoveATR,16)+"|";
   packed+=DoubleToString(InpLFlowEfficiency,16)+"|";
   packed+=DoubleToString(InpLReversalCloseATR,16)+"|";
   packed+=IntegerToString((long)InpLFlowWaitBars)+"|";
   packed+=IntegerToString((long)InpProExhaustionL)+"|";
   packed+=DoubleToString(InpProExhaustMoveATR,16)+"|";
   packed+=DoubleToString(InpLMinPullbackATR,16)+"|";
   packed+=IntegerToString((long)InpLMaxWaveBars)+"|";
   packed+=IntegerToString((long)InpLMaxPullbackBars)+"|";
   packed+=IntegerToString((long)InpNewSweepBars)+"|";
   packed+=IntegerToString((long)InpNewReactionBars)+"|";
   packed+=IntegerToString((long)InpNewLimitLife)+"|";
   packed+=DoubleToString(InpNewMinPriorMoveATR,16)+"|";
   packed+=DoubleToString(InpNewReactionATR,16)+"|";
   packed+=DoubleToString(InpNewZoneMaxATR,16)+"|";
   packed+=DoubleToString(InpNewStopBufferATR,16)+"|";
   packed+=DoubleToString(InpNewCancelRunATR,16)+"|";
   packed+=IntegerToString((long)InpShowEntryContext)+"|";
   packed+=IntegerToString((long)InpContextKeep)+"|";
   packed+=IntegerToString((long)InpContextTrendBars)+"|";
   packed+=IntegerToString((long)InpContextSwingStrength)+"|";
   packed+=IntegerToString((long)InpContextLegBars)+"|";
   packed+=DoubleToString(InpContextWeakeningRatio,16)+"|";
   packed+=IntegerToString((long)InpPivotMarketReader)+"|";
   packed+=IntegerToString((long)InpReaderPivotLookback)+"|";
   packed+=IntegerToString((long)InpReaderLiveTooltip)+"|";
   packed+=IntegerToString((long)InpContextDebugDetails)+"|";
   packed+=IntegerToString((long)InpContextFollowBars)+"|";
   packed+=IntegerToString((long)InpContextFontSize)+"|";
   packed+=DoubleToString(InpContextFarZoneATR,16)+"|";
   packed+=IntegerToString((long)InpZoneLookback)+"|";
   packed+=DoubleToString(InpZoneDepartureATR,16)+"|";
   packed+=DoubleToString(InpZoneNearATR,16)+"|";
   packed+=DoubleToString(InpZoneInvalidATR,16)+"|";
   packed+=IntegerToString((long)InpQualityLookback)+"|";
   packed+=DoubleToString(InpQualityPullbackATR,16)+"|";
   packed+=DoubleToString(InpQualityMaxRiskATR,16)+"|";
   packed+=DoubleToString(InpQualityMaxExtensionATR,16)+"|";
   packed+=DoubleToString(InpQualityMinRoomRisk,16)+"|";
   packed+=IntegerToString((long)InpLDiagnosticsBars)+"|";
   packed+=IntegerToString((long)InpLDiagnostics)+"|";
   packed+=IntegerToString((long)InpDebugNewBars)+"|";
   packed+=IntegerToString((long)InpUseWickRetest)+"|";
   packed+=IntegerToString((long)InpUseC7CB)+"|";
   packed+=IntegerToString((long)InpUseStructure12)+"|";
   packed+=IntegerToString((long)InpEnablePush);
   MqlParam args[3];args[0].type=TYPE_STRING;args[0].string_value=path;
   args[1].type=TYPE_STRING;args[1].string_value=packed;
   args[2].type=TYPE_BOOL;args[2].integer_value=true;
   return IndicatorCreate(_Symbol,tf,IND_CUSTOM,3,args);
}
void PublishForecast(const int count,const datetime &time[])
{
   int j=count-1;if(j<0)return;
   FX0[j]=FX1[j]=FX2[j]=FX3[j]=FX4[j]=EMPTY_VALUE;
   FX5[j]=FX6[j]=FX7[j]=FX8[j]=FX9[j]=EMPTY_VALUE;
   if(LF[0].active)
   {FX0[j]=LF[0].lo;FX1[j]=LF[0].hi;FX2[j]=LF[0].score;FX3[j]=(double)(time[LF[0].born]+PeriodSeconds(_Period));FX4[j]=LF[0].stop;}
   if(LF[1].active)
   {FX5[j]=LF[1].lo;FX6[j]=LF[1].hi;FX7[j]=LF[1].score;FX8[j]=(double)(time[LF[1].born]+PeriodSeconds(_Period));FX9[j]=LF[1].stop;}
}
void ClearSourceForecast(const int source)
{
   for(int slot=0;slot<2;slot++)
   { string name=Prefix+"MTFF_"+IntegerToString(source)+"_"+IntegerToString(slot);ObjectDelete(0,name);ObjectDelete(0,name+"_T"); }
}
void RefreshSourceForecasts()
{
   if(InpForecastWorker || !InpEnabled)return;
   for(int src=0;src<2;src++)
   {
      ENUM_TIMEFRAMES tf=src==0?PERIOD_M30:PERIOD_H1;
      bool enabled=src==0?InpForecastM30:InpForecastH1;
      if(!enabled || PeriodSeconds(_Period)>=PeriodSeconds(tf)) {ClearSourceForecast(src);continue;}
      if(ForecastHandles[src]==INVALID_HANDLE)continue;
      datetime closed=iTime(_Symbol,tf,1);
      if(closed<=0 || closed==ForecastReadStamp[src])continue;
      if(BarsCalculated(ForecastHandles[src])<30)continue;
      double values[10];bool ready=true;
      for(int k=0;k<10;k++)
      {double v[1];if(CopyBuffer(ForecastHandles[src],28+k,0,1,v)!=1){ready=false;break;}values[k]=v[0];}
      if(!ready)continue;
      // Worker publishes only after calculating the latest source close.
      double stamp[1];if(CopyBuffer(ForecastHandles[src],0,0,1,stamp)!=1 || stamp[0]!=(double)closed)continue;
      ForecastReadStamp[src]=closed;
      for(int slot=0;slot<2;slot++)
      {
         int k=slot*5;string name=Prefix+"MTFF_"+IntegerToString(src)+"_"+IntegerToString(slot),label=name+"_T";
         if(values[k]==EMPTY_VALUE || values[k+3]<=0)
         {ObjectDelete(0,name);ObjectDelete(0,label);continue;}
         datetime born=(datetime)values[k+3],finish=born+(datetime)(InpForecastLife*PeriodSeconds(tf));
         color ink=slot==0?InpUpColor:InpDownColor;
         if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_RECTANGLE,0,born,values[k],finish,values[k+1]);
         ObjectMove(0,name,0,born,values[k]);ObjectMove(0,name,1,finish,values[k+1]);
         ObjectSetInteger(0,name,OBJPROP_COLOR,ink);ObjectSetInteger(0,name,OBJPROP_FILL,false);
         ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         string caption=IntegerToString((int)values[k+2])+" "+(src==0?"M30":"H1");
         string tip=caption+" | "+(slot==0?"BUY":"SELL")+" | du bao, cho L xac nhan";
         ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
         if(ObjectFind(0,label)<0)ObjectCreate(0,label,OBJ_TEXT,0,finish,slot==0?values[k]:values[k+1]);
         ObjectMove(0,label,0,finish,slot==0?values[k]:values[k+1]);
         ObjectSetString(0,label,OBJPROP_TEXT,caption);ObjectSetString(0,label,OBJPROP_TOOLTIP,tip);
         ObjectSetInteger(0,label,OBJPROP_COLOR,ink);ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
         ObjectSetInteger(0,label,OBJPROP_ANCHOR,slot==0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
      }
   }
}

int OnInit()
{
   if(!InitializeForecastConfig())return INIT_PARAMETERS_INCORRECT;
   if(InpStartupBars<500 || InpStartupBars>700) return INIT_PARAMETERS_INCORRECT;
   if(InpForecastLookback<30 || InpForecastLookback>200 || InpForecastLife<2 || InpForecastLife>100 ||
      InpForecastMinScore<0 || InpForecastMinScore>100 || InpSmartMinScore<0 || InpSmartMinScore>100)
      return INIT_PARAMETERS_INCORRECT;
   SetIndexBuffer(28,FX0,INDICATOR_CALCULATIONS);
   SetIndexBuffer(29,FX1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(30,FX2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(31,FX3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(32,FX4,INDICATOR_CALCULATIONS);
   SetIndexBuffer(33,FX5,INDICATOR_CALCULATIONS);
   SetIndexBuffer(34,FX6,INDICATOR_CALCULATIONS);
   SetIndexBuffer(35,FX7,INDICATOR_CALCULATIONS);
   SetIndexBuffer(36,FX8,INDICATOR_CALCULATIONS);
   SetIndexBuffer(37,FX9,INDICATOR_CALCULATIONS);
   IndicatorStopping=false;
   if(!MathIsValidNumber(InpLLocationNearATR) || InpLLocationNearATR<=0 || InpLLocationNearATR>1 ||
      !MathIsValidNumber(InpLLocationDepartureATR) || InpLLocationDepartureATR<=0 ||
      InpLLocationWaitBars<2 || InpLLocationWaitBars>20) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpLMinRelativeVolume) || InpLMinRelativeVolume<=0 || InpLMinRelativeVolume>10)
      return INIT_PARAMETERS_INCORRECT;
   if(InpLDiagnosticsBars<1 || InpLDiagnosticsBars>100000) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpLContinuationPushATR) || InpLContinuationPushATR<=0 ||
      !MathIsValidNumber(InpLContinuationMaxRetrace) || InpLContinuationMaxRetrace<=0.15 || InpLContinuationMaxRetrace>=1 ||
      InpLContinuationPullBars<1 || InpLContinuationPullBars>5) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpLRangeEdgeFraction) || InpLRangeEdgeFraction<=0 || InpLRangeEdgeFraction>=0.5 ||
      !MathIsValidNumber(InpLSwingToleranceATR) || InpLSwingToleranceATR<=0 || InpLSwingToleranceATR>1) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpLFlowMoveATR) || InpLFlowMoveATR<=0 ||
      !MathIsValidNumber(InpLFlowEfficiency) || InpLFlowEfficiency<=0 || InpLFlowEfficiency>1 ||
      !MathIsValidNumber(InpLReversalCloseATR) || InpLReversalCloseATR<=0 ||
      InpLFlowWaitBars<1 || InpLFlowWaitBars>10) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpProExhaustMoveATR) || InpProExhaustMoveATR<=0) return INIT_PARAMETERS_INCORRECT;
   if(InpProEWStrength<1 || InpProEWStrength>20 || InpProEWStrengthMajor>50 ||
      !MathIsValidNumber(InpProEWMinATR) || !MathIsValidNumber(InpProEWMinATRMajor) ||
      !MathIsValidNumber(InpProClimaxRV) || !MathIsValidNumber(InpProApproachATR) || !MathIsValidNumber(InpProARatr) ||
      InpProEWStrengthMajor<=InpProEWStrength || InpProEWMinATR<=0 ||
      InpProEWMinATRMajor<InpProEWMinATR || InpProClimaxRV<=0 || InpProApproachATR<=0 ||
      InpProARatr<=0 || InpProWyMaxBars<20 || InpProWyMaxBars>2000 || InpProTestBars<1 || InpProTestBars>100) return INIT_PARAMETERS_INCORRECT;

   if(!MathIsValidNumber(InpLMinPullbackATR) || InpLMinPullbackATR<=0 || InpLMaxWaveBars<5 || InpLMaxWaveBars>500 ||
      InpLMaxPullbackBars<1 || InpLMaxPullbackBars>20 || InpNewSweepBars<5 || InpNewSweepBars>200 ||
      InpNewReactionBars<1 || InpNewReactionBars>10 || InpNewLimitLife<1 || InpNewLimitLife>100 ||
      !MathIsValidNumber(InpNewMinPriorMoveATR) || InpNewMinPriorMoveATR<=0 ||
      !MathIsValidNumber(InpNewReactionATR) || InpNewReactionATR<=0 ||
      !MathIsValidNumber(InpNewZoneMaxATR) || InpNewZoneMaxATR<=0 ||
      !MathIsValidNumber(InpNewStopBufferATR) || InpNewStopBufferATR<=0 ||
      !MathIsValidNumber(InpNewCancelRunATR) || InpNewCancelRunATR<=0) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpContextFarZoneATR) || InpContextFarZoneATR<=InpZoneNearATR)
      return INIT_PARAMETERS_INCORRECT;
   if(InpZoneLookback<20 || InpZoneLookback>250 || !MathIsValidNumber(InpZoneDepartureATR) ||
      InpZoneDepartureATR<=0 || !MathIsValidNumber(InpZoneNearATR) || InpZoneNearATR<=0 ||
      !MathIsValidNumber(InpZoneInvalidATR) || InpZoneInvalidATR<0)
      return INIT_PARAMETERS_INCORRECT;
   if(InpSellTopWaitBars<2 || InpSellTopWaitBars>12 || !MathIsValidNumber(InpSellTopPriorMoveATR) || InpSellTopPriorMoveATR<=0) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpTurnMinMoveATR) || InpTurnMinMoveATR<=0 || InpTurnWaitBars<3 || InpTurnWaitBars>30) return INIT_PARAMETERS_INCORRECT;
   if(InpWyBCFontSize<5 || InpWyBCFontSize>14) return INIT_PARAMETERS_INCORRECT;
   if(InpWyKeepEvents<1 || InpWyKeepEvents>100) return INIT_PARAMETERS_INCORRECT;
   if(InpLiveLabelOffsetBars<0 || InpLiveLabelOffsetBars>200) return INIT_PARAMETERS_INCORRECT;
   if(InpWyFontSize<5 || InpWyFontSize>14 || InpLiveFontSize<7 || InpLiveFontSize>14 || InpLiveMaxLabels<2 || InpLiveMaxLabels>40 || InpLivePerSide<1 || InpLivePerSide>8) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpImpulseMoveATR) || InpImpulseMoveATR<=0 ||
      !MathIsValidNumber(InpImpulseEfficiency) || InpImpulseEfficiency<=0 || InpImpulseEfficiency>1 ||
      !MathIsValidNumber(InpImpulseFailureATR) || InpImpulseFailureATR<=0) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpWyFailureATR) || InpWyFailureATR<=0 || InpWyFailureATR>2) return INIT_PARAMETERS_INCORRECT;
   if(!MathIsValidNumber(InpLCycleDepartureATR) || InpLCycleDepartureATR<=0) return INIT_PARAMETERS_INCORRECT;
   if(InpReaderPivotLookback<60 || InpReaderPivotLookback>2000 || InpQualityLookback<12 || InpQualityLookback>40 ||
      !MathIsValidNumber(InpQualityPullbackATR) || InpQualityPullbackATR<=0 ||
      !MathIsValidNumber(InpQualityMaxRiskATR) || InpQualityMaxRiskATR<=0 ||
      !MathIsValidNumber(InpQualityMaxExtensionATR) || InpQualityMaxExtensionATR<=0 ||
      !MathIsValidNumber(InpQualityMinRoomRisk) || InpQualityMinRoomRisk<=0 || InpMTFLookback<30 || InpMTFLookback>250 || InpContextFollowBars<1 || InpContextFollowBars>10 || InpContextKeep<1 || InpContextKeep>10 || InpContextTrendBars<12 || InpContextTrendBars>200 ||
      InpContextSwingStrength<1 || InpContextSwingStrength>5 ||
      InpContextTrendBars<2*InpContextSwingStrength+5 ||
      InpContextLegBars<2 || InpContextLegBars>10 || !MathIsValidNumber(InpContextWeakeningRatio) || InpContextWeakeningRatio<=0 ||
      InpContextWeakeningRatio>=1 || InpContextFontSize<6 || InpContextFontSize>14)
      return INIT_PARAMETERS_INCORRECT;
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
   IndicatorSetString(INDICATOR_SHORTNAME,"C7CB L COMPACT v2.37");
   Prefix="C7CB_PRO_"+IntegerToString((long)GetMicrosecondCount())+"_";
   LastClosed=0; FirstTime=0; ShownCount=0;
   LiveSDOn=false;LiveKLOn=false;LiveSnapshotCount=0;
   if(!InpForecastWorker) RefreshLevelButtons();
   ResetDisplayCache();
   {
      IndicatorSetString(INDICATOR_SHORTNAME,"C7CB L COMPACT v2.37");
      PlotIndexSetString(0,PLOT_LABEL,"Buy limit setup (not fill)");
      PlotIndexSetString(1,PLOT_LABEL,"Sell limit setup (not fill)");
      PlotIndexSetString(2,PLOT_LABEL,"");
      PlotIndexSetString(3,PLOT_LABEL,"");
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_NONE); // L object carries the limit tooltip.
      PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_NONE);
      for(int k=4;k<10;k++) PlotIndexSetInteger(k,PLOT_DRAW_TYPE,DRAW_NONE);
   }
   if(!InpForecastWorker)
   {
      if(InpForecastM30 && PeriodSeconds(_Period)<PeriodSeconds(PERIOD_M30)) ForecastHandles[0]=CreateForecastHandle(PERIOD_M30);
      if(InpForecastH1 && PeriodSeconds(_Period)<PeriodSeconds(PERIOD_H1)) ForecastHandles[1]=CreateForecastHandle(PERIOD_H1);
      for(int src=0;src<2;src++)
         if((src==0?InpForecastM30:InpForecastH1) && PeriodSeconds(_Period)<PeriodSeconds(src==0?PERIOD_M30:PERIOD_H1) && ForecastHandles[src]==INVALID_HANDLE)
            Print("Forecast source handle failed: ",src==0?"M30":"H1"," error=",GetLastError());
   }
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   IndicatorStopping=true;
   for(int src=0;src<2;src++) if(ForecastHandles[src]!=INVALID_HANDLE) {IndicatorRelease(ForecastHandles[src]);ForecastHandles[src]=INVALID_HANDLE;}
   string owned=Prefix;
   Prefix=""; // Prevent any rendering path from recreating objects during teardown.
   ResetNewEffortState();
   FreeMetricCache();NewRenderDeferred=false;LiveSnapshotCount=0;LiveSDOn=false;LiveKLOn=false;
   ResetDisplayCache();
   LastClosed=0;FirstTime=0;ShownCount=0;
   DeleteOwnedChartObjects(owned);
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
bool MetricCacheReady=false;
int MetricCacheCount=0;
double CachedContextATR[],CachedTickRV[],CachedRealRV[];
int CachedRealMissing[];
void FreeMetricCache()
{
   MetricCacheReady=false;MetricCacheCount=0;
   ArrayFree(CachedContextATR);ArrayFree(CachedTickRV);ArrayFree(CachedRealRV);ArrayFree(CachedRealMissing);
}
void PrepareMetricCache(const int count,const int prev,const bool reset,const double &high[],
                        const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   int old=MetricCacheCount;
   bool rebuild=reset || !MetricCacheReady || old>count || old<prev;
   MetricCacheReady=false;
   if(ArrayResize(CachedContextATR,count,1024)<count || ArrayResize(CachedTickRV,count,1024)<count ||
      ArrayResize(CachedRealRV,count,1024)<count || ArrayResize(CachedRealMissing,count,1024)<count)
   { FreeMetricCache();return; } // Raw functions remain valid if allocation fails.
   int start=rebuild?0:MathMax(0,MathMin(old-1,prev-1));
   for(int i=start;i<count;i++)
   {
      CachedRealMissing[i]=(i>0?CachedRealMissing[i-1]:0)+(volume[i]<=0?1:0);
      CachedContextATR[i]=0;CachedTickRV[i]=0;CachedRealRV[i]=0;
      if(i>=15)
      {
         double sum=0;
         for(int k=i-14;k<i;k++)
            sum+=MathMax(high[k]-low[k],MathMax(MathAbs(high[k]-close[k-1]),MathAbs(low[k]-close[k-1])));
         CachedContextATR[i]=sum/14.0;
      }
      if(i>=20)
      {
         double ts=0,rs=0;bool tk=true,rk=true;
         for(int j=i-20;j<i;j++)
         { if(ticks[j]<=0) tk=false;if(volume[j]<=0) rk=false;ts+=(double)ticks[j];rs+=(double)volume[j]; }
         if(tk && ticks[i]>0 && ts>0) CachedTickRV[i]=(double)ticks[i]/(ts/20.0);
         if(rk && volume[i]>0 && rs>0) CachedRealRV[i]=(double)volume[i]/(rs/20.0);
      }
   }
   MetricCacheCount=count;MetricCacheReady=true;
}

double ContextATR(const int i,const double &high[],const double &low[],const double &close[])
{
   if(i<15) return 0;
   if(MetricCacheReady && i<MetricCacheCount) return CachedContextATR[i];
   double sum=0;
   for(int k=i-14;k<i;k++)
      sum+=MathMax(high[k]-low[k],MathMax(MathAbs(high[k]-close[k-1]),MathAbs(low[k]-close[k-1])));
   return sum/14.0; // Simple average of 14 prior true ranges; no new ATR handle/buffer.
}

double EntryBandDistance(const double lo,const double hi,const double candleLow,const double candleHigh)
{
   if(candleHigh<lo) return lo-candleHigh;
   if(candleLow>hi) return candleLow-hi;
   return 0;
}
int ImpulseSide=0,ImpulseStart=-1,ImpulseKnown=-1,ImpulseExtremeBar=-1,ImpulseBreaks=0;
int ImpulseReleased[2];
double ImpulseGuard=0,ImpulseExtreme=0,ImpulseATR=0;
string ImpulseReading="nhịp chưa có quyền hướng";
void ResetImpulse()
{
   ImpulseReleased[0]=-1;ImpulseReleased[1]=-1;
   ImpulseSide=0;ImpulseStart=-1;ImpulseKnown=-1;ImpulseExtremeBar=-1;ImpulseBreaks=0;
   ImpulseGuard=0;ImpulseExtreme=0;ImpulseATR=0;ImpulseReading="nhịp chưa có quyền hướng";
}
void StepImpulse(const int i,const double &open[],const double &high[],const double &low[],const double &close[],
                 const long &ticks[],const long &volume[])
{
   if(!InpImpulseControl || i<32) return;
   double atr=ContextATR(i,high,low,close);if(atr<=0) return;
   if(ImpulseSide!=0)
   {
      int side=ImpulseSide,p=i-2;bool pivot=true;
      for(int k=1;k<=2;k++) if(side>0?low[p]>=low[p-k] || low[p]>low[p+k]:high[p]<=high[p-k] || high[p]<high[p+k]) pivot=false;
      double guard=side>0?low[p]:high[p];
      if(pivot && p>ImpulseStart && side*(guard-ImpulseGuard)>0 && side*(close[i]-close[p])>=0.8*atr)
         ImpulseGuard=guard;
      if(side*(close[i]-ImpulseGuard)<-InpImpulseFailureATR*ImpulseATR) ImpulseBreaks++;else ImpulseBreaks=0;
      if(ImpulseBreaks>=2)
      { ImpulseReleased[side>0?0:1]=i;ImpulseSide=0;ImpulseReading="nhịp cũ mất đáy/đỉnh bảo vệ qua hai Close"; }
      else
      {
         if(side*(close[i]-ImpulseExtreme)>0) { ImpulseExtreme=close[i];ImpulseExtremeBar=i; }
         if(i-ImpulseExtremeBar>=12)
         {
            double path=0,hi=high[i],lo=low[i];
            for(int j=i-11;j<=i;j++) { path+=MathAbs(close[j]-close[j-1]);hi=MathMax(hi,high[j]);lo=MathMin(lo,low[j]); }
            if(path>0 && MathAbs(close[i]-close[i-12])/path<0.25 && hi-lo<=3*atr)
            { ImpulseReleased[side>0?0:1]=i;ImpulseSide=0;ImpulseReading="nhịp chuyển sang cân bằng, bỏ quyền hướng cũ"; }
         }
      }
   }
   double net=close[i]-close[i-6],path=0;int side=net>0?1:-1,advances=0;
   bool real=UseRealWindow(i-26,i,volume),known=true;double ve=0,vl=0,early=0,late=0;
   for(int j=i-5;j<=i;j++)
   {
      double delta=side*(close[j]-close[j-1]);path+=MathAbs(delta);if(delta>0) advances++;
      double rv=QualityRelativeVolume(j,real,ticks,volume);if(rv<=0) known=false;
      if(j<i-2) { ve+=rv;early+=MathMax(0.0,delta); } else { vl+=rv;late+=MathMax(0.0,delta); }
   }
   bool effortWorks=known && !(ve>0 && vl>=ve && early>0 && late<early*0.60);
   bool push=MathAbs(net)>=InpImpulseMoveATR*atr && path>0 && MathAbs(net)/path>=InpImpulseEfficiency && advances>=4 && effortWorks;
   if(ImpulseSide==0 && push && i-6>=ImpulseReleased[side>0?0:1])
   {
      ImpulseSide=side;ImpulseStart=i-6;ImpulseKnown=i;ImpulseATR=atr;ImpulseBreaks=0;
      ImpulseGuard=side>0?low[i-6]:high[i-6];
      for(int j=i-5;j<=i;j++) ImpulseGuard=side>0?MathMin(ImpulseGuard,low[j]):MathMax(ImpulseGuard,high[j]);
      ImpulseExtreme=close[i];ImpulseExtremeBar=i;
   }
   if(ImpulseSide!=0) ImpulseReading=(ImpulseSide>0?"nhịp tăng còn hiệu lực":"nhịp giảm còn hiệu lực")+
      "; bảo vệ "+DoubleToString(ImpulseGuard,_Digits)+(ImpulseBreaks>0?"; cảnh báo Close phá lần 1":"");
}

struct ProWyState
{
   int stage,start,last,climax,breakBar,returnBar;
   double extreme,boundary,climaxRV,atr,returnExtreme;
   string eventName,status;
};
struct ProPivot { int bar,known,kind;double price; };
struct ProDegree { ProPivot points[64];int count,lastCandidate;string primary,alternative;int bias,score; };
ProWyState ProWy[2];ProDegree ProEW[2];
int WyControlSide=0,WyControlBreak=-1,WyControlFailures=0,WyObservedBreak[2];
double WyControlLevel=0,WyControlATR=0;
string WyControlReading="chưa có SOS/SOW xác nhận";
void StepWyControl(const int i,const double &close[])
{
   if(!InpProEnabled || !InpProWyckoff) return;
   int winner=-1,newest=-1;
   for(int d=0;d<2;d++) if(ProWy[d].stage>=6 && ProWy[d].breakBar>WyObservedBreak[d])
   {
      WyObservedBreak[d]=ProWy[d].breakBar;
      if(ProWy[d].breakBar>newest) { newest=ProWy[d].breakBar;winner=d; }
      else if(ProWy[d].breakBar==newest) winner=-1;
   }
   if(winner>=0)
   {
      WyControlSide=winner==0?1:-1;WyControlBreak=ProWy[winner].breakBar;
      WyControlLevel=ProWy[winner].boundary;WyControlATR=ProWy[winner].atr;WyControlFailures=0;
   }
   if(WyControlSide==0) return;
   if(WyControlSide*(close[i]-WyControlLevel)<-InpWyFailureATR*WyControlATR) WyControlFailures++;
   else WyControlFailures=0;
   if(WyControlFailures>=2)
   {
      WyControlReading="SOS/SOW mất hiệu lực: hai Close mất mốc; chờ cấu trúc mới";
      WyControlSide=0;return;
   }
   WyControlReading=(WyControlSide>0?"SOS: ưu tiên Buy":"SOW: ưu tiên Sell")+
      "; mốc "+DoubleToString(WyControlLevel,_Digits)+
      (WyControlFailures>0?"; cảnh báo mất mốc lần 1":"; giữ quyền hướng");
}

int ProObjectCount=0,ProLast=-1; // Count of retained WyDrawBook records; no parallel name array.
int WySCCount=0,WyBCCount=0,WyOtherCount=0,WyDrawErrors=0;
datetime WyLastMark=0;
struct WyDrawRecord { string name,text,tooltip;datetime stamp;double price,tip;int side,fontSize;color ink;bool dirty; };
WyDrawRecord WyDrawBook[];int WySerial=0;

int WyVisualBar[2],WyVisualLast[2],WyChainMark[2];double WyVisualExtreme[2],WyVisualATR[2];
bool WyVisualActive[2];
string WyClimaxObject(const int side,const int bar)
{ return Prefix+"PRO_"+(side>0?"SC_":"BC_")+IntegerToString(bar); }

void ResetPro()
{
   ResetImpulse();
   WyControlSide=0;WyControlBreak=-1;WyControlFailures=0;WyControlLevel=0;WyControlATR=0;
   WyControlReading="chưa có SOS/SOW xác nhận";
   WySCCount=0;WyBCCount=0;WyOtherCount=0;WyDrawErrors=0;WyLastMark=0;
   ProLast=-1;ProObjectCount=0;WySerial=0;ArrayFree(WyDrawBook);
   for(int d=0;d<2;d++)
   {
      WyChainMark[d]=-1;WyVisualActive[d]=false;WyVisualBar[d]=-1;WyVisualLast[d]=-100;
      WyObservedBreak[d]=-1;ProWy[d].breakBar=-1;ProWy[d].stage=0;ProWy[d].start=-1;ProWy[d].last=-1;ProWy[d].eventName="chưa có chuỗi";
      ProWy[d].status="Chưa xác nhận";ProWy[d].climax=-1;ProWy[d].returnBar=-1;
      ProEW[d].count=0;ProEW[d].lastCandidate=-1;ProEW[d].bias=0;ProEW[d].score=0;
      ProEW[d].primary="chưa đủ pivot";ProEW[d].alternative="";
   }
}
void UpdateWyMark(const string name,const string text,const color ink,const string tooltip)
{
   for(int n=ProObjectCount-1;n>=0;n--) if(WyDrawBook[n].name==name)
   { WyDrawBook[n].text=text;WyDrawBook[n].ink=ink;WyDrawBook[n].tooltip=tooltip;WyDrawBook[n].dirty=true;break; }
}
void RenderWyMarks()
{
   if(InpForecastWorker)return;
   if(!InpEnabled || !InpProEventMarks || Prefix=="") return;
   for(int n=0;n<ProObjectCount;n++)
   {
      WyDrawRecord a=WyDrawBook[n];string tri=a.name+"_TRI";
      if(!a.dirty && ObjectFind(0,a.name)>=0 && ObjectFind(0,tri)>=0) continue;
      bool okay=true;
      if(ObjectFind(0,a.name)<0) okay=ObjectCreate(0,a.name,OBJ_TEXT,0,a.stamp,a.price);
      if(!okay) { WyDrawErrors++;Print("WY text error ",GetLastError()," ",a.name);continue; }
      ObjectSetString(0,a.name,OBJPROP_TEXT,a.text);ObjectSetString(0,a.name,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,a.name,OBJPROP_FONTSIZE,a.fontSize);
      ObjectSetInteger(0,a.name,OBJPROP_ANCHOR,a.side>0?ANCHOR_UPPER:ANCHOR_LOWER);
      ObjectSetInteger(0,a.name,OBJPROP_COLOR,a.ink);ObjectSetInteger(0,a.name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,a.name,OBJPROP_HIDDEN,true);ObjectSetString(0,a.name,OBJPROP_TOOLTIP,a.tooltip);
      if(ObjectFind(0,tri)<0 && !ObjectCreate(0,tri,OBJ_TEXT,0,a.stamp,a.tip))
      { WyDrawErrors++;Print("WY triangle error ",GetLastError()," ",tri);continue; }
      ObjectSetString(0,tri,OBJPROP_TEXT,a.side>0?"▲":"▼");ObjectSetString(0,tri,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,tri,OBJPROP_FONTSIZE,5);ObjectSetInteger(0,tri,OBJPROP_ANCHOR,a.side>0?ANCHOR_UPPER:ANCHOR_LOWER);
      ObjectSetInteger(0,tri,OBJPROP_COLOR,a.ink);ObjectSetInteger(0,tri,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tri,OBJPROP_HIDDEN,true);ObjectSetString(0,tri,OBJPROP_TOOLTIP,a.tooltip);
      WyDrawBook[n].dirty=false;
   }
}
void ProRecord(const int i,const int side,const string label,const string detail,const bool confirmed,
               const datetime &time[],const double &high[],const double &low[],const double atr)
{
   if(!InpProEventMarks || !InpEnabled || Prefix=="") return;
   if(label=="PS" || label=="PSY" || label=="Markup" || label=="Markdown") return;
   string name=(label=="SC" || label=="BC")?WyClimaxObject(side,i):Prefix+"PRO_"+IntegerToString(WySerial++);
   for(int n=0;n<ProObjectCount;n++) if(WyDrawBook[n].name==name) return;
   if(!InpWyHistory && ProObjectCount>=InpWyKeepEvents)
   {
      string old=WyDrawBook[0].name;
      if(!NewRenderDeferred) { ObjectDelete(0,old);ObjectDelete(0,old+"_TRI"); }
      for(int n=1;n<ProObjectCount;n++) WyDrawBook[n-1]=WyDrawBook[n];
      ProObjectCount--;
   }
   if(ArrayResize(WyDrawBook,ProObjectCount+1,64)<ProObjectCount+1)
   { WyDrawErrors++;return; }
   int id=ProObjectCount++;
   WyDrawBook[id].name=name;WyDrawBook[id].stamp=time[i];WyDrawBook[id].side=side;
   WyDrawBook[id].text=label=="Spring"?"SP":label=="UTAD"?"UT":label;
   WyDrawBook[id].fontSize=label=="BC"?InpWyBCFontSize:(int)MathMax(5,InpWyFontSize);
   WyDrawBook[id].dirty=true;
   WyDrawBook[id].price=side>0?low[i]-0.48*atr:high[i]+0.48*atr;
   WyDrawBook[id].tip=side>0?low[i]-0.12*atr:high[i]+0.12*atr;
   WyDrawBook[id].ink=confirmed?(side>0?clrLimeGreen:clrOrangeRed):clrGray;
   WyDrawBook[id].tooltip=label+"; "+detail+"; biết tại đóng nến "+TimeToString(time[i]+PeriodSeconds(_Period));
   if(label=="SC") WySCCount++;else if(label=="BC") WyBCCount++;else WyOtherCount++;
   WyLastMark=time[i];
}
void StepWyVisualClimax(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                        const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(!InpWyStandaloneClimax || !InpProEventMarks || i<26) return;
   int side=slot==0?1:-1;
   if(WyVisualActive[slot])
   {
      int p=WyVisualBar[slot];double atr=WyVisualATR[slot];
      double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0;
      bool response=i>p && side*(close[i]-close[p])>=0.6*atr && side*(close[i]-open[i])>0 && loc>=0.65;
      bool invalid=side*(close[i]-WyVisualExtreme[slot])<-0.15*atr;
      string name=WyClimaxObject(side,p);
      if(response || invalid || i-p>=3)
      {
         string text=side>0?"SC":"BC";
         string detail=text+(response?": có phản ứng Close; chưa xác nhận tích lũy/phân phối":invalid?": bị xuyên, chưa xác nhận":": chưa có phản ứng đủ rõ")+
            "; ứng viên tại "+TimeToString(time[p])+"; cập nhật tại đóng nến "+TimeToString(time[i]+PeriodSeconds(_Period));
         UpdateWyMark(name,text,response?(side>0?clrLimeGreen:clrOrangeRed):clrGray,detail);
         WyVisualActive[slot]=false;
      }
   }
   if(WyVisualActive[slot] || i-WyVisualLast[slot]<4) return;
   double atr=ContextATR(i,high,low,close),range=high[i]-low[i];if(atr<=0 || range<=0) return;
   bool real=UseRealWindow(i-25,i,volume);double rv=QualityRelativeVolume(i,real,ticks,volume);
   double extreme=side>0?low[i]:high[i],prior=side>0?low[i-1]:high[i-1];
   for(int j=i-20;j<i;j++) prior=side>0?MathMin(prior,low[j]):MathMax(prior,high[j]);
   bool approach=-side*(close[i-1]-close[i-6])>=InpProApproachATR*atr;
   double loc=side>0?(close[i]-low[i])/range:(high[i]-close[i])/range;
   double wick=side>0?MathMin(open[i],close[i])-low[i]:high[i]-MathMax(open[i],close[i]);
   bool reject=loc>=0.60 && (wick>=0.30*range || MathAbs(close[i]-open[i])<=0.35*range);
   if(!approach || side*(extreme-prior)>0.15*atr || rv<InpProClimaxRV || (!reject && rv<2.0)) return;
   ProRecord(i,side,side>0?"SC":"BC","ứng viên giá–volume độc lập; chờ phản ứng, chưa xác nhận chuỗi",false,time,high,low,atr);
   WyVisualActive[slot]=true;WyVisualBar[slot]=i;WyVisualLast[slot]=i;WyVisualExtreme[slot]=extreme;WyVisualATR[slot]=atr;
}

void ProWyEvent(const int slot,const int stage,const int i,const string label,const bool confirmed,
                const datetime &time[],const double &high[],const double &low[])
{
   if(label=="SC" || label=="BC") WyChainMark[slot]=i;
   ProWy[slot].stage=stage;ProWy[slot].last=i;ProWy[slot].eventName=label;
   ProWy[slot].status=confirmed?"Đã xác nhận theo quy tắc":"Chưa xác nhận";
   ProRecord(i,slot==0?1:-1,label,ProWy[slot].status,confirmed,time,high,low,ProWy[slot].atr);
}
void StepProWy(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
               const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   int side=slot==0?1:-1;double atr=ContextATR(i,high,low,close);if(atr<=0 || i<26) return;
   bool real=UseRealWindow(i-25,i,volume);double rv=QualityRelativeVolume(i,real,ticks,volume);
   if(rv<=0) return;
   double range=high[i]-low[i];if(range<=0) return;
   double loc=side>0?(close[i]-low[i])/range:(high[i]-close[i])/range;
   double wick=side>0?MathMin(open[i],close[i])-low[i]:high[i]-MathMax(open[i],close[i]);
   double extreme=side>0?low[i]:high[i],body=MathAbs(close[i]-open[i]);
   double previous=side>0?low[i-1]:high[i-1];
   for(int j=i-20;j<i;j++) previous=side>0?MathMin(previous,low[j]):MathMax(previous,high[j]);
   bool atExtreme=side*(extreme-previous)<=0.15*atr;
   bool approach=-side*(close[i-1]-close[i-6])>=InpProApproachATR*atr;
   bool reject=loc>=0.60 && (wick>=0.3*range || body<=0.35*range);
   bool climax=atExtreme && approach && rv>=InpProClimaxRV && reject;
   ProWyState a=ProWy[slot];
   if(a.stage>0 && (i-a.start>InpProWyMaxBars ||
      (a.stage>=2 && side*(close[i]-a.extreme)<-0.35*a.atr && side*(close[i-1]-a.extreme)<-0.35*a.atr)))
   {
      ProWy[slot].stage=0;ProWy[slot].status="Chuỗi hết hạn hoặc vô hiệu";
      ProWy[slot].eventName="Hủy "+a.eventName;a=ProWy[slot];
   }
   if(a.stage==0)
   {
      if(!atExtreme || !approach || rv<1.2 || !reject) return;
      ProWy[slot].start=i;ProWy[slot].atr=atr;ProWy[slot].extreme=extreme;
      ProWy[slot].climaxRV=rv;ProWy[slot].climax=i;ProWy[slot].returnBar=-1;
      ProWyEvent(slot,climax?2:1,i,climax?(side>0?"SC":"BC"):(side>0?"PS":"PSY"),false,time,high,low);
      return;
   }
   if(a.stage==1)
   {
      if(climax)
      {
         ProWy[slot].extreme=extreme;ProWy[slot].climaxRV=rv;ProWy[slot].climax=i;
         ProWyEvent(slot,2,i,side>0?"SC":"BC",false,time,high,low);
      }
      return;
   }
   if(a.stage==2)
   {
      if(side*(extreme-a.extreme)<0)
      { ProWy[slot].extreme=extreme;ProWy[slot].climax=i;ProWy[slot].climaxRV=rv; }
      else if(i>a.climax && side*(close[i]-a.extreme)>=InpProARatr*a.atr && side*(close[i]-close[i-1])>0)
      {
         ProWy[slot].boundary=side>0?high[i]:low[i];
         string mark=WyClimaxObject(side,WyChainMark[slot]);
         if(WyVisualBar[slot]==WyChainMark[slot]) WyVisualActive[slot]=false;
         string detail="SC/BC có AR xác nhận phản ứng tại đóng nến "+TimeToString(time[i]+PeriodSeconds(_Period))+"; chưa xác nhận toàn chuỗi";
         UpdateWyMark(mark,side>0?"SC":"BC",side>0?clrLimeGreen:clrOrangeRed,detail);
         ProWyEvent(slot,3,i,"AR",true,time,high,low);
      }
      return;
   }
   if(a.stage==3)
   {
      if(side*(close[i]-close[i-1])>0)
         ProWy[slot].boundary=side>0?MathMax(a.boundary,high[i]):MathMin(a.boundary,low[i]);
      bool test=i>a.last && MathAbs(extreme-a.extreme)<=0.4*a.atr &&
                close[i]*side>a.extreme*side && rv<=a.climaxRV*0.85 && loc>=0.55;
      if(test) ProWyEvent(slot,4,i,"ST",true,time,high,low);
      return;
   }
   if(a.stage==4 || a.stage==5)
   {
      bool spring=side*(extreme-a.extreme)<0 && side*(close[i]-a.extreme)>0 && loc>=0.65;
      if(a.stage==4 && spring)
      { ProWyEvent(slot,5,i,side>0?"Spring":"UTAD",false,time,high,low);return; }
      bool breakout=side*(close[i]-a.boundary)>0.1*a.atr && side*(close[i]-open[i])>0 && loc>=0.65 && rv>=1.0 &&
                    side*(close[i]-close[i-1])>=0.25*a.atr && body>=0.30*range;
      if(breakout)
      {
         ProWy[slot].breakBar=i;ProWy[slot].returnBar=-1;
         ProWyEvent(slot,6,i,side>0?"SOS":"SOW",true,time,high,low);
      }
      return;
   }
   if(a.stage==6)
   {
      if(side*(close[i]-a.boundary)<-InpWyFailureATR*a.atr &&
         side*(close[i-1]-a.boundary)<-InpWyFailureATR*a.atr)
      { ProWy[slot].stage=0;ProWy[slot].eventName="SOS/SOW thất bại";ProWy[slot].status="Vô hiệu";return; }
      if(a.returnBar<0 && side*(close[i]-close[i-1])<0)
      { ProWy[slot].returnBar=i;ProWy[slot].returnExtreme=extreme;return; }
      if(a.returnBar>=0)
      {
         ProWy[slot].returnExtreme=side>0?MathMin(a.returnExtreme,low[i]):MathMax(a.returnExtreme,high[i]);
         bool holds=side*(ProWy[slot].returnExtreme-a.boundary)>=-0.35*a.atr;
         int first=MathMax(a.climax+1,a.last-6),backStart=a.returnBar;
         bool allReal=UseRealWindow(MathMax(0,first-20),i,volume),known=true;
         double pushV=0,backV=0,backProgress=0;int np=0,nb=0;
         for(int j=first;j<=a.breakBar;j++)
         { double v=QualityRelativeVolume(j,allReal,ticks,volume);if(v<=0) known=false;pushV+=v;np++; }
         int lastOpposite=-1;
         for(int j=backStart;j<i;j++)
         {
            double v=QualityRelativeVolume(j,allReal,ticks,volume);if(v<=0) known=false;backV+=v;nb++;
            backProgress+=MathMax(0.0,-side*(close[j]-close[j-1]));
            if(side*(close[j]-open[j])<0) lastOpposite=j;
         }
         bool testEffort=known && np>0 && nb>0 &&
            (backV/nb<=pushV/np*1.05 || (backV/nb>=pushV/np && backProgress/nb<=0.20*a.atr));
         bool reaction=lastOpposite>=0 && side*(close[i]-open[lastOpposite])>0 &&
            side*(close[i]-close[i-1])>=0.20*a.atr && side*(close[i]-open[i])>0 && loc>=0.65;
         if(holds && testEffort && reaction)
            ProWyEvent(slot,7,i,side>0?"LPS":"LPSY",true,time,high,low);
         else if(i-a.returnBar>InpProTestBars)
         { ProWy[slot].stage=0;ProWy[slot].eventName="Test sau phá biên chưa đạt";ProWy[slot].status="Chưa xác nhận"; }
      }
      return;
   }
   if(a.stage==7 && i>a.last && side*(close[i]-a.boundary)>=0.8*a.atr)
      ProWyEvent(slot,8,i,side>0?"Markup":"Markdown",true,time,high,low);
}
bool ProCount(const int degree,const int start,const int end,string &name,int &bias,int &score)
{
   int legs=end-start;if(legs<1 || legs>8) return false;
   int side=ProEW[degree].points[start].kind<0?1:-1;
   double p[9];for(int k=0;k<=legs;k++) p[k]=side*ProEW[degree].points[start+k].price;
   for(int k=1;k<=legs;k++)
      if((k%2==1 && p[k]<=p[k-1]) || (k%2==0 && p[k]>=p[k-1])) return false;
   if(legs>=2 && p[2]<=p[0]) return false;
   if(legs>=3 && p[3]<=p[1]) return false;
   if(legs>=4 && p[4]<=p[1]) return false;
   if(legs>=5 && (p[5]<=p[3] || p[3]-p[2]<MathMin(p[1]-p[0],p[5]-p[4]))) return false;
   if(legs>=6 && p[6]>=p[5]) return false;
   if(legs>=7 && p[7]>=p[5]) return false;
   if(legs>=8 && p[8]>=p[6]) return false;
   string step=legs<=5?IntegerToString(legs):legs==6?"A":legs==7?"B":"C";
   name=(side>0?"tăng ":"giảm ")+step+(legs>=5?" — khớp quy tắc giá":"? — đếm tạm");
   bias=(legs==2 || legs==4 || legs==8)?side:(legs==1 || legs==3 || legs==5 || legs==7)?-side:side;
   score=legs;return true;
}
void StepProEW(const int d,const int i,const double &high[],const double &low[],const double &close[])
{
   int strength=d==0?InpProEWStrength:InpProEWStrengthMajor,p=i-strength;
   if(p<strength+20 || p<=ProEW[d].lastCandidate) return;
   ProEW[d].lastCandidate=p;bool ph=true,pl=true;
   for(int k=1;k<=strength;k++)
   { if(high[p]<=high[p-k] || high[p]<high[p+k]) ph=false;if(low[p]>=low[p-k] || low[p]>low[p+k]) pl=false; }
   if(ph==pl) return;
   int kind=ph?1:-1;double price=ph?high[p]:low[p];int n=ProEW[d].count;
   if(n>0 && ProEW[d].points[n-1].kind==kind)
   {
      if(kind*(price-ProEW[d].points[n-1].price)<=0) return;
      n--; // Latest confirmed endpoint may extend; previous tooltip snapshots stay unchanged.
   }
   else if(n>0)
   {
      double atr=ContextATR(p,high,low,close),threshold=d==0?InpProEWMinATR:InpProEWMinATRMajor;
      if(atr<=0 || MathAbs(price-ProEW[d].points[n-1].price)<threshold*atr) return;
   }
   if(n>=64) { for(int j=1;j<64;j++) ProEW[d].points[j-1]=ProEW[d].points[j];n=63; }
   ProEW[d].points[n].bar=p;ProEW[d].points[n].known=i;ProEW[d].points[n].kind=kind;ProEW[d].points[n].price=price;
   ProEW[d].count=n+1;ProEW[d].primary="chưa đủ pivot";ProEW[d].alternative="";ProEW[d].bias=0;ProEW[d].score=0;
   for(int legs=8;legs>=1;legs--)
   {
      int start=n-legs;if(start<0) continue;string name="";int bias=0,score=0;
      if(!ProCount(d,start,n,name,bias,score)) continue;
      if(ProEW[d].score==0)
      { ProEW[d].primary=name;ProEW[d].bias=bias;ProEW[d].score=score; }
      else { ProEW[d].alternative=name;break; }
   }
}
string ProSummary()
{
   if(!InpProEnabled) return "";
   string text="";
   if(InpProWyckoff)
   {
      int d=ProWy[1].last>ProWy[0].last?1:0,st=ProWy[d].stage;
      string phase=st==0?"?":st<=3?"A?":st==4?"B?":st==5?"C?":st<=7?"D?":"E?";
      text="Wy "+phase+" "+ProWy[d].eventName+" ("+ProWy[d].status+")";
   }
   if(InpProElliott)
   {
      text+=(text==""?"":"; ")+"EW nhỏ "+ProEW[0].primary+"; lớn "+ProEW[1].primary;
      if(InpContextDebugDetails && ProEW[0].alternative!="") text+="; phương án khác "+ProEW[0].alternative;
   }
   if(InpImpulseControl) text+=(text==""?"":"; ")+ImpulseReading;
   if(InpProWyckoff) text+=(text==""?"":"; ")+WyControlReading;
   return text;
}
bool ProAllows(const int side,string &reason,const bool localSellTop=false)
{
   reason="";if(!InpProEnabled) return true;
   if(InpWyDirectionalControl && InpProWyckoff && WyControlSide!=0 && side!=WyControlSide && !(side<0 && localSellTop))
   { reason=WyControlReading+"; chặn entry ngược hướng cho tới khi mất hiệu lực";return false; }
   if(InpProFilterWy && InpProWyckoff && !InpWyDirectionalControl && !(side<0 && localSellTop))
   {
      int same=side>0?0:1,other=1-same;
      if(ProWy[other].stage>=6 && ProWy[other].last>ProWy[same].last)
      { reason="ngược chuỗi SOS/SOW mới nhất";return false; }
   }
   if(InpProFilterEW && InpProElliott && ProEW[0].score>=2 && ProEW[1].score>=2 &&
      ProEW[0].bias==-side && ProEW[1].bias==-side)
   { reason="hai cấp đếm EW cùng nghiêng ngược entry";return false; }
   return true;
}
void StepPro(const int i,const datetime &time[],const double &open[],const double &high[],const double &low[],
             const double &close[],const long &ticks[],const long &volume[])
{
   if((!InpProEnabled && !InpProEventMarks) || i<=ProLast) return;
   if(InpProWyckoff) for(int d=0;d<2;d++) StepProWy(d,i,time,open,high,low,close,ticks,volume);
   if(InpProWyckoff) for(int d=0;d<2;d++) StepWyVisualClimax(d,i,time,open,high,low,close,ticks,volume);
   StepWyControl(i,close);
   if(InpProEnabled && InpProElliott) for(int d=0;d<2;d++) StepProEW(d,i,high,low,close);
   ProLast=i;
}

struct PivotMarketReading
{
   bool ready,volumeKnown,truncated;
   int background,leg,anchor,bars,protectedBar;
   double anchorPrice,protectedPrice,efficiency,pullback,relativeVolume,resultPerVolume;
   string foundation,phase,force,volumeText,advice;
};
PivotMarketReading LatestMarketReading;
void ReadPivotMarket(const int i,const double &open[],const double &high[],const double &low[],
                     const double &close[],const long &ticks[],const long &volume[],PivotMarketReading &m)
{
   m.ready=false;m.volumeKnown=false;m.truncated=false;m.background=0;m.leg=0;m.anchor=-1;m.bars=0;
   m.protectedBar=-1;m.anchorPrice=0;m.protectedPrice=0;m.efficiency=0;m.pullback=0;m.relativeVolume=0;m.resultPerVolume=0;
   m.foundation="Nền chưa rõ";m.phase="Chưa đủ pivot xác nhận";m.force="chưa đủ dữ liệu";
   m.volumeText="volume chưa đủ dữ liệu";m.advice="Chờ cấu trúc rõ, không suy từ một nến";
   if(i<30) return;
   int strength=InpContextSwingStrength,first=MathMax(20,i-InpReaderPivotLookback);
   int h1=-1,h2=-1,l1=-1,l2=-1;
   for(int j=i-1-strength;j>=MathMax(first,strength);j--)
   {
      bool ph=true,pl=true;
      for(int k=1;k<=strength;k++)
      {
         if(high[j]<=high[j-k] || high[j]<high[j+k]) ph=false;
         if(low[j]>=low[j-k] || low[j]>low[j+k]) pl=false;
      }
      if(ph==pl) continue;
      if(ph) { if(h1<0) h1=j;else if(h2<0) h2=j; }
      if(pl) { if(l1<0) l1=j;else if(l2<0) l2=j; }
      if(h2>=0 && l2>=0) break;
   }
   if(h1<0 || l1<0) { m.truncated=first>20;return; }
   if(h2>=0 && l2>=0)
   {
      if(high[h1]>high[h2] && low[l1]>low[l2]) m.background=1;
      else if(high[h1]<high[h2] && low[l1]<low[l2]) m.background=-1;
   }
   m.foundation=m.background>0?"Nền tăng":m.background<0?"Nền giảm":"Cấu trúc hỗn hợp/chưa rõ";
   m.anchor=l1>h1?l1:h1;m.leg=l1>h1?1:-1;
   m.anchorPrice=m.leg>0?low[m.anchor]:high[m.anchor];m.bars=i-m.anchor;
   m.protectedBar=m.background>0?l1:m.background<0?h1:m.anchor;
   m.protectedPrice=m.background>0?low[l1]:m.background<0?high[h1]:m.anchorPrice;
   double atr=ContextATR(i,high,low,close);
   if(atr<=0 || m.bars<1) return;
   int a=m.anchor+1,n=i-a+1,split=a+n/2;
   bool real=UseRealWindow(MathMax(0,a-20),i,volume),known=true;
   double sumVolume=0;int missingVolume=0;
   for(int j=a-20;j<a;j++)
   { double v=(double)(real?volume[j]:ticks[j]);sumVolume+=v;if(v<=0) missingVolume++; }
   double earlyMove=0,lateMove=0,earlyVol=0,lateVol=0,earlyCounter=0,lateCounter=0;
   double path=0,peak=m.anchorPrice,deepest=0;
   int ne=0,nl=0;
   double recentRange=0,recentBody=0,recentLoc=0,recentOverlap=0;
   int recentCount=0,overlapCount=0;
   double hiEarly=-EMPTY_VALUE,loEarly=EMPTY_VALUE,hiLate=-EMPTY_VALUE,loLate=EMPTY_VALUE;
   int recentStart=MathMax(20,i-7),midRecent=(recentStart+i+1)/2;
   for(int j=a;j<=i;j++)
   {
      double v=(double)(real?volume[j]:ticks[j]);
      double rv=v>0 && sumVolume>0?v/(sumVolume/20.0):0;
      if(rv<=0 || missingVolume>0) known=false;
      double delta=m.leg*(close[j]-close[j-1]);
      double counter=MathMax(0.0,-delta),advance=MathMax(0.0,delta);
      path+=MathAbs(close[j]-close[j-1]);
      if(j<split) { earlyMove+=advance;earlyCounter+=counter;earlyVol+=rv;ne++; }
      else { lateMove+=advance;lateCounter+=counter;lateVol+=rv;nl++; }
      if(m.leg>0) { peak=MathMax(peak,high[j]);deepest=MathMax(deepest,peak-low[j]); }
      else { peak=MathMin(peak,low[j]);deepest=MathMax(deepest,high[j]-peak); }
      double dropped=(double)(real?volume[j-20]:ticks[j-20]);
      sumVolume+=v-dropped;
      if(dropped<=0) missingVolume--;if(v<=0) missingVolume++;
   }
   for(int j=recentStart;j<=i;j++)
   {
      if(j>=recentStart)
      {
         double range=high[j]-low[j];
         recentRange+=range;recentBody+=MathAbs(close[j]-open[j]);
         recentLoc+=range>0?(close[j]-low[j])/range:0.5;recentCount++;
         if(j>recentStart)
         {
            double common=MathMax(0.0,MathMin(high[j],high[j-1])-MathMax(low[j],low[j-1]));
            recentOverlap+=common/MathMax(_Point,MathMin(range,high[j-1]-low[j-1]));overlapCount++;
         }
         if(j<midRecent) { hiEarly=MathMax(hiEarly,high[j]);loEarly=MathMin(loEarly,low[j]); }
         else { hiLate=MathMax(hiLate,high[j]);loLate=MathMin(loLate,low[j]); }
      }
   }
   double net=m.leg*(close[i]-close[m.anchor]);
   m.efficiency=path>0?net/path:0;
   m.pullback=deepest/atr;
   double avEarly=earlyVol/MathMax(1,ne),avLate=lateVol/MathMax(1,nl);
   double mvEarly=earlyMove/MathMax(1,ne),mvLate=lateMove/MathMax(1,nl);
   double ctEarly=earlyCounter/MathMax(1,ne),ctLate=lateCounter/MathMax(1,nl);
   m.volumeKnown=known;m.relativeVolume=avLate;
   m.resultPerVolume=lateVol>0?lateMove/(atr*lateVol):0;
   double oldResult=earlyVol>0?earlyMove/(atr*earlyVol):0;
   bool weakening=n>=6 && ne>0 && mvEarly>0 &&
                  (mvLate<mvEarly*0.75 || (ctLate>ctEarly*1.3 && ctLate>0.1*atr));
   bool effortStall=known && n>=6 && oldResult>0 && avLate>=avEarly*1.15 && m.resultPerVolume<oldResult*0.75;
   bool strong=net>=atr && m.efficiency>=0.55 && ctLate<=MathMax(0.1*atr,mvLate*0.4);
   bool reaccelerating=n>=6 && ne>0 && mvLate>mvEarly*1.25 && ctLate<MathMax(0.1*atr,ctEarly);
   bool broken=m.background>0?close[i]<low[l1]:m.background<0?close[i]>high[h1]:false;
   double recentPath=0;
   for(int j=recentStart+1;j<=i;j++) recentPath+=MathAbs(close[j]-close[j-1]);
   double recentEff=recentPath>0?MathAbs(close[i]-close[recentStart])/recentPath:0;
   double overlap=overlapCount>0?recentOverlap/overlapCount:0;
   bool sideways=recentCount>=5 && recentEff<0.30 && overlap>=0.50;
   bool narrow=sideways && hiEarly>loEarly && hiLate>loLate && hiLate-loLate<(hiEarly-loEarly)*0.75;
   bool wide=sideways && recentRange/MathMax(1,recentCount)>=0.9*atr;
   string legName=m.leg>0?"Nhịp tăng":"Nhịp giảm";
   m.phase=legName;
   m.force=effortStall?"nỗ lực tăng nhưng giá tiến ít":weakening?"đang giảm lực":reaccelerating?"đang tăng tốc lại":strong?"lực đẩy mạnh":"lực đẩy chưa rõ";
   if(sideways)
   {
      m.phase=narrow?"Sideway co hẹp":wide?"Giằng co biên rộng":"Sideway trong biên";
      if(m.background!=0 && !broken) m.phase+=(m.background>0?" trong nền tăng":" trong nền giảm");
      m.force="hai phía chưa tạo tiến triển rõ";
   }
   else if(m.background!=0 && m.leg!=m.background && !broken)
   {
      bool weakPullback=m.efficiency<0.45 && (!known || avLate<=1.0);
      m.phase=weakPullback?"Hồi yếu, cấu trúc nền còn giữ":"Hồi đối ứng, cấu trúc nền còn giữ";
   }
   if(broken)
   { m.phase="Phá mốc bảo vệ, ứng viên chuyển nền";m.advice="Chờ giữ được phía phá; chưa gọi đảo chiều hoàn tất"; }
   else if(sideways) m.advice="Chờ thoát biên và giữ được; chưa chọn hướng từ một nến";
   else if(m.background!=0 && m.leg!=m.background) m.advice="Theo dõi hồi có giữ mốc bảo vệ, chưa coi là đảo chiều";
   else if(effortStall || weakening) m.advice="Không đuổi nhịp; chờ phản ứng hoặc hồi giữ cấu trúc";
   else if(strong || reaccelerating) m.advice="Ưu tiên theo nhịp; không bắt đỉnh/đáy chỉ vì một nến ngược";
   else m.advice="Chờ giá xác nhận hướng tại mốc cấu trúc";
   if(n<4 && known) m.volumeText="nhịp mới, chưa đủ nến so diễn tiến volume";
   else if(!known) m.volumeText="thiếu volume, chưa kết luận nỗ lực/kết quả";
   else if(effortStall) m.volumeText="volume tăng, tiến giá giảm; gặp lực đối ứng";
   else if(avLate<avEarly*0.8)
      m.volumeText=mvLate>=mvEarly*0.9?"volume giảm, giá còn tiến; chưa đủ gọi yếu":"volume và tiến giá cùng giảm";
   else if(avLate>avEarly*1.2)
      m.volumeText=mvLate>mvEarly*1.1?"volume và tiến giá cùng tăng":"volume tăng, giá chưa tiến tương ứng";
   else m.volumeText="volume tương đối ổn định";
   m.ready=true;
}
string PivotReaderDescription(const PivotMarketReading &m)
{
   if(!m.ready) return m.truncated?"Chưa tìm đủ pivot trong giới hạn lịch sử":"Chưa đủ đỉnh/đáy xác nhận";
   return m.foundation+"; "+m.phase+", "+m.force+" ("+IntegerToString(m.bars)+" nến từ "+(m.leg>0?"đáy":"đỉnh")+")";
}
void RefreshLiveMarketReader(const int count,const datetime &time[],const double &open[],const double &high[],
                            const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(InpForecastWorker)return;
   if(!InpPivotMarketReader || !InpEnabled || count<32) return;
   int i=count-2;
   if(ReaderLastClosed==time[i]) return;
   ReadPivotMarket(i,open,high,low,close,ticks,volume,LatestMarketReading);
   ReaderLastClosed=time[i];
   if(InpDebugNewBars)
      Print("C7CB READER | ",TimeToString(time[i])," | ",PivotReaderDescription(LatestMarketReading)," | ",LatestMarketReading.volumeText);
   if(!InpReaderLiveTooltip || Prefix=="") return;
   string name=Prefix+"LIVE_MARKET_READER";
   double atr=ContextATR(i,high,low,close),price=high[i]+MathMax(atr*0.8,20*_Point);
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_TEXT,0,time[i],price)) return;
      ObjectSetString(0,name,OBJPROP_TEXT,"BC");ObjectSetString(0,name,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,7);ObjectSetInteger(0,name,OBJPROP_COLOR,clrSilver);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   ObjectMove(0,name,0,time[i],price);
   string tip="THỊ TRƯỜNG — nến đã đóng\n"+PivotReaderDescription(LatestMarketReading)+
      "\nVolume: "+LatestMarketReading.volumeText+".\nQuan sát: "+LatestMarketReading.advice+".";
   if(InpProEnabled) tip+="\nPRO: "+ProSummary();
   string pendingL=LTrendSummary();if(pendingL!="") tip+="\n"+pendingL;
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
}

int QualityChartCount=0;
struct EntryQuality
{
   int state; // 0=có thể xét, 1=cảnh báo, 2=chặn ngược lực rõ
   bool hardBlock;
   string phase,reason;
   bool transition,volumeKnown;
   double risk,extension,room,protect;
   int runs;
   int origin;
   double clusterEdge;
   bool mtfMissing;
};
double QualityRelativeVolume(const int i,const bool real,const long &ticks[],const long &volume[])
{
   if(i<20) return 0;
   if(MetricCacheReady && i<MetricCacheCount) return real?CachedRealRV[i]:CachedTickRV[i];
   double sum=0;
   for(int j=i-20;j<i;j++)
   { double v=(double)(real?volume[j]:ticks[j]);if(v<=0) return 0;sum+=v; }
   double current=(double)(real?volume[i]:ticks[i]);
   return current>0 && sum>0?current/(sum/20.0):0;
}
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
   if(cache<0 || cache>=48 || cutoff<=0) return false;
   int seconds=PeriodSeconds(tf);
   if(MTFCache[cache].ready && seconds>0 &&
      cutoff>=MTFCache[cache].lastClosed+seconds && cutoff<MTFCache[cache].lastClosed+2*seconds)
      return true;
   if(MTFCache[cache].ready && MTFSuccessEpoch[cache]==MTFQueryEpoch && MTFSuccessCutoff[cache]==cutoff) return true;
   int shift=iBarShift(_Symbol,tf,cutoff-1,false);
   if(shift<0 || seconds<=0) return false;
   datetime opened=iTime(_Symbol,tf,shift);
   if(opened<=0) return false;
   if(opened+seconds>cutoff) shift++;
   if(shift<1) shift=1;
   datetime last=iTime(_Symbol,tf,shift);
   if(last<=0 || last+seconds>cutoff) return false;
   if(MTFCache[cache].ready && MTFCache[cache].lastClosed==last)
   { MTFSuccessEpoch[cache]=MTFQueryEpoch;MTFSuccessCutoff[cache]=cutoff;return true; }
   MTFCache[cache].ready=false;
   MqlRates r[];
   ArraySetAsSeries(r,false);
   int needed=InpMTFLookback+20;
   int copied=CopyRates(_Symbol,tf,shift,needed,r);
   if(copied!=needed) return false;
   int end=copied-1;
   if(r[end].time!=last || r[end].time+seconds>cutoff) return false;
   MTFCache[cache].count=0;
   MTFCache[cache].hasPH=false;MTFCache[cache].hasPL=false;
   MTFCache[cache].lastTime=r[end].time;MTFCache[cache].phTime=0;MTFCache[cache].plTime=0;
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
      if(ph && !MTFCache[cache].hasPH) { MTFCache[cache].hasPH=true;MTFCache[cache].ph=r[p].high;MTFCache[cache].phTime=r[p].time; }
      if(pl && !MTFCache[cache].hasPL) { MTFCache[cache].hasPL=true;MTFCache[cache].pl=r[p].low;MTFCache[cache].plTime=r[p].time; }
      if(!InpMTFZones || (cache>=44 && !LiveSDOn)) continue;
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
      MTFCache[cache].origin[n]=r[p].time;MTFCache[cache].side[n]=pl?1:-1;MTFCache[cache].count++;
   }
   MTFCache[cache].lastClosed=last;MTFCache[cache].ready=true;
   MTFSuccessEpoch[cache]=MTFQueryEpoch;MTFSuccessCutoff[cache]=cutoff;
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
bool UseRealWindow(const int first,const int last,const long &volume[])
{
   if(!InpUseRealVolume) return false;
   if(MetricCacheReady && first>=0 && last>=first && last<MetricCacheCount)
      return CachedRealMissing[last]-(first>0?CachedRealMissing[first-1]:0)==0;
   for(int k=first;k<=last;k++) if(volume[k]<=0) return false;
   return true;
}
struct NewSweepCandidate
{
   bool active;
   int bar,side,route,protectedBar;
   double level,extreme,bodyEdge,atr,protectedPrice,keyLow,keyHigh;
   int keyType;string keyLabel;
   bool fading,absorption;
};
struct NewEffortEvent
{
   int bar,origin,side,state,source; // 0=chờ,1=đã chạm giả định,2=hủy,3=hết hạn,4=không rõ thứ tự,6=chạm rồi vô hiệu
   datetime stamp,knownStamp;
   double zoneLow,zoneHigh,entry,stop,atr;
   bool invalidated;
   string evidence,reading,name,monitor;
};
NewSweepCandidate NewCandidates[2],ExhaustCandidates[2],LTrendPending[2];
int LTrendQueuedAt[2];bool LTrendWasExhaustion[2];string LTrendWhy[2];
NewEffortEvent NewEvents[];
int NewEventCount=0,NewProcessed=-1,NewActive[2];
struct LContinuationState
{
   int phase,baseBar,lastBase,peakBar,pullStart,extremeBar,lastOpposite,qualifiedAt;
   double protectedPrice,baseClose,peakClose,extreme,worstClose,atr,releaseLevel;
};
LContinuationState LContinuation[2];
NewSweepCandidate LRangeCandidates[2];
int LRangeStart[2],LRangeReferenceBar[2];
string LGeneratorWhy[7][2];
NewSweepCandidate SellTopCandidate;int SellTopStarted=-1;
struct LTurnState
{
   int phase,anchor,lastAnchor,broken,known,peakBar,pullStart,origin,lastOpposite,qualified;
   double level,guard,atr,peak,extreme;
};
LTurnState LTurn[2];
void ResetLTurns()
{
   for(int k=0;k<2;k++) { LTurn[k].phase=0;LTurn[k].lastAnchor=-1;LTurn[k].qualified=-1; }
}

struct LKnownLocation
{
   bool active,qualified,major;int origin,born,side,kind,breaks;
   double lo,hi,atr;string label;
};
LKnownLocation LLocations[256];int LLocationCursor=0;
NewSweepCandidate LLocationPending[2];
int LLocationStarted[2];
bool LCollecting=false,LProposalReady[2],LProposalExhaustion[2],LProposalRetry[2];
NewSweepCandidate LProposal[2];double LProposalScore[2];

void ResetNewEffortState()
{
   NewProcessed=-1;NewEventCount=0;ArrayFree(NewEvents);
   ResetPro();ResetLGenerators();ResetLTurns();ResetLLocations();SellTopCandidate.active=false;SellTopStarted=-1;
   for(int k=0;k<2;k++)
   {
      NewCandidates[k].active=false;NewCandidates[k].route=0;ExhaustCandidates[k].active=false;LTrendPending[k].active=false;LTrendQueuedAt[k]=-1;LTrendWhy[k]="";NewActive[k]=-1;
   }
}
string NewEventStatus(const NewEffortEvent &e)
{
   if(e.state==1) return "L: giá đã chạm mức chờ; chưa xác minh khớp thực tế";
   if(e.state==2) return "L: đã hủy — vô hiệu hoặc giá chạy quá xa";
   if(e.state==3) return "L: hết hạn, không tính là có entry";
   if(e.state==4) return "L: chạm và xuyên SL cùng nến — thứ tự chưa rõ";
   if(e.state==6) return "L: đã chạm trước đó, sau đó xuyên mốc bảo vệ";
   return "L: đang chờ hồi, chưa có entry";
}
string NewEventTip(const NewEffortEvent &e)
{
   return (e.side>0?"BUY LIMIT":"SELL LIMIT")+" — KHÔNG ĐUỔI GIÁ\n"+e.evidence+"; "+e.reading+
      "\nVùng "+DoubleToString(e.zoneLow,_Digits)+"–"+DoubleToString(e.zoneHigh,_Digits)+
      "; mức chờ "+DoubleToString(e.entry,_Digits)+"; vô hiệu "+DoubleToString(e.stop,_Digits)+
      "\n"+NewEventStatus(e)+(e.monitor==""?"":"; "+e.monitor)+"; biết tại đóng nến "+TimeToString(e.knownStamp);
}
void RenderNewEvent(const int id)
{
   if(InpForecastWorker)return;
   if(NewRenderDeferred || !InpEnabled || !InpShowEntryContext || Prefix=="" || id<0 || id>=NewEventCount) return;
   if(!InpShowHistory && id<NewEventCount-5) return;
   NewEffortEvent e=NewEvents[id];
   if(ObjectFind(0,e.name)>=0 && ObjectGetInteger(0,e.name,OBJPROP_TYPE)!=OBJ_TEXT) ObjectDelete(0,e.name);
   double price=e.side>0?e.zoneLow-e.atr*0.25:e.zoneHigh+e.atr*0.25;
   if(ObjectFind(0,e.name)<0 && !ObjectCreate(0,e.name,OBJ_TEXT,0,e.stamp,price)) return;
   ObjectMove(0,e.name,0,e.stamp,price);ObjectSetString(0,e.name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,e.name,OBJPROP_ANCHOR,e.side>0?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,e.name,OBJPROP_FONTSIZE,7);ObjectSetString(0,e.name,OBJPROP_TEXT,"L");
   ObjectSetInteger(0,e.name,OBJPROP_HIDDEN,true);ObjectSetInteger(0,e.name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,e.name,OBJPROP_COLOR,e.state==0?clrAqua:e.state==1?clrGold:clrSilver);
   ObjectSetString(0,e.name,OBJPROP_TOOLTIP,NewEventTip(e));
}
void NotifyNewEvent(const string message,const bool notify)
{
   if(InpForecastWorker || !notify || !InpNewAlerts) return;
   Alert(message);
   if(InpEnablePush) SendNotification(message);
}
void StepNewLimit(const int slot,const int i,const double &high[],const double &low[],const bool notify)
{
   int id=NewActive[slot];
   if(id<0 || id>=NewEventCount) return;
   NewEffortEvent e=NewEvents[id];
   if(e.state!=0 && e.state!=1) { NewActive[slot]=-1;return; }
   if(i<=e.bar) return; // Không giả định khớp trước lúc setup được công bố.
   int old=e.state;
   bool invalid=e.side>0?low[i]<=e.stop:high[i]>=e.stop;
   bool touched=e.side>0?low[i]<=e.entry:high[i]>=e.entry;
   if(invalid) e.invalidated=true;
   if(e.state==1)
   {
      if(invalid) { e.state=6;NewActive[slot]=-1; }
      else if(i-e.bar>InpNewLimitLife) NewActive[slot]=-1;
   }
   else if(i-e.bar>InpNewLimitLife) { e.state=3;NewActive[slot]=-1; }
   else if(invalid) { e.state=touched?4:2;NewActive[slot]=-1; }
   else if(touched) e.state=1;
   else if(e.side>0?high[i]-e.entry>InpNewCancelRunATR*e.atr:e.entry-low[i]>InpNewCancelRunATR*e.atr)
   { e.state=2;NewActive[slot]=-1; }
   if(e.state!=old)
   {
      NewEvents[id]=e;RenderNewEvent(id);
      NotifyNewEvent(_Symbol+" "+(e.side>0?"BUY ":"SELL ")+NewEventStatus(e),notify);
   }
}
string LTrendSummary()
{
   if(!InpLRespectFlow) return "";
   string text="";
   for(int k=0;k<2;k++) if(LTrendPending[k].active)
      text+=(text==""?"":"; ")+(k==0?"Buy L chờ: ":"Sell L chờ: ")+LTrendWhy[k];
   if(InpLDiagnostics)
      for(int r=0;r<7;r++) for(int k=0;k<2;k++)
         text+="; "+(k==0?"Buy ":"Sell ")+LRouteName(r)+": "+LGeneratorWhy[r][k];
   return text;
}
struct LStructureReading
{
   int trend,breakDir,h1,h2,l1,l2;
   double upper,lower,breakLevel;
   bool ranging,atEdge,failedBreak,priorSwingTest;
   string description;
};
void ReadLStructure(const int i,const NewSweepCandidate &c,const double &high[],const double &low[],
                    const double &close[],LStructureReading &r)
{
   r.trend=0;r.breakDir=0;r.h1=r.h2=r.l1=r.l2=-1;r.upper=0;r.lower=0;r.breakLevel=0;
   r.ranging=false;r.atEdge=false;r.failedBreak=false;r.priorSwingTest=false;r.description="chưa đủ đỉnh/đáy xác nhận";
   int p=c.bar,strength=InpContextSwingStrength,known=p-1;
   double tolerance=InpLSwingToleranceATR*c.atr;
   for(int j=known-strength;j>=MathMax(strength,known-InpReaderPivotLookback);j--)
   {
      bool ph=true,pl=true;
      for(int k=1;k<=strength;k++)
      { if(high[j]<=high[j-k] || high[j]<high[j+k]) ph=false;if(low[j]>=low[j-k] || low[j]>low[j+k]) pl=false; }
      if(ph==pl) continue;
      if(ph) { if(r.h1<0) r.h1=j;else if(r.h2<0) r.h2=j; }
      if(pl) { if(r.l1<0) r.l1=j;else if(r.l2<0) r.l2=j; }
      if(r.h2>=0 && r.l2>=0) break;
   }
   if(r.h2>=0 && r.l2>=0)
   {
      bool hh=high[r.h1]>high[r.h2]+tolerance,lh=high[r.h1]<high[r.h2]-tolerance;
      bool hl=low[r.l1]>low[r.l2]+tolerance,ll=low[r.l1]<low[r.l2]-tolerance;
      if(hh && hl) r.trend=1;else if(lh && ll) r.trend=-1;
      r.description=(hh?"HH":lh?"LH":"đỉnh ngang")+"/"+(hl?"HL":ll?"LL":"đáy ngang");
   }
   else if(r.h1>=0 && r.l1>=0) r.description="một cặp đỉnh/đáy; nền chưa rõ";
   if(r.l1>=0 && c.side>0)
   {
      double delta=c.extreme-low[r.l1];
      r.description+="; L tại "+(delta>tolerance?"HL":delta<-tolerance?"LL":"đáy ngang")+" so đáy trước";
      r.priorSwingTest=MathAbs(delta)<=0.5*c.atr || (delta<0 && close[i]>low[r.l1]+tolerance);
      r.failedBreak=low[p]<low[r.l1]-tolerance && close[i]>low[r.l1]+tolerance;
   }
   if(r.h1>=0 && c.side<0)
   {
      double delta=c.extreme-high[r.h1];
      r.description+="; L tại "+(delta>tolerance?"HH":delta<-tolerance?"LH":"đỉnh ngang")+" so đỉnh trước";
      r.priorSwingTest=MathAbs(delta)<=0.5*c.atr || (delta>0 && close[i]<high[r.h1]-tolerance);
      r.failedBreak=high[p]>high[r.h1]+tolerance && close[i]<high[r.h1]-tolerance;
   }
   int lastUp=-1,lastDown=-1;
   if(r.h1>=0)
      for(int j=MathMax(r.h1+strength+1,p-12);j<=i;j++)
         if(close[j]>high[r.h1]+tolerance && close[j-1]<=high[r.h1]+tolerance) lastUp=j;
   if(r.l1>=0)
      for(int j=MathMax(r.l1+strength+1,p-12);j<=i;j++)
         if(close[j]<low[r.l1]-tolerance && close[j-1]>=low[r.l1]-tolerance) lastDown=j;
   if(lastUp>lastDown && r.h1>=0 && close[i]>high[r.h1]+tolerance)
   { r.breakDir=1;r.breakLevel=high[r.h1]; }
   else if(lastDown>lastUp && r.l1>=0 && close[i]<low[r.l1]-tolerance)
   { r.breakDir=-1;r.breakLevel=low[r.l1]; }
   int start=MathMax(20,p-12);double path=0,overlap=0;int pairs=0;
   r.upper=high[start];r.lower=low[start];
   for(int j=start;j<p;j++)
   {
      r.upper=MathMax(r.upper,high[j]);r.lower=MathMin(r.lower,low[j]);
      if(j>start)
      {
         path+=MathAbs(close[j]-close[j-1]);double range=MathMin(high[j]-low[j],high[j-1]-low[j-1]);
         if(range>0) { overlap+=MathMax(0.0,MathMin(high[j],high[j-1])-MathMax(low[j],low[j-1]))/range;pairs++; }
      }
   }
   double efficiency=path>0?MathAbs(close[p-1]-close[start])/path:0;
   r.ranging=p-start>=8 && r.upper-r.lower>=0.3*c.atr && efficiency<0.30 && pairs>0 && overlap/pairs>=0.50;
   double band=r.upper-r.lower;
   if(band>0) r.atEdge=c.side>0?c.extreme<=r.lower+InpLRangeEdgeFraction*band:c.extreme>=r.upper-InpLRangeEdgeFraction*band;
   if(r.ranging) r.description+="; đi ngang";
   if(r.breakDir!=0) r.description+=r.breakDir>0?"; đang giữ phía phá đỉnh":"; đang giữ phía phá đáy";
}
void ResetLGenerators()
{
   for(int k=0;k<2;k++)
   {
      LContinuation[k].phase=0;LContinuation[k].baseBar=-1;LContinuation[k].lastBase=-1;
      LRangeCandidates[k].active=false;LRangeStart[k]=-1;LRangeReferenceBar[k]=-1;
      for(int r=0;r<7;r++) LGeneratorWhy[r][k]="chưa có ứng viên";
   }
}
string LRouteName(const int route)
{
   return route==6?"Sell đỉnh mất hiệu quả":route==5?"phá cấu trúc + hồi đầu":route==4?"phản ứng S-D/key level":route==1?"HL/LH thuận nhịp":route==2?"test mép biên":route==3?"kiệt sức/đảo lực":"quét cực trị";
}
void LTrace(const int slot,const int i,const int route,const string reason,const datetime &time[])
{
   if(route<0 || route>6) return;
   LGeneratorWhy[route][slot]=reason;
   if(InpLDiagnostics && (QualityChartCount<=0 || i>=QualityChartCount-1-InpLDiagnosticsBars)) Print("PRO L TRACE | ",TimeToString(time[i]+PeriodSeconds(_Period))," | ",slot==0?"BUY":"SELL",
                            " | ",LRouteName(route)," | ",reason);
}
bool LAlreadyKnown(const int side,const int origin)
{
   for(int n=NewEventCount-1;n>=MathMax(0,NewEventCount-128);n--)
      if(NewEvents[n].side==side && NewEvents[n].origin==origin) return true;
   return false;
}
bool LKnownThisBar(const int side,const int i)
{
   for(int n=NewEventCount-1;n>=0 && NewEvents[n].bar==i;n--)
      if(NewEvents[n].side==side) return true;
   return false;
}
void StepLTurnContext(const int i,const datetime &time[],const double &open[],const double &high[],
                      const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(!InpLStructureTurn || i<34) return;
   int strength=InpContextSwingStrength,ph=-1,pl=-1;
   for(int p=i-strength-2;p>=MathMax(26,i-100);p--)
   {
      bool h=true,l=true;
      for(int k=1;k<=strength;k++)
      { if(high[p]<=high[p-k] || high[p]<high[p+k]) h=false;if(low[p]>=low[p-k] || low[p]>low[p+k]) l=false; }
      if(h && ph<0) ph=p;if(l && pl<0) pl=p;if(ph>=0 && pl>=0) break;
   }
   if(ph<0 || pl<0) return;
   double atr=ContextATR(i,high,low,close);if(atr<=0) return;
   for(int slot=0;slot<2;slot++)
   {
      int side=slot==0?1:-1,anchor=side>0?pl:ph,broken=side>0?ph:pl;
      LTurnState a=LTurn[slot];
      if(a.phase==1 || a.phase==2) continue;
      if(anchor<=broken || anchor==a.lastAnchor) continue;
      double level=side>0?high[broken]:low[broken];
      bool crossed=side*(close[i-2]-level)<=0.05*atr && side*(close[i-1]-level)>0.05*atr && side*(close[i]-level)>0.05*atr;
      if(!crossed) continue;
      bool real=UseRealWindow(anchor-20,i,volume),known=true;double path=0;int advances=0;
      for(int j=anchor+1;j<=i;j++)
      { double d=side*(close[j]-close[j-1]);path+=MathAbs(d);if(d>0) advances++;if(QualityRelativeVolume(j,real,ticks,volume)<=0) known=false; }
      double net=side*(close[i]-close[anchor]);
      if(!known || net<InpTurnMinMoveATR*atr || path<=0 || net/path<0.55 || advances<2) continue;
      a.phase=1;a.anchor=anchor;a.lastAnchor=anchor;a.broken=broken;a.known=i;a.level=level;
      a.guard=side>0?low[anchor]:high[anchor];a.atr=atr;a.peak=close[i];a.peakBar=i;
      a.pullStart=-1;a.origin=-1;a.lastOpposite=-1;a.qualified=-1;LTurn[slot]=a;
      if(WyControlSide==-side && WyControlBreak<i)
      {
         int retired=WyControlSide>0?0:1;
         if(ProWy[retired].stage>=6 && ProWy[retired].breakBar==WyControlBreak)
         { ProWy[retired].stage=0;ProWy[retired].last=i;ProWy[retired].eventName="SOS/SOW thất bại theo cấu trúc mới";ProWy[retired].status="Vô hiệu"; }
         WyControlSide=0;WyControlFailures=0;WyControlReading="chuỗi cũ bị phủ nhận: hai Close phá cấu trúc + nhịp đối hướng hiệu quả"; }
      if(ImpulseSide==-side && ImpulseKnown<i)
      {
         ImpulseReleased[ImpulseSide>0?0:1]=i;ImpulseSide=0;ImpulseBreaks=0;
         ImpulseReading="nhịp cũ đã bị phá cấu trúc; theo dõi hồi đầu của nhịp mới";
      }
      LTrace(slot,i,5,"hai Close phá mốc đã biết, có nhịp đẩy; chờ lần hồi đầu",time);
   }
}
bool LTurnProof(const int i,const NewSweepCandidate &c,string &why)
{
   int slot=c.side>0?0:1;LTurnState a=LTurn[slot];
   bool okay=InpLStructureTurn && a.qualified==i && c.bar==a.origin && c.protectedBar==a.anchor &&
      c.side*(c.extreme-a.guard)>=InpLSwingToleranceATR*c.atr;
   why=okay?"phá cấu trúc đã biết; hồi đầu giảm hiệu quả; Close từ chối/giữ HL-LH":"chưa đủ chu kỳ phá cấu trúc và lần hồi đầu";
   return okay;
}
void StepLTurnEntry(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                    const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpLStructureTurn) return;
   LTurnState a=LTurn[slot];if(a.phase!=1 && a.phase!=2) return;
   int side=slot==0?1:-1;double extreme=side>0?low[i]:high[i];
   if(side*(extreme-a.guard)<-InpLSwingToleranceATR*a.atr || i-a.known>InpLMaxWaveBars)
   { a.phase=3;LTurn[slot]=a;LTrace(slot,i,5,"nhịp mới mất gốc bảo vệ hoặc hết hạn",time);return; }
   double move=side*(close[i]-close[i-1]);
   if(a.phase==1)
   {
      if(i>a.peakBar && move<0)
      { a.phase=2;a.pullStart=i;a.origin=i;a.extreme=extreme;a.lastOpposite=side*(close[i]-open[i])<0?i:-1; }
      else if(side*(close[i]-a.peak)>0) { a.peak=close[i];a.peakBar=i; }
      LTurn[slot]=a;return;
   }
   if(side*(extreme-a.extreme)<0) { a.extreme=extreme;a.origin=i; }
   double push=side*(a.peak-close[a.anchor]),depth=side*(a.peak-a.extreme);
   if(push<=0 || depth>push*0.75 || i-a.pullStart>InpTurnWaitBars)
   { a.phase=3;LTurn[slot]=a;LTrace(slot,i,5,"hồi quá sâu hoặc lần hồi đầu hết cửa sổ",time);return; }
   bool real=UseRealWindow(a.anchor-20,i,volume),known=true;double vp=0,vr=0,progress=0;int np=0,nr=0;
   for(int j=a.anchor+1;j<=a.peakBar;j++)
   { double rv=QualityRelativeVolume(j,real,ticks,volume);if(rv<=0) known=false;vp+=rv;np++; }
   for(int j=a.pullStart;j<i;j++)
   { double rv=QualityRelativeVolume(j,real,ticks,volume);if(rv<=0) known=false;vr+=rv;nr++;progress+=MathMax(0.0,-side*(close[j]-close[j-1])); }
   double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0;
   bool effort=known && np>0 && nr>0 && (vr/nr<=vp/np*1.05 || (vr/nr>=vp/np && progress/nr<=push/np*0.60));
   bool holds=side*(a.extreme-a.guard)>=InpLSwingToleranceATR*a.atr;
   bool formed=i-a.pullStart>=2 && depth>=0.25*a.atr && depth>=push*0.15;
   bool response=a.lastOpposite>=a.pullStart && side*(close[i]-open[a.lastOpposite])>0.02*a.atr &&
      move>=0.20*a.atr && side*(close[i]-open[i])>0 && loc>=0.65;
   if(formed && holds && effort && response)
   {
      a.qualified=i;LTurn[slot]=a;
      NewSweepCandidate c;c.active=true;c.bar=a.origin;c.side=side;c.route=5;c.atr=a.atr;c.extreme=a.extreme;
      c.level=open[a.lastOpposite];c.bodyEdge=side>0?MathMin(open[a.origin],close[a.origin]):MathMax(open[a.origin],close[a.origin]);
      c.protectedBar=a.anchor;c.protectedPrice=a.guard;c.fading=true;c.absorption=false;
      NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
      bool accepted=CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
      NewCandidates[slot]=saved;
      if(accepted || side*(close[i]-a.peak)>0) a.phase=3;
      LTurn[slot]=a;return; // Preserve the exact common-gate reason when publication is rejected.
   }
   if(side*(close[i]-open[i])<0) a.lastOpposite=i;
   if(side*(close[i]-a.peak)>0) a.phase=3;
   LTurn[slot]=a;
   LTrace(slot,i,5,!formed?"hồi đầu chưa đủ rõ":!effort?"hồi còn hiệu quả, chờ tiếp":"chờ Close phản ứng; xem thêm khóa PRO/volume/chu kỳ",time);
}

void StepContinuationL(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                       const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpLContinuation || i<32) return;
   int side=slot==0?1:-1;double atr=ContextATR(i,high,low,close);if(atr<=0) return;
   NewSweepCandidate probe;probe.bar=i;probe.side=side;probe.atr=atr;probe.extreme=side>0?low[i]:high[i];
   LStructureReading r;ReadLStructure(i,probe,high,low,close,r);
   LContinuationState a=LContinuation[slot];
   if(a.phase==0 || a.phase==3)
   {
      int base=side>0?r.l1:r.h1;
      if(base<20 || base==a.lastBase || r.ranging || r.breakDir==-side || (r.trend!=side && r.breakDir!=side))
      { LTrace(slot,i,1,"chưa có nhịp đẩy và đáy/đỉnh bảo vệ thuận cấu trúc",time);return; }
      a.phase=1;a.baseBar=base;a.lastBase=base;a.protectedPrice=side>0?low[base]:high[base];
      a.baseClose=close[base];a.releaseLevel=side>0?(r.h1>=0?high[r.h1]:close[base]):(r.l1>=0?low[r.l1]:close[base]);a.atr=atr;a.peakClose=close[base];a.peakBar=base;
      for(int j=base+1;j<i;j++) if(side*(close[j]-a.peakClose)>0) { a.peakClose=close[j];a.peakBar=j; }
      a.pullStart=-1;a.extremeBar=-1;a.lastOpposite=-1;a.qualifiedAt=-1;
   }
   double extreme=side>0?low[i]:high[i];
   if(side*(extreme-a.protectedPrice)<-InpLSwingToleranceATR*a.atr || i-a.baseBar>InpLMaxWaveBars)
   { a.phase=3;LContinuation[slot]=a;LTrace(slot,i,1,"mốc bảo vệ bị phá hoặc nhịp hết hạn",time);return; }
   bool real=UseRealWindow(a.baseBar-20,i,volume);double rv=QualityRelativeVolume(i,real,ticks,volume);
   double move=side*(close[i]-close[i-1]);
   if(a.phase==1)
   {
      double departure=side*(a.peakClose-a.baseClose),path=0;int advances=0;
      for(int j=a.baseBar+1;j<=a.peakBar;j++)
      { double delta=side*(close[j]-close[j-1]);path+=MathAbs(delta);if(delta>0) advances++; }
      bool released=departure>=InpLContinuationPushATR*a.atr && path>0 && departure/path>=0.5 && advances>=2 &&
                    (!InpLContinuationRequireBreak || side*(a.peakClose-a.releaseLevel)>=0.05*a.atr);
      if(released && i>a.peakBar && move<0)
      {
         a.phase=2;a.pullStart=i;a.extremeBar=i;a.extreme=extreme;a.worstClose=close[i];a.qualifiedAt=-1;
         a.lastOpposite=side*(close[i]-open[i])<0?i:-1;
         LTrace(slot,i,1,"bắt đầu hồi đầu, chờ test HL/LH và phản ứng",time);
      }
      else
      {
         if(side*(close[i]-a.peakClose)>0) { a.peakClose=close[i];a.peakBar=i; }
         LTrace(slot,i,1,released?"nhịp đẩy có Close thực, chưa có hồi":"Close nhịp đẩy chưa đủ tiến triển",time);
      }
      LContinuation[slot]=a;return;
   }
   if(side*(extreme-a.extreme)<0) { a.extreme=extreme;a.extremeBar=i;a.qualifiedAt=-1; }
   if(side*(close[i]-a.worstClose)<0) a.worstClose=close[i];
   double departure=side*(a.peakClose-a.baseClose),depth=side*(a.peakClose-a.worstClose);
   double fraction=departure>0?depth/departure:1.0;
   if(fraction>InpLContinuationMaxRetrace || i-a.pullStart>InpLMaxPullbackBars+InpNewReactionBars)
   { a.phase=3;LContinuation[slot]=a;LTrace(slot,i,1,"hồi quá sâu hoặc hết lần hồi đầu",time);return; }
   double outVol=0,backVol=0,backProgress=0,outProgress=0;int outBars=0,backBars=0,adverse=0;bool known=rv>0;
   for(int j=a.baseBar+1;j<=a.peakBar;j++)
   {
      double v=QualityRelativeVolume(j,real,ticks,volume);if(v<=0) known=false;
      outVol+=v;outBars++;outProgress+=MathMax(0.0,side*(close[j]-close[j-1]));
   }
   for(int j=a.pullStart;j<i;j++)
   {
      double v=QualityRelativeVolume(j,real,ticks,volume),delta=side*(close[j]-close[j-1]);if(v<=0) known=false;
      backVol+=v;backBars++;backProgress+=MathMax(0.0,-delta);if(delta<0) adverse++;
   }
   double meanOut=outBars>0?outVol/outBars:0,meanBack=backBars>0?backVol/backBars:0;
   bool testEffort=known && meanOut>0 && meanBack>0 &&
      (meanBack<=meanOut*1.10 || (meanBack>=meanOut && backProgress/MathMax(1,backBars)<=outProgress/MathMax(1,outBars)*0.65));
   bool holds=side*(a.extreme-a.protectedPrice)>=InpLSwingToleranceATR*a.atr;
   bool formed=depth>=InpLMinPullbackATR*a.atr && fraction>=0.15 && backBars>=InpLContinuationPullBars && adverse>=1;
   if(formed && a.qualifiedAt<0) a.qualifiedAt=i;
   double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0.5;
   double trigger=a.lastOpposite>=0?open[a.lastOpposite]:close[i];
   bool reaction=a.lastOpposite>=0 && side*(close[i]-trigger)>=0.05*a.atr && side*(close[i]-open[i])>0 && move>=0.20*a.atr && loc>=0.65;
   bool created=false;
   if(holds && formed && testEffort && reaction && !LAlreadyKnown(side,a.extremeBar) && !LKnownThisBar(side,i))
   {
      NewSweepCandidate c;c.active=true;c.bar=a.extremeBar;c.side=side;c.atr=a.atr;c.extreme=a.extreme;c.level=trigger;
      c.bodyEdge=side>0?MathMin(open[c.bar],close[c.bar]):MathMax(open[c.bar],close[c.bar]);
      c.fading=meanBack<meanOut;c.absorption=!c.fading;c.route=1;c.protectedPrice=a.protectedPrice;c.protectedBar=a.baseBar;
      NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
      created=CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
      NewCandidates[slot]=saved;
   }
   if(created || (LKnownThisBar(side,i) && formed))
   { a.phase=3;LTrace(slot,i,1,"đã xác nhận L tại test HL/LH đầu",time); }
   else if(side*(close[i]-a.peakClose)>0)
   { a.phase=3;LTrace(slot,i,1,"giá đã chạy lại; bỏ cơ hội đầu, không đuổi",time); }
   else
   {
      if(side*(close[i]-open[i])<0) a.lastOpposite=i;
      LTrace(slot,i,1,!holds?"chưa giữ HL/LH":!formed?"hồi chưa đủ rõ, chờ tiếp":!testEffort?"volume hồi còn đẩy giá hiệu quả, chờ test":"chờ Close xác nhận kết thúc hồi",time);
      if(a.qualifiedAt>=0 && i-a.qualifiedAt>=InpNewReactionBars)
      { a.phase=3;LTrace(slot,i,1,"hồi đã đủ nhưng phản ứng đầu chưa đạt; không dùng lần test sau",time); }
   }
   LContinuation[slot]=a;
}
void StepRangeTestL(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                  const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpLRangeTest || i<32) return;
   int side=slot==0?1:-1;double atr=ContextATR(i,high,low,close);if(atr<=0) return;
   if(LKnownThisBar(side,i)) { LRangeCandidates[slot].active=false;return; }
   if(LRangeCandidates[slot].active)
   {
      NewSweepCandidate c=LRangeCandidates[slot];
      bool invalid=side>0?low[i]<c.extreme-0.05*c.atr:high[i]>c.extreme+0.05*c.atr;
      if(invalid || i-LRangeStart[slot]>InpNewReactionBars+InpLFlowWaitBars)
      { LRangeCandidates[slot].active=false;LTrace(slot,i,2,"test mép biên vô hiệu/hết hạn",time); }
      else
      {
         bool real=UseRealWindow(MathMin(c.bar-20,LRangeReferenceBar[slot]-20),i,volume);
         double rv=QualityRelativeVolume(i-1,real,ticks,volume);
         double referenceRV=QualityRelativeVolume(LRangeReferenceBar[slot],real,ticks,volume);
         double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0.5;
         bool held=i>=c.bar+2 && side*(close[i]-close[i-1])>0 && side*(close[i-1]-close[i-2])>0;
         bool response=side*(close[i]-close[c.bar])>=InpLReversalCloseATR*c.atr && side*(close[i]-c.level)>=0.05*c.atr && loc>=0.65;
         bool effort=rv>0 && referenceRV>0 && rv<=referenceRV*1.10;
         if(held && response && effort && !LAlreadyKnown(side,c.bar))
         {
            NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
            bool created=CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
            NewCandidates[slot]=saved;
            if(created) { LRangeCandidates[slot].active=false;LTrace(slot,i,2,"đã xác nhận test giữ mép biên",time);return; }
         }
         LTrace(slot,i,2,"mép biên đang test, chờ hai Close giữ phản ứng và effort test giảm",time);return;
      }
   }
   NewSweepCandidate probe;probe.bar=i;probe.side=side;probe.atr=atr;probe.extreme=side>0?low[i]:high[i];
   LStructureReading r;ReadLStructure(i,probe,high,low,close,r);
   if(!r.ranging || !r.atEdge || r.breakDir==-side)
   { LTrace(slot,i,2,!r.ranging?"chưa có biên đi ngang rõ":"ở giữa biên hoặc phá biên chưa thất bại",time);return; }
   double edge=side>0?r.lower:r.upper;int touches=0,lastTouch=-1;bool away=true;
   for(int j=MathMax(20,i-24);j<i;j++)
   {
      double x=side>0?low[j]:high[j];bool near=MathAbs(x-edge)<=0.25*atr;
      if(near && away) { touches++;lastTouch=j;away=false; }
      if(side*(x-edge)>0.5*atr) away=true;
   }
   if(touches<2 || lastTouch<20)
   { LTrace(slot,i,2,"mép biên chưa có hai lần chạm tách biệt, chưa xem là vùng test",time);return; }
   bool real=UseRealWindow(MathMax(0,lastTouch-20),i,volume);
   double reference=QualityRelativeVolume(lastTouch,real,ticks,volume);if(reference<=0) return;
   NewSweepCandidate c;c.active=true;c.bar=i;c.side=side;c.atr=atr;c.extreme=probe.extreme;
   c.level=side>0?MathMax(open[i],close[i]):MathMin(open[i],close[i]);
   c.bodyEdge=side>0?MathMin(open[i],close[i]):MathMax(open[i],close[i]);
   c.fading=true;c.absorption=false;c.route=2;c.protectedPrice=edge;c.protectedBar=lastTouch;
   LRangeCandidates[slot]=c;LRangeStart[slot]=i;LRangeReferenceBar[slot]=lastTouch;
   LTrace(slot,i,2,"đã có biên và mép được test; chờ phản ứng giữ giá",time);
}

bool LFlowAllowed(const int i,const NewSweepCandidate &c,const double &open[],const double &high[],
                  const double &low[],const double &close[],const long &ticks[],const long &volume[],string &why)
{
   why="L: chưa bật đọc cấu trúc/lực";if(!InpLRespectFlow) return true;
   int p=c.bar,side=c.side;if(p<27 || p>i || c.atr<=0) { why="thiếu dữ liệu nền";return false; }
   LStructureReading r;ReadLStructure(i,c,high,low,close,r);
   double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0.5;
   double gain=side*(close[i]-(p<i?close[p]:open[p]));
   double trigger=side>0?MathMax(open[p-1],close[p-1]):MathMin(open[p-1],close[p-1]);
   for(int j=p;j>=p-3;j--) if(side*(close[j]-open[j])<0) { trigger=open[j];break; }
   bool localBreak=side*(close[i]-trigger)>=0.05*c.atr;
   bool response=loc>=0.65 && side*(close[i]-open[i])>0 && gain>=InpLReversalCloseATR*c.atr;
   bool decisive=(localBreak || (r.failedBreak && gain>=0.50*c.atr)) && response;
   bool holds=i>=p+2 && side*(close[i]-close[i-1])>0 && side*(close[i-1]-close[i-2])>0;
   if(r.breakDir==-side)
   { why=r.description+"; chờ phá biên thất bại/lấy lại mốc, chưa bắt ngược nhịp mới";return false; }
   if(r.ranging)
   {
      if(!r.atEdge) { why=r.description+"; ở giữa biên, chưa có đáy/đỉnh tại mép";return false; }
      bool sweptEdge=side>0?low[p]<r.lower-0.05*c.atr:high[p]>r.upper+0.05*c.atr;
      bool reclaimed=side>0?close[i]>r.lower+0.05*c.atr:close[i]<r.upper-0.05*c.atr;
      bool edgeTest=r.priorSwingTest && holds;
      if(response && ((sweptEdge && reclaimed && (decisive || holds)) || edgeTest))
      { why=r.description+"; mép biên đã có quét/test và Close giữ phản ứng";return true; }
      why=r.description+"; mép biên mới là ứng viên, chờ quét/test + phản ứng";return false;
   }
   double net=-side*(close[p-1]-close[p-7]),path=0;int incomingBars=0;
   for(int j=p-6;j<p;j++)
   { double move=-side*(close[j]-close[j-1]);path+=MathAbs(move);if(move>0) incomingBars++; }
   bool efficientFlow=net>=InpLFlowMoveATR*c.atr && path>0 && net/path>=InpLFlowEfficiency && incomingBars>=4;
   bool real=UseRealWindow(p-26,i,volume),known=true;double earlyMove=0,lateMove=0,earlyVol=0,lateVol=0;
   for(int j=p-5;j<=p;j++)
   {
      double move=MathMax(0.0,-side*(close[j]-close[j-1])),rv=QualityRelativeVolume(j,real,ticks,volume);
      if(rv<=0) known=false;
      if(j<p-2) { earlyMove+=move;earlyVol+=rv; } else { lateMove+=move;lateVol+=rv; }
   }
   bool fades=known && earlyMove>0 && lateMove<=earlyMove*0.75 && lateVol<=earlyVol*0.9;
   bool effortFails=known && earlyMove>0 && lateVol>=earlyVol && lateMove<=earlyMove*0.75;
   bool continuation=r.trend==side || r.breakDir==side;
   bool heldHigherLow=r.l1>=0 && side>0 && c.extreme>=low[r.l1]+InpLSwingToleranceATR*c.atr;
   bool heldLowerHigh=r.h1>=0 && side<0 && c.extreme<=high[r.h1]-InpLSwingToleranceATR*c.atr;
   if(continuation && (r.priorSwingTest || heldHigherLow || heldLowerHigh) &&
      response && (decisive || holds) && (!efficientFlow || r.failedBreak || fades || effortFails || holds))
   { why=r.description+"; hồi/test giữ cấu trúc, Close xác nhận thuận nhịp";return true; }
   bool stopEvidence=r.failedBreak || ((fades || effortFails) && r.priorSwingTest);
   if(stopEvidence && response && (decisive || holds))
   { why=r.description+"; nhịp cũ bị phủ nhận tại mốc trước, ứng viên đảo lực";return true; }
   if(r.h1<0 && r.l1<0 && net>=InpLFlowMoveATR*c.atr && (fades || effortFails) && holds && response)
   { why="chưa đủ pivot; nhịp đi vào mất hiệu quả và hai Close giữ phản ứng";return true; }
   why=r.description+(efficientFlow?"; nhịp còn hiệu quả, chờ dừng/phủ nhận":"; chưa đủ cấu trúc test hoặc đảo lực");
   return false;
}
void ResetLLocations()
{
   LLocationCursor=0;
   for(int n=0;n<256;n++) LLocations[n].active=false;
   LCollecting=false;
   for(int k=0;k<2;k++) { LLocationPending[k].active=false;LLocationStarted[k]=-1;LProposalReady[k]=false; }
}
void AddLLocation(const int origin,const int known,const int side,const int kind,const double lo,const double hi,
                  const double atr,const double closed,const string label)
{
   int n=-1;
   for(int z=0;z<256;z++) if(LLocations[z].active && LLocations[z].side==side && LLocations[z].kind==kind &&
      EntryBandDistance(LLocations[z].lo,LLocations[z].hi,lo,hi)<=0.15*atr)
   { n=z;break; }
   if(n>=0)
   {
      double mergedLo=MathMin(lo,LLocations[n].lo),mergedHi=MathMax(hi,LLocations[n].hi);
      if(mergedHi-mergedLo<=2*atr)
      {
         if(mergedLo!=LLocations[n].lo || mergedHi!=LLocations[n].hi) LLocations[n].born=known;
         LLocations[n].lo=mergedLo;LLocations[n].hi=mergedHi;
         return;
      }
   }
   n=LLocationCursor%256;LLocationCursor++;
   LLocations[n].major=false;
   for(int z=0;z<256;z++) if(z!=n && LLocations[z].active && LLocations[z].origin==origin && LLocations[z].major) LLocations[n].major=true;
   LLocations[n].active=true;LLocations[n].qualified=side*(closed-(side>0?hi:lo))>=InpLLocationDepartureATR*atr;
   LLocations[n].origin=origin;LLocations[n].born=known;LLocations[n].side=side;LLocations[n].kind=kind;
   LLocations[n].lo=lo;LLocations[n].hi=hi;LLocations[n].atr=atr;LLocations[n].breaks=0;LLocations[n].label=label;
}
void StepLLocations(const int i,const double &open[],const double &high[],const double &low[],const double &close[])
{
   if((!InpLLocationEntry || !InpLLocationChart) && !(InpShowLiveLevels && InpLiveChartLevels)) return;
   for(int n=0;n<256;n++) if(LLocations[n].active)
   {
      if(i-LLocations[n].origin>InpReaderPivotLookback) { LLocations[n].active=false;continue; }
      int side=LLocations[n].side;
      if(side*(close[i]-(side>0?LLocations[n].hi:LLocations[n].lo))>=2*LLocations[n].atr) LLocations[n].major=true;
      double tol=InpLSwingToleranceATR*LLocations[n].atr;
      double far=side>0?LLocations[n].lo:LLocations[n].hi;
      if(side*(close[i]-far)<-tol) LLocations[n].breaks++;else LLocations[n].breaks=0;
      if(LLocations[n].breaks>=2)
      {
         if(LLocations[n].kind==1 && LLocations[n].qualified)
         {
            LLocations[n].side=-side;LLocations[n].born=i;LLocations[n].breaks=0;
            LLocations[n].label="key chart đổi vai";
         }
         else LLocations[n].active=false;
      }
      else if(!LLocations[n].qualified && side*(close[i]-(side>0?LLocations[n].hi:LLocations[n].lo))>=InpLLocationDepartureATR*LLocations[n].atr)
      { LLocations[n].qualified=true;LLocations[n].born=i; }
   }
   int strength=InpContextSwingStrength,p=i-strength;if(p<20+strength) return;
   bool ph=true,pl=true;
   for(int k=1;k<=strength;k++)
   { if(high[p]<=high[p-k] || high[p]<high[p+k]) ph=false;if(low[p]>=low[p-k] || low[p]>low[p+k]) pl=false; }
   if(ph==pl) return;
   double atr=ContextATR(p,high,low,close);if(atr<=0) return;
   int side=pl?1:-1;double key=pl?low[p]:high[p];
   AddLLocation(p,i,side,1,key,key,atr,close[i],pl?"đáy trước chart":"đỉnh trước chart");
   bool major=true;
   for(int j=MathMax(0,p-20);j<p;j++) if(pl?low[j]<low[p]:high[j]>high[p]) major=false;
   double lo=pl?low[p]:MathMin(open[p],close[p]),hi=pl?MathMax(open[p],close[p]):high[p];
   if(hi-lo>=0.05*atr && hi-lo<=2*atr) AddLLocation(p,i,side,2,lo,hi,atr,close[i],pl?"cầu chart":"cung chart");
   if(major) for(int z=0;z<256;z++) if(LLocations[z].active && LLocations[z].side==side &&
      EntryBandDistance(LLocations[z].lo,LLocations[z].hi,key,key)<=0.15*atr) LLocations[z].major=true;
}
void ConsiderLLocation(const int side,const double lo,const double hi,const string label,const int kind,
                       const double extreme,const double previousClose,const double atr,
                       bool &found,double &best,NewSweepCandidate &candidate)
{
   double distance=EntryBandDistance(lo,hi,extreme,extreme),near=InpLLocationNearATR*atr;
   double proximal=side>0?hi:lo;
   if(distance>near || side*(previousClose-proximal)<-near) return;
   double score=distance/atr-(kind==2 || kind==4?0.02:0);
   if(found && score>=best) return;
   found=true;best=score;candidate.keyLow=lo;candidate.keyHigh=hi;candidate.keyLabel=label;candidate.keyType=kind;
}
bool FindLLocation(const int slot,const int i,const datetime &time[],const double &high[],const double &low[],
                   const double &close[],const double atr,NewSweepCandidate &candidate)
{
   int side=slot==0?1:-1;double extreme=side>0?low[i]:high[i],best=EMPTY_VALUE;bool found=false;
   if(InpLLocationChart) for(int n=0;n<256;n++)
      if(LLocations[n].active && LLocations[n].qualified && LLocations[n].side==side && LLocations[n].born<i && (!InpLLocationMajorOnly || LLocations[n].major))
         ConsiderLLocation(side,LLocations[n].lo,LLocations[n].hi,LLocations[n].label,LLocations[n].kind,
                           extreme,close[i-1],atr,found,best,candidate);
   if(InpLLocationMTF && (InpMTFZones || InpMTFKeyLevels))
   {
      datetime cutoff=time[i];
      for(int tf=0;tf<4;tf++) if(MTFEnabled(tf))
      {
         int cache=tf; // Same causal source data for both directions, share cache.
         if(!LoadMTFContext(cache,MTFPeriod(tf),cutoff)) continue;
         if(InpMTFZones) for(int z=0;z<MTFCache[cache].count;z++) if(MTFCache[cache].side[z]==side)
            ConsiderLLocation(side,MTFCache[cache].lo[z],MTFCache[cache].hi[z],(side>0?"cầu ":"cung ")+MTFName(tf),4,
                              extreme,close[i-1],atr,found,best,candidate);
         if(InpMTFKeyLevels)
         {
            if(MTFCache[cache].hasPH)
            {
               double key=MTFCache[cache].ph;
               bool role=side<0 || (close[i-1]>key+0.05*atr && close[i-2]>key+0.05*atr);
               if(role) ConsiderLLocation(side,key,key,"pivot H "+MTFName(tf)+(side>0?" đổi vai":""),3,extreme,close[i-1],atr,found,best,candidate);
            }
            if(MTFCache[cache].hasPL)
            {
               double key=MTFCache[cache].pl;
               bool role=side>0 || (close[i-1]<key-0.05*atr && close[i-2]<key-0.05*atr);
               if(role) ConsiderLLocation(side,key,key,"pivot L "+MTFName(tf)+(side<0?" đổi vai":""),3,extreme,close[i-1],atr,found,best,candidate);
            }
         }
      }
   }
   return found;
}
bool LLocationProof(const int i,const NewSweepCandidate &c,const double &open[],const double &high[],const double &low[],
                    const double &close[],const long &ticks[],const long &volume[],bool &lowVolumeTest,string &why)
{
   lowVolumeTest=false;int p=c.bar,side=c.side;
   if(c.route!=4 || c.keyLabel=="" || p<27 || p>i || c.atr<=0) { why="chưa có vùng đã biết trước";return false; }
   double proximal=side>0?c.keyHigh:c.keyLow;
   double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0.5;
   double gain=side*(close[i]-(p<i?close[p]:open[p]));
   double trigger=side>0?MathMax(open[p-1],close[p-1]):MathMin(open[p-1],close[p-1]);
   for(int j=p;j>=p-3;j--) if(side*(close[j]-open[j])<0) { trigger=open[j];break; }
   bool bodyRecovered=side*(close[i]-trigger)>=0.05*c.atr;
   bool holds=i>=p+2 && side*(close[i]-close[i-1])>0 && side*(close[i-1]-close[i-2])>0;
   bool reaction=side*(close[i]-proximal)>=0.05*c.atr && gain>=InpLReversalCloseATR*c.atr &&
      side*(close[i]-close[i-1])>=0.20*c.atr && side*(close[i]-open[i])>0 && loc>=0.65;
   if(!reaction || (!bodyRecovered && !holds))
   { why=c.keyLabel+": mới chạm, chờ Close phủ nhận lực đi vào và giữ phản ứng";return false; }
   bool real=UseRealWindow(p-26,i,volume),known=true;double early=0,late=0,ve=0,vl=0;
   for(int j=p-5;j<=p;j++)
   {
      double delta=MathMax(0.0,-side*(close[j]-close[j-1])),rv=QualityRelativeVolume(j,real,ticks,volume);
      if(rv<=0) known=false;
      if(j<p-2) { early+=delta;ve+=rv; } else { late+=delta;vl+=rv; }
   }
   bool fades=known && early>0 && late<early*0.75 && vl<=ve*0.90;
   bool stall=known && early>0 && late<early*0.75 && vl>=ve;
   double originRV=QualityRelativeVolume(p,real,ticks,volume),originRange=high[p]-low[p];
   double wick=side>0?MathMin(open[p],close[p])-low[p]:high[p]-MathMax(open[p],close[p]);
   bool climaxReject=originRV>=1.3 && ((originRange>0 && wick>=0.35*originRange) || (holds && bodyRecovered && gain>=0.8*c.atr));
   LStructureReading structure;ReadLStructure(i,c,high,low,close,structure);
   if((structure.breakDir==-side || structure.trend==-side) && !(holds && bodyRecovered && gain>=0.50*c.atr && (fades || stall || climaxReject)))
   { why=c.keyLabel+": đang ngược nhịp phá cấu trúc mới, chưa có dừng lực/test giữ";return false; }
   lowVolumeTest=InpLLocationLowVolTest && known && holds && bodyRecovered && gain>=0.50*c.atr && (fades || stall || climaxReject);
   why=structure.description+"; phản ứng tại "+c.keyLabel+" "+DoubleToString(c.keyLow,_Digits)+"–"+DoubleToString(c.keyHigh,_Digits);
   return true;
}
void StepLLocationEntry(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                        const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpLLocationEntry || i<32) return;
   int side=slot==0?1:-1;
   if(LKnownThisBar(side,i)) { LLocationPending[slot].active=false;return; }
   if(LLocationPending[slot].active)
   {
      NewSweepCandidate c=LLocationPending[slot];
      bool invalid=side>0?low[i]<c.extreme-0.05*c.atr:high[i]>c.extreme+0.05*c.atr;
      if(invalid && side*(close[i]-(side>0?c.keyLow:c.keyHigh))>=-InpLSwingToleranceATR*c.atr)
      {
         c.bar=i;c.extreme=side>0?low[i]:high[i];
         c.bodyEdge=side>0?MathMin(open[i],close[i]):MathMax(open[i],close[i]);
         LLocationPending[slot]=c;invalid=false;
      }
      if(invalid || i-LLocationStarted[slot]>InpLLocationWaitBars)
      { LLocationPending[slot].active=false;LTrace(slot,i,4,"vùng chạm bị xuyên cực trị hoặc hết theo dõi",time); }
      else
      {
         NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
         bool created=CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
         NewCandidates[slot]=saved;
         if(created) LLocationPending[slot].active=false;
         return;
      }
   }
   double atr=ContextATR(i,high,low,close);if(atr<=0) return;
   NewSweepCandidate c;c.active=true;c.bar=i;c.side=side;c.atr=atr;c.route=4;c.extreme=side>0?low[i]:high[i];
   if(!FindLLocation(slot,i,time,high,low,close,atr,c)) { LTrace(slot,i,4,"không chạm key/S-D đã tồn tại trước nến",time);return; }
   c.level=side>0?c.keyHigh:c.keyLow;c.protectedPrice=side>0?c.keyLow:c.keyHigh;c.protectedBar=-1;
   c.bodyEdge=side>0?MathMin(open[i],close[i]):MathMax(open[i],close[i]);c.fading=false;c.absorption=false;
   LLocationPending[slot]=c;LLocationStarted[slot]=i;
   NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
   bool created=CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
   NewCandidates[slot]=saved;
   if(created) LLocationPending[slot].active=false;
}
bool LSellLocationCounterProof(const int i,const NewSweepCandidate &c,const double &open[],const double &high[],
                              const double &low[],const double &close[],const long &ticks[],const long &volume[],string &why)
{
   why="";int p=c.bar;
   if(!InpLSellLocationCounter || !InpImpulseLocationReversal || c.side!=-1 || c.route!=4 ||
      c.keyLabel=="" || p<27 || i<p+2 || c.atr<=0) return false;
   if(!(close[i]<close[i-1] && close[i-1]<close[i-2]) || close[p]-close[i]<0.8*c.atr ||
      close[i]>=MathMin(low[p-1],low[p-2])-0.05*c.atr) return false;
   bool lowTest=false;string locationWhy="";
   if(!LLocationProof(i,c,open,high,low,close,ticks,volume,lowTest,locationWhy)) return false;
   bool real=UseRealWindow(p-26,i,volume),known=true;double early=0,late=0,ve=0,vl=0;
   for(int j=p-5;j<=p;j++)
   {
      double d=MathMax(0.0,close[j]-close[j-1]),rv=QualityRelativeVolume(j,real,ticks,volume);
      if(rv<=0) known=false;
      if(j<p-2) { early+=d;ve+=rv; } else { late+=d;vl+=rv; }
   }
   double range=high[p]-low[p],wick=high[p]-MathMax(open[p],close[p]);
   bool stopping=known && ((early>0 && late<early*0.75 && (vl<=ve*0.90 || vl>=ve)) ||
      (range>0 && QualityRelativeVolume(p,real,ticks,volume)>=1.3 && wick>=0.35*range));
   double confirmRV=QualityRelativeVolume(i,real,ticks,volume);
   if(!stopping || (InpLVolumeLock && confirmRV<InpLMinRelativeVolume)) return false;
   why="Sell cục bộ tại vùng: hai Close phá cụm đi vào, gain Close >=0.8 ATR và giá-volume dừng lực; "+locationWhy;
   return true;
}

bool SellTopProof(const int i,const NewSweepCandidate &c,const double &open[],const double &high[],
                  const double &low[],const double &close[],const long &ticks[],const long &volume[],string &why,bool &counterConfirmed)
{
   counterConfirmed=false;why="Sell đỉnh: chưa đủ dữ liệu";
   int p=c.bar;if(!InpLSellTop || c.side!=-1 || c.route!=6 || p<27 || p>i || c.atr<=0) return false;
   double incoming=close[p-1]-close[p-7],prior=high[p-1];
   for(int j=p-9;j<p;j++) prior=MathMax(prior,high[j]);
   if(incoming<InpSellTopPriorMoveATR*c.atr || high[p]<prior-0.10*c.atr)
   { why="Sell đỉnh: chưa có nhịp tăng và cực trị cục bộ rõ";return false; }
   bool real=UseRealWindow(p-26,i,volume),known=true;double early=0,late=0,ve=0,vl=0;
   for(int j=p-5;j<=p;j++)
   {
      double gain=MathMax(0.0,close[j]-close[j-1]),rv=QualityRelativeVolume(j,real,ticks,volume);
      if(rv<=0) known=false;
      if(j<p-2) { early+=gain;ve+=rv; } else { late+=gain;vl+=rv; }
   }
   double originRange=high[p]-low[p],wick=high[p]-MathMax(open[p],close[p]);
   double originRV=QualityRelativeVolume(p,real,ticks,volume);
   bool fading=known && early>0 && late<early*0.75 && vl<=ve*0.90;
   bool stall=known && early>0 && late<early*0.75 && vl>=ve;
   bool rejection=known && originRange>0 && originRV>=1.3 && wick>=0.35*originRange &&
      (close[p]<open[p] || (close[p]-low[p])/originRange<=0.45);
   if(!fading && !stall && !rejection) { why="Sell đỉnh: giá–volume còn hiệu quả, không bán chỉ vì có BC/râu";return false; }
   bool levelTest=c.keyLabel!="" || (c.protectedBar>=0 && MathAbs(high[p]-c.protectedPrice)<=0.5*c.atr);
   double damage=high[p]-close[i],range=high[i]-low[i];
   double loc=range>0?(close[i]-low[i])/range:1;
   bool response=close[i]<open[i] && loc<=0.35 && close[i]<c.level-0.05*c.atr && damage>=0.35*c.atr;
   bool holds=i>=p+1 && close[i]<close[i-1] && close[i-1]<close[i-2];
   if(!response || (!levelTest && !(holds && incoming>=1.5*c.atr)))
   { why="Sell đỉnh: chờ Close từ chối tại mốc hoặc hai Close giữ phản ứng";return false; }
   double incomingLow=MathMin(low[p-1],low[p-2]);
   counterConfirmed=holds && damage>=0.8*c.atr && close[i]<incomingLow-0.05*c.atr &&
      (levelTest || incoming>=1.5*c.atr);
   bool opposed=(InpImpulseControl && ImpulseSide>0) ||
      (InpProEnabled && InpProWyckoff && WyControlSide>0 && (InpWyDirectionalControl || InpProFilterWy));
   if(opposed && !counterConfirmed)
   { why="Sell đỉnh: ngược quyền tăng; chờ hai Close phá cụm đi vào và lực tăng bị phủ nhận";return false; }
   why=(levelTest?"Sell đỉnh tại S/D hoặc đỉnh trước":"Sell đỉnh sau nhịp tăng mất hiệu quả")+
      "; "+(fading?"giá và effort giảm":stall?"effort lớn nhưng Close tiến ít":"volume cao bị từ chối")+
      "; Close xác nhận"+(opposed?"; phản ứng cục bộ, chưa xác nhận đảo xu hướng lớn":"");
   return true;
}
void StepSellTopL(const int i,const datetime &time[],const double &open[],const double &high[],const double &low[],
                  const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpLSellTop || i<34) return;
   if(SellTopCandidate.active)
   {
      NewSweepCandidate c=SellTopCandidate;
      if(i-SellTopStarted>InpSellTopWaitBars) SellTopCandidate.active=false;
      else
      {
         if(high[i]>c.extreme)
         {
            if(c.keyLabel!="" && high[i]>c.keyHigh+0.5*c.atr)
            { c.keyLabel="";c.keyLow=0;c.keyHigh=0;FindLLocation(1,i,time,high,low,close,c.atr,c); }
            c.bar=i;c.extreme=high[i];c.bodyEdge=MathMax(open[i],close[i]);
            c.level=MathMin(open[i],close[i]); // Same origin-body trigger as Pine route 6.
            SellTopCandidate=c;
         }
         string reason="";bool counter=false;
         if(SellTopProof(i,c,open,high,low,close,ticks,volume,reason,counter))
         {
            NewSweepCandidate saved=NewCandidates[1];NewCandidates[1]=c;
            bool accepted=CreateNewEvent(1,i,time,open,high,low,close,ticks,volume,notify);
            NewCandidates[1]=saved;if(accepted) SellTopCandidate.active=false;
         }
         else LTrace(1,i,6,reason,time);
         return;
      }
   }
   double atr=ContextATR(i,high,low,close);if(atr<=0 || close[i-1]-close[i-7]<InpSellTopPriorMoveATR*atr) return;
   double prior=high[i-1];for(int j=i-9;j<i;j++) prior=MathMax(prior,high[j]);
   if(high[i]<prior-0.10*atr) return;
   NewSweepCandidate c;c.active=true;c.bar=i;c.side=-1;c.route=6;c.atr=atr;c.extreme=high[i];
   c.bodyEdge=MathMax(open[i],close[i]);c.level=MathMin(open[i],close[i]);
   c.keyLabel="";c.keyLow=0;c.keyHigh=0;c.keyType=0;c.protectedBar=-1;c.protectedPrice=0;
   FindLLocation(1,i,time,high,low,close,atr,c);
   LStructureReading r;ReadLStructure(i,c,high,low,close,r);
   if(r.h1>=0) { c.protectedBar=r.h1;c.protectedPrice=high[r.h1]; }
   c.fading=true;c.absorption=false;SellTopCandidate=c;SellTopStarted=i;
   string reason="";bool counter=false;
   if(SellTopProof(i,c,open,high,low,close,ticks,volume,reason,counter))
   {
      NewSweepCandidate saved=NewCandidates[1];NewCandidates[1]=c;
      bool accepted=CreateNewEvent(1,i,time,open,high,low,close,ticks,volume,notify);
      NewCandidates[1]=saved;if(accepted) SellTopCandidate.active=false;
   }
   else LTrace(1,i,6,reason,time);
}

bool LImpulseAllowed(const int i,const NewSweepCandidate &c,const double &open[],const double &high[],
                     const double &low[],const double &close[],const long &ticks[],const long &volume[],string &why)
{
   why="";
   if(c.side<0 && c.route==6)
   { bool counter=false;return SellTopProof(i,c,open,high,low,close,ticks,volume,why,counter); }
   if(!InpImpulseControl || ImpulseSide==0 || c.side==ImpulseSide) return true;
   if(c.side<0 && c.route==4 && LSellLocationCounterProof(i,c,open,high,low,close,ticks,volume,why)) return true;
   int p=c.bar;bool locationTest=false;string proof="";
   bool holds=p>=27 && i>=p+2 && c.side*(close[i]-close[i-1])>0 && c.side*(close[i-1]-close[i-2])>0;
   double incomingEdge=p>0?(c.side>0?high[p-1]:low[p-1]):0;
   bool stopping=false;
   if(p>=27 && p<=i)
   {
      bool real=UseRealWindow(p-26,i,volume),known=true;double early=0,late=0,ve=0,vl=0;
      for(int j=p-5;j<=p;j++)
      {
         double move=MathMax(0.0,-c.side*(close[j]-close[j-1])),rv=QualityRelativeVolume(j,real,ticks,volume);
         if(rv<=0) known=false;
         if(j<p-2) { early+=move;ve+=rv; } else { late+=move;vl+=rv; }
      }
      double rv=QualityRelativeVolume(p,real,ticks,volume),range=high[p]-low[p];
      double wick=c.side>0?MathMin(open[p],close[p])-low[p]:high[p]-MathMax(open[p],close[p]);
      stopping=known && ((early>0 && late<early*0.75 && (vl<=ve*0.9 || vl>=ve)) ||
         (rv>=1.3 && range>0 && wick>=0.35*range));
   }
   if(InpImpulseLocationReversal && c.route==4 && stopping && holds && c.side*(close[i]-incomingEdge)>0 &&
      c.side*(close[i]-close[p])>=0.8*c.atr &&
      LLocationProof(i,c,open,high,low,close,ticks,volume,locationTest,proof))
   { why="vùng lớn: hai Close phủ nhận nhịp đi vào; "+proof;return true; }
   why=ImpulseReading+"; chưa có phá nhịp/test đảo lực, chặn L ngược hướng";return false;
}

bool LRouteAllowed(const int i,const NewSweepCandidate &c,const double &open[],const double &high[],
                   const double &low[],const double &close[],const long &ticks[],const long &volume[],string &flowReason)
{
   bool routeAllowed=false;
   if(c.side<0 && c.route==6) { bool counter=false;return SellTopProof(i,c,open,high,low,close,ticks,volume,flowReason,counter); }
   if(c.route==5) return LTurnProof(i,c,flowReason);
   if(c.route==4)
   {
      bool lowVolumeTest=false;
      return LLocationProof(i,c,open,high,low,close,ticks,volume,lowVolumeTest,flowReason);
   }
   if(c.route==1)
   {
      LStructureReading current;ReadLStructure(i,c,high,low,close,current);
      routeAllowed=c.protectedBar>=20 && c.side*(c.extreme-c.protectedPrice)>=InpLSwingToleranceATR*c.atr &&
                   c.side*(close[i]-c.level)>0;
      flowReason=current.description+"; test "+(c.side>0?"HL":"LH")+" giữ mốc bảo vệ "+DoubleToString(c.protectedPrice,_Digits);
   }
   else if(c.route==2)
   {
      LStructureReading current;ReadLStructure(i,c,high,low,close,current);
      routeAllowed=current.ranging && current.atEdge && current.breakDir!=-c.side;
      flowReason=current.description+"; hai lần chạm mép tách biệt và test giữ giá";
   }
   else routeAllowed=LFlowAllowed(i,c,open,high,low,close,ticks,volume,flowReason);
   if(c.route>0 && routeAllowed)
   {
      string sharedReason="";
      bool sharedAllowed=LFlowAllowed(i,c,open,high,low,close,ticks,volume,sharedReason);
      flowReason+="; "+sharedReason;
      routeAllowed=sharedAllowed;
   }
   return routeAllowed;
}

void StepLTrendPending(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                       const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpLRespectFlow || !LTrendPending[slot].active) return;
   NewSweepCandidate c=LTrendPending[slot];if(i<=LTrendQueuedAt[slot]) return;
   for(int n=NewEventCount-1;n>=0 && NewEvents[n].bar==i;n--)
      if(NewEvents[n].side==c.side) { LTrendPending[slot].active=false;return; }
   bool invalid=c.side>0?low[i]<c.extreme-0.05*c.atr:high[i]>c.extreme+0.05*c.atr;
   if(invalid || i-LTrendQueuedAt[slot]>InpLFlowWaitBars)
   { LTrendPending[slot].active=false;return; }
   NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
   bool created=CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify,LTrendWasExhaustion[slot],true);
   NewCandidates[slot]=saved;
   if(created) LTrendPending[slot].active=false;
}
bool LVolumeAllowed(const int i,const long &ticks[],const long &volume[],double &relative,bool &real,string &why)
{
   real=i>=20 && UseRealWindow(i-20,i,volume);
   relative=i>=20?QualityRelativeVolume(i,real,ticks,volume):0;
   if(!InpLVolumeLock) { why="khóa volume L OFF";return true; }
   if(relative<=0) { why="L chờ: thiếu volume/MA20 của 20 nến trước";return false; }
   if(relative<InpLMinRelativeVolume)
   {
      why="L chặn Vol/MA20="+DoubleToString(relative,2)+" < "+DoubleToString(InpLMinRelativeVolume,2);
      return false;
   }
   why="L đạt Vol/MA20="+DoubleToString(relative,2)+(real?" (real)":" (tick)");
   return true;
}
bool LSameCycle(const NewSweepCandidate &c,const int i,const double &high[],const double &low[],const double &close[])
{
   if(!InpLCycleLock) return false;
   for(int n=NewEventCount-1;n>=0;n--)
   {
      NewEffortEvent e=NewEvents[n];if(e.side!=c.side) continue;
      if(e.bar>=i) return true;
      if(c.bar<=e.bar) return true; // Reusing the same turning leg through another generator.
      double gap=EntryBandDistance(e.zoneLow,e.zoneHigh,c.extreme,c.extreme);
      if(gap>0.5*MathMax(e.atr,c.atr)) return false;
      for(int j=e.bar+1;j<c.bar;j++)
         if(c.side*(close[j]-(c.side>0?e.zoneHigh:e.zoneLow))>=InpLCycleDepartureATR*MathMax(e.atr,c.atr)) return false;
      return true;
   }
   return false;
}

bool CreateNewEvent(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                    const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify,const bool exhaustion=false,const bool flowRetry=false)
{
   NewSweepCandidate c=NewCandidates[slot];
   if(InpSmartScoreFilter && LSmartScore(c.side,i,open,high,low,close,ticks,volume)<InpSmartMinScore)
   { LTrace(slot,i,c.route,"Smart score below minimum",time);return false; }
   bool sellTopCounter=false;string sellTopWhy="";
   if(c.side<0 && c.route==6)
   {
      if(!SellTopProof(i,c,open,high,low,close,ticks,volume,sellTopWhy,sellTopCounter))
      { LTrace(slot,i,6,sellTopWhy,time);return false; }
   }
   if(c.side<0 && c.route==4)
      sellTopCounter=LSellLocationCounterProof(i,c,open,high,low,close,ticks,volume,sellTopWhy);
   string proReason="";if(!ProAllows(c.side,proReason,sellTopCounter))
   { LTrace(slot,i,c.route,"PRO: "+proReason,time);if(InpDebugNewBars) Print("PRO L blocked | ",proReason);return false; }
   double atr=c.atr;
   double stop=c.extreme-c.side*InpNewStopBufferATR*atr;
   bool realConfirm=false;double confirmRV=0;string volumeReason="";
   bool volumeAllowed=LVolumeAllowed(i,ticks,volume,confirmRV,realConfirm,volumeReason);
   if(!InpNewLimitSetup) return false;
   if(flowRetry && c.side*(close[i]-c.level)<=0) return false; // Vẫn phải giữ phía đã lấy lại của mốc L.
   if(LAlreadyKnown(c.side,c.bar)) { LTrace(slot,i,c.route,"đã có L tại cùng gốc, không phát lặp",time);return false; }
   string flowReason="";bool routeAllowed=LRouteAllowed(i,c,open,high,low,close,ticks,volume,flowReason);
   if(!routeAllowed)
   {
      if(!flowRetry && c.route!=4 && c.route!=5 && c.route!=6)
      { LTrendPending[slot]=c;LTrendPending[slot].active=true;LTrendQueuedAt[slot]=i;LTrendWasExhaustion[slot]=exhaustion; }
      LTrendWhy[slot]=flowReason;
      LTrace(slot,i,c.route,flowReason,time);
      if(InpDebugNewBars) Print("PRO L FLOW WAIT | ",TimeToString(time[i])," | ",flowReason);
      return false;
   }
   string impulseWhy="";
   if(!LImpulseAllowed(i,c,open,high,low,close,ticks,volume,impulseWhy))
   { LTrace(slot,i,c.route,impulseWhy,time);return false; }
   if(impulseWhy!="") flowReason+="; "+impulseWhy;
   bool locationVolumeException=false;
   if(!volumeAllowed && c.route==4 && confirmRV>0 && confirmRV<1.0)
   {
      string locationWhy="";
      LLocationProof(i,c,open,high,low,close,ticks,volume,locationVolumeException,locationWhy);
   }
   if(!volumeAllowed && !locationVolumeException)
   {
      LTrendWhy[slot]=volumeReason;
      LTrace(slot,i,exhaustion?3:c.route,volumeReason,time);
      return false; // Không phát L ở nến này, không gắn volume nến sau vào nến trước.
   }
   NewEffortEvent e;
   e.bar=i;e.origin=c.bar;e.stamp=time[c.bar];e.knownStamp=time[i]+PeriodSeconds(_Period);e.source=exhaustion?3:c.route;e.invalidated=false;e.side=c.side;e.state=0;e.atr=atr;e.stop=stop;
   double width=MathMax(0.1*atr,MathMin(InpNewZoneMaxATR*atr,MathAbs(c.bodyEdge-c.extreme)+0.05*atr));
   e.zoneLow=c.side>0?c.extreme:c.extreme-width;
   e.zoneHigh=c.side>0?c.extreme+width:c.extreme;
   e.entry=c.side>0?e.zoneHigh:e.zoneLow;
   if(c.side*(close[i]-e.entry)<=0) { LTrace(slot,i,e.source,"Close còn ở sai phía vùng limit, chưa công bố",time);return false; } // Không treo limit sai phía thị trường.
   if(LSameCycle(c,i,high,low,close))
   { LTrace(slot,i,c.route,"cùng nhịp/vùng đã có L; chưa có nhịp rời và chạm lại độc lập",time);return false; }
   if(LCollecting)
   {
      double score=(c.route==6?4.25:c.route==5?4.5:c.route==4?4.0:c.route==1?3.0:c.route==2?3.0:exhaustion?2.0:1.0);
      score+=MathMin(1.0,c.side*(close[i]-c.extreme)/atr);
      if(!LProposalReady[slot] || score>LProposalScore[slot] ||
         (score==LProposalScore[slot] && c.side*(c.extreme-LProposal[slot].extreme)<0))
      { LProposalReady[slot]=true;LProposal[slot]=c;LProposalScore[slot]=score;LProposalExhaustion[slot]=exhaustion;LProposalRetry[slot]=flowRetry; }
      return true; // Validated duplicate hypotheses are consumed together; only winner is published.
   }
   e.monitor="";
   e.evidence=c.route==6?"L Sell đỉnh: nhịp tăng mất hiệu quả, Close phủ nhận lực mua":c.route==5?"L đổi cấu trúc: nhịp phá mốc, hồi đầu yếu và Close xác nhận":c.route==4?"L vị trí: phản ứng tại "+c.keyLabel:c.route==1?"L thuận nhịp: test HL/LH, hồi giảm hiệu quả và Close xác nhận":c.route==2?"L mép biên: test lại vùng đã giữ, hai Close xác nhận":exhaustion?"L kiệt sức: nhịp đi vào giảm hiệu quả, Close xác nhận":c.fading?"Cung/cầu đẩy trước giảm; quét rồi lấy lại mốc":"Nỗ lực lớn, kết quả bị phủ nhận; lấy lại mốc";
   if(c.side<0 && c.route==4 && sellTopCounter) e.evidence+="; "+sellTopWhy+"; quyền SOS lớn không đổi";
   if(locationVolumeException) e.evidence+="; ngoại lệ: test vùng, hai Close giữ và lực cũ mất hiệu quả";
   e.evidence+="; Vol xác nhận/MA20="+DoubleToString(confirmRV,2)+
      (InpLVolumeLock?(realConfirm?"; khóa Vol real ON":"; khóa Vol tick ON"):"; khóa Vol OFF");
   PivotMarketReading m;ReadPivotMarket(i,open,high,low,close,ticks,volume,m);
   e.reading=m.ready?m.foundation:"nền chưa đủ xác nhận";
   e.reading+="; "+flowReason;
   string proSnapshot=ProSummary();if(proSnapshot!="") e.reading+="; "+proSnapshot;
   if(InpShowEntryContext && (InpMTFZones || InpMTFKeyLevels))
   {
      string mtf=BuildMTFTooltip(slot,i,ArraySize(time),c.side,time,high,low,close);
      string nearZone="";double nearest=EMPTY_VALUE;bool missing=false;
      for(int tf=0;tf<4;tf++) if(MTFEnabled(tf) && InpMTFZones)
      {
         int cache=slot*4+tf;
         if(!MTFCache[cache].ready || StringFind(mtf,MTFName(tf)+": thiếu")>=0) { missing=true;continue; }
         for(int z=0;z<MTFCache[cache].count;z++)
         {
            int side=MTFCache[cache].side[z];
            double lo=MTFCache[cache].lo[z],hi=MTFCache[cache].hi[z];
            double tolerance=InpZoneInvalidATR*MTFCache[cache].scale[z];
            if(side>0?close[i]<lo-tolerance:close[i]>hi+tolerance) continue;
            double gap=EntryBandDistance(lo,hi,e.entry,e.entry);
            if(gap<nearest) { nearest=gap;nearZone=(side>0?"cầu ":"cung ")+MTFName(tf); }
         }
      }
      if(nearZone!="") e.reading+=(nearest<=InpZoneNearATR*atr?"; gần ":"; xa ")+nearZone;
      if(missing) e.reading+="; MTF thiếu một phần";
   }
   e.name=Prefix+"NEW_ENTRY_"+IntegerToString(NewEventCount);
   int id=NewEventCount;
   if(ArrayResize(NewEvents,id+1,256)<id+1) return false;
   int previous=NewActive[slot];
   if(previous>=0 && NewEvents[previous].state==0)
   { NewEvents[previous].state=2;RenderNewEvent(previous);NewActive[slot]=-1; }
   NewEvents[id]=e;NewEventCount++;
   NewActive[slot]=id;LTrendPending[slot].active=false;
   if(c.side>0) Up[i]=low[i];else Down[i]=high[i];
   if(InpShowHistory)
   {
      DisplayBuy[i]=ConfirmedBuy[i];DisplaySell[i]=ConfirmedSell[i];
      DisplayUp[i]=Up[i];DisplayDown[i]=Down[i];
   }
   RenderNewEvent(id);
   if(!NewRenderDeferred && !InpShowHistory && id>=5)
   { ObjectDelete(0,NewEvents[id-5].name);ObjectDelete(0,NewEvents[id-5].name+"_ONE"); }
   LTrace(slot,i,e.source,"L đã xác nhận; gốc "+TimeToString(time[c.bar]),time);
   NotifyNewEvent(_Symbol+" "+EnumToString(_Period)+" | "+(c.side>0?"BUY ":"SELL ")+
      "L — chỉ chờ hồi, chưa khớp",notify);
   return true;
}
void StepNewSweep(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                   const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   int side=slot==0?1:-1;
   double atr=ContextATR(i,high,low,close);
   if(atr<=0) return;
   bool real=UseRealWindow(i-MathMax(24,InpNewSweepBars),i,volume);
   double rv=QualityRelativeVolume(i,real,ticks,volume);
   double priorRV=QualityRelativeVolume(i-1,real,ticks,volume);
   double olderRV=QualityRelativeVolume(i-2,real,ticks,volume);
   if(rv<=0 || priorRV<=0 || olderRV<=0) { LTrace(slot,i,0,"thiếu volume để đọc cú quét",time);return; }
   if(NewCandidates[slot].active)
   {
      NewSweepCandidate c=NewCandidates[slot];
      if(i-c.bar>InpNewReactionBars) NewCandidates[slot].active=false;
      else
      {
         double range=high[i]-low[i],loc=range>0?(close[i]-low[i])/range:0.5;
         bool recovered=side*(close[i]-c.level)>0 && side*(close[i]-close[c.bar])>=InpNewReactionATR*c.atr;
         bool directional=side*(close[i]-open[i])>0 && (side>0?loc>=0.65:loc<=0.35);
         bool productive=rv>=1.0 || (c.fading && side*(close[i]-close[i-1])>=0.35*c.atr);
         bool sweptAgain=side>0?low[i]<c.extreme-0.05*c.atr:high[i]>c.extreme+0.05*c.atr;
         if(recovered && directional && productive && !sweptAgain)
         {
            CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
            NewCandidates[slot].active=false;
            return;
         }
         if(sweptAgain) NewCandidates[slot].active=false;
      }
   }
   double level=side>0?low[i-1]:high[i-1];
   for(int j=i-InpNewSweepBars;j<i;j++) level=side>0?MathMin(level,low[j]):MathMax(level,high[j]);
   double extreme=side>0?low[i]:high[i];
   bool sweep=side>0?extreme<level:extreme>level;
   double priorMove=-side*(close[i-1]-close[i-4]);
   if(!sweep) { LTrace(slot,i,0,"chưa quét cực trị 20 nến; nhánh này không nhận HL/LH",time);return; }
   if(priorMove<InpNewMinPriorMoveATR*atr) { LTrace(slot,i,0,"nhịp đi vào cú quét chưa đủ",time);return; }
   double range=high[i]-low[i];
   if(range<=0) return;
   double body=MathAbs(close[i]-open[i]);
   double wick=side>0?MathMin(open[i],close[i])-low[i]:high[i]-MathMax(open[i],close[i]);
   bool fading=priorRV<olderRV*0.9 || rv<priorRV*0.85;
   bool absorption=rv>=1.3 && wick/range>=0.35 && wick>=body;
   if(!fading && !absorption) { LTrace(slot,i,0,"có quét nhưng chưa thấy giảm hiệu quả/từ chối",time);return; }
   NewCandidates[slot].active=true;NewCandidates[slot].bar=i;NewCandidates[slot].side=side;
   NewCandidates[slot].route=0;NewCandidates[slot].protectedBar=-1;NewCandidates[slot].protectedPrice=0;
   NewCandidates[slot].level=level;NewCandidates[slot].extreme=extreme;NewCandidates[slot].atr=atr;
   NewCandidates[slot].bodyEdge=side>0?MathMin(open[i],close[i]):MathMax(open[i],close[i]);
   LTrace(slot,i,0,"ứng viên quét; chờ Close lấy lại mốc",time);
   NewCandidates[slot].fading=fading;NewCandidates[slot].absorption=absorption;
   double loc=(close[i]-low[i])/range;
   if(side*(close[i]-level)>0 && side*(close[i]-open[i])>0 &&
      (side>0?loc>=0.7:loc<=0.3) && wick/range>=0.35)
   {
      CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
      NewCandidates[slot].active=false;
   }
}
void StepExhaustionL(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                     const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpProExhaustionL || i<30) return;
   int side=slot==0?1:-1;
   for(int n=NewEventCount-1;n>=0 && NewEvents[n].bar==i;n--)
      if(NewEvents[n].side==side) { ExhaustCandidates[slot].active=false;return; }
   double atr=ContextATR(i,high,low,close);if(atr<=0) return;
   bool real=UseRealWindow(i-28,i,volume);
   double rv=QualityRelativeVolume(i,real,ticks,volume);if(rv<=0) return;
   if(ExhaustCandidates[slot].active)
   {
      NewSweepCandidate c=ExhaustCandidates[slot];
      bool invalid=side>0?low[i]<c.extreme-0.05*c.atr:high[i]>c.extreme+0.05*c.atr;
      if(invalid || i-c.bar>InpNewReactionBars) ExhaustCandidates[slot].active=false;
      else
      {
         double range=high[i]-low[i],loc=range>0?(side>0?(close[i]-low[i])/range:(high[i]-close[i])/range):0.5;
         bool reclaimed=side*(close[i]-c.level)>=0.05*c.atr && side*(close[i]-close[i-1])>=0.25*c.atr;
         if(reclaimed && side*(close[i]-open[i])>0 && loc>=0.65)
         {
            NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
            CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify,true);
            NewCandidates[slot]=saved;ExhaustCandidates[slot].active=false;return;
         }
         return;
      }
   }
   double extreme=side>0?low[i]:high[i],priorExtreme=side>0?low[i-1]:high[i-1];
   for(int j=i-6;j<i;j++) priorExtreme=side>0?MathMin(priorExtreme,low[j]):MathMax(priorExtreme,high[j]);
   if(side*(extreme-priorExtreme)>0.1*atr) { LTrace(slot,i,3,"không ở cực trị cục bộ",time);return; }
   double incoming=-side*(close[i-1]-close[i-7]),path=0,early=0,late=0,ve=0,vl=0;
   for(int j=i-6;j<i;j++)
   {
      double delta=-side*(close[j]-close[j-1]);path+=MathAbs(delta);
      double v=QualityRelativeVolume(j,real,ticks,volume);if(v<=0) return;
      if(j<i-3) { early+=MathMax(0.0,delta);ve+=v; }
      else { late+=MathMax(0.0,delta);vl+=v; }
   }
   if(incoming<InpProExhaustMoveATR*atr || path<=0 || incoming/path<0.45) { LTrace(slot,i,3,"nhịp đi vào chưa đủ rõ để xét kiệt sức",time);return; }
   double range=high[i]-low[i];if(range<=0) return;
   double wick=side>0?MathMin(open[i],close[i])-low[i]:high[i]-MathMax(open[i],close[i]);
   bool fading=early>0 && late<early*0.75;
   bool stall=ve>0 && vl>=ve && early>0 && late/vl<early/ve*0.75;
   bool rejection=wick>=0.5*range; // No volume >=MA20 rule for L.
   if(!fading && !stall && !rejection) { LTrace(slot,i,3,"nhịp chưa giảm hiệu quả hoặc bị từ chối",time);return; }
   LTrace(slot,i,3,"ứng viên kiệt sức, chờ Close phủ nhận nhịp cũ",time);
   NewSweepCandidate c;c.active=true;c.bar=i;c.side=side;c.extreme=extreme;c.atr=atr;
   c.level=side>0?MathMax(open[i],close[i]):MathMin(open[i],close[i]);
   c.bodyEdge=side>0?MathMin(open[i],close[i]):MathMax(open[i],close[i]);
   c.fading=fading;c.absorption=stall || rejection;c.route=0;c.protectedBar=-1;c.protectedPrice=0;ExhaustCandidates[slot]=c;
   double loc=side>0?(close[i]-low[i])/range:(high[i]-close[i])/range;
   if(rejection && side*(close[i]-open[i])>0 && loc>=0.7 && side*(close[i]-close[i-1])>=0.25*atr)
   {
      NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
      CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify,true);
      NewCandidates[slot]=saved;ExhaustCandidates[slot].active=false;
   }
}
void ApplyImpulsePendingControl(const int i)
{
   if(!InpImpulseControl || ImpulseSide==0 || ImpulseKnown!=i) return;
   for(int slot=0;slot<2;slot++)
   {
      int id=NewActive[slot];if(id<0 || id>=NewEventCount) continue;
      if(NewEvents[id].state!=0 || NewEvents[id].side==ImpulseSide) continue;
      NewEvents[id].state=2;NewEvents[id].monitor="Hủy chờ tại Close: "+ImpulseReading;
      RenderNewEvent(id);NewActive[slot]=-1;
   }
}

void ApplyWyPendingControl()
{
   if(!InpWyDirectionalControl || !InpProEnabled || !InpProWyckoff || WyControlSide==0) return;
   for(int slot=0;slot<2;slot++)
   {
      int id=NewActive[slot];if(id<0 || id>=NewEventCount) continue;
      if(NewEvents[id].side==WyControlSide || NewEvents[id].state!=0) continue;
      NewEvents[id].state=2;NewEvents[id].monitor="Hủy chờ tại Close: "+WyControlReading;
      RenderNewEvent(id);NewActive[slot]=-1;
   }
}
void StepWyLPS(const int i,const datetime &time[],const double &open[],const double &high[],const double &low[],
               const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpWyLPSLocation || !InpProEnabled || !InpProWyckoff) return;
   for(int slot=0;slot<2;slot++)
   {
      ProWyState a=ProWy[slot];int side=slot==0?1:-1;
      if(a.stage!=7 || a.last!=i || a.returnBar<=a.breakBar || a.returnBar<20) continue;
      int origin=a.returnBar;
      for(int j=origin+1;j<=i;j++) if(side>0?low[j]<low[origin]:high[j]>high[origin]) origin=j;
      NewSweepCandidate c;c.active=true;c.bar=origin;c.side=side;c.route=4;c.atr=a.atr;
      c.extreme=side>0?low[origin]:high[origin];c.bodyEdge=side>0?MathMin(open[origin],close[origin]):MathMax(open[origin],close[origin]);
      c.keyLow=a.boundary-0.15*a.atr;c.keyHigh=a.boundary+0.15*a.atr;
      c.keyLabel=side>0?"SOS → LPS: test cầu sau phá biên":"SOW → LPSY: test cung sau phá biên";
      c.keyType=5;c.level=a.boundary;c.protectedBar=a.breakBar;c.protectedPrice=a.extreme;
      c.fading=true;c.absorption=false;
      NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=c;
      CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
      NewCandidates[slot]=saved;
   }
}
struct LiveLevel { double lo,hi,atr,distance;int side,kind,source,mask;datetime known;string label;bool used; };
LiveLevel LiveLevels[1280];int LiveLevelCount=0,LiveDrawnCount=0;
string LiveSourceName(const int source)
{ return source==0?StringSubstr(EnumToString(_Period),7):MTFName(source-1); }
int LiveSourceSeconds(const int source)
{ return source==0?PeriodSeconds(_Period):PeriodSeconds(MTFPeriod(source-1)); }
string LiveTFText(const int mask)
{
   string result="";
   int order[5];for(int n=0;n<5;n++) order[n]=n;
   for(int a=0;a<5;a++) for(int b=a+1;b<5;b++) if(LiveSourceSeconds(order[b])>LiveSourceSeconds(order[a]))
   { int t=order[a];order[a]=order[b];order[b]=t; }
   for(int n=0;n<5;n++) if((mask & (1<<order[n]))!=0)
   {
      string tf=LiveSourceName(order[n]);
      if(StringFind("+"+result+"+","+"+tf+"+")>=0) continue;
      result+=(result==""?"":"+")+tf;
   }
   return result;
}
void AddLiveLevel(const double lo,const double hi,const double atr,const int side,const int kind,
                  const int source,const datetime known,const string label,const double price)
{
   if(LiveLevelCount>=1280 || atr<=0 || hi<lo) return;
   for(int z=0;z<LiveLevelCount;z++)
   {
      if(LiveLevels[z].side!=side || LiveLevels[z].kind!=kind || (LiveLevels[z].mask & (1<<source))!=0) continue;
      double overlap=MathMin(hi,LiveLevels[z].hi)-MathMax(lo,LiveLevels[z].lo);
      double narrow=MathMin(hi-lo,LiveLevels[z].hi-LiveLevels[z].lo);
      bool match=kind==2?(narrow>0 && overlap>=0.50*narrow):MathAbs(lo-LiveLevels[z].lo)<=0.05*MathMin(atr,LiveLevels[z].atr);
      if(!match) continue;
      LiveLevels[z].mask|=(1<<source);
      if(LiveSourceSeconds(source)>LiveSourceSeconds(LiveLevels[z].source))
      {
         LiveLevels[z].lo=lo;LiveLevels[z].hi=hi;LiveLevels[z].atr=atr;LiveLevels[z].known=known;
         LiveLevels[z].source=source;LiveLevels[z].distance=EntryBandDistance(lo,hi,price,price);
      }
      LiveLevels[z].label=LiveTFText(LiveLevels[z].mask);return;
   }
   for(int n=0;n<LiveLevelCount;n++) if(LiveLevels[n].source==source && LiveLevels[n].kind==kind &&
      LiveLevels[n].side==side && MathAbs(LiveLevels[n].lo-lo)<0.05*atr && MathAbs(LiveLevels[n].hi-hi)<0.05*atr) return;
   int n=LiveLevelCount++;LiveLevels[n].lo=lo;LiveLevels[n].hi=hi;LiveLevels[n].atr=atr;
   LiveLevels[n].side=side;LiveLevels[n].kind=kind;LiveLevels[n].source=source;LiveLevels[n].known=known;
   LiveLevels[n].mask=(1<<source);LiveLevels[n].label=LiveTFText(LiveLevels[n].mask);LiveLevels[n].distance=EntryBandDistance(lo,hi,price,price);LiveLevels[n].used=false;
}
void DrawLiveLevel(const int id,const int ordinal,const datetime now)
{
   LiveLevel a=LiveLevels[id];string name=Prefix+"LIVE_"+IntegerToString(ordinal);
   datetime end=now,start=a.known>0?a.known:now-PeriodSeconds(_Period);
   if(start>=end) start=end-PeriodSeconds(_Period);
   color ink=a.kind==2?(a.side>0?InpLiveDemandColor:InpLiveSupplyColor):(a.side>0?InpLiveSupportColor:InpLiveResistanceColor);
   int expected=a.kind==2?OBJ_RECTANGLE:OBJ_TREND;
   if(ObjectFind(0,name)>=0 && ObjectGetInteger(0,name,OBJPROP_TYPE)!=expected) ObjectDelete(0,name);
   if(a.kind==2)
   {
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE,0,start,a.lo,end,a.hi);
      ObjectMove(0,name,0,start,a.lo);ObjectMove(0,name,1,end,a.hi);
      ObjectSetInteger(0,name,OBJPROP_FILL,false);ObjectSetInteger(0,name,OBJPROP_BACK,true);
   }
   else
   {
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,start,a.lo,end,a.lo);
      ObjectMove(0,name,0,start,a.lo);ObjectMove(0,name,1,end,a.lo);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   string middle=name+"_MID";
   if(a.kind==2)
   {
      double mid=(a.lo+a.hi)/2.0;
      if(ObjectFind(0,middle)<0) ObjectCreate(0,middle,OBJ_TREND,0,start,mid,end,mid);
      ObjectMove(0,middle,0,start,mid);ObjectMove(0,middle,1,end,mid);
      ObjectSetInteger(0,middle,OBJPROP_STYLE,STYLE_DOT);ObjectSetInteger(0,middle,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,middle,OBJPROP_COLOR,a.side>0?clrLimeGreen:clrTomato);
      ObjectSetInteger(0,middle,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,middle,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,middle,OBJPROP_HIDDEN,true);
   }
   else ObjectDelete(0,middle);
   string tip=a.label+(a.kind==2?(a.side>0?" Demand":" Supply"):(a.side>0?" Support":" Resistance"))+"; "+DoubleToString(a.lo,_Digits)+(a.kind==2?" – "+DoubleToString(a.hi,_Digits):"")+
      "; còn hiệu lực theo nến đóng; bản đồ hiện tại "+TimeToString(now);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   if(a.kind==2) ObjectSetString(0,middle,OBJPROP_TOOLTIP,tip);
   string text=name+"_LABEL";double price=a.kind==2?(a.lo+a.hi)/2.0:a.lo;
   int shift=iBarShift(_Symbol,_Period,now,false);
   datetime labelTime=shift>=0?iTime(_Symbol,_Period,shift+InpLiveLabelOffsetBars):0;
   if(labelTime<=0) labelTime=now-(datetime)((long)MathMax(1,PeriodSeconds(_Period))*InpLiveLabelOffsetBars);
   if(ObjectFind(0,text)>=0 && ObjectGetInteger(0,text,OBJPROP_TYPE)!=OBJ_TEXT) ObjectDelete(0,text);
   if(ObjectFind(0,text)<0) ObjectCreate(0,text,OBJ_TEXT,0,labelTime,price);
   ObjectMove(0,text,0,labelTime,price);
   ObjectSetString(0,text,OBJPROP_TEXT,a.label);
   ObjectSetString(0,text,OBJPROP_FONT,"Arial");ObjectSetInteger(0,text,OBJPROP_FONTSIZE,InpLiveFontSize);
   ObjectSetInteger(0,text,OBJPROP_ANCHOR,ANCHOR_LOWER);
   ObjectSetInteger(0,text,OBJPROP_COLOR,a.side>0?clrLimeGreen:clrTomato);
   ObjectSetInteger(0,text,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,text,OBJPROP_HIDDEN,true);
   ObjectSetString(0,text,OBJPROP_TOOLTIP,tip);
}
void RefreshLiveLevelSnapshot()
{
   if(Prefix=="") return;
   if(!InpEnabled || !InpShowLiveLevels || (!LiveSDOn && !LiveKLOn) || LiveSnapshotCount<32)
   {
      for(int n=0;n<LiveDrawnCount;n++)
      { string old=Prefix+"LIVE_"+IntegerToString(n);ObjectDelete(0,old);ObjectDelete(0,old+"_LABEL");ObjectDelete(0,old+"_MID"); }
      LiveDrawnCount=0;return;
   }
   double atr=LiveSnapshotATR;if(atr<=0) return;
   datetime cutoff=LiveSnapshotCutoff;double price=LiveSnapshotClose;LiveLevelCount=0;
   if(InpLiveChartLevels) for(int n=0;n<256;n++)
   {
      LKnownLocation a=LLocations[n];
      if(!a.active || !a.qualified || a.born>LiveSnapshotCount-2 || (!a.major && InpLLocationMajorOnly)) continue;
      if((a.kind==2 && !LiveSDOn) || (a.kind==1 && !LiveKLOn)) continue;
      if(a.side*(price-(a.side>0?a.lo:a.hi))<-InpLSwingToleranceATR*a.atr) continue;
      AddLiveLevel(a.lo,a.hi,a.atr,a.side,a.kind,0,LiveOriginTime[n],"Chart "+(a.kind==2?(a.side>0?"Demand":"Supply"):(a.side>0?"Support":"Resistance")),price);
   }
   if(InpLiveMTFLevels) for(int tf=0;tf<4;tf++)
   {
      if(!MTFEnabled(tf) || (!InpMTFZones && !InpMTFKeyLevels)) continue;
      int cache=44+tf;if(!LoadMTFContext(cache,MTFPeriod(tf),cutoff)) continue;
      if(LiveSDOn && InpMTFZones) for(int z=0;z<MTFCache[cache].count;z++)
      {
         double lo=MTFCache[cache].lo[z],hi=MTFCache[cache].hi[z],scale=MTFCache[cache].scale[z];int side=MTFCache[cache].side[z];
         if(side*(price-(side>0?lo:hi))<-InpZoneInvalidATR*scale) continue;
         AddLiveLevel(lo,hi,scale,side,2,tf+1,MTFCache[cache].origin[z],MTFName(tf)+(side>0?" Demand":" Supply"),price);
      }
      if(LiveKLOn && InpMTFKeyLevels)
      {
         double keys[4];keys[0]=MTFCache[cache].lastHigh;keys[1]=MTFCache[cache].lastLow;
         keys[2]=MTFCache[cache].ph;keys[3]=MTFCache[cache].pl;
         for(int k=0;k<4;k++)
         {
            if(k<2 && !InpLiveClosedBarKeys) continue;
            if((k==2 && !MTFCache[cache].hasPH) || (k==3 && !MTFCache[cache].hasPL)) continue;
            double level=keys[k];int side=(k==0 || k==2)?-1:1;
            bool flipped=side*(LiveSnapshotClose-level)<-InpLSwingToleranceATR*atr && side*(LiveSnapshotPrevious-level)<-InpLSwingToleranceATR*atr;
            if(flipped) side=-side;
            if(side*(price-level)<-InpLSwingToleranceATR*atr) continue;
            string label=MTFName(tf)+(k<2?(k==0?" H đóng":" L đóng"):(k==2?" pivot H":" pivot L"))+(flipped?" đổi vai":"");
            datetime origin=k<2?MTFCache[cache].lastTime:(k==2?MTFCache[cache].phTime:MTFCache[cache].plTime);
            AddLiveLevel(level,level,atr,side,1,tf+1,origin,label,price);
         }
      }
   }
   int chosen[160],selected=0;
   for(int source=0;source<5;source++) for(int kind=1;kind<=2;kind++) for(int d=0;d<2;d++)
      for(int pick=0;pick<InpLivePerSide;pick++)
      {
         int best=-1;
         for(int n=0;n<LiveLevelCount;n++) if(!LiveLevels[n].used && LiveLevels[n].source==source &&
            LiveLevels[n].kind==kind && LiveLevels[n].side==(d==0?1:-1) &&
            (best<0 || LiveLevels[n].distance<LiveLevels[best].distance)) best=n;
         if(best<0) break;LiveLevels[best].used=true;chosen[selected++]=best;
      }
   for(int a=0;a<selected;a++) for(int b=a+1;b<selected;b++)
      if(LiveLevels[chosen[b]].distance<LiveLevels[chosen[a]].distance) { int x=chosen[a];chosen[a]=chosen[b];chosen[b]=x; }
   int height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0),gap=InpLiveFontSize+7;
   int capacity=MathMax(1,(height-50)/gap),ordinal=MathMin(selected,MathMin(InpLiveMaxLabels,capacity));
   for(int a=0;a<ordinal;a++) for(int b=a+1;b<ordinal;b++)
      if(LiveLevels[chosen[b]].hi>LiveLevels[chosen[a]].hi) { int x=chosen[a];chosen[a]=chosen[b];chosen[b]=x; }
   for(int n=0;n<ordinal;n++) DrawLiveLevel(chosen[n],n,cutoff);
   for(int n=ordinal;n<LiveDrawnCount;n++)
   { string old=Prefix+"LIVE_"+IntegerToString(n);ObjectDelete(0,old);ObjectDelete(0,old+"_LABEL");ObjectDelete(0,old+"_MID"); }
   LiveDrawnCount=ordinal;
}
void RefreshLiveLevels(const int count,const datetime &time[],const double &high[],const double &low[],const double &close[])
{
   if(InpForecastWorker)return;
   LiveSnapshotCount=count;
   if(count>=32)
   {
      int i=count-2;LiveSnapshotATR=ContextATR(i,high,low,close);
      LiveSnapshotCutoff=time[count-1];LiveSnapshotClose=close[i];LiveSnapshotPrevious=close[i-1];
      for(int n=0;n<256;n++)
         LiveOriginTime[n]=LLocations[n].origin>=0 && LLocations[n].origin<count?time[LLocations[n].origin]:0;
   }
   RefreshLiveLevelSnapshot();RefreshLevelButtons();
}
struct LForecastState
{
   bool active; int side,pivot,born,score; double lo,hi,stop,atr; string status;
};
LForecastState LF[2];
int LFUsedPivot[2];
void ResetLForecast()
{
   for(int k=0;k<2;k++) { LF[k].active=false;LFUsedPivot[k]=-1; }
}
int LSmartScore(const int side,const int i,const double &open[],const double &high[],
                const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(i<26) return 0;
   double atr=ContextATR(i,high,low,close);if(atr<=0) return 0;
   int score=20;
   double net=side*(close[i]-close[i-6]),path=0;
   for(int j=i-5;j<=i;j++) path+=MathAbs(close[j]-close[j-1]);
   if(net>0) score+=15;
   if(net>=0.8*atr && path>0 && net/path>=0.55) score+=15;
   double recent=0,older=0;
   for(int j=i-2;j<=i;j++) recent+=MathMax(0.0,-side*(close[j]-close[j-1]));
   for(int j=i-5;j<=i-3;j++) older+=MathMax(0.0,-side*(close[j]-close[j-1]));
   if(older>0 && recent<older*0.75) score+=15;
   double range=high[i]-low[i];
   if(range>0 && (side>0?(close[i]-low[i])/range:(high[i]-close[i])/range)>=0.65) score+=10;
   bool real=UseRealWindow(i-25,i,volume);
   double rv=QualityRelativeVolume(i,real,ticks,volume);
   if(rv>=1.0 && side*(close[i]-open[i])>0) score+=10;
   double v1=0,v2=0;bool known=true;
   for(int j=i-5;j<=i;j++)
   { double v=QualityRelativeVolume(j,real,ticks,volume);if(v<=0) known=false;if(j<=i-3)v1+=v;else v2+=v; }
   if(known && v2<v1 && recent<older) score+=10;
   if(ImpulseSide==side) score+=5;
   if(ImpulseSide==-side) score-=20;
   return (int)MathMax(0,MathMin(100,score));
}
void DrawLForecast(const int slot,const datetime &time[],const int i)
{
   if(InpForecastWorker)return;
   string name=Prefix+"LF_"+IntegerToString(slot),text=name+"_TEXT";
   if(!LF[slot].active) { ObjectDelete(0,name);ObjectDelete(0,text);ObjectDelete(0,name+"_SL");ObjectDelete(0,name+"_SL_PRICE");return; }
   LForecastState f=LF[slot];
   datetime begin=time[f.born]+PeriodSeconds(_Period);
   datetime finish=begin+(datetime)(InpForecastLife*PeriodSeconds(_Period));
   color ink=f.side>0?InpUpColor:InpDownColor;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE,0,begin,f.lo,finish,f.hi);
   ObjectMove(0,name,0,begin,f.lo);ObjectMove(0,name,1,finish,f.hi);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);ObjectSetInteger(0,name,OBJPROP_FILL,false);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   string info="L DU KIEN "+(f.side>0?"BUY":"SELL")+" | "+IntegerToString(f.score)+"/100 | "+f.status;
   string tip=info+"\nVung "+DoubleToString(f.lo,_Digits)+" - "+DoubleToString(f.hi,_Digits)+
      "\nHuy khi Close vuot "+DoubleToString(f.stop,_Digits)+
      "\nCho L goc xac nhan; diem so khong phai xac suat thang.";
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   if(ObjectFind(0,text)<0) ObjectCreate(0,text,OBJ_TEXT,0,begin,f.side>0?f.lo:f.hi);
   ObjectMove(0,text,0,begin,f.side>0?f.lo:f.hi);
   ObjectSetString(0,text,OBJPROP_TEXT,IntegerToString(f.score));ObjectSetString(0,text,OBJPROP_TOOLTIP,tip);
   ObjectSetInteger(0,text,OBJPROP_COLOR,ink);ObjectSetInteger(0,text,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,text,OBJPROP_ANCHOR,f.side>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0,text,OBJPROP_SELECTABLE,false);
}
void StepLForecast(const int i,const datetime &time[],const double &open[],const double &high[],
                   const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(!InpLForecast || i<30) return;
   double atr=ContextATR(i,high,low,close);if(atr<=0)return;
   for(int slot=0;slot<2;slot++)
   {
      int side=slot==0?1:-1;
      if(LF[slot].active)
      {
         bool done=false;
         for(int n=NewEventCount-1;n>=0;n--)
         {
            if(NewEvents[n].bar<=LF[slot].born) break;
            if(NewEvents[n].bar>i || NewEvents[n].side!=side) continue;
            if(NewEvents[n].zoneLow<=LF[slot].hi && NewEvents[n].zoneHigh>=LF[slot].lo) {done=true;break;}
         }
         bool invalid=side*(close[i]-LF[slot].stop)<0;
         bool expired=i-LF[slot].born>=InpForecastLife;
         bool runaway=side*(close[i]-(side>0?LF[slot].hi:LF[slot].lo))>4*LF[slot].atr;
         if(done || invalid || expired || runaway) LF[slot].active=false;
         else if(low[i]<=LF[slot].hi && high[i]>=LF[slot].lo) LF[slot].status="DA CHAM / CHO L";
         continue; // do not replace or move an existing hypothesis on same bar
      }
      int best=-1,bestScore=-1;
      for(int p=i-2;p>=MathMax(26,i-InpForecastLookback);p--)
      {
         if(p<=LFUsedPivot[slot]) break;
         bool pivot=true;
         for(int k=1;k<=2;k++)
            if(side>0 ? (low[p]>=low[p-k] || low[p]>low[p+k]) : (high[p]<=high[p-k] || high[p]<high[p+k])) pivot=false;
         if(!pivot)continue;
         double extreme=side>0?low[p]:high[p];
         double edge=side>0?MathMin(open[p],close[p]):MathMax(open[p],close[p]);
         double width=MathMax(0.1*atr,MathMin(0.4*atr,MathAbs(edge-extreme)));
         double lo=side>0?extreme:extreme-width,hi=side>0?extreme+width:extreme;
         double gap=side*(close[i]-(side>0?hi:lo));
         if(gap<0.3*atr || gap>2.5*atr)continue;
         bool broken=false;double departure=0;
         for(int j=p+1;j<=i;j++)
         { if(side*(close[j]-extreme)<-0.1*atr)broken=true;departure=MathMax(departure,side*(close[j]-extreme)); }
         if(broken || departure<1.0*atr)continue;
         int points=LSmartScore(side,i,open,high,low,close,ticks,volume);
         points=(int)MathMin(100,points+15);
         if(points>=InpForecastMinScore && points>bestScore) {best=p;bestScore=points;}
      }
      if(best<0)continue;
      double extreme=side>0?low[best]:high[best];
      double edge=side>0?MathMin(open[best],close[best]):MathMax(open[best],close[best]);
      double width=MathMax(0.1*atr,MathMin(0.4*atr,MathAbs(edge-extreme)));
      LF[slot].active=true;LF[slot].side=side;LF[slot].pivot=best;LF[slot].born=i;
      LF[slot].score=bestScore;LF[slot].atr=atr;LF[slot].lo=side>0?extreme:extreme-width;
      LF[slot].hi=side>0?extreme+width:extreme;LF[slot].stop=extreme-side*InpNewStopBufferATR*atr;
      LF[slot].status="CHO HOI";LFUsedPivot[slot]=best;
   }
}

int CalculateNewEffort(const int count,const int prev,const bool reset,const datetime &time[],
                       const double &open[],const double &high[],const double &low[],const double &close[],
                       const long &ticks[],const long &volume[])
{
   if(reset)
   {
      ResetNewEffortState();ResetDisplayCache();ResetLForecast();
      if(Prefix!="") ObjectsDeleteAll(0,Prefix,0,-1);
      ArrayInitialize(Up,EMPTY_VALUE);ArrayInitialize(Down,EMPTY_VALUE);
      ArrayInitialize(ConfirmedBuy,EMPTY_VALUE);ArrayInitialize(ConfirmedSell,EMPTY_VALUE);
      ArrayInitialize(DisplayUp,EMPTY_VALUE);ArrayInitialize(DisplayDown,EMPTY_VALUE);
      ArrayInitialize(DisplayBuy,EMPTY_VALUE);ArrayInitialize(DisplaySell,EMPTY_VALUE);
      ArrayInitialize(DisplayStructBuy,EMPTY_VALUE);ArrayInitialize(DisplayStructSell,EMPTY_VALUE);
      ArrayInitialize(DisplayRetestBuy,EMPTY_VALUE);ArrayInitialize(DisplayRetestSell,EMPTY_VALUE);
      ArrayInitialize(DisplayWickBuy,EMPTY_VALUE);ArrayInitialize(DisplayWickSell,EMPTY_VALUE);
      ArrayInitialize(StructBuy,EMPTY_VALUE);ArrayInitialize(StructSell,EMPTY_VALUE);
      ArrayInitialize(RetestBuy,EMPTY_VALUE);ArrayInitialize(RetestSell,EMPTY_VALUE);
      ArrayInitialize(WickBuy,EMPTY_VALUE);ArrayInitialize(WickSell,EMPTY_VALUE);
      ArrayInitialize(StrongWideWick,EMPTY_VALUE);
      ShownCount=0;
   }
   for(int j=reset?0:MathMax(0,prev-1);j<count;j++)
   {
      if(j<=NewProcessed) continue;
      StrongWideWick[j]=EMPTY_VALUE;
      Up[j]=Down[j]=ConfirmedBuy[j]=ConfirmedSell[j]=EMPTY_VALUE;
      DisplayUp[j]=DisplayDown[j]=DisplayBuy[j]=DisplaySell[j]=EMPTY_VALUE;
      DisplayStructBuy[j]=DisplayStructSell[j]=DisplayRetestBuy[j]=DisplayRetestSell[j]=EMPTY_VALUE;
      DisplayWickBuy[j]=DisplayWickSell[j]=EMPTY_VALUE;
   }
   if(!InpEnabled) { NewRenderDeferred=false;return count; }
   NewRenderDeferred=reset;
   int start=MathMax(MathMax(26,InpNewSweepBars+1),NewProcessed+1);
   if(reset) start=MathMax(start,count-1-InpStartupBars);
   bool changed=false;
   for(int i=start;i<count-1;i++)
   {
      for(int route=0;route<7;route++) LGeneratorWhy[route][0]="";
      bool notify=!reset && i==count-2;
      StepImpulse(i,open,high,low,close,ticks,volume);
      StepPro(i,time,open,high,low,close,ticks,volume);
      StepLTurnContext(i,time,open,high,low,close,ticks,volume);
      StepLLocations(i,open,high,low,close);
      for(int slot=0;slot<2;slot++) StepNewLimit(slot,i,high,low,notify);
      ApplyImpulsePendingControl(i);
      ApplyWyPendingControl();
      LCollecting=InpLArbitrate;
      for(int slot=0;slot<2;slot++) LProposalReady[slot]=false;
      for(int slot=0;slot<2;slot++) StepNewSweep(slot,i,time,open,high,low,close,ticks,volume,notify);
      for(int slot=0;slot<2;slot++) StepLTrendPending(slot,i,time,open,high,low,close,ticks,volume,notify);
      for(int slot=0;slot<2;slot++) StepExhaustionL(slot,i,time,open,high,low,close,ticks,volume,notify);
      for(int slot=0;slot<2;slot++) StepContinuationL(slot,i,time,open,high,low,close,ticks,volume,notify);
      for(int slot=0;slot<2;slot++) StepRangeTestL(slot,i,time,open,high,low,close,ticks,volume,notify);
      for(int slot=0;slot<2;slot++) StepLLocationEntry(slot,i,time,open,high,low,close,ticks,volume,notify);
      for(int slot=0;slot<2;slot++) StepLTurnEntry(slot,i,time,open,high,low,close,ticks,volume,notify);
      StepSellTopL(i,time,open,high,low,close,ticks,volume,notify);
      StepWyLPS(i,time,open,high,low,close,ticks,volume,notify);
      LCollecting=false;
      for(int slot=0;slot<2;slot++) if(LProposalReady[slot])
      {
         NewSweepCandidate saved=NewCandidates[slot];NewCandidates[slot]=LProposal[slot];
         CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify,LProposalExhaustion[slot],LProposalRetry[slot]);
         NewCandidates[slot]=saved;LProposalReady[slot]=false;
      }
      StepLForecast(i,time,open,high,low,close,ticks,volume);
      IndexDisplayBar(i);
      NewProcessed=i;changed=true;
   }
   bool flush=NewRenderDeferred;
   NewRenderDeferred=false;
   if(flush && changed)
   {
      int first=InpShowHistory?0:MathMax(0,NewEventCount-5);
      for(int n=first;n<NewEventCount;n++) RenderNewEvent(n);
   }
   if(changed && InpLForecast) for(int slot=0;slot<2;slot++) DrawLForecast(slot,time,count-2);
   if(changed && !InpShowHistory) RefreshRecent(count,time,low,high);
   if(changed) { RenderWyMarks();RefreshLiveLevels(count,time,high,low,close); }
   RefreshLiveMarketReader(count,time,open,high,low,close,ticks,volume);
   return count;
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   if(IndicatorStopping || rates_total<1) return 0;
   QualityChartCount=rates_total;MTFQueryEpoch++;
   ArraySetAsSeries(time,false); ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false); ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
   ArraySetAsSeries(tick_volume,false); ArraySetAsSeries(volume,false);
   bool reset=prev_calculated<=0 || prev_calculated>rates_total || FirstTime!=time[0];
   FirstTime=time[0];
   {
      if(!reset && NewProcessed==rates_total-2) {RefreshSourceForecasts();return rates_total;}
      ulong started=GetMicrosecondCount();int before=NewProcessed;
      if(InpEnabled) PrepareMetricCache(rates_total,prev_calculated,reset,high,low,close,tick_volume,volume);
      else if(MetricCacheReady) FreeMetricCache();
      int result=CalculateNewEffort(rates_total,prev_calculated,reset,time,open,high,low,close,tick_volume,volume);
      if(reset || (InpDebugNewBars && NewProcessed>before))
      {
         int buys=0,sells=0;
         for(int n=0;n<NewEventCount;n++) if(NewEvents[n].side>0) buys++;else sells++;
         Print("C7CB PERF v2.36 | bars=",rates_total," | calc_ms=",DoubleToString((double)(GetMicrosecondCount()-started)/1000.0,1),
               " | L Buy=",buys," Sell=",sells," | diagnostics=",InpLDiagnostics?"ON":"OFF");
      }
      if(reset) {ForecastReadStamp[0]=0;ForecastReadStamp[1]=0;}
      RefreshSourceForecasts();
      if(InpForecastWorker)
      {
         PublishForecast(rates_total,time);
         DisplayUp[rates_total-1]=rates_total>1?(double)time[rates_total-2]:0;
      }
      return result;
   }
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(IndicatorStopping) return;
   if(!InpEnabled) return;
   MTFQueryEpoch++;
   if(id==CHARTEVENT_OBJECT_CLICK && (sparam==Prefix+"BTN_SD" || sparam==Prefix+"BTN_KL"))
   {
      if(sparam==Prefix+"BTN_SD")
      {
         LiveSDOn=!LiveSDOn;
         if(LiveSDOn) for(int tf=0;tf<4;tf++) MTFCache[44+tf].ready=false;
      }
      else LiveKLOn=!LiveKLOn;
      RefreshLevelButtons();RefreshLiveLevelSnapshot();ChartRedraw(0);return;
   }
   if(id!=CHARTEVENT_CHART_CHANGE) return;
   RefreshLevelButtons();RefreshLiveLevelSnapshot();
}
