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
int main() {
 oledReady=true;linkSeen=true;lastHeartbeatMs=1000;usageAvailable=true;todayTokens=12000000;
 for (int count : {1,2}) for(int percent : {0,75,100}) for(uint32_t reset : {0U,345600U,UINT32_MAX}) {
  usageLimitCount=count;
  usageLimits[0]={"LIMIT123",static_cast<uint8_t>(percent),reset};
  usageLimits[1]={"OTHER5H",80,7200};
  drawDashboard();
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
