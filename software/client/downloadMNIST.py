import keras
from keras.datasets import mnist

import numpy as np
from PIL import Image, ImageOps
import os

def save_image(filename, data_array):
    im = Image.fromarray(data_array.astype('uint8'))
    #im_invert = ImageOps.invert(im)
    im.save(filename)

# Load MNIST Data
(x_train, y_train), (x_test, y_test) = mnist.load_data()

DIR_NAME = "MNIST"
if os.path.exists(DIR_NAME) == False:
    os.mkdir(DIR_NAME)

# Save Images
i = 0
print("[---------------------------------------------------------------]")
for x in zip(x_train, y_train):
    #print(x[1])
    #print(x[0])
    filename = "{0}/{1:05d}_{2}.jpg".format(DIR_NAME,i, x[1])
    #print(filename)
    save_image(filename, x[0])
    i += 1
