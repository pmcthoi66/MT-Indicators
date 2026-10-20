"""Exercise actual MQL cache/bookkeeping bodies in a small native C++ adapter.

This regression check does not replace compilation with MetaEditor or chart tests.
Run with: python3 -m unittest discover -s tests -p 'test_metric_cache.py' -v
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from mql_source_adapter import extract_function


SOURCE = Path(__file__).resolve().parents[1] / "C7CB_L_COMPACT_v2_35.mq5"


ADAPTER = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <vector>
int InpStartupBars=600;
bool InpUseRealVolume=true,InpShowHistory=false,InpShowEntryContext=true;
bool failNextResize=false;
long mathOperations=0;
template<class A,class B> auto MathMax(A a,B b) {
    ++mathOperations; using C=std::common_type_t<A,B>; return std::max(C(a),C(b));
}
template<class A,class B> auto MathMin(A a,B b) {
    ++mathOperations; using C=std::common_type_t<A,B>; return std::min(C(a),C(b));
}
template<class T> auto MathAbs(T value) { ++mathOperations;return std::abs(value); }
template<class T> int ArraySize(const std::vector<T>& values) { return int(values.size()); }
template<class T> int ArrayResize(std::vector<T>& values,int size,int=0) {
    if(failNextResize) {failNextResize=false;return -1;}
    values.resize(size);return size;
}
template<class T> void ArrayFree(std::vector<T>& values) { values.clear();values.shrink_to_fit(); }
const double EMPTY_VALUE=std::numeric_limits<double>::max();
std::vector<double> Up,Down,ConfirmedBuy,ConfirmedSell,StructBuy,StructSell;
std::vector<double> RetestBuy,RetestSell,WickBuy,WickSell,StrongWideWick;
std::vector<int> RecentBars,RecentTypes,StrongBars,ContextBars,ContextTypes;
int RecentCount=0,StrongCount=0,ContextCount=0;
'''


CASES = r'''
void require(bool condition,const std::string& message) {
    if(!condition) throw std::runtime_error(message);
}
void equal(double actual,double expected,const std::string& message) {
    require(std::abs(actual-expected)<=1e-12*std::max(1.0,std::abs(expected)),message);
}
struct Data {
    std::vector<double> high,low,close;
    std::vector<long> ticks,volume;
    void grow(int count) {
        int before=int(high.size());
        high.resize(count);low.resize(count);close.resize(count);ticks.resize(count);volume.resize(count);
        for(int i=before;i<count;i++) {
            close[i]=100.0+0.003*i+std::sin(i*0.31);
            high[i]=close[i]+0.2+(i%7)*0.03;
            low[i]=close[i]-0.3-(i%5)*0.02;
            ticks[i]=(i%47==0?0:100+i%113);
            volume[i]=(i%31==0?0:500+i%79);
        }
    }
};
double referenceATR(const Data& d,int i) {
    if(i<15 || i>=int(d.high.size())) return 0;
    double sum=0;
    for(int j=i-14;j<i;j++) {
        double previous=d.close[j-1];
        sum+=std::max({d.high[j]-d.low[j],std::abs(d.high[j]-previous),std::abs(d.low[j]-previous)});
    }
    return sum/14.0;
}
double referenceRV(const Data& d,int i,bool real) {
    if(i<20 || i>=int(d.ticks.size())) return 0;
    const auto& values=real?d.volume:d.ticks;
    double sum=0;
    for(int j=i-20;j<i;j++) {if(values[j]<=0) return 0;sum+=values[j];}
    return values[i]>0 && sum>0?values[i]*20.0/sum:0;
}
bool referenceWindow(const Data& d,int first,int last) {
    if(!InpUseRealVolume || first<0 || last<first || last>=int(d.volume.size())) return false;
    return std::all_of(d.volume.begin()+first,d.volume.begin()+last+1,[](long value){return value>0;});
}
void prepare(const Data& d,int count,int previous,bool reset) {
    PrepareMetricCache(count,previous,reset,d.high,d.low,d.close,d.ticks,d.volume);
}
void parity(const Data& d) {
    int count=int(d.high.size());
    for(int i=0;i<count;i++) {
        equal(ContextATR(i,d.high,d.low,d.close),referenceATR(d,i),"ATR mismatch at "+std::to_string(i));
        equal(QualityRelativeVolume(i,false,d.ticks,d.volume),referenceRV(d,i,false),"tick RV mismatch");
        equal(QualityRelativeVolume(i,true,d.ticks,d.volume),referenceRV(d,i,true),"real RV mismatch");
        int first=std::max(0,i-20);
        require(UseRealWindow(first,i,d.volume)==referenceWindow(d,first,i),"real-volume window mismatch");
    }
    require(!UseRealWindow(-1,10,d.volume),"negative window must be rejected");
    require(!UseRealWindow(10,9,d.volume),"reversed window must be rejected");
    require(!UseRealWindow(0,count,d.volume),"window beyond data must be rejected");
}
void startup() {
    Data d;d.grow(5000);prepare(d,5000,0,true);
    require(MetricCacheReady && MetricCacheFirst==4368 && MetricCacheCapacity==632,"bounded startup interval");
    require(ArraySize(CachedContextATR)==632 && ArraySize(CachedRealMissing)==632,"bounded cache storage");
    parity(d);
    mathOperations=0;prepare(d,5000,0,true);long small=mathOperations;
    d.grow(50000);mathOperations=0;prepare(d,50000,0,true);long large=mathOperations;
    require(large==small,"startup metric work must not grow with full chart history");
    require(ArraySize(CachedTickRV)==632,"large-history cache allocation is bounded");
    parity(d);
}
void incremental() {
    Data d;d.grow(5000);prepare(d,5000,0,true);
    for(int count=5001;count<=6500;count++) {
        // The formerly forming candle changes before the next bar closes it.
        int former=count-2;d.high[former]+=0.17;d.low[former]-=0.11;
        d.close[former]+=0.05;d.ticks[former]+=17;d.volume[former]=777;
        d.grow(count);prepare(d,count,count-1,false);
        if(count%97==0) parity(d);
    }
    parity(d);
    d.grow(8500);prepare(d,8500,6500,false);parity(d);
    require(MetricCacheFirst==8500-632,"jump must retain only latest window");
    InpUseRealVolume=false;
    require(!UseRealWindow(10,20,d.volume),"real volume remains opt-in");
}
void lifecycle() {
    for(int count:{1,14,20,31,600}) {
        Data d;d.grow(count);prepare(d,count,0,true);parity(d);
    }
    Data d;d.grow(3000);prepare(d,3000,0,true);
    InpStartupBars=700;prepare(d,3000,3000,false);parity(d);
    require(MetricCacheCapacity==732 && ArraySize(CachedRealRV)==732,"input change rebuilds ring");
    d.high.resize(90);d.low.resize(90);d.close.resize(90);d.ticks.resize(90);d.volume.resize(90);
    prepare(d,90,3000,true);parity(d);
    FreeMetricCache();failNextResize=true;prepare(d,90,0,true);
    require(!MetricCacheReady && CachedContextATR.empty(),"allocation failure releases partial cache");
    parity(d); // Direct calculation remains usable after allocation failure.
    prepare(d,91,90,false);
    require(!MetricCacheReady,"reject an input count beyond available arrays");
    equal(ContextATR(90,d.high,d.low,d.close),0,"ATR index beyond data");
    equal(QualityRelativeVolume(90,false,d.ticks,d.volume),0,"volume index beyond data");
}
void recent() {
    for(auto* values:{&Up,&Down,&ConfirmedBuy,&ConfirmedSell,&StructBuy,&StructSell,&RetestBuy,&RetestSell,&WickBuy,&WickSell,&StrongWideWick})
        values->assign(200,EMPTY_VALUE);
    for(int i=0;i<200;i++) {
        (i%2==0?Up:Down)[i]=100.0+i;
        require(IndexDisplayBar(i),"bookkeeping failed");
    }
    require(RecentCount==5 && RecentBars.size()==5 && RecentTypes.size()==5,"recent queue stays bounded");
    for(int k=0;k<5;k++) {
        require(RecentBars[k]==195+k,"recent queue lost chronological order");
        require(RecentTypes[k]==(195+k)%2,"recent queue lost signal type");
    }
    require(ContextCount==0 && ContextBars.empty() && ContextTypes.empty(),"unused context index must not accumulate");
    require(MarkEnabled(0) && MarkEnabled(3) && !MarkEnabled(4),"compact mark selection");
}
int main(int argc,char** argv) {
    try {
        require(argc==2,"select a regression scenario");
        std::string scenario=argv[1];
        if(scenario=="startup") startup();
        else if(scenario=="incremental") incremental();
        else if(scenario=="lifecycle") lifecycle();
        else if(scenario=="recent") recent();
        else throw std::runtime_error("unknown scenario");
        std::cout<<scenario<<" passed\n";
        return 0;
    } catch(const std::exception& error) {std::cerr<<error.what()<<"\n";return 1;}
}
'''


class MetricCacheRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which("g++")
        if compiler is None:
            raise RuntimeError("g++ is required for the native cache regression adapter")
        source = SOURCE.read_text(encoding="utf-8-sig")
        globals_start = source.index("bool MetricCacheReady=")
        globals_end = source.index("void FreeMetricCache", globals_start)
        globals_code = source[globals_start:globals_end]
        globals_code = globals_code.replace("double CachedContextATR[],CachedTickRV[],CachedRealRV[];", "std::vector<double> CachedContextATR,CachedTickRV,CachedRealRV;")
        globals_code = globals_code.replace("int CachedRealMissing[];", "std::vector<int> CachedRealMissing;")
        names = ("FreeMetricCache", "PrepareMetricCache", "ContextATR", "QualityRelativeVolume", "UseRealWindow", "AppendIndex", "MarkValue", "MarkEnabled", "IndexDisplayBar")
        functions = "\n\n".join(extract_function(source, name) for name in names)
        functions = re.sub(r"int &(\w+)\[\]", r"std::vector<int>& \1", functions)
        cls.directory = tempfile.TemporaryDirectory(prefix="mql5-cache-regression-")
        cpp = Path(cls.directory.name) / "cache.cpp"
        cls.binary = Path(cls.directory.name) / "cache"
        cpp.write_text(ADAPTER + globals_code + functions + CASES, encoding="utf-8")
        subprocess.run([compiler, "-std=c++17", "-D_GLIBCXX_ASSERTIONS", "-O2", "-Wall", "-Wextra", "-pedantic", str(cpp), "-o", str(cls.binary)], check=True, capture_output=True, text=True)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def run_case(self, name):
        result = subprocess.run([str(self.binary), name], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_bounded_startup_and_raw_parity(self):
        self.run_case("startup")

    def test_incremental_wrap_and_history_jump(self):
        self.run_case("incremental")

    def test_history_reset_capacity_and_allocation_failure(self):
        self.run_case("lifecycle")

    def test_recent_marks_keep_only_five(self):
        self.run_case("recent")


if __name__ == "__main__":
    unittest.main()
