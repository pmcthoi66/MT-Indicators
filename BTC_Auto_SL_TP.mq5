//+------------------------------------------------------------------+
//|                                    BTC AUTO SL / BE+ / EMA9 / TP v5.90 |
//| Copyright 2026, PVTHOI.      One Pass / Closed EMA / Verified Trade Results    |
//| V5.90: SL ban đầu -> BE dương -> EMA9; TP góc chuẩn hóa ATR |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, PVTHOI"
#property link      "https://www.mql5.com"
#property version   "5.90"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
// Các khoảng USD dưới đây là biến động GIÁ, không phải tiền lãi tài khoản.
input group "--- QUẢN LÝ VỊ THẾ ---"
input ulong InpMagicNumber=0;            // Chỉ dùng bộ lọc Magic này khi InpManageAllMagic=false
input bool InpManageAllMagic=true;      // true = mọi Magic trên symbol của chart
input bool InpEnabled=true;             // Tự động quản lý ON/OFF ban đầu
input int InpSlippage=50;                // Trượt giá tối đa, points
input bool InpDebugMode=false;           // Log lỗi giao dịch trong Experts

input group "--- SL / TP BAN ĐẦU ---"
input bool InpUseInitialSL=true;         // Tự thêm SL cho vị thế chưa có SL
input bool InpInitialSLUseEMA9=true;     // Kết hợp EMA9; không rộng hơn khoảng SL points bên dưới
input int InpSLOffset=20000;             // Khoảng SL tối đa = input * Point của sàn
input bool InpUseInitialTP=false;         // Tự thêm TP cố định khi vị thế chưa có TP
input int InpTPOffset=40000;             // Khoảng TP cố định = input * Point của sàn

input group "--- BE DƯƠNG ---"
input bool InpUseBreakEven=true;         // Dời SL qua giá vào khi đạt ngưỡng
input double InpBETriggerUSD=100.0;      // Giá chạy có lợi 100 đơn vị giá để kích hoạt
input double InpBEOffsetUSD=5.0;         // Khóa 5 đơn vị giá trên/dưới entry; chưa tính phí

input group "--- BÁM EMA9 SAU BE ---"
input bool InpUseEMATrailing=true;       // Chỉ bám EMA sau khi SL đã đạt BE dương
input double InpEMASLBufferUSD=20.0;     // BUY: EMA trừ buffer; SELL: EMA cộng buffer
input int InpMinTrailStepPoints=50;      // Bước cải thiện SL tối thiểu, points
input int InpModifyIntervalMs=250;       // Khoảng nghỉ sửa SL liên tiếp; BE không phải chờ khoảng này
input int InpFailedRetryMs=1000;         // Khoảng chờ khi máy chủ từ chối một yêu cầu

input group "--- CHỐT LỜI GÓC EMA9 ---"
input bool InpUseEMAAngleTP=true;        // Chốt toàn bộ khi EMA bẻ ngược chiều, có lãi và góc <= ngưỡng
input double InpTPAngleDegrees=160.0;    // Góc trong; 180 = thẳng, 160 = đổi hướng ít nhất 20 độ
input bool InpTPRequirePriceConfirm=true; // BUY: nến đóng dưới EMA; SELL: nến đóng trên EMA
input int InpATRPeriod=14;               // ATR chuẩn hóa góc; không phụ thuộc zoom chart
input ENUM_TIMEFRAMES InpEMATimeframe=PERIOD_CURRENT; // Khung EMA9 và ATR dùng quản lý lệnh

input group "--- CHỐT MỘT PHẦN ---"
input bool InpUsePartialClose=false;     // Mặc định OFF; chỉ hỗ trợ tài khoản hedging
input double InpPartialTriggerUSD=100.0; // Ngưỡng biến động giá có lợi
input double InpPartialPercent=50.0;     // Phần trăm lot chốt, một lần mỗi vị thế

input group "--- BẢNG BIAS VÀ THÔNG BÁO ---"
input bool InpShowPanel=true;            // Hiện bảng màu nến đóng và các nút
input int InpTableX=340;                 // Vị trí ngang của bảng
input int InpTableY=1;                   // Vị trí dọc của bảng
input bool InpSendAlert=false;           // Popup trên máy tính
input bool InpSendPush=false;            // Thông báo điện thoại

