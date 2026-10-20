//+------------------------------------------------------------------+
//|                                    EMA9 SL/TP MANAGER LIGHT v5.94 |
//| Copyright 2026, PVTHOI.      Invisible Guard Tool - Optimized    |
//| V5.94: EMA9 only; one position pass; minimal handles / UI updates   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, PVTHOI"
#property link      "https://www.mql5.com"
#property version   "5.94"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "--- CẤU HÌNH QUẢN LÝ LỆNH ---"
input bool     InpShowResumeButton = true; // OFF: giữ nút ON; false = ẩn hoàn toàn, bật lại qua Inputs
input bool     InpAutoEnabled = true;     // ON/OFF toàn bộ quản lý tự động khi khởi động
input bool     InpManageAllMagic = true; // false: chỉ quản lý magic được chọn (0 = lệnh tay)
input bool     InpLockProfit = true;      // Trailing SL phải vượt giá vào lệnh
input int      InpMinTrailPoints = 10;    // Bước dời SL tối thiểu
input int      InpRetrySeconds = 3;       // Chờ lại sau lỗi máy chủ / chốt từng phần
input int      InpSLUpdateMs = 250;        // Nhịp gửi dời SL tối thiểu (ms)
input int      InpSignalRefreshMs = 250;   // Chờ đọc lại EMA khi dữ liệu chưa sẵn sàng (ms)
input ulong    InpMagicNumber  = 0;        // Magic quản lý; 0 = lệnh tay nếu ManageAllMagic=false
input int      InpSlippage     = 50;       // Độ trượt giá (Points)
input bool     InpDebugMode    = false;    // Bật log debug chi tiết trong tab Experts

input group "--- KHOẢNG CÁCH BAN ĐẦU (POINTS) ---"
input bool     InpUseInitialSL = true;     // Bật/Tắt tự động gán Stop Loss ban đầu
input bool     InpUseInitialTP = false;    // Bật/Tắt tự động gán Take Profit ban đầu
input int      InpSLOffset     = 3000;    // Khoảng cách dừng lỗ gốc (đơn vị point của symbol)
input int      InpTPOffset     = 10000;    // Khoảng cách chốt lời gốc (đơn vị point của symbol)

input group "--- EMA9: SL / TP / BE DƯƠNG ---"
input bool     InpUseEMASL = true;         // ON/OFF SL bám EMA9; OFF = không tự trailing
input bool     InpUseEMATP = true;         // ON/OFF chốt lệnh khi EMA9 gấp ngược chiều
input bool     InpUsePositiveBE = true;    // ON/OFF BE dương khi nến tiếp diễn và đủ lãi
input ENUM_TIMEFRAMES InpEMATimeframe = PERIOD_CURRENT; // Khung EMA9; CURRENT = khung chart
input int      InpEMAPeriod = 9;           // Chu kỳ EMA
input int      InpEMAAtrPeriod = 14;       // ATR chuẩn hóa góc, không phụ thuộc zoom
input double   InpEMAAngleScale = 4.0;     // Độ nhạy góc chuẩn hóa ATR; tăng = nhạy hơn
input double   InpEMATPAngle = 160.0;      // Góc trong <= mức này + đổi dốc + đóng qua EMA
input double   InpEMASLBufferPrice = 0.30; // SL cách EMA theo đơn vị GIÁ
input bool     InpEMASLAfterBE = true;     // true: BE dương trước, sau đó SL bám EMA
input double   InpBETriggerPrice = 2.0;    // Lãi chênh GIÁ tối thiểu để xét BE
input double   InpBEOffsetPrice = 0.20;    // BUY Entry+offset; SELL Entry-offset, chưa tính phí
input double   InpEMATPMinProfitPrice = 0.0; // Chỉ TP khi giá thoát đang lãi hơn mức này

input group "--- CẤU HÌNH CHỐT LỜI TỪNG PHẦN (PARTIAL CLOSE) ---"
input bool     InpUsePartialClose   = false;  // Bật/Tắt Chốt lời từng phần (Partial Close)
input double   InpPartialTriggerUSD = 25.0;   // Mức lãi GIÁ USD từ giá vào lệnh để chốt từng phần
input double   InpPartialPercent    = 50.0;   // % Khối lượng chốt lời (Ví dụ: 50%)

