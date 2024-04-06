//############################################################################
//   2023 ICLAB Fall Course
//   Lab01       : Supper MOSFET Calculator(SMC)
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.09.24
//   Version     : v12.0
//   File Name   : SMC.v
//   Module Name : SMC
//############################################################################

// calculate the Id or gm of 6 MOSFETs and output the weighted average or average of the top 3 or bottom 3 MOSFETs
// operation 1 - calculate the Id or gm of 6 MOSFETs
// operation 2 - sort the Id or gm in descending order
// operation 3 - select the top 3 or bottom 3 Id or gm according to mode
module SMC(
	// Input Ports
	mode,
	W_0, V_GS_0, V_DS_0,
	W_1, V_GS_1, V_DS_1,
	W_2, V_GS_2, V_DS_2,
	W_3, V_GS_3, V_DS_3,
	W_4, V_GS_4, V_DS_4,
	W_5, V_GS_5, V_DS_5,
	// Output Ports
	out_n
);

//==============================================//
//          Input & Output Declaration          //
//==============================================//
input [2:0] W_0, V_GS_0, V_DS_0;
input [2:0] W_1, V_GS_1, V_DS_1;
input [2:0] W_2, V_GS_2, V_DS_2;
input [2:0] W_3, V_GS_3, V_DS_3;
input [2:0] W_4, V_GS_4, V_DS_4;
input [2:0] W_5, V_GS_5, V_DS_5;
input [1:0] mode;
output [7:0] out_n;         // use this if using continuous assignment for out_n  // Ex: assign out_n = XXX;
// output reg [7:0] out_n; 	// use this if using procedure assignment for out_n   // Ex: always@(*) begin out_n = XXX; end

//==============================================//
//         Wire & Register Declaration          //
//==============================================//
// Declare the wire/reg you would use in your circuit
// wire for port connection and cont. assignment
// reg for proc. assignment
wire [7:0] Id_gm_0, Id_gm_1, Id_gm_2, Id_gm_3, Id_gm_4, Id_gm_5;
wire [7:0] max0, max1, max2, max3, max4, max5;
reg  [7:0] result0, result1, result2;
reg  [6:0] result0_div3, result1_div3, result2_div3;
wire [7:0] out_n_temp;
wire [6:0] out_n_temp2;

//==============================================//
//           Callculate Id or gm                //
//==============================================//
// Callculate 6 Id or gm given W, V_GS, V_DS
CALCULATOR c0(.W(W_0), .V_GS(V_GS_0), .V_DS(V_DS_0), .mode0(mode[0]), .Id_gm(Id_gm_0));
CALCULATOR c1(.W(W_1), .V_GS(V_GS_1), .V_DS(V_DS_1), .mode0(mode[0]), .Id_gm(Id_gm_1));
CALCULATOR c2(.W(W_2), .V_GS(V_GS_2), .V_DS(V_DS_2), .mode0(mode[0]), .Id_gm(Id_gm_2));
CALCULATOR c3(.W(W_3), .V_GS(V_GS_3), .V_DS(V_DS_3), .mode0(mode[0]), .Id_gm(Id_gm_3));
CALCULATOR c4(.W(W_4), .V_GS(V_GS_4), .V_DS(V_DS_4), .mode0(mode[0]), .Id_gm(Id_gm_4));
CALCULATOR c5(.W(W_5), .V_GS(V_GS_5), .V_DS(V_DS_5), .mode0(mode[0]), .Id_gm(Id_gm_5));

// In mode[0] == 1, (Weighted Average)
// Larger:  I_avg = (3*n0 + 4*n1 + 5*n2) / 12 (mode[1] = 0)
// Smaller: I_avg = (3*n3 + 4*n4 + 5*n5) / 12 (mode[1] = 1)

// In mode[0] == 0, (Average)
// Larger:  I_avg = (n0 + n1 + n2) / 3 (mode[1] = 0)
// Smaller: I_avg = (n3 + n4 + n5) / 3 (mode[1] = 1)

// Sort the Id or gm in descending order
SORT s0(.unsorted0(Id_gm_0), .unsorted1(Id_gm_1), .unsorted2(Id_gm_2), .unsorted3(Id_gm_3), .unsorted4(Id_gm_4), .unsorted5(Id_gm_5), .max0(max0), .max1(max1), .max2(max2), .max3(max3), .max4(max4), .max5(max5));

