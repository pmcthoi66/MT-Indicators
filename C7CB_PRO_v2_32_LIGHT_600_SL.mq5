// v2.32 LIGHT: 600-bar startup; latest five L/SL; Buy diagnostics OFF; causal MTF interval reuse.
// v2.29 TEST: frozen causal L forecast, bounded scoring, closed-bar scheduling.
// C7CB PRO v2.27 — TEST, self-contained; keep Original unchanged.
// ProFilterWy/EW default OFF for observation. LVolumeLock defaults ON in v2.20; OFF restores MA20-free L.
// ProSummary is captured when entry becomes known; live reader shows current interpretation.
// Wyckoff A-E are schematic hypotheses, not proof of accumulation/distribution.
// EW checks price rules on 2 pivot scales + alternate count; not internal subwaves,
// diagonals, truncated fifths, flats, triangles, combinations or a uniquely correct count.
// Confirmed endpoints may extend and the live count may change; earlier snapshots do not.
// Event labels, if enabled, sit at RECOGNITION bars; L origin/known-time logic stays unchanged.
// v2.21: Sell route 6 aligns with Pine: local 9-bar high, origin-body trigger,
// high-to-Close rejection and two Close transitions including origin -> next bar.
// Buy, shared direction ownership, MA20, cycle lock and other Sell routes unchanged.
// v2.22: cache repeated metrics exactly, defer historical L drawing until replay ends.
// No history truncation or entry-filter changes.
// v2.23: optional Sell-only known-location counter proof scopes an SOS/impulse exception
// to this candidate. It does not release either global directional owner or alter Buy.
// v2.24: SD/KL buttons, top left, neutral OFF by default; display only.
// v2.25: upper-right buttons, pass-local exact-cutoff MTF memoization,
// no full label-history repaint on chart zoom. Entry and alert rules unchanged.
// v2.0: stop rendering before teardown, delete/verify this instance across all
// subwindows, release calculation caches; preserve other indicators and user objects.
// v2.27: bullish Wy marks below candles (up triangle), bearish above (down triangle).
// L text anchors face away from candles. Detection and alert conditions unchanged.
// MODULE MAP
// 01 Inputs and lifecycle; 02 legacy compatibility; 03 causal context/MTF reader;
// 04 impulse/Wyckoff/Elliott state; 05 L candidates and shared validation;
// 06 structural-turn L; 07 current level display; 08 calculation and chart events.
// Display state is separate from entry state. Pending/failed marks stay dim;
// confirmed responses brighten. Chart labels use color, not a question-mark suffix.
// L source coordinates may precede recognition; knownStamp always records availability.
// Legacy signal-rule port of the Pine v5 C7CB source supplied as an image.
// Candle 1 = shift 2; candle 2 = shift 1; candle 3 = signal candle.
// Candle 0 (shift 3) is declared in Pine but unused by its signal rules.
// Deliberately preserve asymmetric high/low comparisons from the source.
#property strict
#property version "2.32"
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
// Existing L/display inputs are retained; obsolete D-only inputs have been removed.
input group "00 — L FORECAST / DU BAO CO DIEU KIEN"
input int InpStartupBars=600; // 500..700 closed bars on attach / history reset
input bool InpBuyStatus=false; // show current closed-bar Buy diagnostics
input bool InpShowLStop=true; // SL line and price for latest L setups + forecast
input color InpLStopColor=clrOrangeRed;
input bool InpLForecast=true;
input int InpForecastLookback=80; // 30..200, closed bars only
input int InpForecastLife=12; // bars after publication, never extended
input int InpForecastMinScore=65; // heuristic points, NOT win probability
input bool InpSmartScoreFilter=false; // optional extra filter for actual L
input int InpSmartMinScore=60;

input group "01 — CHUNG / LICH SU ENTRY / CANH BAO"
input bool InpNewEffortEngine=true; // ON: chỉ chạy bộ mới; bỏ qua hoàn toàn bộ tín hiệu/lọc cũ
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
input bool InpContextHoverOnly=true; // Chỉ hiện dấu ⓘ; rê chuột để đọc bối cảnh
input double InpContextFarZoneATR=1.0; // Từ khoảng cách này ghi "xa vùng"

input group "12 — S-D / KEYLEVEL: DU LIEU BOI CANH"
input bool InpUseSupplyDemandContext=true;
input bool InpUseKeyLevelContext=true;
input bool InpDrawContextLevels=true; // Chỉ vẽ vùng/mốc của entry mới nhất, tối đa 6 object
input int InpZoneLookback=150; // Tìm vùng trên khung chart, tối đa 250 nến trước entry
input double InpZoneDepartureATR=1.0; // Rời vùng pivot >= 1 ATR để công nhận vùng
input double InpZoneNearATR=0.25; // Khoảng cách tối đa để coi entry gần vùng/mốc
input double InpZoneInvalidATR=0.05; // Đóng xuyên biên xa thêm 0.05 ATR: vùng hết hiệu lực

input group "13 — CHAT LUONG ENTRY / CHUYEN LUC"
input bool InpReadEntryQuality=true; // Phân tích chuỗi đẩy-hồi trên tooltip
input bool InpUseEntryQualityFilter=false; // Chỉ chặn ngược nhịp mạnh chưa đổi cấu trúc; các rủi ro khác chỉ cảnh báo
input bool InpEarlyForceTransitionAlerts=false; // Báo chuyển lực tại nến đóng nếu chất lượng đạt
input bool InpEarlyForceTransition=false; // Bổ sung tick chuyển lực engulfing sau cụm chững lại; chỉ nến đóng
input int InpQualityLookback=20; // 12..40 nến; chia đợt theo biến động Close
input double InpQualityPullbackATR=1.0; // Hồi đủ ATR mới tách nhịp chính; hồi nhỏ không đặt lại gốc
input bool InpQualityUseMTFRoom=false; // Kiểm tra vùng/key MTF đang bật trong bộ lọc chất lượng
input double InpQualityMaxRiskATR=2.0; // Khoảng bảo vệ cấu trúc tối đa/ATR
input double InpQualityMaxExtensionATR=2.5; // Khoảng chạy từ đầu đợt/ATR
input double InpQualityMinRoomRisk=1.2; // Khoảng trống tới vùng đối diện / khoảng bảo vệ

input group "14 — CHAN DOAN: MAC DINH OFF"
input int InpLDiagnosticsBars=300; // Giới hạn log ở N nến cuối, tránh tràn Experts
input bool InpLDiagnostics=false; // Log lý do từng nhánh tại đóng nến; mặc định OFF
input bool InpDebugSummary=false; // Full history diagnostics only when requested
input bool InpDebugNewBars=false; // Tam bat de kiem tra moi nen dong; tat sau khi chan doan

