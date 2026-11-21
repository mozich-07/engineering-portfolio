/**
 * @file TrafficLightController.ino
 * @brief 路畅 TrafficLight-基于 Arduino Uno 平台的双向互斥交通灯系统
 * @version V1.0
 * @date 2026-1-26
 * 
 * @details 功能说明：
 * 1. 实现东西/南北方向红绿灯交替控制，支持绿灯时长调节（10-60秒）
 * 2. 数码管显示倒计时，优化消影和闪烁问题
 * 3. 正常模式下黄灯常亮，相位切换时黄灯闪烁提示
 * 4. 支持暂停/重置、夜间模式、紧急模式三种按键控制
 * 5. OLED显示当前状态、倒计时、绿灯时长等信息
 * 
 * 硬件连接：
 * - LED：LED1(东西)红11/黄12/绿13；LED2(南北)红A0/黄12/绿A1
 * - 蜂鸣器：A2；电位器：A3；按键1：D0；按键2：D1
 * - 数码管：段脚A-G对应D2-D8；位选十位D9/个位D10（共阳极）
 * - OLED：I2C接口，地址0x3C
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

/************************** 硬件配置常量 **************************/
// OLED显示屏配置
#define OLED_SCREEN_WIDTH    128  // OLED宽度
#define OLED_SCREEN_HEIGHT   64   // OLED高度
#define OLED_RESET_PIN       -1   // 复位引脚（无则设为-1）
#define OLED_I2C_ADDRESS     0x3C // OLED I2C地址

// LED引脚定义（共阴极：LOW点亮，HIGH熄灭）
#define LED_EW_RED           11   // 东西方向红灯
#define LED_EW_YELLOW        12   // 东西方向黄灯（与南北黄灯共用）
#define LED_EW_GREEN         13   // 东西方向绿灯
#define LED_NS_RED           A0   // 南北方向红灯
#define LED_NS_YELLOW        12   // 南北方向黄灯（与东西黄灯共用）
#define LED_NS_GREEN         A1   // 南北方向绿灯

// 外设引脚定义
#define BUZZER_PIN           A2   // 蜂鸣器引脚
#define POTENTIOMETER_PIN    A3   // 电位器引脚（调节绿灯时长）
#define KEY_PAUSE_RESET      0    // 按键1：暂停/重置
#define KEY_MODE_SWITCH      1    // 按键2：夜间/紧急模式

// 数码管引脚定义（共阳极）
#define SEGMENT_A            2    // 数码管段A
#define SEGMENT_B            3    // 数码管段B
#define SEGMENT_C            4    // 数码管段C
#define SEGMENT_D            5    // 数码管段D
#define SEGMENT_E            6    // 数码管段E
#define SEGMENT_F            7    // 数码管段F
#define SEGMENT_G            8    // 数码管段G
#define DIGIT_TENS           9    // 数码管十位
#define DIGIT_UNITS          10   // 数码管个位

// 系统常量配置
#define SEG_SCAN_INTERVAL    5    // 数码管扫描间隔(ms)，5-10ms最佳
#define SEG_DISPLAY_TIME     1500 // 数码管单数字显示时间(μs)
#define DEBOUNCE_TIME        20   // 按键消抖时间(ms)
#define EMERGENCY_DURATION   5000 // 紧急模式持续时间(ms)
#define NIGHT_MODE_DURATION  3    // 夜间模式倒计时时长(s)

/************************** 全局变量定义 **************************/
// OLED显示屏对象
Adafruit_SSD1306 g_OledDisplay(OLED_SCREEN_WIDTH, OLED_SCREEN_HEIGHT, &Wire, OLED_RESET_PIN);

// 数码管段码表（共阳极：0=点亮，1=熄灭）
const byte g_SegmentCode[10] = {
  B1111110, // 0
  B0110000, // 1
  B1101101, // 2
  B1111001, // 3
  B0110011, // 4
  B1011011, // 5
  B1011111, // 6
  B1110000, // 7
  B1111111, // 8
  B1111011  // 9
};