CTrade trade;
string PrefixID, StatePrefix;
double point_size,tick_size;
bool auto_on,sl_on,be_on,ema_on,tp_on,partial_on;
bool ui_dirty=false, cleanup_due=true,scan_pending=true;
ulong last_scan=0,last_panel_refresh=0,last_trade_error=0;
int ema_handle=INVALID_HANDLE,atr_handle=INVALID_HANDLE;
datetime ema_bar=0;
ulong data_retry=0,last_cleanup=0;
bool ema_ready=false;
double ema_price=0,ema_close=0,ema_slope=0,ema_prev_slope=0,ema_angle=180;
datetime ema_signal_time=0;
struct AttemptState
{
   ulong id;
   ulong last_modify;
   ulong retry_modify;
   ulong retry_close;
   bool history_checked;
};
AttemptState attempts[];
int StateIndex(ulong id)
{
   for(int i=0;i<ArraySize(attempts);i++) if(attempts[i].id==id) return i;
   int n=ArraySize(attempts);ArrayResize(attempts,n+1);
   attempts[n].id=id;attempts[n].last_modify=0;attempts[n].retry_modify=0;
   attempts[n].retry_close=0;attempts[n].history_checked=false;
   return n;
}

bool ManagedPosition()
{
   return PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (InpManageAllMagic || (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber);
}
string StateKey(string kind, ulong id) { return StatePrefix+kind+(string)id; }
uint HashText(string value)
{
   uint h=2166136261;
   for(int i=0;i<StringLen(value);i++) { h^=(uint)StringGetCharacter(value,i); h*=16777619; }
   return h;
}
double NormalizePrice(double price, bool upward=false)
{
   double units=price/tick_size;
   return NormalizeDouble((upward ? MathCeil(units-1e-8) : MathFloor(units+1e-8))*tick_size,_Digits);
}
bool ValidPrice(double p) { return MathIsValidNumber(p) && p>0 && p!=EMPTY_VALUE; }
bool TradingAllowed()
{
   return TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
          AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
}
bool CheckedResult(bool sent, string action, ulong ticket, bool allow_partial=false)
{
   uint code=trade.ResultRetcode();
   bool ok=sent && (code==TRADE_RETCODE_DONE || (allow_partial && code==TRADE_RETCODE_DONE_PARTIAL));
   if(!ok && (InpDebugMode || last_trade_error==0 || GetTickCount64()-last_trade_error>=10000))
   {
      PrintFormat("%s #%I64u: retcode=%u (%s), error=%d",action,ticket,code,trade.ResultRetcodeDescription(),GetLastError());
      last_trade_error=GetTickCount64();
   }
   return ok;
}
double GetPartialCloseVolume(double volume, double percent)
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(step<=0 || minimum<=0) return 0;
   double v=MathFloor(volume*percent/100.0/step+1e-8)*step;
   v=MathMin(v,MathFloor((volume-minimum)/step+1e-8)*step);
   v=NormalizeDouble(v,8);
   if(v<minimum-1e-8 || volume-v<minimum-1e-8 || v>=volume) return 0;
   return v;
}

//+------------------------------------------------------------------+
//| HÀM GỬI THÔNG BÁO TÙY CHỌN (ON/OFF NOTIFICATION)                 |
//+------------------------------------------------------------------+
void SendCustomAlert(string text) {
   if(InpSendAlert) {
      Alert(text);
   }
   if(InpSendPush) {
      SendNotification(text);
   }
}

//+------------------------------------------------------------------+
//| HÀM TẠO NHÃN TEXT                                                |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size=10) {
   string objName = PrefixID + name;
   if(ObjectFind(0,objName)>=0 && ObjectGetString(0,objName,OBJPROP_TEXT)==text &&
      (color)ObjectGetInteger(0,objName,OBJPROP_COLOR)==clr &&
      ObjectGetInteger(0,objName,OBJPROP_XDISTANCE)==x && ObjectGetInteger(0,objName,OBJPROP_YDISTANCE)==y) return;
   ui_dirty=true;
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
//| HÀM TẠO NÚT BẤM (BUTTON)                                         |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int width, int height, color bg_clr, color txt_clr) {
   string objName = PrefixID + name;
   if(ObjectFind(0,objName)>=0)
   {
      if(ObjectGetInteger(0,objName,OBJPROP_XDISTANCE)==x && ObjectGetInteger(0,objName,OBJPROP_YDISTANCE)==y &&
         ObjectGetInteger(0,objName,OBJPROP_XSIZE)==width && ObjectGetInteger(0,objName,OBJPROP_YSIZE)==height) return;
      ObjectSetInteger(0,objName,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,objName,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,objName,OBJPROP_XSIZE,width);ObjectSetInteger(0,objName,OBJPROP_YSIZE,height);
      ui_dirty=true;return;
   }
   ui_dirty=true;
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);   
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);  
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg_clr);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, txt_clr);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

