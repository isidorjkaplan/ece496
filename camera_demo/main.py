import cv2
from imutils.video import FPS
import time
import numpy as np
import socket
import struct
import io


CROPPED_DIM = 28
CROPPED_SHOW_DIM = 350
global_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
SERVER_IP = "192.168.2.123"
SERVER_PORT = 6202


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
        with open('test_image/00000_5.jpg', 'rb') as file:
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

        result_size = b""
        result = b""

        while len(result_size) < 4:
            # Only receive the result size for now
            chunk = client_socket.recv(4 - len(result_size))

            # If connection close unexpectedly
            if not chunk:
                print("server unexpectedly terminate connection...")
                exit(1)

            # Append the received chunk to the previously received data
            result_size += chunk

        # At this point, 'result_size' contains all the received bytes for size, should be 40
        result_size = struct.unpack('!I', result_size)[0]
        if result_size != 40:
            print("result size is not 40, something is wrong...")

        # now get the actual result
        while len(result) < result_size:
            # Only receive the result size for now
            chunk = client_socket.recv(result_size - len(result))

            # If connection close unexpectedly
            if not chunk:
                print("server unexpectedly terminate connection...")
                exit(1)

            # Append the received chunk to the previously received data
            result += chunk

        # turn bytes received into list
        int_list = [int.from_bytes(result[i:i + 4], byteorder='little') for i in range(0, len(result), 4)]
        print("Received result: ", int_list)
        print("Expected Length: %d; Received Length: %d" % (result_size, len(result)))

    except ConnectionRefusedError:
        print("Connection was refused. Make sure the server is running and reachable.")
    finally:
        # Close the socket
        client_socket.close()


def do_filter(image):
    # Convert image to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Apply thresholding
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    thresh = 255 - thresh
    return cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)


def test_filter():
    # set up camera to use
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

        # crop center to send to server
        cv2.rectangle(frame, pt1=(340, 60), pt2=(940, 660), color=(0, 0, 255), thickness=3)
        cropped = frame[60:660, 340:940, :]
        cropped = do_filter(cropped)
        cropped = cv2.resize(cropped, (CROPPED_DIM, CROPPED_DIM))

        # create versions that we use to show result
        frame_show = cv2.resize(frame, (800, 450))
        cropped_show = cv2.resize(cropped, (350, 350))

        # create the window that we display
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


def sendAndRecv(image):
    # generate image size
    imgSize = len(image)
    imgSize = struct.pack("!I", imgSize)

    # send image size and image
    global_socket.sendall(imgSize)
    global_socket.sendall(image)

    # receive result
    result_size = b""
    result = b""

    # loop to receive all of result size
    while len(result_size) < 4:
        chunk = global_socket.recv(4 - len(result_size))
        if not chunk:
            print("server unexpectedly terminate connection...")
            exit(1)
        result_size += chunk

    # At this point, 'result_size' contains all the received bytes for size, should be 40
    result_size = struct.unpack('!I', result_size)[0]

    # now get the actual result
    while len(result) < result_size:
        chunk = global_socket.recv(result_size - len(result))
        if not chunk:
            print("server unexpectedly terminate connection...")
            exit(1)
        result += chunk

    # turn bytes received into list
    int_list = [int.from_bytes(result[i:i + 4], byteorder='little') for i in range(0, len(result), 4)]
    print("result = ", int_list)

    if result_size != 40:
        print("result size is not 40, something is wrong...")

    # Sort the list in descending order and get the top 3 values
    top_3_values = sorted(int_list, reverse=True)[:3]

    # Get the indices of the top 3 values
    top_3_indices = [int_list.index(value) for value in top_3_values]
    return top_3_indices


def main():
    # if 0 then use built in web cam
    # if 1 then use external web cam
    CAM = 1

    # setup the display frame
    combined = np.zeros([815, 1115, 3], 'uint8')
    combined[:, :, :] = 30
    # camera in
    combined[5:455, 5:805, :] = 0
    # cropped
    combined[510:810, 5:305, :] = 0
    # filtered
    combined[510:810, 505:805, :] = 0
    # top1
    combined[170:370, 910:1110, :] = 255
    # top2
    combined[390:590, 910:1110, :] = 255
    # top3
    combined[610:810, 910:1110, :] = 255
    # text
    cv2.putText(combined, "Top 3:", (910, 150), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    cv2.putText(combined, "<-Raw Image", (810, 75), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    cv2.putText(combined, "Cropped", (5, 500), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    cv2.putText(combined, "Filtered", (505, 500), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)

    cv2.imshow("frame", combined)

    # set up the socket to talk with server
    global_socket.connect((SERVER_IP, SERVER_PORT))

    # set up camera to use
    print("before cam", flush=True)
    cam = cv2.VideoCapture(CAM)
    print("after cam", flush=True)
    cam.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cam.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    fps = FPS().start()
    counter = 0
    res = None

    print("before while", flush=True)
    while True:
        ret, frame = cam.read()  # get frame
        if CAM == 0:
            frame = cv2.flip(frame, 1)  # flip horizontally

        # crop center to send to server
        cv2.rectangle(frame, pt1=(340, 60), pt2=(940, 660), color=(0, 0, 255), thickness=3)
        cropped = frame[60:660, 340:940, :]
        filtered = cropped
        if CAM == 0:
            filtered = cv2.flip(filtered, 1)
        filtered = do_filter(filtered)
        filtered = cv2.resize(filtered, (CROPPED_DIM, CROPPED_DIM))

        # create versions that we use to show result
        frame_show = cv2.resize(frame, (800, 450))
        cropped_show = cv2.resize(cropped, (300, 300))
        filtered_show = cv2.resize(filtered, (300, 300))

        # only send to server at slower speed
        if counter == 0:
            img_encode = (cv2.imencode('.jpg', filtered)[1]).tobytes()
            res = sendAndRecv(img_encode)

        # populate display window
        combined[0:450, 0:800, :] = frame_show
        combined[510:810, 5:305, :] = cropped_show
        combined[510:810, 505:805, :] = filtered_show
        combined[170:370, 910:1110, :] = 255
        combined[390:590, 910:1110, :] = 255
        combined[610:810, 910:1110, :] = 255
        cv2.putText(combined, "%d" % res[0], (960, 320), cv2.FONT_HERSHEY_SIMPLEX, 5, (0, 0, 0), 5)
        cv2.putText(combined, "%d" % res[1], (960, 540), cv2.FONT_HERSHEY_SIMPLEX, 5, (0, 0, 0), 5)
        cv2.putText(combined, "%d" % res[2], (960, 760), cv2.FONT_HERSHEY_SIMPLEX, 5, (0, 0, 0), 5)

        cv2.imshow("frame", combined)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        counter = counter + 1
        if counter == 20:
            counter = 0

        # time.sleep(0.016)  # so we don't burn the camera
        fps.update()

    fps.stop()
    # Print the estimated FPS
    print("FPS: {:.2f}".format(fps.fps()))
    cam.release()
    cv2.destroyAllWindows()

    global_socket.close()


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    # test_read_file()
    # test_send()
    # test_filter()
    main()

# See PyCharm help at https://www.jetbrains.com/help/pycharm/