// 按键状态结构体
typedef struct {
  byte currentState;        // 当前按键状态
  byte lastState;           // 上一次按键状态
  unsigned long stateChangeTime; // 状态变化时间戳
  unsigned long pressStartTime;  // 按键按下开始时间
  bool isStable;            // 状态是否稳定（消抖完成）
} KeyStatus_t;

// 系统运行状态
typedef struct {
  byte trafficPhase;        // 交通灯相位：0-东西绿 1-东西黄 2-南北绿 3-南北黄
  int  countdownTime;       // 当前倒计时时间(s)
  int  totalPhaseTime;      // 当前相位总时长(s)
  int  greenLightDuration;  // 绿灯时长(10-60s，由电位器调节)
  bool isPaused;            // 暂停状态标志
  bool isNightMode;         // 夜间模式标志
  bool isEmergencyMode;     // 紧急模式标志
  bool isYellowBlink;       // 黄灯闪烁标志（仅相位切换时生效）
  unsigned long emergencyEndTime; // 紧急模式结束时间戳
} SystemState_t;

// 全局实例化
SystemState_t g_SystemState;
KeyStatus_t   g_KeyPauseReset;
KeyStatus_t   g_KeyModeSwitch;

// 时间戳（用于非阻塞定时）
unsigned long g_TimeStamp100ms = 0;
unsigned long g_TimeStamp1s = 0;
unsigned long g_TimeStampKeyScan = 0;
unsigned long g_TimeStampOledUpdate = 0;
unsigned long g_TimeStampPotRead = 0;
unsigned long g_TimeStampSegScan = 0;

/************************** 函数声明 **************************/
void System_Init(void);                // 系统初始化
void System_Loop(void);                // 主循环逻辑
void TrafficLight_SetPhase(byte phase, bool playBeep); // 设置交通灯相位
void TrafficLight_NextPhase(void);     // 切换到下一个相位
void TrafficLight_AllRedGreenOff(void);// 关闭所有红绿灯
void DigitalTube_ScanDisplay(int tens, int units); // 数码管扫描显示
void DigitalTube_SetSegment(int num);  // 设置数码管段码
void Key_Scan(KeyStatus_t *pKey, byte pin, void (*shortPressCb)(void), void (*longPressCb)(void)); // 按键扫描
void Key_PauseReset_ShortPress(void);  // 暂停/继续 短按回调
void Key_PauseReset_LongPress(void);   // 系统重置 长按回调
void Key_ModeSwitch_ShortPress(void);  // 夜间模式 短按回调
void Key_ModeSwitch_LongPress(void);   // 紧急模式 长按回调
void Peripheral_ReadPotentiometer(void);// 读取电位器值
void Peripheral_Beep(int durationMs, int freqHz); // 蜂鸣器发声
void OLED_UpdateDisplay(void);         // 更新OLED显示
void OLED_DrawStatusIcon(byte phase);  // 绘制状态图标

/************************** 初始化函数 **************************/
void setup() {
  System_Init();
}

/************************** 主循环函数 **************************/
void loop() {
  System_Loop();
}

/************************** 系统核心函数 **************************/
/**
 * @brief 系统初始化
 * @details 初始化硬件引脚、外设、系统状态
 */
