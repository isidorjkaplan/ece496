import torch
from keras.datasets import mnist
from PIL import Image
import torch.nn as nn
import torch.nn.functional as F
from torch.autograd import Variable
from torchsummary import summary
from sklearn.model_selection import train_test_split
import matplotlib.pyplot as plt


def print_hi(name):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, {name}')  # Press Ctrl+F8 to toggle the breakpoint.


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(device)
    (X_train, Y_train), (X_test, Y_test) = mnist.load_data()

    for i in range(len(X_train)):
        img = X_train[i]
        label = int(Y_train[i])
        im = Image.fromarray(img)
        im.save("pics/file_%d_%d.png" % (i, label))

    print_hi('PyCharm')

# See PyCharm help at https://www.jetbrains.com/help/pycharm/
