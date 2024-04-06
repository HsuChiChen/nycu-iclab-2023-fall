//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Siamese Neural Network
//   Author     		: Jia-Yu Lee (maggie8905121@gmail.com)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : PATTERN.v
//   Module Name : PATTERN
//   Release version : V1.0 (Release Date: 2023-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`define CYCLE_TIME      50.0
// `define SEED_NUMBER     28825252
// `define PATTERN_NUMBER 10000

module PATTERN(
    //Output Port
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel,
	Weight,
    Opt,
    //Input Port
    out_valid,
    out
);
//======================================
//      PARAMETER & INTEGER DECLARATION
//======================================
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;

//======================================
//      I/O PORTS
//======================================
output reg clk, rst_n, in_valid;
output reg [inst_sig_width+inst_exp_width:0]  Img;
output reg [inst_sig_width+inst_exp_width:0]  Kernel;
output reg [inst_sig_width+inst_exp_width:0]  Weight;
output reg [ 1:0]  Opt;
input out_valid;
input [inst_sig_width+inst_exp_width:0]  out;

//======================================
//      OTHER PARAMETERS & VARIABLES
//======================================
// User modification
parameter PATNUM = 100;
parameter PATNUM_SIMPLE = 100;
integer   SEED = 587;
// PATTERN operation
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 1000;
parameter OUT_NUM = 1;

// PATTERN CONTROL
integer stop;
integer pat;
integer exe_lat;
integer out_lat;
integer out_check_idx;
integer tot_lat;
integer input_delay;
integer each_delay;

// FILE CONTROL
integer file;
integer file_out;

// String control
// Should use %0s
reg[9*8:1]  reset_color       = "\033[1;0m";
reg[10*8:1] txt_black_prefix  = "\033[1;30m";
reg[10*8:1] txt_red_prefix    = "\033[1;31m";
reg[10*8:1] txt_green_prefix  = "\033[1;32m";
reg[10*8:1] txt_yellow_prefix = "\033[1;33m";
reg[10*8:1] txt_blue_prefix   = "\033[1;34m";

reg[10*8:1] bkg_black_prefix  = "\033[40;1m";
reg[10*8:1] bkg_red_prefix    = "\033[41;1m";
reg[10*8:1] bkg_green_prefix  = "\033[42;1m";
reg[10*8:1] bkg_yellow_prefix = "\033[43;1m";
reg[10*8:1] bkg_blue_prefix   = "\033[44;1m";
reg[10*8:1] bkg_white_prefix  = "\033[47;1m";

//======================================
//      DATA MODEL
//======================================
parameter NUM_INPUT = 2;
parameter IMAGE_NUM = 3;
parameter IMAGE_SIZE = 4;
parameter KERNEL_NUM = 3;
parameter KERNEL_SIZE = 3;
parameter WEIGHT_SIZE = 2;

// input
reg[inst_sig_width+inst_exp_width:0] _img[NUM_INPUT:1][IMAGE_NUM:1][IMAGE_SIZE-1:0][IMAGE_SIZE-1:0]; // 2 x (3 x 4 x 4)
reg[inst_sig_width+inst_exp_width:0] _kernel[KERNEL_NUM:1][KERNEL_SIZE-1:0][KERNEL_SIZE-1:0];
reg[inst_sig_width+inst_exp_width:0] _weight[WEIGHT_SIZE-1:0][WEIGHT_SIZE-1:0];
reg[1:0] _opt;
// feature map
reg[inst_sig_width+inst_exp_width:0] _pad[NUM_INPUT:1][IMAGE_NUM:1][IMAGE_SIZE+1:0][IMAGE_SIZE+1:0];
reg[inst_sig_width+inst_exp_width:0] _conv[NUM_INPUT:1][IMAGE_NUM:1][IMAGE_SIZE-1:0][IMAGE_SIZE-1:0];
reg[inst_sig_width+inst_exp_width:0] _convSum[NUM_INPUT:1][IMAGE_SIZE-1:0][IMAGE_SIZE-1:0];
reg[inst_sig_width+inst_exp_width:0] _pool[NUM_INPUT:1][IMAGE_SIZE/2-1:0][IMAGE_SIZE/2-1:0];
reg[inst_sig_width+inst_exp_width:0] _full[NUM_INPUT:1][IMAGE_SIZE-1:0]; // flatten
reg[inst_sig_width+inst_exp_width:0] _normal[NUM_INPUT:1][IMAGE_SIZE-1:0]; // flatten
reg[inst_sig_width+inst_exp_width:0] _encode[NUM_INPUT:1][IMAGE_SIZE-1:0]; // flatten
reg[inst_sig_width+inst_exp_width:0] _distance;
// wire
wire[inst_sig_width+inst_exp_width:0] _conv_w[NUM_INPUT:1][IMAGE_NUM:1][IMAGE_SIZE-1:0][IMAGE_SIZE-1:0];
wire[inst_sig_width+inst_exp_width:0] _convSum_w[NUM_INPUT:1][IMAGE_SIZE-1:0][IMAGE_SIZE-1:0];
wire[inst_sig_width+inst_exp_width:0] _pool_w[NUM_INPUT:1][IMAGE_SIZE/2-1:0][IMAGE_SIZE/2-1:0];
wire[inst_sig_width+inst_exp_width:0] _full_w[NUM_INPUT:1][IMAGE_SIZE-1:0]; // flatten
wire[inst_sig_width+inst_exp_width:0] _normal_w[NUM_INPUT:1][IMAGE_SIZE-1:0]; // flatten
wire[inst_sig_width+inst_exp_width:0] _encode_w[NUM_INPUT:1][IMAGE_SIZE-1:0]; // flatten
wire[inst_sig_width+inst_exp_width:0] _distance_w;

