"""Regression checks for extracted MQL forecast/event functions.

The C++17 adapter supplies controlled price/volume metrics and chart-object APIs.
It executes the real function bodies, not a Python reimplementation. It does not
replace MetaEditor compilation or a market-data backtest.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from mql_source_adapter import extract_function


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "C7CB_L_COMPACT_v2_35.mq5"


def extract_struct(source, name):
    match = re.search(r"\bstruct\s+" + re.escape(name) + r"\s*\{[^}]*\};", source)
    if match is None:
        raise AssertionError(f"Missing MQL struct: {name}")
    return match.group(0)


def cpp_strings(code):
    # MQL strings concatenate literals directly; C++ needs std::string literals.
    return re.sub(r'"(?:\\.|[^"\\])*"', lambda match: match.group(0) + "s", code)


PRELUDE = r'''
#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <vector>
using string=std::string;
using datetime=long long;
using color=int;
using namespace std::string_literals;
template<class A,class B> auto MathMin(A a,B b) { using T=std::common_type_t<A,B>;return std::min(T(a),T(b)); }
template<class A,class B> auto MathMax(A a,B b) { using T=std::common_type_t<A,B>;return std::max(T(a),T(b)); }
template<class T> auto MathAbs(T a) { return std::abs(a); }
template<class T> int ArraySize(const std::vector<T>& v) { return static_cast<int>(v.size()); }
template<class T> int ArrayResize(std::vector<T>& v,int n,int=0) { v.resize(n);return n; }
string IntegerToString(long long n) { return std::to_string(n); }
string DoubleToString(double n,int) { std::ostringstream out;out<<n;return out.str(); }
string TimeToString(datetime n) { return std::to_string(n); }
string EnumToString(int) { return "PERIOD_M1"; }
int StringFind(const string& text,const string& part) { auto n=text.find(part);return n==string::npos?-1:int(n); }
int PeriodSeconds(int) { return 60; }
template<class... T> void Print(T&&...) {}
constexpr int _Period=1,_Digits=2;
constexpr double EMPTY_VALUE=1.7976931348623157e308;
const string _Symbol="TEST";

constexpr int OBJ_TEXT=1,OBJ_RECTANGLE=2,OBJPROP_TYPE=3,OBJPROP_FONT=4,
 OBJPROP_ANCHOR=5,OBJPROP_FONTSIZE=6,OBJPROP_TEXT=7,OBJPROP_HIDDEN=8,
 OBJPROP_SELECTABLE=9,OBJPROP_COLOR=10,OBJPROP_TOOLTIP=11,OBJPROP_FILL=12,
 OBJPROP_STYLE=13,ANCHOR_UPPER=14,ANCHOR_LOWER=15,ANCHOR_LEFT_UPPER=16,
 ANCHOR_LEFT_LOWER=17,STYLE_DASH=18;
constexpr color clrAqua=19,clrGold=20,clrSilver=21;
struct ChartObject { int type=0;std::vector<datetime> stamps;std::map<int,string> strings; };
std::map<string,ChartObject> objects;
int ObjectFind(int,const string& name) { return objects.count(name)?0:-1; }
int ObjectGetInteger(int,const string& name,int) { return objects.at(name).type; }
bool ObjectDelete(int,const string& name) { objects.erase(name);return true; }
bool ObjectCreate(int,const string& name,int type,int,datetime at,double,datetime end=0,double=0) {
 objects[name].type=type;objects[name].stamps={at};if(end)objects[name].stamps.push_back(end);return true;
}
bool ObjectMove(int,const string& name,int point,datetime at,double) {
 auto& p=objects[name].stamps;if(int(p.size())<=point)p.resize(point+1);p[point]=at;return true;
}
bool ObjectSetString(int,const string& name,int prop,const string& value) { objects[name].strings[prop]=value;return true; }
template<class T> bool ObjectSetInteger(int,const string&,int,T) { return true; }
void require(bool condition,const string& why) { if(!condition)throw std::runtime_error(why); }
bool near(double a,double b) { return std::abs(a-b)<1e-10; }
'''


GLOBALS = r'''
LForecastState LF[2];int LFUsedPivot[2];
std::vector<NewEffortEvent> NewEvents;int NewEventCount=0,NewActive[2]={-1,-1};
NewSweepCandidate NewCandidates[2],LTrendPending[2],LProposal[2];
bool LProposalReady[2]={false,false},LProposalExhaustion[2],LProposalRetry[2];double LProposalScore[2];
string LTrendWhy[2];bool LCollecting=false;
int LTrendQueuedAt[2];bool LTrendWasExhaustion[2];
int ImpulseSide=1,scoreCalls[2]={0,0};
bool InpLForecast=true,InpSmartScoreFilter=false,InpEnabled=true,InpShowEntryContext=false,
 InpShowHistory=false,InpDebugNewBars=false,InpLVolumeLock=true,InpNewLimitSetup=true,
 InpMTFZones=false,InpMTFKeyLevels=false,NewRenderDeferred=false;
int InpForecastLookback=80,InpForecastLife=12,InpForecastMinScore=65,InpSmartMinScore=60,InpNewLimitLife=10;
double InpNewStopBufferATR=0.1,InpNewZoneMaxATR=0.6,InpZoneInvalidATR=0.05,InpZoneNearATR=0.25,InpNewCancelRunATR=3;
color InpUpColor=1,InpDownColor=2;
string Prefix="test_";
std::vector<double> Up,Down,DisplayBuy,DisplaySell,DisplayUp,DisplayDown,ConfirmedBuy,ConfirmedSell;
double ContextATR(int,const std::vector<double>&,const std::vector<double>&,const std::vector<double>&) { return 1.0; }
bool UseRealWindow(int,int,const std::vector<long>&) { return false; }
double QualityRelativeVolume(int,bool,const std::vector<long>&,const std::vector<long>&) { return 1.2; }
template<class... T> void LTrace(T&&...) {}
template<class... T> bool SellTopProof(T&&...) { return false; }
template<class... T> bool LSellLocationCounterProof(T&&...) { return false; }
template<class... T> bool ProAllows(T&&...) { return true; }
template<class... T> bool LAlreadyKnown(T&&...) { return false; }
template<class... T> bool LRouteAllowed(T&&...) { return true; }
template<class... T> bool LImpulseAllowed(T&&...) { return true; }
template<class... T> bool LLocationProof(T&&...) { return false; }
template<class... T> bool LSameCycle(T&&...) { return false; }
bool LVolumeAllowed(int,const std::vector<long>&,const std::vector<long>&,double& rv,bool& real,string& why) {
 rv=1.2;real=false;why="volume ready";return true;
}
struct PivotMarketReading { bool ready=false;string foundation; };
template<class... T> void ReadPivotMarket(T&&...) {}
string ProSummary() { return ""; }
template<class... T> string BuildMTFTooltip(T&&...) { return ""; }
bool MTFEnabled(int) { return false; }
string MTFName(int) { return "M15"; }
struct StubMTFCache { bool ready=false;int count=0;int side[250];double lo[250],hi[250],scale[250]; };
StubMTFCache MTFCache[48];
double EntryBandDistance(double lo,double hi,double low,double high) { return high<lo?lo-high:low>hi?low-hi:0; }
int notified=0;
void NotifyNewEvent(const string&,bool notify) { if(notify)++notified; }
'''


SCENARIOS = r'''
struct Tape {
 std::vector<datetime> time;
 std::vector<double> open,high,low,close;
 std::vector<long> ticks,volume;
 explicit Tape(int n=128):time(n),open(n,101.1),high(n,101.6),low(n,100.6),close(n,101.2),ticks(n,120),volume(n,120) {
  for(int i=0;i<n;++i)time[i]=100000+i*60;
  close[34]=100.2;close[35]=100.4;close[36]=100.6;close[37]=100.8;
  open[38]=100.4;close[38]=100.5;low[38]=100.0;close[39]=101.0;close[40]=101.4;
  for(int i=34;i<=40;++i)low[i]=std::min(low[i],close[i]-.1);
 }
 void step(int i) { StepLForecast(i,time,open,high,low,close,ticks,volume); }
 void mirror() { for(size_t i=0;i<open.size();++i) {open[i]=202-open[i];close[i]=202-close[i];double h=high[i];high[i]=202-low[i];low[i]=202-h;} }
};
void clear() {
 ResetLForecast();NewEvents.clear();NewEventCount=0;NewActive[0]=NewActive[1]=-1;
 objects.clear();scoreCalls[0]=scoreCalls[1]=0;ImpulseSide=1;InpForecastLife=12;
 InpForecastMinScore=65;InpShowEntryContext=false;InpShowHistory=false;
 InpEnabled=true;NewRenderDeferred=false;LCollecting=false;notified=0;
 Up.assign(128,0);Down.assign(128,0);ConfirmedBuy.assign(128,0);ConfirmedSell.assign(128,0);
 DisplayBuy.assign(128,0);DisplaySell.assign(128,0);DisplayUp.assign(128,0);DisplayDown.assign(128,0);
}
NewEffortEvent event(int bar,int side,double lo=100,double hi=100.4) {
 NewEffortEvent e{};e.bar=bar;e.side=side;e.zoneLow=lo;e.zoneHigh=hi;e.entry=side>0?hi:lo;
 e.stop=side>0?lo-.1:hi+.1;e.atr=1;e.name="actual_"+std::to_string(NewEventCount);return e;
}
void append(const NewEffortEvent& e) {NewEvents.push_back(e);NewEventCount=int(NewEvents.size());}
bool sameForecast(const LForecastState& a,const LForecastState& b) {
 return a.active==b.active && a.side==b.side && a.pivot==b.pivot && a.born==b.born && a.score==b.score &&
 near(a.lo,b.lo)&&near(a.hi,b.hi)&&near(a.stop,b.stop)&&near(a.atr,b.atr)&&a.status==b.status;
}
void scenario(const string& name) {
 clear();Tape t;
 if(name=="publish") {
  t.step(40);require(LF[0].active,"buy forecast should publish");require(LF[0].pivot==38,"newest confirmed pivot must win");
  require(LF[0].born==40,"birth is publication bar, not pivot bar");require(LF[0].score>=65,"score threshold not applied");
  require(scoreCalls[0]<=1 && scoreCalls[1]<=1,"score must be computed at most once per direction/bar");
 } else if(name=="same_bar_actual") {
  append(event(40,1));t.step(40);require(!LF[0].active,"already confirmed L must not be forecast on same birth bar");
  require(LFUsedPivot[0]==38,"confirmed pivot must be consumed");
  t.step(41);require(!LF[0].active,"confirmed pivot must not be recycled one bar later");
 } else if(name=="different_actual") {
  append(event(40,1,90,90.4));append(event(40,-1));t.step(40);
  require(LF[0].active,"different-zone or opposite-side actual L must not suppress buy forecast");
 } else if(name=="sell_actual") {
  t.mirror();ImpulseSide=-1;append(event(40,-1,101.6,102.0));t.step(40);
  require(!LF[1].active && LFUsedPivot[1]==38,"same-bar confirmation suppression must work for sells");
 } else if(name=="lifetime") {
  t.step(40);auto initial=LF[0];require(initial.active,"forecast fixture did not publish");
  for(int i=41;i<52;++i) {
   t.low[i]=initial.lo+.2;t.close[i]=101.2;t.step(i);
   require(LF[0].active,"forecast expired early");
   require(LF[0].born==initial.born && LF[0].pivot==initial.pivot,"touch must not reset birth/pivot");
   require(near(LF[0].lo,initial.lo)&&near(LF[0].hi,initial.hi)&&near(LF[0].stop,initial.stop),"published bounds moved");
  }
  require(LF[0].status=="DA CHAM / CHO L","touch should update status only");
  t.step(52);require(!LF[0].active,"forecast must expire exactly at configured bar lifetime");
  require(LF[0].born==40,"expiry must not replace a forecast on the same bar");
 } else if(name=="later_confirmation") {
  t.step(40);append(event(41,1));t.step(41);
  require(!LF[0].active,"subsequent overlapping actual confirmation must consume active forecast");
 } else if(name=="close_invalidation") {
  t.step(40);double stop=LF[0].stop;t.low[41]=stop-.5;t.close[41]=101.2;t.step(41);
  require(LF[0].active,"wick alone must not invalidate close-based forecast");
  t.close[42]=stop-.01;t.step(42);require(!LF[0].active,"close beyond stop must invalidate");
 } else if(name=="future_mutation") {
  t.step(40);std::array<LForecastState,2> baseline={LF[0],LF[1]};clear();
  for(size_t i=41;i<t.close.size();++i) {t.open[i]=-1e9;t.high[i]=1e12;t.low[i]=-1e12;t.close[i]=1e9;t.ticks[i]=0;t.volume[i]=0;}
  t.step(40);require(sameForecast(LF[0],baseline[0])&&sameForecast(LF[1],baseline[1]),"future candle mutation changed historical forecast");
  clear();Tape shortTape(41);shortTape.step(40);
  require(sameForecast(LF[0],baseline[0])&&sameForecast(LF[1],baseline[1]),"forecast must work with only data known at publication");
 } else if(name=="draw_gap") {
  t.step(40);t.time[41]=t.time[40]+2*86400;DrawLForecast(0,t.time,40);
  require(objects.at("test_LF_0").stamps[0]==t.time[41],"forecast must start at actual next chart bar across a market gap");
 } else if(name=="render_without_context") {
  auto e=event(40,1);e.stamp=t.time[40];e.originStamp=t.time[30];e.knownStamp=t.time[41];append(e);
  RenderNewEvent(0);require(objects.count(e.name),"disabling detailed context must not hide actual L marker");
  require(objects.at(e.name).stamps[0]==t.time[40],"actual marker timestamp changed");
  require(objects.at(e.name).strings[OBJPROP_TOOLTIP].find(std::to_string(t.time[41]))!=string::npos,"brief tooltip must disclose availability time");
 } else if(name=="event_publication") {
  NewSweepCandidate c{};c.side=1;c.bar=30;c.extreme=100;c.bodyEdge=100.3;c.atr=1;c.level=100.2;c.route=0;
  NewCandidates[0]=c;t.time[41]=t.time[40]+2*86400;
  require(CreateNewEvent(0,40,t.time,t.open,t.high,t.low,t.close,t.ticks,t.volume,false),"valid candidate did not publish");
  auto e=NewEvents.at(0);require(e.stamp==t.time[40],"actual L must be drawn at confirmation bar, not origin");
  require(e.originStamp==t.time[30],"origin timestamp must remain available separately");
  require(e.knownStamp==t.time[41],"availability must use actual next bar across a market gap");
  require(objects.at(e.name).stamps[0]==t.time[40],"actual chart object backdated the L");
 } else if(name=="limit_order") {
  auto e=event(40,1);append(e);NewActive[0]=0;
  t.low[40]=99;t.high[40]=102;StepNewLimit(0,40,t.high,t.low,false);
  require(NewEvents[0].state==0,"origin/confirmation candle cannot fill a newly published pending limit");
  t.low[41]=100.2;StepNewLimit(0,41,t.high,t.low,false);require(NewEvents[0].state==1,"later entry touch not recorded");
  t.low[42]=99.8;StepNewLimit(0,42,t.high,t.low,false);require(NewEvents[0].state==6,"post-touch invalidation not recorded");
 } else if(name=="ambiguous_limit") {
  append(event(40,1));NewActive[0]=0;t.low[41]=99.8;StepNewLimit(0,41,t.high,t.low,false);
  require(NewEvents[0].state==4,"same candle entry and stop must remain ambiguous, not a verified fill");
 } else throw std::runtime_error("unknown scenario");
}
int main(int argc,char** argv) {
 try {require(argc==2,"scenario argument required");scenario(argv[1]);std::cout<<"PASS "<<argv[1]<<"\n";return 0;}
 catch(const std::exception& e) {std::cerr<<e.what()<<"\n";return 1;}
}
'''


class SignalLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which("g++")
        if compiler is None:
            raise RuntimeError("g++ is required for extracted MQL logic regression tests")
        source = SOURCE.read_text(encoding="utf-8-sig")
        declarations = "\n".join(extract_struct(source, name) for name in (
            "LForecastState", "NewEffortEvent", "NewSweepCandidate"))
        names = ("ResetLForecast", "LSmartScore", "StepLForecast", "DrawLForecast",
                 "NewEventStatus", "NewEventTip", "RenderNewEvent", "CreateNewEvent", "StepNewLimit")
        functions = []
        for name in names:
            body = extract_function(source, name)
            if name == "LSmartScore":
                opening = body.index("{")
                body = body[:opening + 1] + "\n++scoreCalls[side>0?0:1];\n" + body[opening + 1:]
            functions.append(cpp_strings(body))
        code = PRELUDE + declarations + GLOBALS + "\n".join(functions) + SCENARIOS
        cls.temp = tempfile.TemporaryDirectory(prefix="mql-signal-lifecycle-")
        cls.addClassCleanup(cls.temp.cleanup)
        cpp = Path(cls.temp.name) / "lifecycle.cpp"
        cls.binary = Path(cls.temp.name) / "lifecycle"
        cpp.write_text(code)
        result = subprocess.run([compiler, "-std=c++17", "-O0", "-D_GLIBCXX_ASSERTIONS", str(cpp), "-o", str(cls.binary)],
                                text=True, capture_output=True, timeout=60)
        if result.returncode:
            raise AssertionError(f"C++ adapter compilation failed:\n{result.stdout}\n{result.stderr}")

    def run_scenario(self, scenario):
        result = subprocess.run([str(self.binary), scenario], text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS " + scenario, result.stdout)

    def test_forecast_publishes_newest_pivot_with_bounded_scoring(self):
        self.run_scenario("publish")

    def test_same_bar_confirmation_consumes_forecast_pivot(self):
        self.run_scenario("same_bar_actual")

    def test_unrelated_confirmation_does_not_suppress_forecast(self):
        self.run_scenario("different_actual")

    def test_same_bar_confirmation_is_symmetric_for_sell(self):
        self.run_scenario("sell_actual")

    def test_forecast_birth_bounds_and_lifetime_are_fixed(self):
        self.run_scenario("lifetime")

    def test_later_confirmation_consumes_active_forecast(self):
        self.run_scenario("later_confirmation")

    def test_forecast_invalidation_uses_closed_price(self):
        self.run_scenario("close_invalidation")

    def test_future_candles_do_not_change_historical_forecast(self):
        self.run_scenario("future_mutation")

    def test_forecast_drawing_uses_actual_publication_time_across_gap(self):
        self.run_scenario("draw_gap")

    def test_actual_markers_remain_visible_without_detailed_context(self):
        self.run_scenario("render_without_context")

    def test_actual_event_draws_at_confirmation_and_keeps_origin(self):
        self.run_scenario("event_publication")

    def test_limit_cannot_fill_before_publication_and_tracks_later_invalidation(self):
        self.run_scenario("limit_order")

    def test_same_candle_limit_and_stop_are_not_a_verified_fill(self):
        self.run_scenario("ambiguous_limit")


if __name__ == "__main__":
    unittest.main()
