"""Native adapters for actual Woodies CCI MQL functions, not MetaEditor tests."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from mql_source_adapter import extract_function

SOURCE = Path(__file__).resolve().parents[1] / "Woodies_CCI_MT5_V3_2_Light.mq5"

ADAPTER = r'''
#include <algorithm>
#include <cmath>
#include <cstdint>
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
const double EMPTY_VALUE=std::numeric_limits<double>::max();
const double POISON=-987654321.25;
const int INVALID_HANDLE=-1;
enum ENUM_APPLIED_PRICE {PRICE_CLOSE=0,PRICE_OPEN,PRICE_HIGH,PRICE_LOW,PRICE_MEDIAN,PRICE_TYPICAL,PRICE_WEIGHTED};
enum {INIT_SUCCEEDED=0,INIT_FAILED=-1,INIT_PARAMETERS_INCORRECT=2};
enum {INDICATOR_DATA=0,INDICATOR_CALCULATIONS=2};
enum {PLOT_ARROW=1,PLOT_SHIFT,PLOT_EMPTY_VALUE,PLOT_SHOW_DATA,PLOT_LABEL,PLOT_DRAW_BEGIN};
enum {INDICATOR_MINIMUM=1,INDICATOR_MAXIMUM,INDICATOR_DIGITS,INDICATOR_SHORTNAME};
const int PERIOD_M5=5;
int _Period=PERIOD_M5;
string _Symbol="TEST";
bool _StopFlag=false;
const void* stopArray=nullptr;
int stopIndex=-1;
const void* measuredRSI=nullptr;
const void* measuredPrice=nullptr;
const void* causalArray=nullptr;
int causalLast=-1;
long long rsiAccesses=0,priceAccesses=0;
void touch(const void* a,std::size_t index) {
    if(a==causalArray && int(index)>causalLast)throw std::runtime_error("future sample accessed");
    if(a==measuredRSI) ++rsiAccesses;
    if(a==measuredPrice) ++priceAccesses;
    if(a==stopArray && int(index)==stopIndex) _StopFlag=true;
}
template<class T> struct Array:std::vector<T> {
    using std::vector<T>::vector;
    using std::vector<T>::operator=;
    T& operator[](std::size_t i) {touch(this,i);return std::vector<T>::at(i);}
    const T& operator[](std::size_t i) const {touch(this,i);return std::vector<T>::at(i);}
};
template<class A,class B> auto MathMax(A a,B b) {using C=std::common_type_t<A,B>;return std::max(C(a),C(b));}
template<class A,class B> auto MathMin(A a,B b) {using C=std::common_type_t<A,B>;return std::min(C(a),C(b));}
double MathAbs(double x) {return std::abs(x);}
bool MathIsValidNumber(double x) {return std::isfinite(x);}
template<class T> void ArraySetAsSeries(const Array<T>&,bool) {}
template<class T> int ArraySize(const Array<T>& a) {return int(a.size());}
template<class T> int ArrayResize(Array<T>& a,int size) {a.resize(size);return size;}
template<class... T> void PlotIndexSetInteger(T&&...) {}
template<class... T> void PlotIndexSetDouble(T&&...) {}
template<class... T> void PlotIndexSetString(T&&...) {}
template<class... T> void IndicatorSetDouble(T&&...) {}
template<class... T> void IndicatorSetInteger(T&&...) {}
template<class... T> void IndicatorSetString(T&&...) {}
string IntegerToString(int n) {return std::to_string(n);}
int GetLastError() {return 1;}
template<class... T> void Print(T&&...) {}
int alertCount=0;
template<class... T> void Alert(T&&...) {++alertCount;}
int bindingFailure=-1,createdHandles=0,releasedHandles=0;
bool handleCreationFails=false;
std::vector<std::pair<int,int>> bindings;
bool SetIndexBuffer(int index,Array<double>&,int kind) {
    bindings.push_back({index,kind});return index!=bindingFailure;
}
int iRSI(const string&,int,int,ENUM_APPLIED_PRICE) {
    if(handleCreationFails) return INVALID_HANDLE;
    ++createdHandles;return 73;
}
bool IndicatorRelease(int handle) {if(handle!=INVALID_HANDLE)++releasedHandles;return true;}
int availableBars=0,copyShortfall=0,copyCalls=0;
std::vector<double> nativeRSI;
int BarsCalculated(int handle) {return handle==INVALID_HANDLE?-1:availableBars;}
int CopyBuffer(int,int,int,int count,Array<double>& target) {
    ++copyCalls;
    int actual=std::max(0,count-copyShortfall);
    target.resize(actual);
    if(int(nativeRSI.size())<actual) return -1;
    for(int i=0;i<actual;i++) target[i]=nativeRSI[nativeRSI.size()-actual+i];
    return actual;
}
void require(bool ok,const string& message) {if(!ok)throw std::runtime_error(message);}
void equal(double actual,double expected,const string& message) {
    if(expected==EMPTY_VALUE) require(actual==EMPTY_VALUE,message+" expected EMPTY_VALUE");
    else require(std::isfinite(actual) && std::abs(actual-expected)<=2e-8*std::max(1.0,std::abs(expected)),message);
}
'''

CASES = r'''
void initialize() {
    _StopFlag=false;stopArray=nullptr;stopIndex=-1;
    _Period=PERIOD_M5;bindingFailure=-1;handleCreationFails=false;
    bindings.clear();createdHandles=0;releasedHandles=0;
    alertCount=0;copyCalls=0;copyShortfall=0;
    require(OnInit()==INIT_SUCCEEDED,"valid OnInit rejected");
    require(int(bindings.size())==24,"all24 buffers must be bound");
    std::vector<bool> seen(24,false);
    for(auto [index,kind]:bindings) {
        require(index>=0 && index<24 && !seen[index],"duplicate or invalid buffer index");
        require(kind==(index<15?INDICATOR_DATA:INDICATOR_CALCULATIONS),"wrong buffer role");seen[index]=true;
    }
    measuredRSI=&RSIFilterBuffer;measuredPrice=&Price;
}
struct Data {
    Array<datetime> time;
    Array<double> open,high,low,close;
    Array<long> ticks,volume;
    Array<int> spread;
    explicit Data(int size) {
        grow(size);
        for(auto a:allBuffers) a->assign(size,POISON);
    }
    void grow(int size) {
        int old=int(time.size());
        time.resize(size);open.resize(size);high.resize(size);low.resize(size);close.resize(size);
        ticks.resize(size);volume.resize(size);spread.resize(size);
        for(auto a:allBuffers) a->resize(size,POISON);
        nativeRSI.resize(size);
        for(int i=old;i<size;i++) {
            time[i]=1700000000LL+i*300;
            close[i]=100+4*std::sin(i*0.19)+1.2*std::sin(i*0.91)+i*0.002;
            open[i]=close[i]-0.1;high[i]=close[i]+0.4;low[i]=close[i]-0.3;
            ticks[i]=100;volume[i]=0;spread[i]=1;
            nativeRSI[i]=50+15*std::sin(i*0.13)+5*std::sin(i*0.8);
        }
        availableBars=size;
    }
    int calculate(int previous) const {
        return OnCalculate(int(time.size()),previous,time,open,high,low,close,ticks,volume,spread);
    }
};
double referenceCCI(const std::vector<double>& prices,int i,int period) {
    if(period<2 || i<period-1) return EMPTY_VALUE;
    int first=i-period+1;long double average=0;
    for(int j=first;j<=i;j++) average+=static_cast<long double>(prices[j])-prices[first];
    average/=period;
    long double deviation=0;
    for(int j=first;j<=i;j++) deviation+=std::abs((static_cast<long double>(prices[j])-prices[first])-average);
    if(deviation==0) return 0;
    return double(((static_cast<long double>(prices[i])-prices[first])-average)/(0.015L*deviation/period));
}
bool validRSI(double v) {return std::isfinite(v) && v!=EMPTY_VALUE && v>=0 && v<=100;}
double referenceSlope(const std::vector<double>& values,int i,int n) {
    int first=i-n+1;
    if(n<2 || first<InpRSIPeriod) return EMPTY_VALUE;
    long double meanY=0,meanX=(n-1.0L)/2;
    for(int j=first;j<=i;j++) {if(!validRSI(values[j]))return EMPTY_VALUE;meanY+=values[j];}
    meanY/=n;long double numerator=0,denominator=0;
    for(int k=0;k<n;k++) {
        long double x=k-meanX;numerator+=x*(values[first+k]-meanY);denominator+=x*x;
    }
    return double(numerator/denominator);
}
bool referenceRSIPass(const std::vector<double>& rsi,int i,bool buy) {
    if(!InpUseRSIFilter) return true;
    if(i<InpRSIPeriod || !validRSI(rsi[i])) return false;
    if(InpUseRSIRegression) {
        double slope=referenceSlope(rsi,i,InpRSISlopeBars);
        if(slope==EMPTY_VALUE) return false;
        bool against=buy?slope<-InpRSISlopeDeadband:slope>InpRSISlopeDeadband;
        if(against) {
            if(!InpAllowRSIShortTurn) return false;
            double shortSlope=referenceSlope(rsi,i,InpRSIShortSlopeBars);
            if(shortSlope==EMPTY_VALUE || !(buy?shortSlope>InpRSIShortSlopeDeadband:shortSlope<-InpRSIShortSlopeDeadband)) return false;
        }
    }
    if(InpUseRSILevels && (buy?rsi[i]<InpRSIBuyFloor:rsi[i]>InpRSISellCeiling))return false;
    return !InpRequireRSISlope || (i>0 && validRSI(rsi[i-1]) && (buy?rsi[i]>rsi[i-1]:rsi[i]<rsi[i-1]));
}
void mathCCI() {
    for(int shape=0;shape<4;shape++) {
        Array<double> prices(220);std::mt19937 generator(8347);
        for(int i=0;i<220;i++) {
            if(shape==0)prices[i]=17.25;
            if(shape==1)prices[i]=5+i*0.125;
            if(shape==2)prices[i]=100+double(generator()%1000)/73;
            if(shape==3)prices[i]=1e12+double(int(generator()%1000)-500)*0.0001220703125;
        }
        for(int period:{2,6,14,89,300}) for(int i=0;i<220;i++) {
            causalArray=&prices;causalLast=i;
            equal(CCI(prices,i,period),referenceCCI(prices,i,period),"independent CCI shape/period mismatch");
        }
        causalArray=nullptr;
    }
    const double tiny=16*std::numeric_limits<double>::denorm_min();
    Array<double> prices={0,tiny,2*tiny,3*tiny};
    equal(CCI(prices,3,4),100,"underflowing .015*MAD must retain the finite mathematical CCI");
}
void mathRegression() {
    defaults();initialize();RSIFilterBuffer.resize(220);std::vector<double> values(220);
    for(int shape=0;shape<3;shape++) {
        for(int i=0;i<220;i++) values[i]=shape==0?50:(shape==1?30+i*0.1:50+20*std::sin(i*0.37));
        RSIFilterBuffer.assign(values.begin(),values.end());
        for(int n:{2,3,13,55})for(int i=0;i<220;i++) {
            causalArray=&RSIFilterBuffer;causalLast=i;
            equal(RSIRegressionSlope(i,n),referenceSlope(values,i,n),"independent RSI least-squares mismatch");
        }
        causalArray=nullptr;
    }
    for(double bad:{EMPTY_VALUE,-1.0,101.0,std::numeric_limits<double>::quiet_NaN()}) {
        std::fill(RSIFilterBuffer.begin(),RSIFilterBuffer.end(),50);RSIFilterBuffer[210]=bad;
        require(RSIRegressionSlope(219,13)==EMPTY_VALUE,"invalid RSI window must be rejected");
    }
}
void parity(const Data& d,bool signals=true) {
    int count=int(d.time.size());std::vector<double> prices(count),cci(count),turbo(count);std::vector<int> runs(count);
    for(int i=0;i<count;i++) {
        prices[i]=d.close[i]+((d.high[i]-d.close[i])+(d.low[i]-d.close[i]))/3;
        cci[i]=referenceCCI(prices,i,InpCCIPeriod);turbo[i]=referenceCCI(prices,i,InpTCCIPeriod);
        equal(CCIBuffer[i],cci[i],"CCI chart value mismatch at "+std::to_string(i));
        equal(TCCIBuffer[i],turbo[i],"Turbo chart value mismatch");
        equal(ZeroLineBuffer[i],InpZeroLevel,"zero line missing");
        equal(Upper100Buffer[i],InpUpper100,"upper level missing");
        equal(Lower100Buffer[i],InpLower100,"lower level missing");
        equal(Upper200Buffer[i],InpUpper200,"upper2 level missing");
        equal(Lower200Buffer[i],InpLower200,"lower2 level missing");
        int side=cci[i]==EMPTY_VALUE?0:(cci[i]>0?1:(cci[i]<0?-1:0));
        int prior=i>0 && cci[i-1]!=EMPTY_VALUE?(cci[i-1]>0?1:(cci[i-1]<0?-1:0)):0;
        runs[i]=cci[i]==EMPTY_VALUE?0:(i>0 && side!=0 && side==prior?runs[i-1]+1:1);
        equal(RunBuffer[i],runs[i],"histogram run mismatch");
        double expected[4]={EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE};
        if(cci[i]!=EMPTY_VALUE) expected[side==0 || runs[i]<=4?2:(runs[i]==5?3:(side>0?0:1))]=cci[i];
        double actual[]={HistDarkGreenBuffer[i],HistMaroonBuffer[i],HistGrayBuffer[i],HistYellowBuffer[i]};
        for(int k=0;k<4;k++)equal(actual[k],expected[k],"histogram color/run mismatch");
    }
    if(!signals) return;
    int first=std::max(InpCCIPeriod,InpTCCIPeriod),last=count-(InpClosedBarsOnly?2:1);
    int lastBuy=-1000000,lastSell=-1000000;bool buyUsed=false,sellUsed=false;
    for(int i=0;i<count;i++) {
        bool buy=false,sell=false;
        if(i==0 || cci[i-1]==EMPTY_VALUE)buyUsed=sellUsed=false;
        else {if(cci[i-1]>=0)buyUsed=false;if(cci[i-1]<=0)sellUsed=false;}
        auto turn=[&](bool isBuy){
            if(i<2 || turbo[i-2]==EMPTY_VALUE)return false;
            double old=turbo[i-1]-turbo[i-2],now=turbo[i]-turbo[i-1];
            return isBuy?(old<=0 && now>InpTurboMinTurn):(old>=0 && -now>InpTurboMinTurn);
        };
        auto histogram=[&](bool isBuy){
            if(i<1 || runs[i-1]<InpHistogramMinRun)return false;
            return isBuy?(cci[i-1]<0 && cci[i]>cci[i-1] && cci[i]-cci[i-1]>=InpHistogramMinRetreat)
                        :(cci[i-1]>0 && cci[i]<cci[i-1] && cci[i-1]-cci[i]>=InpHistogramMinRetreat);
        };
        if(i>=first && i<=last && cci[i-1]!=EMPTY_VALUE && cci[i]!=EMPTY_VALUE && turbo[i-1]!=EMPTY_VALUE && turbo[i]!=EMPTY_VALUE) {
            buy=cci[i-1]<=-InpReversalLevel && turbo[i]>turbo[i-1] && cci[i]>=cci[i-1];
            sell=cci[i-1]>=InpReversalLevel && turbo[i]<turbo[i-1] && cci[i]<=cci[i-1];
            buy=buy && referenceRSIPass(nativeRSI,i,true) && (!InpRequireTurboTurn || turn(true)) && (!InpUseHistogramFilter || histogram(true)) && (!InpOneSignalPerExtreme || !buyUsed);
            sell=sell && referenceRSIPass(nativeRSI,i,false) && (!InpRequireTurboTurn || turn(false)) && (!InpUseHistogramFilter || histogram(false)) && (!InpOneSignalPerExtreme || !sellUsed);
        }
        bool emitBuy=buy && !sell && i-lastBuy>=InpSignalCooldown;
        bool emitSell=sell && !buy && i-lastSell>=InpSignalCooldown;
        if(emitBuy){lastBuy=i;buyUsed=true;}
        if(emitSell){lastSell=i;sellUsed=true;}
        require((BuySignalBuffer[i]!=EMPTY_VALUE)==emitBuy,"independent BUY rule mismatch at "+std::to_string(i));
        require((SellSignalBuffer[i]!=EMPTY_VALUE)==emitSell,"independent SELL rule mismatch at "+std::to_string(i));
        require((BuyConfirmBuffer[i]!=EMPTY_VALUE)==(emitBuy && InpShowConfirmationDots && turn(true) && histogram(true)),"BUY confirmation must be additive on same candle");
        require((SellConfirmBuffer[i]!=EMPTY_VALUE)==(emitSell && InpShowConfirmationDots && turn(false) && histogram(false)),"SELL confirmation must be additive on same candle");
        if(emitBuy || emitSell) {
            double value=emitBuy?BuySignalBuffer[i]:SellSignalBuffer[i];
            require(std::isfinite(value),"marker must be finite");
            if(InpKeepMarkersVisible)require(value>=InpScaleMin && value<=InpScaleMax,"marker clipped outside scale");
        }
    }
}
void batchAndIncremental() {
    for(int mode=0;mode<8;mode++) {
        defaults();InpUseRSIFilter=mode!=0;InpClosedBarsOnly=(mode%2==0);
        InpRequireTurboTurn=(mode&2)!=0;InpUseHistogramFilter=(mode&4)!=0;
        InpOneSignalPerExtreme=(mode&1)!=0;InpSignalCooldown=mode%3;
        InpUseRSILevels=(mode&4)!=0;InpRequireRSISlope=(mode&2)!=0;
        InpReversalLevel=80;initialize();Data d(200);d.calculate(0);parity(d);
        d.close.back()+=0.9;d.high.back()+=1;d.calculate(200);parity(d);
        d.grow(203);d.calculate(200);parity(d);
        for(int i=0;i<203;i++){d.time[i]+=300;d.close[i]+=std::sin(i*0.71);}
        d.calculate(203);parity(d);
        d.grow(51);d.calculate(203);parity(d);
        d.close[4]+=1;d.calculate(0);parity(d);
    }
    defaults();InpReversalLevel=80;initialize();Data d(1);int previous=d.calculate(0);
    for(int n=2;n<=100;n++) {
        d.grow(n);previous=d.calculate(previous);require(previous==n,"incremental result cursor");parity(d);
    }
}
void rsiReadiness() {
    defaults();InpReversalLevel=80;initialize();Data d(120);availableBars=0;
    int previous=d.calculate(0);parity(d,false);
    for(int i=0;i<120;i++)require(BuySignalBuffer[i]==EMPTY_VALUE && SellSignalBuffer[i]==EMPTY_VALUE,"RSI wait must block arrows");
    d.grow(124);availableBars=0;previous=d.calculate(previous);parity(d,false);
    require(alertCount==0,"waiting cannot alert");
    availableBars=124;previous=d.calculate(previous);parity(d);
    require(alertCount==0,"initial delayed history cannot alert");
    d.grow(127);copyShortfall=1;previous=d.calculate(previous);parity(d,false);
    copyShortfall=0;previous=d.calculate(previous);parity(d);
    require(previous==127,"RSI recovery must finish chart cursor");
}
void copiedInvalidRSI() {
    for(double bad:{EMPTY_VALUE,std::numeric_limits<double>::quiet_NaN(),-1.0,101.0}) {
        defaults();InpReversalLevel=80;initialize();Data d(180);
        double saved=nativeRSI[78];nativeRSI[78]=bad;
        int previous=d.calculate(0);
        require(previous==180 && g_signalCalculated==0 && g_rsiWaiting,"full-count invalid closed RSI must retain the signal cursor");
        parity(d,false);
        for(int i=0;i<180;i++)require(BuySignalBuffer[i]==EMPTY_VALUE && SellSignalBuffer[i]==EMPTY_VALUE,"invalid RSI history cannot emit signals");
        nativeRSI[78]=saved;int before=copyCalls;previous=d.calculate(previous);
        require(copyCalls==before+1 && g_signalCalculated==180 && !g_rsiWaiting,"same-count valid retry must bypass fast path and commit signals");
        parity(d);require(alertCount==0,"delayed initial RSI recovery must not alert history");
        d.grow(181);saved=nativeRSI[179];nativeRSI[179]=bad;
        previous=d.calculate(previous);parity(d,false);
        require(previous==181 && g_signalCalculated==180 && g_rsiWaiting,"invalid newly closed RSI must preserve prior completed signal prefix");
        nativeRSI[179]=saved;before=copyCalls;d.calculate(previous);
        require(copyCalls==before+1 && g_signalCalculated==181 && !g_rsiWaiting,"incremental invalid RSI recovery must retry pending suffix");parity(d);

        defaults();InpReversalLevel=80;initialize();Data forming(180);
        nativeRSI[0]=bad;nativeRSI.back()=bad;forming.calculate(0);
        require(g_signalCalculated==180 && !g_rsiWaiting,"warmup and forming invalid RSI must not block closed-bar signals");parity(forming);
        defaults();InpClosedBarsOnly=false;InpReversalLevel=80;initialize();Data live(180);
        saved=nativeRSI.back();nativeRSI.back()=bad;previous=live.calculate(0);
        require(previous==180 && g_signalCalculated==0 && g_rsiWaiting,"invalid forming RSI must block live signal mode");parity(live,false);
        nativeRSI.back()=saved;live.calculate(previous);
        require(g_signalCalculated==180 && !g_rsiWaiting,"live RSI retry must recover");parity(live);
    }
}
void bindingsAndParameters() {
    defaults();initialize();OnDeinit(0);require(releasedHandles==createdHandles,"normal teardown releases RSI");
    for(int failed=0;failed<24;failed++) {
        defaults();bindings.clear();bindingFailure=failed;createdHandles=releasedHandles=0;
        require(OnInit()==INIT_FAILED,"failed binding must reject initialization");
        require(createdHandles==releasedHandles,"failed initialization leaks RSI handle");
    }
    bindingFailure=-1;handleCreationFails=true;require(OnInit()==INIT_FAILED,"failed RSI handle must reject init");handleCreationFails=false;
    defaults();InpCCIPeriod=1;require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid CCI period");
    defaults();InpScaleMax=InpScaleMin;require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid scale");
    defaults();InpScaleMin=-std::numeric_limits<double>::max();InpScaleMax=std::numeric_limits<double>::max();
    require(OnInit()==INIT_PARAMETERS_INCORRECT,"overflowing scale span must be rejected");
    defaults();InpRSISlopeDeadband=std::numeric_limits<double>::quiet_NaN();require(OnInit()==INIT_PARAMETERS_INCORRECT,"NaN RSI deadband");
}
void alerts() {
    defaults();initialize();Data d(50);
    std::fill(BuySignalBuffer.begin(),BuySignalBuffer.end(),EMPTY_VALUE);std::fill(SellSignalBuffer.begin(),SellSignalBuffer.end(),EMPTY_VALUE);
    BuySignalBuffer[48]=0;CheckM5SignalAlert(50,d.time);require(alertCount==0,"startup historical arrow must not alert");
    CheckM5SignalAlert(50,d.time);require(alertCount==0,"startup arrow must stay deduplicated");
    d.grow(51);BuySignalBuffer[49]=0;SellSignalBuffer[49]=EMPTY_VALUE;CheckM5SignalAlert(51,d.time);
    require(alertCount==1,"new closed arrow must alert");CheckM5SignalAlert(51,d.time);require(alertCount==1,"same arrow must not alert twice");
    _Period=1;d.grow(52);BuySignalBuffer[50]=0;CheckM5SignalAlert(52,d.time);require(alertCount==1,"nonM5 chart must not alert");
}
void cancellation() {
    defaults();initialize();Data d(160);_StopFlag=true;
    require(d.calculate(0)==0 && CCIBuffer[0]==POISON,"early stop must leave buffers untouched");
    _StopFlag=false;stopArray=&d.high;stopIndex=75;
    int previous=d.calculate(0);require(previous>=0 && previous<160,"cancelled history cannot claim full calculation");
    stopArray=nullptr;_StopFlag=false;
    require(d.calculate(previous)==160,"cancelled calculation must resume");parity(d);
}
void boundedWork() {
    defaults();InpReversalLevel=1e9;initialize();Data d(600);rsiAccesses=0;
    d.calculate(0);require(rsiAccesses<600*5,"RSI regressions must be skipped without reversal candidates");parity(d);
    defaults();InpUseRSIFilter=false;InpCCIPeriod=14;InpTCCIPeriod=14;initialize();Data same(600);priceAccesses=0;
    same.calculate(0);require(priceAccesses<600*42,"identical CCI periods should share one exact calculation");parity(same);
}
void copyTailWork() {
    defaults();initialize();Data d(180);int previous=d.calculate(0);int before=copyCalls;
    d.close.back()+=0.7;nativeRSI.back()=90;previous=d.calculate(previous);
    require(copyCalls==before,"ordinary closed-bar ticks must not copy RSI again");parity(d);
    d.grow(181);previous=d.calculate(previous);
    require(copyCalls==before+1,"newly closed bar must refresh RSI");parity(d);
    d.grow(182);availableBars=0;previous=d.calculate(previous);before=copyCalls;
    availableBars=182;previous=d.calculate(previous);
    require(copyCalls==before+1,"pending RSI retry must bypass the fast path");parity(d);
    before=copyCalls;previous=d.calculate(0);
    require(copyCalls==before+1,"history reset must refresh RSI");parity(d);
    defaults();InpClosedBarsOnly=false;initialize();Data live(180);previous=live.calculate(0);before=copyCalls;
    nativeRSI.back()=90;live.close.back()+=0.5;live.calculate(previous);
    require(copyCalls==before+1,"live signal mode must refresh forming RSI");parity(live);
}
int main(int argc,char** argv) {
    try {
        require(argc==2,"select a test scenario");string name=argv[1];
        if(name=="cci")mathCCI();else if(name=="regression")mathRegression();
        else if(name=="lifecycle")batchAndIncremental();else if(name=="readiness")rsiReadiness();else if(name=="invalid_rsi")copiedInvalidRSI();
        else if(name=="bindings")bindingsAndParameters();else if(name=="alerts")alerts();
        else if(name=="stop")cancellation();else if(name=="work")boundedWork();else if(name=="copies")copyTailWork();
        else throw std::runtime_error("unknown scenario");
        std::cout<<name<<" passed\n";return 0;
    } catch(const std::exception& error) {std::cerr<<error.what()<<"\n";return 1;}
}
'''


class WoodiesCCIRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which("g++")
        if compiler is None:
            raise RuntimeError("g++ is required for the Woodies native adapter")
        source = SOURCE.read_text(encoding="utf-8-sig")
        inputs = re.findall(r"^input\s+(?!group\b)(\w+)\s+(\w+)\s*=\s*([^;]+);", source, re.M)
        declarations = "\n".join(f"{kind} {name}={value};" for kind, name, value in inputs)
        defaults = "void defaults(){\n" + "\n".join(f"{name}={value};" for _, name, value in inputs) + "\n}\n"
        first_function = re.search(r"^(?:bool|void|int|double)\s+\w+\s*\(", source, re.M).start()
        globals_code = source[source.index("double HistDarkGreenBuffer[];"):first_function]
        buffers = [name for name in re.findall(r"double\s+(\w+)\[\];", globals_code) if name != "RSICopy"]
        globals_code = re.sub(r"double\s+(\w+)\[\];", r"Array<double> \1;", globals_code)
        buffer_list = "std::vector<Array<double>*> allBuffers={" + ",".join("&" + name for name in buffers) + "};\n"
        names = re.findall(r"^(?:bool|void|int|double)\s+(\w+)\s*\(", source, re.M)
        functions, prototypes = [], []
        for name in names:
            code = extract_function(source, name).replace("std::vector<", "Array<")
            opening = code.index("{")
            signature = code[:opening]
            prototypes.append(signature + ";")
            signature = re.sub(r"=\s*[^,)]+", "", signature)
            functions.append(signature + code[opening:])
        program = ADAPTER + declarations + globals_code + buffer_list + defaults + "\n".join(prototypes + functions) + CASES
        cls.directory = tempfile.TemporaryDirectory(prefix="woodies-regression-")
        cpp = Path(cls.directory.name) / "woodies.cpp"
        cls.binary = Path(cls.directory.name) / "woodies"
        cpp.write_text(program, encoding="utf-8")
        built = subprocess.run([compiler, "-std=c++17", "-O2", "-D_GLIBCXX_ASSERTIONS", "-Wall", "-Wextra", "-pedantic", str(cpp), "-o", str(cls.binary)], capture_output=True, text=True)
        if built.returncode:
            cls.directory.cleanup()
            raise RuntimeError("Woodies native adapter compilation failed:\n" + built.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def run_case(self, case):
        result = subprocess.run([str(self.binary), case], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_independent_cci_mean_absolute_deviation(self):
        self.run_case("cci")

    def test_independent_rsi_least_squares(self):
        self.run_case("regression")

    def test_signal_reference_and_incremental_history_lifecycle(self):
        self.run_case("lifecycle")

    def test_rsi_wait_updates_cci_and_replays_signals(self):
        self.run_case("readiness")

    def test_full_count_invalid_rsi_retries_and_forming_mode_rules(self):
        self.run_case("invalid_rsi")

    def test_buffer_binding_failures_and_parameter_validation(self):
        self.run_case("bindings")

    def test_m5_alert_initialization_and_deduplication(self):
        self.run_case("alerts")

    def test_stop_and_resume(self):
        self.run_case("stop")

    def test_candidate_regression_and_identical_period_work(self):
        self.run_case("work")

    def test_closed_bar_rsi_copy_fast_path_and_retry_exceptions(self):
        self.run_case("copies")


if __name__ == "__main__":
    unittest.main()
