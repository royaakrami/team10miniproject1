// Arduino 2 wheel pos. control
// Controls

// MiniProject_PositionControl.ino

// This is meant to hold each wheel at a goal angle of 0. This is also
// shown as pi radians where tape 0 is up or tape 1 is up. 
// The goal is sent from Raspberry Pi over I2C.
// It can also be sent from the serial monitor when testing without the Pi. 

// every wheel runs a cascade
// It's calculated like here:
// outer loop (position, PI):  desired_speed = Kp_pos*e + Ki_pos*integral(e)
//  inner loop (velocity, P):   Voltage       = Kp*(desired_speed - actual_speed)

// the exercise 2a velocity controller is the inner loop, not changed, where kp=3
// on both of the motors. 
// the integral term found in the outer loop is what pulls a wheel back to its goal, 
// after someone turns it by hand. 

// the desired_speed is clamped to increase and decrease the max_speed.
// while the clamps active the integrator is frozen
// this is so that there are no buildups in large movements and overshoot doesnt occur

// to test this without pi, you would open the serial monitor at 115200. 
// then you would type 0, 1, 2, or 3
// same meaning as I2C byte
// every 10ms the board will print the following:
// time goal_L pos_L volt_L goal_R pos_R volt_R
// angles will be in radians and voltages will be in V
// print_data just prints all that data and it can be set to false. 

#include <Wire.h>

// pin assignments
const int enablePin = 4;

const int directionPin[2] = {7, 8};
const int pwmPin[2]       = {9, 10};
const int encoderA1 = 3, encoderB1 = 6;   // motor 1 cross wire
const int encoderA2 = 2, encoderB2 = 5;   // motor 2

// Explains what motor is the left wheel. If the wheels answer the wrong column
// of the quadrant table, these two numbers should be swapped then
const int LEFT  = 0;   // index 0 - motor 1
const int RIGHT = 1;   // index 1 - motor 2

// I2C
const int I2C_ADDRESS = 0x08;
volatile byte goal_byte = 0;        // written by I2C/Serial, read in loop()
volatile bool new_goal = false;

// Gains
// inner velocity loop from exercise 2a
const float Kp[2] = {3.0, 3.0};

// Outer position loop. Chosen from a discrete-time simulation of this
// this is the outer position loop. it's picked from a discrete-time simulation
// of this cascade with the identified motor models, like in position_control_sim.m
// about 0.7 s to settle on a pi rad step
const float Kp_pos = 8.0;           // (rad/s) per rad
const float Ki_pos = 2.0;           // (rad/s) per rad*s
const float max_speed = 8.0;        // rad/s clamp on desired_speed

// physical constants
const float Battery_Voltage = 7.8;
const float counts_per_rev = 3200.0;   // 64 counts/rev * 50:1 gearbox

// timing
const unsigned long desired_Ts_ms = 10;
unsigned long last_time_ms, start_time_ms;
const bool PRINT_DATA = true;

// controller state - two-element arrays with one per motor
volatile long encoderCount[2] = {0, 0};
long prevCount[2] = {0, 0};
float desired_pos[2] = {0, 0};
float integral_error[2] = {0, 0};

// encoder ISRs
// interrupts only on channel a and compare to b for direction
// increases/decreases by 2 for each edge keeps the 3200 counts/rev scaling
// like in exercise 2a
void encoderISR1() {
  if (digitalRead(encoderA1) == digitalRead(encoderB1)) encoderCount[0] += 2;
  else encoderCount[0] -= 2;
}

void encoderISR2() {
  if (digitalRead(encoderA2) == digitalRead(encoderB2)) encoderCount[1] += 2;
  else encoderCount[1] -= 2;
}

// these are I2C handlers
void receiveEvent(int howMany) {
  while (Wire.available()) {
    byte b = Wire.read();
    if (b <= 3) {            
      goal_byte = b;
      new_goal = true;
    }
  }
}

void requestEvent() {
  Wire.write(goal_byte);
}

// this turns a goal byte into wheel angles, so 0 is to 0 rad, 1 is to pi rad
void applyGoal(byte b) {
  desired_pos[LEFT]  = ((b >> 1) & 1) ? PI : 0.0;
  desired_pos[RIGHT] = (b & 1) ? PI : 0.0;
}