void System_Init(void) {
  // 初始化串口
  Serial.begin(9600);

  // 1. 初始化LED引脚（默认熄灭：HIGH）
  pinMode(LED_EW_RED, OUTPUT);        digitalWrite(LED_EW_RED, HIGH);
  pinMode(LED_EW_YELLOW, OUTPUT);     digitalWrite(LED_EW_YELLOW, LOW);  // 正常模式黄灯常亮
  pinMode(LED_EW_GREEN, OUTPUT);      digitalWrite(LED_EW_GREEN, HIGH);
  pinMode(LED_NS_RED, OUTPUT);        digitalWrite(LED_NS_RED, HIGH);
  pinMode(LED_NS_YELLOW, OUTPUT);     digitalWrite(LED_NS_YELLOW, LOW);  // 正常模式黄灯常亮
  pinMode(LED_NS_GREEN, OUTPUT);      digitalWrite(LED_NS_GREEN, HIGH);

  // 2. 初始化蜂鸣器（默认关闭：LOW）
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // 3. 初始化数码管（共阳极：段脚默认HIGH，位选默认HIGH）
  for (int i = SEGMENT_A; i <= SEGMENT_G; i++) {
    pinMode(i, OUTPUT);
    digitalWrite(i, HIGH);
  }
  pinMode(DIGIT_TENS, OUTPUT);        digitalWrite(DIGIT_TENS, HIGH);
  pinMode(DIGIT_UNITS, OUTPUT);       digitalWrite(DIGIT_UNITS, HIGH);

  // 4. 初始化按键（上拉输入）
  pinMode(KEY_PAUSE_RESET, INPUT_PULLUP);
  pinMode(KEY_MODE_SWITCH, INPUT_PULLUP);
  pinMode(POTENTIOMETER_PIN, INPUT);

  // 5. 初始化按键状态
  g_KeyPauseReset = (KeyStatus_t){HIGH, HIGH, 0, 0, true};
  g_KeyModeSwitch = (KeyStatus_t){HIGH, HIGH, 0, 0, true};

  // 6. 初始化OLED显示屏
  if (!g_OledDisplay.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDRESS)) {
    Serial.println(F("OLED初始化失败！"));
    while (1); // 初始化失败则卡死
  }
  g_OledDisplay.clearDisplay();
  g_OledDisplay.display();
  g_OledDisplay.setTextColor(WHITE);
  g_OledDisplay.setTextSize(1);

  // 7. 初始化系统状态
  g_SystemState = (SystemState_t){
    .trafficPhase = 0,
    .countdownTime = 30,
    .totalPhaseTime = 30,
    .greenLightDuration = 30,
    .isPaused = false,
    .isNightMode = false,
    .isEmergencyMode = false,
    .isYellowBlink = false,
    .emergencyEndTime = 0
  };

  // 8. 读取电位器初始值
  Peripheral_ReadPotentiometer();

  // 9. 开机提示音
  Peripheral_Beep(300, 2000);

  // 10. 设置初始相位（东西绿灯，不播放提示音）
  TrafficLight_SetPhase(0, false);
}

/**
 * @brief 系统主循环逻辑
 * @details 非阻塞式处理所有定时任务、外设控制
 */
