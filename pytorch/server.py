import torch
import torch.nn as nn
from PIL import Image
import numpy as np
import io
import socket

HOST = "127.0.0.1"
PORT = 62500


# model we are using
class CNN_Model(nn.Module):
    def __init__(self):
        super(CNN_Model, self).__init__()
        cnn1_out_ch = 4
        cnn2_out_ch = 4
        have_linear = False
        # Convolution 1 , input_shape=(1,28,28), output_shape=(1,26,26)
        self.cnn1 = nn.Conv2d(in_channels=1, out_channels=cnn1_out_ch, kernel_size=3, stride=1, padding=0)
        # activation
        self.relu1 = nn.ReLU()
        # Max pool 1, output_shape=(1,13,13)
        self.maxpool1 = nn.MaxPool2d(kernel_size=2)
        # Convolution 2, output_shape=(1,11,11)
        self.cnn2 = nn.Conv2d(in_channels=cnn1_out_ch, out_channels=cnn2_out_ch, kernel_size=3, stride=1, padding=0)
        # activation
        self.relu2 = nn.ReLU()
        # Convolution 3, output_shape=(1,9,9)
        self.cnn3 = nn.Conv2d(in_channels=cnn2_out_ch, out_channels=10, kernel_size=3, stride=1, padding=0)
        # activation
        self.relu3 = nn.ReLU()
        # Max pool 2, output_shape=(10,4,4)
        self.maxpool2 = nn.MaxPool2d(kernel_size=2)
        # Average pool, output_shape=(10,1,1)
        self.avgpool = nn.AvgPool2d(kernel_size=4)
        # Fully connected 1, input_shape=(1*5*5)
        # self.fc1 = nn.Linear(10 * 5 * 5, 10)
        if have_linear:
            self.fc1 = nn.Linear(10 * 1 * 1, 10)

    def forward(self, x):
        have_linear = False
        # Convolution 1
        out = self.cnn1(x)
        out = self.relu1(out)
        # Max pool 1
        out = self.maxpool1(out)
        # Convolution 2
        out = self.cnn2(out)
        out = self.relu2(out)
        # Convolution 3
        out = self.cnn3(out)
        out = self.relu3(out)
        # Max pool 2
        out = self.maxpool2(out)
        # Average pool
        out = self.avgpool(out)
        out = out.view(out.size(0), -1)
        # print(out.size())
        # Linear function (readout)
        if have_linear:
            out = self.fc1(out)
        return out


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    # check device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(device)

    # load only works if the same model is already declared
    # load our model
    model = torch.load("model_90.pt")
    model.eval()

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, PORT))
        s.listen()
        conn, addr = s.accept()
        with conn:
            print(f"Connected by {addr}")
            # process per image
            image_count = 0
            while True:
                # initialize a bytearray to store binary
                buffer = bytearray(1024)
                byte_received = 0
                view = memoryview(buffer)

                # receive image
                while True:
                    nbytes = conn.recv_into(view)
                    byte_received = byte_received + nbytes
                    view = view[byte_received:]

                    # check if client closed connection
                    if nbytes == 0:
                        exit()
                    # if we received "done", break loop
                    if byte_received >= 4:
                        if buffer[byte_received-4:byte_received] == b"done":
                            # print("image received")
                            break

                # run inference on image
                image = Image.open(io.BytesIO(buffer[:byte_received-4]))
                image.load()
                image = np.asarray(image, dtype="int32")
                image = image.astype('float32') / 256
                image = torch.from_numpy(image)
                image = image.unsqueeze(0)
                output = model(image)
                # inference result
                ans = int(torch.max(output, 0)[1])

                # send response
                conn.send(ans.to_bytes())
                # print("inference sent")
                image_count = image_count + 1
                if image_count % 5000 == 0:
                    print("sent inference %d" % image_count)
