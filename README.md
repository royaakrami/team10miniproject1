This is Team 10's joint computer vision & localization/control submission for the first Mini Project. It contains the following folders:

**Graphs for documentation are further down** 

Computer Vision: 
- test_i2c_send.py 
- test_i2c_receive.ino 
- pi_main.py 
- marker_quadrant.py

Localization & Controls: 
- capture_position_step.m 
- capture_step_response.m 
- MiniProject_PositionControl.ino 
- position_control_sim.m

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

**This is the Open-Loop Response Graph**
Following a 3 volt step, this is angular velocity and commanded voltage for both of the motors. It compares the motor-model, expected/nominal predictions, with the experimental data we obtained. 
<img width="1026" height="719" alt="Screenshot 2026-10-05 at 8 24 52 PM" src="https://github.com/user-attachments/assets/a0d46969-5ffb-49a0-93e8-5fed82c88ed4" />

**This is the Closed-Loop Position and Voltage Graph**
For a 0 to pi position commmand, in radians, the voltage and position is commanded. The outer pi position controller makes the desired_speed, explained in the code you'll see. The inner velocity controller makes the motor voltage. Comparing experimental w/ nominal in these graphs: 
<img width="1001" height="721" alt="Screenshot 2026-10-05 at 8 25 34 PM" src="https://github.com/user-attachments/assets/fc4ca45a-2f25-40d9-9d16-ac3d604ff130" />

**This is the Position-Control Simulink diagram**
It's a cascaded position-control model for both of the wheels. Every wheel uses an outer PI position loop. They also use voltage saturation, velocity loop, and first-order motor model. We integrated motor velocity and that gave us angular position for the position feedback. 
<img width="659" height="448" alt="Screenshot 2026-10-05 at 8 26 22 PM" src="https://github.com/user-attachments/assets/0c1c89b9-75eb-4d86-bbce-3bb9feb00b65" />

**This is the Open-Loop Simulink diagram**
These are open loop models of both of the motors. The 3V passes through the voltage saturation block. The motor transfer function, Ksigma/(s+sigma), is used to predict the angular velocity. 
<img width="695" height="445" alt="Screenshot 2026-10-05 at 8 27 16 PM" src="https://github.com/user-attachments/assets/a2d1f1d1-7d60-494a-ab60-f8bfa0511cdd" />