void System_Loop(void) {
  unsigned long currentTime = millis();

  // 1. 紧急模式处理（最高优先级）
  if (g_SystemState.isEmergencyMode) {
    // 紧急模式持续5秒后自动退出
    if (currentTime - g_SystemState.emergencyEndTime > EMERGENCY_DURATION) {
      g_SystemState.isEmergencyMode = false;
      digitalWrite(BUZZER_PIN, LOW);
      TrafficLight_SetPhase(0, false);
      // 恢复黄灯常亮
      digitalWrite(LED_EW_YELLOW, LOW);
      digitalWrite(LED_NS_YELLOW, LOW);
    }
    // 紧急模式显示88
    DigitalTube_ScanDisplay(8, 8);
    return;
  }

  // 2. 数码管扫描显示（5ms一次，平衡闪烁和消影）
  if (currentTime - g_TimeStampSegScan >= SEG_SCAN_INTERVAL) {
    g_TimeStampSegScan = currentTime;
    int tens = g_SystemState.isNightMode ? 8 : g_SystemState.countdownTime / 10;
    int units = g_SystemState.isNightMode ? 8 : g_SystemState.countdownTime % 10;
    DigitalTube_ScanDisplay(tens, units);
  }

  // 3. 100ms定时任务（黄灯闪烁、蜂鸣器控制）
  if (currentTime - g_TimeStamp100ms >= 100) {
    g_TimeStamp100ms = currentTime;

    if (!g_SystemState.isPaused) {
      bool isBuzzerOn = false;

      // 黄灯逻辑：仅相位1/3（切换期）闪烁，其余时间常亮
      if (g_SystemState.trafficPhase == 1 || g_SystemState.trafficPhase == 3) {
        g_SystemState.isYellowBlink = !g_SystemState.isYellowBlink;
        digitalWrite(LED_EW_YELLOW, g_SystemState.isYellowBlink ? HIGH : LOW);
        digitalWrite(LED_NS_YELLOW, g_SystemState.isYellowBlink ? HIGH : LOW);
        isBuzzerOn = g_SystemState.isYellowBlink;
      } else {
        // 正常模式黄灯常亮
        digitalWrite(LED_EW_YELLOW, LOW);
        digitalWrite(LED_NS_YELLOW, LOW);
        g_SystemState.isYellowBlink = false;
      }

      // 蜂鸣器控制（夜间模式关闭蜂鸣器）
      digitalWrite(BUZZER_PIN, (isBuzzerOn && !g_SystemState.isNightMode) ? HIGH : LOW);

      // 4. 1秒倒计时任务（嵌套在100ms任务中）
      if (currentTime - g_TimeStamp1s >= 1000) {
        g_TimeStamp1s = currentTime;
        g_SystemState.countdownTime--;
        
        // 倒计时结束切换相位
        if (g_SystemState.countdownTime <= 0) {
          TrafficLight_NextPhase();
        }
      }
    } else {
      // 暂停状态：关闭蜂鸣器，黄灯保持常亮
      digitalWrite(BUZZER_PIN, LOW);
      digitalWrite(LED_EW_YELLOW, LOW);
      digitalWrite(LED_NS_YELLOW, LOW);
    }
  }

  // 5. 按键扫描（50ms一次，消抖）
  if (currentTime - g_TimeStampKeyScan >= 50) {
    g_TimeStampKeyScan = currentTime;
    Key_Scan(&g_KeyPauseReset, KEY_PAUSE_RESET, Key_PauseReset_ShortPress, Key_PauseReset_LongPress);
    Key_Scan(&g_KeyModeSwitch, KEY_MODE_SWITCH, Key_ModeSwitch_ShortPress, Key_ModeSwitch_LongPress);
  }

  // 6. OLED显示更新（200ms一次，降低刷新率）
  if (currentTime - g_TimeStampOledUpdate >= 200) {
    g_TimeStampOledUpdate = currentTime;
    OLED_UpdateDisplay();
  }

  // 7. 读取电位器（1秒一次，更新绿灯时长）
  if (currentTime - g_TimeStampPotRead >= 1000) {
    g_TimeStampPotRead = currentTime;
    Peripheral_ReadPotentiometer();
  }
}

/************************** 交通灯控制函数 **************************/
/**
 * @brief 关闭所有红绿灯（黄灯不受影响）
 */
void TrafficLight_AllRedGreenOff(void) {
  digitalWrite(LED_EW_RED, HIGH);
  digitalWrite(LED_EW_GREEN, HIGH);
  digitalWrite(LED_NS_RED, HIGH);
  digitalWrite(LED_NS_GREEN, HIGH);
}

/**
 * @brief 设置交通灯相位
 * @param phase 相位值：0-东西绿 1-东西黄 2-南北绿 3-南北黄
 * @param playBeep 是否播放提示音
 */
