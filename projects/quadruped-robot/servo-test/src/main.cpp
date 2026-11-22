#include <Arduino.h>

// #if !defined( ARDUINO_ESP32C3_DEV )
// 	#error This code is intended to run on the ESP32_C3 platform! Please check your Tools->Board setting.
// #endif

#define TIMER_INTERRUPT_DEBUG       1
#define ISR_SERVO_DEBUG             1

// Select different ESP32 timer number (0-1) to avoid conflict
#define USE_ESP32_TIMER_NO          1

#include "ESP32_C3_ISR_Servo.h"
//#include "itest.h"
// Don't use PIN_D1 in core v2.0.0 and v2.0.1. Check https://github.com/espressif/arduino-esp32/issues/5868
// Don't use PIN_D2 with ESP32_C3 (crash)

//See file .../hardware/espressif/esp32/variants/(esp32|doitESP32devkitV1)/pins_arduino.h
#define PIN_LED           2         // Pin D2 mapped to pin GPIO2/ADC12 of ESP32, control on-board LED

#define PIN_D0            6         // Pin D0 mapped to pin GPIO0/BOOT/ADC11/TOUCH1 of ESP32
#define PIN_D1            7         // Pin D1 mapped to pin GPIO1/TX0 of ESP32
#define PIN_D2            8         // Pin D2 mapped to pin GPIO2/ADC12/TOUCH2 of ESP32
#define PIN_D3            9         // Pin D3 mapped to pin GPIO3/RX0 of ESP32
#define PIN_D4            2         // Pin D4 mapped to pin GPIO4/ADC10/TOUCH0 of ESP32
#define PIN_D5            18         // Pin D5 mapped to pin GPIO5/SPISS/VSPI_SS of ESP32
#define PIN_D6            3         // Pin D6 mapped to pin GPIO6/FLASH_SCK of ESP32
#define PIN_D7            19         // Pin D7 mapped to pin GPIO7/FLASH_D0 of ESP32


// Published values for SG90 servos; adjust if needed
#define MIN_MICROS      500  //544
#define MAX_MICROS      2500

#define NUM_SERVOS    8

typedef struct
{
	int     servoIndex;
	uint8_t servoPin;
} ISR_servo_t;

ISR_servo_t ISR_servo[NUM_SERVOS] =
{
	{ -1, PIN_D0 }, { -1, PIN_D1 }, { -1, PIN_D2 }, { -1, PIN_D3 }, { -1, PIN_D4 }, { -1, PIN_D5 }, { -1, PIN_D6 }, { -1, PIN_D7 }
};

void setup()
{
	Serial.begin(115200);

	while (!Serial && millis() < 5000);

  delay(500);

	Serial.print(F("\nStarting ESP32_C3_MultipleRandomServos on "));
	Serial.println(ARDUINO_BOARD);
	Serial.println(ESP32_C3_ISR_SERVO_VERSION);

	//Select ESP32 timer USE_ESP32_TIMER_NO
	ESP32_ISR_Servos.useTimer(USE_ESP32_TIMER_NO);

	for (int index = 0; index < NUM_SERVOS; index++)
	{
		ISR_servo[index].servoIndex = ESP32_ISR_Servos.setupServo(ISR_servo[index].servoPin, MIN_MICROS, MAX_MICROS);
    ESP32_ISR_Servos.setPosition(ISR_servo[index].servoIndex, 90);
		if (ISR_servo[index].servoIndex != -1)
		{
			Serial.print(F("Setup OK Servo index = "));
			Serial.println(ISR_servo[index].servoIndex);
		}
		else
		{
			Serial.print(F("Setup Failed Servo index = "));
			Serial.println(ISR_servo[index].servoIndex);
		}
	}
}

void printServoInfo(int indexServo)
{
	Serial.print(F("Servos idx = "));
	Serial.print(indexServo);
	Serial.print(F(", act. pos. (deg) = "));
	Serial.print(ESP32_ISR_Servos.getPosition(ISR_servo[indexServo].servoIndex) );
	Serial.print(F(", pulseWidth (us) = "));
	Serial.println(ESP32_ISR_Servos.getPulseWidth(ISR_servo[indexServo].servoIndex));
}

void loop()
{
	int position;      // position in degrees

	for (int index = 0; index < NUM_SERVOS; index++)
	{
    position = 75;
		ESP32_ISR_Servos.setPosition(ISR_servo[index].servoIndex, position );
    delay(500);                                                                                                             
    position = 90;
		ESP32_ISR_Servos.setPosition(ISR_servo[index].servoIndex, position );
    delay(500);
		//printServoInfo(index);
	}
	// waits 5s between test
	delay(3000);

}
