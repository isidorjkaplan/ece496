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
    counter = 0

    print("before while", flush=True)
    while True:
        ret, frame = cam.read()  # get frame
        frame = cv2.flip(frame, 1)  # flip horizontally
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        frame_show = cv2.resize(frame, (800, 450))
        gray_show = cv2.resize(gray, (800, 450))
        gray_show_3ch = np.zeros([450, 800, 3], 'uint8')
        for i in range(3):
            gray_show_3ch[:, :, i] = gray_show
        combined = np.zeros([450, 1600, 3], 'uint8')
        combined[0:450, 0:800, :] = frame_show
        combined[0:450, 800:1600, :] = gray_show_3ch

        cv2.imshow("frame", combined)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        if (counter % 600) == 0:
            img_encode = cv2.imencode('.jpg', combined)[1]
            filename = "testimage_%d.jpg" % counter
            with open(filename, "wb") as f:
                f.write(img_encode)

        counter = counter + 1
        time.sleep(0.016)  # so we don't burn the camera

    cam.release()
    cv2.destroyAllWindows()


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    main()

# See PyCharm help at https://www.jetbrains.com/help/pycharm/