// select top 3 or bottom 3 Id or gm according to mode
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

// divide the result by 3 in previous current calculation
DIVISION3_TABLE d0(.operand(result0), .result(result0_div3));
DIVISION3_TABLE d1(.operand(result1), .result(result1_div3));
DIVISION3_TABLE d2(.operand(result2), .result(result2_div3));

// weighted average or average
assign out_n_temp = (mode[0])? (3 * result0_div3 + 4 * result1_div3 + 5 * result2_div3) / 4  : (result0_div3 + result1_div3 + result2_div3);
// divide the result by 3
DIVISION3_TABLE d3(.operand(out_n_temp), .result(out_n_temp2));
// concatenate the result with 1'b0
assign out_n = {1'b0, out_n_temp2};

endmodule

//==============================================//
//            Calculate Id or gm                //
//==============================================//
module CALCULATOR(
  // Input Ports
    W, V_GS, V_DS, mode0,
  // Output Ports
    Id_gm
);

input [2:0] W, V_GS, V_DS;
input mode0;
output [7:0] Id_gm;

wire [2:0] V_GS_minus1;
reg [5:0] mul_result;
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

multiplication_table m0(.operand1(operand1), .operand2(operand2), .result(mul_result));
assign Id_gm_temp = (mode0)? mul_result : 2 * operand1;
assign Id_gm = W * Id_gm_temp;

endmodule

//==============================================//
//			6-input Sorting Network				//
//==============================================//
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

//==============================================//
//         3-bit x 4-bit Multiplication         //
//==============================================//
module multiplication_table(
    input [2:0] operand1, // 3-bit input, range 0~6
    input [3:0] operand2, // 4-bit input, range 0~11
    output reg [5:0] result // 6-bit output
);

always @(*) begin
    case({operand1, operand2})
        // operand1=0
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
        // operand1=1
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
        // operand1=2
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
        // operand1=3
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
		// operand1=4
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
		// operand1=5
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
		7'b101_1101: result = 6'd01; // operand2=13
		7'b101_1110: result = 6'd06; // operand2=14
		7'b101_1111: result = 6'd11; // operand2=15
		// operand1=6
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
		7'b110_1011: result = 6'd02; // operand2=11
		7'b110_1100: result = 6'd08; // operand2=12
		7'b110_1101: result = 6'd14; // operand2=13
		7'b110_1110: result = 6'd20; // operand2=14
		7'b110_1111: result = 6'd26; // operand2=15
		// operand1=7
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
		7'b111_1010: result = 6'd06; // operand2=10
		7'b111_1011: result = 6'd13; // operand2=11
		7'b111_1100: result = 6'd20; // operand2=12
		7'b111_1101: result = 6'd27; // operand2=13
		7'b111_1110: result = 6'd34; // operand2=14
		7'b111_1111: result = 6'd41; // operand2=15
	endcase
end

endmodule

//==============================================//
//         8-bit Division by 3 Table            //
//==============================================//
module DIVISION3_TABLE(
	input [7:0] operand,
	output reg [6:0] result
);

always @(*) begin
	case(operand)
		8'd0: result = 7'd0;
		8'd1: result = 7'd0;
		8'd2: result = 7'd0;
		8'd3: result = 7'd1;
		8'd4: result = 7'd1;
		8'd5: result = 7'd1;
		8'd6: result = 7'd2;
		8'd7: result = 7'd2;
		8'd8: result = 7'd2;
		8'd9: result = 7'd3;
		8'd10: result = 7'd3;
		8'd11: result = 7'd3;
		8'd12: result = 7'd4;
		8'd13: result = 7'd4;
		8'd14: result = 7'd4;
		8'd15: result = 7'd5;
		8'd16: result = 7'd5;
		8'd17: result = 7'd5;
		8'd18: result = 7'd6;
		8'd19: result = 7'd6;
		8'd20: result = 7'd6;
		8'd21: result = 7'd7;
		8'd22: result = 7'd7;
		8'd23: result = 7'd7;
		8'd24: result = 7'd8;
		8'd25: result = 7'd8;
		8'd26: result = 7'd8;
		8'd27: result = 7'd9;
		8'd28: result = 7'd9;
		8'd29: result = 7'd9;
		8'd30: result = 7'd10;
		8'd31: result = 7'd10;
		8'd32: result = 7'd10;
		8'd33: result = 7'd11;
		8'd34: result = 7'd11;
		8'd35: result = 7'd11;
		8'd36: result = 7'd12;
		8'd37: result = 7'd12;
		8'd38: result = 7'd12;
		8'd39: result = 7'd13;
		8'd40: result = 7'd13;
		8'd41: result = 7'd13;
		8'd42: result = 7'd14;
		8'd43: result = 7'd14;
		8'd44: result = 7'd14;
		8'd45: result = 7'd15;
		8'd46: result = 7'd15;
		8'd47: result = 7'd15;
		8'd48: result = 7'd16;
		8'd49: result = 7'd16;
		8'd50: result = 7'd16;
		8'd51: result = 7'd17;
		8'd52: result = 7'd17;
		8'd53: result = 7'd17;
		8'd54: result = 7'd18;
		8'd55: result = 7'd18;
		8'd56: result = 7'd18;
		8'd57: result = 7'd19;
		8'd58: result = 7'd19;
		8'd59: result = 7'd19;
		8'd60: result = 7'd20;
		8'd61: result = 7'd20;
		8'd62: result = 7'd20;
		8'd63: result = 7'd21;
		8'd64: result = 7'd21;
		8'd65: result = 7'd21;
		8'd66: result = 7'd22;
		8'd67: result = 7'd22;
		8'd68: result = 7'd22;
		8'd69: result = 7'd23;
		8'd70: result = 7'd23;
		8'd71: result = 7'd23;
		8'd72: result = 7'd24;
		8'd73: result = 7'd24;
		8'd74: result = 7'd24;
		8'd75: result = 7'd25;
		8'd76: result = 7'd25;
		8'd77: result = 7'd25;
		8'd78: result = 7'd26;
		8'd79: result = 7'd26;
		8'd80: result = 7'd26;
		8'd81: result = 7'd27;
		8'd82: result = 7'd27;
		8'd83: result = 7'd27;
		8'd84: result = 7'd28;
		8'd85: result = 7'd28;
		8'd86: result = 7'd28;
		8'd87: result = 7'd29;
		8'd88: result = 7'd29;
		8'd89: result = 7'd29;
		8'd90: result = 7'd30;
		8'd91: result = 7'd30;
		8'd92: result = 7'd30;
		8'd93: result = 7'd31;
		8'd94: result = 7'd31;
		8'd95: result = 7'd31;
		8'd96: result = 7'd32;
		8'd97: result = 7'd32;
		8'd98: result = 7'd32;
		8'd99: result = 7'd33;
		8'd100: result = 7'd33;
		8'd101: result = 7'd33;
		8'd102: result = 7'd34;
		8'd103: result = 7'd34;
		8'd104: result = 7'd34;
		8'd105: result = 7'd35;
		8'd106: result = 7'd35;
		8'd107: result = 7'd35;
		8'd108: result = 7'd36;
		8'd109: result = 7'd36;
		8'd110: result = 7'd36;
		8'd111: result = 7'd37;
		8'd112: result = 7'd37;
		8'd113: result = 7'd37;
		8'd114: result = 7'd38;
		8'd115: result = 7'd38;
		8'd116: result = 7'd38;
		8'd117: result = 7'd39;
		8'd118: result = 7'd39;
		8'd119: result = 7'd39;
		8'd120: result = 7'd40;
		8'd121: result = 7'd40;
		8'd122: result = 7'd40;
		8'd123: result = 7'd41;
		8'd124: result = 7'd41;
		8'd125: result = 7'd41;
		8'd126: result = 7'd42;
		8'd127: result = 7'd42;
		8'd128: result = 7'd42;
		8'd129: result = 7'd43;
		8'd130: result = 7'd43;
		8'd131: result = 7'd43;
		8'd132: result = 7'd44;
		8'd133: result = 7'd44;
		8'd134: result = 7'd44;
		8'd135: result = 7'd45;
		8'd136: result = 7'd45;
		8'd137: result = 7'd45;
		8'd138: result = 7'd46;
		8'd139: result = 7'd46;
		8'd140: result = 7'd46;
		8'd141: result = 7'd47;
		8'd142: result = 7'd47;
		8'd143: result = 7'd47;
		8'd144: result = 7'd48;
		8'd145: result = 7'd48;
		8'd146: result = 7'd48;
		8'd147: result = 7'd49;
		8'd148: result = 7'd49;
		8'd149: result = 7'd49;
		8'd150: result = 7'd50;
		8'd151: result = 7'd50;
		8'd152: result = 7'd50;
		8'd153: result = 7'd51;
		8'd154: result = 7'd51;
		8'd155: result = 7'd51;
		8'd156: result = 7'd52;
		8'd157: result = 7'd52;
		8'd158: result = 7'd52;
		8'd159: result = 7'd53;
		8'd160: result = 7'd53;
		8'd161: result = 7'd53;
		8'd162: result = 7'd54;
		8'd163: result = 7'd54;
		8'd164: result = 7'd54;
		8'd165: result = 7'd55;
		8'd166: result = 7'd55;
		8'd167: result = 7'd55;
		8'd168: result = 7'd56;
		8'd169: result = 7'd56;
		8'd170: result = 7'd56;
		8'd171: result = 7'd57;
		8'd172: result = 7'd57;
		8'd173: result = 7'd57;
		8'd174: result = 7'd58;
		8'd175: result = 7'd58;
		8'd176: result = 7'd58;
		8'd177: result = 7'd59;
		8'd178: result = 7'd59;
		8'd179: result = 7'd59;
		8'd180: result = 7'd60;
		8'd181: result = 7'd60;
		8'd182: result = 7'd60;
		8'd183: result = 7'd61;
		8'd184: result = 7'd61;
		8'd185: result = 7'd61;
		8'd186: result = 7'd62;
		8'd187: result = 7'd62;
		8'd188: result = 7'd62;
		8'd189: result = 7'd63;
		8'd190: result = 7'd63;
		8'd191: result = 7'd63;
		8'd192: result = 7'd64;
		8'd193: result = 7'd64;
		8'd194: result = 7'd64;
		8'd195: result = 7'd65;
		8'd196: result = 7'd65;
		8'd197: result = 7'd65;
		8'd198: result = 7'd66;
		8'd199: result = 7'd66;
		8'd200: result = 7'd66;
		8'd201: result = 7'd67;
		8'd202: result = 7'd67;
		8'd203: result = 7'd67;
		8'd204: result = 7'd68;
		8'd205: result = 7'd68;
		8'd206: result = 7'd68;
		8'd207: result = 7'd69;
		8'd208: result = 7'd69;
		8'd209: result = 7'd69;
		8'd210: result = 7'd70;
		8'd211: result = 7'd70;
		8'd212: result = 7'd70;
		8'd213: result = 7'd71;
		8'd214: result = 7'd71;
		8'd215: result = 7'd71;
		8'd216: result = 7'd72;
		8'd217: result = 7'd72;
		8'd218: result = 7'd72;
		8'd219: result = 7'd73;
		8'd220: result = 7'd73;
		8'd221: result = 7'd73;
		8'd222: result = 7'd74;
		8'd223: result = 7'd74;
		8'd224: result = 7'd74;
		8'd225: result = 7'd75;
		8'd226: result = 7'd75;
		8'd227: result = 7'd75;
		8'd228: result = 7'd76;
		8'd229: result = 7'd76;
		8'd230: result = 7'd76;
		8'd231: result = 7'd77;
		8'd232: result = 7'd77;
		8'd233: result = 7'd77;
		8'd234: result = 7'd78;
		8'd235: result = 7'd78;
		8'd236: result = 7'd78;
		8'd237: result = 7'd79;
		8'd238: result = 7'd79;
		8'd239: result = 7'd79;
		8'd240: result = 7'd80;
		8'd241: result = 7'd80;
		8'd242: result = 7'd80;
		8'd243: result = 7'd81;
		8'd244: result = 7'd81;
		8'd245: result = 7'd81;
		8'd246: result = 7'd82;
		8'd247: result = 7'd82;
		8'd248: result = 7'd82;
		8'd249: result = 7'd83;
		8'd250: result = 7'd83;
		8'd251: result = 7'd83;
		8'd252: result = 7'd84;
		8'd253: result = 7'd84;
		8'd254: result = 7'd84;
		8'd255: result = 7'd85;
	endcase
end

endmodule