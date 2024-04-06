//############################################################################
//   2023 ICLAB Fall Course
//   Lab02       : Calculation on the coordinates
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.10.02
//   Version     : v6.0
//   File Name   : CC.v
//   Module Name : CC
//############################################################################

module CC(
    // Input Ports
    clk,
    rst_n,
	in_valid,
	mode,
    xi,
    yi,

    // Output Ports
    out_valid,
	xo,
	yo
    );

//==============================================//
//          Input & Output Declaration          //
//==============================================//
input               clk, rst_n, in_valid;
input        [1:0]  mode;
input signed [7:0]  xi, yi;  

output reg          out_valid;
output reg  signed [7:0]   xo, yo;

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter   IDLE           = 4'd0,
            READ           = 4'd1,
            MODE1_CALC     = 4'd2,
            MODE2_CALC     = 4'd3,
            MODE0_FIRST    = 4'd4,
            MODE0_START    = 4'd5,
            MODE0_RIGHT    = 4'd6,
            MODE0_END      = 4'd7;

//==============================================//
//            FSM State Declaration             //
//==============================================//
reg [3:0] current_state, next_state;
reg [1:0] counter;

//==============================================//
//                 reg declaration              //
//==============================================//
// mode0
reg signed [7:0] x[0:3], y[0:3];
reg signed [8:0] begin_point, end_point;

reg signed [7:0] offset1;
wire signed [8:0] slope_invere1;
wire signed [8:0] candidate_offset1;
wire signed [10:0] outer_product1;
wire condition1;
wire pos1;

reg signed [7:0] offset2;
wire signed [8:0] slope_invere2;
wire signed [8:0] candidate_offset2;
wire signed [10:0] outer_product2;
wire condition2;
wire pos2;

// mode1
wire signed [6:0] a;
wire signed [6:0] b;
wire signed [11:0] c;
reg [1:0] relationships;
wire signed [40:0] LHS, RHS;
wire signed [12:0] LHS_ROOT;

// mode2
wire signed [16:0] directed_area;
wire [16:0] area;

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
    case(current_state)
        IDLE: begin
            if(in_valid) next_state = READ;
            else next_state = IDLE;
        end
        READ: begin
            if(counter == 3) begin
                case(mode)
                    2'b00: next_state = MODE0_FIRST;
                    2'b01: next_state = MODE1_CALC;
                    2'b10: next_state = MODE2_CALC;
                    default: next_state = IDLE; // illegal mode
                endcase
            end
            else begin
                next_state = READ; // counter != 3
            end
        end

        MODE0_FIRST: begin
            if(xo + 1 == end_point) next_state = MODE0_END;
            else next_state = MODE0_RIGHT;
        end

        MODE0_START: begin
            if(begin_point + offset1 + 1 == end_point) next_state = MODE0_END;
            else next_state = MODE0_RIGHT;
        end

        MODE0_RIGHT: begin
            if(xo + 2 == end_point) next_state = MODE0_END;
            else next_state = MODE0_RIGHT;
        end

        MODE0_END: begin
            if(yo == y[1]) next_state = IDLE;
            else next_state = MODE0_START;
        end

        MODE1_CALC: begin
            next_state = IDLE;
        end
        MODE2_CALC: begin
            next_state = IDLE;
        end
        default: next_state = IDLE; // illegal state
    endcase
end

// input register
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
            x[counter] <= 8'd0;
            y[counter] <= 8'd0;
    end
    else if(next_state == READ || current_state == READ) begin
        x[counter] <= xi;
        y[counter] <= yi;
    end
end

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 0;
    else if(next_state == READ || current_state == READ) counter <= counter + 1;
    else counter <= 0;
end

assign slope_invere1 = (x[0] - x[2]) / (y[0] - y[2]);
assign pos1 = (x[0] - x[2]) > 0? 1 : 0;
assign candidate_offset1 = begin_point + slope_invere1 + pos1;
assign outer_product1 = (candidate_offset1 - x[2]) * (y[0] - y[2]) - (yo + 1 - y[2]) * (x[0] - x[2]) ;
assign condition1 = outer_product1 > 0;

always @(*) begin
    // if x[0] > X[2], slope is positive
    // candidate offset = slope_invere or slope_invere + 1
    if(condition1) begin
        offset1 = slope_invere1 - 1 + pos1; // point in the scope
    end else begin
        offset1 = slope_invere1 + pos1;
    end
    // if x[0] < X[2], slope is negative
end

// wire
assign slope_invere2 = (x[1] - x[3]) / (y[1] - y[3]);
assign pos2 = (x[1] - x[3]) > 0 ? 1 : 0;
assign candidate_offset2 = end_point + slope_invere2 + pos2;
assign outer_product2 = (candidate_offset2 - x[3]) * (y[1] - y[3]) - (yo + 1 - y[3]) * (x[1] - x[3]);
assign condition2 = outer_product2 > 0;


// left side of the line

always @(*) begin
    // if x[1] > X[3], slope is positive
    // candidate offset = slope_invere or slope_invere + 1
    if(condition2) begin
        offset2 = slope_invere2 - 1 + pos2;
    end else begin
        // offset2 = slope_invere2 + 1;
        offset2 = slope_invere2 + pos2;
    end
    // if x[1] < X[3], slope is negative
end

// begin_point
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin_point <= 0;
    else if(current_state == MODE0_FIRST) begin
        begin_point <= x[2];
    end
    else if(current_state == MODE0_START) begin
        begin_point <= begin_point + offset1;
    end
end