// Chỉ đọc EMA9 / ATR trên nến đã đóng, một lần mỗi nến và dùng chung cho mọi vị thế.
double InnerAngle(double previous,double current)
{
   return 180.0-MathAbs(MathArctan(current)-MathArctan(previous))*180.0/M_PI;
}
bool AdverseTurn(bool buy,double previous,double current,double angle)
{
   return angle<=InpTPAngleDegrees && (buy ? previous>0 && current<previous : previous<0 && current>previous);
}
void SyncEMAHandles()
{
   bool need=auto_on && ((sl_on && InpInitialSLUseEMA9) || ema_on || tp_on);
   if(!need)
   {
      if(ema_handle!=INVALID_HANDLE) IndicatorRelease(ema_handle);
      if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle);
      ema_handle=INVALID_HANDLE;atr_handle=INVALID_HANDLE;ema_ready=false;ema_bar=0;
      return;
   }
   if(ema_handle==INVALID_HANDLE) ema_handle=iMA(_Symbol,InpEMATimeframe,9,0,MODE_EMA,PRICE_CLOSE);
   if(tp_on && atr_handle==INVALID_HANDLE) atr_handle=iATR(_Symbol,InpEMATimeframe,InpATRPeriod);
   if(!tp_on && atr_handle!=INVALID_HANDLE) { IndicatorRelease(atr_handle);atr_handle=INVALID_HANDLE; }
}
void CacheEMA()
{
   datetime bar=iTime(_Symbol,InpEMATimeframe,0);
   if(bar==0 || ema_handle==INVALID_HANDLE) { ema_ready=false;return; }
   if(ema_ready && bar==ema_bar) return;
   ema_ready=false;
   ulong now=GetTickCount64();
   if(data_retry!=0 && now-data_retry<1000) return;
   data_retry=now;
   double e[],a[];MqlRates r[];
   ArraySetAsSeries(e,true);ArraySetAsSeries(a,true);ArraySetAsSeries(r,true);
   if(CopyBuffer(ema_handle,0,1,3,e)!=3 || CopyRates(_Symbol,InpEMATimeframe,1,1,r)!=1) return;
   for(int j=0;j<3;j++) if(!ValidPrice(e[j])) return;
   double scale=1;
   if(tp_on)
   {
      if(atr_handle==INVALID_HANDLE || CopyBuffer(atr_handle,0,1,1,a)!=1 || !ValidPrice(a[0])) return;
      scale=a[0];
   }
   ema_price=e[0];ema_close=r[0].close;ema_signal_time=r[0].time;
   ema_slope=(e[0]-e[1])/scale;ema_prev_slope=(e[1]-e[2])/scale;
   ema_angle=InnerAngle(ema_prev_slope,ema_slope);
   ema_bar=bar;ema_ready=true;
}
// EMA dùng đặt SL ban đầu nhưng không tăng khoảng rủi ro hơn SL points đã cấu hình.
double InitialSL(bool buy,double open,double market)
{
   double fixed=open+(buy ? -1.0 : 1.0)*InpSLOffset*point_size;
   double result=fixed;
   if(InpInitialSLUseEMA9 && ema_ready)
   {
      double candidate=ema_price+(buy ? -InpEMASLBufferUSD : InpEMASLBufferUSD);
      double distance=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                              (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*point_size+tick_size;
      if((buy ? market-candidate : candidate-market)>=distance)
         result=(buy ? MathMax(fixed,candidate) : MathMin(fixed,candidate));
   }
   return NormalizePrice(result,!buy);
}

// Kiểm tra cả SL/TP giữ nguyên; SL bằng giá cũ không được chặn việc thêm TP.
bool IsStopsValid(ulong ticket, double sl, double tp, long type)
{
   if(!PositionSelectByTicket(ticket) || !MathIsValidNumber(sl) || !MathIsValidNumber(tp) || sl<0 || tp<0) return false;
   MqlTick q; if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=0) return false;
   double old_sl=PositionGetDouble(POSITION_SL), old_tp=PositionGetDouble(POSITION_TP);
   double eps=tick_size*0.25;
   bool cs=MathAbs(sl-old_sl)>eps, ct=MathAbs(tp-old_tp)>eps;
   if(!cs && !ct) return false;
   if(old_sl>0 && (sl==0 || (cs && (type==POSITION_TYPE_BUY ? sl<old_sl : sl>old_sl)))) return false;
   double stops=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point_size;
   double freeze=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point_size;
   double market=(type==POSITION_TYPE_BUY ? q.bid : q.ask);
   double sign=(type==POSITION_TYPE_BUY ? 1.0 : -1.0);
   if(sl>0 && sign*(market-sl)<MathMax(stops,freeze)+tick_size-eps) return false;
   if(tp>0 && sign*(tp-market)<MathMax(stops,freeze)+tick_size-eps) return false;
   // Một mức cũ đang bị freeze có thể làm toàn bộ yêu cầu modify bị từ chối.
   if(freeze>0 && ((old_sl>0 && sign*(market-old_sl)<=freeze+eps) ||
                  (old_tp>0 && sign*(old_tp-market)<=freeze+eps))) return false;
   return true;
}
bool ModifyStops(ulong ticket,int state,double sl,double tp,string reason,bool throttle=false)
{
   ulong now=GetTickCount64();
   if(now<attempts[state].retry_modify ||
      (throttle && attempts[state].last_modify!=0 && now-attempts[state].last_modify<(ulong)InpModifyIntervalMs) ||
      !PositionSelectByTicket(ticket)) return false;
   long type=PositionGetInteger(POSITION_TYPE);
   if(!IsStopsValid(ticket,sl,tp,type)) return false;
   attempts[state].last_modify=now;ResetLastError();
   bool sent=trade.PositionModify(ticket,sl,tp);
   if(!CheckedResult(sent,reason,ticket))
   { attempts[state].retry_modify=now+(ulong)InpFailedRetryMs;return false; }
   if(!PositionSelectByTicket(ticket) || MathAbs(PositionGetDouble(POSITION_SL)-sl)>tick_size*0.5 ||
      MathAbs(PositionGetDouble(POSITION_TP)-tp)>tick_size*0.5)
   { attempts[state].retry_modify=now+(ulong)InpFailedRetryMs;return false; }
   SendCustomAlert(StringFormat("%s #%I64u | SL=%s | TP=%s",reason,ticket,DoubleToString(sl,_Digits),DoubleToString(tp,_Digits)));
   return true;
}
bool CloseForAngle(ulong ticket,int state)
{
   ulong now=GetTickCount64();
   if(now<attempts[state].retry_close) return false;
   bool sent=trade.PositionClose(ticket);
   bool ok=CheckedResult(sent,"TP góc EMA9",ticket,true);
   attempts[state].retry_close=now+(ulong)InpFailedRetryMs;
   if(ok) { SendCustomAlert("TP góc EMA9 #"+(string)ticket);cleanup_due=true; }
   return ok;
}
bool BetterSL(long type, double candidate, double old_sl)
{
   if(!ValidPrice(candidate)) return false;
   double step=MathMax(tick_size,InpMinTrailStepPoints*point_size);
   return old_sl==0 || (type==POSITION_TYPE_BUY ? candidate-old_sl : old_sl-candidate)>=step-tick_size*0.1;
}
bool HadExit()
{
   for(int j=HistoryDealsTotal()-1;j>=0;j--)
   {
      ulong deal=HistoryDealGetTicket(j);
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY || entry==DEAL_ENTRY_INOUT) return true;
   }
   return false;
}
void ManagePositions()
{
   last_scan=GetTickCount64();scan_pending=false;
   if(!auto_on || !TradingAllowed()) return;
   MqlTick q;if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<=0) return;
   bool data_loaded=false;
   // ĐÚNG MỘT vòng quét vị thế mỗi tick; dữ liệu EMA dùng chung, tải khi cần.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !ManagedPosition()) continue;
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int state=StateIndex(id);
      long type=PositionGetInteger(POSITION_TYPE);
      bool buy=type==POSITION_TYPE_BUY;
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double market=(buy ? q.bid : q.ask),gain=(buy ? market-open : open-market);
      double positive_be=NormalizePrice(open+(buy ? InpBEOffsetUSD : -InpBEOffsetUSD),buy);
      if(!data_loaded && ema_handle!=INVALID_HANDLE) { CacheEMA();data_loaded=true; }
      // Chốt lời được ưu tiên; không bị khoảng chờ sửa SL chặn.
      if(tp_on && ema_ready && gain>0 && ema_signal_time>=opened &&
         AdverseTurn(buy,ema_prev_slope,ema_slope,ema_angle) &&
         (!InpTPRequirePriceConfirm || (buy ? ema_close<ema_price : ema_close>ema_price)))
      { CloseForAngle(ticket,state);continue; }
      bool need_sl=sl_on && sl==0,need_tp=InpUseInitialTP && tp==0;
      double ns=sl,nt=tp;
      if(need_sl) ns=InitialSL(buy,open,market);
      if(need_tp) nt=NormalizePrice(open+(buy ? 1.0 : -1.0)*InpTPOffset*point_size,buy);
      // BE được gộp vào cùng request ban đầu; BUY làm tròn lên, SELL xuống để giữ BE dương.
      if(be_on && gain>=InpBETriggerUSD && BetterSL(type,positive_be,ns)) ns=positive_be;
      double eps=tick_size*0.25;
      bool changed=MathAbs(ns-sl)>eps || MathAbs(nt-tp)>eps;
      if(changed)
      {
         if(ModifyStops(ticket,state,ns,nt,"SL/TP và BE")) continue;
         // TP không hợp lệ không được chặn đặt SL; chiều ngược lại tương tự.
         if(MathAbs(ns-sl)>eps && MathAbs(nt-tp)>eps)
         {
            if(ModifyStops(ticket,state,ns,tp,"Bảo vệ SL")) continue;
            if(ModifyStops(ticket,state,sl,nt,"TP ban đầu")) continue;
         }
         if(GetTickCount64()<attempts[state].retry_modify) continue;
      }
      // Bám EMA chỉ khi SL đã đạt BE dương, kể cả trader tự dời SL.
      bool protected_be=sl>0 && (buy ? sl>=positive_be-eps : sl<=positive_be+eps);
      if(ema_on && protected_be && ema_ready && gain>0)
      {
         double candidate=NormalizePrice(ema_price+(buy ? -InpEMASLBufferUSD : InpEMASLBufferUSD),!buy);
         if((buy ? candidate>=positive_be-eps : candidate<=positive_be+eps) && BetterSL(type,candidate,sl) &&
            ModifyStops(ticket,state,candidate,tp,"Bám EMA9",true)) continue;
      }
      if(partial_on && gain>=InpPartialTriggerUSD &&
         AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         string key=StateKey("P",id);
         if(GlobalVariableCheck(key)) continue;
         double v=GetPartialCloseVolume(volume,InpPartialPercent);
         if(v<=0 || GetTickCount64()<attempts[state].retry_close) continue;
         if(!attempts[state].history_checked)
         {
            // Không chốt lặp nếu đã giảm vị thế từ trước khi nâng cấp/restart.
            if(!HistorySelectByPosition(id)) continue;
            attempts[state].history_checked=true;
            if(HadExit()) { GlobalVariableSet(key,1);continue; }
         }
         bool sent=trade.PositionClosePartial(ticket,v);
         bool ok=CheckedResult(sent,"Chốt một phần",ticket,true);
         attempts[state].retry_close=GetTickCount64()+(ulong)InpFailedRetryMs;
         if(ok && PositionSelectByTicket(ticket) && PositionGetDouble(POSITION_VOLUME)<volume-1e-8)
         { GlobalVariableSet(key,1);GlobalVariablesFlush();SendCustomAlert("Chốt một phần #"+(string)ticket); }
      }
   }
}
bool ContainsID(const ulong &ids[],ulong id)
{
   for(int j=0;j<ArraySize(ids);j++) if(ids[j]==id) return true;
   return false;
}
void CleanupGlobalVariables()
{
   // Timer lấy danh sách vị thế đúng một lượt, đối chiếu trong RAM thay vì quét lại mỗi cờ.
   ulong active[];int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0 || !ManagedPosition()) continue;
      ArrayResize(active,count+1);active[count++]=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   }
   for(int i=GlobalVariablesTotal()-1;i>=0;i--)
   {
      string name=GlobalVariableName(i);
      if(StringFind(name,StatePrefix)!=0) continue;
      ulong id=(ulong)StringToInteger(StringSubstr(name,StringLen(StatePrefix)+1));
      if(StringSubstr(name,StringLen(StatePrefix),1)=="F" || !ContainsID(active,id)) GlobalVariableDel(name);
   }
   for(int i=ArraySize(attempts)-1;i>=0;i--)
      if(!ContainsID(active,attempts[i].id))
      {
         int n=ArraySize(attempts);
         if(i<n-1) attempts[i]=attempts[n-1];
         ArrayResize(attempts,n-1);
      }
   ArrayFree(active);
}