input group "--- CẤU HÌNH HỆ THỐNG THÔNG BÁO ---"
input bool     InpSendAlert    = false;     // Bật thông báo Alert (Popup + Âm thanh trên PC)
input bool     InpSendPush     = false;    // Bật thông báo Push Notification (Gửi về App điện thoại)

input group "--- CÀI ĐẶT BẢNG GIAO DIỆN ---"
input int      InpTableX       = 340;       
input int      InpTableY       = 1;      

//--- Biến toàn cục
CTrade trade;
string PrefixID         = "BIAS_PANEL_";
string PrefixGV_PARTIAL = "EMA_PARTIAL_";
bool auto_enabled = false;
bool gui_dirty=false;
int cleanup_ticks=0;
bool ema_sl_enabled=false,ema_tp_enabled=false,positive_be_enabled=false;
int ema_handle=INVALID_HANDLE,ema_atr_handle=INVALID_HANDLE;
datetime ema_cache_bar=0,ema_ignore_tp_bar=0,ema_closed_time=0;
ulong ema_cache_attempt=0;
bool ema_cache_valid=false,ema_buy_turn=false,ema_sell_turn=false;
bool ema_buy_continue=false,ema_sell_continue=false;
double ema_last=0,ema_inner_angle=180;

double NormalizePrice(double price) {
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size == 0) tick_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return MathRound(price / tick_size) * tick_size;
}

//+------------------------------------------------------------------+
//| HÀM CHUẨN HÓA KHỐI LƯỢNG CHỐT LỜI HỢP LỆ VỚI SÀN                 |
//+------------------------------------------------------------------+
double GetPartialCloseVolume(double current_volume, double percent) {
   double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double raw_vol = current_volume * (percent / 100.0);
   double close_vol = raw_vol;
   
   if(step_vol > 0) {
      close_vol = MathFloor(raw_vol / step_vol) * step_vol;
   }
   
   if(current_volume - close_vol < min_vol) {
      close_vol = current_volume - min_vol;
      if(step_vol > 0) close_vol = MathFloor(close_vol / step_vol) * step_vol;
   }
   
   if(close_vol < min_vol) return 0.0;
   return NormalizeDouble(close_vol, 8);
}

//+------------------------------------------------------------------+
//| HÀM GỬI THÔNG BÁO TÙY CHỌN (ON/OFF NOTIFICATION)                 |
//+------------------------------------------------------------------+
void SendCustomAlert(string text) {
   if(InpSendAlert) Alert(text);
   if(InpSendPush)  SendNotification(text);
}

//+------------------------------------------------------------------+
//| HÀM TẠO NHÃN TEXT                                                |
//+------------------------------------------------------------------+
void CreateLabel(string name,string text,int x,int y,color clr,int size=10) {
   string obj=PrefixID+name;
   if(ObjectFind(0,obj)<0) {
      ObjectCreate(0,obj,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,obj,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,size);
      ObjectSetString(0,obj,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,y);
      gui_dirty=true;
   }
   if(ObjectGetString(0,obj,OBJPROP_TEXT)!=text) { ObjectSetString(0,obj,OBJPROP_TEXT,text); gui_dirty=true; }
   if(ObjectGetInteger(0,obj,OBJPROP_COLOR)!=clr) { ObjectSetInteger(0,obj,OBJPROP_COLOR,clr); gui_dirty=true; }
}
void CreateButton(string name,string text,int x,int y,int width,int height,color bg,color clr) {
   string obj=PrefixID+name;
   if(ObjectFind(0,obj)<0) {
      ObjectCreate(0,obj,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,obj,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,9); ObjectSetString(0,obj,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,obj,OBJPROP_XSIZE,width); ObjectSetInteger(0,obj,OBJPROP_YSIZE,height);
      ObjectSetInteger(0,obj,OBJPROP_STATE,false); ObjectSetInteger(0,obj,OBJPROP_COLOR,clr);
      gui_dirty=true;
   }
   if(ObjectGetString(0,obj,OBJPROP_TEXT)!=text) { ObjectSetString(0,obj,OBJPROP_TEXT,text); gui_dirty=true; }
   if(ObjectGetInteger(0,obj,OBJPROP_BGCOLOR)!=bg) { ObjectSetInteger(0,obj,OBJPROP_BGCOLOR,bg); gui_dirty=true; }
}

