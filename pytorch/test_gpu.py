import torch
import torch.nn as nn
from PIL import Image
import numpy as np
import os
import time

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(device)


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


# load only works if the same model is already declared
model = torch.load("model_90.pt", map_location=device)
model.to(device)
model.eval()

print('using gpu ?', end='')
print(next(model.parameters()).is_cuda)
# exit()

# get images and answers in list
images = []
paths = []
answers = []
folder = "pics/"

for fname in os.listdir(folder):
    path = os.path.join(folder, fname)
    if os.path.isfile(path):
        # store tensor into list
        img = Image.open(path)
        img.load()
        img = np.asarray(img, dtype="int32")
        img = img.astype('float32') / 256
        img = torch.from_numpy(img)
        img = img.unsqueeze(0)
        img = img.to(device)
        images.append(img)
        # store path and answer in list
        paths.append(path)
        answers.append(int(path.split(".")[0][-1]))

correct_count = 0
start = time.time_ns()
# # testing with files
# for i in range(len(images)):
#     # load from file instead
#     img = Image.open(paths[i])
#     img.load()
#     img = np.asarray(img, dtype="int32")
#     img = img.astype('float32') / 256
#     img = torch.from_numpy(img)
#     img = img.unsqueeze(0)
#     # inference
#     output = model(img)
#     # print(paths[i])
#     # print("ans = %d" % answers[i])
#     # print(int(torch.max(out, 0)[1]))
#     # print((int(torch.max(out, 0)[1]) == answers[i]))
#     if int(torch.max(output, 0)[1]) == answers[i]:
#         correct_count = correct_count + 1


for i in range(len(images)):
    # inference
    output = model(images[i])
    # print(paths[i])
    # print("ans = %d" % answers[i])
    # print(int(torch.max(out, 0)[1]))
    # print((int(torch.max(out, 0)[1]) == answers[i]))
    if int(torch.max(output, 0)[1]) == answers[i]:
        correct_count = correct_count + 1

end = time.time_ns()
time_elapsed = end - start
print("image tested: %d" % len(images))
print("time elapsed (ns) = %d" % time_elapsed)
print("time elapsed per img(ns) = %d" % (time_elapsed/60000))
print("accuracy = %f" % (float(correct_count)/60000))
