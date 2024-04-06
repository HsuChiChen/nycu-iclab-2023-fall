//############################################################################
//   2023 ICLAB Fall Course
//   Lab01       : Supper MOSFET Calculator(SMC)
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.09.22
//   Version     : v2.0
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
// output [7:0] out_n;         					// use this if using continuous assignment for out_n  // Ex: assign out_n = XXX;
output reg [7:0] out_n; 								// use this if using procedure assignment for out_n   // Ex: always@(*) begin out_n = XXX; end

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment
wire [6:0] Id_gm_0, Id_gm_1, Id_gm_2, Id_gm_3, Id_gm_4, Id_gm_5;
wire [6:0] n_0, n_1, n_2, n_3, n_4, n_5;

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

/*biwise inverse*/
wire  [6:0] ld_gm_0_temp, ld_gm_1_temp, ld_gm_2_temp, ld_gm_3_temp, ld_gm_4_temp, ld_gm_5_temp;
wire  [6:0] mode_1_expansion;

assign mode_1_expansion = {7{~mode[1]}};
assign ld_gm_0_temp = Id_gm_0 ^ mode_1_expansion;
assign ld_gm_1_temp = Id_gm_1 ^ mode_1_expansion;
assign ld_gm_2_temp = Id_gm_2 ^ mode_1_expansion;
assign ld_gm_3_temp = Id_gm_3 ^ mode_1_expansion;
assign ld_gm_4_temp = Id_gm_4 ^ mode_1_expansion;
assign ld_gm_5_temp = Id_gm_5 ^ mode_1_expansion;

/*Sort*/
wire [6:0] max1_temp, max2_temp, max3_temp;

SELECT_MAX_3 s0(.n0(ld_gm_0_temp), .n1(ld_gm_1_temp), .n2(ld_gm_2_temp), .n3(ld_gm_3_temp), .n4(ld_gm_4_temp), .n5(ld_gm_5_temp), .result0(max1_temp), .result1(max2_temp), .result2(max3_temp));

/*biwise inverse*/
wire [6:0] max1_t, max2_t, max3_t;
reg [6:0] max1, max3;

assign max1_t = max1_temp ^ mode_1_expansion;
assign max2_t = max2_temp ^ mode_1_expansion;
assign max3_t = max3_temp ^ mode_1_expansion;

always @(*) begin
	if(mode[1]) begin
		max1 = max1_t;
		max3 = max3_t;
	end
	else begin
		max1 = max3_t;
		max3 = max1_t;
	end
end

/*Select according to mode*/
// area 69125
// wire [9:0] out_n_temp;
// wire [8:0] out_n_temp_div3;

// assign out_n_temp = (mode[0])? (3 * max1 + 4 * max2_t + 5 * max3) : (max1 + max2_t + max3);
// assign out_n_temp_div3 = out_n_temp / 3;

// /*Output*/
// assign out_n = (mode[0])? (out_n_temp_div3 >> 2) : out_n_temp_div3;

// area 66737
assign out_n = (mode[0])? (3 * max1 + 4 * max2_t + 5 * max3) / 12 : (max1 + max2_t + max3) / 3;

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
// mode 0: gm
// mode 1: Id

output reg [6:0] Id_gm;

wire operation_mode;
wire [1:0] calculate_mode;
wire [2:0] V_GS_minus1;
wire [6:0] w_mul_V_GS_minus1;
wire [6:0] w_mul_V_DS;
reg [8:0] Id_gm_temp;


