// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module model #(
    parameter VALUE_BITS = 18,
    parameter N = 12,
    // DO NOT CHANGE BELOW VALUES
    INPUT_WIDTH=28, INPUT_CHANNELS=1, OUTPUT_CHANNELS = 10
)(
    // General signals
    input clk, 
    input reset,
    // next row logic
    input   logic signed [VALUE_BITS - 1 : 0]  in_data[INPUT_CHANNELS],
    input   logic                              in_last,
    input   logic                              in_valid,
    output  logic                              in_ready,
    // output row valid 
    output  logic signed [VALUE_BITS - 1 : 0]  out_data[OUTPUT_CHANNELS],
    output  logic                              out_valid,
    output  logic                              out_last,
    input   logic                              out_ready
);    
    // weights
    localparam                                      CNN1_IN_CH = INPUT_CHANNELS;
    localparam                                      CNN1_OUT_CH = 4;
    localparam [32*CNN1_OUT_CH*CNN1_IN_CH*9-1:0]    PARAMCNN1WEIGHT = {-32'd10174, -32'd104150, -32'd91946, 32'd48411, -32'd40553, -32'd15014, 32'd44825, 32'd112022, 32'd81093, 32'd194725, 32'd122059, 32'd46556, 32'd115785, 32'd24132, 32'd50906, 32'd13227, -32'd3240, 32'd4675, 32'd55276, 32'd45645, 32'd40350, -32'd63657, 32'd40389, 32'd455, 32'd46677, 32'd65183, 32'd111589, 32'd94716, -32'd55682, -32'd121383, 32'd119082, 32'd11150, -32'd140981, 32'd59706, 32'd111818, -32'd32214};
    logic signed [32-1:0]                           cnn1weight[CNN1_OUT_CH][CNN1_IN_CH][3][3];
    localparam [32*CNN1_OUT_CH-1:0]                 PARAMCNN1BIAS = {-32'd5046, 32'd1505, -32'd1722, -32'd23765};
    logic signed [32-1:0]                           cnn1bias[CNN1_OUT_CH];

    localparam                                      CNN2_IN_CH = CNN1_OUT_CH;
    localparam                                      CNN2_OUT_CH = 4;
    localparam [32*CNN2_OUT_CH*CNN2_IN_CH*9-1:0]    PARAMCNN2WEIGHT = {32'd109236, 32'd2658, -32'd11465, 32'd42538, -32'd58894, -32'd44536, 32'd31282, -32'd104144, 32'd142203, -32'd27440, -32'd7070, 32'd7623, 32'd75575, 32'd11236, -32'd1996, -32'd7523, -32'd7632, 32'd28409, -32'd38722, -32'd24599, 32'd5760, 32'd36098, 32'd22751, 32'd12006, -32'd9661, 32'd66, 32'd11601, 32'd49363, -32'd13792, 32'd25063, -32'd10624, 32'd10856, 32'd60251, 32'd71402, 32'd53942, 32'd43235, 32'd38758, 32'd54588, 32'd2798, -32'd63034, 32'd19660, -32'd17945, -32'd49817, 32'd4620, -32'd66929, -32'd254693, -32'd19759, -32'd112019, -32'd27409, 32'd46808, -32'd6405, -32'd521, 32'd80937, 32'd32075, -32'd98908, -32'd14719, -32'd76878, 32'd19288, 32'd16883, 32'd251, 32'd65486, 32'd90184, 32'd5513, 32'd13370, -32'd14866, 32'd709, 32'd47066, -32'd18351, 32'd35250, 32'd71029, 32'd27217, 32'd42037, -32'd161305, -32'd17371, -32'd175867, -32'd163285, 32'd23718, -32'd27367, -32'd162841, -32'd34212, -32'd115626, 32'd14814, -32'd8460, -32'd47958, 32'd91586, -32'd48527, -32'd30865, 32'd88780, -32'd37742, -32'd51016, 32'd6659, 32'd37300, -32'd135232, 32'd27401, -32'd37018, -32'd61562, 32'd66630, 32'd50267, -32'd169312, -32'd12944, -32'd70534, 32'd110047, 32'd105849, 32'd20980, -32'd44848, 32'd94541, 32'd52719, 32'd139212, 32'd126461, -32'd8850, 32'd24150, 32'd49474, 32'd32073, 32'd56786, 32'd47452, 32'd86857, 32'd171069, 32'd28095, 32'd24228, 32'd10269, -32'd13180, -32'd49669, -32'd8657, -32'd20904, 32'd7354, 32'd44458, 32'd32295, -32'd22912, 32'd30393, -32'd55724, -32'd70693, -32'd10836, 32'd3080, 32'd62169, 32'd32554, -32'd197622, -32'd22312, -32'd38503, 32'd3193, -32'd35635, -32'd56561, 32'd113871, -32'd6717, -32'd19707};
    logic signed [32-1:0]                           cnn2weight[CNN2_OUT_CH][CNN2_IN_CH][3][3];
    localparam [32*CNN2_OUT_CH-1:0]                 PARAMCNN2BIAS = {-32'd85527, 32'd4897, 32'd218209, -32'd7496};
    logic signed [32-1:0]                           cnn2bias[CNN2_OUT_CH];

    localparam                                      CNN3_IN_CH = CNN2_OUT_CH;
    localparam                                      CNN3_OUT_CH = OUTPUT_CHANNELS;
    localparam [32*CNN3_OUT_CH*CNN3_IN_CH*9-1:0]    PARAMCNN3WEIGHT = {32'd27445, -32'd6993, 32'd27924, 32'd9200, -32'd49747, 32'd520, 32'd53481, -32'd11324, -32'd2675, -32'd13908, 32'd24722, 32'd18957, 32'd22825, 32'd44864, -32'd72374, -32'd29985, 32'd112600, -32'd94867, -32'd20127, -32'd4753, -32'd799324, -32'd10751, 32'd72670, -32'd180968, 32'd136917, -32'd158876, -32'd28239, -32'd5397, 32'd27057, -32'd33306, 32'd32546, -32'd28456, -32'd50805, 32'd5725, -32'd11999, -32'd85384, 32'd6837, -32'd35902, -32'd87170, -32'd17083, -32'd92340, -32'd101838, -32'd3535, 32'd39782, -32'd71344, 32'd151064, -32'd120796, 32'd53104, -32'd100737, 32'd131222, 32'd126389, -32'd190547, -32'd52764, 32'd102431, 32'd34236, -32'd52146, 32'd68360, 32'd26288, -32'd5051, 32'd68014, 32'd25789, 32'd17503, 32'd54344, -32'd386249, -32'd57051, -32'd204219, -32'd361466, 32'd26823, -32'd24535, -32'd286846, -32'd16992, 32'd82424, -32'd459, -32'd12407, 32'd35213, 32'd8415, -32'd11047, -32'd957, -32'd888, -32'd19631, -32'd66828, -32'd4057, 32'd27916, 32'd86739, -32'd31371, 32'd74298, -32'd150861, -32'd207417, -32'd223709, 32'd2070, -32'd23948, 32'd65256, 32'd33861, 32'd14818, 32'd70334, 32'd49070, -32'd62030, -32'd116974, -32'd128838, -32'd9182, 32'd57163, -32'd39154, 32'd73464, 32'd2563, -32'd23024, -32'd3288, -32'd20321, -32'd2711, -32'd46814, -32'd23030, 32'd18703, -32'd107481, -32'd14974, 32'd53018, -32'd93971, -32'd48498, -32'd36617, 32'd16894, 32'd7796, -32'd3, -32'd152165, -32'd54084, 32'd934, 32'd4666, -32'd116377, -32'd314391, -32'd97352, 32'd929, 32'd89372, 32'd32148, -32'd80481, 32'd5373, -32'd96838, 32'd37442, 32'd24363, 32'd26953, 32'd47028, 32'd15318, 32'd103743, -32'd84358, 32'd21648, 32'd81310, -32'd30820, 32'd80037, 32'd117757, 32'd10085, -32'd74359, 32'd70461, 32'd51027, 32'd39271, -32'd121631, -32'd50709, -32'd10673, -32'd176696, 32'd30034, -32'd17017, 32'd35986, 32'd125853, 32'd138111, -32'd6080, 32'd68971, 32'd25943, -32'd86398, -32'd52524, -32'd66667, -32'd157794, -32'd24219, -32'd14089, 32'd37765, 32'd96870, 32'd29257, -32'd52670, -32'd39404, -32'd145157, -32'd28039, -32'd47745, -32'd194856, 32'd45145, -32'd7271, 32'd46696, -32'd26608, -32'd36381, -32'd88346, 32'd4523, -32'd37411, -32'd59836, 32'd29115, 32'd71715, 32'd30554, 32'd48404, 32'd67727, 32'd47038, -32'd170590, -32'd58397, 32'd71024, -32'd55454, 32'd23693, 32'd20587, -32'd53086, -32'd114017, -32'd129511, -32'd46702, 32'd28401, -32'd77629, 32'd62845, 32'd78610, 32'd88550, -32'd25687, -32'd53923, -32'd53593, 32'd40262, 32'd60836, 32'd23871, -32'd44822, 32'd2852, 32'd34989, 32'd46012, -32'd35037, -32'd29531, -32'd4066, -32'd11103, 32'd4622, 32'd45525, 32'd23170, 32'd28599, -32'd37216, -32'd256115, 32'd56751, -32'd97745, -32'd41517, 32'd26807, -32'd37902, 32'd64302, 32'd23465, 32'd34053, 32'd36423, -32'd20844, -32'd1208, -32'd63872, -32'd14230, -32'd42776, 32'd10960, -32'd9052, 32'd6470, 32'd9580, 32'd11642, -32'd27572, -32'd65703, 32'd19297, -32'd26212, 32'd4719, 32'd5035, 32'd19416, 32'd21368, 32'd34514, -32'd13529, -32'd15774, -32'd36366, -32'd80087, -32'd31770, -32'd26035, 32'd213, -32'd5547, -32'd10590, 32'd38904, 32'd51920, 32'd74534, -32'd24922, 32'd59295, 32'd26462, -32'd289650, -32'd95942, 32'd15864, -32'd2370, -32'd13388, -32'd3089, 32'd62145, 32'd43555, 32'd56146, 32'd12074, 32'd11249, -32'd35566, -32'd13151, -32'd25078, 32'd38005, -32'd140248, -32'd152920, 32'd116939, -32'd46588, -32'd56568, -32'd28143, 32'd60511, 32'd53907, -32'd24843, -32'd30674, 32'd56636, 32'd47789, -32'd18252, 32'd34593, 32'd742, -32'd90898, 32'd52302, -32'd17282, -32'd144709, -32'd57882, -32'd78067, -32'd169443, -32'd95324, -32'd54182, 32'd6108, 32'd16304, -32'd3274, 32'd41525, 32'd63353, 32'd33172, -32'd62194, 32'd9578, 32'd17669, -32'd22831, 32'd91909, -32'd5646, -32'd48538, -32'd21065, 32'd49417, 32'd65769, 32'd43924, 32'd31199, -32'd47551, -32'd21389, 32'd3854, -32'd92421, -32'd57028, 32'd14033, -32'd95071, -32'd42518, -32'd17196, -32'd316607, -32'd110805, -32'd56584, -32'd1109, 32'd99731, 32'd66631, -32'd18071, -32'd60740, 32'd13427, -32'd125892, 32'd26155, -32'd441, 32'd50421, 32'd68100, 32'd38973, 32'd54105, -32'd20287, 32'd58042, 32'd7352, 32'd10570, -32'd144641, -32'd35471, -32'd1294, -32'd1284};
    logic signed [32-1:0]                           cnn3weight[CNN3_OUT_CH][CNN3_IN_CH][3][3];
    localparam [32*CNN3_OUT_CH-1:0]                 PARAMCNN3BIAS = {32'd66299, -32'd6688, 32'd38521, -32'd12491, -32'd495, 32'd18486, -32'd6314, 32'd111662, 32'd4264, -32'd48027};
    logic signed [32-1:0]                           cnn3bias[CNN3_OUT_CH];

    always_comb begin
        // cnn1 weights
        for(int o_channel = 0; o_channel < CNN1_OUT_CH; o_channel++) begin
            for(int i_channel = 0; i_channel < CNN1_IN_CH; i_channel++) begin
                for(int row = 0; row < 3; row++) begin
                    for(int col = 0; col < 3; col++) begin
                        cnn1weight[o_channel][i_channel][row][col] = PARAMCNN1WEIGHT[((32*CNN1_OUT_CH*CNN1_IN_CH*9-1) - (o_channel*CNN1_IN_CH*9*32) - (i_channel*9*32) - (row*3*32) - (col*32))-:32];
                    end
                end
            end
        end
        // cnn1 bias
        for(int o_channel = 0; o_channel < CNN1_OUT_CH; o_channel++) begin
            cnn1bias[o_channel] = PARAMCNN1BIAS[(32*CNN1_OUT_CH-1) - (o_channel*32) -:32];
        end
        // cnn2 weights
        for(int o_channel = 0; o_channel < CNN2_OUT_CH; o_channel++) begin
            for(int i_channel = 0; i_channel < CNN2_IN_CH; i_channel++) begin
                for(int row = 0; row < 3; row++) begin
                    for(int col = 0; col < 3; col++) begin
                        // cnn2weight[o_channel][i_channel][row][col] = PARAMCNN2WEIGHT[((32*CNN2_OUT_CH*CNN2_IN_CH*9-1) - (o_channel*CNN2_IN_CH*9*32) - (i_channel*9*32) - (row*3*32) - (col*32))-:32];
                        cnn2weight[o_channel][i_channel][row][col] = 2 << N;
                    end
                end
            end
        end
        // cnn2 bias
        for(int o_channel = 0; o_channel < CNN2_OUT_CH; o_channel++) begin
            // cnn2bias[o_channel] = PARAMCNN2BIAS[(32*CNN2_OUT_CH-1) - (o_channel*32) -:32];
            cnn2bias[o_channel] = 0;
        end
        // cnn3 weights
        for(int o_channel = 0; o_channel < CNN3_OUT_CH; o_channel++) begin
            for(int i_channel = 0; i_channel < CNN3_IN_CH; i_channel++) begin
                for(int row = 0; row < 3; row++) begin
                    for(int col = 0; col < 3; col++) begin
                        // cnn3weight[o_channel][i_channel][row][col] = PARAMCNN3WEIGHT[((32*CNN3_OUT_CH*CNN3_IN_CH*9-1) - (o_channel*CNN3_IN_CH*9*32) - (i_channel*9*32) - (row*3*32) - (col*32))-:32];
                        cnn3weight[o_channel][i_channel][row][col] = 1 << N;
                    end
                end
            end
        end
        // cnn3 bias
        for(int o_channel = 0; o_channel < CNN3_OUT_CH; o_channel++) begin
            // cnn3bias[o_channel] = PARAMCNN3BIAS[(32*CNN3_OUT_CH-1) - (o_channel*32) -:32];
            cnn3bias[o_channel] = 0;
        end
    end

    // conv1 <-> conv2
    logic signed [VALUE_BITS-1:0]  conv1toconv2_data[CNN1_OUT_CH];
    logic                          conv1toconv2_o_valid;
    logic                          conv2toconv1_o_ready;
    logic                          conv1toconv2_o_last;
    // conv2 <-> conv3
    logic signed [VALUE_BITS-1:0]  conv2toconv3_data[CNN2_OUT_CH];
    logic                          conv2toconv3_o_valid;
    logic                          conv3toconv2_o_ready;
    logic                          conv2toconv3_o_last;

    // conv2d #(
    //     .WIDTH(INPUT_WIDTH),
    //     .KERNAL_SIZE(3),
    //     .VALUE_BITS(18),
    //     .N(12),
    //     .OUTPUT_CHANNELS(1),
    //     .INPUT_CHANNELS(1)
    // ) convtest (
    //     .clk(clk),
    //     .reset(reset),
    //     .i_data(in_data),
    //     .i_valid(in_valid),
    //     .i_ready(in_ready),
    //     .i_last(in_data[0][VALUE_BITS-1]),
    //     .i_weights(cnn1weight[0:0]),
    //     .i_bias(cnn1bias[0:0]),
    //     .o_data(out_data[0:0]),
    //     .o_valid(out_valid),
    //     .o_ready(out_ready),
    //     .o_last(conv1toconv2_o_last)
    // );

    conv2d #(
        .WIDTH(INPUT_WIDTH),
        .KERNAL_SIZE(3),
        .VALUE_BITS(VALUE_BITS),
        .N(N),
        .STRIDE(2),
        .OUTPUT_CHANNELS(CNN1_OUT_CH),
        .INPUT_CHANNELS(CNN1_IN_CH)
    ) conv1 (
        .clk(clk),
        .reset(reset),
        .i_data(in_data),
        .i_valid(in_valid),
        .i_ready(in_ready),
        .i_last(in_last),
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
        .STRIDE(2),
        .OUTPUT_CHANNELS(CNN2_OUT_CH),
        .INPUT_CHANNELS(CNN2_IN_CH)
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
        .WIDTH(5),
        .KERNAL_SIZE(3),
        .VALUE_BITS(VALUE_BITS),
        .N(N),
        .STRIDE(10), // Any number > then WIDTH; when i_last raises we round up and send exactly one result
        .OUTPUT_CHANNELS(OUTPUT_CHANNELS),
        .INPUT_CHANNELS(CNN3_IN_CH)
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
        .o_last(out_last)
    );

endmodule 