bool IsStopsValid(ulong ticket, double new_sl, double target_tp, long pos_type, bool priority=false) {
   if(!PositionSelectByTicket(ticket)) return false;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=0) return false;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) tick=point;
   double old_sl=PositionGetDouble(POSITION_SL), old_tp=PositionGetDouble(POSITION_TP);
   bool change_sl=MathAbs(new_sl-old_sl)>=tick*0.5;
   bool change_tp=MathAbs(target_tp-old_tp)>=tick*0.5;
   if(!change_sl && !change_tp) return false;
   double stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   double freeze=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point;
   double min_dist=MathMax(stops,freeze)+tick;
   double side=(pos_type==POSITION_TYPE_BUY?1.0:-1.0);
   double price=(side>0?q.bid:q.ask);
   if(old_sl>0 && freeze>0 && side*(price-old_sl)<=freeze) return false;
   if(old_tp>0 && freeze>0 && side*(old_tp-price)<=freeze) return false;
   if(change_sl) {
      if(new_sl<=0 || side*(price-new_sl)<min_dist) return false;
      if(old_sl>0 && side*(new_sl-old_sl)<(priority?tick:MathMax(tick,InpMinTrailPoints*point))) return false;
   }
   if(change_tp && (target_tp<=0 || side*(target_tp-price)<min_dist)) return false;
   return true;
}

