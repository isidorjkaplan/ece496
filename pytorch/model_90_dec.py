# Create CNN Model
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