void TrafficLight_SetPhase(byte phase, bool playBeep) {
  // 关闭所有红绿灯
  TrafficLight_AllRedGreenOff();
  g_SystemState.trafficPhase = phase;

  // 设置当前相位总时长
  if (g_SystemState.isNightMode) {
    g_SystemState.totalPhaseTime = NIGHT_MODE_DURATION;
  } else {
    g_SystemState.totalPhaseTime = (phase == 0 || phase == 2) ? g_SystemState.greenLightDuration : 3;
  }

  // 播放相位切换提示音
  if (playBeep && !g_SystemState.isNightMode) {
    switch (phase) {
      case 0: // 东西绿灯
        Peripheral_Beep(50, 2000);
        delay(60);
        Peripheral_Beep(50, 2000);
        break;
      case 1: // 东西黄灯
      case 3: // 南北黄灯
        Peripheral_Beep(80, 2500);
        break;
      case 2: // 南北绿灯
        Peripheral_Beep(80, 1500);
        break;
    }
  }

  // 夜间模式处理
  if (g_SystemState.isNightMode) {
    g_SystemState.countdownTime = NIGHT_MODE_DURATION;
    g_SystemState.isYellowBlink = true;
    return;
  }

  // 正常模式设置LED状态
  switch (phase) {
    case 0: // 东西绿灯，南北红灯
      digitalWrite(LED_EW_GREEN, LOW);
      digitalWrite(LED_NS_RED, LOW);
      g_SystemState.countdownTime = g_SystemState.greenLightDuration;
      // 黄灯常亮
      digitalWrite(LED_EW_YELLOW, LOW);
      digitalWrite(LED_NS_YELLOW, LOW);
      break;
    case 1: // 东西黄灯
    case 3: // 南北黄灯
      g_SystemState.countdownTime = 3;
      g_SystemState.isYellowBlink = true;
      break;
    case 2: // 南北绿灯，东西红灯
      digitalWrite(LED_NS_GREEN, LOW);
      digitalWrite(LED_EW_RED, LOW);
      g_SystemState.countdownTime = g_SystemState.greenLightDuration;
      // 黄灯常亮
      digitalWrite(LED_EW_YELLOW, LOW);
      digitalWrite(LED_NS_YELLOW, LOW);
      break;
  }
}

/**
 * @brief 切换到下一个相位
 */
void TrafficLight_NextPhase(void) {
  if (!g_SystemState.isNightMode) {
    TrafficLight_SetPhase((g_SystemState.trafficPhase + 1) % 4, true);
  } else {
    g_SystemState.countdownTime = NIGHT_MODE_DURATION;
  }
}

/************************** 数码管控制函数 **************************/
/**
 * @brief 数码管扫描显示（消影优化版）
 * @param tens 十位数字（0-9）
 * @param units 个位数字（0-9）
 */
void DigitalTube_ScanDisplay(int tens, int units) {
  // 1. 关闭所有位选，基础消影（防止串码）
  digitalWrite(DIGIT_TENS, HIGH);
  digitalWrite(DIGIT_UNITS, HIGH);
  delayMicroseconds(30);

  // 2. 显示十位
  DigitalTube_SetSegment(tens);
  digitalWrite(DIGIT_TENS, LOW);
  delayMicroseconds(SEG_DISPLAY_TIME); // 延长显示时间，减少闪烁
  digitalWrite(DIGIT_TENS, HIGH);
  delayMicroseconds(30); // 消影延时

  // 3. 清除段码残留（防止十位串到个位）
  for (int i = SEGMENT_A; i <= SEGMENT_G; i++) {
    digitalWrite(i, HIGH);
  }
  delayMicroseconds(30);

  // 4. 显示个位
  DigitalTube_SetSegment(units);
  digitalWrite(DIGIT_UNITS, LOW);
  delayMicroseconds(SEG_DISPLAY_TIME); // 延长显示时间，减少闪烁
  digitalWrite(DIGIT_UNITS, HIGH);
  delayMicroseconds(30); // 消影延时
}

/**
 * @brief 设置数码管段码（共阳极）
 * @param num 要显示的数字（0-9）
 */
