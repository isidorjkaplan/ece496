
import sys

file = open(sys.argv[1], 'rb')
data = file.read()
print("File is %d bytes" % len(data))
line = ''
for byte in data:
    line = line + ("8'h%x, " % byte)
    if len(line) > 100:
        print(line)
        line = ''
print(line)