// ERROR CHECK 0.002
wire [inst_sig_width+inst_exp_width:0] _errAllow = 32'h3B03126F;
reg  [inst_sig_width+inst_exp_width:0] _errDiff;
wire [inst_sig_width+inst_exp_width:0] _errDiff_w;
reg  [inst_sig_width+inst_exp_width:0] _errBound;
wire [inst_sig_width+inst_exp_width:0] _errBound_w;

wire _isErr;

// DISPLAY 
real err_real;
real your_real;
real gold_real;

// Utility
function[inst_sig_width+inst_exp_width:0] _randInput;
    input integer _pat;
    reg[6:0] fract_rand;
    integer dig_idx;
    begin
        _randInput = 0;
        if(_pat < PATNUM_SIMPLE) begin
            _randInput = 0;
            _randInput[inst_sig_width+:inst_exp_width] = {$random(SEED)} % 4 + 126;
            _randInput[inst_sig_width+inst_exp_width]  = {$random(SEED)} % 2;
        end
        else begin
            _randInput = 0;
            _randInput[inst_sig_width+:inst_exp_width] = {$random(SEED)} % 9 + 126;
            _randInput[inst_sig_width+inst_exp_width]  = {$random(SEED)} % 2;
            fract_rand = {$random(SEED)} % 128;
            for(dig_idx=0 ; dig_idx<7 ; dig_idx=dig_idx+1) begin
                _randInput[inst_sig_width-dig_idx] = fract_rand[6-dig_idx];
            end
        end
    end
endfunction

function real _convertFloat;
        input reg[inst_sig_width+inst_exp_width:0] _x;
        integer _yExp;
        real _yFrac;
        real _yFloat;
        integer _i;
    begin
        // Exponent
        _yExp = -127;
        for(_i=0 ; _i<inst_exp_width ; _i=_i+1) begin
            _yExp = _yExp + (2**_i)*_x[inst_sig_width+_i];
            //$display("%d %d %d\n", _yExp, _x[inst_sig_width+_i], inst_sig_width+_i);
        end
        // Fraction
        _yFrac = 1;
        for(_i=0 ; _i<inst_sig_width ; _i=_i+1) begin
            _yFrac = _yFrac + 2.0**(_i-inst_sig_width)*_x[_i];
            //$display("%.31f %d %d\n", _yFrac, _x[_i], _i);
        end
        // Float
        _yFloat = 0;
        _yFloat = _x[inst_sig_width+inst_exp_width] ? -_yFrac * (2.0**_yExp) : _yFrac * (2.0**_yExp);

        _convertFloat = _yFloat;
    end
endfunction

reg[4*8:1] _line1  = "____";
reg[4*8:1] _space1 = "    ";
reg[9*8:1] _line2  = "_________";
reg[9*8:1] _space2 = "         ";
task dump_input;
    input integer isHex;
    integer num_idx;
    integer sub_idx;
    integer col_idx;
    integer row_idx;
