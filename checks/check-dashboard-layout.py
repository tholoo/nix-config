#!/usr/bin/env python3
"""Compile the actual OLED renderer against recording hardware stubs."""
from pathlib import Path
import subprocess
import tempfile

temporary = tempfile.TemporaryDirectory(prefix="breadboard-layout-")
root = Path(temporary.name)
stub = r'''
#pragma once
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
using std::min;
constexpr int HIGH=1, LOW=0, OUTPUT=1, SSD1306_WHITE=1, SSD1306_SWITCHCAPVCC=2;
uint32_t millis() { return 1000; }
void delay(int) {}
void digitalWrite(int,int) {}
void pinMode(int,int) {}
struct SerialFake { void begin(int) {} void setRxBufferSize(int) {} int available() {return 0;} int read() {return 0;} operator bool() {return true;} void println(const char* = "") {} template<class... T> void printf(const char*,T...) {} } Serial;
struct WireFake { void begin(int,int) {} void setClock(int) {} void beginTransmission(int) {} int endTransmission() {return 0;} } Wire;
struct Glyph {int x,y,w,h;};
struct Adafruit_SSD1306 {
 std::vector<Glyph> glyphs; std::string text; int x=0,y=0,size=1; bool badRect=false;
 Adafruit_SSD1306(int,int,WireFake*,int) {}
 bool begin(int,int,bool,bool) {return true;}
 void clearDisplay() {glyphs.clear();text.clear();badRect=false;}
 void display() {} void setTextColor(int) {} void setTextSize(int n) {size=n;}
 void setCursor(int a,int b) {x=a;y=b;}
 void print(const char* s) {text+=s;for(;*s;++s) {if(*s=='\n'){x=0;y+=8*size;continue;}if(x+6*size>128){x=0;y+=8*size;}if(*s!=' ')glyphs.push_back({x,y,6*size,8*size});x+=6*size;}}
 void println(const char* s="") {print(s);print("\n");}
 void drawRect(int a,int b,int w,int h,int) {badRect|=a<0||b<0||a+w>128||b+h>64;}
 void fillRect(int a,int b,int w,int h,int c) {drawRect(a,b,w,h,c);}
};
'''
(root / "hardware.h").write_text(stub)
for name in ["Arduino.h", "Wire.h", "Adafruit_GFX.h", "Adafruit_SSD1306.h"]:
    (root / name).write_text('#include "hardware.h"\n')
test = r'''
#include "DASHBOARD_SOURCE"
void packet(const char *value) {
 std::string line(value);
 processSerialLine(line.data());
}
int main() {
 packet("BEGIN");packet("USAGE|1|-1|0");packet("LIMIT|7D|84|90000");
 packet("BUDGET|5|7");
 if(todayBudget!=-1) {std::cerr<<"FAIL: budget committed before END\n";return 1;}
 packet("END");
 if(todayBudget!=5 || reserveBudget!=7) {std::cerr<<"FAIL: budget packet not parsed\n";return 1;}
 for(int deficit : {-85,-7,-1}) {
  packet("BEGIN");packet(("BUDGET|"+std::to_string(deficit)+"|0").c_str());packet("END");
  char text[22];formatBudget(text,sizeof(text));
  if(todayBudget!=deficit || reserveBudget!=0 || std::string(text)!="TODAY "+std::to_string(deficit)+"% +0% RES") {
   std::cerr<<"FAIL: deficit must display as a signed budget, including -1%\n";return 1;
  }
 }
 for(const char *invalid : {"BUDGET|bad|7", "BUDGET|-1|7", "BUDGET|-86|0", "BUDGET|0|101", "BUDGET|15|7", "BUDGET|5|99", "BUDGET|5", "BUDGET||7"}) {
  packet("BEGIN");packet(invalid);packet("END");
  if(todayBudget!=-1 || reserveBudget!=-1) {std::cerr<<"FAIL: invalid budget accepted\n";return 1;}
 }
 packet("BEGIN");packet("USAGE|1|12345678|0");packet("END");
 if(todayBudget!=-1) {std::cerr<<"FAIL: legacy packet retained stale budget\n";return 1;}
 oledReady=true;linkSeen=true;lastHeartbeatMs=1000;usageAvailable=true;todayBudget=5;reserveBudget=7;
 for(int today : {-85,-7,-1,0,5,14}) for(int reserve : {-1,0,7,85}) for (int count : {1,2}) for(int percent : {0,75,100}) for(uint32_t reset : {0U,345600U,UINT32_MAX}) {
  if(today<0 && reserve>0) continue;
  todayBudget=today;reserveBudget=reserve;usageLimitCount=count;
  usageLimits[0]={"LIMIT123",static_cast<uint8_t>(percent),reset};
  usageLimits[1]={"OTHER5H",80,7200};
  drawDashboard();
  const std::string expected = reserve<0 ? "TODAY --% +--% RES" :
    "TODAY "+std::to_string(today)+"% +"+std::to_string(reserve)+"% RES";
  if(display.text.find(expected)==std::string::npos) {std::cerr<<"FAIL: wrong daily budget text\n";return 1;}
  if (display.text.find("NO SECOND QUOTA")!=std::string::npos) {std::cerr<<"FAIL: placeholder wastes the single-quota area\n";return 1;}
  for(const auto &g:display.glyphs) {
   if(g.x<0||g.y<0||g.x+g.w>128||g.y+g.h>64) {std::cerr<<"FAIL: text outside 128x64 screen\n";return 1;}
   if(g.y>0 && g.y<16) {std::cerr<<"FAIL: quota text crosses the OLED color boundary\n";return 1;}
  }
  if(display.badRect) {std::cerr<<"FAIL: progress bar outside screen\n";return 1;}
 }
 std::cout<<"PASS: single/two-quota layouts at 0%, 75%, 100% fit the screen below the color boundary\n";
}
'''
source = Path(__file__).resolve().parents[1] / "breadboard/src/dashboard.cpp"
(root / "check.cpp").write_text(test.replace("DASHBOARD_SOURCE", str(source)))
subprocess.run(
    ["g++", "-std=c++17", "-I" + str(root), str(root / "check.cpp"),
     "-o", str(root / "check")],
    check=True,
)
result = subprocess.run([str(root / "check")])
temporary.cleanup()
raise SystemExit(result.returncode)
