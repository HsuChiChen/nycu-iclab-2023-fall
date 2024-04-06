//############################################################################
//   2023 ICLAB Fall Course
//   Lab02       : Calculation on the coordinates
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.09.29
//   Version     : v1.0
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
input       [1:0]   mode;
input       [7:0]   xi, yi;  

output reg          out_valid;
output reg  [7:0]   xo, yo;

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter   IDLE           = 3'd0,
            READ           = 3'd1,
            MODE0_RIGHT    = 3'd2,
            MODE0_END      = 3'd3,
            MODE1_CALC     = 3'd4,
            MODE2_CALC     = 3'd6;

//==============================================//
//            FSM State Declaration             //
//==============================================//
reg [2:0] current_state, next_state;
reg [1:0] counter;
reg signed [8:0] layer;
reg signed [7:0] current_x;

//==============================================//
//                 reg declaration              //
//==============================================//
// mode0
reg signed [7:0] x[0:3], y[0:3];
reg signed [7:0] begin_point, end_point;

// mode1
wire signed [11:0] a, b, c;
reg [1:0] relationships;
wire signed [24:0] LHS, RHS;

// mode2
wire signed [15:0] directed_area;
wire [15:0] area;

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
                    2'b00: next_state = MODE0_RIGHT;
                    2'b01: next_state = MODE1_CALC;
                    2'b10: next_state = MODE2_CALC;
                    default: next_state = IDLE; // illegal mode
                endcase
            end
            else begin
                next_state = READ; // counter != 4
            end
        end
        MODE0_RIGHT: begin
            if(current_x + 1 == end_point) next_state = MODE0_END;
            else next_state = MODE0_RIGHT;
        end

        MODE0_END: begin
            if(layer + y[3] == y[1]) next_state = IDLE;
            else next_state = MODE0_RIGHT;
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

// layer
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) layer <= 0;
    else if(current_state == MODE0_END) layer <= layer + 1;
    else if(current_state == IDLE) layer <= 0;
end

// current_x
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) current_x <= 0;
    else if(current_state == READ || current_state == MODE0_END) current_x <= begin_point;
    else if(current_state == MODE0_RIGHT) current_x <= current_x + 1;
    else if(current_state == IDLE) current_x <= 0;
end


// out_valid
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 0;
    else if(current_state == MODE0_RIGHT || current_state == MODE0_END || current_state == MODE1_CALC || current_state == MODE2_CALC) out_valid <= 1;
    else out_valid <= 0;
end

// xo, yo
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        xo <= 8'd0;
        yo <= 8'd0;
    end else begin
        if (current_state == MODE0_RIGHT || current_state == MODE0_END) begin
            xo <= current_x;
            yo <= layer + y[2];
        end else if (current_state == MODE1_CALC) begin
            xo <= 8'd0;
            yo <= {6'd0, relationships};
        end else if (current_state == MODE2_CALC) begin
            xo <= area[15:8];
            yo <= area[7:0];
        end
    end
end


//==============================================//
//        combinational logic of mode0          //
//==============================================//
always @(*) begin
    // positive slope
    if(x[0] > x[2]) begin
        // begin_point = x[2] + (x[0] - x[2]) * layer / (y[0] - y[2]);
        begin_point = x[2] + (x[0] - x[2]) * (layer + 1) / (y[0] - y[2]);
    end
    // negative slope
    else begin
        // top layer
        if(layer + y[2] == y[0]) begin
            begin_point = x[0];
        end
        else begin
            // if a is negetive and b is positive, $floor(a / b) = (a - b + 1) / b
            begin_point = x[2] + ( (x[0] - x[2]) * (layer + 1) - (y[0] - y[2]) + 1 ) / (y[0] - y[2]);
        end
    end
end


always @(*) begin
    // negative slope
    if(x[1] < x[3]) begin
        // if a is negetive and b is positive, $floor(a / b) = (a - b + 1) / b     
        end_point = x[3] + ( (x[1] - x[3]) * layer - (y[1] - y[3]) + 1 ) / (y[1] - y[3]);
    end
    // positive slope
    else begin
        // top layer
        if(layer + y[3] == y[1]) begin
            end_point = x[1];
        end
        else begin
            // if a is positive and b is positive, $ceiling(a / b) = (a + b - 1) / b
            end_point = x[3] + ( (x[1] - x[3]) * (layer + 1) + (y[1] - y[3]) - 1 ) / (y[1] - y[3]) - 1;
        end
    end
end

//==============================================//
//        combinational logic of mode1          //
//==============================================//
// Standard Form of Equation of a Line : ax + bx + c = 0
assign a = y[0] - y[1];
assign b = x[1] - x[0];
assign c = x[0] * y[1] - x[1] * y[0];
// wire signed [10:0] test1, test2;
// assign test1 = x[0] * y[1];
// assign test2 = x[1] * y[0];

// circle center (x[2], y[2])
// a point on circle (x[3], y[3])
// Standard Form of Equation of a Circle : (x - h)^2 + (y - k)^2 = r^2
// The relationships between circles and lines can be categorized into three types:
// (1) non-intersecting, (2) intersecting, (3) tangent 

assign LHS = (a * x[2] + b * y[2] + c) * (a * x[2] + b * y[2] + c);
assign RHS = (a * a + b * b) * ((x[2] - x[3]) * (x[2] - x[3]) + (y[2] - y[3]) * (y[2] - y[3]));
always @(*) begin
    if(LHS > RHS) relationships = 2'b00; // relationships 0 : non-intersecting
    else if(LHS < RHS) relationships = 2'b01; // relationships 1 : intersecting
    else relationships = 2'b10; // relationships 2 : tangent
end

//==============================================//
//        combinational logic of mode2          //
//==============================================//
// Area Of Quadrilateral
assign directed_area = ((x[0] * y[1] - x[1] * y[0]) + (x[1] * y[2] - x[2] * y[1]) + (x[2] * y[3] - x[3] * y[2]) + (x[3] * y[0] - x[0] * y[3])) / 2;
assign area = (directed_area[15]) ? ~directed_area + 1 : directed_area;

endmodule