//+------------------------------------------------------------------+
//| CẬP NHẬT PANEL ĐA KHUNG (GUI TRÊN TIMER)                         |
//+------------------------------------------------------------------+
void ToggleButton(string name,string label,bool active,int x,int y)
{
   color background=(active ? clrDarkGreen : clrDimGray);
   CreateButton(name,label,x,y,44,22,background,clrWhiteSmoke);
   string object=PrefixID+name;
   if(ObjectGetString(0,object,OBJPROP_TEXT)!=label ||
      (color)ObjectGetInteger(0,object,OBJPROP_BGCOLOR)!=background)
   {
      ObjectSetString(0,object,OBJPROP_TEXT,label);
      ObjectSetInteger(0,object,OBJPROP_BGCOLOR,background);
      ui_dirty=true;
   }
}
void UpdatePanelGUI()
{
   if(!InpShowPanel) return;
   const int gap=4; // Khoảng trống tương đương một dấu cách, dùng đều giữa tất cả nút.
   const int tf_width=90; // Nới khoảng UP/DOWN để chữ không sát khung kế tiếp.
   int title_width=(int)MathMax(120,StringLen("BIAS "+_Symbol)*8+10);
   int row_width=title_width+5*tf_width+8+75+63+60+6*44+8*gap;
   int chart_width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int left=InpTableX;
   if(chart_width>row_width+8) left=(int)MathMax(0,MathMin(left,chart_width-row_width-8));
   int y=InpTableY;
   int tf_start=left+title_width;
   int buttons_x=tf_start+5*tf_width+8;
   int auto_x=buttons_x+75+63+60+3*gap;
   static bool hidden=false;
   if(!auto_on)
   {
      if(!hidden)
      {
         for(int i=ObjectsTotal(0)-1;i>=0;i--)
         {
            string name=ObjectName(0,i);
            if(StringFind(name,PrefixID)==0 && name!=PrefixID+"AUTO") ObjectDelete(0,name);
         }
         ui_dirty=true;hidden=true;
      }
      ToggleButton("AUTO","AUTO",false,auto_x,y);
      if(ui_dirty) { ChartRedraw(0);ui_dirty=false; }
      return;
   }
   hidden=false;
   ENUM_TIMEFRAMES frames[5]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_H1,PERIOD_H4};
   string labels[5]={"M1","M5","M15","H1","H4"};
   static datetime cached[5];
   static int previous_left=-1;
   bool moved=previous_left!=left;previous_left=left;
   CreateLabel("TITLE","BIAS "+_Symbol,left,y+4,clrWhiteSmoke,10);
   for(int j=0;j<5;j++)
   {
      int tx=tf_start+j*tf_width;
      CreateLabel("TF_"+labels[j],labels[j]+":",tx,y+4,clrWhiteSmoke,9);
      datetime stamp=iTime(_Symbol,frames[j],1);
      if(!moved && stamp>0 && stamp==cached[j] && ObjectFind(0,PrefixID+"VAL_"+labels[j])>=0) continue;
      MqlRates r[];
      if(CopyRates(_Symbol,frames[j],1,1,r)==1)
      {
         cached[j]=r[0].time;
         string value=(r[0].close>r[0].open ? "UP" : r[0].close<r[0].open ? "DOWN" : "SIDE");
         color c=(r[0].close>r[0].open ? clrLimeGreen : r[0].close<r[0].open ? clrCrimson : clrGray);
         CreateLabel("VAL_"+labels[j],value,tx+32,y+4,c,9);
      }
      else CreateLabel("VAL_"+labels[j],"N/A",tx+32,y+4,clrGray,9);
   }
   int x=buttons_x;
   CreateButton("BTN_CLOSE_ALL","Close All",x,y,75,22,clrChocolate,clrWhite);x+=75+gap;
   CreateButton("BTN_CLOSE_PROFIT","C Profit",x,y,63,22,clrForestGreen,clrWhite);x+=63+gap;
   CreateButton("BTN_CLOSE_LOSS","C Loss",x,y,60,22,clrCrimson,clrWhite);x+=60+gap;
   ToggleButton("AUTO","AUTO",auto_on,x,y);x+=44+gap;
   ToggleButton("SL","SL",sl_on,x,y);x+=44+gap;
   ToggleButton("BE","BE+",be_on,x,y);x+=44+gap;
   ToggleButton("EMA","EMA9",ema_on,x,y);x+=44+gap;
   ToggleButton("TP","TP",tp_on,x,y);x+=44+gap;
   ToggleButton("PART","PART",partial_on,x,y);
   if(ui_dirty) { ChartRedraw(0);ui_dirty=false; }
}