assign operation_mode = (V_GS - 3'b1 > V_DS) ? 1 : 0;
// operation_mode 0: saturation region
// operation_mode 1: triode region
assign V_GS_minus1 = V_GS - 1;
assign calculate_mode = {mode0, operation_mode};
assign w_mul_V_GS_minus1 = W * V_GS_minus1;
assign w_mul_V_DS = W * V_DS;

always @(*) begin
  case(calculate_mode)
    2'b00: Id_gm_temp = 2 * w_mul_V_GS_minus1;
    2'b01: Id_gm_temp = 2 * w_mul_V_DS;
    2'b10: Id_gm_temp = w_mul_V_GS_minus1 * V_GS_minus1;
    2'b11: Id_gm_temp = w_mul_V_DS * (2 * V_GS_minus1 - V_DS);
  endcase
end

assign Id_gm = Id_gm_temp / 3;

endmodule


module SELECT_MAX_3 (n0, n1, n2, n3, n4, n5, result0, result1, result2);

input	[6:0]	n0, n1, n2, n3, n4, n5;
output	[6:0]	result0, result1, result2;

reg		[6:0]	temp_max1, temp_max2;
reg		[6:0]	temp_max1_1, temp_max2_1, temp_max3_1;
wire	[6:0]	wtemp_max1, wtemp_max2, wtemp_max3;
wire	[6:0]	temp_max1_2, temp_max2_2, temp_max3_2;
wire	[6:0]	temp_max1_3, temp_max2_3, temp_max3_3;
wire	[6:0]	temp_max1_4, temp_max2_4, temp_max3_4;

always @(*)
begin
	if (n0 > n1)
	begin
		temp_max1 = n0;
		temp_max2 = n1;
	end
	else
	begin
		temp_max1 = n1;
		temp_max2 = n0;
	end


	if (n2 > temp_max2)
	begin
		if (n2 > temp_max1)
		begin
			temp_max3_1 = temp_max2;
			temp_max2_1 = temp_max1;
			temp_max1_1 = n2;
		end
		else
		begin
			temp_max3_1 = temp_max2;
			temp_max2_1 = n2;
			temp_max1_1 = temp_max1;
		end
	end
	else
	begin
		temp_max3_1 = n2;
		temp_max2_1 = temp_max2;
		temp_max1_1 = temp_max1;
	end
end

INSERT_GROUP I1 (.n(n3), .temp_max1(temp_max1_1), .temp_max2(temp_max2_1), .temp_max3(temp_max3_1), .result1(temp_max1_2), .result2(temp_max2_2), .result3(temp_max3_2));
INSERT_GROUP I2 (.n(n4), .temp_max1(temp_max1_2), .temp_max2(temp_max2_2), .temp_max3(temp_max3_2), .result1(temp_max1_3), .result2(temp_max2_3), .result3(temp_max3_3));
INSERT_GROUP I3 (.n(n5), .temp_max1(temp_max1_3), .temp_max2(temp_max2_3), .temp_max3(temp_max3_3), .result1(result0), .result2(result1), .result3(result2));

endmodule

module INSERT_GROUP (n, temp_max1, temp_max2, temp_max3, result1, result2, result3);

input		[6:0]	n, temp_max1, temp_max2, temp_max3;
output	reg	[6:0]	result1, result2, result3;
//reg			[2:0]	big_mode;

always @(*)
begin
	result1 = temp_max1;
	result2 = temp_max2;
	result3 = temp_max3;

	if (n > temp_max3)
	begin
		if (n > temp_max2)
		begin
			if (n > temp_max1)
			begin
				result3 = temp_max2;
				result2 = temp_max1;
				result1 = n;
			end
			else
			begin
				result3 = temp_max2;
				result2 = n;
			end
		end
		else
			result3 = n;
	end
end

endmodule

// module BBQ (meat,vagetable,water,cost);
// input XXX;
// output XXX;
// 
// endmodule

// --------------------------------------------------
// Example for using submodule 
// BBQ bbq0(.meat(meat_0), .vagetable(vagetable_0), .water(water_0), .cost(cost[0]));
// --------------------------------------------------
// Example for continuous assignment
// assign out_n = XXX;
// --------------------------------------------------
// Example for procedure assignment
// always@(*) begin 
// 	out_n = XXX; 
// end
// --------------------------------------------------
// Example for case statement
// always @(*) begin
// 	case(op)
// 		2'b00: output_reg = a + b;
// 		2'b10: output_reg = a - b;
// 		2'b01: output_reg = a * b;
// 		2'b11: output_reg = a / b;
// 		default: output_reg = 0;
// 	endcase
// end
// --------------------------------------------------
