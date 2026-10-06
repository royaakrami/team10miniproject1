# test_i2c_send.py file
# sends a goal to the arduino by typing it in. 
# lets the controls team test the wheels without running the vision code.
# lets us check the I2C link on its own. 

# hardware info: arduino on the pi's I2C bus 
# SDA to SDA
# SCL to SCL
# GND to GND
# at the ARD

from smbus2 import SMBus

ARD_ADDR = 8
arduino = SMBus(1)

while True:
    text = input("Goal (left right), click q to quit: ")
    if text == "q":
        break
    try:
        left, right = [int(n) for n in text.split()]
        arduino.write_byte(ARD_ADDR, left * 2 + right)
        print("Sent", [left, right])
    except ValueError:
        print("Type two numbers like: 0 1")
    except OSError:
        print("Arduino isnt responding so wires & address issue")
