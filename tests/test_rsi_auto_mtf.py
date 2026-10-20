"""Exercise actual RSI Auto MTF MQL bodies through a checked native adapter.

This validates mapping/lifecycle logic, not MetaEditor compilation or MT5.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from mql_source_adapter import extract_function

SOURCE = Path(__file__).resolve().parents[1] / "RSI_Auto_3TF.mq5"

ADAPTER = r'''
#include <algorithm>
#include <cmath>
#include <ctime>
#include <iostream>
#include <climits>
#include <limits>
#include <map>
#include <numeric>
#include <set>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>
using datetime=long long;
using string=std::string;
using color=int;
enum ENUM_TIMEFRAMES {
 PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M2=2,PERIOD_M3=3,PERIOD_M4=4,PERIOD_M5=5,
 PERIOD_M6=6,PERIOD_M10=10,PERIOD_M12=12,PERIOD_M15=15,PERIOD_M20=20,PERIOD_M30=30,
 PERIOD_H1=16385,PERIOD_H2=16386,PERIOD_H3=16387,PERIOD_H4=16388,PERIOD_H6=16390,
 PERIOD_H8=16392,PERIOD_H12=16396,PERIOD_D1=16408,PERIOD_W1=32769,PERIOD_MN1=49153
};
enum ENUM_APPLIED_PRICE {PRICE_CLOSE=1,PRICE_OPEN,PRICE_HIGH,PRICE_LOW,PRICE_MEDIAN,PRICE_TYPICAL,PRICE_WEIGHTED};
enum ENUM_LINE_STYLE {STYLE_SOLID=0,STYLE_DASH,STYLE_DOT,STYLE_DASHDOT,STYLE_DASHDOTDOT};
enum {clrWhite=1,clrGreen,clrOrange,clrViolet,clrYellow,clrDimGray};
enum {INVALID_HANDLE=-1,INIT_SUCCEEDED=0,INIT_FAILED=-1,INIT_PARAMETERS_INCORRECT=2,INDICATOR_DATA=0,MODE_SMA=0};
enum {PLOT_LABEL=1,PLOT_LINE_COLOR,PLOT_LINE_WIDTH,PLOT_LINE_STYLE,PLOT_EMPTY_VALUE,PLOT_DRAW_BEGIN};
enum {INDICATOR_SHORTNAME=1,INDICATOR_DIGITS=2};
const double EMPTY_VALUE=std::numeric_limits<double>::max(),POISON=-999123.25;
bool _StopFlag=false;
ENUM_TIMEFRAMES _Period=PERIOD_H1;
string _Symbol="TEST";
datetime serverNow=0;
unsigned long long milliseconds=100000;
const void* stopArray=nullptr;
int stopIndex=-1;
template<class T> struct Array:std::vector<T> {
 using std::vector<T>::vector;
 using std::vector<T>::operator=;
 mutable bool series=false;
 T& physical(std::size_t i) {return std::vector<T>::at(i);}
 const T& physical(std::size_t i) const {return std::vector<T>::at(i);}
 T& operator[](std::size_t i) {
  if(this==stopArray && int(i)==stopIndex) _StopFlag=true;
  return physical(series?this->size()-1-i:i);
 }
 const T& operator[](std::size_t i) const {
  if(this==stopArray && int(i)==stopIndex) _StopFlag=true;
  return physical(series?this->size()-1-i:i);
 }
};
template<class T> bool ArraySetAsSeries(const Array<T>& a,bool series) {a.series=series;return true;}
template<class T> int ArraySize(const Array<T>& a) {return int(a.size());}
template<class T,std::size_t N> int ArraySize(const T(&)[N]) {return N;}
template<class T> int ArrayResize(Array<T>& a,int n) {a.resize(n);return n;}
template<class T> void ArrayFree(Array<T>& a) {a.clear();}
template<class T,class V> int ArrayInitialize(Array<T>& a,V v) {std::fill(a.begin(),a.end(),T(v));return a.size();}
template<class T,std::size_t N,class V> int ArrayInitialize(T(&a)[N],V v) {std::fill(std::begin(a),std::end(a),T(v));return N;}
template<class A,class B> auto MathMin(A a,B b) {using C=std::common_type_t<A,B>;return std::min(C(a),C(b));}
template<class A,class B> auto MathMax(A a,B b) {using C=std::common_type_t<A,B>;return std::max(C(a),C(b));}
double MathAbs(double v) {return std::abs(v);}
bool MathIsValidNumber(double v) {return std::isfinite(v);}
datetime TimeCurrent() {return serverNow;}
unsigned long long GetTickCount64() {return milliseconds;}
int GetLastError() {return 1;}
void ResetLastError() {}
template<class... T> void Print(T&&...) {}
template<class... T> bool PlotIndexSetInteger(T&&...) {return true;}
template<class... T> bool PlotIndexSetDouble(T&&...) {return true;}
template<class... T> bool PlotIndexSetString(T&&...) {return true;}
template<class... T> bool IndicatorSetString(T&&...) {return true;}
template<class... T> bool IndicatorSetInteger(T&&...) {return true;}
string IntegerToString(int v) {return std::to_string(v);}
int StringReplace(string& value,const string& from,const string& to) {
 int count=0;std::size_t at=0;
 while((at=value.find(from,at))!=string::npos) {value.replace(at,from.size(),to);at+=to.size();++count;}
 return count;
}
int PeriodSeconds(ENUM_TIMEFRAMES tf) {
 if(tf==PERIOD_CURRENT)tf=_Period;
 if(tf>=PERIOD_M1 && tf<=PERIOD_M30) return int(tf)*60;
 if(tf>=PERIOD_H1 && tf<=PERIOD_H12) return (int(tf)-16384)*3600;
 if(tf==PERIOD_D1)return 86400;
 if(tf==PERIOD_W1)return 604800;
 if(tf==PERIOD_MN1)return 2592000;
 return 0;
}
string EnumToString(ENUM_TIMEFRAMES tf) {return "PERIOD_"+std::to_string(int(tf));}
struct MqlDateTime {int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0,day_of_year=0;};
bool TimeToStruct(datetime value,MqlDateTime& d) {
 time_t raw=value;std::tm* t=std::gmtime(&raw);if(!t)return false;
 d={t->tm_year+1900,t->tm_mon+1,t->tm_mday,t->tm_hour,t->tm_min,t->tm_sec,t->tm_wday,t->tm_yday};return true;
}
datetime StructToTime(const MqlDateTime& d) {
 std::tm t={};t.tm_year=d.year-1900;t.tm_mon=d.mon-1;t.tm_mday=d.day;
 t.tm_hour=d.hour;t.tm_min=d.min;t.tm_sec=d.sec;return timegm(&t);
}
datetime stamp(int year,int month,int day,int hour=0,int minute=0,int second=0) {
 std::tm t={};t.tm_year=year-1900;t.tm_mon=month-1;t.tm_mday=day;
 t.tm_hour=hour;t.tm_min=minute;t.tm_sec=second;return timegm(&t);
}
struct Series {
 std::vector<datetime> opens;
 std::vector<double> rsi;
 int calculated=-1,timeShortfall=0,valueShortfall=0,lag=0,readableRecent=-1;
 bool rollOnTimeCopy=false;
};
struct Handle {
 ENUM_TIMEFRAMES tf;bool movingAverage;int input;
 int reportedCount=INT_MIN,readableRecent=-1;
};
std::map<ENUM_TIMEFRAMES,Series> sources;
std::map<int,Handle> handles;
std::set<int> released;
int nextHandle=50,createdRSI=0,createdMA=0,creationAttempt=0,failCreation=-1;
int failedBinding=-1,copyCalls=0,timeCopyCalls=0,barShiftCalls=0,maxCopyRequest=0;
std::vector<int> bound;
std::map<int,int> handleCopies;
bool SetIndexBuffer(int index,Array<double>&,int) {bound.push_back(index);return index!=failedBinding;}
int iRSI(const string&,ENUM_TIMEFRAMES tf,int,ENUM_APPLIED_PRICE) {
 if(creationAttempt++==failCreation)return INVALID_HANDLE;
 int h=nextHandle++;handles[h]={tf,false,-1};++createdRSI;return h;
}
int iMA(const string&,ENUM_TIMEFRAMES tf,int period,int shift,int method,int input) {
 if(creationAttempt++==failCreation)return INVALID_HANDLE;
 if(period!=7 || shift!=0 || method!=MODE_SMA || !handles.count(input))throw std::runtime_error("unexpected SMA definition");
 int h=nextHandle++;handles[h]={tf,true,input};++createdMA;return h;
}
bool IndicatorRelease(int h) {
 if(!handles.count(h) || released.count(h))throw std::runtime_error("invalid/double handle release");
 for(const auto& pair:handles) if(!released.count(pair.first) && pair.second.movingAverage && pair.second.input==h)
  throw std::runtime_error("RSI dependency released before SMA handle");
 released.insert(h);return true;
}
int iBars(const string&,ENUM_TIMEFRAMES tf) {return sources[tf].opens.size();}
int Bars(const string& s,ENUM_TIMEFRAMES tf) {return iBars(s,tf);}
datetime iTime(const string&,ENUM_TIMEFRAMES tf,int shift) {
 const auto& a=sources[tf].opens;return shift>=0 && shift<int(a.size())?a[a.size()-1-shift]:0;
}
int iBarShift(const string&,ENUM_TIMEFRAMES tf,datetime endpoint,bool exact) {
 ++barShiftCalls;const auto& a=sources[tf].opens;
 auto at=std::upper_bound(a.begin(),a.end(),endpoint);if(at==a.begin())return -1;
 --at;if(exact && *at!=endpoint)return -1;return a.end()-at-1;
}
int BarsCalculated(int h) {
 if(!handles.count(h) || released.count(h))return -1;
 if(handles[h].reportedCount!=INT_MIN)return handles[h].reportedCount;
 const auto& a=sources[handles[h].tf];return a.calculated<0?int(a.opens.size()):a.calculated;
}
int readableFirst(int h) {
 const auto& handle=handles.at(h);const auto& source=sources.at(handle.tf);
 int count=handle.readableRecent>=0?handle.readableRecent:source.readableRecent;
 return count<0?0:std::max(0,int(source.opens.size())-count);
}
double nativeValue(int h,int ascendingIndex) {
 const auto& handle=handles.at(h);const auto& a=sources.at(handle.tf);
 if(ascendingIndex<0 || ascendingIndex>=int(a.rsi.size()))return EMPTY_VALUE;
 if(!handle.movingAverage)return a.rsi[ascendingIndex];
 if(ascendingIndex<6)return EMPTY_VALUE;
 long double sum=0;
 for(int j=ascendingIndex-6;j<=ascendingIndex;j++) {
  double v=nativeValue(handle.input,j);
  if(!std::isfinite(v) || v==EMPTY_VALUE || v<0 || v>100)return EMPTY_VALUE;
  sum+=v;
 }
 return double(sum/7);
}
int CopyTime(const string&,ENUM_TIMEFRAMES tf,int shift,int count,Array<datetime>& target) {
 ++timeCopyCalls;maxCopyRequest=std::max(maxCopyRequest,count);
 auto& a=sources[tf];int end=int(a.opens.size())-shift;
 int start=std::max(0,end-count),actual=std::max(0,end-start-a.timeShortfall);
 target.resize(actual);for(int i=0;i<actual;i++)target.physical(i)=a.opens[start+i];
 if(a.rollOnTimeCopy) {
  a.rollOnTimeCopy=false;a.opens.push_back(a.opens.back()+PeriodSeconds(tf));a.rsi.push_back(67.0);
 }
 return actual;
}
int CopyBuffer(int h,int,int shift,int count,Array<double>& target) {
 ++copyCalls;++handleCopies[h];maxCopyRequest=std::max(maxCopyRequest,count);
 auto& a=sources[handles.at(h).tf];int end=int(a.opens.size())-shift-a.lag;
 int start=std::max(readableFirst(h),std::max(0,end-count));
 int actual=std::max(0,end-start-a.valueShortfall);
 target.resize(actual);for(int i=0;i<actual;i++)target.physical(i)=nativeValue(h,start+i);
 return actual;
}
int CopyBuffer(int h,int,datetime begin,datetime end,Array<double>& target) {
 ++copyCalls;++handleCopies[h];auto& a=sources[handles.at(h).tf];
 int first=std::lower_bound(a.opens.begin(),a.opens.end(),begin)-a.opens.begin();
 int stop=std::upper_bound(a.opens.begin(),a.opens.end(),end)-a.opens.begin();
 maxCopyRequest=std::max(maxCopyRequest,stop-first);
 first=std::max(first,readableFirst(h));
 stop=std::min(stop,int(a.opens.size())-a.lag);stop=std::max(first,stop-a.valueShortfall);
 int count=std::max(0,stop-first);target.resize(count);
 for(int i=0;i<count;i++)target.physical(i)=nativeValue(h,first+i);
 return count;
}
void require(bool ok,const string& message) {if(!ok)throw std::runtime_error(message);}
void equal(double got,double expected,const string& message) {
 if(expected==EMPTY_VALUE)require(got==EMPTY_VALUE,message+" expected EMPTY_VALUE");
 else require(std::isfinite(got) && std::abs(got-expected)<=1e-10*std::max(1.0,std::abs(expected)),message);
}
'''

CASES = r'''
std::vector<Array<double>*> plots() {return {&Lower,&Current,&Higher,&Fourth,&SMA7};}
void cleanup() {
 OnDeinit(0);
 require(released.size()==handles.size(),"native handle leaked");
}
void resetHarness(ENUM_TIMEFRAMES chart=PERIOD_H1) {
 cleanup();handles.clear();released.clear();sources.clear();bound.clear();
 nextHandle=50;createdRSI=createdMA=creationAttempt=0;failCreation=-1;failedBinding=-1;
 copyCalls=timeCopyCalls=barShiftCalls=maxCopyRequest=0;handleCopies.clear();
 _StopFlag=false;stopArray=nullptr;stopIndex=-1;milliseconds=100000;serverNow=0;
 defaults();_Period=chart;InpAutoTimeframes=false;
 InpTF1=PERIOD_M5;InpTF2=PERIOD_CURRENT;InpTF3=PERIOD_H4;InpTF4=PERIOD_D1;
 InpHistoryBars=100;
}
void start() {
 require(OnInit()==INIT_SUCCEEDED,"valid initialization failed");
 require(bound==std::vector<int>({0,1,2,3,4}),"five plot bindings in order");
 for(auto p:plots())require(p->series,"plot must use series indices");
}
datetime nextOpen(datetime opened,ENUM_TIMEFRAMES tf) {
 if(tf!=PERIOD_MN1)return opened+PeriodSeconds(tf);
 time_t raw=opened;std::tm t=*std::gmtime(&raw);
 t.tm_mday=1;t.tm_hour=t.tm_min=t.tm_sec=0;++t.tm_mon;return timegm(&t);
}
void fillValues(Series& a) {
 a.rsi.resize(a.opens.size());
 for(int i=0;i<int(a.rsi.size());i++)a.rsi[i]=i<InpRSIPeriod?EMPTY_VALUE:18.0+double((i*17+11)%73);
}
void cover(ENUM_TIMEFRAMES tf,datetime chartFirst,datetime until) {
 Series a;
 datetime beginning;
 if(tf==PERIOD_MN1) {
  time_t raw=chartFirst;std::tm t=*std::gmtime(&raw);
  t.tm_year-=6;t.tm_mday=1;t.tm_hour=t.tm_min=t.tm_sec=0;beginning=timegm(&t);
 } else {
  int sec=PeriodSeconds(tf);beginning=chartFirst/sec*sec-64LL*sec;
 }
 for(datetime t=beginning;t<=until;t=nextOpen(t,tf))a.opens.push_back(t);
 fillValues(a);sources[tf]=std::move(a);
}
void coverAll(datetime beginning,datetime until) {
 std::set<ENUM_TIMEFRAMES> unique(std::begin(TF),std::end(TF));
 for(auto tf:unique)cover(tf,beginning,until);
}
struct Chart {
 Array<datetime> time;
 Array<double> open,high,low,close;
 Array<long> ticks,volume;
 Array<int> spread;
 explicit Chart(const std::vector<datetime>& dates) {
  time.assign(dates.begin(),dates.end());
  for(auto p:plots())p->assign(dates.size(),POISON);
  resizeOthers(dates.size());
 }
 Chart(datetime first,int count) {
  for(int i=0;i<count;i++) {time.push_back(first);first=nextOpen(first,_Period);}
  for(auto p:plots())p->assign(count,POISON);
  resizeOthers(count);
 }
 void resizeOthers(int n) {
  open.resize(n,100);high.resize(n,101);low.resize(n,99);close.resize(n,100);
  ticks.resize(n,100);volume.resize(n,0);spread.resize(n,1);
 }
 void append(int count) {
  datetime t=time.physical(time.size()-1);
  for(int i=0;i<count;i++) {t=nextOpen(t,_Period);time.push_back(t);}
  for(auto p:plots())p->resize(time.size(),POISON);
  resizeOthers(time.size());
 }
 void dropOldest(int count) {
  time.erase(time.begin(),time.begin()+count);
  for(auto p:plots())p->erase(p->begin(),p->begin()+count);
  resizeOthers(time.size());
 }
 int calculate(int previous) const {
  return OnCalculate(time.size(),previous,time,open,high,low,close,ticks,volume,spread);
 }
 datetime oldest() const {return time.physical(0);}
 datetime newest() const {return time.physical(time.size()-1);}
};
bool good(double v) {return std::isfinite(v) && v!=EMPTY_VALUE && v>=0 && v<=100;}
double expectedAt(int line,const Chart& d,int chartIndex) {
 if(chartIndex>=InpHistoryBars)return EMPTY_VALUE;
 datetime endpoint=serverNow;
 if(chartIndex>0)endpoint=std::min(nextOpen(d.time[chartIndex],_Period),d.time[chartIndex-1]);
 const auto& s=sources.at(TF[line]);int chosen=-1;
 for(int j=0;j<int(s.opens.size());j++) {
  if(s.opens[j]>endpoint)break;
  datetime closed=nextOpen(s.opens[j],TF[line]);
  if(j+1<int(s.opens.size()))closed=std::min(closed,s.opens[j+1]);
  if((chartIndex==0 && InpLiveCurrentBar) || closed<=endpoint)chosen=j;
 }
 if(chosen<(long long)InpRSIPeriod+(line==4?6:0))return EMPTY_VALUE;
 if(line<4)return good(s.rsi[chosen])?s.rsi[chosen]:EMPTY_VALUE;
 long double sum=0;
 for(int j=chosen-6;j<=chosen;j++) {if(!good(s.rsi[j]))return EMPTY_VALUE;sum+=s.rsi[j];}
 return double(sum/7);
}
void parity(const Chart& d,int only=-1) {
 for(int line=0;line<5;line++)if(only<0 || line==only)
  for(int i=0;i<int(d.time.size());i++)
   equal((*plots()[line])[i],expectedAt(line,d,i),"mapping/SMA mismatch line="+std::to_string(line)+" index="+std::to_string(i));
}
void initContracts() {
 for(auto chart:{PERIOD_M1,PERIOD_M15,PERIOD_H1,PERIOD_H4,PERIOD_D1,PERIOD_MN1}) {
  resetHarness(chart);InpAutoTimeframes=true;start();
  for(int k=0;k<5;k++)require(ValidFrame(TF[k]),"auto frame must be supported");
  require(TF[4]==chart,"SMA must use chart RSI");cleanup();
 }
 resetHarness();InpTF1=InpTF2=InpTF3=InpTF4=PERIOD_H1;start();
 require(createdRSI==1 && createdMA==1,"identical frames must borrow one chart RSI");cleanup();
 resetHarness();InpTF1=PERIOD_M1;InpTF2=PERIOD_M5;InpTF3=PERIOD_M15;InpTF4=PERIOD_H4;start();
 require(createdRSI==5 && createdMA==1,"separate chart RSI needed only when not in four frames");cleanup();
 for(int fail=0;fail<5;fail++) {
  resetHarness();failedBinding=fail;
  require(OnInit()==INIT_FAILED,"binding failure must reject initialization");
  require(handles.empty(),"binding failure must not create native handles");cleanup();
 }
 for(int fail=0;fail<5;fail++) {
  resetHarness();failCreation=fail;
  require(OnInit()==INIT_FAILED,"partial source creation must fail");
  require(released.size()==handles.size(),"partial initialization must release every created source");cleanup();
 }
 resetHarness();InpPrice=ENUM_APPLIED_PRICE(0);require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid price enum");
 resetHarness();InpTF1=ENUM_TIMEFRAMES(7);require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid manual frame");
 resetHarness();InpRSIPeriod=1;require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid RSI period");
 resetHarness();InpHistoryBars=99;require(OnInit()==INIT_PARAMETERS_INCORRECT,"invalid history cap");
}
void mappingAndSMA() {
 for(bool live:{false,true}) {
  resetHarness();InpLiveCurrentBar=live;start();Chart d(stamp(2026,1,1),85);
  serverNow=d.newest()+1800;coverAll(d.oldest(),serverNow);
  require(d.calculate(0)==85,"initial chart calculation count");parity(d);
  for(int k=0;k<5;k++)require(Pending[k]==0,"ready line must not be pending");
 }
 resetHarness();InpRSIPeriod=std::numeric_limits<int>::max();start();Chart huge(stamp(2026,1,1),3);
 serverNow=huge.newest()+1800;coverAll(huge.oldest(),serverNow);huge.calculate(0);
 for(auto p:plots())for(double v:*p)require(v==EMPTY_VALUE,"huge RSI period is warmup, not integer overflow");
}
void gapsAndCalendar() {
 resetHarness();InpTF1=InpTF2=InpTF3=InpTF4=PERIOD_M15;start();
 Chart d(std::vector<datetime>{stamp(2026,1,2,8),stamp(2026,1,2,9),stamp(2026,1,2,12)});
 serverNow=stamp(2026,1,2,12,30);coverAll(d.oldest(),serverNow);d.calculate(0);parity(d);
 const auto& s=sources.at(PERIOD_M15);
 auto exact=std::find(s.opens.begin(),s.opens.end(),stamp(2026,1,2,9,45))-s.opens.begin();
 equal(Lower[1],s.rsi.at(exact),"09 H1 point must stop at10, not missing next open12");
 auto& gap=sources[PERIOD_M15];
 for(int j=int(gap.opens.size())-1;j>=0;j--)if(gap.opens[j]>=stamp(2026,1,2,9,45) && gap.opens[j]<stamp(2026,1,2,12)) {
  gap.opens.erase(gap.opens.begin()+j);gap.rsi.erase(gap.rsi.begin()+j);
 }
 d.calculate(0);parity(d);
 auto nearest=std::find(gap.opens.begin(),gap.opens.end(),stamp(2026,1,2,9,30))-gap.opens.begin();
 equal(Lower[1],gap.rsi.at(nearest),"source09:30 closed by09:45 even when next actual source opens12");
 for(int year:{2024,2025}) {
  resetHarness(PERIOD_MN1);InpTF1=InpTF2=InpTF3=InpTF4=PERIOD_D1;start();
  Chart months(stamp(year,1,1),4);serverNow=months.newest()+43200;coverAll(months.oldest(),serverNow);
  months.calculate(0);parity(months);
  require(BarClose(stamp(year,1,1),PERIOD_MN1)==stamp(year,2,1),"31-day month boundary");
  require(BarClose(stamp(year,2,1),PERIOD_MN1)==stamp(year,3,1),"leap/nonleap February boundary");
  require(BarClose(stamp(year,12,1),PERIOD_MN1)==stamp(year+1,1,1),"December year boundary");
 }
 for(int year:{2024,2025}) {
  resetHarness(PERIOD_D1);InpTF1=InpTF2=InpTF3=InpTF4=PERIOD_MN1;start();
  Chart days(stamp(year,2,26),6);serverNow=days.newest()+43200;coverAll(days.oldest(),serverNow);
  days.calculate(0);parity(days);
  const auto& monthly=sources.at(PERIOD_MN1);
  auto february=std::find(monthly.opens.begin(),monthly.opens.end(),stamp(year,2,1))-monthly.opens.begin();
  bool checked=false;
  for(int i=1;i<int(days.time.size());i++)if(days.time[i]==stamp(year,3,1)-86400) {
   equal(Lower[i],monthly.rsi.at(february),"February monthly RSI closes on March1 for leap and nonleap years");
   checked=true;
  }
  require(checked,"daily fixture must include final February candle");
 }
}
void causalHistory() {
 resetHarness();start();Chart d(stamp(2026,2,1),90);
 serverNow=d.newest()+1700;coverAll(d.oldest(),serverNow);d.calculate(0);
 std::vector<std::vector<double>> saved(5);
 for(int k=0;k<5;k++)for(int i=1;i<90;i++)saved[k].push_back((*plots()[k])[i]);
 for(auto& pair:sources) {
  auto& s=pair.second;
  for(int j=0;j<int(s.opens.size());j++)if(nextOpen(s.opens[j],pair.first)>d.newest())s.rsi[j]=92;
 }
 d.calculate(0);
 for(int k=0;k<5;k++)for(int i=1;i<90;i++)equal((*plots()[k])[i],saved[k][i-1],"future source samples changed a closed chart point");
}
void pendingAndLimitedHistory() {
 resetHarness();start();Chart d(stamp(2026,1,1),100);
 serverNow=d.newest()+1800;coverAll(d.oldest(),serverNow);
 sources[TF[2]].calculated=0;sources[TF[2]].readableRecent=0;
 require(d.calculate(0)==100,"one pending TF must not reset chart cursor");
 require(Pending[2]>0 && Pending[0]==0,"each TF needs independent pending state");
 parity(d,0);parity(d,1);parity(d,3);parity(d,4);
 int goodCopies=handleCopies[Handles[0]];maxCopyRequest=0;
 milliseconds+=50;d.calculate(100);
 require(maxCopyRequest<=8,"pending historical replay must be throttled while current points still refresh");
 require(handleCopies[Handles[0]]>goodCopies,"good line must update during another TF's wait");
 sources[TF[2]].calculated=-1;sources[TF[2]].readableRecent=-1;milliseconds+=1100;d.calculate(100);parity(d);
 require(Pending[2]==0,"ready TF must replay missed suffix");
 auto& limited=sources[TF[0]];
 limited.opens.erase(limited.opens.begin(),limited.opens.end()-40);
 limited.rsi.erase(limited.rsi.begin(),limited.rsi.end()-40);fillValues(limited);
 d.calculate(0);parity(d,0);
 require(Lower[0]!=EMPTY_VALUE && Lower[99]==EMPTY_VALUE && Pending[0]==0,"short source coverage must render valid recent overlap");
 cover(TF[0],d.oldest(),serverNow);milliseconds+=300;d.calculate(100);parity(d,0);
 require(SourceFirst[0]==sources[TF[0]].opens.front(),"older source backfill must rebuild prior empty points");
}
void invalidReadiness() {
 for(double bad:{EMPTY_VALUE,std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity(),-1.0,101.0}) {
  resetHarness();start();Chart d(stamp(2026,1,1),35);
  serverNow=d.newest()+1800;coverAll(d.oldest(),serverNow);sources[TF[0]].rsi.back()=bad;
  d.calculate(0);require(Lower[0]==EMPTY_VALUE && Pending[0]>0,"invalid selected RSI must be hidden and retried");
  sources[TF[0]].rsi.back()=45;milliseconds+=300;d.calculate(35);parity(d);
 }
 for(double goodBoundary:{0.0,100.0}) {
  resetHarness();start();Chart d(stamp(2026,1,1),35);
  serverNow=d.newest()+1800;coverAll(d.oldest(),serverNow);sources[TF[0]].rsi.back()=goodBoundary;
  d.calculate(0);equal(Lower[0],goodBoundary,"RSI endpoints0/100 are valid");require(Pending[0]==0,"valid boundary pending");
 }
 resetHarness();InpLiveCurrentBar=false;start();Chart d(stamp(2026,1,1),35);
 serverNow=d.newest()+1801;coverAll(d.oldest(),serverNow);sources[TF[0]].rsi.back()=EMPTY_VALUE;
 d.calculate(0);parity(d);require(Pending[0]==0,"invalid forming source is not needed in closed-source mode");
}
void historyCapAndReset() {
 resetHarness();start();Chart d(stamp(2026,1,1),130);datetime beginning=d.oldest();
 serverNow=d.newest()+1800;coverAll(beginning,serverNow);d.calculate(0);parity(d);
 d.append(7);serverNow=d.newest()+1800;coverAll(beginning,serverNow);milliseconds+=300;
 require(d.calculate(130)==137,"multi-bar catchup count");parity(d);
 for(auto p:plots())for(int i=100;i<137;i++)require((*p)[i]==EMPTY_VALUE,"shifted old history leaked beyond cap");
 d.dropOldest(3);d.append(3);serverNow=d.newest()+1800;coverAll(beginning,serverNow);milliseconds+=300;
 d.calculate(137);parity(d);
 d.dropOldest(107);d.calculate(137);parity(d);
 require(d.time.size()==30,"shrink fixture");
}
void snapshotsAndLag() {
 for(int failure=0;failure<4;failure++) {
  resetHarness();start();Chart d(stamp(2026,1,1),70);
  serverNow=d.newest()+1800;coverAll(d.oldest(),serverNow);
  auto& broken=sources[TF[0]];
  if(failure==0)broken.rollOnTimeCopy=true;
  if(failure==1)broken.lag=1;
  if(failure==2)broken.timeShortfall=1;
  if(failure==3)broken.valueShortfall=1;
  d.calculate(0);
  if(failure==2) {
   parity(d); // Exact-time point reads can safely recover a failed bulk time copy.
  } else {
   require(Pending[0]>0,"inconsistent/unavailable source snapshot must be retried");
   require(Lower[0]==EMPTY_VALUE,"misaligned/unreadable copy must not publish a latest value");
  }
  broken.lag=broken.timeShortfall=broken.valueShortfall=0;
  milliseconds+=1100;serverNow=std::max(serverNow,broken.opens.back()+1);d.calculate(70);parity(d);
 }
}
void cancellation() {
 resetHarness();start();Chart d(stamp(2026,1,1),180);
 serverNow=d.newest()+1800;coverAll(d.oldest(),serverNow);_StopFlag=true;
 require(d.calculate(0)==0 && LastNewest==0,"already stopped calculation must not commit cursor");
 _StopFlag=false;stopArray=&Lower;stopIndex=20;
 require(d.calculate(0)==0 && LastNewest==0,"cancelled mapping must not claim a complete chart");
 stopArray=nullptr;_StopFlag=false;require(d.calculate(0)==180,"cancelled mapping resume");parity(d);
}
void boundedWork() {
 resetHarness(PERIOD_M1);InpHistoryBars=2500;
 InpTF1=PERIOD_M1;InpTF2=PERIOD_M5;InpTF3=PERIOD_M15;InpTF4=PERIOD_H1;start();
 Chart d(stamp(2026,1,1),2000);serverNow=d.newest()+30;coverAll(d.oldest(),serverNow);
 d.calculate(0);parity(d);
 require(maxCopyRequest<=512,"source buffers must have a fixed512sample bound");
 require(barShiftCalls<100,"dense history must reuse cached opens instead of querying every point");
 maxCopyRequest=copyCalls=timeCopyCalls=barShiftCalls=0;milliseconds+=10;serverNow+=1;
 d.calculate(2000);parity(d);
 require(maxCopyRequest<=8,"ordinary tick must only copy a tiny source block");
 require(barShiftCalls<=5 && copyCalls<=5,"ordinary tick should update one point per line");
}
void reportedCountsAreHints() {
 for(int report:{-1,0,32}) {
  resetHarness(PERIOD_M15);InpAutoTimeframes=true;start();
  Chart d(stamp(2026,1,1),100);serverNow=d.newest()+7*60+30;coverAll(d.oldest(),serverNow);
  // Reproduce the reported M15 chart: H1 is fully reported, while the other
  // independent handles already expose valid recent data but report fewer bars.
  for(int k:{0,1,2,4}) {
   handles[Handles[k]].reportedCount=report;
   handles[Handles[k]].readableRecent=32;
  }
  require(d.calculate(0)==100,"short calculated count must not reset the chart");
  for(int k=0;k<5;k++)for(int i=0;i<3;i++)
   equal((*plots()[k])[i],expectedAt(k,d,i),"valid recent RSI/SMA hidden by reported calculated count");
  require(Lower[3]==EMPTY_VALUE,"unavailable old M1 value must remain empty");
  for(auto& pair:sources)pair.second.rsi.back()=34+int(pair.first)%9;
  milliseconds+=50;maxCopyRequest=0;d.calculate(100);
  for(int k=0;k<5;k++)equal((*plots()[k])[0],expectedAt(k,d,0),"recent line disappeared during historical retry throttle");
  require(maxCopyRequest<=8,"pending prefix must not force a full replay every tick");
  for(auto& pair:handles) {pair.second.reportedCount=INT_MIN;pair.second.readableRecent=-1;}
  milliseconds+=1100;d.calculate(100);parity(d);
 }
}
void partialBulkReadKeepsRecentPoints() {
 resetHarness(PERIOD_M15);InpAutoTimeframes=true;start();
 Chart d(stamp(2026,1,1),100);serverNow=d.newest()+7*60+30;coverAll(d.oldest(),serverNow);
 // A requested 512-bar interval returns its latest32 samples while older
 // indicator calculation is pending. Their dates do not match the first32 opens.
 for(int k:{0,1,2,4})handles[Handles[k]].readableRecent=32;
 d.calculate(0);
 for(int k=0;k<5;k++)for(int i=0;i<3;i++)
  equal((*plots()[k])[i],expectedAt(k,d,i),"partial bulk copy masked or misdated an available recent point");
 require(Lower[3]==EMPTY_VALUE,"partially returned recent values must not be paired with old cache dates");
 milliseconds+=20;maxCopyRequest=0;d.calculate(100);
 for(int k=0;k<5;k++)equal((*plots()[k])[0],expectedAt(k,d,0),"old unavailable prefix must not blank a ready line");
 require(maxCopyRequest<=8,"ordinary pending tick must remain bounded");
 for(auto& pair:handles)pair.second.readableRecent=-1;
 milliseconds+=1100;d.calculate(100);parity(d);
}
void unavailableFormingSamplesDoNotBlockClosedPoints() {
 resetHarness(PERIOD_M15);InpAutoTimeframes=true;InpLiveCurrentBar=false;start();
 Chart d(stamp(2026,1,1),100);serverNow=d.newest()+7*60+30;coverAll(d.oldest(),serverNow);
 sources[TF[0]].lag=1;
 sources[TF[2]].lag=1; // Both chart RSI and its SMA have an unfinished newest sample.
 d.calculate(0);parity(d);
 for(int k=0;k<5;k++) {
  require((*plots()[k])[0]!=EMPTY_VALUE,"unneeded forming sample blocked a closed-source line");
  require(Pending[k]==0,"unneeded forming sample must not keep valid closed history pending");
 }
 milliseconds+=20;d.calculate(100);parity(d);
}
int main(int argc,char** argv) {
 try {
  require(argc==2,"select scenario");string name=argv[1];
  if(name=="init")initContracts();else if(name=="mapping")mappingAndSMA();
  else if(name=="calendar")gapsAndCalendar();else if(name=="causal")causalHistory();
  else if(name=="pending")pendingAndLimitedHistory();else if(name=="invalid")invalidReadiness();
  else if(name=="history")historyCapAndReset();else if(name=="snapshot")snapshotsAndLag();
  else if(name=="stop")cancellation();else if(name=="work")boundedWork();
  else if(name=="counts")reportedCountsAreHints();else if(name=="partial")partialBulkReadKeepsRecentPoints();
  else if(name=="closed_lag")unavailableFormingSamplesDoNotBlockClosedPoints();
  else throw std::runtime_error("unknown scenario");
  cleanup();std::cout<<name<<" passed\n";return 0;
 } catch(const std::exception& e) {std::cerr<<e.what()<<"\n";return 1;}
}
'''


class RSIAutoMTFRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler = shutil.which("g++")
        if compiler is None:
            raise RuntimeError("g++ is required for the native RSI MTF adapter")
        source = SOURCE.read_text(encoding="utf-8-sig")
        inputs = re.findall(r"^input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);", source, re.M)
        declarations = "\n".join(f"{kind} {name}={value};" for kind, name, value in inputs)
        defaults = "void defaults(){\n" + "\n".join(f"{name}={value};" for _, name, value in inputs) + "\n}\n"
        pattern = r"^(?:string|void|int|bool|double|datetime|ulong)\s+(\w+)\s*\("
        first_function = re.search(pattern, source, re.M).start()
        globals_code = source[source.index("double Lower[]"):first_function]
        globals_code = re.sub(r"double\s+([^;]+);", lambda m: "Array<double> " + m.group(1).replace("[]", "") + ";" if "[]" in m.group(1) else m.group(0), globals_code)
        functions, prototypes = [], []
        for name in re.findall(pattern, source, re.M):
            code = extract_function(source, name).replace("std::vector<", "Array<")
            code = re.sub(r"\b(double|datetime|int)\s+(\w+)\[\]\s*;", r"Array<\1> \2;", code)
            opening = code.index("{")
            signature = code[:opening]
            prototypes.append(signature + ";")
            functions.append(re.sub(r"=\s*[^,)]+", "", signature) + code[opening:])
        program = ADAPTER + declarations + globals_code + defaults + "\n".join(prototypes + functions) + CASES
        cls.directory = tempfile.TemporaryDirectory(prefix="rsi-mtf-regression-")
        cpp = Path(cls.directory.name) / "rsi.cpp"
        cls.binary = Path(cls.directory.name) / "rsi"
        cpp.write_text(program, encoding="utf-8")
        built = subprocess.run([compiler, "-std=c++17", "-O2", "-D_GLIBCXX_ASSERTIONS", "-Wall", "-Wextra", "-pedantic", str(cpp), "-o", str(cls.binary)], capture_output=True, text=True)
        if built.returncode:
            cls.directory.cleanup()
            raise RuntimeError("RSI MTF native adapter compilation failed:\n" + built.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def run_case(self, name):
        result = subprocess.run([str(self.binary), name], capture_output=True, text=True, timeout=40)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_bindings_parameters_and_unique_source_lifetime(self):
        self.run_case("init")

    def test_independent_timestamp_mapping_and_chart_rsi_sma(self):
        self.run_case("mapping")

    def test_chart_source_gaps_and_calendar_month_boundaries(self):
        self.run_case("calendar")

    def test_future_samples_do_not_change_closed_chart_points(self):
        self.run_case("causal")

    def test_independent_pending_lines_limited_history_and_backfill(self):
        self.run_case("pending")

    def test_invalid_rsi_is_hidden_and_retried(self):
        self.run_case("invalid")

    def test_history_cap_after_catchup_and_chart_shifts(self):
        self.run_case("history")

    def test_atomic_source_snapshots_lag_and_partial_copies(self):
        self.run_case("snapshot")

    def test_cancellation_and_full_reset_resume(self):
        self.run_case("stop")

    def test_bounded_source_blocks_and_constant_tick_work(self):
        self.run_case("work")

    def test_calculated_counts_do_not_hide_readable_recent_data(self):
        self.run_case("counts")

    def test_partial_bulk_window_keeps_recent_lines_visible(self):
        self.run_case("partial")

    def test_unavailable_forming_samples_do_not_block_closed_source_points(self):
        self.run_case("closed_lag")


if __name__ == "__main__":
    unittest.main()
