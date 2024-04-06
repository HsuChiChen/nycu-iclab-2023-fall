//############################################################################
//   2023 ICLAB Fall Course
//   Lab01       : Supper MOSFET Calculator(SMC)
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.09.24
//   Version     : v9.0
//   File Name   : SMC.v
//   Module Name : SMC
//############################################################################

module SMC(
  // Input signals
    mode,
    W_0, V_GS_0, V_DS_0,
    W_1, V_GS_1, V_DS_1,
    W_2, V_GS_2, V_DS_2,
    W_3, V_GS_3, V_DS_3,
    W_4, V_GS_4, V_DS_4,
    W_5, V_GS_5, V_DS_5,
  // Output signals
    out_n
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [2:0] W_0, V_GS_0, V_DS_0;
input [2:0] W_1, V_GS_1, V_DS_1;
input [2:0] W_2, V_GS_2, V_DS_2;
input [2:0] W_3, V_GS_3, V_DS_3;
input [2:0] W_4, V_GS_4, V_DS_4;
input [2:0] W_5, V_GS_5, V_DS_5;
input [1:0] mode;
output [7:0] out_n;         // use this if using continuous assignment for out_n  // Ex: assign out_n = XXX;
// output reg [7:0] out_n; 	// use this if using procedure assignment for out_n   // Ex: always@(*) begin out_n = XXX; end

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment
wire [7:0] Id_gm_0, Id_gm_1, Id_gm_2, Id_gm_3, Id_gm_4, Id_gm_5;
wire [7:0] max0, max1, max2, max3, max4, max5;
reg  [7:0] result0, result1, result2;
wire  [6:0] result0_div3, result1_div3, result2_div3;

//================================================================
//    DESIGN
//================================================================

// --------------------------------------------------
// write your design here
// --------------------------------------------------

/*Calculate Id or gm*/
CALCULATOR c0(.W(W_0), .V_GS(V_GS_0), .V_DS(V_DS_0), .mode0(mode[0]), .Id_gm(Id_gm_0));
CALCULATOR c1(.W(W_1), .V_GS(V_GS_1), .V_DS(V_DS_1), .mode0(mode[0]), .Id_gm(Id_gm_1));
CALCULATOR c2(.W(W_2), .V_GS(V_GS_2), .V_DS(V_DS_2), .mode0(mode[0]), .Id_gm(Id_gm_2));
CALCULATOR c3(.W(W_3), .V_GS(V_GS_3), .V_DS(V_DS_3), .mode0(mode[0]), .Id_gm(Id_gm_3));
CALCULATOR c4(.W(W_4), .V_GS(V_GS_4), .V_DS(V_DS_4), .mode0(mode[0]), .Id_gm(Id_gm_4));
CALCULATOR c5(.W(W_5), .V_GS(V_GS_5), .V_DS(V_DS_5), .mode0(mode[0]), .Id_gm(Id_gm_5));

/*Sort Id or gm*/
SORT s0(.unsorted0(Id_gm_0), .unsorted1(Id_gm_1), .unsorted2(Id_gm_2), .unsorted3(Id_gm_3), .unsorted4(Id_gm_4), .unsorted5(Id_gm_5), .max0(max0), .max1(max1), .max2(max2), .max3(max3), .max4(max4), .max5(max5));

/*Select according to mode*/
always @(*) begin
	if(mode[1]) begin
		result0 = max0;
		result1 = max1;
		result2 = max2;
	end
	else begin
		result0 = max3;
		result1 = max4;
		result2 = max5;
	end
end

// assign result0_div3 = result0 / 3;
// assign result1_div3 = result1 / 3;
// assign result2_div3 = result2 / 3;



assign out_n = (mode[0])? (3 * result0_div3 + 4 * result1_div3 + 5 * result2_div3) / 12 : (result0_div3 + result1_div3 + result2_div3) / 3;

endmodule


//================================================================
//   SUB MODULE
//================================================================

module CALCULATOR(
  // Input signals
    W, V_GS, V_DS, mode0,
  // Output signals
    Id_gm
);

input [2:0] W, V_GS, V_DS;
input mode0;
output [7:0] Id_gm;

wire [2:0] V_GS_minus1;
reg [5:0] op1_mul_op2;
wire [5:0] Id_gm_temp;

assign V_GS_minus1 = V_GS - 3'b1;

// (V_GS - 3'b1 > V_DS) ?
// truth : triode region
// false : saturation region

// mode0 == 1 : Id
// mode0 == 0 : gm

reg [2:0] operand1;
reg [3:0] operand2;

always @(*) begin
	if(V_GS_minus1 > V_DS) begin
		operand1 = V_DS;
		operand2 = 2 * V_GS_minus1 - V_DS;
	end
	else begin
		operand1 = V_GS_minus1;
		operand2 = V_GS_minus1;
	end
end

multiplication_table m0(.operand1(operand1), .operand2(operand2), .result(op1_mul_op2));
assign Id_gm_temp = (mode0)? op1_mul_op2 : 2 * operand1;
assign Id_gm = W * Id_gm_temp;

endmodule

// sort
module SORT (unsorted0, unsorted1, unsorted2, unsorted3, unsorted4, unsorted5, max0, max1, max2, max3, max4, max5);
	input [7:0] unsorted0, unsorted1, unsorted2, unsorted3, unsorted4, unsorted5;
	output reg [7:0] max0, max1, max2, max3, max4, max5;

	reg [7:0] layer1_0, layer1_1, layer1_2, layer1_3, layer1_4, layer1_5;
	reg [7:0] layer2_0, layer2_1, layer2_2, layer2_3, layer2_4, layer2_5;
	reg [7:0]           layer3_1, layer3_2, layer3_3, layer3_4          ;
	reg [7:0]                     layer4_2, layer4_3                    ;

	always @(*) begin
		// layer 1
		if(unsorted0 > unsorted1) begin
			layer1_0 = unsorted0;
			layer1_1 = unsorted1;
		end
		else begin
			layer1_0 = unsorted1;
			layer1_1 = unsorted0;
		end

		if(unsorted2 > unsorted3) begin
			layer1_2 = unsorted2;
			layer1_3 = unsorted3;
		end
		else begin
			layer1_2 = unsorted3;
			layer1_3 = unsorted2;
		end

		if(unsorted4 > unsorted5) begin
			layer1_4 = unsorted4;
			layer1_5 = unsorted5;
		end
		else begin
			layer1_4 = unsorted5;
			layer1_5 = unsorted4;
		end

		// layer 2
		if(layer1_0 > layer1_2) begin
			layer2_0 = layer1_0;
			layer2_2 = layer1_2;
		end
		else begin
			layer2_0 = layer1_2;
			layer2_2 = layer1_0;
		end

		if(layer1_3 > layer1_5) begin
			layer2_3 = layer1_3;
			layer2_5 = layer1_5;
		end
		else begin
			layer2_3 = layer1_5;
			layer2_5 = layer1_3;
		end

		if(layer1_1 > layer1_4) begin
			layer2_1 = layer1_1;
			layer2_4 = layer1_4;
		end
		else begin
			layer2_1 = layer1_4;
			layer2_4 = layer1_1;
		end

		//layer 3
		if(layer2_0 > layer2_1) begin
			max0 = layer2_0;
			layer3_1 = layer2_1;
		end
		else begin
			max0 = layer2_1;
			layer3_1 = layer2_0;
		end
		
		if(layer2_2 > layer2_3) begin
			layer3_2 = layer2_2;
			layer3_3 = layer2_3;
		end
		else begin
			layer3_2 = layer2_3;
			layer3_3 = layer2_2;
		end

		if(layer2_4 > layer2_5) begin
			layer3_4 = layer2_4;
			max5     = layer2_5;
		end
		else begin
			layer3_4 = layer2_5;
			max5     = layer2_4;
		end

		// layer 4
		if(layer3_1 > layer3_2) begin
			max1     = layer3_1;
			layer4_2 = layer3_2;
		end
		else begin
			max1     = layer3_2;
			layer4_2 = layer3_1;
		end

		if(layer3_3 > layer3_4) begin
			layer4_3 = layer3_3;
			max4     = layer3_4;
		end
		else begin
			layer4_3 = layer3_4;
			max4     = layer3_3;
		end

		// layer 5
		if(layer4_2 > layer4_3) begin
			max2 = layer4_2;
			max3 = layer4_3;
		end
		else begin
			max2 = layer4_3;
			max3 = layer4_2;
		end
	end
endmodule

module multiplication_table(
    input [2:0] operand1, // 3位输入，范围0~6
    input [3:0] operand2, // 4位输入，范围0~11
    output reg [5:0] result // 6位输出
);

always @(*) begin
    case({operand1, operand2})
        // operand1=0 的情况
        7'b000_0000: result = 6'd0; // operand2=0
        7'b000_0001: result = 6'd0; // operand2=1
        7'b000_0010: result = 6'd0; // operand2=2
        7'b000_0011: result = 6'd0; // operand2=3
        7'b000_0100: result = 6'd0; // operand2=4
        7'b000_0101: result = 6'd0; // operand2=5
        7'b000_0110: result = 6'd0; // operand2=6
        7'b000_0111: result = 6'd0; // operand2=7
        7'b000_1000: result = 6'd0; // operand2=8
        7'b000_1001: result = 6'd0; // operand2=9
        7'b000_1010: result = 6'd0; // operand2=10
        7'b000_1011: result = 6'd0; // operand2=11
		7'b000_1100: result = 6'd0; // operand2=12
		7'b000_1101: result = 6'd0; // operand2=13
		7'b000_1110: result = 6'd0; // operand2=14
		7'b000_1111: result = 6'd0; // operand2=15
        // operand1=1 的情况
        7'b001_0000: result = 6'd0; // operand2=0
        7'b001_0001: result = 6'd1; // operand2=1
        7'b001_0010: result = 6'd2; // operand2=2
        7'b001_0011: result = 6'd3; // operand2=3
        7'b001_0100: result = 6'd4; // operand2=4
        7'b001_0101: result = 6'd5; // operand2=5
        7'b001_0110: result = 6'd6; // operand2=6
        7'b001_0111: result = 6'd7; // operand2=7
        7'b001_1000: result = 6'd8; // operand2=8
        7'b001_1001: result = 6'd9; // operand2=9
        7'b001_1010: result = 6'd10; // operand2=10
        7'b001_1011: result = 6'd11; // operand2=11
		7'b001_1100: result = 6'd12; // operand2=12
		7'b001_1101: result = 6'd13; // operand2=13
		7'b001_1110: result = 6'd14; // operand2=14
		7'b001_1111: result = 6'd15; // operand2=15
        // operand1=2 的情况
        7'b010_0000: result = 6'd0; // operand2=0
        7'b010_0001: result = 6'd2; // operand2=1
        7'b010_0010: result = 6'd4; // operand2=2
        7'b010_0011: result = 6'd6; // operand2=3
        7'b010_0100: result = 6'd8; // operand2=4
        7'b010_0101: result = 6'd10; // operand2=5
        7'b010_0110: result = 6'd12; // operand2=6
        7'b010_0111: result = 6'd14; // operand2=7
        7'b010_1000: result = 6'd16; // operand2=8
        7'b010_1001: result = 6'd18; // operand2=9
        7'b010_1010: result = 6'd20; // operand2=10
        7'b010_1011: result = 6'd22; // operand2=11
		7'b010_1100: result = 6'd24; // operand2=12
		7'b010_1101: result = 6'd26; // operand2=13
		7'b010_1110: result = 6'd28; // operand2=14
		7'b010_1111: result = 6'd30; // operand2=15
        // operand1=3 的情况
		7'b011_0000: result = 6'd0; // operand2=0
		7'b011_0001: result = 6'd3; // operand2=1
		7'b011_0010: result = 6'd6; // operand2=2
		7'b011_0011: result = 6'd9; // operand2=3
		7'b011_0100: result = 6'd12; // operand2=4
		7'b011_0101: result = 6'd15; // operand2=5
		7'b011_0110: result = 6'd18; // operand2=6
		7'b011_0111: result = 6'd21; // operand2=7
		7'b011_1000: result = 6'd24; // operand2=8
		7'b011_1001: result = 6'd27; // operand2=9
		7'b011_1010: result = 6'd30; // operand2=10
		7'b011_1011: result = 6'd33; // operand2=11
		7'b011_1100: result = 6'd36; // operand2=12
		7'b011_1101: result = 6'd39; // operand2=13
		7'b011_1110: result = 6'd42; // operand2=14
		7'b011_1111: result = 6'd45; // operand2=15
		// operand1=4 的情况
		7'b100_0000: result = 6'd0; // operand2=0
		7'b100_0001: result = 6'd4; // operand2=1
		7'b100_0010: result = 6'd8; // operand2=2
		7'b100_0011: result = 6'd12; // operand2=3
		7'b100_0100: result = 6'd16; // operand2=4
		7'b100_0101: result = 6'd20; // operand2=5
		7'b100_0110: result = 6'd24; // operand2=6
		7'b100_0111: result = 6'd28; // operand2=7
		7'b100_1000: result = 6'd32; // operand2=8
		7'b100_1001: result = 6'd36; // operand2=9
		7'b100_1010: result = 6'd40; // operand2=10
		7'b100_1011: result = 6'd44; // operand2=11
		7'b100_1100: result = 6'd48; // operand2=12
		7'b100_1101: result = 6'd52; // operand2=13
		7'b100_1110: result = 6'd56; // operand2=14
		7'b100_1111: result = 6'd60; // operand2=15
		// operand1=5 的情况
		7'b101_0000: result = 6'd0; // operand2=0
		7'b101_0001: result = 6'd5; // operand2=1
		7'b101_0010: result = 6'd10; // operand2=2
		7'b101_0011: result = 6'd15; // operand2=3
		7'b101_0100: result = 6'd20; // operand2=4
		7'b101_0101: result = 6'd25; // operand2=5
		7'b101_0110: result = 6'd30; // operand2=6
		7'b101_0111: result = 6'd35; // operand2=7
		7'b101_1000: result = 6'd40; // operand2=8
		7'b101_1001: result = 6'd45; // operand2=9
		7'b101_1010: result = 6'd50; // operand2=10
		7'b101_1011: result = 6'd55; // operand2=11
		7'b101_1100: result = 6'd60; // operand2=12
		7'b101_1101: result = 6'd65; // operand2=13
		7'b101_1110: result = 6'd70; // operand2=14
		7'b101_1111: result = 6'd75; // operand2=15
		// operand1=6 的情况
		7'b110_0000: result = 6'd0; // operand2=0
		7'b110_0001: result = 6'd6; // operand2=1
		7'b110_0010: result = 6'd12; // operand2=2
		7'b110_0011: result = 6'd18; // operand2=3
		7'b110_0100: result = 6'd24; // operand2=4
		7'b110_0101: result = 6'd30; // operand2=5
		7'b110_0110: result = 6'd36; // operand2=6
		7'b110_0111: result = 6'd42; // operand2=7
		7'b110_1000: result = 6'd48; // operand2=8
		7'b110_1001: result = 6'd54; // operand2=9
		7'b110_1010: result = 6'd60; // operand2=10
		7'b110_1011: result = 6'd66; // operand2=11
		7'b110_1100: result = 6'd72; // operand2=12
		7'b110_1101: result = 6'd78; // operand2=13
		7'b110_1110: result = 6'd84; // operand2=14
		7'b110_1111: result = 6'd90; // operand2=15
		// operand1=7 的情况
		7'b111_0000: result = 6'd0; // operand2=0
		7'b111_0001: result = 6'd7; // operand2=1
		7'b111_0010: result = 6'd14; // operand2=2
		7'b111_0011: result = 6'd21; // operand2=3
		7'b111_0100: result = 6'd28; // operand2=4
		7'b111_0101: result = 6'd35; // operand2=5
		7'b111_0110: result = 6'd42; // operand2=6
		7'b111_0111: result = 6'd49; // operand2=7
		7'b111_1000: result = 6'd56; // operand2=8
		7'b111_1001: result = 6'd63; // operand2=9
		7'b111_1010: result = 6'd70; // operand2=10
		7'b111_1011: result = 6'd77; // operand2=11
		7'b111_1100: result = 6'd84; // operand2=12
		7'b111_1101: result = 6'd91; // operand2=13
		7'b111_1110: result = 6'd98; // operand2=14
		7'b111_1111: result = 6'd105; // operand2=15
	endcase

end

endmodule

