//############################################################################
//   2023 ICLAB Fall Course
//   Lab04       : Siamese Neural Network
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.10.15
//   Version     : v5.0
//   File Name   : SNN.v
//   Module Name : SNN
//############################################################################

module SNN(
    // Input Ports
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel,
	Weight,
    Opt,

    // Output Ports
    out_valid,
    out
    );

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

// input and output port
input rst_n, clk, in_valid;
input [inst_sig_width+inst_exp_width:0] Img, Kernel, Weight;
input [1:0] Opt;

output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//==============================================//
//             Parameter and Integer            //
//==============================================//
// state parameter
parameter   IDLE               = 4'd0,
            READ_WEIGHT        = 4'd1,
            CONV               = 4'd2,
            FULL_CONNECTED_1   = 4'd3,
            FULL_CONNECTED_2   = 4'd4,
            FULL_CONNECTED_END = 4'd5,
            NORM_ACT           = 4'd6,
            L1_NORM            = 4'd7,
            OUT_VALID          = 4'd8;

integer i;
//==============================================//
//                 reg declaration              //
//==============================================//
// state reg
reg [3:0] current_state, next_state;

// 7-bit counter
reg [6:0] counter;

// 3 kernel, each kernel has 3*3 32-bit data
reg [31:0] Kernel_reg[0:26];

// 1 weight, each weight has 2*2 32-bit data
reg [31:0] Weight_reg[0:3];

// 2-bit Opt
// 2’d0 : Sigmoid & {Replication}
// 2’d1 : Sigmoid & {Zero}
// 2’d2 : tanh & {Replication}
// 2’d3 : tanh & {Zero}
// Opt[1] : 0 -> Sigmoid, 1 -> tanh
// Opt[0] : 0 -> Replication, 1 -> Zero
reg [1:0] Opt_reg;

// original image
reg [31:0] ori_img[0:15];

// feature map
reg [31:0] feature_map[0:31];

// full connected
reg [31:0] full_connected_result[0:7];

// // normalization
// reg [31:0] normalized_result[0:7];

// activation
reg [31:0] activation_result[0:7];

//==============================================//
//             Current State Block              //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) current_state <= IDLE;
    else current_state <= next_state;
end

//==============================================//
//              Next State Block                //
//==============================================//
always @(*) begin
    case (current_state)
        IDLE: begin
            if (in_valid) next_state = READ_WEIGHT;
            else next_state = IDLE;
        end
        READ_WEIGHT: begin
            if (counter == 8) next_state = CONV;
            else next_state = READ_WEIGHT;
        end
        CONV: begin
            // after (9 + 1) cycles for reading weight, start convolution
            // 1 cycle for convolution calculation
            if (counter == (95 + 10 + 1)) next_state = FULL_CONNECTED_1;
            else next_state = CONV;
        end
        FULL_CONNECTED_1: begin
            next_state = FULL_CONNECTED_2;
        end
        FULL_CONNECTED_2: begin
            next_state = FULL_CONNECTED_END;
        end
        FULL_CONNECTED_END: begin
            next_state = NORM_ACT;
        end
        NORM_ACT: begin
            // 8 input
            // 5 cycles for normalization and activation calculation
            if(counter == (7 + 5)) next_state = L1_NORM;
            else next_state = NORM_ACT;
        end
        L1_NORM: begin
            next_state = OUT_VALID;
        end
        OUT_VALID: begin
            next_state = IDLE;
        end

        default: next_state = IDLE; // illegal state
    endcase
end

//==============================================//
//            Sequential Block                  //
//==============================================//
// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 0;
    else if((current_state == IDLE && next_state != READ_WEIGHT) || current_state == FULL_CONNECTED_2) counter <= 0;
    else counter <= counter + 1;
end

//================================================//
//                    read data                   //
//================================================//
// directly used invalid signal instead of state machine
// read data - ori_img
always @(posedge clk) begin
    // counter from  0 to 15, 16 32-bit data
    // counter from 16 to 31, 16 32-bit data
    // counter from 32 to 47, 16 32-bit data
    // counter from 48 to 63, 16 32-bit data
    if (in_valid) ori_img[counter[3:0]] <= Img;
end

// read data - Kernel
always @(posedge clk) begin
    // counter from 0 to 26, 3 kernel, each kernel has 3*3 32-bit data
    if (in_valid && counter < 27) Kernel_reg[counter] <= Kernel;
end

// read data - Weight
always @(posedge clk) begin
    // counter from 0 to 3, 1 weight, each weight has 2*2 32-bit data
    if (in_valid && counter < 4) Weight_reg[counter] <= Weight;
end

// read data - Opt
always @(posedge clk) begin
    // counter == 0, 2-bit Opt
    if (in_valid && counter == 0) Opt_reg <= Opt;
end