void DigitalTube_SetSegment(int num) {
  // 限制数字范围0-9
  num = constrain(num, 0, 9);
  
  // 共阳极段码输出：0点亮，1熄灭
  digitalWrite(SEGMENT_A, bitRead(g_SegmentCode[num], 6));
  digitalWrite(SEGMENT_B, bitRead(g_SegmentCode[num], 5));
  digitalWrite(SEGMENT_C, bitRead(g_SegmentCode[num], 4));
  digitalWrite(SEGMENT_D, bitRead(g_SegmentCode[num], 3));
  digitalWrite(SEGMENT_E, bitRead(g_SegmentCode[num], 2));
  digitalWrite(SEGMENT_F, bitRead(g_SegmentCode[num], 1));
  digitalWrite(SEGMENT_G, bitRead(g_SegmentCode[num], 0));
}

/************************** 按键处理函数 **************************/
/**
 * @brief 通用按键扫描函数（消抖+长短按识别）
 * @param pKey 按键状态指针
 * @param pin 按键引脚
 * @param shortPressCb 短按回调函数（按下时间<1200ms）
 * @param longPressCb 长按回调函数（按下时间≥1200ms）
 */
void Key_Scan(KeyStatus_t *pKey, byte pin, void (*shortPressCb)(void), void (*longPressCb)(void)) {
  unsigned long currentTime = millis();
  
  // 读取当前按键状态（上拉输入：LOW=按下，HIGH=释放）
  pKey->currentState = digitalRead(pin);

  // 状态变化时记录时间，开始消抖
  if (pKey->currentState != pKey->lastState && pKey->isStable) {
    pKey->stateChangeTime = currentTime;
    pKey->isStable = false;
  }

  // 消抖完成（20ms稳定）
  if (!pKey->isStable && currentTime - pKey->stateChangeTime >= DEBOUNCE_TIME) {
    // 按键按下时记录开始时间
    if (pKey->currentState == LOW) {
      pKey->pressStartTime = currentTime;
    } 
    // 按键释放时判断长短按
    else {
      unsigned long pressDuration = currentTime - pKey->pressStartTime;
      if (pressDuration >= 1200) { // 长按（≥1200ms）
        if (longPressCb != NULL) {
          longPressCb();
        }
      } else if (pressDuration >= 50) { // 短按（50-1200ms）
        if (shortPressCb != NULL) {
          shortPressCb();
        }
      }
    }
    pKey->isStable = true;
  }

  // 更新上一次状态
  pKey->lastState = pKey->currentState;
}

/**
 * @brief 暂停/重置按键 - 短按回调（暂停/继续）
 */
void Key_PauseReset_ShortPress(void) {
  g_SystemState.isPaused = !g_SystemState.isPaused;
  Peripheral_Beep(50, 2500); // 提示音
}

/**
 * @brief 暂停/重置按键 - 长按回调（系统重置）
 */
void Key_PauseReset_LongPress(void) {
  Peripheral_Beep(200, 3000); // 重置提示音
  g_SystemState.isPaused = false;
  g_SystemState.isNightMode = false;
  TrafficLight_SetPhase(0, false);
  // 恢复黄灯常亮
  digitalWrite(LED_EW_YELLOW, LOW);
  digitalWrite(LED_NS_YELLOW, LOW);
}

/**
 * @brief 模式切换按键 - 短按回调（夜间模式）
 */
void Key_ModeSwitch_ShortPress(void) {
  g_SystemState.isNightMode = !g_SystemState.isNightMode;
  Peripheral_Beep(100, 1800); // 提示音
  TrafficLight_SetPhase(g_SystemState.isNightMode ? 1 : 0, false);
  g_SystemState.isPaused = false;
  // 退出夜间模式时恢复黄灯常亮
  if (!g_SystemState.isNightMode) {
    digitalWrite(LED_EW_YELLOW, LOW);
    digitalWrite(LED_NS_YELLOW, LOW);
  }
}

/**
 * @brief 模式切换按键 - 长按回调（紧急模式）
 */
