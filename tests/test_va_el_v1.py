"""Check actual VA_EL_V1 MQL bodies using a checked native C++ adapter.

Run: python3 -m unittest discover -s tests -p 'test_va_el_v1.py' -v
This adapter is not a substitute for MetaEditor compilation or chart validation.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from mql_source_adapter import extract_function

SOURCE = Path(__file__).resolve().parents[1] / "VA_EL_V1.mq5"

ADAPTER = r'''
#include <algorithm>
#include <climits>
#include <cmath>
#include <iostream>
#include <limits>
#include <numeric>
#include <random>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>
using datetime=long long;
using string=std::string;
using color=int;
bool _StopFlag=false;
long long indexedAccesses=0,volumeAccesses=0,realAccesses=0;
const void* measuredVolume=nullptr;
const void* measuredReal=nullptr;
const void* stopArray=nullptr;
int stopIndex=-1;
void touch(const void* a,std::size_t i) {
    ++indexedAccesses;
    if(a==measuredVolume) ++volumeAccesses;
    if(a==measuredReal) ++realAccesses;
    if(a==stopArray && int(i)==stopIndex) _StopFlag=true;
}
template<class T> struct Array:std::vector<T> {
    using std::vector<T>::vector;
    using std::vector<T>::operator=;
    T& operator[](std::size_t i) {touch(this,i);return std::vector<T>::operator[](i);}
    const T& operator[](std::size_t i) const {touch(this,i);return std::vector<T>::operator[](i);}
};
template<class A,class B> auto MathMax(A a,B b) {
    using C=std::common_type_t<A,B>;return std::max(C(a),C(b));
}
template<class A,class B> auto MathMin(A a,B b) {
    using C=std::common_type_t<A,B>;return std::min(C(a),C(b));
}
bool MathIsValidNumber(double a) {return std::isfinite(a);}
template<class T> void ArraySetAsSeries(const Array<T>&,bool) {}
const double EMPTY_VALUE=std::numeric_limits<double>::max();
const double POISON=-987654321.25;
enum {INIT_SUCCEEDED=0,INIT_PARAMETERS_INCORRECT=2,INIT_FAILED=-1};
enum {INDICATOR_DATA=0,INDICATOR_COLOR_INDEX=1,INDICATOR_CALCULATIONS=2};
enum {PLOT_COLOR_INDEXES=1,PLOT_LINE_COLOR,PLOT_DRAW_TYPE,PLOT_EMPTY_VALUE,PLOT_LABEL,PLOT_SHOW_DATA};
enum {INDICATOR_SHORTNAME=1,INDICATOR_DIGITS=2,DRAW_LINE=10,DRAW_NONE=11};
enum {clrSilver=1,clrPurple=2,clrGray=3};
int bindingFailure=-1,averagePlotType=-1;
std::vector<std::pair<int,int>> bindings;
string shortName;
bool SetIndexBuffer(int index,Array<double>&,int type) {
    bindings.push_back({index,type});return index!=bindingFailure;
}
void PlotIndexSetInteger(int p,int property,int value) {
    if(p==1 && property==PLOT_DRAW_TYPE) averagePlotType=value;
}
void PlotIndexSetInteger(int,int,int,int) {}
template<class... T> void PlotIndexSetDouble(T&&...) {}
template<class... T> void PlotIndexSetString(T&&...) {}
void IndicatorSetString(int,const string& value) {shortName=value;}
template<class... T> void IndicatorSetInteger(T&&...) {}
void require(bool condition,const string& message) {
    if(!condition) throw std::runtime_error(message);
}
void equal(double actual,double expected,const string& message) {
    if(expected==EMPTY_VALUE) require(actual==EMPTY_VALUE,message+" expected EMPTY_VALUE");
    else require(std::isfinite(actual) && std::abs(actual-expected)<=2e-9*std::max(1.0,std::abs(expected)),message);
}
'''

CASES = r'''
void initialize() {
    _StopFlag=false;stopArray=nullptr;stopIndex=-1;bindingFailure=-1;
    bindings.clear();averagePlotType=-1;
    FirstBarTime=991;UsingRealVolume=true;LatestRealVolumeBar=991;
    require(OnInit()==INIT_SUCCEEDED,"valid initialization failed");
    require(FirstBarTime==0 && !UsingRealVolume && LatestRealVolumeBar==-1,"OnInit did not reset source state");
    require(int(bindings.size())==EXPECTED_BUFFER_COUNT,"buffer binding count");
    const int kinds[]={INDICATOR_DATA,INDICATOR_COLOR_INDEX,INDICATOR_DATA,INDICATOR_DATA,INDICATOR_CALCULATIONS,INDICATOR_CALCULATIONS};
    for(int i=0;i<EXPECTED_BUFFER_COUNT;i++) require(bindings[i]==std::make_pair(i,kinds[i]),"buffer binding order/kind");
    measuredVolume=&BufferVolume;
}
struct Data {
    Array<datetime> time;
    Array<double> open,high,low,close;
    Array<long> ticks,real;
    Array<int> spread;
    explicit Data(int count=0) {
        grow(count);
        // A new terminal fixture owns fresh indicator-buffer storage.
        for(auto b:allBuffers) b->assign(count,POISON);
    }
    void grow(int count) {
        int before=int(time.size());
        time.resize(count);open.resize(count);high.resize(count);low.resize(count);close.resize(count);
        ticks.resize(count);real.resize(count);spread.resize(count);
        for(auto b:allBuffers) b->resize(count,POISON);
        for(int i=before;i<count;i++) {
            std::mt19937_64 generator(1271+9973LL*i);
            time[i]=1700000000LL+60*i;open[i]=100+i*0.01;
            close[i]=open[i]+(i%3-1)*0.25;high[i]=open[i]+1;low[i]=open[i]-1;
            ticks[i]=long(generator()%1200)-20;
            real[i]=(i%5==0?0:long(generator()%180)-5);spread[i]=1;
        }
    }
    int calculate(int previous) const {
        return OnCalculate(int(time.size()),previous,time,open,high,low,close,ticks,real,spread);
    }
};
std::vector<double> referenceVolumes(const Data& d) {
    bool useReal=inpVolumeType==vol_volume && std::any_of(d.real.begin(),d.real.end(),[](long v){return v>0;});
    std::vector<double> result;
    const auto& source=useReal?d.real:d.ticks;
    for(long v:source) result.push_back(std::max(0.0,double(v)));
    return result;
}
double referenceAverage(const std::vector<double>& volumes,int i) {
    int first=std::max(0,i-inpAveragePeriod+1),count=i-first+1;
    long double sum=std::accumulate(volumes.begin()+first,volumes.begin()+i+1,0.0L);
    if(inpAverageMethod==ma_sma) return double(sum/count);
    if(inpAverageMethod==ma_lwma) {
        long double weighted=0;
        for(int j=first;j<=i;j++) weighted+=(j-first+1.0L)*volumes[j];
        return double(weighted/(count*(count+1.0L)/2));
    }
    if(inpAverageMethod==ma_smma && i<inpAveragePeriod)
        return double(std::accumulate(volumes.begin(),volumes.begin()+i+1,0.0L)/(i+1));
    int seed=inpAverageMethod==ma_ema?0:inpAveragePeriod-1;
    long double alpha=inpAverageMethod==ma_ema?2.0L/(inpAveragePeriod+1.0L):1.0L/inpAveragePeriod;
    long double initial=std::accumulate(volumes.begin(),volumes.begin()+seed+1,0.0L)/(seed+1);
    long double result=initial*std::pow(1-alpha,i-seed);
    for(int j=seed+1;j<=i;j++) result+=alpha*volumes[j]*std::pow(1-alpha,i-j);
    return double(result);
}
int referenceTier(double ratio) {
    const double boundaries[]={inpLowVolStartRatio,inpMediumVolStartRatio,inpHighVolStartRatio,inpVeryHighVolStartRatio};
    return 1+int(std::count_if(std::begin(boundaries),std::end(boundaries),[ratio](double x){return ratio>=x;}));
}
void parity(const Data& d,int limit=-1) {
    auto values=referenceVolumes(d);
    int count=int(values.size());if(limit<0) limit=count;
    std::vector<double> averages;
    for(int i=0;i<limit;i++) averages.push_back(referenceAverage(values,i));
    for(int i=0;i<limit;i++) {
        equal(BufferVolume[i],values[i],"histogram source/unit mismatch at "+std::to_string(i));
        equal(BufferAverage[i],averages[i],"MA mismatch at "+std::to_string(i));
        int first=std::max(0,i-inpAveragePeriod+1);
        long double sum=0,weighted=0;
        for(int j=first;j<=i;j++) {sum+=values[j];weighted+=(j-first+1.0L)*values[j];}
        equal(BufferRollingSum[i],double(sum),"rolling sum mismatch");
        equal(BufferRollingWeighted[i],double(weighted),"weighted buffer mismatch");
        bool ready=i>0 && (!inpRequireFullPeriod || i>=inpAveragePeriod) && averages[i-1]>0;
        double ratio=ready?values[i]/averages[i-1]:EMPTY_VALUE;
        double displayedRatio=ready && std::isfinite(ratio)?ratio:EMPTY_VALUE;
        equal(BufferRelativeVolume[i],displayedRatio,"prior-MA relative volume mismatch");
        int colorIndex=0;
        if(ready && values[i]>0 && (!inpClosedColorsOnly || i<count-1)) {
            if(ratio>=inpAbnormalVolumeRatio) colorIndex=11;
            else if(d.close[i]!=d.open[i]) colorIndex=referenceTier(ratio)+(d.close[i]<d.open[i]?5:0);
        }
        equal(BufferColorIndex[i],colorIndex,"color mismatch at "+std::to_string(i));
    }
}
void batch() {
    for(int method=ma_sma;method<=ma_lwma;method++)
      for(int period:{1,2,20,401,INT_MAX})
       for(bool useReal:{false,true}) {
        defaults();inpAverageMethod=enMaTypes(method);inpAveragePeriod=period;
        inpVolumeType=useReal?vol_volume:vol_ticks;inpShowAverage=!useReal;initialize();
        Data d(241);require(d.calculate(0)==241,"batch result count");parity(d);
        require(averagePlotType==(inpShowAverage?DRAW_LINE:DRAW_NONE),"average visibility setting");
       }
}
void incremental() {
    for(int method=ma_sma;method<=ma_lwma;method++) for(int period:{1,2,20,401}) {
        defaults();inpAverageMethod=enMaTypes(method);inpAveragePeriod=period;initialize();Data d(1);
        require(d.calculate(0)==1,"initial one-bar count");
        for(int count=2;count<=77;count++) {
            d.ticks.back()+=73;d.close.back()=d.open.back()-0.5;
            require(d.calculate(count-1)==count-1,"active tick count");parity(d);
            d.grow(count);require(d.calculate(count-1)==count,"incremental count");parity(d);
        }
        // A same-length chart-window shift changes every indexed bar.
        for(int i=0;i<77;i++) {d.time[i]+=60;d.ticks[i]=700+i*3;}
        require(d.calculate(77)==77,"same-count shifted history count");parity(d);
        d.grow(18);require(d.calculate(77)==18,"shrinking history count");parity(d);
        d.ticks[0]=999;require(d.calculate(0)==18,"explicit historical reset");parity(d);
    }
}
void sourceTransitions() {
    for(int method=ma_sma;method<=ma_lwma;method++) {
        defaults();inpVolumeType=vol_volume;inpAverageMethod=enMaTypes(method);inpAveragePeriod=2;
        initialize();Data d(12);std::fill(d.real.begin(),d.real.end(),0);std::fill(d.ticks.begin(),d.ticks.end(),1000);
        d.calculate(0);require(!UsingRealVolume,"all-zero real history should fall back");parity(d);
        d.real.back()=10;d.calculate(12);
        require(UsingRealVolume && BufferVolume[0]==0,"new real availability must rebuild all prior bars in real units");parity(d);
        d.real.back()=0;d.calculate(12);
        require(!UsingRealVolume && BufferVolume[0]==1000,"removing final positive real sample must restore tick units");parity(d);
        d.real[4]=40;d.calculate(0);require(UsingRealVolume,"positive historical real volume");parity(d);
        d.ticks.back()=1000000000;d.calculate(12);
        require(UsingRealVolume && BufferVolume.back()==0 && BufferColorIndex.back()==0,"zero real tail must not become huge ticks");parity(d);
        d.grow(13);d.real.back()=0;d.ticks.back()=1000000000;d.calculate(12);parity(d);
        d.grow(4);d.calculate(13);require(!UsingRealVolume,"dropping sole positive bar should reset source");parity(d);
    }
    defaults();initialize();Data d(3);d.ticks[1]=-9;d.real[1]=-20;
    UsingRealVolume=false;equal(ReadVolume(1,d.ticks,d.real),0,"negative tick clamp");
    UsingRealVolume=true;equal(ReadVolume(1,d.ticks,d.real),0,"negative real clamp");
}
void colors() {
    for(int side:{-1,0,1}) for(int current:{0,49,50,99,100,149,150,199,200,299,300}) {
        defaults();inpAveragePeriod=1;initialize();Data d(3);d.ticks={100,current,100};
        d.open[1]=100;d.close[1]=100+side;d.calculate(0);parity(d);
    }
    defaults();inpAveragePeriod=20;initialize();Data d(25);
    std::fill(d.ticks.begin(),d.ticks.end(),100);d.ticks[19]=500;d.ticks[20]=500;d.calculate(0);parity(d);
    require(BufferRelativeVolume[19]==EMPTY_VALUE && BufferColorIndex[19]==0,"full PRIOR period needed before classification");
    require(BufferRelativeVolume[20]!=EMPTY_VALUE,"first complete prior window should classify");
    inpRequireFullPeriod=false;initialize();d.calculate(0);parity(d);
    require(BufferRelativeVolume[1]!=EMPTY_VALUE,"explicit partial-history mode");
    inpClosedColorsOnly=false;d.ticks.back()=5000;d.calculate(25);parity(d);
    require(BufferColorIndex.back()==11,"live color option must classify active extreme volume");
    inpClosedColorsOnly=true;d.calculate(25);parity(d);
    require(BufferColorIndex.back()==0 && BufferRelativeVolume.back()>0,"active ratio is available while color stays neutral");
    d.grow(26);d.calculate(25);parity(d);
    require(BufferColorIndex[24]==11,"new closed bar must be recolored");
    defaults();inpAveragePeriod=1;initialize();Data zero(3);zero.ticks={0,0,500};zero.calculate(0);parity(zero);
    require(BufferRelativeVolume.back()==EMPTY_VALUE,"zero prior average has no valid ratio");
}
void validation() {
    defaults();initialize();
    for(int period:{0,-1}) {defaults();inpAveragePeriod=period;require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid MA period");}
    defaults();inpAverageMethod=enMaTypes(4);require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid MA enum");
    defaults();inpVolumeType=enVolumeType(2);require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid source enum");
    for(int field=0;field<5;field++) for(double invalid:{std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity(),-std::numeric_limits<double>::infinity()}) {
        defaults();double* ratios[]={&inpLowVolStartRatio,&inpMediumVolStartRatio,&inpHighVolStartRatio,&inpVeryHighVolStartRatio,&inpAbnormalVolumeRatio};
        *ratios[field]=invalid;require(OnInit()==INIT_PARAMETERS_INCORRECT,"nonfinite ratio must be rejected");
    }
    defaults();inpLowVolStartRatio=0;require(OnInit()==INIT_PARAMETERS_INCORRECT,"zero low boundary");
    defaults();inpHighVolStartRatio=inpMediumVolStartRatio;require(OnInit()==INIT_PARAMETERS_INCORRECT,"equal boundaries");
    for(int failure=0;failure<EXPECTED_BUFFER_COUNT;failure++) {
        defaults();bindingFailure=failure;bindings.clear();
        require(OnInit()==INIT_FAILED,"buffer failure must fail initialization");
        require(bindings.back().first==failure,"expected failed binding was not attempted");
    }
    bindingFailure=-1;defaults();initialize();
}
void disabledAndStops() {
    defaults();inpEnabled=false;initialize();Data d(5);require(d.calculate(0)==5,"disabled count");
    d.grow(11);require(d.calculate(5)==11,"disabled growth count");
    for(int i=0;i<11;i++) {
        require(BufferVolume[i]==EMPTY_VALUE && BufferAverage[i]==EMPTY_VALUE && BufferRelativeVolume[i]==EMPTY_VALUE,"disabled new buffers must be hidden");
        require(BufferColorIndex[i]==0 && BufferRollingSum[i]==0 && BufferRollingWeighted[i]==0,"disabled new calculation buffers");
    }
    d.grow(3);d.calculate(11);require(BufferVolume[0]==EMPTY_VALUE,"disabled shrink");
    defaults();initialize();Data stopped(80);_StopFlag=true;
    require(stopped.calculate(0)==0 && BufferVolume[0]==POISON && FirstBarTime==0,"early stop must return before state/data access");
    _StopFlag=false;stopArray=&BufferVolume;stopIndex=30;
    int processed=stopped.calculate(0);require(processed==31,"stop must return actually completed prefix");
    stopArray=nullptr;_StopFlag=false;parity(stopped,31);
    require(BufferVolume[31]==POISON,"unprocessed suffix must remain untouched");
    require(stopped.calculate(processed)==80,"partial calculation resume count");parity(stopped);
    defaults();inpVolumeType=vol_volume;initialize();Data scan(80);std::fill(scan.real.begin(),scan.real.end(),0);
    stopArray=&scan.real;stopIndex=50;
    require(scan.calculate(0)==0 && BufferVolume[0]==POISON,"source-scan cancellation must not claim completion");
    stopArray=nullptr;_StopFlag=false;scan.calculate(0);parity(scan);
}
long long fullWork(int method,int count) {
    defaults();inpAverageMethod=enMaTypes(method);inpAveragePeriod=10000;initialize();Data d(count);
    std::fill(d.ticks.begin(),d.ticks.end(),100);volumeAccesses=0;
    d.calculate(0);return volumeAccesses;
}
void linearWork() {
    for(int method=ma_sma;method<=ma_lwma;method++) {
        auto small=fullWork(method,1000),large=fullWork(method,2000);
        require(large<=2*small+40,"warmup BufferVolume indexed accesses must grow linearly");
        require(large<30*2000,"warmup must not revisit entire earlier prefix");
    }
    defaults();inpVolumeType=vol_volume;initialize();Data d(10000);
    std::fill(d.real.begin(),d.real.end(),0);d.calculate(0);measuredReal=&d.real;
    for(int i=0;i<5;i++) {realAccesses=0;d.calculate(10000);require(realAccesses<=3,"fallback ticks must inspect only changed tail");}
    d.real[9990]=5;d.calculate(0);realAccesses=0;d.calculate(10000);
    require(realAccesses<=4 && UsingRealVolume,"known real history should avoid full rescans on ordinary ticks");
    measuredReal=nullptr;
}
void overflowDisplay() {
    for(auto method:{ma_ema,ma_smma}) {
        defaults();inpAverageMethod=method;inpAveragePeriod=20;initialize();
        Data d(15003);std::fill(d.ticks.begin(),d.ticks.end(),0);
        d.ticks[0]=1;d.ticks[15001]=1;
        require(d.calculate(0)==15003,"long zero-run completion");
        double prior=BufferAverage[15000];
        require(prior>0 && std::isfinite(prior),"decaying MA should retain a positive subnormal baseline");
        require(std::isinf(1.0/prior),"independent ratio should overflow at this baseline");
        require(BufferRelativeVolume[15001]==EMPTY_VALUE,"overflowing Data Window ratio must be hidden");
        require(BufferColorIndex[15001]==11,"overflowing ratio must retain extreme-volume classification");
        equal(BufferRelativeVolume[15002],0,"following zero-volume bar has a finite zero ratio");
        require(BufferColorIndex[15002]==0,"forming zero-volume bar remains neutral");
    }
}
int main(int argc,char** argv) {
    try {
        require(argc==2,"select a scenario");string name=argv[1];
        if(name=="batch") batch();else if(name=="incremental") incremental();
        else if(name=="sources") sourceTransitions();else if(name=="colors") colors();
        else if(name=="validation") validation();else if(name=="disabled_stops") disabledAndStops();
        else if(name=="linear") linearWork();else if(name=="overflow") overflowDisplay();
        else throw std::runtime_error("unknown scenario");
        std::cout<<name<<" passed\n";return 0;
    } catch(const std::exception& e) {std::cerr<<e.what()<<"\n";return 1;}
}
'''


class VolumeCoreRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which("g++")
        if compiler is None:
            raise RuntimeError("g++ is required for the native regression adapter")
        source = SOURCE.read_text(encoding="utf-8-sig")
        enums = "\n".join(re.findall(r"enum\s+\w+\s*\{.*?\};", source, re.S))
        inputs = re.findall(r"^input\s+(?!group\b)(\w+)\s+(\w+)\s*=\s*([^;]+);", source, re.M)

        def color_value(found):
            red, green, blue = map(int, found.groups())
            return str(red | green << 8 | blue << 16)

        declarations = "\n".join(f"{kind} {name}={value};" for kind, name, value in inputs)
        defaults = "void defaults(){\n" + "\n".join(f"{name}={value};" for _, name, value in inputs) + "\n}\n"
        declarations = re.sub(r"C'(\d+),(\d+),(\d+)'", color_value, declarations)
        defaults = re.sub(r"C'(\d+),(\d+),(\d+)'", color_value, defaults)
        globals_code = source[source.index("double BufferVolume[];"):source.index("double ReadVolume(")]
        buffers = re.findall(r"double\s+(\w+)\[\];", globals_code)
        globals_code = re.sub(r"double\s+(\w+)\[\];", r"Array<double> \1;", globals_code)
        count = re.search(r"#property\s+indicator_buffers\s+(\d+)", source).group(1)
        buffer_list = "std::vector<Array<double>*> allBuffers={" + ",".join("&" + name for name in buffers) + "};\n"
        functions = "\n\n".join(extract_function(source, name) for name in ("ReadVolume", "OnInit", "VolumeTier", "OnCalculate"))
        functions = functions.replace("std::vector<", "Array<")
        program = ADAPTER + enums + declarations + globals_code + f"const int EXPECTED_BUFFER_COUNT={count};\n" + buffer_list + defaults + functions + CASES
        cls.directory = tempfile.TemporaryDirectory(prefix="va-el-regression-")
        cpp = Path(cls.directory.name) / "volume.cpp"
        cls.binary = Path(cls.directory.name) / "volume"
        cpp.write_text(program, encoding="utf-8")
        built = subprocess.run([compiler, "-std=c++17", "-O2", "-D_GLIBCXX_ASSERTIONS", "-Wall", "-Wextra", "-pedantic", str(cpp), "-o", str(cls.binary)], capture_output=True, text=True)
        if built.returncode:
            cls.directory.cleanup()
            raise RuntimeError("Native adapter compilation failed:\n" + built.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def run_case(self, name):
        result = subprocess.run([str(self.binary), name], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_randomized_averages_and_exposed_buffers(self):
        self.run_case("batch")

    def test_incremental_ticks_and_history_resets(self):
        self.run_case("incremental")

    def test_real_volume_unit_consistency_and_source_transitions(self):
        self.run_case("sources")

    def test_prior_average_thresholds_warmup_and_closed_bar_colors(self):
        self.run_case("colors")

    def test_parameter_and_binding_validation(self):
        self.run_case("validation")

    def test_disabled_updates_and_interrupted_calculations(self):
        self.run_case("disabled_stops")

    def test_linear_warmup_and_constant_tail_source_checks(self):
        self.run_case("linear")

    def test_overflowing_relative_volume_display_preserves_extreme_color(self):
        self.run_case("overflow")


if __name__ == "__main__":
    unittest.main()
