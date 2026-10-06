// test_i2c_receive.ino
// this receives left/right objective from pi over I2C
// prints that to serial monitor
// checks the pi to arduino link

// hardware is:
// pi SDA to arduino SDA (A4)
// pi SCL to arduino SCL (A5)
// gnd to gnd
// i2C addy 8 will be equal to ard_addr in pi


#include <Wire.h>

volatile byte desired[2] = {0, 0};
volatile bool newData = false;

void receiveEvent(int howMany) {
  Wire.read();                          // HERE I HANDLE OFFSET BY SKIPPING THE BYTE FOR OFFSET
  for (int i = 0; i < 2 && Wire.available(); i++) desired[i] = Wire.read();
  newData = true;
}

void setup() {
  Serial.begin(115200);
  Wire.begin(8);
  Wire.onReceive(receiveEvent);
  Serial.println("Need the goal from pi, waiting for it");
}

void loop() {
  if (newData) {                        // here i print outside of the interrupt
    newData = false;
    Serial.print("Goal Position: ");
    Serial.print(desired[0]);
    Serial.print(" ");
    Serial.println(desired[1]);
  }
}
