import socket
import os
import time

HOST = "127.0.0.1"
PORT = 62500

# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    # get image paths and answers in a list
    paths = []
    answers = []
    results = []
    folder = "pics/"

    for filename in os.listdir(folder):
        path = os.path.join(folder, filename)
        if os.path.isfile(path):
            # store path and answer in list
            paths.append(path)
            answers.append(int(path.split(".")[0][-1]))

    # connect to server
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((HOST, PORT))

        # send files and receive inference result
        start = time.time_ns()
        for path in paths:
            with open(path, mode="rb") as file:
                s.sendfile(file)
            s.sendall(b"done")
            data = s.recv(1024)
            if len(data) != 1:
                print("result not 1 byte long")
                exit()
            ans = int.from_bytes(data)
            results.append(ans)
        end = time.time_ns()

    print("inference done")
    for i in range(10):
        print("%s inference result is %d" % (paths[i], results[i]))

    # check accuracy
    correct_count = 0
    for i in range(60000):
        if results[i] == answers[i]:
            correct_count = correct_count + 1
            
    time_elapsed = end - start
    print("time elapsed (ns) = %d" % time_elapsed)
    print("time elapsed per img(ns) = %d" % (time_elapsed / 60000))
    print("accuracy = %f" % (float(correct_count) / 60000))
