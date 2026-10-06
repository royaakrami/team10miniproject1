# pi_main.py
# this runs the pi side of this mini project
# the camera finds the marker and its quadrant with marker_quadrant.py
# this shows the live cam img with the marker position
# this sends the new goal (left, right) to the arduino over I2C
# this shows the goal position, l, r on the lcd
# the goal send and the goal position run in a background part so the lcd doesnt make the camera lag!!

# for the hardware, the usb webcam can be on any usb port of the pi
# adafruit 16x2 rgb lcd plate is on the pi's I2C pins, sda and scl
# arduino on the same i2c bus 
# Pi SDA to arduino SDA, SCL to SCL, GND to GND

# message is sent to arduino, 3 bytes, 0 left and right, 0 is the REGISTER/OFFSET BYTE
# this is run by doing python3 pi_main.py and you press q in the cam window in order to quit

import queue
import threading

import cv2
import board
import adafruit_character_lcd.character_lcd_rgb_i2c as character_lcd
from smbus2 import SMBus

from marker_quadrant import get_quadrant, draw, GOALS, MIRROR

# below is the I2C address for arduino and it has to match the arduino's wire.begin(8)
ARD_ADDR = 8          
q = queue.Queue()
# the main loop puts goals in the above line and the thread removes them


def i2c_worker():
    # the background thread sends every new goal into the arduino and then it updates the LCD
    lcd = character_lcd.Character_LCD_RGB_I2C(board.I2C(), 16, 2)
    lcd.color = [0, 100, 0]
    arduino = SMBus(1)

    while True:
        goal = q.get()            # it waits here until theres a new goal
        while not q.empty():      # if multiple are piled up then it skips to a new one
            goal = q.get()

        try:
            arduino.write_byte(ARD_ADDR, goal[0] * 2 + goal[1])
        except OSError:
            print("Arduino not responding (not connected?)")

        lcd.clear()
        lcd.message = f"Goal Position:\n{goal[0]} {goal[1]}"


def main():
    # daemon = true means that this thread will stop whemn the main program quits
    threading.Thread(target=i2c_worker, daemon=True).start()

    camera = cv2.VideoCapture(0)
    camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    goal = [0, 0]     # both wheels start with 0 facing up
    q.put(goal)       # and we show the starting goal on the LCD

    while True:
        ret, frame = camera.read()
        if not ret:
            print("Camera not found. Maybe not pluugged in.")
            break
        if MIRROR:
            frame = cv2.flip(frame, 1)

        quadrant, center = get_quadrant(frame)

        # this only sends when the goal changes, so no lag and no I2C bus congestion
        if quadrant and GOALS[quadrant] != goal:
            goal = GOALS[quadrant]
            print("New goal:", goal)
            q.put(goal)

        draw(frame, quadrant, center, goal)
        cv2.imshow("Mini Project", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    camera.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