//==============================================//
//             Define 9 multiplier              //
//==============================================//
reg [31:0] mul0_op1, mul0_op2;
wire [31:0] mul0_result;
reg [31:0] mul1_op1, mul1_op2;
wire [31:0] mul1_result;
reg [31:0] mul2_op1, mul2_op2;
wire [31:0] mul2_result;
reg [31:0] mul3_op1, mul3_op2;
wire [31:0] mul3_result;
reg [31:0] mul4_op1, mul4_op2;
wire [31:0] mul4_result;
reg [31:0] mul5_op1, mul5_op2;  
wire [31:0] mul5_result;
reg [31:0] mul6_op1, mul6_op2;
wire [31:0] mul6_result;
reg [31:0] mul7_op1, mul7_op2;
wire [31:0] mul7_result;
reg [31:0] mul8_op1, mul8_op2;
wire [31:0] mul8_result;
fp_mult mult0(.inst_a(mul0_op1), .inst_b(mul0_op2), .inst_rnd(3'b000), .z_inst(mul0_result));
fp_mult mult1(.inst_a(mul1_op1), .inst_b(mul1_op2), .inst_rnd(3'b000), .z_inst(mul1_result));
fp_mult mult2(.inst_a(mul2_op1), .inst_b(mul2_op2), .inst_rnd(3'b000), .z_inst(mul2_result));
fp_mult mult3(.inst_a(mul3_op1), .inst_b(mul3_op2), .inst_rnd(3'b000), .z_inst(mul3_result));
fp_mult mult4(.inst_a(mul4_op1), .inst_b(mul4_op2), .inst_rnd(3'b000), .z_inst(mul4_result));
fp_mult mult5(.inst_a(mul5_op1), .inst_b(mul5_op2), .inst_rnd(3'b000), .z_inst(mul5_result));
fp_mult mult6(.inst_a(mul6_op1), .inst_b(mul6_op2), .inst_rnd(3'b000), .z_inst(mul6_result));
fp_mult mult7(.inst_a(mul7_op1), .inst_b(mul7_op2), .inst_rnd(3'b000), .z_inst(mul7_result));
fp_mult mult8(.inst_a(mul8_op1), .inst_b(mul8_op2), .inst_rnd(3'b000), .z_inst(mul8_result));

//==============================================//
//              Define 5 2-input adder          //
//              Define 2 3-input adder          //
//==============================================//
// reg [31:0] add0_op1, add0_op2;
wire [31:0] add0_result;
// reg [31:0] add1_op1, add1_op2;
wire [31:0] add1_result;
// reg [31:0] add2_op1, add2_op2;
wire [31:0] add2_result;
// reg [31:0] add3_op1, add3_op2;
wire [31:0] add3_result;
// reg [31:0] add4_op1, add4_op2;
wire [31:0] add4_result;
reg [31:0] add5_op1, add5_op2, add5_op3;
wire [31:0] add5_result;
reg [31:0] add6_op1, add6_op2, add6_op3;
wire [31:0] add6_result;
// 4 2-input adder
fp_add add0(.inst_a(mul0_result), .inst_b(mul1_result), .inst_rnd(3'b000), .z_inst(add0_result));
fp_add add1(.inst_a(mul2_result), .inst_b(mul3_result), .inst_rnd(3'b000), .z_inst(add1_result));
fp_add add2(.inst_a(mul4_result), .inst_b(mul5_result), .inst_rnd(3'b000), .z_inst(add2_result));
fp_add add3(.inst_a(mul6_result), .inst_b(mul7_result), .inst_rnd(3'b000), .z_inst(add3_result));

// 6-input adder
fp_sum3 add4(.inst_a(add5_op1), .inst_b(add5_op2), .inst_c(add5_op3), .inst_rnd(3'b000), .z_inst(add5_result));
fp_sum3 add5(.inst_a(add6_op1), .inst_b(add6_op2), .inst_c(add6_op3), .inst_rnd(3'b000), .z_inst(add6_result));
fp_add  add6(.inst_a(add5_result), .inst_b(add6_result), .inst_rnd(3'b000), .z_inst(add4_result));

//================================================//
//  after reading weight, start convolution       //
//================================================//
wire [6:0] counter_conv;
wire [6:0] counter_conv_delay1;
wire [6:0] counter_conv_delay2;
assign counter_conv = counter - 9;
assign counter_conv_delay1 = counter_conv - 1;
assign counter_conv_delay2 = counter_conv - 2;

// pooling
wire [31:0] pooling_result[0:7];

// mul_op1
always @(posedge clk) begin
    // row 0
    if(current_state == CONV && counter_conv[3:0] == 0) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 0]; mul1_op1 <= (Opt_reg[0])? 0 : ori_img[ 0]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[ 1];
        mul3_op1 <= (Opt_reg[0])? 0 : ori_img[ 0]; mul4_op1 <=                   ori_img[ 0]; mul5_op1 <=                   ori_img[ 1];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[ 4]; mul7_op1 <=                   ori_img[ 4]; mul8_op1 <=                   ori_img[ 5];
    end else if(current_state == CONV && counter_conv[3:0] == 1) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 0]; mul1_op1 <= (Opt_reg[0])? 0 : ori_img[ 1]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[ 2];
        mul3_op1 <=                   ori_img[ 0]; mul4_op1 <=                   ori_img[ 1]; mul5_op1 <=                   ori_img[ 2];
        mul6_op1 <=                   ori_img[ 4]; mul7_op1 <=                   ori_img[ 5]; mul8_op1 <=                   ori_img[ 6];
    end else if(current_state == CONV && counter_conv[3:0] == 2) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 1]; mul1_op1 <= (Opt_reg[0])? 0 : ori_img[ 2]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[ 3];
        mul3_op1 <=                   ori_img[ 1]; mul4_op1 <=                   ori_img[ 2]; mul5_op1 <=                   ori_img[ 3];
        mul6_op1 <=                   ori_img[ 5]; mul7_op1 <=                   ori_img[ 6]; mul8_op1 <=                   ori_img[ 7];
    end else if(current_state == CONV && counter_conv[3:0] == 3) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 2]; mul1_op1 <= (Opt_reg[0])? 0 : ori_img[ 3]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[ 3];
        mul3_op1 <=                   ori_img[ 2]; mul4_op1 <=                   ori_img[ 3]; mul5_op1 <= (Opt_reg[0])? 0 : ori_img[ 3];
        mul6_op1 <=                   ori_img[ 6]; mul7_op1 <=                   ori_img[ 7]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[ 7];
    
    // row 1
    end else if(current_state == CONV && counter_conv[3:0] == 4) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 0]; mul1_op1 <=               ori_img[ 0]; mul2_op1 <=                   ori_img[ 1];
        mul3_op1 <= (Opt_reg[0])? 0 : ori_img[ 4]; mul4_op1 <=               ori_img[ 4]; mul5_op1 <=                   ori_img[ 5];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[ 8]; mul7_op1 <=               ori_img[ 8]; mul8_op1 <=                   ori_img[ 9];
    end else if(current_state == CONV && counter_conv[3:0] == 5) begin
        mul0_op1 <=                   ori_img[ 0]; mul1_op1 <=               ori_img[ 1]; mul2_op1 <=                   ori_img[ 2];
        mul3_op1 <=                   ori_img[ 4]; mul4_op1 <=               ori_img[ 5]; mul5_op1 <=                   ori_img[ 6];
        mul6_op1 <=                   ori_img[ 8]; mul7_op1 <=               ori_img[ 9]; mul8_op1 <=                   ori_img[10];
    end else if(current_state == CONV && counter_conv[3:0] == 6) begin
        mul0_op1 <=                   ori_img[ 1]; mul1_op1 <=               ori_img[ 2]; mul2_op1 <=                   ori_img[ 3];
        mul3_op1 <=                   ori_img[ 5]; mul4_op1 <=               ori_img[ 6]; mul5_op1 <=                   ori_img[ 7];
        mul6_op1 <=                   ori_img[ 9]; mul7_op1 <=               ori_img[10]; mul8_op1 <=                   ori_img[11];
    end else if(current_state == CONV && counter_conv[3:0] == 7) begin
        mul0_op1 <=                   ori_img[ 2]; mul1_op1 <=               ori_img[ 3]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[ 3];
        mul3_op1 <=                   ori_img[ 6]; mul4_op1 <=               ori_img[ 7]; mul5_op1 <= (Opt_reg[0])? 0 : ori_img[ 7];
        mul6_op1 <=                   ori_img[10]; mul7_op1 <=               ori_img[11]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[11];
    
    // row 2
    end else if(current_state == CONV && counter_conv[3:0] == 8) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 4]; mul1_op1 <=               ori_img[ 4]; mul2_op1 <=                   ori_img[ 5];
        mul3_op1 <= (Opt_reg[0])? 0 : ori_img[ 8]; mul4_op1 <=               ori_img[ 8]; mul5_op1 <=                   ori_img[ 9];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[12]; mul7_op1 <=               ori_img[12]; mul8_op1 <=                   ori_img[13];
    end else if(current_state == CONV && counter_conv[3:0] == 9) begin
        mul0_op1 <=                   ori_img[ 4]; mul1_op1 <=               ori_img[ 5]; mul2_op1 <=                   ori_img[ 6];
        mul3_op1 <=                   ori_img[ 8]; mul4_op1 <=               ori_img[ 9]; mul5_op1 <=                   ori_img[10];
        mul6_op1 <=                   ori_img[12]; mul7_op1 <=               ori_img[13]; mul8_op1 <=                   ori_img[14];
    end else if(current_state == CONV && counter_conv[3:0] == 10) begin
        mul0_op1 <=                   ori_img[ 5]; mul1_op1 <=               ori_img[ 6]; mul2_op1 <=                   ori_img[ 7];
        mul3_op1 <=                   ori_img[ 9]; mul4_op1 <=               ori_img[10]; mul5_op1 <=                   ori_img[11];
        mul6_op1 <=                   ori_img[13]; mul7_op1 <=               ori_img[14]; mul8_op1 <=                   ori_img[15];
    end else if(current_state == CONV && counter_conv[3:0] == 11) begin
        mul0_op1 <=                   ori_img[ 6]; mul1_op1 <=               ori_img[ 7]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[ 7];
        mul3_op1 <=                   ori_img[10]; mul4_op1 <=               ori_img[11]; mul5_op1 <= (Opt_reg[0])? 0 : ori_img[11];
        mul6_op1 <=                   ori_img[14]; mul7_op1 <=               ori_img[15]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[15];

    // row 3
    end else if(current_state == CONV && counter_conv[3:0] == 12) begin
        mul0_op1 <= (Opt_reg[0])? 0 : ori_img[ 8]; mul1_op1 <=                   ori_img[ 8]; mul2_op1 <=                   ori_img[ 9];
        mul3_op1 <= (Opt_reg[0])? 0 : ori_img[12]; mul4_op1 <=                   ori_img[12]; mul5_op1 <=                   ori_img[13];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[12]; mul7_op1 <= (Opt_reg[0])? 0 : ori_img[12]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[13];
    end else if(current_state == CONV && counter_conv[3:0] == 13) begin
        mul0_op1 <=                   ori_img[ 8]; mul1_op1 <=                   ori_img[ 9]; mul2_op1 <=                   ori_img[10];
        mul3_op1 <=                   ori_img[12]; mul4_op1 <=                   ori_img[13]; mul5_op1 <=                   ori_img[14];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[12]; mul7_op1 <= (Opt_reg[0])? 0 : ori_img[13]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[14];
    end else if(current_state == CONV && counter_conv[3:0] == 14) begin
        mul0_op1 <=                   ori_img[ 9]; mul1_op1 <=                   ori_img[10]; mul2_op1 <=                   ori_img[11];
        mul3_op1 <=                   ori_img[13]; mul4_op1 <=                   ori_img[14]; mul5_op1 <=                   ori_img[15];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[13]; mul7_op1 <= (Opt_reg[0])? 0 : ori_img[14]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[15];
    end else if(current_state == CONV && counter_conv[3:0] == 15) begin
        mul0_op1 <=                   ori_img[10]; mul1_op1 <=                   ori_img[11]; mul2_op1 <= (Opt_reg[0])? 0 : ori_img[11];
        mul3_op1 <=                   ori_img[14]; mul4_op1 <=                   ori_img[15]; mul5_op1 <= (Opt_reg[0])? 0 : ori_img[15];
        mul6_op1 <= (Opt_reg[0])? 0 : ori_img[14]; mul7_op1 <= (Opt_reg[0])? 0 : ori_img[15]; mul8_op1 <= (Opt_reg[0])? 0 : ori_img[15];
    end else if(current_state == FULL_CONNECTED_1) begin
        mul0_op1 <= pooling_result[0]; mul1_op1 <= pooling_result[1];
        mul2_op1 <= pooling_result[0]; mul3_op1 <= pooling_result[1];
        mul4_op1 <= pooling_result[2]; mul5_op1 <= pooling_result[3];
        mul6_op1 <= pooling_result[2]; mul7_op1 <= pooling_result[3];
        mul8_op1 <= 0;
    end else if(current_state == FULL_CONNECTED_2) begin
        mul0_op1 <= pooling_result[4 + 0]; mul1_op1 <= pooling_result[4 + 1];
        mul2_op1 <= pooling_result[4 + 0]; mul3_op1 <= pooling_result[4 + 1];
        mul4_op1 <= pooling_result[4 + 2]; mul5_op1 <= pooling_result[4 + 3];
        mul6_op1 <= pooling_result[4 + 2]; mul7_op1 <= pooling_result[4 + 3];
        mul8_op1 <= 0;
    end
end

// mul_op2
reg [4:0] offset_k;
always @(*) begin
    if(counter_conv[6:4] == 3'd0 || counter_conv[6:4] == 3'd3) offset_k = 0;
    else if(counter_conv[6:4] == 3'd1 || counter_conv[6:4] == 3'd4) offset_k = 9;
    else if(counter_conv[6:4] == 3'd2 || counter_conv[6:4] == 3'd5) offset_k = 18;
    else offset_k = 0;
end

always @(posedge clk) begin
    if(current_state == CONV) begin
        mul0_op2 <= Kernel_reg[offset_k + 0];
        mul1_op2 <= Kernel_reg[offset_k + 1];
        mul2_op2 <= Kernel_reg[offset_k + 2];
        mul3_op2 <= Kernel_reg[offset_k + 3];
        mul4_op2 <= Kernel_reg[offset_k + 4];
        mul5_op2 <= Kernel_reg[offset_k + 5];
        mul6_op2 <= Kernel_reg[offset_k + 6];
        mul7_op2 <= Kernel_reg[offset_k + 7];
        mul8_op2 <= Kernel_reg[offset_k + 8];
    end if(current_state == FULL_CONNECTED_1 || current_state == FULL_CONNECTED_2) begin
        mul0_op2 <= Weight_reg[0];
        mul1_op2 <= Weight_reg[2];
        mul2_op2 <= Weight_reg[1];
        mul3_op2 <= Weight_reg[3];
        mul4_op2 <= Weight_reg[0];
        mul5_op2 <= Weight_reg[2];
        mul6_op2 <= Weight_reg[1];
        mul7_op2 <= Weight_reg[3];
        mul8_op2 <= 0;
    end
end

// mul_result
// 5 of 6-input
always @(posedge clk) begin
    if(current_state == CONV) begin
        add5_op1 <= add0_result;
        add5_op2 <= add1_result;
        add5_op3 <= add2_result;
        add6_op1 <= add3_result;
        add6_op2 <= mul8_result; // no add
    end
end

// 1 of 6-input
reg [4:0] offset_adder_delay1;
always @(*) begin
    // first 3 image, offset_adder_delay1 =  0
    // last  3 image, offset_adder_delay1 = 16
    if(counter_conv_delay1[6:4] < 3'd3) offset_adder_delay1 = 0;
    else offset_adder_delay1 = 16;
end

always @(posedge clk) begin
    if(current_state == CONV) begin
        add6_op3 <= feature_map[counter_conv_delay1[3:0] + offset_adder_delay1];
    end
end

// add_result
reg [4:0] offset_adder_delay2;
always @(*) begin
    // first 3 image, offset_adder_delay2 =  0
    // last  3 image, offset_adder_delay2 = 16
    if(counter_conv_delay2[6:4] < 3'd3) offset_adder_delay2 = 0;
    else offset_adder_delay2 = 16;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 32; i = i + 1) begin
            feature_map[i] <= 0;
        end
    // counter_conv = 0 or 1, do nothing
    end else if(current_state == CONV && counter_conv > 1) begin
        feature_map[counter_conv_delay2[3:0] + offset_adder_delay2] <= add4_result;
    end else if(current_state == OUT_VALID) begin
        for(i = 0; i < 32; i = i + 1) begin
            feature_map[i] <= 0;
        end
    end
end

//================================================//
//       after convolution, start pooling         //
//================================================//
// When zctr is 1, z0 = Max(a,b)
wire [31:0] max_temp[0:15];

// temp max of frist feature map
fp_cmp  cmp0(.inst_a(feature_map[ 0]), .inst_b(feature_map[ 1]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 0]), .z1_inst());
fp_cmp  cmp1(.inst_a(feature_map[ 2]), .inst_b(feature_map[ 3]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 1]), .z1_inst());
fp_cmp  cmp2(.inst_a(feature_map[ 4]), .inst_b(feature_map[ 5]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 2]), .z1_inst());
fp_cmp  cmp3(.inst_a(feature_map[ 6]), .inst_b(feature_map[ 7]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 3]), .z1_inst());
fp_cmp  cmp4(.inst_a(feature_map[ 8]), .inst_b(feature_map[ 9]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 4]), .z1_inst());
fp_cmp  cmp5(.inst_a(feature_map[10]), .inst_b(feature_map[11]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 5]), .z1_inst());
fp_cmp  cmp6(.inst_a(feature_map[12]), .inst_b(feature_map[13]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 6]), .z1_inst());
fp_cmp  cmp7(.inst_a(feature_map[14]), .inst_b(feature_map[15]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 7]), .z1_inst());
// temp max of second feature map
fp_cmp  cmp8(.inst_a(feature_map[16]), .inst_b(feature_map[17]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 8]), .z1_inst());
fp_cmp  cmp9(.inst_a(feature_map[18]), .inst_b(feature_map[19]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[ 9]), .z1_inst());
fp_cmp cmp10(.inst_a(feature_map[20]), .inst_b(feature_map[21]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[10]), .z1_inst());
fp_cmp cmp11(.inst_a(feature_map[22]), .inst_b(feature_map[23]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[11]), .z1_inst());
fp_cmp cmp12(.inst_a(feature_map[24]), .inst_b(feature_map[25]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[12]), .z1_inst());
fp_cmp cmp13(.inst_a(feature_map[26]), .inst_b(feature_map[27]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[13]), .z1_inst());
fp_cmp cmp14(.inst_a(feature_map[28]), .inst_b(feature_map[29]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[14]), .z1_inst());
fp_cmp cmp15(.inst_a(feature_map[30]), .inst_b(feature_map[31]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_temp[15]), .z1_inst());
// pooling result of first feature map
fp_cmp cmp16(.inst_a(max_temp[ 0]), .inst_b(max_temp[ 2]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[0]), .z1_inst());
fp_cmp cmp17(.inst_a(max_temp[ 1]), .inst_b(max_temp[ 3]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[1]), .z1_inst());
fp_cmp cmp18(.inst_a(max_temp[ 4]), .inst_b(max_temp[ 6]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[2]), .z1_inst());
fp_cmp cmp19(.inst_a(max_temp[ 5]), .inst_b(max_temp[ 7]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[3]), .z1_inst());
// pooling result of second feature map
fp_cmp cmp20(.inst_a(max_temp[ 8]), .inst_b(max_temp[10]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[4]), .z1_inst());
fp_cmp cmp21(.inst_a(max_temp[ 9]), .inst_b(max_temp[11]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[5]), .z1_inst());
fp_cmp cmp22(.inst_a(max_temp[12]), .inst_b(max_temp[14]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[6]), .z1_inst());
fp_cmp cmp23(.inst_a(max_temp[13]), .inst_b(max_temp[15]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(pooling_result[7]), .z1_inst());

//================================================//
//       after pooling, start full connected      //
//================================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 8; i = i + 1) begin
            full_connected_result[i] <= 0;
        end
    end
    // delay 1 cycle after FULL_CONNECTED_1
    else if(current_state == FULL_CONNECTED_2) begin
        full_connected_result[0] <= add0_result;
        full_connected_result[1] <= add1_result;
        full_connected_result[2] <= add2_result;
        full_connected_result[3] <= add3_result;
    // delay 1 cycle after FULL_CONNECTED_2
    end else if(current_state == FULL_CONNECTED_END) begin
        full_connected_result[4] <= add0_result;
        full_connected_result[5] <= add1_result;
        full_connected_result[6] <= add2_result;
        full_connected_result[7] <= add3_result;
    end
end

//================================================//
//       after full connected, start normalizing  //
//================================================//
// determine max and min
wire [31:0] max_normalize[0:3];
wire [31:0] min_normalize[0:3];
wire [31:0] max[0:1], min[0:1];
fp_cmp cmp24(.inst_a(full_connected_result[0]), .inst_b(full_connected_result[1]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_normalize[0]), .z1_inst(min_normalize[0]));
fp_cmp cmp25(.inst_a(full_connected_result[2]), .inst_b(full_connected_result[3]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_normalize[1]), .z1_inst(min_normalize[1]));
fp_cmp cmp26(.inst_a(full_connected_result[4]), .inst_b(full_connected_result[5]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_normalize[2]), .z1_inst(min_normalize[2]));
fp_cmp cmp27(.inst_a(full_connected_result[6]), .inst_b(full_connected_result[7]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max_normalize[3]), .z1_inst(min_normalize[3]));

fp_cmp cmp28(.inst_a(max_normalize[0]), .inst_b(max_normalize[1]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max[0]), .z1_inst());
fp_cmp cmp29(.inst_a(max_normalize[2]), .inst_b(max_normalize[3]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(max[1]), .z1_inst());
fp_cmp cmp30(.inst_a(min_normalize[0]), .inst_b(min_normalize[1]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(), .z1_inst(min[0]));
fp_cmp cmp31(.inst_a(min_normalize[2]), .inst_b(min_normalize[3]), .inst_zctr(1'b1), .aeqb_inst(), .altb_inst(), .agtb_inst(), .unordered_inst(), .z0_inst(), .z1_inst(min[1]));


//==============================================//
//              Define 2 divider                //
//==============================================// 
reg  [31:0] div0_op1, div0_op2;
wire [31:0] div0_result;
reg  [31:0] div1_op1, div1_op2;
wire [31:0] div1_result;
fp_div div0(.inst_a(div0_op1), .inst_b(div0_op2), .inst_rnd(3'b000), .z_inst(div0_result));
fp_div div1(.inst_a(div1_op1), .inst_b(div1_op2), .inst_rnd(3'b000), .z_inst(div1_result));

//==============================================//
//              Define 2 subtractor             //
//==============================================//
reg  [31:0] sub4_op1, sub4_op2;
wire [31:0] sub4_result;
reg  [31:0] sub5_op1, sub5_op2;
wire [31:0] sub5_result;
fp_sub sub4(.inst_a(sub4_op1), .inst_b(sub4_op2), .inst_rnd(3'b000), .z_inst(sub4_result));
fp_sub sub5(.inst_a(sub5_op1), .inst_b(sub5_op2), .inst_rnd(3'b000), .z_inst(sub5_result));

//==============================================//
//              Define 2 adder                  //
//==============================================//
reg  [31:0] add7_op1, add7_op2;
wire [31:0] add7_result;
reg  [31:0] add8_op1, add8_op2;
wire [31:0] add8_result;
fp_add add7(.inst_a(add7_op1), .inst_b(add7_op2), .inst_rnd(3'b000), .z_inst(add7_result));
fp_add add8(.inst_a(add8_op1), .inst_b(add8_op2), .inst_rnd(3'b000), .z_inst(add8_result));

//==============================================//
//              Define 1 exp                    //
//==============================================//
reg [31:0] exp_input;
wire [31:0] exp_result;
fp_exp exp0(.inst_a(exp_input), .z_inst(exp_result));

// cycle 1
// sub4_op1 = x and sub4_op2 = min
always @(posedge clk) begin
    // first 4 cycle, x = full_connected_result[counter], min = min[0]
    // last  4 cycle, x = full_connected_result[counter], min = min[1]
    if(current_state == FULL_CONNECTED_END || current_state == NORM_ACT) begin
        sub4_op1 <= full_connected_result[counter];
        sub4_op2 <= min[counter[2]];
    end
end

// sub5_op1 = max and sub5_op2 = min
always @(posedge clk) begin
    // first 4 cycle, max = max[0], min = min[0]
    // last  4 cycle, max = max[1], min = min[1]
    if(current_state == FULL_CONNECTED_END || current_state == NORM_ACT) begin
        sub5_op1 <= max[counter[2]];
        sub5_op2 <= min[counter[2]];
    end
end

// cycle 2
// divider for normalization
always @(posedge clk) begin
    if(current_state == NORM_ACT) begin
        div0_op1 <= sub4_result;
        div0_op2 <= sub5_result;
    end
end

// cycle 3
// exp for activation
// z_vlaue = div0_result
// Opt[1] = 1 : tanh activation
// Opt[1] = 0 : sigmoid activation
wire [31:0] exp_input_wire;
assign exp_input_wire = (Opt_reg[1])?  {div0_result[31], (div0_result[30:23] + 1'b1), div0_result[22:0]} : {~div0_result[31], div0_result[30:0]}; // 2 * z or -z

always @(posedge clk) begin
    if(current_state == NORM_ACT) begin
        exp_input <= exp_input_wire;
    end
end

// cycle 4
always @(posedge clk) begin
    if(current_state == NORM_ACT) begin
        // Opt[1] = 1 : tanh activation
        // Opt[1] = 0 : sigmoid activation
        // -1 in IEEE 754 is 32'b10111111100000000000000000000000
        // +1 in IEEE 754 is 32'b00111111100000000000000000000000
        // +0 in IEEE 754 is 32'b00000000000000000000000000000000
        // +2 in IEEE 754 is 32'b01000000000000000000000000000000
        add7_op1 <= (Opt_reg[1])? exp_result : 32'b01000000000000000000000000000000; // exp_result or 2
        add7_op2 <= 32'b10111111100000000000000000000000; // -1
        add8_op1 <= exp_result; // exp_result
        add8_op2 <= 32'b00111111100000000000000000000000; // +1
    end
end

// cycle 5
// divider for activation
always @(posedge clk) begin
    if(current_state == NORM_ACT) begin
        div1_op1 <= add7_result;
        div1_op2 <= add8_result;
    end
end

// cycle 5
always @(posedge clk) begin
    if(current_state == NORM_ACT) begin
        activation_result[counter - 5] <= div1_result;
    end
end

//================================================//
//       after activation, start L1 distance      //
//================================================//
// L1_distance = sum of |activation_result of image 0 - activation_result of image 1|
reg [31:0] sub0_op1, sub0_op2, sub1_op1, sub1_op2, sub2_op1, sub2_op2, sub3_op1, sub3_op2;
wire [31:0] L1_distance0, L1_distance1, L1_distance2, L1_distance3;
wire [31:0] final_result;

fp_sub sub0(.inst_a(sub0_op1), .inst_b(sub0_op2), .inst_rnd(3'b000), .z_inst(L1_distance0));
fp_sub sub1(.inst_a(sub1_op1), .inst_b(sub1_op2), .inst_rnd(3'b000), .z_inst(L1_distance1));
fp_sub sub2(.inst_a(sub2_op1), .inst_b(sub2_op2), .inst_rnd(3'b000), .z_inst(L1_distance2));
fp_sub sub3(.inst_a(sub3_op1), .inst_b(sub3_op2), .inst_rnd(3'b000), .z_inst(L1_distance3));
fp_sum4 sum0(.inst_a({1'b0, L1_distance0[30:0]}), .inst_b({1'b0, L1_distance1[30:0]}), .inst_c({1'b0, L1_distance2[30:0]}), .inst_d({1'b0, L1_distance3[30:0]}), .inst_rnd(3'b000), .z_inst(final_result));

always @(posedge clk) begin
    if(current_state == L1_NORM) begin
        sub0_op1 <= activation_result[0];
        sub0_op2 <= activation_result[4];
        sub1_op1 <= activation_result[1];
        sub1_op2 <= activation_result[5];
        sub2_op1 <= activation_result[2];
        sub2_op2 <= activation_result[6];
        sub3_op1 <= activation_result[3];
        sub3_op2 <= activation_result[7];
    end
end

//================================================//
//              Output L1 distance                //
//================================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
        out <= 0;
    end else if(current_state == OUT_VALID) begin
        out_valid <= 1;
        out <= final_result;
    end else begin
        out_valid <= 0;
        out <= 0;
    end
end

endmodule

//==============================================//
//                 DesignWare IP                //
//==============================================//
// multiplication of floating point
module fp_mult( inst_a, inst_b, inst_rnd, z_inst);

parameter sig_width = 23;
parameter exp_width = 8;
parameter ieee_compliance = 1;
parameter en_ubr_flag = 0;

input [sig_width+exp_width : 0] inst_a;
input [sig_width+exp_width : 0] inst_b;
input [2 : 0] inst_rnd;
output [sig_width+exp_width : 0] z_inst;
// output [7 : 0] status_inst;

    // Instance of DW_fp_mult
    DW_fp_mult #(sig_width, exp_width, ieee_compliance, en_ubr_flag)
	  U1 ( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status() );

endmodule

//================================================//
// 2-input adder of floating point
module fp_add(inst_a, inst_b, inst_rnd, z_inst);

parameter sig_width = 23;
parameter exp_width = 8;
parameter ieee_compliance = 0;


input [sig_width+exp_width : 0] inst_a;
input [sig_width+exp_width : 0] inst_b;
input [2 : 0] inst_rnd;
output [sig_width+exp_width : 0] z_inst;
// output [7 : 0] status_inst;

    // Instance of DW_fp_add
    DW_fp_add #(sig_width, exp_width, ieee_compliance)
	  U1 ( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status() );

endmodule

//================================================//
// 3-input adder of floating point
module fp_sum3( inst_a, inst_b, inst_c, inst_rnd, z_inst);

parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;


input [inst_sig_width+inst_exp_width : 0] inst_a;
input [inst_sig_width+inst_exp_width : 0] inst_b;
input [inst_sig_width+inst_exp_width : 0] inst_c;
input [2 : 0] inst_rnd;
output [inst_sig_width+inst_exp_width : 0] z_inst;
// output [7 : 0] status_inst;

    // Instance of DW_fp_sum3
    DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) U1 (
			.a(inst_a),
			.b(inst_b),
			.c(inst_c),
			.rnd(inst_rnd),
			.z(z_inst),
			.status());

endmodule

//================================================//
// comparation of floating point
module fp_cmp( inst_a, inst_b, inst_zctr, aeqb_inst, altb_inst, 
		agtb_inst, unordered_inst, z0_inst, z1_inst);

parameter sig_width = 23;
parameter exp_width = 8;
parameter ieee_compliance = 0;


input [sig_width+exp_width : 0] inst_a;
input [sig_width+exp_width : 0] inst_b;
input inst_zctr;
output aeqb_inst;
output altb_inst;
output agtb_inst;
output unordered_inst;
output [sig_width+exp_width : 0] z0_inst;
output [sig_width+exp_width : 0] z1_inst;
// output [7 : 0] status0_inst;
// output [7 : 0] status1_inst;

    // Instance of DW_fp_cmp
    DW_fp_cmp #(sig_width, exp_width, ieee_compliance)
	  U1 ( .a(inst_a), .b(inst_b), .zctr(inst_zctr), .aeqb(aeqb_inst), 
		.altb(altb_inst), .agtb(agtb_inst), .unordered(unordered_inst), 
		.z0(z0_inst), .z1(z1_inst), .status0(), 
		.status1() );

endmodule

//================================================//
// division of floating point
module fp_div( inst_a, inst_b, inst_rnd, z_inst);

parameter sig_width = 23;
parameter exp_width = 8;
parameter ieee_compliance = 0;
parameter faithful_round = 0;
parameter en_ubr_flag = 0;


input [sig_width+exp_width : 0] inst_a;
input [sig_width+exp_width : 0] inst_b;
input [2 : 0] inst_rnd;
output [sig_width+exp_width : 0] z_inst;
// output [7 : 0] status_inst;

  // Instance of DW_fp_div
DW_fp_div #(sig_width, exp_width, ieee_compliance, faithful_round, en_ubr_flag) U1 
( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status());

endmodule

//================================================//
// exponent of floating point
module fp_exp( inst_a, z_inst);

// parameter inst_sig_width = 10;
parameter inst_sig_width = 23;
// parameter inst_exp_width = 5;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 2;


input [inst_sig_width+inst_exp_width : 0] inst_a;
output [inst_sig_width+inst_exp_width : 0] z_inst;
// output [7 : 0] status_inst;

    // Instance of DW_fp_exp
    DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) U1 (
			.a(inst_a),
			.z(z_inst),
			.status() );

endmodule

//================================================//
// subtraction of floating point
module fp_sub(inst_a, inst_b, inst_rnd, z_inst);

parameter sig_width = 23;
parameter exp_width = 8;
parameter ieee_compliance = 0;


input [sig_width+exp_width : 0] inst_a;
input [sig_width+exp_width : 0] inst_b;
input [2 : 0] inst_rnd;
output [sig_width+exp_width : 0] z_inst;
// output [7 : 0] status_inst;

    // Instance of DW_fp_sub
    DW_fp_sub #(sig_width, exp_width, ieee_compliance)
	  U1 ( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status() );

endmodule

//================================================//
// 4-input sum of floating point
module fp_sum4( inst_a, inst_b, inst_c, inst_d, inst_rnd, 
		z_inst);

parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;


input [inst_sig_width+inst_exp_width : 0] inst_a;
input [inst_sig_width+inst_exp_width : 0] inst_b;
input [inst_sig_width+inst_exp_width : 0] inst_c;
input [inst_sig_width+inst_exp_width : 0] inst_d;
input [2 : 0] inst_rnd;
output [inst_sig_width+inst_exp_width : 0] z_inst;
// output [7 : 0] status_inst;

    // Instance of DW_fp_sum4
    DW_fp_sum4 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) U1 (
			.a(inst_a),
			.b(inst_b),
			.c(inst_c),
			.d(inst_d),
			.rnd(inst_rnd),
			.z(z_inst),
			.status() );

endmodule