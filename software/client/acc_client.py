import os
import struct
from PIL import Image
os.system("rm -f ./test_files/*.result")

ilist = os.listdir("./test_files")
for f in ilist:
    if f[-4:] == ".png":
        im1 = Image.open("./test_files/" + f)
        im1.save("./test_files/" + f[0:-4] + ".jpg")
os.system("rm -f ./test_files/*.png")

ilist = os.listdir("./test_files")

cmd = "./a.out"
for f in ilist:
    cmd += " "
    cmd += "./test_files/" + f
os.system(cmd)

guesslist = [];

for f in ilist:
    with open("./test_files/"+f+".result", "rb") as file:
        cont = file.read();
        guesslist.append(struct.unpack("I" * (len(cont)//4), cont))
        print(f, guesslist[-1])
assert len(guesslist) == len(ilist)


num_correct = 0
for i in range(len(ilist)):
    correctpred = int([int(s) for s in ilist[i] if s.isdigit()][-1])
    index_max = max(enumerate(guesslist[i]), key=lambda v: v[1])[0]
    print(correctpred, index_max);
    if (correctpred == index_max):
        num_correct += 1

print("Accuracy: ", 100*num_correct/len(ilist) ,"%")