// end_point
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) end_point <= 0;
    else if(current_state == READ) end_point <= xi; // x[3]
    else if(current_state == MODE0_END) begin
        end_point <= end_point + offset2;
        
    end
end

// out_valid
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 0;
    else if(current_state == MODE0_FIRST || current_state == MODE0_START || current_state == MODE0_RIGHT || current_state == MODE0_END || current_state == MODE1_CALC || current_state == MODE2_CALC) out_valid <= 1;
    else out_valid <= 0;
end

// xo, yo
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        xo <= 8'd0;
        yo <= 8'd0;
    end else begin
        if (counter == 3) begin
            xo <= x[2];
            yo <= y[2];
        end else if (current_state == MODE0_START) begin
            xo <= begin_point + offset1;
            yo <= yo + 1;
        end else if (current_state == MODE0_RIGHT || current_state == MODE0_END) begin
            xo <= xo + 1;
            yo <= yo;
        end else if (current_state == MODE1_CALC) begin
            xo <= 8'd0;
            yo <= {6'd0, relationships};
        end else if (current_state == MODE2_CALC) begin
            xo <= area[16:9];
            yo <= area[8:1];
        end
    end
end

//==============================================//
//                     mode1                    //
//==============================================//
// // Standard Form of Equation of a Line : ax + bx + c = 0
// assign a = y[0] - y[1];
// assign b = x[1] - x[0];
// assign c = x[0] * y[1] - x[1] * y[0];

// // circle center (x[2], y[2])
// // a point on circle (x[3], y[3])
// // Standard Form of Equation of a Circle : (x - h)^2 + (y - k)^2 = r^2
// // The relationships between circles and lines can be categorized into three types:
// // (1) non-intersecting, (2) intersecting, (3) tangent 

// assign LHS_ROOT = (a * x[2] + b * y[2] + c);
// assign LHS = LHS_ROOT * LHS_ROOT;
// assign RHS = (a * a + b * b) * ((x[2] - x[3]) * (x[2] - x[3]) + (y[2] - y[3]) * (y[2] - y[3]));
// always @(*) begin
//     if(LHS > RHS) relationships = 2'b00; // relationships 0 : non-intersecting
//     else if(LHS < RHS) relationships = 2'b01; // relationships 1 : intersecting
//     else 
//     relationships = 2'b10; // relationships 2 : tangent
// end

// define 3 multiplier to share in 3 cycle
wire signed [12:0] result_mul1;
wire signed [12:0] result_mul2;
wire signed [24:0] result_mul3;
reg signed [6:0] mul1, mul2;
reg signed [6:0] mul3, mul4;
reg signed [12:0] mul5, mul6;

assign result_mul1 = mul1 * mul2;
assign result_mul2 = mul3 * mul4;
assign result_mul3 = mul5 * mul6;

// wire
wire signed [13:0] RHS_1;
wire signed [13:0] RHS_2;

// register
reg signed [11:0] c_reg;
reg signed [13:0] RHS_1_reg;

// combination logic
// cycle 1
assign a = y[0] - y[1];
assign b = x[1] - x[0];
assign c = result_mul1 - result_mul2;

// cycle 2
assign LHS_ROOT = result_mul1 + result_mul2 + c_reg;

// cycle 3
assign LHS = result_mul3;
assign RHS_2 = result_mul1 + result_mul2;
assign RHS = RHS_1_reg * (result_mul1 + result_mul2);

// register to store between cycle
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        c_reg <= 0;
        RHS_1_reg <= 0;
    end else if(counter == 2) begin
        c_reg <= c;
        RHS_1_reg <= result_mul3;
    end else if(counter == 3) begin
        c_reg <= c_reg;
        RHS_1_reg <= RHS_1_reg + result_mul3;
    end
end

// input of multiplier in 3 different cycle
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mul1 <= 0;
        mul2 <= 0;
        mul3 <= 0;
        mul4 <= 0;
        mul5 <= 0;
        mul6 <= 0;
    end else if(counter == 1) begin
        mul1 <= x[0];
        mul2 <= yi; // y[1]
        mul3 <= xi; // x[1]
        mul4 <= y[0];
        mul5 <= y[0] - yi; // a = y[0] - y[1];
        mul6 <= y[0] - yi; // a = y[0] - y[1];
    end else if(counter == 2) begin
        mul1 <= a;
        mul2 <= xi; // x[2]
        mul3 <= b;
        mul4 <= yi; // y[2]
        mul5 <= b;
        mul6 <= b;
    end else if(counter == 3)begin
        mul1 <= x[2] - xi; // x[2] - x[3]
        mul2 <= x[2] - xi; // x[2] - x[3]
        mul3 <= y[2] - yi; // y[2] - y[3]
        mul4 <= y[2] - yi; // y[2] - y[3]
        mul5 <= LHS_ROOT;
        mul6 <= LHS_ROOT;
    end
end

// judge the relationship between circle and line
always @(*) begin
    if(LHS > RHS) relationships = 2'b00; // relationships 0 : non-intersecting
    else if(LHS < RHS) relationships = 2'b01; // relationships 1 : intersecting
    else 
    relationships = 2'b10; // relationships 2 : tangent
end

//==============================================//
//        combinational logic of mode2          //
//==============================================//
// Area Of Quadrilateral
assign directed_area = ((x[2] - x[0]) * (y[3] - y[1]) + (y[2] - y[0]) * (x[1] - x[3]));
assign area = (directed_area[16]) ? ~directed_area + 1 : directed_area;

endmodule