input group "15 — LEGACY C7CB: TUONG THICH BO CU"
input bool InpCompactContext=true; // Một câu ngắn ngay cạnh entry, không dùng bảng
input bool InpWickEarlyReaction=false; // Bao tai nen dong phan ung sau retest, khong doi pha ca cum
input bool InpGroupArrowsByRegion=false; // Mot bao dau + mot HL/LH cho moi vung, tick CB giu rieng
input double InpRegionDepartureATR=1.0; // Gia phai roi vung it nhat 1 ATR de mo chu ky moi
input double InpRegionNewExtremeATR=0.5; // Dinh/day moi cach vung cu it nhat 0.5 ATR
input bool InpWickOnRetestAllowed=false; // Rau tu choi o nen dau HOAC nen thu lai
input bool InpUseWickRetest=false; // Mac dinh tat nhom bo loc bo sung; chi dung bo loc C7CB goc
input bool InpWickRetestVolumeFilter=false; // Volume nen pha >= 0.8 EMA20 theo he so chung
input int InpWickRetestMaxBars=5; // Cum toi da 5 nen, toi thieu 3
input int InpWickExtremeLookback=3; // Nen rau tai cuc tri cua N nen truoc
input double InpWickMinRatio=0.35; // Rau tu choi >= 35% bien do nen
input double InpWickRetestTolerance=0.35; // Vung thu lai = 35% bien do nen rau
input double InpWickMaxSweep=0.25; // Cho phep quet qua cuc tri toi da 25% bien do
input bool InpUseStars=false; // Morning/Evening Star, high-volume signal candle
input bool InpUseEngulfing=false; // Body engulfing, high-volume signal candle
input double InpPatternHighVolumeFactor=1.0; // >=1.0 * SMA20 volume (includes signal candle)
input double InpStarSmallBodyFactor=0.5; // Middle body <= 50% of first body
input double InpStarPenetration=0.5; // Third close crosses 50% of first body
input bool InpUseC7CB=false; // Bat/tat rieng logic C7CB
input bool InpUseStructure12=false; // Mac dinh tat nhom bo loc bo sung; chi dung bo loc C7CB goc
input int InpStructureAnchorLookback=10; // Diem 1: cuc tri so voi N nen truoc
input int InpStructureATRPeriod=14;
input double InpStructureMinMoveATR=0.80; // Nhip bat/hoi toi thieu tu diem 1
input int InpStructureSwingBars=1; // 1: xac nhan diem 2 bang nen dong ke tiep
input int InpStructureMaxWait=20; // So nen toi da tu diem 1 den diem 2
input bool InpStructureVolumeEMAFilter=false; // Bo mui ten HL/LH neu volume nen xac nhan duoi nguong EMA20
input bool InpStructureVolumeFilter=false; // Volume hoi yeu va phuc hoi: tuy chon
input bool InpFilterLowVolumeDoji=false; // Loai CB khi vua than nho/doji vua volume thap
input double InpDojiMaxBodyRatio=0.25; // Than <= 25% bien do nen: nen than nho/doji
input bool InpRejectConsecutiveDojis=false; // Bo tin hieu neu nen truoc va nen tin hieu deu la doji
input double InpOriginalVolumeMinRisePercent=0.0; // Muc tang toi thieu cho nhanh volume tang dan
input int InpVolumeAveragePeriod=20; // SMA volume cua N nen truoc, khong gom nen CB
input bool InpUseCBVolumeEMAFilter=false; // Bo loc EMA rieng tuy chon; volume 3 nen co dieu kien rieng
input double InpVolumeEMAThresholdFactor=0.80; // Nguong volume = he so * EMA; 1.0 chat, 0.8 noi
input int InpCBVolumeEMAPeriod=20; // EMA20 volume, khong phai EMA gia
input double InpThreeBarHighVolumeFactor=1.0; // Neu volume khong tang: ca 3 nen >= he so * EMA20
input bool InpUseWideLowVolumeEntry=false; // Them mau 3 bien do tang dan, volume nen 3 thap nhat
input double InpWideLowVolumeWickBodyFactor=1.0; // Rau tu choi nen 3 phai dai hon than theo he so
input bool InpFilterEarlyTicks=false; // false: giu tick som, khong chan bang cum volume
input bool InpUseVolumeCluster=false; // Loc CB bang cum gia/volume suy yeu
input bool InpStrictVolumeFilter=false; // false: loc nhe; true: dieu kien chat v1.30
input int InpVolumeClusterBars=5; // Cum 3..5 nen, gom nen CB
input double InpMinVolumeDecline=0.05; // Do giam fitted / volume trung binh >= 5%
input bool InpConfirmVolumeRecovery=false; // Xac nhan can volume phuc hoi va nen dung huong
input double InpRecoveryVolumeFactor=1.0; // Volume xac nhan >= TB cum CB * he so
input bool InpEnableConfirmation=false;
input int InpConfirmationBars=3; // Maximum number of subsequent candles
input bool InpInvalidateOnOppositeClose=false;
input bool InpEnableConfirmationAlerts=false;
input bool InpEnablePush=false;
input bool InpClosedBarsOnly=false; // false matches Pine live-bar behavior

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
   datetime origin[250],phTime,plTime,lastTime;
   int side[250]; // 1=cầu, -1=cung
   bool hasPH,hasPL;
   double ph,pl,lastHigh,lastLow;
};
MTFContextCache MTFCache[48];
// Successful requests only; reused within ONE calculation/event pass at an identical cutoff.
// Failure is never memoized, so loading history can be retried immediately.
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
   if(InpNewEffortEngine) return type<=3;
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

