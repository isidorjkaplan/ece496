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

        cv2.rectangle(frame, pt1=(340, 60), pt2=(940,660), color=(0, 0, 255), thickness=3)
        cropped = frame[60:660, 340:940, :]
        cropped = cv2.resize(cropped, (28, 28))

        frame_show = cv2.resize(frame, (800, 450))
        cropped_show = cv2.resize(cropped, (450, 450))

        combined = np.zeros([450, 1250, 3], 'uint8')
        combined[0:450, 0:800, :] = frame_show
        combined[0:450, 800:1250, :] = cropped_show

        cv2.imshow("frame", combined)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        # if (counter % 600) == 0:
        #     img_encode = cv2.imencode('.jpg', combined)[1]
        #     filename = "testimage_%d.jpg" % counter
        #     with open(filename, "wb") as f:
        #         f.write(img_encode)

        counter = counter + 1
        time.sleep(0.016)  # so we don't burn the camera

    cam.release()
    cv2.destroyAllWindows()


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    main()

# See PyCharm help at https://www.jetbrains.com/help/pycharm/