//+------------------------------------------------------------------+
//| HÀM XỬ LÝ ĐÓNG LỆNH THEO NHÓM                                    |
//+------------------------------------------------------------------+
void ActionClosePositions(string mode) {
   if(!TradingAllowed()) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
            if(!ManagedPosition()) continue;
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            profit+=PositionGetDouble(POSITION_SWAP);
            if(mode=="ALL" || (mode=="PROFIT" && profit>0) || (mode=="LOSS" && profit<0))
               CheckedResult(trade.PositionClose(ticket),"Đóng vị thế",ticket,true);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BẮT SỰ KIỆN CLICK NÚT TRÊN PANEL                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE) { UpdatePanelGUI();return; }
   if(id!=CHARTEVENT_OBJECT_CLICK || StringFind(sparam,PrefixID)!=0) return;
   string button=StringSubstr(sparam,StringLen(PrefixID));
   if(button=="BTN_CLOSE_ALL") ActionClosePositions("ALL");
   else if(button=="BTN_CLOSE_PROFIT") ActionClosePositions("PROFIT");
   else if(button=="BTN_CLOSE_LOSS") ActionClosePositions("LOSS");
   else if(button=="AUTO") auto_on=!auto_on;
   else if(button=="SL") sl_on=!sl_on;
   else if(button=="BE") be_on=!be_on;
   else if(button=="EMA") ema_on=!ema_on;
   else if(button=="TP") tp_on=!tp_on;
   else if(button=="PART")
   {
      if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) partial_on=!partial_on;
      else Print("Chốt một phần chỉ hỗ trợ tài khoản hedging.");
   }
   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   ema_bar=0;ema_ready=false;data_retry=0;
   SyncEMAHandles();UpdatePanelGUI();
   if(auto_on) ManagePositions();
}
int OnInit()
{
   if(InpSlippage<0 || InpSLOffset<=0 || InpTPOffset<=0 || InpBETriggerUSD<=0 ||
      InpBEOffsetUSD<=0 || InpBEOffsetUSD>=InpBETriggerUSD || InpEMASLBufferUSD<0 ||
      InpMinTrailStepPoints<0 || InpModifyIntervalMs<0 || InpFailedRetryMs<100 ||
      InpTPAngleDegrees<=0 || InpTPAngleDegrees>=180 || InpATRPeriod<2 ||
      InpPartialTriggerUSD<=0 || InpPartialPercent<=0 || InpPartialPercent>=100) return INIT_PARAMETERS_INCORRECT;
   point_size=SymbolInfoDouble(_Symbol,SYMBOL_POINT);tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick_size<=0) tick_size=point_size;
   if(point_size<=0 || tick_size<=0) return INIT_FAILED;
   PrefixID="BTC590_"+(string)ChartID()+"_";
   string scope=AccountInfoString(ACCOUNT_SERVER)+"|"+_Symbol+"|"+(InpManageAllMagic ? "ALL" : (string)InpMagicNumber);
   StatePrefix="B580_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+(string)HashText(scope)+"_";
   if(MQLInfoInteger(MQL_TESTER)) StatePrefix="T"+StatePrefix;
   auto_on=InpEnabled;sl_on=InpUseInitialSL;be_on=InpUseBreakEven;ema_on=InpUseEMATrailing;tp_on=InpUseEMAAngleTP;
   partial_on=InpUsePartialClose && AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   if(InpUsePartialClose && !partial_on) Print("Partial close OFF: tài khoản không phải hedging.");
   trade.SetExpertMagicNumber(InpMagicNumber);trade.SetDeviationInPoints(InpSlippage);
   trade.SetAsyncMode(false);trade.SetTypeFillingBySymbol(_Symbol);
   SyncEMAHandles();
   if(auto_on && ((sl_on && InpInitialSLUseEMA9) || ema_on || tp_on) && ema_handle==INVALID_HANDLE) return INIT_FAILED;
   if(auto_on && tp_on && atr_handle==INVALID_HANDLE) return INIT_FAILED;
   if(MQLInfoInteger(MQL_TESTER)) GlobalVariablesDeleteAll(StatePrefix);
   CleanupGlobalVariables();UpdatePanelGUI();
   if(!EventSetMillisecondTimer(250)) return INIT_FAILED;
   if(auto_on && !TradingAllowed()) Print("AUTO SL chưa có quyền giao dịch: kiểm tra Algo Trading và Allow Algo Trading của EA.");
   ManagePositions(); // Quét ngay vị thế đang mở khi vừa gắn EA.
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(ema_handle!=INVALID_HANDLE) IndicatorRelease(ema_handle);
   if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(PrefixID!="") ObjectsDeleteAll(0,PrefixID);
   if(StatePrefix!="") CleanupGlobalVariables();
   if(MQLInfoInteger(MQL_TESTER) && StatePrefix!="") GlobalVariablesDeleteAll(StatePrefix);
   ArrayFree(attempts);ChartRedraw(0);
}
void OnTick() { ManagePositions(); }
void OnTimer()
{
   ulong now=GetTickCount64();
   // Giao dịch mới: quét ở timer kế tiếp; khi ít tick: kiểm tra dự phòng mỗi giây.
   // OnTick vẫn quét đúng một lượt; last_scan tránh timer lặp quét khi tick đã xử lý.
   if(auto_on && (scan_pending || now-last_scan>=1000)) ManagePositions();
   if(now-last_panel_refresh>=1000)
   { UpdatePanelGUI();last_panel_refresh=now; }
   if(cleanup_due || now-last_cleanup>=10000)
   { CleanupGlobalVariables();last_cleanup=now;cleanup_due=false; }
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   // Không gửi lệnh sửa trong handler giao dịch; vị thế có thể chưa cập nhật đầy đủ.
   if(trans.symbol==_Symbol) { cleanup_due=true;scan_pending=true; }
}
// HƯỚNG DẪN: MQL5/Experts -> Compile F7 -> gắn một EA quản lý cho mỗi symbol.
// Mặc định quét mọi Magic trên symbol chart, gồm lệnh tay và EA; Close All cũng theo phạm vi này.
// AUTO OFF ẩn toàn bộ bảng trừ nút AUTO và giải phóng EMA/ATR; SL/TP trên server vẫn tồn tại.
// SL OFF dừng THÊM SL ban đầu, không vô hiệu hóa BE/EMA; mỗi chế độ có nút riêng.
// TP OFF dừng chốt theo góc EMA; TP cố định vẫn theo InpUseInitialTP và TP có sẵn trên server.
// Muốn chỉ chốt theo EMA: InpUseInitialTP=false; EA không tự xóa TP đang có của trader.
// BIAS UP/DOWN là màu nến đóng của từng khung, không phải xác nhận xu hướng.
// EMA9 dùng nến đóng: SL server luôn theo tick, nhưng điểm bám EMA cập nhật khi đóng nến.
// Góc = 180 - |atan(slope mới/ATR) - atan(slope trước/ATR)|, đổi radian sang độ.
// TP 160 độ: chỉ bẻ ngược chiều vị thế, giá hiện tại có lợi; mặc định cần nến đóng qua EMA.
// BE dương chỉ nói mức giá SL vượt entry; chưa đảm bảo lãi ròng sau phí, swap, slippage/gap.
// Cờ partial của vị thế đang mở được giữ qua restart để không chốt lại; xóa khi vị thế đóng.
// AUTO và SL mặc định ON. Quét ngay OnInit, theo tick, giao dịch mới và timer dự phòng.