void Key_ModeSwitch_LongPress(void) {
  if (!g_SystemState.isEmergencyMode) {
    g_SystemState.isEmergencyMode = true;
    g_SystemState.emergencyEndTime = millis();
    TrafficLight_AllRedGreenOff();
    // 紧急模式：双红灯亮，黄灯灭，蜂鸣器响
    digitalWrite(LED_EW_RED, LOW);
    digitalWrite(LED_NS_RED, LOW);
    digitalWrite(LED_EW_YELLOW, HIGH);
    digitalWrite(LED_NS_YELLOW, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
  }
}

/************************** 外设控制函数 **************************/
/**
 * @brief 读取电位器值，更新绿灯时长（10-60秒）
 */
void Peripheral_ReadPotentiometer(void) {
  int potValue = analogRead(POTENTIOMETER_PIN);
  // 映射电位器值（0-1023）到绿灯时长（10-60秒）
  g_SystemState.greenLightDuration = map(potValue, 0, 1023, 10, 60);

  // 非夜间模式且当前为绿灯相位时，更新总时长
  if (!g_SystemState.isNightMode && (g_SystemState.trafficPhase == 0 || g_SystemState.trafficPhase == 2)) {
    g_SystemState.totalPhaseTime = g_SystemState.greenLightDuration;
    // 防止倒计时超过绿灯时长
    g_SystemState.countdownTime = min(g_SystemState.countdownTime, g_SystemState.greenLightDuration);
  }
}

/**
 * @brief 蜂鸣器发声
 * @param durationMs 发声时长(ms)
 * @param freqHz 频率(Hz)（预留参数，当前未使用）
 */
void Peripheral_Beep(int durationMs, int freqHz) {
  (void)freqHz; // 屏蔽未使用参数警告
  digitalWrite(BUZZER_PIN, HIGH);
  delay(durationMs);
  digitalWrite(BUZZER_PIN, LOW);
}

/************************** OLED显示函数 **************************/
/**
 * @brief 更新OLED显示内容
 */
void OLED_UpdateDisplay(void) {
  // 清空屏幕
  g_OledDisplay.clearDisplay();

  // 绘制状态图标（暂停/夜间/紧急/相位）
  OLED_DrawStatusIcon(g_SystemState.trafficPhase);

  // 显示模式文本
  if (g_SystemState.isEmergencyMode) {
    // 紧急模式
    g_OledDisplay.setTextSize(2);
    g_OledDisplay.setCursor(10, 12);
    g_OledDisplay.print(F("EMERGENCY!"));
  } else if (g_SystemState.isNightMode) {
    // 夜间模式
    g_OledDisplay.setTextSize(2);
    g_OledDisplay.setCursor(30, 0);
    g_OledDisplay.print(F("NIGHT"));
  } else {
    // 正常模式：显示当前相位
    g_OledDisplay.setTextSize(1);
    g_OledDisplay.setCursor(30, 0);
    switch (g_SystemState.trafficPhase) {
      case 0: g_OledDisplay.print(F("EW-GREEN")); break;
      case 1: g_OledDisplay.print(F("EW-YELLOW")); break;
      case 2: g_OledDisplay.print(F("NS-GREEN")); break;
      case 3: g_OledDisplay.print(F("NS-YELLOW")); break;
    }
  }

  // 显示倒计时
  if (!g_SystemState.isEmergencyMode) {
    g_OledDisplay.setTextSize(2);
    char countdownBuf[3];
    sprintf(countdownBuf, "%02d", g_SystemState.isNightMode ? 88 : g_SystemState.countdownTime);
    // 居中显示倒计时
    int xPos = (OLED_SCREEN_WIDTH - strlen(countdownBuf) * 12) / 2;
    g_OledDisplay.setCursor(xPos, 20);
    g_OledDisplay.print(countdownBuf);
  }

  // 显示进度条（非暂停/夜间/紧急模式）
  if (!g_SystemState.isNightMode && !g_SystemState.isPaused && !g_SystemState.isEmergencyMode) {
    int progress = map(g_SystemState.countdownTime, 0, g_SystemState.totalPhaseTime, 0, OLED_SCREEN_WIDTH);
    g_OledDisplay.fillRect(0, 45, progress, 4, WHITE); // 进度条填充
    g_OledDisplay.drawRect(0, 45, OLED_SCREEN_WIDTH, 4, WHITE); // 进度条边框
  }

  // 显示绿灯时长、模式、暂停状态
  g_OledDisplay.setTextSize(1);
  if (!g_SystemState.isNightMode && !g_SystemState.isEmergencyMode) {
    // 显示绿灯时长
    g_OledDisplay.setCursor(0, 54);
    g_OledDisplay.print(F("G:"));
    g_OledDisplay.print(g_SystemState.greenLightDuration);
  }
  
  if (!g_SystemState.isEmergencyMode) {
    // 显示工作模式
    g_OledDisplay.setCursor(85, 54);
    g_OledDisplay.print(g_SystemState.isNightMode ? F("Mode:N") : F("Mode:A"));
    
    // 显示暂停状态
    if (g_SystemState.isPaused) {
      g_OledDisplay.setCursor(55, 54);
      g_OledDisplay.print(F("PAUSE"));
    }
  }

  // 刷新显示
  g_OledDisplay.display();
}

/**
 * @brief 绘制OLED状态图标
 * @param phase 当前交通灯相位
 */
void OLED_DrawStatusIcon(byte phase) {
  // 暂停图标（双竖线）
  if (g_SystemState.isPaused && !g_SystemState.isEmergencyMode) {
    g_OledDisplay.fillTriangle(95, 18, 95, 30, 103, 24, WHITE);
    g_OledDisplay.fillRect(107, 18, 3, 12, WHITE);
    g_OledDisplay.fillRect(112, 18, 3, 12, WHITE);
  }

  // 夜间模式图标（月亮）
  if (g_SystemState.isNightMode) {
    g_OledDisplay.drawCircle(14, 14, 9, WHITE);
    g_OledDisplay.fillCircle(18, 14, 7, BLACK);
    return;
  }
  
  // 紧急模式图标（感叹号）
  if (g_SystemState.isEmergencyMode) {
    int centerX = OLED_SCREEN_WIDTH / 2;
    int centerY = 20;
    // 绘制感叹号外框
    g_OledDisplay.drawRect(centerX - 10, centerY - 10, 20, 6, WHITE);
    g_OledDisplay.drawRect(centerX - 6, centerY - 10, 12, 20, WHITE);
    g_OledDisplay.fillRect(centerX - 2, centerY - 6, 4, 12, WHITE);
    g_OledDisplay.setTextSize(2);
    g_OledDisplay.setCursor(centerX - 2, centerY - 2);
    g_OledDisplay.print(F("!"));
    return;
  }
  
  // 相位图标
  switch (phase) {
    case 0: // 东西绿灯
      g_OledDisplay.drawLine(5,15,20,15,WHITE);
      g_OledDisplay.drawLine(5,15,10,10,WHITE);
      g_OledDisplay.drawLine(5,15,10,20,WHITE);
      g_OledDisplay.drawLine(108,15,123,15,WHITE);
      g_OledDisplay.drawLine(123,15,118,10,WHITE);
      g_OledDisplay.drawLine(123,15,118,20,WHITE);
      break;
    case 2: // 南北绿灯
      g_OledDisplay.drawLine(5,5,5,20,WHITE);
      g_OledDisplay.drawLine(5,5,0,12,WHITE);
      g_OledDisplay.drawLine(5,5,10,12,WHITE);
      g_OledDisplay.drawLine(108,5,108,20,WHITE);
      g_OledDisplay.drawLine(108,20,103,13,WHITE);
      g_OledDisplay.drawLine(108,20,113,13,WHITE);
      break;
    case 1: // 东西黄灯
    case 3: // 南北黄灯
      g_OledDisplay.drawTriangle(30,18,18,32,42,32,WHITE);
      g_OledDisplay.fillTriangle(30,20,20,30,40,30,BLACK);
      g_OledDisplay.setTextSize(2);
      g_OledDisplay.setCursor(26,19);
      g_OledDisplay.print(F("!"));
      break;
  }
}
