"""Run actual MQL replay control flow against deterministic terminal/API stubs.

The C++ adapter isolates history availability and clock behavior. It does not
replace compilation in MetaEditor or verification with MT5 market data.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from mql_source_adapter import extract_function


SOURCE = Path(__file__).resolve().parents[1] / "C7CB_L_COMPACT_v2_35.mq5"

ADAPTER = r'''
#include <algorithm>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>
using datetime=long long;
using string=std::string;
using ENUM_TIMEFRAMES=int;
template<class A,class B> auto MathMax(A a,B b) {
    using C=std::common_type_t<A,B>;return std::max(C(a),C(b));
}
template<class A,class B> auto MathMin(A a,B b) {
    using C=std::common_type_t<A,B>;return std::min(C(a),C(b));
}
template<class T> void ArrayInitialize(std::vector<T>& a,T value) {std::fill(a.begin(),a.end(),value);}
template<class T> void ArraySetAsSeries(const std::vector<T>&,bool) {}
template<class... T> void Print(T&&...) {}
template<class... T> void ObjectsDeleteAll(T&&...) {}
string TimeToString(datetime t) {return std::to_string(t);}
string DoubleToString(double x,int) {return std::to_string(x);}
const double EMPTY_VALUE=std::numeric_limits<double>::max();
bool InpNewLimitSetup=true,InpLLocationMTF=true,InpLLocationEntry=true,InpLSellTop=true;
bool InpMTFZones=true,InpMTFKeyLevels=true,InpEnabled=true,InpLArbitrate=true;
bool InpShowHistory=false,InpLForecast=true,InpDebugNewBars=false,InpLDiagnostics=false;
int InpNewSweepBars=20,InpStartupBars=600;
bool enabledSources[4]={true,true,true,true};
bool sourceReady=true;
int missingAt=-1;
std::vector<std::pair<int,datetime>> historyRequests;
bool MTFEnabled(int tf) {return enabledSources[tf];}
int MTFPeriod(int tf) {return tf;}
bool LoadMTFContext(int cache,int,datetime cutoff) {
    historyRequests.push_back({cache,cutoff});
    return sourceReady && cutoff!=1+60LL*missingAt;
}
bool NewReplayPending=false,MTFHistoryWaiting=false,NewRenderDeferred=false;
unsigned long MTFRetryAfter=0,MTFQueryEpoch=0,clockMilliseconds=0;
unsigned long GetTickCount64() {return clockMilliseconds;}
unsigned long GetMicrosecondCount() {return clockMilliseconds*1000;}
int NewProcessed=-1,NewEventCount=0,ShownCount=0,QualityChartCount=0;
datetime FirstTime=0;
bool IndicatorStopping=false,MetricCacheReady=false;
int metricPreparations=0;
template<class... T> void PrepareMetricCache(T&&...) {++metricPreparations;MetricCacheReady=true;}
void FreeMetricCache() {MetricCacheReady=false;}
string Prefix="test_",LGeneratorWhy[7][2];
bool LCollecting=false,LProposalReady[2]={false,false};
bool LProposalExhaustion[2]={false,false},LProposalRetry[2]={false,false};
struct NewSweepCandidate {};
NewSweepCandidate NewCandidates[2],LProposal[2];
struct Event {int side=1;};
std::vector<Event> NewEvents;
std::vector<double> Up,Down,ConfirmedBuy,ConfirmedSell,DisplayUp,DisplayDown;
std::vector<double> DisplayBuy,DisplaySell,DisplayStructBuy,DisplayStructSell;
std::vector<double> DisplayRetestBuy,DisplayRetestSell,DisplayWickBuy,DisplayWickSell;
std::vector<double> StructBuy,StructSell,RetestBuy,RetestSell,WickBuy,WickSell,StrongWideWick;
std::vector<int> processedBars;
std::vector<std::pair<int,bool>> notificationEligibility;
bool diagnosticsCleared=true;
void ResetNewEffortState() {
    NewProcessed=-1;NewEventCount=0;NewEvents.clear();
    NewReplayPending=false;MTFHistoryWaiting=false;MTFRetryAfter=0;
}
void ResetDisplayCache() {}
void ResetLForecast() {}
template<class... T> void StepImpulse(int i,T&&...) {
    processedBars.push_back(i);
    for(int route=0;route<7;++route) for(int slot=0;slot<2;++slot)
        diagnosticsCleared=diagnosticsCleared && LGeneratorWhy[route][slot].empty();
}
template<class... T> void StepPro(T&&...) {}
template<class... T> void StepLTurnContext(T&&...) {}
template<class... T> void StepLLocations(T&&...) {}
template<class... T> void StepNewLimit(T&&...) {}
template<class... T> void ApplyImpulsePendingControl(T&&...) {}
template<class... T> void ApplyWyPendingControl(T&&...) {}
void StepNewSweep(int slot,int i,const std::vector<datetime>&,
                  const std::vector<double>&,const std::vector<double>&,
                  const std::vector<double>&,const std::vector<double>&,
                  const std::vector<long>&,const std::vector<long>&,bool notify) {
    if(slot==0) notificationEligibility.push_back({i,notify});
    LGeneratorWhy[0][slot]="previous bar diagnostic";
}
template<class... T> void StepLTrendPending(T&&...) {}
template<class... T> void StepExhaustionL(T&&...) {}
template<class... T> void StepContinuationL(T&&...) {}
template<class... T> void StepRangeTestL(T&&...) {}
template<class... T> void StepLLocationEntry(T&&...) {}
template<class... T> void StepLTurnEntry(T&&...) {}
template<class... T> void StepSellTopL(T&&...) {}
template<class... T> void StepWyLPS(T&&...) {}
template<class... T> bool CreateNewEvent(T&&...) {return false;}
template<class... T> void StepLForecast(T&&...) {}
bool IndexDisplayBar(int) {return true;}
void RenderNewEvent(int) {}
template<class... T> void DrawLForecast(T&&...) {}
template<class... T> void RefreshRecent(T&&...) {}
void RenderWyMarks() {}
template<class... T> void RefreshLiveLevels(T&&...) {}
template<class... T> void RefreshLiveMarketReader(T&&...) {}
'''

CASES = r'''
void require(bool condition,const std::string& message) {
    if(!condition) throw std::runtime_error(message);
}
void resizeBuffers(int count) {
    std::vector<double>* buffers[]={&Up,&Down,&ConfirmedBuy,&ConfirmedSell,&DisplayUp,&DisplayDown,
        &DisplayBuy,&DisplaySell,&DisplayStructBuy,&DisplayStructSell,&DisplayRetestBuy,&DisplayRetestSell,
        &DisplayWickBuy,&DisplayWickSell,&StructBuy,&StructSell,&RetestBuy,&RetestSell,&WickBuy,&WickSell,&StrongWideWick};
    for(auto a:buffers) a->resize(count);
}
struct Data {
    std::vector<datetime> time;
    std::vector<double> open,high,low,close;
    std::vector<long> ticks,volume;
    std::vector<int> spread;
    explicit Data(int count) {grow(count);}
    void grow(int count) {
        int before=int(time.size());time.resize(count);open.resize(count,100);
        high.resize(count,101);low.resize(count,99);close.resize(count,100);
        ticks.resize(count,100);volume.resize(count,100);spread.resize(count,1);
        for(int i=before;i<count;++i) time[i]=1+60LL*i;
        resizeBuffers(count);
    }
    int calculate(int previous) const {
        return OnCalculate(int(time.size()),previous,time,open,high,low,close,ticks,volume,spread);
    }
};
void resetHarness() {
    ResetNewEffortState();FirstTime=0;processedBars.clear();notificationEligibility.clear();historyRequests.clear();
    MetricCacheReady=false;metricPreparations=0;clockMilliseconds=0;sourceReady=true;missingAt=-1;
    NewRenderDeferred=false;diagnosticsCleared=true;
    InpNewLimitSetup=InpLLocationMTF=InpLLocationEntry=InpLSellTop=true;
    InpMTFZones=InpMTFKeyLevels=InpEnabled=true;
    for(int tf=0;tf<4;++tf) enabledSources[tf]=true;
    for(int route=0;route<7;++route) for(int slot=0;slot<2;++slot)
        LGeneratorWhy[route][slot]="stale diagnostic";
}
void requireSilentReplay() {
    for(auto item:notificationEligibility) require(!item.second,"resumed startup replay must not notify");
}
void firstStartupWait() {
    resetHarness();Data d(1000);sourceReady=false;
    require(d.calculate(0)==1000,"terminal history count should still be returned");
    require(NewProcessed==398,"missing first source must preserve chosen 600-bar start");
    require(processedBars.empty(),"signal state must not advance before required source history");
    require(NewReplayPending && MTFHistoryWaiting,"startup must remain pending");
    auto calls=historyRequests.size();int prepares=metricPreparations;
    clockMilliseconds=999;d.calculate(1000);
    require(historyRequests.size()==calls && metricPreparations==prepares,"history retries must be throttled for one second");
    clockMilliseconds=1000;sourceReady=true;d.calculate(1000);
    require(processedBars.size()==600 && processedBars.front()==399 && processedBars.back()==998,
        "resumed first-bar wait must not restart full chart history");
    require(NewProcessed==998 && !NewReplayPending && !MTFHistoryWaiting,"successful retry must catch up");
    requireSilentReplay();require(diagnosticsCleared,"both buy and sell diagnostic columns must reset");
}
void partialReplayAndLiveAlert() {
    resetHarness();Data d(1000);missingAt=402;d.calculate(0);
    require(processedBars==std::vector<int>({399,400,401}),"replay must stop immediately before unavailable bar");
    require(NewProcessed==401 && NewReplayPending,"partial replay must retain its cursor and silent mode");
    clockMilliseconds=1000;missingAt=-1;d.calculate(1000);
    require(processedBars.size()==600,"resumed replay must not repeat earlier processed bars");
    for(int k=0;k<600;++k) require(processedBars[k]==399+k,"replay order/cursor continuity");
    requireSilentReplay();
    d.grow(1001);d.calculate(1000);
    require(processedBars.back()==999,"new live closed bar should be processed");
    require(notificationEligibility.back()==std::make_pair(999,true),"latest live close should be eligible to notify");
    auto count=processedBars.size();d.close.back()=9000;d.calculate(1001);
    require(processedBars.size()==count,"forming-candle ticks must not reprocess a closed bar");
}
void pendingLiveClose() {
    resetHarness();Data d(1000);d.calculate(0);requireSilentReplay();
    d.grow(1001);missingAt=999;clockMilliseconds=10;d.calculate(1000);
    require(NewProcessed==998 && MTFHistoryWaiting && !NewReplayPending,"live wait must not become startup replay");
    require(processedBars.size()==600,"missing live source must not mutate signal state");
    clockMilliseconds=1009;missingAt=-1;d.calculate(1001);
    require(processedBars.size()==600,"retry before the deadline must remain deferred");
    clockMilliseconds=1010;d.calculate(1001);
    require(notificationEligibility.back()==std::make_pair(999,true),"recovered latest live close remains eligible to notify");
}
void unusedSourceGating() {
    resetHarness();sourceReady=false;
    InpLLocationMTF=false;require(SignalMTFReady(100,6001),"disabled MTF must not block signals");
    require(historyRequests.empty(),"disabled MTF must not request history");
    InpLLocationMTF=true;InpLLocationEntry=false;InpLSellTop=false;
    require(SignalMTFReady(100,6001) && historyRequests.empty(),"no MTF signal route must not request history");
    InpLLocationEntry=true;
    for(int tf=0;tf<4;++tf) enabledSources[tf]=false;
    require(SignalMTFReady(100,6001) && historyRequests.empty(),"disabled source timeframes must be ignored");
    enabledSources[2]=true;sourceReady=true;
    require(SignalMTFReady(100,6001),"available enabled source must pass preflight");
    require(historyRequests==std::vector<std::pair<int,datetime>>({{2,6001}}),"only enabled source should be requested at bar-open cutoff");
}
void tinyHistoryWarmup() {
    resetHarness();Data d(10);d.calculate(0);
    require(NewProcessed==8 && processedBars.empty(),"short-history cursor should be marked caught up without signal work");
    int preparations=metricPreparations;d.calculate(10);
    require(metricPreparations==preparations,"short-history ticks should take the same-bar fast path");
    d.grow(27);d.calculate(10);
    require(NewProcessed==25 && processedBars.empty(),"warmup threshold must not process the forming bar");
    d.grow(28);d.calculate(27);
    require(processedBars==std::vector<int>({26}),"first eligible closed bar should be processed after warmup");
}
int main(int argc,char** argv) {
    try {
        if(argc!=2) throw std::runtime_error("one case name required");
        std::string name=argv[1];
        if(name=="first_wait") firstStartupWait();
        else if(name=="partial_replay") partialReplayAndLiveAlert();
        else if(name=="live_wait") pendingLiveClose();
        else if(name=="gating") unusedSourceGating();
        else if(name=="warmup") tinyHistoryWarmup();
        else throw std::runtime_error("unknown case");
        std::cout<<"PASS "<<name<<"\n";
    } catch(const std::exception& e) {std::cerr<<e.what()<<"\n";return 1;}
}
'''


@unittest.skipUnless(shutil.which("g++"), "g++ is required for the native logic adapter")
class MTFReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="mtf-replay-")
        cls.addClassCleanup(cls.temp.cleanup)
        source = SOURCE.read_text(encoding="utf-8-sig")
        selected = "\n\n".join(
            extract_function(source, name)
            for name in ("SignalMTFReady", "CalculateNewEffort", "OnCalculate")
        )
        cpp = Path(cls.temp.name) / "replay.cpp"
        cls.binary = Path(cls.temp.name) / "replay"
        cpp.write_text(ADAPTER + "\n" + selected + "\n" + CASES)
        compiled = subprocess.run(
            ["g++", "-std=c++17", "-O2", "-D_GLIBCXX_ASSERTIONS", str(cpp), "-o", str(cls.binary)],
            capture_output=True, text=True, timeout=30,
        )
        if compiled.returncode:
            raise AssertionError("C++ logic adapter failed to compile:\n" + compiled.stderr)

    def run_case(self, name):
        result = subprocess.run([str(self.binary), name], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS " + name, result.stdout)

    def test_missing_first_source_preserves_start_and_throttles_retries(self):
        self.run_case("first_wait")

    def test_partial_startup_replay_is_silent_and_live_close_can_notify(self):
        self.run_case("partial_replay")

    def test_missing_live_history_waits_without_mutating_signal_state(self):
        self.run_case("live_wait")

    def test_disabled_or_unused_mtf_sources_do_not_block(self):
        self.run_case("gating")

    def test_tiny_history_fast_path_resumes_at_first_eligible_bar(self):
        self.run_case("warmup")


if __name__ == "__main__":
    unittest.main()
