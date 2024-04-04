import cv2
from imutils.video import FPS
import time
import numpy as np


def main():
    print("before cam", flush=True)
    cam = cv2.VideoCapture(0)
    print("after cam", flush=True)
    cam.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cam.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    fps = FPS().start()

    print("before while", flush=True)
    while True:
        ret, frame = cam.read()  # get frame
        frame = cv2.flip(frame, 1)  # flip horizontally
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        frame_show = cv2.resize(frame, (640, 480))
        gray_show = cv2.resize(gray, (640, 480))
        combined = np.zeros([480, 1280, 3], 'uint8')
        combined[0:480, 0:640, :] = frame_show
        combined[0:480, 640:1280, :] = gray_show

        cv2.imshow("frame", combined)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        time.sleep(0.016)  # so we don't burn the camera

    cam.release()
    cv2.destroyAllWindows()


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    main()

# See PyCharm help at https://www.jetbrains.com/help/pycharm/