// Chart-only visibility, upper right (SD then KL). Neutral/OFF on attach or reinitialization.
bool LiveSDOn=false,LiveKLOn=false;
int LiveSnapshotCount=0;
double LiveSnapshotATR=0,LiveSnapshotClose=0,LiveSnapshotPrevious=0;
datetime LiveSnapshotCutoff=0,LiveOriginTime[256];
void RefreshLevelButtons()
{
   if(Prefix=="" || !InpEnabled || !InpNewEffortEngine) return;
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

// Instance-scoped teardown: never delete another copy or user drawings.
bool IndicatorStopping=false,NewRenderDeferred=false;
bool DeleteOwnedChartObjects(const string owned)
{
   if(owned=="") return true; // Empty-prefix bulk deletion would wipe unrelated objects.
   ResetLastError();
   ObjectsDeleteAll(0,owned,-1,-1); // All subwindows and object types, this instance only.
   // Verify after the chart command queue is drained; retry individual remnants once.
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

int OnInit()
{
   if(InpStartupBars<500 || InpStartupBars>700) return INIT_PARAMETERS_INCORRECT;
   if(InpForecastLookback<30 || InpForecastLookback>200 || InpForecastLife<2 || InpForecastLife>100 ||
      InpForecastMinScore<0 || InpForecastMinScore>100 || InpSmartMinScore<0 || InpSmartMinScore>100)
      return INIT_PARAMETERS_INCORRECT;
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
   IndicatorSetString(INDICATOR_SHORTNAME,"C7CB PRO v2.27");
   Prefix="C7CB_PRO_"+IntegerToString((long)GetMicrosecondCount())+"_";
   LastClosed=0; FirstTime=0; ShownCount=0;
   LiveSDOn=false;LiveKLOn=false;LiveSnapshotCount=0;
   RefreshLevelButtons();
   ResetDisplayCache();
   // Keep the original C7CB marks visible; added modules are shown only when enabled.
   if(!InpUseStructure12)
      for(int p=4;p<8;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
   if(!InpUseWickRetest)
      for(int p=8;p<10;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
   if(!InpEnabled)
      for(int p=0;p<10;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
   if(InpNewEffortEngine)
   {
      IndicatorSetString(INDICATOR_SHORTNAME,"C7CB PRO v2.27 WE");
      PlotIndexSetString(0,PLOT_LABEL,"Buy limit setup (not fill)");
      PlotIndexSetString(1,PLOT_LABEL,"Sell limit setup (not fill)");
      PlotIndexSetString(2,PLOT_LABEL,"");
      PlotIndexSetString(3,PLOT_LABEL,"");
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_NONE); // L object carries the limit tooltip.
      PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_NONE);
      // Pro engine is L-only. Legacy bound buffers remain reserved and hidden.
      PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_NONE);
      PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_NONE);
      for(int k=4;k<10;k++) PlotIndexSetInteger(k,PLOT_DRAW_TYPE,DRAW_NONE);
   }
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   IndicatorStopping=true;
   string owned=Prefix;
   Prefix=""; // Prevent any rendering path from recreating objects during teardown.
   ResetNewEffortState();
   FreeMetricCache();NewRenderDeferred=false;LiveSnapshotCount=0;LiveSDOn=false;LiveKLOn=false;
   ResetDisplayCache();ResetStructure();
   LastClosed=0;FirstTime=0;ShownCount=0;
   DeleteOwnedChartObjects(owned);
   // Bound indicator buffers are released by MT5; do not ArrayFree runtime-owned buffers.
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
         if(!ObjectSetInteger(0,name,OBJPROP_FONTSIZE,7)) ok=false;
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
// v2.22: memoize exact prior-bar ATR/RV arithmetic; no rolling-sum drift.
// Cache rows are rebuilt on history reset and refreshed from prev-1 on live updates.
// Plain calculation arrays only; indicator buffers remain runtime-owned.
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
// Bộ đọc cấu trúc độc lập entry. Pivot chỉ dùng nếu đã được xác nhận trước nến đang đọc.
// Không sửa lịch sử tín hiệu. Giới hạn tìm pivot được công khai khi thiếu gốc.
// PRO 1.00 — causal research model. Event time is recognition time, never pivot time.
// References: wyckoffanalytics.com/wyckoff-method/; elliottwave.com/waveopedia/impulse/
// ================= CONTINUOUS CLOSE / STRUCTURE / EFFORT OWNERSHIP =================
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
   // Protected pivots become available only after two closed bars to their right.
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
         // Quiet established balance can end directional ownership without a forced reversal.
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
   // Increasing effort with collapsing result is NOT a fresh effective impulse.
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
// Direction ownership is independent of the schematic's age/first-test timeout.
// A new local SC/BC cannot silently erase a confirmed SOS/SOW.
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
// A bounded render book separates detection from MT5 object creation.
// History OFF retains only N records and draws once AFTER replay, avoiding create/delete per bar.
void UpdateWyMark(const string name,const string text,const color ink,const string tooltip)
{
   for(int n=ProObjectCount-1;n>=0;n--) if(WyDrawBook[n].name==name)
   { WyDrawBook[n].text=text;WyDrawBook[n].ink=ink;WyDrawBook[n].tooltip=tooltip;WyDrawBook[n].dirty=true;break; }
}
void RenderWyMarks()
{
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
// Independent OBSERVATION marks do not modify ProWy stage, bias, or entry filters.
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
   // Heavy-volume full-body climax is only a candidate until subsequent price responds.
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
      // Range opposite boundary is causal and can expand before ST, never after ST.
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
         // Compare the complete return against the breakout leg with one volume source.
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
// Impulse hypotheses at one degree. No internal 5-3-5-3-5 or diagonal claim.
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
   // Only simple zigzag-like ABC: A down, B below 5, C below A. Not flat/triangle/WXY.
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
   // Retain strongest completed hypothesis and a shorter alternate; no unique count assertion.
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
   // Chart observations are controlled by EventMarks/Wyckoff, independently of entry PRO filters.
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
   // Đỉnh xác nhận gần nhất là gốc nhịp từ đỉnh; đáy gần nhất là gốc nhịp từ đáy.
   // Nhịp hồi có thể ngược nền, không vì vậy tự đổi nền.
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
   // Sideway cần nhìn xuyên qua nhiều pivot nhỏ, không chỉ nhịp từ pivot gần nhất.
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
datetime QualityEntryCutoff(const int i)
{
   int shift=QualityChartCount-1-i;
   if(shift<0) return 0;
   datetime opened=iTime(_Symbol,_Period,shift);
   if(opened<=0) return 0;
   datetime nominal=opened+PeriodSeconds(_Period);
   return nominal<TimeCurrent()?nominal:TimeCurrent();
}
// v1.74: phân tích chuỗi có thứ tự. Không dùng nến sau i.
// Các đợt là chuỗi Close tăng/giảm liên tiếp, không phải pivot gắn ngược lịch sử.
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
bool EarlyForceTransition(const int i,const int direction,const double &open[],const double &high[],
                          const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(i<25) return false;
   bool real=UseRealWindow(i-24,i,volume);
   double rv=QualityRelativeVolume(i,real,ticks,volume);
   if(rv<1.0 || direction*(close[i]-open[i])<=0 || direction*(close[i-1]-open[i-1])>=0) return false;
   // Engulfing thân + đóng phá biên nến cuối: không chỉ đổi màu nến.
   bool engulf=direction>0?open[i]<=close[i-1] && close[i]>=open[i-1] && close[i]>high[i-1]:
                           open[i]>=close[i-1] && close[i]<=open[i-1] && close[i]<low[i-1];
   if(!engulf) return false;
   double atr=ContextATR(i,high,low,close);
   if(atr<=0 || -direction*(close[i-1]-close[i-5])<0.8*atr) return false;
   // Tìm volume cực đại trong 4 nến trước; phải chững lại rồi có nến đẩy thiếu volume.
   int peak=i-4;
   for(int j=i-3;j<i;j++)
      if((real?volume[j]:ticks[j])>(real?volume[peak]:ticks[peak])) peak=j;
   if(peak>=i-1 || QualityRelativeVolume(peak,real,ticks,volume)<1.3) return false;
   double body=MathAbs(close[peak]-open[peak]),otherBody=0;
   for(int j=i-4;j<i;j++) if(j!=peak) otherBody+=MathAbs(close[j]-open[j]);
   if(body>otherBody/3.0*0.8) return false;
   double pv=(double)(real?volume[peak]:ticks[peak]),last=(double)(real?volume[i-1]:ticks[i-1]);
   bool newExtreme=direction<0?high[i-1]>high[peak]:low[i-1]<low[peak];
   return last>0 && last<=pv*0.75 && newExtreme;
}
void EvaluateEntryQuality(const int i,const int direction,const double &open[],const double &high[],
                          const double &low[],const double &close[],const long &ticks[],const long &volume[],
                          EntryQuality &q)
{
   q.hardBlock=false;
   q.state=1;q.phase="Chưa đủ dữ liệu";q.reason="Cần lịch sử nhịp và MA20";
   q.transition=false;q.volumeKnown=false;q.risk=0;q.extension=0;q.room=-1;q.protect=0;q.runs=0;q.origin=i;q.clusterEdge=0;q.mtfMissing=false;
   int first=i-InpQualityLookback;
   if(first<20) return;
   double atr=ContextATR(i,high,low,close);
   if(atr<=0) return;
   bool real=UseRealWindow(first-20,i,volume);
   int dirs[41],starts[41],ends[41],nr=0;
   double moves[41],vols[41];
   bool known=true;
   for(int j=first;j<i;j++)
   {
      double delta=close[j]-close[j-1];int d=delta>0?1:delta<0?-1:0;
      double rv=QualityRelativeVolume(j,real,ticks,volume);
      if(rv<=0) known=false;
      if(d==0) { if(nr>0) { ends[nr-1]=j;vols[nr-1]+=rv; }continue; }
      if(nr==0 || dirs[nr-1]!=d)
      { dirs[nr]=d;starts[nr]=j;ends[nr]=j;moves[nr]=MathAbs(delta);vols[nr]=rv;nr++; }
      else { ends[nr-1]=j;moves[nr-1]+=MathAbs(delta);vols[nr-1]+=rv; }
   }
   q.runs=nr;q.volumeKnown=known && QualityRelativeVolume(i,real,ticks,volume)>0;
   q.transition=EarlyForceTransition(i,direction,open,high,low,close,ticks,volume);
   int last=-1,previous=-1;
   for(int k=nr-1;k>=0;k--) if(dirs[k]==direction)
   { if(last<0)last=k;else { previous=k;break; } }
   bool weak=false;
   if(previous>=0 && last>0 && previous>0)
   {
      double before=moves[previous-1]/MathMax(_Point,moves[previous]);
      double after=moves[last-1]/MathMax(_Point,moves[last]);
      weak=moves[last]<=0.75*moves[previous] && after>=before*1.2;
      // Nỗ lực theo hướng entry tăng nhưng tiến giá giảm cũng là mất hiệu quả.
      if(q.volumeKnown && vols[last]>=vols[previous] && moves[last]<=0.65*moves[previous]) weak=true;
   }
   double hi=high[i-1],lo=low[i-1];
   for(int j=i-5;j<i;j++) { hi=MathMax(hi,high[j]);lo=MathMin(lo,low[j]); }
   bool breakCluster=direction>0?close[i]>hi:close[i]<lo;
   double net=direction*(close[i-1]-close[i-4]),path=0;
   for(int j=i-3;j<i;j++)path+=MathAbs(close[j]-close[j-1]);
   bool strongOpposite=net<-atr && path>0 && -net/path>=0.65;
   q.state=0;q.phase="Đẩy/tiếp diễn có điều kiện";q.reason="Chưa gặp điều kiện chặn trong bộ kiểm tra";
   if(nr>=5) q.phase="Nhịp đẩy-hồi xen kẽ";
   if(weak && !breakCluster && !q.transition)
   { q.state=2;q.phase="Lực theo hướng entry mất hiệu quả";q.reason="Đợt đẩy tiến ít hơn, hồi đối ứng tăng; chưa đóng thoát cụm 5 nến"; }
   else if(strongOpposite && !breakCluster && !q.transition)
   { q.state=1;q.phase="Phản ứng ngược nhịp mạnh";q.reason="Chưa phá cụm để xác nhận chuyển lực"; }
   if(q.transition) { q.state=0;q.phase="Chuyển lực sau nỗ lực lớn/kết quả nhỏ";q.reason="Đẩy cuối volume giảm, engulfing đóng phủ nhận; vẫn kiểm tra giá vào"; }
   // Bảo vệ: pivot gần nhất đã xác nhận trước entry; fallback biên 5 nến.
   double protectedPrice=direction>0?lo:hi;
   int strength=InpContextSwingStrength;
   for(int p=i-1-strength;p>=MathMax(first,strength);p--)
   {
      bool pivot=true;
      for(int k=1;k<=strength;k++)
         if(direction>0 ? low[p]>=low[p-k] || low[p]>low[p+k] : high[p]<=high[p-k] || high[p]<high[p+k]) pivot=false;
      if(pivot) { protectedPrice=direction>0?low[p]:high[p];break; }
   }
   q.protect=direction>0?MathMin(protectedPrice,low[i]):MathMax(protectedPrice,high[i]);
   q.risk=MathAbs(close[i]-q.protect);
   // Nhịp chính dùng đảo chiều đủ ATR; một Close ngược nhỏ không đặt lại gốc.
   int waveDir=0,base=first-1,extremeIndex=base;
   double extreme=close[base],threshold=InpQualityPullbackATR*atr;
   for(int j=first;j<=i;j++)
   {
      if(waveDir==0)
      {
         if(close[j]-close[base]>=threshold) waveDir=1;
         else if(close[base]-close[j]>=threshold) waveDir=-1;
         if(waveDir!=0) { extreme=close[j];extremeIndex=j; }
      }
      else if(waveDir>0)
      {
         if(close[j]>=extreme) { extreme=close[j];extremeIndex=j; }
         else if(extreme-close[j]>=threshold)
         { base=extremeIndex;waveDir=-1;extreme=close[j];extremeIndex=j; }
      }
      else
      {
         if(close[j]<=extreme) { extreme=close[j];extremeIndex=j; }
         else if(close[j]-extreme>=threshold)
         { base=extremeIndex;waveDir=1;extreme=close[j];extremeIndex=j; }
      }
   }
   q.origin=base;
   q.extension=waveDir==direction?MathMax(0.0,direction*(close[i]-close[base])):0;
   // Cụm 5 nến trước: thân nhỏ, chồng lấn, Close tiến ít gần cực trị nhịp.
   double overlap=0,rangeSum=0,bodySum=0;
   for(int j=i-5;j<i;j++)
   {
      double r=high[j]-low[j];rangeSum+=r;bodySum+=MathAbs(close[j]-open[j]);
      if(j>i-5)
      {
         double common=MathMax(0.0,MathMin(high[j],high[j-1])-MathMax(low[j],low[j-1]));
         overlap+=common/MathMax(_Point,MathMin(r,high[j-1]-low[j-1]));
      }
   }
   double waveHigh=high[first],waveLow=low[first];
   for(int j=first;j<i;j++) { waveHigh=MathMax(waveHigh,high[j]);waveLow=MathMin(waveLow,low[j]); }
   bool nearExtreme=direction>0?waveHigh-hi<=0.35*atr:lo-waveLow<=0.35*atr;
   bool stalled=nearExtreme && overlap/4.0>=0.50 && rangeSum>0 && bodySum/rangeSum<=0.55 &&
                MathAbs(close[i-1]-close[i-5])<=0.65*atr;
   q.clusterEdge=direction>0?hi:lo;
   bool escaped=direction>0?close[i]>hi+0.05*atr:close[i]<lo-0.05*atr;
   if(stalled && !escaped && !q.transition)
   { q.state=MathMax(q.state,1);q.phase="Chững/giằng co tại cực trị nhịp";q.reason="Chưa đóng thoát biên cụm 5 nến; vượt đỉnh/đáy nến ứng viên là chưa đủ"; }
   EntryMarketContext market={};
   if(InpUseSupplyDemandContext) FindEntryZones(i,open,high,low,close,atr,market);
   bool obstacle=direction>0?market.supply:market.demand;
   if(obstacle)
      q.room=direction>0?MathMax(0.0,market.supplyLow-close[i]):MathMax(0.0,close[i]-market.demandHigh);
   // Cản đã biết trên chart: biên cụm/extreme phía trước giá, không cần vùng cung/cầu hợp lệ.
   double chartBarrier=direction>0?waveHigh:waveLow;
   double gap=direction*(chartBarrier-close[i]);
   if(gap>=0 && (q.room<0 || gap<q.room)) q.room=gap;
   // MTF chỉ nến nguồn đã đóng tại entry; 4 cache riêng, không chiếm 40 cache tooltip.
   // Timestamp được nạp theo index qua QualityTimes, cùng thứ tự oldest-first với OnCalculate.
   if(InpQualityUseMTFRoom)
   {
      datetime cutoff=QualityEntryCutoff(i);
      for(int tf=0;tf<4;tf++)
      {
         if(!MTFEnabled(tf) || (!InpMTFZones && !InpMTFKeyLevels)) continue;
         int cache=40+tf;
         if(cutoff<=0 || !LoadMTFContext(cache,MTFPeriod(tf),cutoff)) { q.mtfMissing=true;continue; }
         if(InpMTFZones) for(int z=0;z<MTFCache[cache].count;z++)
         {
            int side=MTFCache[cache].side[z];
            if(side==direction) continue;
            double zl=MTFCache[cache].lo[z],zh=MTFCache[cache].hi[z];
            double tolerance=InpZoneInvalidATR*MTFCache[cache].scale[z];
            if(direction>0?close[i]>zh+tolerance:close[i]<zl-tolerance) continue;
            double d=direction>0?MathMax(0.0,zl-close[i]):MathMax(0.0,close[i]-zh);
            if(q.room<0 || d<q.room) q.room=d;
         }
         if(InpMTFKeyLevels)
         {
            double keys[4];keys[0]=MTFCache[cache].lastHigh;keys[1]=MTFCache[cache].lastLow;
            keys[2]=MTFCache[cache].ph;keys[3]=MTFCache[cache].pl;
            for(int k=0;k<4;k++)
            {
               if(k==2 && !MTFCache[cache].hasPH) continue;
               if(k==3 && !MTFCache[cache].hasPL) continue;
               double d=direction*(keys[k]-close[i]);
               if(d>=0 && (q.room<0 || d<q.room)) q.room=d;
            }
         }
      }
   }
   if(q.risk<=_Point) { q.state=1;q.reason="Chưa có khoảng bảo vệ cấu trúc hợp lệ"; }
   else if(q.risk>InpQualityMaxRiskATR*atr)
   { q.state=2;q.reason="Khoảng bảo vệ cấu trúc quá xa; chờ hồi, không ép SL gần lại"; }
   else if(q.room>=0 && q.room/q.risk<InpQualityMinRoomRisk)
   { q.state=2;q.reason="Khoảng trống tới vùng đối diện không đủ so với khoảng bảo vệ"; }
   else if(q.extension>InpQualityMaxExtensionATR*atr)
   { q.state=MathMax(q.state,1);q.reason="Nhịp đã kéo xa; chờ hồi kiểm tra thay vì đuổi giá"; }
   if((q.mtfMissing || q.room<0) && q.state==0)
   { q.state=1;q.reason=q.mtfMissing?"Thiếu dữ liệu MTF đang bật; chưa duyệt khoảng trống":"Chưa xác định được cản đối diện; không coi là khoảng trống vô hạn"; }
   if(!q.volumeKnown && q.state==0)
   { q.state=1;q.reason="Thiếu volume để đánh giá chuỗi nỗ lực/kết quả"; }
   // Chế độ cân bằng: yếu tố rủi ro không được tự biến thành điều kiện loại tín hiệu.
   // Chỉ khóa ngược nhịp khi cả hướng Close, tính liên tục và cấu trúc cùng xác nhận.
   double oppositeMove=-direction*(close[i-1]-close[i-6]),travel=0;
   int against=0;
   for(int j=i-5;j<i;j++)
   {
      double delta=close[j]-close[j-1];travel+=MathAbs(delta);
      if(direction*delta<0) against++;
   }
   bool dominant=oppositeMove>=1.2*atr && travel>0 && oppositeMove/travel>=0.65 && against>=4;
   int structuralTrend=ContextTrend(i,high,low);
   q.hardBlock=dominant && structuralTrend==-direction && !breakCluster && !q.transition;
   if(q.hardBlock)
   {
      q.state=2;q.phase=direction<0?"Lực tăng và cấu trúc tăng còn hiệu lực":"Lực giảm và cấu trúc giảm còn hiệu lực";
      q.reason="Ngược nhịp mạnh, chưa đóng phá cụm để xác nhận đổi hướng";
   }
   else if(q.state==2) q.state=1; // SL xa/cản gần/suy yếu chỉ cảnh báo, không tự loại entry.
}
bool EntryQualityPass(const int i,const int direction,const double &open[],const double &high[],
                      const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   if(!InpUseEntryQualityFilter) return true;
   EntryQuality q;EvaluateEntryQuality(i,direction,open,high,low,close,ticks,volume,q);
   return !q.hardBlock;
}
string QualityTooltip(const int i,const int direction,const double &open[],const double &high[],const double &low[],
                       const double &close[],const long &ticks[],const long &volume[])
{
   if(!InpReadEntryQuality) return "";
   EntryQuality q;EvaluateEntryQuality(i,direction,open,high,low,close,ticks,volume,q);
   double atr=ContextATR(i,high,low,close);
   string result="\nCHẤT LƯỢNG ENTRY: "+(q.hardBlock?"Bỏ — ngược lực rõ":q.state==0?"Có thể xét":"Có thể xét — có cảnh báo")+
       "\nGiai đoạn: "+q.phase+" | "+IntegerToString(q.runs)+" đợt Close tăng/giảm."+
       "\nLý do: "+q.reason+".";
   if(atr>0 && q.risk>0)
      result+="\nBảo vệ cấu trúc: "+DoubleToString(q.protect,_Digits)+"; khoảng "+DoubleToString(q.risk/atr,2)+
              " ATR; đã đi "+DoubleToString(q.extension/atr,2)+" ATR từ gốc nhịp chính "+IntegerToString(i-q.origin)+" nến trước; biên cụm cần vượt "+DoubleToString(q.clusterEdge,_Digits)+"."+
              "\nKhoảng trống chart / bảo vệ: "+(q.room>=0?DoubleToString(q.room/q.risk,2):"chưa thấy vùng; không coi là vô hạn")+".";
   return result+"\nTick là ứng viên; bộ lọc chất lượng "+(InpUseEntryQualityFilter?"ON":"OFF")+
          "; chỉ ngược lực rõ mới chặn. Khoảng trống gồm chart"+(InpQualityUseMTFRoom?" và MTF đang bật":"")+"; chỉ dữ liệu đã biết tại entry.";
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
   if(cache<0 || cache>=48 || cutoff<=0) return false;
   int seconds=PeriodSeconds(tf);
   // Reuse only a proven closed-bar interval. No rounding across sessions/weekends.
   // Resets invalidate ready; failures remain retryable. Historical replay keeps its causal cutoff.
   if(MTFCache[cache].ready && seconds>0 &&
      cutoff>=MTFCache[cache].lastClosed+seconds && cutoff<MTFCache[cache].lastClosed+2*seconds)
      return true;
   if(MTFCache[cache].ready && MTFSuccessEpoch[cache]==MTFQueryEpoch && MTFSuccessCutoff[cache]==cutoff) return true;
   int shift=iBarShift(_Symbol,tf,cutoff-1,false);
   if(shift<0 || seconds<=0) return false;
   datetime opened=iTime(_Symbol,tf,shift);
   if(opened<=0) return false;
   if(opened+seconds>cutoff) shift++;
   // shift 0 là nến đang chạy tại hiện tại, tuyệt đối không dùng OHLC hoàn chỉnh của nó.
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
   // Nếu lịch sử đang tải thì thử lại ở lần cập nhật nến chart sau, không chặn bằng Sleep.
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
// Tooltip giao dịch ngắn; dữ liệu kỹ thuật chỉ xuất khi bật Debug Details.
string CompactQualityTip(const int slot,const int i,const int count,const int direction,
                         const datetime &time[],const double &open[],const double &high[],const double &low[],
                         const double &close[],const long &ticks[],const long &volume[])
{
   EntryQuality q;EvaluateEntryQuality(i,direction,open,high,low,close,ticks,volume,q);
   string verdict=q.hardBlock?"BỎ":q.state==0?"CÓ THỂ XÉT":"XÉT THẬN TRỌNG";
   string why=q.reason;
   if(StringFind(why,"Khoảng bảo vệ")>=0) why="SL theo cấu trúc quá xa";
   else if(StringFind(why,"Khoảng trống")>=0) why="gần cản, khoảng trống không đủ";
   else if(StringFind(why,"Nhịp đã")>=0) why="đã kéo xa, chờ hồi";
   else if(StringFind(why,"Chưa đóng thoát")>=0) why="chưa thoát cụm giằng co";
   else if(StringFind(why,"Đợt đẩy")>=0) why="đẩy yếu đi, hồi đối ứng tăng";
   else if(StringFind(why,"Chưa phá cụm")>=0) why="chưa xác nhận chuyển lực";
   else if(q.state==0) why="chưa gặp điều kiện chặn";
   else if(StringFind(why,"Thiếu")>=0 || StringFind(why,"lịch sử")>=0) why="thiếu dữ liệu xác nhận";
   else if(StringFind(why,"Chưa xác định")>=0) why="chưa đánh giá được cản đối diện";
   string place="",support="",barrier="";
   double ds=EMPTY_VALUE,db=EMPTY_VALUE,atr=ContextATR(i,high,low,close);
   // Dùng cùng snapshot tại entry, không lấy vùng hình thành sau tín hiệu.
   string ignored=BuildMTFTooltip(slot,i,count,direction,time,high,low,close);
   bool missing=false;
   for(int tf=0;tf<4;tf++) if(MTFEnabled(tf) && InpMTFZones)
   {
      int cache=slot*4+tf;
      if(!MTFCache[cache].ready || StringFind(ignored,MTFName(tf)+": thiếu")>=0) { missing=true;continue; }
      for(int z=0;z<MTFCache[cache].count;z++)
      {
         double lo=MTFCache[cache].lo[z],hi=MTFCache[cache].hi[z];int side=MTFCache[cache].side[z];
         double tolerance=InpZoneInvalidATR*MTFCache[cache].scale[z];
         if(side>0?close[i]<lo-tolerance:close[i]>hi+tolerance) continue;
         double d=EntryBandDistance(lo,hi,close[i],close[i]);
         string label=(side>0?"cầu ":"cung ")+MTFName(tf);
         if(side==direction && d<ds) { ds=d;support=label; }
         if(side!=direction && d<db) { db=d;barrier=label; }
      }
   }
   if(support!="") place+=(ds<=InpZoneNearATR*atr?"gần ":"xa ")+support;
   if(barrier!="") place+=(place!=""?"; ":"")+(db<=InpZoneNearATR*atr?"cản gần: ":"cản xa: ")+barrier;
   if(!InpMTFZones || (!InpMTF_M15 && !InpMTF_H1 && !InpMTF_H4 && !InpMTF_D1)) place="vùng MTF đang tắt";
   if(place=="") place=missing?"MTF chưa đủ dữ liệu":"chưa thấy vùng MTF phù hợp";
   else if(missing) place+="; thiếu một phần MTF";
   string reading="Nhịp trước: "+q.phase+".";
   if(InpPivotMarketReader)
   {
      PivotMarketReading m;ReadPivotMarket(i,open,high,low,close,ticks,volume,m);
      reading=PivotReaderDescription(m)+". Vol: "+m.volumeText+".";
   }
   return (direction>0?"BUY: ":"SELL: ")+verdict+" — "+why+".\n"+reading+"\nVị trí: "+place+".";
}
string CompactFollowTip(const int i,const int direction,const int count,const double &high[],const double &low[],const double &close[])
{
   string status=ContextFollowStatus(i,direction,count,high,low,close);
   if(StringFind(status,"Bị phủ nhận")>=0) return "Theo dõi: Bị phủ nhận — đóng xuyên biên bảo vệ.";
   if(StringFind(status,"Đã xác nhận")>=0) return "Theo dõi: Đã xác nhận vượt biên nến; vẫn xét chất lượng entry.";
   if(i==count-1) return "Theo dõi: Chưa xác nhận — nến đang chạy.";
   if(count-2-i>=InpContextFollowBars) return "Theo dõi: Chưa xác nhận.";
   return "Chờ: "+(direction>0?"đóng vượt đỉnh":"đóng dưới đáy")+" tín hiệu; vẫn xét cấu trúc và cản.";
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
         if(InpContextDebugDetails)
         {
            tip+=QualityTooltip(i,direction,open,high,low,close,tick_volume,volume);
            if(InpPivotMarketReader)
            {
               PivotMarketReading m;ReadPivotMarket(i,open,high,low,close,tick_volume,volume,m);
               tip+="\nPIVOT READER: "+PivotReaderDescription(m)+".\nVolume: "+m.volumeText+".\nQuan sát: "+m.advice;
               if(m.ready) tip+="\nGốc: "+TimeToString(time[m.anchor])+" (đã xác nhận trước entry); mốc bảo vệ "+
                  DoubleToString(m.protectedPrice,_Digits)+"; hiệu quả Close "+DoubleToString(m.efficiency,2)+
                  "; hồi lớn nhất "+DoubleToString(m.pullback,2)+" ATR; RVOL gần "+DoubleToString(m.relativeVolume,2);
            }
         }
         else tip=CompactQualityTip(slot,i,count,direction,time,open,high,low,close,tick_volume,volume);
         ContextBaseTips[slot]=tip;
      }
      if(InpContextDebugDetails)
      {
         tip+=BuildMTFTooltip(slot,i,count,direction,time,high,low,close);
         tip+="\n"+ContextFollowStatus(i,direction,count,high,low,close);
      }
      else tip+="\n"+CompactFollowTip(i,direction,count,high,low,close);
      string displayText=InpContextHoverOnly?"ⓘ":caption;
      bool ok=true;
      if(fresh)
      {
         if(!ObjectCreate(0,name,OBJ_TEXT,0,time[i],price)) continue;
         ContextNames[slot]=name;
         if(!ObjectSetString(0,name,OBJPROP_FONT,"Arial")) ok=false;
         if(!ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpContextHoverOnly?MathMax(7,InpContextFontSize):InpContextFontSize)) ok=false;
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
   if(MetricCacheReady && first>=0 && last>=first && last<MetricCacheCount)
      return CachedRealMissing[last]-(first>0?CachedRealMissing[first-1]:0)==0;
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
// ================= L ENGINE: CANDIDATES -> VALIDATION -> LIMIT SETUP =================
// Không gửi lệnh. OHLC chỉ biết vùng chạm; không chứng minh khớp lệnh hay thứ tự tick.
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
// Independent generators: a valid HL/LH or edge test does NOT need a new 20-bar extreme.
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
// A proposal is not an event: no chart object or pending order until commit.
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
   if(!notify || !InpNewAlerts) return;
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
// Adaptive L guard: a pause in an efficient trend is not a reversal.
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
   // Only pivots ALREADY confirmed before the candidate. Never identify its own bottom with future bars.
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
   // Broken support/resistance outranks the old HH/HL or LH/LL background.
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
// ================= STRUCTURAL TURN: BREAK -> DEPARTURE -> FIRST RETURN =================
// Uses only pivots known BEFORE the two breakout closes. A warning BC alone cannot unlock Sell.
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
      // A later, effective structural failure can retire a distant old SOS/SOW boundary.
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
   // Resuming the departure extreme consumes this first return; no second attempt at the same anchor.
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
   // A fresh decline cannot be bought just because the delayed pivot background still says up.
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
   // Continuation requires a tested prior swing or a held HL/LH, not just a matching old trend label.
   bool heldHigherLow=r.l1>=0 && side>0 && c.extreme>=low[r.l1]+InpLSwingToleranceATR*c.atr;
   bool heldLowerHigh=r.h1>=0 && side<0 && c.extreme<=high[r.h1]-InpLSwingToleranceATR*c.atr;
   if(continuation && (r.priorSwingTest || heldHigherLow || heldLowerHigh) &&
      response && (decisive || holds) && (!efficientFlow || r.failedBreak || fades || effortFails || holds))
   { why=r.description+"; hồi/test giữ cấu trúc, Close xác nhận thuận nhịp";return true; }
   bool stopEvidence=r.failedBreak || ((fades || effortFails) && r.priorSwingTest);
   if(stopEvidence && response && (decisive || holds))
   { why=r.description+"; nhịp cũ bị phủ nhận tại mốc trước, ứng viên đảo lực";return true; }
   // With no usable pivots, demand a substantial incoming leg + actual price/volume loss of efficiency.
   if(r.h1<0 && r.l1<0 && net>=InpLFlowMoveATR*c.atr && (fades || effortFails) && holds && response)
   { why="chưa đủ pivot; nhịp đi vào mất hiệu quả và hai Close giữ phản ứng";return true; }
   why=r.description+(efficientFlow?"; nhịp còn hiệu quả, chờ dừng/phủ nhận":"; chưa đủ cấu trúc test hoặc đảo lực");
   return false;
}

// Location registry: known before contact, qualified only after actual departure.
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
   // Merge same-role overlapping bands. Expanded geometry becomes known NOW, never at old born.
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
   // A wide candle crossing a level is not a test: its turning extreme must be at that location.
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
      // OPEN of contact bar: no complete HTF candle from inside/after this contact can define its level.
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
   // The only MA20 exception: a documented test at a known location, not an arbitrary low-volume candle.
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
         // Only unconfirmed candidates move. Keep original contact deadline bounded.
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

// ================= SELL ONLY: LOCAL TOP EXHAUSTION / REJECTION =================
// This exception belongs to one Sell setup. It NEVER clears or changes Buy ownership.
// Local Sell response, not a global trend reversal. Must survive the normal
// known-location proof plus two Close transitions, incoming-cluster break and effort failure.
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
   // Pine parity: rejection distance from the tested HIGH, not origin Close.
   // Two declining Close transitions still protect against the active Buy owner.
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
   // A known location alone cannot override an effective impulse. Require an actual
   // two-Close response through the preceding incoming candle, plus price/volume proof.
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
   // Any newly confirmed L of this side supersedes the queued candidate.
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

// Common final gate for ALL L routes; volume alone never replaces structural acceptance.
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

// ================= L: SHARED SELECTION / CYCLE OWNERSHIP =================
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
      // A new contact needs an intervening CLOSE departure, not just another nearby wick.
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
   // Chỉ khóa nến công bố L. Nến quét/test và các nến trước không bị ép vượt MA20.
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
   // Vùng từ chân nến quét đến mép thân gần chân; giới hạn bề rộng bằng ATR, không mặc định 50% nến.
   double width=MathMax(0.1*atr,MathMin(InpNewZoneMaxATR*atr,MathAbs(c.bodyEdge-c.extreme)+0.05*atr));
   e.zoneLow=c.side>0?c.extreme:c.extreme-width;
   e.zoneHigh=c.side>0?c.extreme+width:c.extreme;
   e.entry=c.side>0?e.zoneHigh:e.zoneLow;
   if(c.side*(close[i]-e.entry)<=0) { LTrace(slot,i,e.source,"Close còn ở sai phía vùng limit, chưa công bố",time);return false; } // Không treo limit sai phía thị trường.
   if(LSameCycle(c,i,high,low,close))
   { LTrace(slot,i,c.route,"cùng nhịp/vùng đã có L; chưa có nhịp rời và chạm lại độc lập",time);return false; }
   if(LCollecting)
   {
      // Location context wins over duplicate local patterns; advance is bounded to avoid chasing.
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
   // MTF vẫn cung cấp vị trí, không chặn bộ mới; chỉ dữ liệu có trước phản ứng.
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
   // Một lệnh chờ mỗi hướng, không chồng limit cùng hướng.
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
   // Phản ứng sau cú quét: kiểm tra trước khi tìm ứng viên mới.
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
   // Giá vẫn đẩy theo hướng cũ nhưng effort giảm, HOẶC volume cao mà có từ chối rõ.
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
   // Cú quét và phản ứng có thể hoàn tất trong cùng nến đã đóng, không dùng trước giờ đóng.
   if(side*(close[i]-level)>0 && side*(close[i]-open[i])>0 &&
      (side>0?loc>=0.7:loc<=0.3) && wick/range>=0.35)
   {
      CreateNewEvent(slot,i,time,open,high,low,close,ticks,volume,notify);
      NewCandidates[slot].active=false;
   }
}
// Separate optional path: exhaustion near a LOCAL extreme, not a relaxed 20-bar sweep.
void StepExhaustionL(const int slot,const int i,const datetime &time[],const double &open[],const double &high[],
                     const double &low[],const double &close[],const long &ticks[],const long &volume[],const bool notify)
{
   if(!InpProExhaustionL || i<30) return;
   int side=slot==0?1:-1;
   // Existing core gets priority. Never double-publish L on the same recognition bar.
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

// Cancel only STILL-PENDING contrary limits at this Close. Process this bar's range
// first: a fill earlier inside the SOS/SOW recognition bar must never be erased.
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

// ================= WYCKOFF FIRST TEST -> L LOCATION =================
// SOW prepares a SELL LPSY, not a speculative BUY bottom. SOS is mirrored.
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

// ================= CURRENT VALID LEVEL MAP (DISPLAY ONLY) =================
// Reserved cache 44..47: live drawing cannot alter entry's historical MTF caches.
struct LiveLevel { double lo,hi,atr,distance;int side,kind,source,mask;datetime known;string label;bool used; };
LiveLevel LiveLevels[1280];int LiveLevelCount=0,LiveDrawnCount=0;
string LiveSourceName(const int source)
{ return source==0?StringSubstr(EnumToString(_Period),7):MTFName(source-1); }
int LiveSourceSeconds(const int source)
{ return source==0?PeriodSeconds(_Period):PeriodSeconds(MTFPeriod(source-1)); }
string LiveTFText(const int mask)
{
   string result="";
   // Higher TF first, including the chart's own actual timeframe.
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
   // Merge only same-role, same-kind confluence from DIFFERENT source TFs.
   // Keep the larger TF's band and source origin; never union a broad and narrow zone.
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
   // Same-source duplicates are consolidated visually; the entry registry is untouched.
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
   // Current-valid selection drawn from the SOURCE origin to bar 0 for visual context.
   // These historical line segments do not backdate availability or trading signals.
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
   // Use actual chart timestamps so session gaps/weekends do not shift the bar offset.
   int shift=iBarShift(_Symbol,_Period,now,false);
   datetime labelTime=shift>=0?iTime(_Symbol,_Period,shift+InpLiveLabelOffsetBars):0;
   if(labelTime<=0) labelTime=now-(datetime)((long)MathMax(1,PeriodSeconds(_Period))*InpLiveLabelOffsetBars);
   if(ObjectFind(0,text)>=0 && ObjectGetInteger(0,text,OBJPROP_TYPE)!=OBJ_TEXT) ObjectDelete(0,text);
   if(ObjectFind(0,text)<0) ObjectCreate(0,text,OBJ_TEXT,0,labelTime,price);
   ObjectMove(0,text,0,labelTime,price);
   ObjectSetString(0,text,OBJPROP_TEXT,a.label);
   ObjectSetString(0,text,OBJPROP_FONT,"Arial");ObjectSetInteger(0,text,OBJPROP_FONTSIZE,InpLiveFontSize);
   // Label aligned 10 chart bars (configurable) to the left of bar 0; line geometry unchanged.
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
      // Hide endangered bands until role is resolved; a live chart Close must still respect them.
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
   // Deterministic nearest selection: reuse objects; remove obsolete ones every closed bar.
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

// Retain only the data needed to redraw existing levels on a click, without
// CopyRates/full-history replay or waiting for a market tick.
void RefreshLiveLevels(const int count,const datetime &time[],const double &high[],const double &low[],const double &close[])
{
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


// Forecast is observational. It never submits orders or bypasses existing L gates.
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
// A bounded, causal score shared by forecasts and optional actual-L filtering.
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
// Display only: uses the original structural stop; never sends or modifies orders.
void DrawLStop(const string name,const datetime begin,const datetime finish,const double stop,const bool active,const string label)
{
   string text=name+"_PRICE";
   if(!InpShowLStop) { ObjectDelete(0,name);ObjectDelete(0,text);return; }
   color ink=active?InpLStopColor:clrSilver;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,begin,stop,finish,stop);
   ObjectMove(0,name,0,begin,stop);ObjectMove(0,name,1,finish,stop);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   string caption=label+" "+DoubleToString(stop,_Digits);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,caption);
   if(ObjectFind(0,text)<0) ObjectCreate(0,text,OBJ_TEXT,0,finish,stop);
   ObjectMove(0,text,0,finish,stop);ObjectSetString(0,text,OBJPROP_TEXT,caption);
   ObjectSetInteger(0,text,OBJPROP_COLOR,ink);ObjectSetInteger(0,text,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,text,OBJPROP_ANCHOR,ANCHOR_LEFT);ObjectSetInteger(0,text,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,text,OBJPROP_HIDDEN,true);
}
void RefreshLStops()
{
   // Fixed five slots prevent accumulating SL objects over long histories.
   for(int slot=0;slot<5;slot++)
   {
      string name=Prefix+"LSTOP_"+IntegerToString(slot);
      int id=NewEventCount-1-slot;
      if(!InpShowLStop || id<0)
      { ObjectDelete(0,name);ObjectDelete(0,name+"_PRICE");continue; }
      NewEffortEvent e=NewEvents[id];
      datetime finish=e.knownStamp+(datetime)(InpNewLimitLife*PeriodSeconds(_Period));
      DrawLStop(name,e.knownStamp,finish,e.stop,e.state==0 || e.state==1,
                (e.side>0?"SL BUY":"SL SELL")+((e.state==0 || e.state==1)?"":" [CU]"));
   }
}

void DrawLForecast(const int slot,const datetime &time[],const int i)
{
   string name=Prefix+"LF_"+IntegerToString(slot),text=name+"_TEXT";
   if(!LF[slot].active) { ObjectDelete(0,name);ObjectDelete(0,text);ObjectDelete(0,name+"_SL");ObjectDelete(0,name+"_SL_PRICE");return; }
   LForecastState f=LF[slot];
   datetime begin=time[f.born]+PeriodSeconds(_Period);
   datetime finish=begin+(datetime)(InpForecastLife*PeriodSeconds(_Period));
   DrawLStop(name+"_SL",begin,finish,f.stop,true,"SL DU KIEN");
   color ink=f.side>0?clrSeaGreen:clrIndianRed;
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
   ObjectSetString(0,text,OBJPROP_TEXT,info);ObjectSetString(0,text,OBJPROP_TOOLTIP,tip);
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
         // Actual recognition time is e.bar, never backdated origin.
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
         // Known structural location and departure add evidence, without demanding a reversal candle yet.
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

void RenderBuyStatus(const int i,const datetime &time[],const double &open[],const double &high[],
                     const double &low[],const double &close[],const long &ticks[],const long &volume[])
{
   string lines[9];
   int total=0;for(int n=0;n<NewEventCount;n++) if(NewEvents[n].side>0) total++;
   string pro="";bool allowed=ProAllows(1,pro);
   lines[0]="BUY | "+TimeToString(time[i],TIME_DATE|TIME_MINUTES)+" | L lich su: "+IntegerToString(total);
   lines[1]=allowed?"PRO: cho phep Buy":"PRO: "+pro;
   bool real=UseRealWindow(i-25,i,volume);double rv=QualityRelativeVolume(i,real,ticks,volume);
   lines[2]="Vol/MA20="+DoubleToString(rv,2)+" | Impulse="+IntegerToString(ImpulseSide)+" | Smart="+
      IntegerToString(LSmartScore(1,i,open,high,low,close,ticks,volume))+"/100";
   lines[3]=InpLForecast?(LF[0].active?"Du kien Buy: "+LF[0].status:"Du kien Buy: chua co vung dat nguong "+IntegerToString(InpForecastMinScore)):"Du bao OFF";
   int routes[5]={0,1,3,4,5};
   for(int k=0;k<5;k++)
   { int r=routes[k];lines[4+k]=LRouteName(r)+": "+(LGeneratorWhy[r][0]==""?"khong co cap nhat tren nen nay":LGeneratorWhy[r][0]); }
   for(int k=0;k<9;k++)
   {
      string name=Prefix+"BUY_STATUS_"+IntegerToString(k);
      if(!InpBuyStatus) {ObjectDelete(0,name);continue;}
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,8);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,80+k*15);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(0,name,OBJPROP_COLOR,clrDarkGray);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetString(0,name,OBJPROP_TEXT,lines[k]);ObjectSetString(0,name,OBJPROP_TOOLTIP,lines[k]);
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
   if(changed && InpBuyStatus && count>30) RenderBuyStatus(count-2,time,open,high,low,close,ticks,volume);
   if(changed) RefreshLStops();
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
   if(InpNewEffortEngine)
   {
      if(!reset && NewProcessed==rates_total-2) return rates_total;
      ulong started=GetMicrosecondCount();int before=NewProcessed;
      if(InpEnabled) PrepareMetricCache(rates_total,prev_calculated,reset,high,low,close,tick_volume,volume);
      else if(MetricCacheReady) FreeMetricCache();
      int result=CalculateNewEffort(rates_total,prev_calculated,reset,time,open,high,low,close,tick_volume,volume);
      if(reset || (InpDebugNewBars && NewProcessed>before))
      {
         int buys=0,sells=0;
         for(int n=0;n<NewEventCount;n++) if(NewEvents[n].side>0) buys++;else sells++;
         Print("C7CB PERF v2.32 | bars=",rates_total," | calc_ms=",DoubleToString((double)(GetMicrosecondCount()-started)/1000.0,1),
               " | L Buy=",buys," Sell=",sells," | diagnostics=",InpLDiagnostics?"ON":"OFF");
      }
      return result;
   }
   if(MetricCacheReady) FreeMetricCache();
   bool changed=reset;
   if(reset) ResetPro();
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
      if(ConfirmedBuy[i]!=EMPTY_VALUE && !EntryQualityPass(i,1,open,high,low,close,tick_volume,volume)) ConfirmedBuy[i]=EMPTY_VALUE;
      if(ConfirmedSell[i]!=EMPTY_VALUE && !EntryQualityPass(i,-1,open,high,low,close,tick_volume,volume)) ConfirmedSell[i]=EMPTY_VALUE;
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
      if(allowed && closed && InpEarlyForceTransition)
      {
         reversalBuy=reversalBuy || EarlyForceTransition(i,1,open,high,low,close,tick_volume,volume);
         reversalSell=reversalSell || EarlyForceTransition(i,-1,open,high,low,close,tick_volume,volume);
      }
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
      bool qualityArm=(buy || sell) && EntryQualityPass(i,buy?1:-1,open,high,low,close,tick_volume,volume);
      if(closed && InpEnableConfirmation && qualityArm)
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
   RefreshLiveMarketReader(rates_total,time,open,high,low,close,tick_volume,volume);
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
      PrintFormat("C7CB v1.74 | bars=%d raw3=%d vol3_pass=%d vol3_block=%d CB=%d confirmed=%d structure=%d retest=%d wick=%d group=%s history=%s latest=%s",
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
         if((StructBuy[c]!=EMPTY_VALUE || StructSell[c]!=EMPTY_VALUE) &&
            EntryQualityPass(c,StructBuy[c]!=EMPTY_VALUE?1:-1,open,high,low,close,tick_volume,volume))
         {
            string msg=StringFormat("C7CB SIGNAL 1 HH/LL %s | %s %s | %s",StructBuy[c]!=EMPTY_VALUE?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(msg);
            if(InpEnablePush) SendNotification(msg);
         }
         if((RetestBuy[c]!=EMPTY_VALUE || RetestSell[c]!=EMPTY_VALUE) &&
            EntryQualityPass(c,RetestBuy[c]!=EMPTY_VALUE?1:-1,open,high,low,close,tick_volume,volume))
         {
            string msg=StringFormat("C7CB SIGNAL 2 HL/LH %s | %s %s | %s",RetestBuy[c]!=EMPTY_VALUE?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(msg);
            if(InpEnablePush) SendNotification(msg);
         }
         if((WickBuy[c]!=EMPTY_VALUE || WickSell[c]!=EMPTY_VALUE) &&
            EntryQualityPass(c,WickBuy[c]!=EMPTY_VALUE?1:-1,open,high,low,close,tick_volume,volume))
         {
            string msg=StringFormat("C7CB WICK RETEST %s | %s %s | %s",WickBuy[c]!=EMPTY_VALUE?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
            if(InpEnableConfirmationAlerts) Alert(msg);
            if(InpEnablePush) SendNotification(msg);
         }
         if(InpEarlyForceTransition && InpEarlyForceTransitionAlerts)
         {
            int early=Up[c]!=EMPTY_VALUE && EarlyForceTransition(c,1,open,high,low,close,tick_volume,volume)?1:
                      Down[c]!=EMPTY_VALUE && EarlyForceTransition(c,-1,open,high,low,close,tick_volume,volume)?-1:0;
            if(early!=0 && EntryQualityPass(c,early,open,high,low,close,tick_volume,volume))
            {
               string earlyMessage=StringFormat("C7CB EARLY FORCE TRANSITION %s | %s %s | %s",
                  early>0?"BUY":"SELL",_Symbol,EnumToString(_Period),TimeToString(time[c],TIME_DATE|TIME_MINUTES));
               if(InpEnableConfirmationAlerts) Alert(earlyMessage);
               if(InpEnablePush) SendNotification(earlyMessage);
            }
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
   if(InpEnabled)
   {
      for(int j=MathMax(26,ProLast+1);j<rates_total-1;j++)
         StepPro(j,time,open,high,low,close,tick_volume,volume);
      RenderWyMarks();
   }
   return rates_total;
}

// Cập nhật vị trí nhận tooltip khi zoom/đổi tỉ lệ chart, không quét lại tín hiệu.
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(IndicatorStopping) return;
   if(!InpEnabled || !InpNewEffortEngine) return;
   MTFQueryEpoch++;
   if(id==CHARTEVENT_OBJECT_CLICK && (sparam==Prefix+"BTN_SD" || sparam==Prefix+"BTN_KL"))
   {
      if(sparam==Prefix+"BTN_SD")
      {
         LiveSDOn=!LiveSDOn;
         // KL-only snapshots omit S/D construction. Reload visual caches on enable.
         if(LiveSDOn) for(int tf=0;tf<4;tf++) MTFCache[44+tf].ready=false;
      }
      else LiveKLOn=!LiveKLOn;
      RefreshLevelButtons();RefreshLiveLevelSnapshot();ChartRedraw(0);return;
   }
   if(id!=CHARTEVENT_CHART_CHANGE) return;
   RefreshLevelButtons();RefreshLiveLevelSnapshot();
   // L/Wy objects are time/price anchored and follow zoom/scroll automatically.
   // Never resend all historical labels to the synchronous chart queue on zoom.
}
