//############################################################################
//   2023 ICLAB Fall Course
//   Lab01       : Supper MOSFET Calculator(SMC)
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.09.22
//   Version     : v6.0
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
wire [6:0] Id_gm_0, Id_gm_1, Id_gm_2, Id_gm_3, Id_gm_4, Id_gm_5;
wire [6:0] max0, max1, max2, max3, max4, max5;
reg  [6:0] result0, result1, result2;

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

assign out_n = (mode[0])? (3 * result0 + 4 * result1 + 5 * result2) / 12 : (result0 + result1 + result2) / 3;

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
output [6:0] Id_gm;

wire [2:0] V_GS_minus1;
reg [5:0] Id_gm_temp;

assign V_GS_minus1 = V_GS - 3'b1;

// (V_GS - 3'b1 > V_DS) ?
// truth : triode region
// false : saturation region

// mode0 == 1 : Id
// mode0 == 0 : gm
always @(*) begin
	if(mode0) begin
		if(V_GS_minus1 > V_DS) begin
			Id_gm_temp = V_DS * (2 * V_GS_minus1 - V_DS);
		end
		else begin
			Id_gm_temp = V_GS_minus1 * V_GS_minus1;
		end
	end
	else begin
		if(V_GS_minus1 > V_DS) begin
			Id_gm_temp = 2 * V_DS;
		end
		else begin
			Id_gm_temp = 2 * V_GS_minus1;
		end
	end
end

assign Id_gm = W * Id_gm_temp / 3;

endmodule

// sort
module SORT (unsorted0, unsorted1, unsorted2, unsorted3, unsorted4, unsorted5, max0, max1, max2, max3, max4, max5);
	input [6:0] unsorted0, unsorted1, unsorted2, unsorted3, unsorted4, unsorted5;
	output reg [6:0] max0, max1, max2, max3, max4, max5;

	reg [6:0] layer1_0, layer1_1, layer1_2, layer1_3, layer1_4, layer1_5;
	reg [6:0] layer2_0, layer2_1, layer2_2, layer2_3, layer2_4, layer2_5;
	reg [6:0]           layer3_1, layer3_2, layer3_3, layer3_4          ;
	reg [6:0]                     layer4_2, layer4_3                    ;

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