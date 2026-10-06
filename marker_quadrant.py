# this is marker_quadrant.py
# it finds an ArUco marker in the camera image
# it figures out the quadrant its in, so NE, NW, SW, SE. 
# it turns that quadrant into wheel goal positions
# so NE = 0,0
# NW = 0,1
# SW = 1,1
# SE = 1,0

# the left wheel is north = 0, 
# south = 1
# the right wheel is east = 0, west = 1

# for the hardware, the USB webcam is plugged into any USB port found on the raspberry pi
# to run it we do python3 marker_quadrant.py, q is pressed in the camera window in order to quit. 

import cv2
DICT = cv2.aruco.DICT_6X6_50 # this needs to match the printed marker
MIRROR = False # this is set to True if the left/right seem like they're swapped
#Quadrant name -> [left wheel, right wheel]
# the quadrant name goes to left wheel, right wheel
GOALS = {"NE": [0, 0], "NW": [0, 1], "SW": [1, 1], "SE": [1, 0]}
# this sets up the aruco detetector 
aruco_dict = cv2.aruco.getPredefinedDictionary(DICT)
try:
detector = cv2.aruco.ArucoDetector(aruco_dict, cv2.aruco.DetectorParameters())
def find_markers(gray):
corners, ids, _ = detector.detectMarkers(gray)
return corners, ids
except AttributeError:
params = cv2.aruco.DetectorParameters_create()
def find_markers(gray):
corners, ids, _ = cv2.aruco.detectMarkers(gray, aruco_dict, parameters=params)
return corners, ids

def get_quadrant(frame):
# this returns (quadrant, (x,y)) for the first marker found, or (none, none)
gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
corners, ids = find_markers(gray)
if ids is None:
return None, None
# the center of the marker is the avg of the 4 corners
x, y = corners[0][0].mean(axis=0)
h, w = gray.shape
ns = "N" if y < h / 2 else "S" # top half = north (y goes DOWN in images)
ew = "E" if x > w / 2 else "W" # right half = east
return ns + ew, (int(x), int(y))

def draw(frame, quadrant, center, goal):
# this draws the crosshair, a dot on the marker, along with the goal text
h, w = frame.shape[:2]
cv2.line(frame, (w // 2, 0), (w // 2, h), (255, 255, 255), 1)
cv2.line(frame, (0, h // 2), (w, h // 2), (255, 255, 255), 1)
if center:
cv2.circle(frame, center, 8, (0, 0, 255), -1)
text = f"{quadrant or 'no marker'} goal: {goal[0]} {goal[1]}"
cv2.putText(frame, text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

def main():
camera = cv2.VideoCapture(0)
camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640) # small frames mean faster detection
camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
goal = [0, 0] # the system starts with both wheels at 0
while True:
ret, frame = camera.read()
if not ret:
print("camera not found. maybe not plugged in?")
break
if MIRROR:
frame = cv2.flip(frame, 1)
quadrant, center = get_quadrant(frame)
# only reacts when the goal changes, so this prevents lag in lcd/arduino
if quadrant and GOALS[quadrant] != goal:
goal = GOALS[quadrant]
print("New goal:", goal)
# the next step is to send the lcd plus the arduino here
draw(frame, quadrant, center, goal)
cv2.imshow("Mini Project", frame)
if cv2.waitKey(1) & 0xFF == ord("q"):
break
camera.release()
cv2.destroyAllWindows()

if __name__ == "__main__":
main()