// velocity loop
// this returns the signed commanded voltage so it can be printed
float runVelocityLoop(int i, float desired_speed, float actual_speed) {
  float error = desired_speed - actual_speed;
  float Voltage = Kp[i] * error;

  digitalWrite(directionPin[i], Voltage > 0 ? HIGH : LOW);

  unsigned int PWM = (unsigned int)(255.0 * abs(Voltage) / Battery_Voltage);
  if (PWM > 255) PWM = 255;          // this saturates at battery voltage
  analogWrite(pwmPin[i], PWM);

  if (Voltage >  Battery_Voltage) Voltage =  Battery_Voltage;
  if (Voltage < -Battery_Voltage) Voltage = -Battery_Voltage;
  return Voltage;
}

void setup() {
  pinMode(enablePin, OUTPUT);
  for (int i = 0; i < 2; i++) {
    pinMode(directionPin[i], OUTPUT);
    pinMode(pwmPin[i], OUTPUT);
  }

  pinMode(encoderA1, INPUT_PULLUP);
  pinMode(encoderB1, INPUT_PULLUP);
  pinMode(encoderA2, INPUT_PULLUP);
  pinMode(encoderB2, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(encoderA1), encoderISR1, CHANGE);
  attachInterrupt(digitalPinToInterrupt(encoderA2), encoderISR2, CHANGE);

  digitalWrite(enablePin, HIGH);
  analogWrite(pwmPin[0], 0);
  analogWrite(pwmPin[1], 0);

  Wire.begin(I2C_ADDRESS);
  Wire.onReceive(receiveEvent);
  Wire.onRequest(requestEvent);

  Serial.begin(115200);
  Serial.println("Ready. Type 0-3 to set goal (bit1 = left, bit0 = right).");

  last_time_ms = millis();
  start_time_ms = last_time_ms;
}

void loop() {
  // this serial goal input is for testing
  while (Serial.available()) {
    char c = Serial.read();
    if (c >= '0' && c <= '3') {
      goal_byte = c - '0';
      new_goal = true;
    }
  }

  // this picks up a new goal from I2C or serial
  if (new_goal) {
    noInterrupts();
    byte b = goal_byte;
    new_goal = false;
    interrupts();
    applyGoal(b);
  }

  // this reads the encoders
  long count[2];
  noInterrupts();
  count[0] = encoderCount[0];
  count[1] = encoderCount[1];
  interrupts();

  float dt = (float)desired_Ts_ms / 1000.0;
  float actual_pos[2], actual_speed[2], voltage[2];

  for (int i = 0; i < 2; i++) {
    actual_pos[i]   = 2.0 * PI * (float)count[i] / counts_per_rev;
    actual_speed[i] = 2.0 * PI * (float)(count[i] - prevCount[i]) / counts_per_rev / dt;
    prevCount[i] = count[i];

    // this is the outer position look, pi and managing that clamping stuff
    float pos_error = desired_pos[i] - actual_pos[i];
    float desired_speed = Kp_pos * pos_error + Ki_pos * integral_error[i];

    if (desired_speed > max_speed) {
      desired_speed = max_speed;        
    } else if (desired_speed < -max_speed) {
      desired_speed = -max_speed;
    } else {
      integral_error[i] += pos_error * dt;
    }

    // this is an inner velocity loop here
    voltage[i] = runVelocityLoop(i, desired_speed, actual_speed[i]);
  }

  // data out is time goal_L pos_L volt_L goal_R pos_R volt_R
  if (PRINT_DATA) {
    Serial.print((float)(millis() - start_time_ms) / 1000.0, 3); Serial.print("\t");
    Serial.print(desired_pos[LEFT]);   Serial.print("\t");
    Serial.print(actual_pos[LEFT]);    Serial.print("\t");
    Serial.print(voltage[LEFT]);       Serial.print("\t");
    Serial.print(desired_pos[RIGHT]);  Serial.print("\t");
    Serial.print(actual_pos[RIGHT]);   Serial.print("\t");
    Serial.println(voltage[RIGHT]);
  }


  // this holds the 10 ms sample period
  while (millis() < last_time_ms + desired_Ts_ms) {}
  last_time_ms = millis();
}