// Rate limit per position; successful trade must be confirmed by the server.
struct Attempt { ulong ticket; ulong modify_at; ulong partial_at; ulong close_at; ulong blocked_until; };
Attempt attempts[];
int AttemptIndex(ulong ticket) {
   for(int i=0;i<ArraySize(attempts);i++) if(attempts[i].ticket==ticket) return i;
   int n=ArraySize(attempts);
   if(ArrayResize(attempts,n+1)!=n+1) return -1;
   attempts[n].ticket=ticket; attempts[n].modify_at=0;
   attempts[n].partial_at=0; attempts[n].close_at=0; attempts[n].blocked_until=0;
   return n;
}
bool CanAttempt(ulong ticket,bool partial=false) {
   int i=AttemptIndex(ticket); if(i<0) return false;
   ulong now=GetTickCount64();
   if(now<attempts[i].blocked_until) return false;
   ulong last=partial?attempts[i].partial_at:attempts[i].modify_at;
   ulong delay=partial?(ulong)InpRetrySeconds*1000:(ulong)InpSLUpdateMs;
   if(last>0 && now-last<delay) return false;
   if(partial) attempts[i].partial_at=now; else attempts[i].modify_at=now;
   return true;
}
void BackoffTrade(ulong ticket,uint rc) {
   if(rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL || rc==TRADE_RETCODE_NO_CHANGES) return;
   int i=AttemptIndex(ticket); if(i<0) return;
   ulong delay=(ulong)InpRetrySeconds*1000;
   // Price-dependent rejections can be retried at the next allowed SL refresh.
   if(rc==TRADE_RETCODE_REQUOTE || rc==TRADE_RETCODE_PRICE_CHANGED ||
      rc==TRADE_RETCODE_PRICE_OFF || rc==TRADE_RETCODE_INVALID_STOPS) delay=(ulong)InpSLUpdateMs;
   attempts[i].blocked_until=GetTickCount64()+delay;
}
bool ConfirmTrade(bool sent,ulong ticket) {
   uint rc=trade.ResultRetcode();
   bool ok=sent && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL);
   BackoffTrade(ticket,rc);
   if(!ok && InpDebugMode) PrintFormat("Trade #%I64u: %u %s",ticket,rc,trade.ResultRetcodeDescription());
   return ok;
}
bool ModifyPosition(ulong ticket,double sl,double tp,bool priority=false) {
   // Recheck the latest quote and selected position immediately before sending.
   if(!PositionSelectByTicket(ticket)) return false;
   if(!IsStopsValid(ticket,sl,tp,PositionGetInteger(POSITION_TYPE),priority)) return false;
   if(!CanAttempt(ticket)) return false;
   return ConfirmTrade(trade.PositionModify(ticket,sl,tp),ticket);
}
bool ClosePartial(ulong ticket,double volume) {
   // CTrade partial close is supported for hedging. Netting is deliberately skipped.
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return false;
   if(!CanAttempt(ticket,true)) return false;
   return ConfirmTrade(trade.PositionClosePartial(ticket,volume),ticket);
}
// EMA logic uses three CLOSED EMA points and a fixed ATR scale for both segments.
ENUM_TIMEFRAMES EMATF() { return InpEMATimeframe==PERIOD_CURRENT?_Period:InpEMATimeframe; }
bool AnyEMAManagement() { return ema_sl_enabled || ema_tp_enabled || positive_be_enabled; }
void ResetEMACache() {
   ema_cache_bar=0; ema_cache_attempt=0; ema_cache_valid=false;
   ema_last=0; ema_inner_angle=180; ema_closed_time=0;
   ema_buy_turn=false; ema_sell_turn=false;
   ema_buy_continue=false; ema_sell_continue=false;
}
void ReleaseEMA() {
   if(ema_handle!=INVALID_HANDLE) IndicatorRelease(ema_handle);
   if(ema_atr_handle!=INVALID_HANDLE) IndicatorRelease(ema_atr_handle);
   ema_handle=INVALID_HANDLE; ema_atr_handle=INVALID_HANDLE;
   ResetEMACache(); ema_ignore_tp_bar=0;
}
bool EnsureEMA() {
   if(!AnyEMAManagement()) return true;
   if(ema_handle==INVALID_HANDLE)
      ema_handle=iMA(_Symbol,EMATF(),InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(!ema_tp_enabled && ema_atr_handle!=INVALID_HANDLE) { IndicatorRelease(ema_atr_handle); ema_atr_handle=INVALID_HANDLE; }
   if(ema_tp_enabled && ema_atr_handle==INVALID_HANDLE)
      ema_atr_handle=iATR(_Symbol,EMATF(),InpEMAAtrPeriod);
   if(ema_handle==INVALID_HANDLE || (ema_tp_enabled && ema_atr_handle==INVALID_HANDLE)) {
      ReleaseEMA(); Print("Không nạp được EMA/ATR; chức năng EMA không bật."); return false;
   }
   return true;
}
// Pure predicates: 180 degrees = straight line; smaller = a sharper bend.
double EMAInnerAngle(double previous,double current,double atr,double scale) {
   if(atr<=0) return 180.0;
   double a=MathArctan(previous/atr*scale),b=MathArctan(current/atr*scale);
   return 180.0-MathAbs(b-a)*180.0/3.14159265358979323846;
}
bool EMATurnSignal(double side,double previous,double current,double angle,double threshold,
                   double close,double ema) {
   return side*previous>0 && side*current<0 && angle<=threshold && side*(close-ema)<0;
}
bool EMAContinuation(double side,double previous_close,double close,double open,
                     double ema,double slope) {
   return side*(close-previous_close)>0 && side*(close-open)>0 &&
          side*(close-ema)>0 && side*slope>0;
}
bool RefreshEMA() {
   datetime bar=iTime(_Symbol,EMATF(),0);
   if(bar<=0) return false;
   if(ema_cache_valid && ema_cache_bar==bar) return true;
   ulong now=GetTickCount64();
   if(ema_cache_attempt>0 && now-ema_cache_attempt<(ulong)InpSignalRefreshMs) return false;
   ema_cache_attempt=now;
   ema_cache_valid=false;
   double e[3],a[1]; MqlRates r[2];
   // Fixed arrays are chronological: e[0]=bar3, e[2]=bar1; r[1]=bar1.
   if(CopyBuffer(ema_handle,0,1,3,e)!=3 || (ema_tp_enabled && CopyBuffer(ema_atr_handle,0,1,1,a)!=1) ||
      CopyRates(_Symbol,EMATF(),1,2,r)!=2) { ema_cache_valid=false; return false; }
   for(int k=0;k<3;k++) if(!MathIsValidNumber(e[k]) || e[k]==EMPTY_VALUE || e[k]<=0) return false;
   if(!ema_tp_enabled) a[0]=1.0;
   if(!MathIsValidNumber(a[0]) || a[0]<=0 || a[0]==EMPTY_VALUE) return false;
   if(iTime(_Symbol,EMATF(),0)!=bar || r[1].time!=iTime(_Symbol,EMATF(),1)) return false;
   double previous=e[1]-e[0],current=e[2]-e[1];
   ema_last=e[2]; ema_closed_time=r[1].time+(datetime)PeriodSeconds(EMATF());
   ema_inner_angle=EMAInnerAngle(previous,current,a[0],InpEMAAngleScale);
   // Never close on a pre-existing turn immediately after attachment/ON/toggling TP.
   ema_buy_turn=ema_tp_enabled && bar!=ema_ignore_tp_bar && EMATurnSignal(1,previous,current,ema_inner_angle,InpEMATPAngle,r[1].close,ema_last);
   ema_sell_turn=ema_tp_enabled && bar!=ema_ignore_tp_bar && EMATurnSignal(-1,previous,current,ema_inner_angle,InpEMATPAngle,r[1].close,ema_last);
   ema_buy_continue=EMAContinuation(1,r[0].close,r[1].close,r[1].open,ema_last,current);
   ema_sell_continue=EMAContinuation(-1,r[0].close,r[1].close,r[1].open,ema_last,current);
   ema_cache_bar=bar; ema_cache_valid=true; return true;
}
bool CloseEMAPosition(ulong ticket) {
   int i=AttemptIndex(ticket); if(i<0) return false;
   ulong now=GetTickCount64();
   if(now<attempts[i].blocked_until || (attempts[i].close_at>0 && now-attempts[i].close_at<(ulong)InpSLUpdateMs)) return false;
   attempts[i].close_at=now;
   return ConfirmTrade(trade.PositionClose(ticket),ticket);
}
// Một lượt quét/tick. Ưu tiên TP đảo chiều, sau đó gộp SL ban đầu/BE/EMA thành một yêu cầu.
void ManagePositions() {
   bool ema_ready=AnyEMAManagement() && RefreshEMA();
   MqlTick q; if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=0) return;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tick<=0) tick=point;
   if(tick<=0 || point<=0) return;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(!InpManageAllMagic && (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double side=type==POSITION_TYPE_BUY?1.0:-1.0;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN),old=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP),volume=PositionGetDouble(POSITION_VOLUME);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      long identifier=PositionGetInteger(POSITION_IDENTIFIER);
      double price=side>0?q.bid:q.ask,profit=side*(price-entry);
      bool turn=ema_ready && (side>0?ema_buy_turn:ema_sell_turn);
      if(ema_tp_enabled && turn && opened<ema_closed_time && profit>InpEMATPMinProfitPrice) {
         if(CloseEMAPosition(ticket)) SendCustomAlert("EMA9 TP: #"+(string)ticket);
         continue; // Không chốt từng phần / sửa SL cùng tick với TP.
      }
      bool need_sl=InpUseInitialSL && old==0;
      bool need_tp=InpUseInitialTP && tp==0;
      double proposed=need_sl?NormalizePrice(entry-side*InpSLOffset*point):old;
      double target_tp=need_tp?NormalizePrice(entry+side*InpTPOffset*point):tp;
      bool be_priority=false;
      if(ema_ready) {
         double raw_be=entry+side*InpBEOffsetPrice;
         double be=NormalizeDouble((side>0?MathCeil(raw_be/tick):MathFloor(raw_be/tick))*tick,_Digits);
         bool protected_be=old>0 && side*(old-be)>=-tick*0.1;
         bool continuation=side>0?ema_buy_continue:ema_sell_continue;
         if(positive_be_enabled && !protected_be && continuation && profit>=InpBETriggerPrice && opened<ema_closed_time) {
            if(proposed<=0 || side*(be-proposed)>0) { proposed=be; be_priority=true; }
         }
         // BE phải đã được máy chủ xác nhận; EMA chỉ bám từ tick tiếp theo.
         if(ema_sl_enabled && (!InpEMASLAfterBE || !positive_be_enabled || protected_be)) {
            double raw=ema_last-side*InpEMASLBufferPrice;
            double ema_sl=NormalizeDouble((side>0?MathFloor(raw/tick):MathCeil(raw/tick))*tick,_Digits);
            if(ema_sl>0 && (!InpLockProfit || side*(ema_sl-entry)>0) &&
               (proposed<=0 || side*(ema_sl-proposed)>0)) proposed=ema_sl;
         }
      }
      bool sl_changed=MathAbs(proposed-old)>=tick*0.5;
      bool tp_changed=MathAbs(target_tp-tp)>=tick*0.5;
      if(sl_changed || tp_changed) {
         // TP ban đầu không hợp lệ không được cản SL bảo vệ hợp lệ.
         if(need_tp && !IsStopsValid(ticket,proposed,target_tp,type,be_priority) &&
            IsStopsValid(ticket,proposed,tp,type,be_priority)) target_tp=tp;
         if(ModifyPosition(ticket,proposed,target_tp,be_priority) && need_sl)
            SendCustomAlert("Initial/protective SL: #"+(string)ticket);
      }
      // Chốt từng phần tùy chọn, mặc định OFF; không cần lượt quét thứ hai.
      if(InpUsePartialClose && profit>=InpPartialTriggerUSD &&
         AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
         string marker=PrefixGV_PARTIAL+(string)identifier;
         if(!GlobalVariableCheck(marker)) {
            double close_volume=GetPartialCloseVolume(volume,InpPartialPercent);
            if(close_volume>0 && ClosePartial(ticket,close_volume)) {
               GlobalVariableSet(marker,1.0);
               SendCustomAlert("Partial close: #"+(string)ticket);
            }
         } else GlobalVariableGet(marker);
      }
   }
}