begin
    
    // [#0] **1 **2 **3
    // _________________
    //   0| **1 **2 **3
    if(isHex === 1) file_out = $fopen("input_hex.txt", "w");
    else file_out = $fopen("input_float.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n\n", pat);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Option ]\n");
    $fwrite(file_out, "[========]\n\n");
    $fwrite(file_out, "[ opt ] %d\n", _opt);
    if(_opt === 2'd0) $fwrite(file_out, "[ Sigmoid ][ Replication ]");
    if(_opt === 2'd1) $fwrite(file_out, "[ Sigmoid ][ Zero ]");
    if(_opt === 2'd2) $fwrite(file_out, "[ tanh ][ Replication ]");
    if(_opt === 2'd3) $fwrite(file_out, "[ tanh ][ Zero ]");
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=======]\n");
    $fwrite(file_out, "[ Input ]\n");
    $fwrite(file_out, "[=======]\n\n");

    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=IMAGE_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=0 ; sub_idx<IMAGE_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<IMAGE_SIZE ; row_idx=row_idx+1) begin
            for(sub_idx=1 ; sub_idx<=IMAGE_NUM ; sub_idx=sub_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _img[num_idx][sub_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _convertFloat(_img[num_idx][sub_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Kernel ]\n");
    $fwrite(file_out, "[========]\n\n");

    for(sub_idx=1 ; sub_idx<=KERNEL_NUM ; sub_idx=sub_idx+1) begin
        $fwrite(file_out, "[%1d] ", sub_idx);
        for(col_idx=0 ; col_idx<KERNEL_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
        $fwrite(file_out, "%0s", _space1);
    end
    $fwrite(file_out, "\n");
    // _________________
    for(sub_idx=0 ; sub_idx<KERNEL_NUM ; sub_idx=sub_idx+1) begin
        $fwrite(file_out, "%0s", _line1);
        for(col_idx=0 ; col_idx<KERNEL_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
        $fwrite(file_out, "%0s", _space1);
    end
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(row_idx=0 ; row_idx<KERNEL_SIZE ; row_idx=row_idx+1) begin
        for(sub_idx=1 ; sub_idx<=KERNEL_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%2d| ",row_idx);
            for(col_idx=0 ; col_idx<KERNEL_SIZE ; col_idx=col_idx+1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _kernel[sub_idx][row_idx][col_idx]);
                else $fwrite(file_out, "%8.3f ", _convertFloat(_kernel[sub_idx][row_idx][col_idx]));
            end
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Weight ]\n");
    $fwrite(file_out, "[========]\n\n");

    // [#0] **1 **2 **3
    $fwrite(file_out, "[W] ");
    for(col_idx=0 ; col_idx<WEIGHT_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _line1);
    for(col_idx=0 ; col_idx<WEIGHT_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(row_idx=0 ; row_idx<WEIGHT_SIZE ; row_idx=row_idx+1) begin
        $fwrite(file_out, "%2d| ",row_idx);
        for(col_idx=0 ; col_idx<WEIGHT_SIZE ; col_idx=col_idx+1) begin
            if(isHex === 1) $fwrite(file_out, "%8h ", _weight[row_idx][col_idx]);
            else $fwrite(file_out, "%8.3f ", _convertFloat(_weight[row_idx][col_idx]));
        end
        $fwrite(file_out, "%0s", _space1);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fclose(file_out);
end endtask

task dump_output;
    input integer isHex;
    integer num_idx;
    integer sub_idx;
    integer col_idx;
    integer row_idx;
begin
    if(isHex === 1) file_out = $fopen("output_hex.txt", "w");
    else file_out = $fopen("output_float.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n\n", pat);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Option ]\n");
    $fwrite(file_out, "[========]\n\n");
    $fwrite(file_out, "[ opt ] %d\n", _opt);
    if(_opt === 2'd0) $fwrite(file_out, "[ Sigmoid ][ Replication ]");
    if(_opt === 2'd1) $fwrite(file_out, "[ Sigmoid ][ Zero ]");
    if(_opt === 2'd2) $fwrite(file_out, "[ tanh ][ Replication ]");
    if(_opt === 2'd3) $fwrite(file_out, "[ tanh ][ Zero ]");
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=========]\n");
    $fwrite(file_out, "[ Padding ]\n");
    $fwrite(file_out, "[=========]\n\n");

    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=IMAGE_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE+2 ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=0 ; sub_idx<IMAGE_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE+2 ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<IMAGE_SIZE+2 ; row_idx=row_idx+1) begin
            for(sub_idx=1 ; sub_idx<=IMAGE_NUM ; sub_idx=sub_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<IMAGE_SIZE+2 ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _pad[num_idx][sub_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _convertFloat(_pad[num_idx][sub_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=====================]\n");
    $fwrite(file_out, "[ Convolution Partial ]\n");
    $fwrite(file_out, "[=====================]\n\n");
    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=IMAGE_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=0 ; sub_idx<IMAGE_NUM ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<IMAGE_SIZE ; row_idx=row_idx+1) begin
            for(sub_idx=1 ; sub_idx<=IMAGE_NUM ; sub_idx=sub_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _conv[num_idx][sub_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _convertFloat(_conv[num_idx][sub_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=================]\n");
    $fwrite(file_out, "[ Convolution Sum ]\n");
    $fwrite(file_out, "[=================]\n\n");
    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<IMAGE_SIZE ; row_idx=row_idx+1) begin
            $fwrite(file_out, "%2d| ",row_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _convSum[num_idx][row_idx][col_idx]);
                else $fwrite(file_out, "%8.3f ", _convertFloat(_convSum[num_idx][row_idx][col_idx]));
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[============]\n");
    $fwrite(file_out, "[ Maxpooling ]\n");
    $fwrite(file_out, "[============]\n\n");
    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE/2 ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE/2 ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<IMAGE_SIZE/2 ; row_idx=row_idx+1) begin
            $fwrite(file_out, "%2d| ",row_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE/2 ; col_idx=col_idx+1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _pool[num_idx][row_idx][col_idx]);
                else $fwrite(file_out, "%8.3f ", _convertFloat(_pool[num_idx][row_idx][col_idx]));
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=======]\n");
    $fwrite(file_out, "[ Fully ]\n");
    $fwrite(file_out, "[=======]\n\n");

    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<1 ; row_idx=row_idx+1) begin
            $fwrite(file_out, "%2d| ",row_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _full[num_idx][col_idx]);
                else $fwrite(file_out, "%8.3f ", _convertFloat(_full[num_idx][col_idx]));
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Normal ]\n");
    $fwrite(file_out, "[========]\n\n");

    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<1 ; row_idx=row_idx+1) begin
            $fwrite(file_out, "%2d| ",row_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _normal[num_idx][col_idx]);
                else $fwrite(file_out, "%8.3f ", _convertFloat(_normal[num_idx][col_idx]));
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Encode ]\n");
    $fwrite(file_out, "[========]\n\n");

    for(num_idx=1 ; num_idx<=NUM_INPUT ; num_idx=num_idx+1) begin
        $fwrite(file_out, "[ IMAGE %1d ]\n\n", num_idx);
        // [#0] **1 **2 **3
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "[%1d] ", sub_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(sub_idx=1 ; sub_idx<=1 ; sub_idx=sub_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<1 ; row_idx=row_idx+1) begin
            $fwrite(file_out, "%2d| ",row_idx);
            for(col_idx=0 ; col_idx<IMAGE_SIZE ; col_idx=col_idx+1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _encode[num_idx][col_idx]);
                else $fwrite(file_out, "%8.3f ", _convertFloat(_encode[num_idx][col_idx]));
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[==========]\n");
    $fwrite(file_out, "[ Distance ]\n");
    $fwrite(file_out, "[==========]\n\n");
    if(isHex === 1) $fwrite(file_out, "%8h ", _distance);
    else $fwrite(file_out, "%8.3f ", _convertFloat(_distance));
    $fwrite(file_out, "\n");

    $fclose(file_out);
end endtask

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              Clock
//======================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
        // Print Pass Info and accumulate the total latency
        $display("%0sPASS PATTERN NO.%4d, %0sCycles: %3d%0s",txt_blue_prefix, pat, txt_green_prefix, exe_lat, reset_color);
    end
    $finish;
    // pass_task;
end endtask

//**************************************
//      Reset Task
//**************************************
task reset_task; begin

    force clk = 0;
    rst_n = 1;

    in_valid = 'd0;
    Img = 'dx;
    Kernel = 'dx;
	Weight = 'dx;
    Opt = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if (out_valid !== 0 || out !== 0) begin
        $display("                                           `:::::`                                                       ");
        $display("                                          .+-----++                                                      ");
        $display("                .--.`                    o:------/o                                                      ");
        $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
        $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
        $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
        $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
        $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
        $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
        $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
        $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
        $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
        $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
        $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
        $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
        $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
        $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
        $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
        $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
        $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
        $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
        $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
        $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
        $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
        $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
        $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
        $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
        $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     after the reset signal is asserted");
        $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
        $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
        $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
        $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
        $display("                       `s--------------------------::::::::-----:o                                       ");
        $display("                       +:----------------------------------------y`                                      ");
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

//**************************************
//      Input Task
//**************************************
task random_input;
    integer i;
    integer j;
    integer k;
    integer m;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(j=1 ; j<=IMAGE_NUM ; j=j+1) begin
            for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
                for(m=0 ; m<IMAGE_SIZE ; m=m+1) begin
                    _img[i][j][k][m] = _randInput(pat);
                end
            end
        end
    end
    for(j=1 ; j<=KERNEL_NUM ; j=j+1) begin
        for(k=0 ; k<KERNEL_SIZE ; k=k+1) begin
            for(m=0 ; m<KERNEL_SIZE ; m=m+1) begin
                _kernel[j][k][m] = _randInput(pat);
            end
        end
    end
    for(k=0 ; k<WEIGHT_SIZE ; k=k+1) begin
        for(m=0 ; m<WEIGHT_SIZE ; m=m+1) begin
            _weight[k][m] = _randInput(pat);
        end
    end
    _opt = {$random(SEED)} % 4;
end endtask

task input_task;
    integer i;
    integer j;
    integer k;
    integer m;
    integer cnt;
begin
    random_input;
    _storePadding;
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
    cnt = 0;
    for(i=0 ; i<NUM_INPUT*IMAGE_NUM*IMAGE_SIZE*IMAGE_SIZE ; i=i+1)begin
        in_valid = 'b1;
        Img = _img[(i/(IMAGE_SIZE*IMAGE_SIZE*IMAGE_NUM))%NUM_INPUT+1][(i/IMAGE_SIZE/IMAGE_SIZE)%IMAGE_NUM+1][(i/IMAGE_SIZE)%IMAGE_SIZE][i%IMAGE_SIZE];
        if(cnt<KERNEL_NUM*KERNEL_SIZE*KERNEL_SIZE) Kernel = _kernel[i/(KERNEL_SIZE*KERNEL_SIZE)+1][(i/KERNEL_SIZE)%KERNEL_SIZE][i%KERNEL_SIZE];
        else Kernel = 'dx;
        if(cnt<WEIGHT_SIZE*WEIGHT_SIZE) Weight = _weight[i/WEIGHT_SIZE][i%WEIGHT_SIZE];
        else Weight = 'dx;
        if(cnt<1) Opt = _opt;
        else Opt = 'dx;
        @(negedge clk);
        cnt = cnt + 1;
    end
    in_valid = 'b0;
    Img = 'dx;
    Kernel = 'dx;
    Weight = 'dx;
    Opt = 'dx;
end endtask

//**************************************
//      Wait Task
//**************************************
task wait_task; begin
    exe_lat = -1;
    while (out_valid !== 1) begin
        if (out !== 0) begin
            $display("                                           `:::::`                                                       ");
            $display("                                          .+-----++                                                      ");
            $display("                .--.`                    o:------/o                                                      ");
            $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
            $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
            $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
            $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
            $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
            $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
            $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
            $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
            $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
            $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
            $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
            $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
            $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
            $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
            $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
            $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
            $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
            $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
            $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
            $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
            $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
            $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
            $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
            $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
            $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     when the out_valid is pulled down ");
            $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
            $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
            $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
            $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
            $display("                       `s--------------------------::::::::-----:o                                       ");
            $display("                       +:----------------------------------------y`                                      ");
            repeat(5) #(CYCLE);
            $finish;
        end
        if (exe_lat == DELAY) begin
            $display("                                   ..--.                                ");
            $display("                                `:/:-:::/-                              ");
            $display("                                `/:-------o                             ");
            $display("                                /-------:o:                             "); 
            $display("                                +-:////+s/::--..                        ");
            $display("    The execution latency      .o+/:::::----::::/:-.       at %-12d ps  ", $time*1000);
            $display("    is over %5d   cycles    `:::--:/++:----------::/:.                ", DELAY);
            $display("                            -+:--:++////-------------::/-               ");
            $display("                            .+---------------------------:/--::::::.`   ");
            $display("                          `.+-----------------------------:o/------::.  ");
            $display("                       .-::-----------------------------:--:o:-------:  ");
            $display("                     -:::--------:/yy------------------/y/--/o------/-  ");
            $display("                    /:-----------:+y+:://:--------------+y--:o//:://-   ");
            $display("                   //--------------:-:+ssoo+/------------s--/. ````     ");
            $display("                   o---------:/:------dNNNmds+:----------/-//           ");
            $display("                   s--------/o+:------yNNNNNd/+--+y:------/+            ");
            $display("                 .-y---------o:-------:+sso+/-:-:yy:------o`            ");
            $display("              `:oosh/--------++-----------------:--:------/.            ");
            $display("              +ssssyy--------:y:---------------------------/            ");
            $display("              +ssssyd/--------/s/-------------++-----------/`           ");
            $display("              `/yyssyso/:------:+o/::----:::/+//:----------+`           ");
            $display("             ./osyyyysssso/------:/++o+++///:-------------/:            ");
            $display("           -osssssssssssssso/---------------------------:/.             ");
            $display("         `/sssshyssssssssssss+:---------------------:/+ss               ");
            $display("        ./ssssyysssssssssssssso:--------------:::/+syyys+               ");
            $display("     `-+sssssyssssssssssssssssso-----::/++ooooossyyssyy:                ");
            $display("     -syssssyssssssssssssssssssso::+ossssssssssssyyyyyss+`              ");
            $display("     .hsyssyssssssssssssssssssssyssssssssssyhhhdhhsssyssso`             ");
            $display("     +/yyshsssssssssssssssssssysssssssssyhhyyyyssssshysssso             ");
            $display("    ./-:+hsssssssssssssssssssssyyyyyssssssssssssssssshsssss:`           ");
            $display("    /---:hsyysyssssssssssssssssssssssssssssssssssssssshssssy+           ");
            $display("    o----oyy:-:/+oyysssssssssssssssssssssssssssssssssshssssy+-          ");
            $display("    s-----++-------/+sysssssssssssssssssssssssssssssyssssyo:-:-         ");
            $display("    o/----s-----------:+syyssssssssssssssssssssssyso:--os:----/.        ");
            $display("    `o/--:o---------------:+ossyysssssssssssyyso+:------o:-----:        ");
            $display("      /+:/+---------------------:/++ooooo++/:------------s:---::        ");
            $display("       `/o+----------------------------------------------:o---+`        ");
            $display("         `+-----------------------------------------------o::+.         ");
            $display("          +-----------------------------------------------/o/`          ");
            $display("          ::----------------------------------------------:-            ");
            repeat(5) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

//**************************************
//      Calculate Task
//**************************************
task _storePadding;
    integer i;
    integer j;
    integer k;
    integer m;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(j=1 ; j<=IMAGE_NUM ; j=j+1) begin
            for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
                for(m=0 ; m<IMAGE_SIZE ; m=m+1) begin
                    _pad[i][j][k+1][m+1] = _img[i][j][k][m];
                end
            end
        end
    end
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(j=1 ; j<=IMAGE_NUM ; j=j+1) begin
            for(k=0 ; k<IMAGE_SIZE+2 ; k=k+1) begin
                for(m=0 ; m<IMAGE_SIZE+2 ; m=m+1) begin
                    if(_opt[0]==='d0) begin
                        if(k===0 && m===0) _pad[i][j][k][m] = _pad[i][j][k+1][m+1];
                        else if(k===0 && m===IMAGE_SIZE+1) _pad[i][j][k][m] = _pad[i][j][k+1][m-1];
                        else if(k===IMAGE_SIZE+1 && m===0) _pad[i][j][k][m] = _pad[i][j][k-1][m+1];
                        else if(k===IMAGE_SIZE+1 && m===IMAGE_SIZE+1) _pad[i][j][k][m] = _pad[i][j][k-1][m-1];
                        else begin
                            if(k===0) _pad[i][j][k][m] = _pad[i][j][k+1][m];
                            else if(k===IMAGE_SIZE+1) _pad[i][j][k][m] = _pad[i][j][k-1][m];
                            else if(m===0) _pad[i][j][k][m] = _pad[i][j][k][m+1];
                            else if(m===IMAGE_SIZE+1) _pad[i][j][k][m] = _pad[i][j][k][m-1];
                        end
                    end
                    else begin
                        if(k===0 || k===IMAGE_SIZE+1) _pad[i][j][k][m] = 0;
                        if(m===0 || m===IMAGE_SIZE+1) _pad[i][j][k][m] = 0;
                    end
                end
            end
        end
    end
end endtask

task _storeConvolution;
    integer i;
    integer j;
    integer k;
    integer m;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(j=1 ; j<=IMAGE_NUM ; j=j+1) begin
            for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
                for(m=0 ; m<IMAGE_SIZE ; m=m+1) begin
                    _conv[i][j][k][m] = _conv_w[i][j][k][m];
                end
            end
        end
    end
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
            for(m=0 ; m<IMAGE_SIZE ; m=m+1) begin
                _convSum[i][k][m] = _convSum_w[i][k][m];
            end
        end
    end
end endtask

task _storeMaxPool;
    integer i;
    integer k;
    integer m;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(k=0 ; k<IMAGE_SIZE/2 ; k=k+1) begin
            for(m=0 ; m<IMAGE_SIZE/2 ; m=m+1) begin
                _pool[i][k][m] = _pool_w[i][k][m];
            end
        end
    end
end endtask

task _storeFully;
    integer i;
    integer k;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
            _full[i][k] = _full_w[i][k];
        end
    end
end endtask

task _storeNormal;
    integer i;
    integer k;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
            _normal[i][k] = _normal_w[i][k];
        end
    end
end endtask

task _storeEncode;
    integer i;
    integer k;
begin
    for(i=1 ; i<=NUM_INPUT ; i=i+1) begin
        for(k=0 ; k<IMAGE_SIZE ; k=k+1) begin
            _encode[i][k] = _encode_w[i][k];
        end
    end
end endtask

task _storeDistance;begin
    _distance = _distance_w;
end endtask

task _storeErr;begin
    _errDiff = _errDiff_w;
    _errBound = _errBound_w;
end endtask

task cal_task; begin
    _storeConvolution;
    _storeMaxPool;
    _storeFully;
    _storeNormal;
    _storeEncode;
    _storeDistance;
end endtask

//**************************************
//      Check Task
//**************************************
task check_task; begin
    out_lat = 0;
    while(out_valid === 1) begin
        if(out_lat == OUT_NUM) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Out cycles is more than %-2d                    /s:-----+s`     at %-12d ps ", OUT_NUM, $time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   ");
            repeat(5) @(negedge clk);
            $finish;
        end
        //====================
        // Check
        //====================
        if(_isErr !== 0) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Output is not correct!!!                      /s:-----+s`     at %-12d ps   ", $time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   "); 
            $display("[Info] Dump debugging file...");
            dump_input(0);
            dump_input(1);
            dump_output(0);
            dump_output(1);
            $display("[Info] Your   disatnce : %8h / %8.4f", out, _convertFloat(out));
            $display("[Info] Golden disatnce : %8h / %8.4f\n", _distance, _convertFloat(_distance));
            repeat(5) @(negedge clk);
            $finish;
        end

        out_lat = out_lat + 1;
        @(negedge clk);
    end

    if (out_lat<OUT_NUM) begin     
        $display("                                                                                ");
        $display("                                                   ./+oo+/.                     ");
        $display("    Out cycles is less than %-2d                    /s:-----+s`     at %-12d ps ", OUT_NUM, $time*1000);
        $display("                                                  y/-------:y                   ");
        $display("                                             `.-:/od+/------y`                  ");
        $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
        $display("                              -m+:::::::---------------------::o+.              ");
        $display("                             `hod-------------------------------:o+             ");
        $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
        $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
        $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
        $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
        $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
        $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
        $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
        $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
        $display("                 s:----------------/s+///------------------------------o`       ");
        $display("           ``..../s------------------::--------------------------------o        ");
        $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
        $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
        $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
        $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
        $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
        $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
        $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
        $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
        $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
        $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
        $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
        $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
        $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
        $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
        $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
        $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
        $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
        $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
        $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
        $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
        $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
        $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
        $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   "); 
        repeat(5) @(negedge clk);
        $finish;
    end
    tot_lat = tot_lat + exe_lat;
end endtask

//=================
// Convolution
//=================
genvar i_input, i_imag, i_row, i_col, i_innner;
generate
    for(i_input=1 ; i_input<=NUM_INPUT ; i_input=i_input+1) begin : gen_conv
        for(i_imag=1 ; i_imag<=IMAGE_NUM ; i_imag=i_imag+1) begin
            for(i_row=0 ; i_row<=IMAGE_SIZE-1 ; i_row=i_row+1) begin
                for(i_col=0 ; i_col<=IMAGE_SIZE-1 ; i_col=i_col+1) begin
                    wire [inst_sig_width+inst_exp_width:0] out1;
                    convSubMult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    CSM(
                        // Image
                        _pad[i_input][i_imag][i_row][i_col],   _pad[i_input][i_imag][i_row][i_col+1],   _pad[i_input][i_imag][i_row][i_col+2],
                        _pad[i_input][i_imag][i_row+1][i_col], _pad[i_input][i_imag][i_row+1][i_col+1], _pad[i_input][i_imag][i_row+1][i_col+2],
                        _pad[i_input][i_imag][i_row+2][i_col], _pad[i_input][i_imag][i_row+2][i_col+1], _pad[i_input][i_imag][i_row+2][i_col+2],
                        // Kernel
                        _kernel[i_imag][0][0], _kernel[i_imag][0][1], _kernel[i_imag][0][2],
                        _kernel[i_imag][1][0], _kernel[i_imag][1][1], _kernel[i_imag][1][2],
                        _kernel[i_imag][2][0], _kernel[i_imag][2][1], _kernel[i_imag][2][2],
                        // Output
                        out1
                    );
                    assign _conv_w[i_input][i_imag][i_row][i_col] = out1;
                end
            end
        end
    end
endgenerate

//=================
// Convolution Sum
//=================
generate
    for(i_input=1 ; i_input<=NUM_INPUT ; i_input=i_input+1) begin : gen_conv_sum
        for(i_row=0 ; i_row<IMAGE_SIZE ; i_row=i_row+1) begin
            for(i_col=0 ; i_col<IMAGE_SIZE ; i_col=i_col+1) begin
                wire [inst_sig_width+inst_exp_width:0] add0;
                wire [inst_sig_width+inst_exp_width:0] add1;
                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(_conv_w[i_input][1][i_row][i_col]), .b(_conv_w[i_input][2][i_row][i_col]), .op(1'd0), .rnd(3'd0), .z(add0));
                
                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A1 (.a(add0), .b(_conv_w[i_input][3][i_row][i_col]), .op(1'd0), .rnd(3'd0), .z(add1));
                
                assign _convSum_w[i_input][i_row][i_col] = add1;
            end
        end
    end
endgenerate

//=================
// Maxpooling
//=================
generate
    for(i_input=1 ; i_input<=NUM_INPUT ; i_input=i_input+1) begin : gen_maxpool
        for(i_row=0 ; i_row<IMAGE_SIZE/2 ; i_row=i_row+1) begin
            for(i_col=0 ; i_col<IMAGE_SIZE/2 ; i_col=i_col+1) begin
                wire [inst_sig_width+inst_exp_width:0] min;
                wire [inst_sig_width+inst_exp_width:0] max;
                findMinAndMax#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    FMAM(
                        _convSum_w[i_input][i_row*2][i_col*2],
                        _convSum_w[i_input][i_row*2][i_col*2+1],
                        _convSum_w[i_input][i_row*2+1][i_col*2],
                        _convSum_w[i_input][i_row*2+1][i_col*2+1],
                        min, max
                    ); 
                assign _pool_w[i_input][i_row][i_col] = max;
            end
        end
    end
endgenerate

//=================
// Fully Connected
//=================
// TODO : improve generate for
generate
    for(i_input=1 ; i_input<=NUM_INPUT ; i_input=i_input+1) begin : gen_full
        for(i_row=0 ; i_row<IMAGE_SIZE/2 ; i_row=i_row+1) begin
            for(i_col=0 ; i_col<IMAGE_SIZE/2 ; i_col=i_col+1) begin
                wire [inst_sig_width+inst_exp_width:0] out0;
                wire [inst_sig_width+inst_exp_width:0] out1;
                wire [inst_sig_width+inst_exp_width:0] out2;
                DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    M0 (.a(_pool_w[i_input][i_row][0]), .b(_weight[0][i_col]), .rnd(3'd0), .z(out0));
                
                DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                    M1 (.a(_pool_w[i_input][i_row][1]), .b(_weight[1][i_col]), .rnd(3'd0), .z(out1));

                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(out0), .b(out1), .op(1'd0), .rnd(3'd0), .z(out2));

                assign _full_w[i_input][i_row*IMAGE_SIZE/2+i_col] = out2;
            end
        end
    end
endgenerate

//=================
// Normalization
//=================
// TODO : improve generate for
generate
    for(i_input=1 ; i_input<=NUM_INPUT ; i_input=i_input+1) begin : gen_normal
        for(i_row=0 ; i_row<IMAGE_SIZE ; i_row=i_row+1) begin
            wire [inst_sig_width+inst_exp_width:0] min;
            wire [inst_sig_width+inst_exp_width:0] max;
            wire [inst_sig_width+inst_exp_width:0] num_diff;
            wire [inst_sig_width+inst_exp_width:0] deno_diff;
            wire [inst_sig_width+inst_exp_width:0] div_out;
            wire [7:0] status_inst;
            findMinAndMax#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                FMAM(
                    _full_w[i_input][0],
                    _full_w[i_input][1],
                    _full_w[i_input][2],
                    _full_w[i_input][3],
                    min, max
                );
            DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                S0 (.a(_full_w[i_input][i_row]), .b(min), .op(1'd1), .rnd(3'd0), .z(num_diff));
            DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                S1 (.a(max), .b(min), .op(1'd1), .rnd(3'd0), .z(deno_diff));
            DW_fp_div#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                D0 (.a(num_diff), .b(deno_diff), .rnd(3'd0), .z(div_out), .status(status_inst));
            assign _normal_w[i_input][i_row] = div_out;
        end
    end
endgenerate

//=================
// Encode
//=================
generate
    for(i_input=1 ; i_input<=NUM_INPUT ; i_input=i_input+1) begin : gen_encode
        for(i_row=0 ; i_row<IMAGE_SIZE ; i_row=i_row+1) begin
            wire [inst_sig_width+inst_exp_width:0] sigmoid_out;
            wire [inst_sig_width+inst_exp_width:0] tanh_out;
            sigmoid#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                s(_normal_w[i_input][i_row], sigmoid_out);
            tanh#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                t(_normal_w[i_input][i_row], tanh_out);
            assign _encode_w[i_input][i_row] = _opt[1]==1 ? tanh_out : sigmoid_out;
        end
    end
endgenerate

//=================
// Distance
//=================
// TODO : improve generate for
generate
    for(i_input=0 ; i_input<1 ; i_input=i_input+1) begin : gen_dist
        wire [inst_sig_width+inst_exp_width:0] diff0;
        wire [inst_sig_width+inst_exp_width:0] diff1;
        wire [inst_sig_width+inst_exp_width:0] diff2;
        wire [inst_sig_width+inst_exp_width:0] diff3;

        wire [inst_sig_width+inst_exp_width:0] out0;
        wire [inst_sig_width+inst_exp_width:0] out1;
        wire [inst_sig_width+inst_exp_width:0] out2;
        wire [inst_sig_width+inst_exp_width:0] out3;

        wire [inst_sig_width+inst_exp_width:0] add0;
        wire [inst_sig_width+inst_exp_width:0] add1;
        wire [inst_sig_width+inst_exp_width:0] add2;
        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            S0 (.a(_encode_w[1][0]), .b(_encode_w[2][0]), .op(1'd1), .rnd(3'd0), .z(diff0));
        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            S1 (.a(_encode_w[1][1]), .b(_encode_w[2][1]), .op(1'd1), .rnd(3'd0), .z(diff1));
        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            S2 (.a(_encode_w[1][2]), .b(_encode_w[2][2]), .op(1'd1), .rnd(3'd0), .z(diff2));
        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            S3 (.a(_encode_w[1][3]), .b(_encode_w[2][3]), .op(1'd1), .rnd(3'd0), .z(diff3));

        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            A0 (.a(out0), .b(out1), .op(1'd0), .rnd(3'd0), .z(add0));
        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            A1 (.a(out2), .b(out3), .op(1'd0), .rnd(3'd0), .z(add1));
        DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
            A2 (.a(add0), .b(add1), .op(1'd0), .rnd(3'd0), .z(add2));

        assign out0 = diff0[inst_sig_width+inst_exp_width]? {1'b0, diff0[inst_sig_width+inst_exp_width-1:0]} : diff0;
        assign out1 = diff1[inst_sig_width+inst_exp_width]? {1'b0, diff1[inst_sig_width+inst_exp_width-1:0]} : diff1;
        assign out2 = diff2[inst_sig_width+inst_exp_width]? {1'b0, diff2[inst_sig_width+inst_exp_width-1:0]} : diff2;
        assign out3 = diff3[inst_sig_width+inst_exp_width]? {1'b0, diff3[inst_sig_width+inst_exp_width-1:0]} : diff3;

        assign _distance_w = add2;
    end
endgenerate


//======================================
//      Error Calculation
//======================================
// TODO : Check this is better?
// gold - ans
generate
    for(i_input=0 ; i_input<1 ; i_input=i_input+1) begin : gen_err
        wire [inst_sig_width+inst_exp_width:0] bound;
        wire [inst_sig_width+inst_exp_width:0] error_diff;
        wire [inst_sig_width+inst_exp_width:0] error_diff_pos;
        DW_fp_sub
        #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
            Err_S0 (.a(_distance), .b(out), .z(error_diff), .rnd(3'd0));

        // gold * _errAllow
        DW_fp_mult
        #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
            Err_M0 (.a(_errAllow), .b(_distance_w), .z(bound), .rnd(3'd0));

        // check |gold - ans| > _errAllow * gold
        DW_fp_cmp
        #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
            Err_C0 (.a(error_diff_pos), .b(bound), .agtb(_isErr), .zctr(1'd0));

        assign error_diff_pos = error_diff[inst_sig_width+inst_exp_width] ? {1'b0, error_diff[inst_sig_width+inst_exp_width-1:0]} : error_diff;
        assign _errDiff_w = error_diff_pos;
        assign _errBound_w = bound;
    end
endgenerate
endmodule

//======================================
// IP Module
//======================================
module convSubMult
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 1
)
(
    input  [inst_sig_width+inst_exp_width:0] a0, a1, a2, a3, a4, a5, a6, a7, a8,
    input  [inst_sig_width+inst_exp_width:0] b0, b1, b2, b3, b4, b5, b6, b7, b8,
    output [inst_sig_width+inst_exp_width:0] out
);

    wire [inst_sig_width+inst_exp_width:0] pixel0, pixel1, pixel2, pixel3, pixel4, pixel5, pixel6, pixel7, pixel8;

    // Multiplication
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M0 (.a(a0), .b(b0), .rnd(3'd0), .z(pixel0));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M1 (.a(a1), .b(b1), .rnd(3'd0), .z(pixel1));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M2 (.a(a2), .b(b2), .rnd(3'd0), .z(pixel2));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M3 (.a(a3), .b(b3), .rnd(3'd0), .z(pixel3));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M4 (.a(a4), .b(b4), .rnd(3'd0), .z(pixel4));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M5 (.a(a5), .b(b5), .rnd(3'd0), .z(pixel5));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M6 (.a(a6), .b(b6), .rnd(3'd0), .z(pixel6));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M7 (.a(a7), .b(b7), .rnd(3'd0), .z(pixel7));
    
    DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        M8 (.a(a8), .b(b8), .rnd(3'd0), .z(pixel8));

    wire [inst_sig_width+inst_exp_width:0] add0, add1, add2, add3, add4, add5, add6;

    // Addition
    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(pixel0), .b(pixel1), .op(1'd0), .rnd(3'd0), .z(add0));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A1 (.a(add0), .b(pixel2), .op(1'd0), .rnd(3'd0), .z(add1));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A2 (.a(add1), .b(pixel3), .op(1'd0), .rnd(3'd0), .z(add2));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A3 (.a(add2), .b(pixel4), .op(1'd0), .rnd(3'd0), .z(add3));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A4 (.a(add3), .b(pixel5), .op(1'd0), .rnd(3'd0), .z(add4));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A5 (.a(add4), .b(pixel6), .op(1'd0), .rnd(3'd0), .z(add5));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A6 (.a(add5), .b(pixel7), .op(1'd0), .rnd(3'd0), .z(add6));

    DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A7 (.a(add6), .b(pixel8), .op(1'd0), .rnd(3'd0), .z(out));
endmodule

module findMinAndMax
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 1
)
(
    input  [inst_sig_width+inst_exp_width:0] a0, a1, a2, a3,
    output [inst_sig_width+inst_exp_width:0] minOut, maxOut
);
    wire [inst_sig_width+inst_exp_width:0] max0;
    wire [inst_sig_width+inst_exp_width:0] max1;
    wire [inst_sig_width+inst_exp_width:0] min0;
    wire [inst_sig_width+inst_exp_width:0] min1;
    wire flag0;
    wire flag1;
    wire flag2;
    wire flag3;
    DW_fp_cmp
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
        C0_1 (.a(a0), .b(a1), .agtb(flag0), .zctr(1'd0));
    DW_fp_cmp
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
        C1_2 (.a(a2), .b(a3), .agtb(flag1), .zctr(1'd0));
    
    DW_fp_cmp
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
        Cmax (.a(max0), .b(max1), .agtb(flag2), .zctr(1'd0));
    DW_fp_cmp
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
        Cmin (.a(min0), .b(min1), .agtb(flag3), .zctr(1'd0));

    assign max0 = flag0==1 ? a0 : a1;
    assign max1 = flag1==1 ? a2 : a3;

    assign min0 = flag0==1 ? a1 : a0;
    assign min1 = flag1==1 ? a3 : a2;
    assign maxOut = flag2==1 ? max0 : max1;
    assign minOut = flag3==1 ? min1 : min0;
endmodule

module sigmoid
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg));
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp));
    
    DW_fp_addsub // 1+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(float_gain1), .b(exp), .op(1'd0), .rnd(3'd0), .z(deno));
    
    DW_fp_div // 1 / [1+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(float_gain1), .b(deno), .rnd(3'd0), .z(out));
endmodule

module tanh
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 1,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp_pos;
    wire [inst_sig_width+inst_exp_width:0] exp_neg;
    wire [inst_sig_width+inst_exp_width:0] nume;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg));
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp_neg));

    DW_fp_exp // exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E1 (.a(in), .z(exp_pos));

    //

    DW_fp_addsub // exp(x)-exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(exp_pos), .b(exp_neg), .op(1'd1), .rnd(3'd0), .z(nume));

    DW_fp_addsub // exp(x)+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A1 (.a(exp_pos), .b(exp_neg), .op(1'd0), .rnd(3'd0), .z(deno));

    DW_fp_div // [exp(x)-exp(-x)] / [exp(x)+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(nume), .b(deno), .rnd(3'd0), .z(out));
endmodule