import cv2
from imutils.video import FPS
import time
import numpy as np
import socket
import struct


CROPPED_DIM = 28
CROPPED_SHOW_DIM = 350


def test_read_file():
    with open('file_0_5.jpg', 'rb') as file:
        img = file.read()
        imgSize = len(img)
        print("img size is %d bytes" % imgSize)


def test_send():
    print("testing send and receive")
    # IP address and port of the server you want to connect to
    server_ip = "192.168.2.123"
    server_port = 6202

    # Create a TCP socket
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    try:
        # Connect to the server
        client_socket.connect((server_ip, server_port))
        print("Connected to the server.")

        img = None
        imgSize = None

        # Send data to the server
        # Read image file as binary
        with open('file_0_5.jpg', 'rb') as file:
            img = file.read()

        imgSize = len(img)
        print("img size is %d bytes" % imgSize)
        # packs into type BYTES so its now binary,
        # I is unsigned int
        # ! is big endian
        imgSize = struct.pack("!I", imgSize)
        print("img size is after conversion is ", imgSize)
        print("img size is of length %d" % len(imgSize))

        # send all sends everything, no need to check how many bytes sent
        client_socket.sendall(imgSize)
        client_socket.sendall(img)
        print("Image sent")

        # need to add better receiving logic but will do later
        # Receive data from the server
        resultSize = client_socket.recv(4)
        print("Result Size without conversion: ", resultSize)
        resultSize = struct.unpack('!I', resultSize)[0]
        result = client_socket.recv(1024)
        print("Received result: ", result)
        print("Expected Length: %d; Received Length: %d" % (resultSize, len(result)))

    except ConnectionRefusedError:
        print("Connection was refused. Make sure the server is running and reachable.")
    finally:
        # Close the socket
        client_socket.close()


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

        cv2.rectangle(frame, pt1=(340, 60), pt2=(940, 660), color=(0, 0, 255), thickness=3)
        cropped = frame[60:660, 340:940, :]
        cropped = cv2.resize(cropped, (CROPPED_DIM, CROPPED_DIM))

        frame_show = cv2.resize(frame, (800, 450))
        cropped_show = cv2.resize(cropped, (350, 350))

        combined = np.zeros([450 + CROPPED_SHOW_DIM, 800, 3], 'uint8')
        combined[0:450, 0:800, :] = frame_show
        combined[450:(450 + CROPPED_SHOW_DIM), 0:CROPPED_SHOW_DIM, :] = cropped_show

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
    # test_read_file()
    test_send()
    # main()

# See PyCharm help at https://www.jetbrains.com/help/pycharm/