void CleanupGlobalVariables() {
   for(int j=ArraySize(attempts)-1;j>=0;j--) {
      if(!PositionSelectByTicket(attempts[j].ticket)) ArrayRemove(attempts,j,1);
   }
   // Partial-close markers retain their stable position identifier across OFF/ON.

}
void UpdatePanelGUI()
{
   if(!auto_enabled) return;
   ENUM_TIMEFRAMES timeframes[5] =
   {
      PERIOD_M1,
      PERIOD_M5,
      PERIOD_M15,
      PERIOD_H1,
      PERIOD_H4
   };

   string tf_names[5] =
   {
      "M1",
      "M5",
      "M15",
      "H1",
      "H4"
   };

   int y = InpTableY;
   CreateButton("BTN_AUTO",auto_enabled?"AUTO ON":"AUTO OFF",InpTableX+715,MathMax(0,y-3),95,24,
                auto_enabled?clrForestGreen:clrFireBrick,clrWhite);

   //===============================================================
   // TITLE
   //===============================================================
   CreateLabel(
      "TITLE",
      "BIAS " + _Symbol + " == ",
      InpTableX,
      y,
      clrWhite,
      10
   );

   //===============================================================
   // CÁC VỊ TRÍ CỐ ĐỊNH
   //===============================================================
   int x_tf[5] =
   {
      InpTableX + 190,
      InpTableX + 290,
      InpTableX + 390,
      InpTableX + 490,
      InpTableX + 590
   };

   //===============================================================
   // TIMEFRAME + BIAS
   //===============================================================
   for(int i = 0; i < 5; i++)
   {
      MqlRates rates[1];

      string bias_str = "N/A";
      color  bias_clr = clrDarkGray;

      if(CopyRates(_Symbol, timeframes[i], 0, 1, rates) > 0)
      {
         bias_str="SIDE";
         if(rates[0].close > rates[0].open)
         {
            bias_str = "UP";
            bias_clr = clrLimeGreen;
         }
         else
         if(rates[0].close < rates[0].open)
         {
            bias_str = "DOWN";
            bias_clr = clrCrimson;
         }
      }

      CreateLabel("TF_"+tf_names[i],tf_names[i]+":",x_tf[i],y,clrLightGray,9);
      int status_offset=(tf_names[i]=="M15"?41:34);
      CreateLabel("VAL_"+tf_names[i],bias_str,x_tf[i]+status_offset,y,bias_clr,9);

   }

   //===============================================================
   // BUTTONS
   //===============================================================
   int btn_x = InpTableX + 815;
   CreateButton("BTN_SL9",ema_sl_enabled?"SL9 ON":"SL9 OFF",InpTableX+715,y+28,82,24,ema_sl_enabled?clrForestGreen:clrDimGray,clrWhite);
   CreateButton("BTN_TP9",ema_tp_enabled?"TP9 ON":"TP9 OFF",InpTableX+802,y+28,82,24,ema_tp_enabled?clrForestGreen:clrDimGray,clrWhite);
   CreateButton("BTN_BE",positive_be_enabled?"BE+ ON":"BE+ OFF",InpTableX+889,y+28,82,24,positive_be_enabled?clrForestGreen:clrDimGray,clrWhite);

   CreateButton(
      "BTN_CLOSE_ALL",
      "Close All",
      btn_x,
      MathMax(0,y - 3),
      80,
      24,
      clrChocolate,
      clrWhite
   );

   CreateButton(
      "BTN_CLOSE_PROFIT",
      "C Profit",
      btn_x + 95,
      MathMax(0,y - 3),
      80,
      24,
      clrForestGreen,
      clrWhite
   );

   CreateButton(
      "BTN_CLOSE_LOSS",
      "C Loss",
      btn_x + 190,
      MathMax(0,y - 3),
      75,
      24,
      clrCrimson,
      clrWhite
   );

   if(gui_dirty) { ChartRedraw(0); gui_dirty=false; }
}
//+------------------------------------------------------------------+
//| HÀM XỬ LÝ ĐÓNG LỆNH THEO NHÓM                                    |
//+------------------------------------------------------------------+
void ActionClosePositions(string mode) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
            if(!InpManageAllMagic && (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(mode == "ALL")                       ConfirmTrade(trade.PositionClose(ticket),ticket);
            else if(mode == "PROFIT" && profit > 0) ConfirmTrade(trade.PositionClose(ticket),ticket);
            else if(mode == "LOSS" && profit < 0)   ConfirmTrade(trade.PositionClose(ticket),ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BẮT SỰ KIỆN CLICK NÚT TRÊN PANEL                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam,PrefixID)==0) {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      if(sparam == PrefixID + "BTN_AUTO") {
         SetAutoEnabled(!auto_enabled);
      }
      else if(auto_enabled && (sparam==PrefixID+"BTN_SL9" || sparam==PrefixID+"BTN_TP9" || sparam==PrefixID+"BTN_BE")) {
         bool old_sl=ema_sl_enabled,old_tp=ema_tp_enabled,old_be=positive_be_enabled;
         if(sparam==PrefixID+"BTN_SL9") ema_sl_enabled=!ema_sl_enabled;
         if(sparam==PrefixID+"BTN_TP9") {
            ema_tp_enabled=!ema_tp_enabled;
            ema_ignore_tp_bar=iTime(_Symbol,EMATF(),0); ResetEMACache();
         }
         if(sparam==PrefixID+"BTN_BE") positive_be_enabled=!positive_be_enabled;
         if(!EnsureEMA()) { ema_sl_enabled=old_sl; ema_tp_enabled=old_tp; positive_be_enabled=old_be; }
         if(!AnyEMAManagement()) ReleaseEMA();
         UpdatePanelGUI();
      }
      else if(auto_enabled && sparam == PrefixID + "BTN_CLOSE_ALL") {
         ActionClosePositions("ALL");
         ObjectSetInteger(0, PrefixID + "BTN_CLOSE_ALL", OBJPROP_STATE, false);
      }
      else if(auto_enabled && sparam == PrefixID + "BTN_CLOSE_PROFIT") {
         ActionClosePositions("PROFIT");
         ObjectSetInteger(0, PrefixID + "BTN_CLOSE_PROFIT", OBJPROP_STATE, false);
      }
      else if(auto_enabled && sparam == PrefixID + "BTN_CLOSE_LOSS") {
         ActionClosePositions("LOSS");
         ObjectSetInteger(0, PrefixID + "BTN_CLOSE_LOSS", OBJPROP_STATE, false);
      }
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| INITIALIZATION / DEINITIALIZATION                                |
//+------------------------------------------------------------------+
int OnInit() {
   if(InpSlippage<0 || InpRetrySeconds<1 || InpSLUpdateMs<100 || InpSignalRefreshMs<100 ||
      InpMinTrailPoints<0 || (InpUseInitialSL && InpSLOffset<=0) ||
      (InpUseInitialTP && InpTPOffset<=0) || (InpUsePartialClose &&
      (InpPartialTriggerUSD<=0 || InpPartialPercent<=0 || InpPartialPercent>=100))) return INIT_PARAMETERS_INCORRECT;
   ema_sl_enabled=InpUseEMASL; ema_tp_enabled=InpUseEMATP; positive_be_enabled=InpUsePositiveBE;
   if(InpEMAPeriod<2 || InpEMAAtrPeriod<2 || InpEMAAngleScale<=0 || InpEMATPAngle<=0 ||
      InpEMATPAngle>=180 || InpEMASLBufferPrice<0 || InpBETriggerPrice<=0 ||
      InpBEOffsetPrice<=0 || InpEMATPMinProfitPrice<0) return INIT_PARAMETERS_INCORRECT;
   auto_enabled=false;
   PrefixID="GL590_"+(string)ChartID()+"_";
   // Account-scoped state; stable position identifier survives ticket changes.
   uint server_hash=0;
   string server=AccountInfoString(ACCOUNT_SERVER);
   for(int k=0;k<StringLen(server);k++) server_hash=server_hash*31+(uint)StringGetCharacter(server,k);
   string scope=(string)server_hash+"_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+(string)InpMagicNumber+"_";
   PrefixGV_PARTIAL="GL590_P_"+scope;
   trade.SetAsyncMode(false);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   if(!SetAutoEnabled(InpAutoEnabled)) return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void ReleaseRuntime() {
   EventKillTimer(); ReleaseEMA(); ArrayFree(attempts);
   cleanup_ticks=0; gui_dirty=false;
}

bool AcquireRuntime() {
   if(!EnsureEMA()) return false;
   ema_ignore_tp_bar=iTime(_Symbol,EMATF(),0);
   if(!EventSetTimer(1)) { Print("Không thể khởi tạo timer; AUTO vẫn OFF."); return false; }
   return true;
}

void ShowOffState() {
   ObjectsDeleteAll(0,PrefixID);
   if(InpShowResumeButton)
      CreateButton("BTN_AUTO","AUTO OFF",InpTableX+715,MathMax(0,InpTableY-3),95,24,clrFireBrick,clrWhite);
   ChartRedraw(0);
}

bool SetAutoEnabled(bool enabled) {
   auto_enabled=false; // gate queued events before releasing resources
   ReleaseRuntime();
   ObjectsDeleteAll(0,PrefixID);
   if(!enabled) { ShowOffState(); return true; }
   if(!AcquireRuntime()) { ReleaseRuntime(); ShowOffState(); return false; }
   auto_enabled=true;
   UpdatePanelGUI();
   return true;
}

void OnDeinit(const int reason) {
   auto_enabled=false;
   ReleaseRuntime();
   ObjectsDeleteAll(0,PrefixID);
   ChartRedraw(0);
}

void OnTick() {
   if(!auto_enabled || PositionsTotal()==0 || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return;
   ManagePositions();
}

void OnTimer() {
   if(!auto_enabled) return;
   UpdatePanelGUI();
   if(++cleanup_ticks>=30) { CleanupGlobalVariables(); cleanup_ticks=0; } 
}