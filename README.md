This is Team 10's joint computer vision & localization/control submission for the first Mini Project. It contains the following folders:

Computer Vision: 
test_i2c_send.py 
test_i2c_receive.ino 
pi_main.py 
marker_quadrant.py

Localization & Controls: 
capture_position_step.m 
capture_step_response.m 
MiniProject_PositionControl.ino 
position_control_sim.m

Here is a breakdown of them all:

-- Computer Vision --
test_i2c_send.py sends a goal to the arduino by typing it in. This lets the controls team test the wheels without running the vision code. It lets us check the I2C link on its own.
test_i2c_receive.ino receives the left/right objective from Pi over I2C. It prints that to the serial monitor and checks the Pi to Arduino link.
marker_quadrant.py it finds an ArUco marker in the camera image and it figures out the quadrant it's in. These quadrants are NE, NW, SW, and SE. It turns that quadrant into wheel goal positions.
pi_main.py runs the pi side of the mini project. so the camera finds the marker and its quadrant with marker_quadrant.py. this shows the live cam img with the marker position. this sends the new goal (left, right) to the arduino over I2C. this shows the goal position, l, r, on the LCD. the goal send and the goal position run in a background part so the lcd doesn't make the camera lag!!

-- Localization & Controls --
capture_position_step.m runs an experimental position step on MiniProject_PositionControl.ino, and it saves it so that position_control_sim.m can compare against it.
capture_step_response.m this reads the step response data from the arduinos serial port into MATLAB. This makes it so that the arduino IDE doesnt select the data in the serial monitor. Because we were dealing with that bug earlier.
MiniProject_PositionControl.ino is meant to hold each wheel at a goal angle of 0. It shown as pi radians where tape 0 is up or tape 1 is up. The goal is sent from Raspberry Pi over I2C. It can also be sent from the serial monitor when testing without the Pi.
