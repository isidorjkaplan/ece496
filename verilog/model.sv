// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module model #(
    parameter VALUE_BITS = 32,
    parameter N = 16,
    // DO NOT CHANGE BELOW VALUES
    INPUT_WIDTH = 28, INPUT_CHANNELS=1, OUTPUT_WIDTH = 1, OUTPUT_CHANNELS = 10
)(
    // General signals
    input clk, 
    input reset,
    // next row logic
    input   logic [VALUE_BITS - 1 : 0]  in_data[INPUT_CHANNELS],
    input   logic                       in_valid,
    output  logic                       in_ready,
    // output row valid 
    output  logic [VALUE_BITS - 1 : 0]  out_data[OUTPUT_CHANNELS],
    output  logic                       out_valid,
    input   logic                       out_ready
);    
    // weights
    localparam                                              CNN1_IN_CH = 1;
    localparam                                              CNN1_OUT_CH = 4;
    localparam [VALUE_BITS*CNN1_OUT_CH*CNN1_IN_CH*9-1:0]    PARAMCNN1WEIGHT = {-24'd10174, -24'd104150, -24'd91946, 24'd48411, -24'd40553, -24'd15014, 24'd44825, 24'd112022, 24'd81093, 24'd194725, 24'd122059, 24'd46556, 24'd115785, 24'd24132, 24'd50906, 24'd13227, -24'd3240, 24'd4675, 24'd55276, 24'd45645, 24'd40350, -24'd63657, 24'd40389, 24'd455, 24'd46677, 24'd65183, 24'd111589, 24'd94716, -24'd55682, -24'd121383, 24'd119082, 24'd11150, -24'd140981, 24'd59706, 24'd111818, -24'd32214};
    logic signed [VALUE_BITS-1:0]                           cnn1weight[CNN1_OUT_CH][CNN1_IN_CH][3][3];
    localparam [VALUE_BITS*CNN1_OUT_CH-1:0]                 PARAMCNN1BIAS = {-24'd5046, 24'd1505, -24'd1722, -24'd23765};
    logic signed [VALUE_BITS-1:0]                           cnn1bias[CNN1_OUT_CH];

    localparam                                              CNN2_IN_CH = 4;
    localparam                                              CNN2_OUT_CH = 4;
    localparam [VALUE_BITS*CNN2_OUT_CH*CNN2_IN_CH*9-1:0]    PARAMCNN2WEIGHT = {24'd109236, 24'd2658, -24'd11465, 24'd42538, -24'd58894, -24'd44536, 24'd31282, -24'd104144, 24'd142203, -24'd27440, -24'd7070, 24'd7623, 24'd75575, 24'd11236, -24'd1996, -24'd7523, -24'd7632, 24'd28409, -24'd38722, -24'd24599, 24'd5760, 24'd36098, 24'd22751, 24'd12006, -24'd9661, 24'd66, 24'd11601, 24'd49363, -24'd13792, 24'd25063, -24'd10624, 24'd10856, 24'd60251, 24'd71402, 24'd53942, 24'd43235, 24'd38758, 24'd54588, 24'd2798, -24'd63034, 24'd19660, -24'd17945, -24'd49817, 24'd4620, -24'd66929, -24'd254693, -24'd19759, -24'd112019, -24'd27409, 24'd46808, -24'd6405, -24'd521, 24'd80937, 24'd32075, -24'd98908, -24'd14719, -24'd76878, 24'd19288, 24'd16883, 24'd251, 24'd65486, 24'd90184, 24'd5513, 24'd13370, -24'd14866, 24'd709, 24'd47066, -24'd18351, 24'd35250, 24'd71029, 24'd27217, 24'd42037, -24'd161305, -24'd17371, -24'd175867, -24'd163285, 24'd23718, -24'd27367, -24'd162841, -24'd34212, -24'd115626, 24'd14814, -24'd8460, -24'd47958, 24'd91586, -24'd48527, -24'd30865, 24'd88780, -24'd37742, -24'd51016, 24'd6659, 24'd37300, -24'd135232, 24'd27401, -24'd37018, -24'd61562, 24'd66630, 24'd50267, -24'd169312, -24'd12944, -24'd70534, 24'd110047, 24'd105849, 24'd20980, -24'd44848, 24'd94541, 24'd52719, 24'd139212, 24'd126461, -24'd8850, 24'd24150, 24'd49474, 24'd32073, 24'd56786, 24'd47452, 24'd86857, 24'd171069, 24'd28095, 24'd24228, 24'd10269, -24'd13180, -24'd49669, -24'd8657, -24'd20904, 24'd7354, 24'd44458, 24'd32295, -24'd22912, 24'd30393, -24'd55724, -24'd70693, -24'd10836, 24'd3080, 24'd62169, 24'd32554, -24'd197622, -24'd22312, -24'd38503, 24'd3193, -24'd35635, -24'd56561, 24'd113871, -24'd6717, -24'd19707};
    logic signed [VALUE_BITS-1:0]                           cnn2weight[CNN2_OUT_CH][CNN2_IN_CH][3][3];
    localparam [VALUE_BITS*CNN2_OUT_CH-1:0]                 PARAMCNN2BIAS = {-24'd85527, 24'd4897, 24'd218209, -24'd7496};
    logic signed [VALUE_BITS-1:0]                           cnn2bias[CNN2_OUT_CH];

    localparam                                              CNN3_IN_CH = 4;
    localparam                                              CNN3_OUT_CH = 10;
    localparam [VALUE_BITS*CNN3_OUT_CH*CNN3_IN_CH*9-1:0]    PARAMCNN3WEIGHT = {24'd27445, -24'd6993, 24'd27924, 24'd9200, -24'd49747, 24'd520, 24'd53481, -24'd11324, -24'd2675, -24'd13908, 24'd24722, 24'd18957, 24'd22825, 24'd44864, -24'd72374, -24'd29985, 24'd112600, -24'd94867, -24'd20127, -24'd4753, -24'd799324, -24'd10751, 24'd72670, -24'd180968, 24'd136917, -24'd158876, -24'd28239, -24'd5397, 24'd27057, -24'd33306, 24'd32546, -24'd28456, -24'd50805, 24'd5725, -24'd11999, -24'd85384, 24'd6837, -24'd35902, -24'd87170, -24'd17083, -24'd92340, -24'd101838, -24'd3535, 24'd39782, -24'd71344, 24'd151064, -24'd120796, 24'd53104, -24'd100737, 24'd131222, 24'd126389, -24'd190547, -24'd52764, 24'd102431, 24'd34236, -24'd52146, 24'd68360, 24'd26288, -24'd5051, 24'd68014, 24'd25789, 24'd17503, 24'd54344, -24'd386249, -24'd57051, -24'd204219, -24'd361466, 24'd26823, -24'd24535, -24'd286846, -24'd16992, 24'd82424, -24'd459, -24'd12407, 24'd35213, 24'd8415, -24'd11047, -24'd957, -24'd888, -24'd19631, -24'd66828, -24'd4057, 24'd27916, 24'd86739, -24'd31371, 24'd74298, -24'd150861, -24'd207417, -24'd223709, 24'd2070, -24'd23948, 24'd65256, 24'd33861, 24'd14818, 24'd70334, 24'd49070, -24'd62030, -24'd116974, -24'd128838, -24'd9182, 24'd57163, -24'd39154, 24'd73464, 24'd2563, -24'd23024, -24'd3288, -24'd20321, -24'd2711, -24'd46814, -24'd23030, 24'd18703, -24'd107481, -24'd14974, 24'd53018, -24'd93971, -24'd48498, -24'd36617, 24'd16894, 24'd7796, -24'd3, -24'd152165, -24'd54084, 24'd934, 24'd4666, -24'd116377, -24'd314391, -24'd97352, 24'd929, 24'd89372, 24'd32148, -24'd80481, 24'd5373, -24'd96838, 24'd37442, 24'd24363, 24'd26953, 24'd47028, 24'd15318, 24'd103743, -24'd84358, 24'd21648, 24'd81310, -24'd30820, 24'd80037, 24'd117757, 24'd10085, -24'd74359, 24'd70461, 24'd51027, 24'd39271, -24'd121631, -24'd50709, -24'd10673, -24'd176696, 24'd30034, -24'd17017, 24'd35986, 24'd125853, 24'd138111, -24'd6080, 24'd68971, 24'd25943, -24'd86398, -24'd52524, -24'd66667, -24'd157794, -24'd24219, -24'd14089, 24'd37765, 24'd96870, 24'd29257, -24'd52670, -24'd39404, -24'd145157, -24'd28039, -24'd47745, -24'd194856, 24'd45145, -24'd7271, 24'd46696, -24'd26608, -24'd36381, -24'd88346, 24'd4523, -24'd37411, -24'd59836, 24'd29115, 24'd71715, 24'd30554, 24'd48404, 24'd67727, 24'd47038, -24'd170590, -24'd58397, 24'd71024, -24'd55454, 24'd23693, 24'd20587, -24'd53086, -24'd114017, -24'd129511, -24'd46702, 24'd28401, -24'd77629, 24'd62845, 24'd78610, 24'd88550, -24'd25687, -24'd53923, -24'd53593, 24'd40262, 24'd60836, 24'd23871, -24'd44822, 24'd2852, 24'd34989, 24'd46012, -24'd35037, -24'd29531, -24'd4066, -24'd11103, 24'd4622, 24'd45525, 24'd23170, 24'd28599, -24'd37216, -24'd256115, 24'd56751, -24'd97745, -24'd41517, 24'd26807, -24'd37902, 24'd64302, 24'd23465, 24'd34053, 24'd36423, -24'd20844, -24'd1208, -24'd63872, -24'd14230, -24'd42776, 24'd10960, -24'd9052, 24'd6470, 24'd9580, 24'd11642, -24'd27572, -24'd65703, 24'd19297, -24'd26212, 24'd4719, 24'd5035, 24'd19416, 24'd21368, 24'd34514, -24'd13529, -24'd15774, -24'd36366, -24'd80087, -24'd31770, -24'd26035, 24'd213, -24'd5547, -24'd10590, 24'd38904, 24'd51920, 24'd74534, -24'd24922, 24'd59295, 24'd26462, -24'd289650, -24'd95942, 24'd15864, -24'd2370, -24'd13388, -24'd3089, 24'd62145, 24'd43555, 24'd56146, 24'd12074, 24'd11249, -24'd35566, -24'd13151, -24'd25078, 24'd38005, -24'd140248, -24'd152920, 24'd116939, -24'd46588, -24'd56568, -24'd28143, 24'd60511, 24'd53907, -24'd24843, -24'd30674, 24'd56636, 24'd47789, -24'd18252, 24'd34593, 24'd742, -24'd90898, 24'd52302, -24'd17282, -24'd144709, -24'd57882, -24'd78067, -24'd169443, -24'd95324, -24'd54182, 24'd6108, 24'd16304, -24'd3274, 24'd41525, 24'd63353, 24'd33172, -24'd62194, 24'd9578, 24'd17669, -24'd22831, 24'd91909, -24'd5646, -24'd48538, -24'd21065, 24'd49417, 24'd65769, 24'd43924, 24'd31199, -24'd47551, -24'd21389, 24'd3854, -24'd92421, -24'd57028, 24'd14033, -24'd95071, -24'd42518, -24'd17196, -24'd316607, -24'd110805, -24'd56584, -24'd1109, 24'd99731, 24'd66631, -24'd18071, -24'd60740, 24'd13427, -24'd125892, 24'd26155, -24'd441, 24'd50421, 24'd68100, 24'd38973, 24'd54105, -24'd20287, 24'd58042, 24'd7352, 24'd10570, -24'd144641, -24'd35471, -24'd1294, -24'd1284};
    logic signed [VALUE_BITS-1:0]                           cnn3weight[CNN3_OUT_CH][CNN3_IN_CH][3][3];
    localparam [VALUE_BITS*CNN3_OUT_CH-1:0]                 PARAMCNN3BIAS = {24'd66299, -24'd6688, 24'd38521, -24'd12491, -24'd495, 24'd18486, -24'd6314, 24'd111662, 24'd4264, -24'd48027};
    logic signed [VALUE_BITS-1:0]                           cnn3bias[CNN3_OUT_CH];

    always_comb begin
        // cnn1 weights
        for(int o_channel = 0; o_channel < CNN1_OUT_CH; o_channel++) begin
            for(int i_channel = 0; i_channel < CNN1_IN_CH; i_channel++) begin
                for(int row = 0; row < 3; row++) begin
                    for(int col = 0; col < 3; col++) begin
                        cnn1weight[o_channel][i_channel][row][col] = PARAMCNN1WEIGHT[((VALUE_BITS*CNN1_OUT_CH*CNN1_IN_CH*9-1) - (o_channel*CNN1_IN_CH*9*VALUE_BITS) - (i_channel*9*VALUE_BITS) - (row*3*VALUE_BITS) - (col*VALUE_BITS))-:VALUE_BITS];
                    end
                end
            end
        end
        // cnn1 bias
        for(int o_channel = 0; o_channel < CNN1_OUT_CH; o_channel++) begin
            cnn1bias[o_channel] = PARAMCNN1BIAS[(VALUE_BITS*CNN1_OUT_CH-1) - (o_channel*VALUE_BITS) -:VALUE_BITS];
        end
        // cnn2 weights
        for(int o_channel = 0; o_channel < CNN2_OUT_CH; o_channel++) begin
            for(int i_channel = 0; i_channel < CNN2_IN_CH; i_channel++) begin
                for(int row = 0; row < 3; row++) begin
                    for(int col = 0; col < 3; col++) begin
                        cnn2weight[o_channel][i_channel][row][col] = PARAMCNN2WEIGHT[((VALUE_BITS*CNN2_OUT_CH*CNN2_IN_CH*9-1) - (o_channel*CNN2_IN_CH*9*VALUE_BITS) - (i_channel*9*VALUE_BITS) - (row*3*VALUE_BITS) - (col*VALUE_BITS))-:VALUE_BITS];
                    end
                end
            end
        end
        // cnn2 bias
        for(int o_channel = 0; o_channel < CNN2_OUT_CH; o_channel++) begin
            cnn2bias[o_channel] = PARAMCNN2BIAS[(VALUE_BITS*CNN2_OUT_CH-1) - (o_channel*VALUE_BITS) -:VALUE_BITS];
        end
        // cnn3 weights
        for(int o_channel = 0; o_channel < CNN3_OUT_CH; o_channel++) begin
            for(int i_channel = 0; i_channel < CNN3_IN_CH; i_channel++) begin
                for(int row = 0; row < 3; row++) begin
                    for(int col = 0; col < 3; col++) begin
                        cnn3weight[o_channel][i_channel][row][col] = PARAMCNN3WEIGHT[((VALUE_BITS*CNN3_OUT_CH*CNN3_IN_CH*9-1) - (o_channel*CNN3_IN_CH*9*VALUE_BITS) - (i_channel*9*VALUE_BITS) - (row*3*VALUE_BITS) - (col*VALUE_BITS))-:VALUE_BITS];
                    end
                end
            end
        end
        // cnn3 bias
        for(int o_channel = 0; o_channel < CNN3_OUT_CH; o_channel++) begin
            cnn3bias[o_channel] = PARAMCNN3BIAS[(VALUE_BITS*CNN3_OUT_CH-1) - (o_channel*VALUE_BITS) -:VALUE_BITS];
        end
    end

    // conv1 <-> conv2
    logic [VALUE_BITS-1:0]  conv1toconv2_data[4];
    logic                   conv1toconv2_o_valid;
    logic                   conv2toconv1_o_ready;
    logic                   conv1toconv2_o_last;
    // conv2 <-> conv3
    logic [VALUE_BITS-1:0]  conv2toconv3_data[4];
    logic                   conv2toconv3_o_valid;
    logic                   conv3toconv2_o_ready;
    logic                   conv2toconv3_o_last;

    conv2d #(
        .WIDTH(INPUT_WIDTH),
        .KERNAL_SIZE(3),
        .VALUE_BITS(VALUE_BITS),
        .N(N),
        .OUTPUT_CHANNELS(4),
        .INPUT_CHANNELS(1)
    ) conv1 (
        .clk(clk),
        .reset(reset),
        .i_data(in_data),
        .i_valid(in_valid),
        .i_ready(in_ready),
        .i_last(in_data[0][VALUE_BITS-1]),
        .i_weights(cnn1weight),
        .i_bias(cnn1bias),
        .o_data(conv1toconv2_data),
        .o_valid(conv1toconv2_o_valid),
        .o_ready(conv2toconv1_o_ready),
        .o_last(conv1toconv2_o_last)
    );

    conv2d #(
        .WIDTH(13),
        .KERNAL_SIZE(3),
        .VALUE_BITS(VALUE_BITS),
        .N(N),
        .OUTPUT_CHANNELS(4),
        .INPUT_CHANNELS(4)
    ) conv2 (
        .clk(clk),
        .reset(reset),
        .i_data(conv1toconv2_data),
        .i_valid(conv1toconv2_o_valid),
        .i_ready(conv2toconv1_o_ready),
        .i_last(conv1toconv2_o_last),
        .i_weights(cnn2weight),
        .i_bias(cnn2bias),
        .o_data(conv2toconv3_data),
        .o_valid(conv2toconv3_o_valid),
        .o_ready(conv3toconv2_o_ready),
        .o_last(conv2toconv3_o_last)
    );

    conv2d #(
        .WIDTH(9),
        .KERNAL_SIZE(3),
        .VALUE_BITS(VALUE_BITS),
        .N(N),
        .OUTPUT_CHANNELS(10),
        .INPUT_CHANNELS(4)
    ) conv3 (
        .clk(clk),
        .reset(reset),
        .i_data(conv2toconv3_data),
        .i_valid(conv2toconv3_o_valid),
        .i_ready(conv3toconv2_o_ready),
        .i_last(conv2toconv3_o_last),
        .i_weights(cnn3weight),
        .i_bias(cnn3bias),
        .o_data(out_data),
        .o_valid(out_valid),
        .o_ready(out_ready),
        .o_last()
    );

endmodule 

