import os
import struct
from PIL import Image
from time import sleep
import subprocess

#os.system("rm -f ./test_files/*.result")
#
subprocess.call("find ./test_files -maxdepth 1 -name \"*.result\" -print0 | xargs -0 rm", shell=True, executable="/bin/bash")

ilist = os.listdir("./test_files")
for f in ilist:
    if f[-4:] == ".png":
        im1 = Image.open("./test_files/" + f)
        im1.save("./test_files/" + f[0:-4] + ".jpg")
#os.system("rm -f ./test_files/*.png")
subprocess.call("rm -f ./test_files/*.png", shell=True, executable="/bin/bash")

ilist = os.listdir("./test_files")

#totargs = ["./a.out"]
#for f in ilist:
#    totargs.append("test_files/" + f)

cmd = "./a.out test_files/*jpg"
#for f in ilist:
#    cmd += " test_files/" + f

subprocess.call(cmd, shell=True, executable="/bin/bash")

guesslist = [];

for f in ilist:
    with open("./test_files/"+f+".result", "rb") as file:
        cont = file.read();
        guesslist.append(struct.unpack("I" * (len(cont)//4), cont))
        #print(f, guesslist[-1])
assert len(guesslist) == len(ilist)


num_correct = 0
for i in range(len(ilist)):
    correctpred = int([int(s) for s in ilist[i] if s.isdigit()][-1])
    index_max = max(enumerate(guesslist[i]), key=lambda v: v[1])[0]
    #print(correctpred, index_max);
    if (correctpred == index_max):
        num_correct += 1

print("Accuracy: ", 100*num_correct/len(ilist) ,"%")
