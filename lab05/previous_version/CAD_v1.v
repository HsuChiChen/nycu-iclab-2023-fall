//############################################################################
//   2023 ICLAB Fall Course
//   Lab05       : Matrix convolution, max pooling and transposed convolution
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.10.23
//   Version     : v1.0
//   File Name   : CAD.v
//   Module Name : CAD
//############################################################################

module CAD (
    // Input Ports
    clk,
    rst_n,
    in_valid,
    in_valid2,
    mode,
    matrix,
    matrix_size,
    matrix_idx,

    // Output Ports
    out_valid,
    out_value
    );

// Input Ports
input clk, rst_n, in_valid, in_valid2, mode;
input signed [7:0] matrix;
input [1:0] matrix_size;
input [3:0] matrix_idx;

// Output Ports
output reg out_valid;
output reg out_value;

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter   IDLE           = 0,

            // write image and kernel to SRAM
            READ_IMG       = 1,
            READ_KER       = 2,

            // read image and kernel index
            READ_WAIT      = 3,
            READ_INDEX     = 4,

            // mode 0 - convolution
            CONV_INIT      = 5,
            CONV_READ      = 6,
            CONV_CALC      = 7,
            CONV_MAX       = 8,
            CONV_OUT       = 9,
            CONV_READ_DOWN = 10,
            CONV_ONLY_OUT  = 11,

            // mode 1 - deconvolution
            DECONV_INIT    = 12,
            DECONV_READ    = 13,
            DECONV_CALC    = 14,
            DECONV_MAX     = 15,
            DECONV_OUT     = 16,
            DECONV_LEFT    = 17;

// integer and genvar
integer i;
genvar j;

//==============================================//
//                 reg declaration              //
//==============================================//
// state reg
reg [5:0] current_state, next_state;

// write data to SRAM
// 2-bit matrix size
reg [1:0] matrix_size_reg;

// 14-bit image address
reg [13:0] addr_img;

// 9-bit kernel address
reg [8:0] addr_ker;

// select mode, image, and kernel
// 1-bit mode
reg mode_reg;

// convolution of 6*6 image and 5*5 kernel
// 6*6 8-bit image
reg signed [7:0] img_reg [0:5][0:5];

// 6*4 8-bit image for next row
reg signed [7:0] img_reg_next [0:3][0:5];

// 5*5 8-bit kernel
reg signed [7:0] ker_reg [0:24];

// 5-bit counter_init
reg [4:0] counter_init;

// 4-bit counter_read
reg [3:0] counter_read;

// 3-bit counter_calc
reg [2:0] counter_calc;

// 20-bit max value candidate
reg signed [19:0] max_candidate [0:3];

// 20-bit max value
reg signed [19:0] max_reg;

// terminal address of image SRAM
reg [13:0] addr_img_conv_end;

// next row address of image SRAM
reg [13:0] addr_img_next_row;

// 4-bit counter for number of invalid2
reg [3:0] counter_invalid2;

// image address lower bound
reg signed [15:0] addr_img_lower_bound;

// image address upper bound
reg signed [15:0] addr_img_upper_bound;

// previous image address
reg [13:0] addr_img_prev;

// zero flag
reg zero_flag;

//==============================================//
//       psedo-reg wire declaration             //
//==============================================//
// end address of image SRAM
reg [13:0] addr_img_read_end;

// write enable, 1 for read, 0 for write
reg web_img, web_ker;

// data_in of image SRAM and kernel SRAM
reg signed [7:0] data_in;

// data_out of image SRAM and kernel SRAM
wire signed [7:0] data_out_img, data_out_ker;

// CONV_INIT state, counter_init = 0 ~ 23
wire [4:0] counter_init_delay1;
// CONV_READ state, counter_read = 0 ~ 11
wire [3:0] counter_read_delay1;

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
            if (in_valid) next_state = READ_IMG;
            else next_state = IDLE;
        end

        // write image and kernel to SRAM
        // 1. read image when in_valid is high
        READ_IMG: begin
            if (addr_img == addr_img_read_end) next_state = READ_KER;
            else next_state = READ_IMG;
        end
        // 2. read kernel when in_valid is high
        READ_KER: begin
            if (addr_ker == 399) next_state = READ_WAIT;
            else next_state = READ_KER;
        end

        // read image and kernel index
        // 3. wait for index until in_valid2 is high
        READ_WAIT: begin
            if (in_valid2) next_state = READ_INDEX;
            else next_state = READ_WAIT;
        end
        // 4. read index in one cycle
        READ_INDEX: begin
            // mode 0 - convolution
            // mode 1 - deconvolution
            if(mode_reg) next_state = DECONV_INIT;
            else next_state = CONV_INIT;
        end

        // mode 0 - convolution
        // 5. read 24 image and 25 kernel data from SRAM
        CONV_INIT: begin
            if (counter_init == 25) next_state = CONV_READ;
            else next_state = CONV_INIT;
        end
        // 6. read 6 * 2 = 12 image data from SRAM
        CONV_READ: begin
            if (counter_read == 12) next_state = CONV_CALC;
            else next_state = CONV_READ;
        end
        // 7. calculate convolution and compare 4 candidates
        CONV_CALC: begin
            if (counter_calc == 5) next_state = CONV_MAX;
            else next_state = CONV_CALC;
        end
        // 8. output 1 candidate
        CONV_MAX: begin
            next_state = CONV_OUT;
        end
        CONV_OUT: begin
            if(addr_img == addr_img_conv_end) next_state = CONV_ONLY_OUT;
            else if(addr_img == addr_img_next_row) next_state = CONV_READ_DOWN;
            else next_state = CONV_READ;
        end
        // 6-2. read 6 * 2 = 12 image data from SRAM
        CONV_READ_DOWN: begin
            if (counter_read == 12) next_state = CONV_CALC;
            else next_state = CONV_READ_DOWN;
        end

        // 9. only output last 20 bits
        CONV_ONLY_OUT: begin
            if(counter_init == 18) begin
                // number of invalid2 0 ~ 15 in one image
                if(counter_invalid2 == 0) begin
                    next_state = IDLE;
                end else begin
                    next_state = READ_WAIT;
                end
            end
            else next_state = CONV_ONLY_OUT;
        end

        // mode 1 - deconvolution
        // 1. read 25 kernel data from SRAM
        DECONV_INIT: begin
            if(counter_init == 25) next_state = DECONV_READ;
            else next_state = DECONV_INIT;
        end
        // 2. read 5 image data from SRAM
        DECONV_READ: begin
            if(counter_read == 12) next_state = DECONV_CALC;
            else next_state = DECONV_READ;
        end
        // 2-2. reset all block to zero and read 5 image data from SRAM
        DECONV_LEFT: begin
            if(counter_read == 12) next_state = DECONV_CALC;
            else next_state = DECONV_LEFT;
        end
        // 3. calculate convolution
        DECONV_CALC: begin
            if(counter_calc == 5) next_state = DECONV_MAX;
            else next_state = DECONV_CALC;
        end
        // 4. idle
        DECONV_MAX: begin
            next_state = DECONV_OUT;
        end
        // 5. output
        DECONV_OUT: begin
            if(addr_img == addr_img_conv_end) next_state = CONV_ONLY_OUT;
            else if(addr_img == addr_img_next_row + 4) next_state = DECONV_LEFT;
            else next_state = DECONV_READ;
        end

        default: next_state = IDLE; // illegal state
    endcase
end

//==============================================//
//        Write Image and Kernel to SRAM        //
//==============================================//
// read matrix size
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) matrix_size_reg <= 0;
    else if (current_state == IDLE && next_state == READ_IMG) matrix_size_reg <= matrix_size;
end

// maximum image address
// matrix_size_reg = 0 : addr_img <  8 *  8 * 16 = 2^10
// matrix_size_reg = 1 : addr_img < 16 * 16 * 16 = 2^12
// matrix_size_reg = 2 : addr_img < 32 * 32 * 16 = 2^14
// ahead 2 clock cycles

always @(*) begin
    if(matrix_size_reg == 0) begin
        addr_img_read_end = 1023; // 2^10 - 1
    end else if(matrix_size_reg == 1) begin
        addr_img_read_end = 4095; // 2^12 - 1
    end else begin // matrix_size_reg == 2
        addr_img_read_end = 16383; // 2^14 - 1
    end
end

//==============================================//
//        Image and Kernel SRAM Control         //
//==============================================//
// data_in of image SRAM and kernel SRAM
always @(*) begin
    if(in_valid) begin
        data_in = matrix;
    end else begin
        data_in = 0;
    end
end

// address of image SRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_img <= 0;
    // read image
    end else if(next_state == READ_IMG || current_state == READ_IMG) begin
        addr_img <= addr_img + 1;
    end else if(current_state == IDLE || current_state == READ_KER || current_state == CONV_ONLY_OUT) begin
        addr_img <= 0;
    
    // initial address of image SRAM
    // mode 0 - convolution
    end else if(current_state == READ_WAIT && next_state == READ_INDEX && mode == 0) begin
        // when matrix_size_reg = 0, 1 image has  8 *  8 =   64 = 2^6 blocks
        // when matrix_size_reg = 1, 1 image has 16 * 16 =  256 = 2^8  blocks
        // when matrix_size_reg = 2, 1 image has 32 * 32 = 1024 = 2^10 blocks
        addr_img <= matrix_idx << (6 + 2 * matrix_size_reg);
    // mode 1 - deconvolution
    end else if(current_state == READ_WAIT && next_state == READ_INDEX && mode == 1) begin
        // when matrix_size_reg = 0, 1 image has  8 *  8 =   64 = 2^6 blocks
        // when matrix_size_reg = 1, 1 image has 16 * 16 =  256 = 2^8  blocks
        // when matrix_size_reg = 2, 1 image has 32 * 32 = 1024 = 2^10 blocks
        addr_img <= (matrix_idx << (6 + 2 * matrix_size_reg)) - 4 * (8 << matrix_size_reg);

    // mode 0 - convolution
    // CONV_INIT state, counter_init = 0 ~ 23
    // counter_init = 24 and 25, do not change address
    end else if(current_state == CONV_INIT && (counter_init == 24 || counter_init == 25)) begin
        addr_img <= addr_img;
    // next row
    end else if(current_state == CONV_INIT && (counter_init + 1) % 6 != 0) begin
        addr_img <= addr_img + (8 << matrix_size_reg);
    // next colunn
    end else if(current_state == CONV_INIT && (counter_init + 1) % 6 == 0) begin
        addr_img <= addr_img - 5 * (8 << matrix_size_reg) + 1;
    
    // CONV_READ state, counter_read = 0 ~ 11
    // counter_init = 12, do not change address
    end else if(current_state == CONV_READ && counter_read >= 11) begin
        addr_img <= addr_img;
    // next row
    end else if(current_state == CONV_READ && (counter_read + 1) % 6 != 0) begin
        addr_img <= addr_img + (8 << matrix_size_reg);
    // next column
    end else if(current_state == CONV_READ && (counter_read + 1) % 6 == 0) begin
        addr_img <= addr_img - 5 * (8 << matrix_size_reg) + 1;
    // next row

    // CONV_READ_DOWN state, counter_read = 0 ~ 11
    // counter_init = 12, do not change address
    end else if(current_state == CONV_READ_DOWN && counter_read >= 11) begin
        addr_img <= addr_img;
    // next row
    end else if(current_state == CONV_READ_DOWN && (counter_read + 1) % 6 != 0) begin
        addr_img <= addr_img + 1;
    // next column
    end else if(current_state == CONV_READ_DOWN && (counter_read + 1) % 6 == 0) begin
        addr_img <= addr_img + (8 << matrix_size_reg) - 5;
    // next row

    // CONV_OUT state
    end else if(current_state == CONV_OUT && next_state == CONV_READ) begin
        addr_img <= addr_img - 5 * (8 << matrix_size_reg) + 1;
    end else if(current_state == CONV_OUT && next_state == CONV_READ_DOWN) begin
        addr_img <= addr_img + 1;

    // mode 1 - deconvolution
    // DECONV_LEFT state
    end else if(current_state == DECONV_OUT && next_state == DECONV_LEFT) begin
        addr_img <= addr_img - 4 * (8 << matrix_size_reg) - 3;
    // DECONV_READ state
    end else if(current_state == DECONV_OUT) begin
        addr_img <= addr_img - 4 * (8 << matrix_size_reg) + 1;
    end
    // DECONV_READ state and DECONV_LEFT state, read 5 blocks
    else if((current_state == DECONV_READ || current_state == DECONV_LEFT) && counter_read < 4) begin
        addr_img <= addr_img + (8 << matrix_size_reg);
    end
end

// write enable of image SRAM
always @(*) begin
    if (current_state == READ_KER || current_state == READ_WAIT) begin
        web_img = 1; // disable write image
    // 1. read image
    end else if (in_valid) begin
        web_img = 0; // enable write image
    end else begin
        web_img = 1; // disable write image
    end
end

// address of kernel SRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_ker <= 0;
    // avoid addr_ker = 400
    end else if ((current_state == DECONV_INIT && counter_init == 24) || (current_state == CONV_INIT && counter_init == 24) || next_state == READ_WAIT || current_state == IDLE) begin
        addr_ker <= 0;   
    // read kernel in CONV_INIT state
    end else if(current_state == READ_KER && next_state != READ_WAIT) begin
        addr_ker <= addr_ker + 1;
    // initial address of kernel SRAM
    end else if(current_state == READ_INDEX) begin
        addr_ker <= matrix_idx * 25; // 1 kernel has 5 * 5 = 25 blocks
    
    // mode 0 - convolution
    end else if((current_state == CONV_INIT && next_state != CONV_READ)) begin
        addr_ker <= addr_ker + 1;
   
    // mode 1 - deconvolution
    end else if(current_state == DECONV_INIT) begin
        addr_ker <= addr_ker + 1;
    end
end

// write enable of kernel SRAM
always @(*) begin
    if (current_state == READ_KER) begin
        web_ker = 0; // enable write kernel
    end else begin
        web_ker = 1; // disable write kernel
    end
end

// 32 * 32 * 16 single-port SRAM for image
// 14-bit address, 8-bit data
// mem_img m0(.clk(clk), .addr(addr_img), .data_in(data_in), .WEB(web_img), .data_out(data_out_img));
sram_1024x16_inst m0(.A(addr_img), .DO(data_out_img), .DI(data_in), .CK(clk), .WEB(web_img), .OE(1'b1), .CS(1'b1));

// 5 * 5 * 16 single-port SRAM for kernel
// 10-bit address, 8-bit data
// mem_kernel m1(.clk(clk), .addr(addr_ker), .data_in(data_in), .WEB(web_ker), .data_out(data_out_ker));
sram_32x16_inst m1(.A(addr_ker), .DO(data_out_ker), .DI(data_in), .CK(clk), .WEB(web_ker), .OE(1'b1), .CS(1'b1));

//==============================================//
//                    Read Index                //
//==============================================//
// first cycle
// read operation mode for convolution or deconvolution
always @(posedge clk) begin
    if (current_state == READ_WAIT && next_state == READ_INDEX) begin
        mode_reg <= mode;
    end
end

//================================================//
//            Read 25 Kernel from SRAM            //
//================================================//
// 5-bit counter_init
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter_init <= 0;
    // mode 0 - convolution
    end else if (current_state == CONV_INIT || current_state == CONV_ONLY_OUT) begin
        counter_init <= counter_init + 1;
    
    // mode 1 - deconvolution
    end else if (current_state == DECONV_INIT) begin
        counter_init <= counter_init + 1;
    end else begin
        counter_init <= 0;
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 25; i = i + 1) begin
            ker_reg[i] <= 0;
        end
    end else if (current_state == READ_INDEX) begin
        for (i = 0; i < 25; i = i + 1) begin
            ker_reg[i] <= 0;
        end
    // mode 0 - convolution
    end else if (current_state == CONV_INIT) begin
        ker_reg[counter_init_delay1] <= data_out_ker;
    // mode 1 - deconvolution
    end else if(current_state == DECONV_INIT) begin
        ker_reg[24 - counter_init_delay1] <= data_out_ker;
    end
end

//==============================================//
//           Read 24 Image from SRAM            //
//==============================================//
assign counter_init_delay1 = counter_init - 1;
assign counter_read_delay1 = counter_read - 1;
wire valid_addr_img;
assign valid_addr_img = (addr_img_prev >= addr_img_lower_bound && addr_img_prev <= addr_img_upper_bound && zero_flag != 1);


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 6; i = i + 1) begin
            img_reg[i][0] <= 0;
            img_reg[i][1] <= 0;
            img_reg[i][2] <= 0;
            img_reg[i][3] <= 0;
            img_reg[i][4] <= 0;
            img_reg[i][5] <= 0;
        end
    // initial all image data to 0
    end else if(current_state == READ_INDEX) begin
        for (i = 0; i < 6; i = i + 1) begin
            img_reg[i][0] <= 0;
            img_reg[i][1] <= 0;
            img_reg[i][2] <= 0;
            img_reg[i][3] <= 0;
            img_reg[i][4] <= 0;
            img_reg[i][5] <= 0;
        end
    // CONV_INIT state
    // read 6 * 4 = 24 blocks, from counter_init = 1 ~ 24, ie counter_init_delay1 = 0 ~ 23
    end else if (current_state == CONV_INIT && counter_init > 0 && counter_init < 25) begin
        img_reg[counter_init_delay1 % 6][counter_init_delay1 / 6] <= data_out_img;

    // CONV_READ state
    // read 6 * 2 = 12 blocks, from counter_read = 1 ~ 12, ie counter_read_delay1 = 0 ~ 11
    end else if (current_state == CONV_READ && counter_read < 13) begin
        img_reg[counter_read_delay1 % 6][counter_read_delay1 / 6 + 4] <= data_out_img;

    // CONV_READ_DOWN state
    // read 6 * 2 = 12 blocks, from counter_read = 1 ~ 12, ie counter_read_delay1 = 0 ~ 11
    end else if (current_state == CONV_READ_DOWN && counter_read < 13) begin
        img_reg[counter_read_delay1 / 6 + 4][counter_read_delay1 % 6] <= data_out_img;

    // CONV_OUT state
    // next_state == CONV_READ, shift 2 columns
    end else if(current_state == CONV_OUT && next_state == CONV_READ) begin
        for (i = 0; i < 6; i = i + 1) begin
            img_reg[i][0] <= img_reg[i][2];
            img_reg[i][1] <= img_reg[i][3];
            img_reg[i][2] <= img_reg[i][4];
            img_reg[i][3] <= img_reg[i][5];
        end
    // next_state == CONV_READ_DOWN, restore frist 2 row by img_reg_next
    end else if(current_state == CONV_OUT && next_state == CONV_READ_DOWN) begin
        for (i = 0; i < 6; i = i + 1) begin
            img_reg[0][i] <= img_reg_next[0][i];
            img_reg[1][i] <= img_reg_next[1][i];
            img_reg[2][i] <= img_reg_next[2][i];
            img_reg[3][i] <= img_reg_next[3][i];

        end
    
    // mode 1 - deconvolution
    // DECONV_READ state, read 5 data
    end else if((current_state == DECONV_READ || current_state == DECONV_LEFT) && counter_read_delay1 == 0) begin
        img_reg[0][4] <= valid_addr_img? data_out_img : 0;
    end else if((current_state == DECONV_READ || current_state == DECONV_LEFT) && counter_read_delay1 == 1) begin
        img_reg[1][4] <= valid_addr_img? data_out_img : 0;
    end else if((current_state == DECONV_READ || current_state == DECONV_LEFT) && counter_read_delay1 == 2) begin
        img_reg[2][4] <= valid_addr_img? data_out_img : 0;
    end else if((current_state == DECONV_READ || current_state == DECONV_LEFT) && counter_read_delay1 == 3) begin
        img_reg[3][4] <= valid_addr_img? data_out_img : 0;
    end else if((current_state == DECONV_READ || current_state == DECONV_LEFT) && counter_read_delay1 == 4) begin
        img_reg[4][4] <= valid_addr_img ? data_out_img : 0;

    // DECONV_OUT state, reset all block to zero
    end else if(current_state == DECONV_OUT && current_state == DECONV_LEFT) begin
        for (i = 0; i < 5; i = i + 1) begin
            img_reg[i][0] <= 0;
            img_reg[i][1] <= 0;
            img_reg[i][2] <= 0;
            img_reg[i][3] <= 0;
            img_reg[i][4] <= 0;
        end
    
    // DECONV_OUT state, shift 1 column
    end else if(current_state == DECONV_OUT) begin
        for (i = 0; i < 5; i = i + 1) begin
            img_reg[i][0] <= img_reg[i][1];
            img_reg[i][1] <= img_reg[i][2];
            img_reg[i][2] <= img_reg[i][3];
            img_reg[i][3] <= img_reg[i][4];
            img_reg[i][4] <= 0;
        end
    end
end

// store 6 * 4 = 24 image data for next row
reg store_flag;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        store_flag <= 1;
    end else if (current_state == CONV_INIT || current_state == CONV_READ_DOWN) begin
        store_flag <= 1;
    end else if (current_state == CONV_OUT) begin
        store_flag <= 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 6; i = i + 1) begin
            img_reg_next[0][i] <= 0;
            img_reg_next[1][i] <= 0;
            img_reg_next[2][i] <= 0;
            img_reg_next[3][i] <= 0;
        end
    end else if (store_flag && current_state == CONV_MAX) begin
        for (i = 0; i < 6; i = i + 1) begin
            img_reg_next[0][i] <= img_reg[2][i];
            img_reg_next[1][i] <= img_reg[3][i];
            img_reg_next[2][i] <= img_reg[4][i];
            img_reg_next[3][i] <= img_reg[5][i];
        end
    end
end


//==============================================//
//           Read 12 Image from SRAM            //
//==============================================//
// 4-bit counter_read
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter_read <= 0;
    // mode 0 - convolution
    end else if (current_state == CONV_READ || current_state == CONV_READ_DOWN) begin
        counter_read <= counter_read + 1;
    end else if (current_state == CONV_INIT || current_state == CONV_CALC) begin
        counter_read <= 0;

    // mode 1 - deconvolution
    end else if (current_state == DECONV_READ || current_state == DECONV_LEFT) begin
        counter_read <= counter_read + 1;
    end else if (current_state == DECONV_INIT || current_state == DECONV_CALC) begin
        counter_read <= 0;
    end
end


//==============================================//
//           Convolution Calculation            //
//==============================================//
// define 25 8-bit / 8-bit signed multiplication
reg signed [7:0] mul_op1[0:24];
reg signed [7:0] mul_op2[0:24];
wire signed [15:0] mul_result[0:24];


for(j = 0; j < 25; j = j + 1) begin
    assign mul_result[j] = mul_op1[j] * mul_op2[j];
end

// define 24 15-bit signed addition
reg signed [19:0] add_op[0:24];
wire signed [19:0] add_result;

assign add_result = add_op[0] + add_op[1] + add_op[2] + add_op[3] + add_op[4] + add_op[5] + add_op[6] + add_op[7] + add_op[8] + add_op[9] + add_op[10] + add_op[11] + add_op[12] + add_op[13] + add_op[14] + add_op[15] + add_op[16] + add_op[17] + add_op[18] + add_op[19] + add_op[20] + add_op[21] + add_op[22] + add_op[23] + add_op[24];


// 3-bit counter_calc
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter_calc <= 0;
    // mode 0 - convolution
    end else if (next_state == CONV_CALC || current_state == CONV_CALC) begin
        counter_calc <= counter_calc + 1;
    end else if (current_state == CONV_MAX) begin
        counter_calc <= 0;
        
    // mode 1 - deconvolution
    end else if (next_state == DECONV_CALC || current_state == DECONV_CALC) begin
        counter_calc <= counter_calc + 1;
    end else if (current_state == DECONV_OUT) begin
        counter_calc <= 0;
    end
end

// cycle 1
// multiplication operand 1 - 6 * 6 image
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 25; i = i + 1) begin
            mul_op1[i] <= 0;
        end
    // mode 0 - convolution
    end else if (next_state == CONV_CALC || current_state == CONV_CALC) begin
        for(i = 0; i < 25; i = i + 1) begin
            mul_op1[i] <= img_reg[i / 5 + counter_calc / 2][i % 5 + counter_calc % 2];
        end
    
    // mode 1 - deconvolution
    end  else if (current_state == DECONV_CALC) begin
        for(i = 0; i < 25; i = i + 1) begin
            mul_op1[i] <= img_reg[i / 5][i % 5];
        end
    end
end

// all same
// multiplication operand 2 - 5 * 5 kernel
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 25; i = i + 1) begin
            mul_op2[i] <= 0;
        end

    // mode 0 - convolution and mode 1 - deconvolution
    end else if (current_state == CONV_READ || current_state == DECONV_READ) begin
        for(i = 0; i < 25; i = i + 1) begin
            mul_op2[i] <= ker_reg[i];
        end
    end
end

// cycle 2
// addition operand - 25 15-bit multiplication result
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 25; i = i + 1) begin
            add_op[i] <= 0;
        end
    // mode 0 - convolution and mode 1 - deconvolution
    end else if (current_state == CONV_CALC || current_state == DECONV_CALC) begin
        for(i = 0; i < 25; i = i + 1) begin
            add_op[i] <= mul_result[i];
        end
    end
end

// mode 0 - convolution
// cycle 3
// store 4 candidates
wire [3:0] counter_calc_delay2;
assign counter_calc_delay2 = counter_calc - 2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 4; i = i + 1) begin
            max_candidate[i] <= 0;
        end
    end else if (current_state == CONV_CALC) begin
        max_candidate[counter_calc_delay2] <= add_result;
    end
end

// cycle 4
// compare 4 candidates
reg signed [19:0] max_temp1, max_temp2, max;
always @(*) begin
    // compare first 2 candidates
    if(max_candidate[0] > max_candidate[1]) begin
        max_temp1 = max_candidate[0];
    end else begin
        max_temp1 = max_candidate[1];
    end
    // compare last 2 candidates
    if(max_candidate[2] > max_candidate[3]) begin
        max_temp2 = max_candidate[2];
    end else begin
        max_temp2 = max_candidate[3];
    end
    // compare 2 results
    if(max_temp1 > max_temp2) begin
        max = max_temp1;
    end else begin
        max = max_temp2;
    end
end

// max_reg
// ouput_flag
reg output_flag;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        max_reg <= 0;
    // mode 0 - convolution
    end else if (current_state == CONV_MAX) begin
        max_reg <= max;

    // mode 1 - deconvolution
    end else if (current_state == DECONV_MAX) begin
        max_reg <= add_result;

    end else if (output_flag) begin
        max_reg <= max_reg >> 1; // right shift 1 bit
    end
end

//==============================================//
//           Calculate Next Row address         //
//==============================================//
// start_addr_img <= matrix_idx << (6 + 2 * matrix_size_reg);

// next_row address
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_img_next_row <= 0;
    // mode 0 - convolution
    end else if (current_state == READ_INDEX && mode_reg == 0) begin
        // matrix_size_reg == 0, addr_img_next_row = start_address + ( 8 - 1) +  8 * 5
        // matrix_size_reg == 1, addr_img_next_row = start_address + (16 - 1) + 16 * 5
        // matrix_size_reg == 2, addr_img_next_row = start_address + (32 - 1) + 32 * 5
        addr_img_next_row <= addr_img + 6 * (8 << matrix_size_reg) - 1;
    end else if (current_state == CONV_OUT && next_state == CONV_READ_DOWN) begin
        // next next row
        addr_img_next_row <= addr_img + 2 * (8 << matrix_size_reg);
    
    // mode 1 - deconvolution
    end else if (current_state == READ_INDEX && mode_reg == 1) begin
        // pseudo start address + 5 * 32 - 1
        addr_img_next_row <= addr_img + 5 * (8 << matrix_size_reg) - 1;
    end else if(current_state == DECONV_OUT && next_state == DECONV_LEFT) begin
        // next next row
        addr_img_next_row <= addr_img + (8 << matrix_size_reg) - 4;
    end
end

// conv_end address
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_img_conv_end <= 16383;
    // mode 0 - convolution
    end else if (current_state == READ_WAIT && next_state == READ_INDEX && mode == 0) begin
        // when matrix_size_reg = 0, 1 image has  8 *  8 =   64 = 2^6 blocks
        // when matrix_size_reg = 1, 1 image has 16 * 16 =  256 = 2^8  blocks
        // when matrix_size_reg = 2, 1 image has 32 * 32 = 1024 = 2^10 blocks
        // next image start address - 1
        addr_img_conv_end <= ((matrix_idx + 1) << (6 + 2 * matrix_size_reg)) - 1;
    
    // mode 1 - deconvolution
    end else if(current_state == READ_WAIT && next_state == READ_INDEX && mode == 1) begin
        // real start address + (36 * 32) + 3
        // real start address + (22 * 16) + 3
        addr_img_conv_end <= (matrix_idx << (6 + 2 * matrix_size_reg)) + ((8 << matrix_size_reg) + 4) * (8 << matrix_size_reg) + 3;
    end
end

//==============================================//
//          counter number of invalid2          //
//==============================================//
// 4-bit counter_invalid2
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter_invalid2 <= 0;
    end else if (current_state == READ_INDEX) begin
        counter_invalid2 <= counter_invalid2 + 1;
    end else if (current_state == IDLE) begin
        counter_invalid2 <= 0;
    end
end

//==============================================//
//        image address valid or invalid        //
//==============================================//
// image address lower bound
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_img_lower_bound <= 0;
    end else if (current_state == READ_WAIT && next_state == READ_INDEX && mode == 1) begin
        // real start address
        addr_img_lower_bound <= matrix_idx << (6 + 2 * matrix_size_reg);
    end else if (current_state == IDLE) begin
        addr_img_lower_bound <= 0;
    end
end

// image address upper bound
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_img_upper_bound <= 0;
    end else if (current_state == READ_WAIT && next_state == READ_INDEX && mode == 1) begin
        // real start address + (32 * 32) - 1
        addr_img_upper_bound <= (matrix_idx << (6 + 2 * matrix_size_reg)) + (8 << matrix_size_reg) * (8 << matrix_size_reg) - 1;
    end else if (current_state == IDLE) begin
        addr_img_upper_bound <= 0;
    end
end

// addr_img_prev
always @(posedge clk) begin
    addr_img_prev <= addr_img;
end

// zero_flag
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        zero_flag <= 0;
    end else if (current_state == DECONV_OUT && addr_img == addr_img_next_row) begin
        zero_flag <= 1;
    end else if(current_state == DECONV_INIT || current_state == DECONV_LEFT) begin
        zero_flag <= 0;
    end
end



//==============================================//
//                Output Block                  //
//==============================================//
// ouput_flag
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        output_flag <= 0;
    end else if (next_state == READ_WAIT || next_state == IDLE) begin
        output_flag <= 0;
    // mode 0 - convolution
    end else if (current_state == CONV_MAX) begin
        output_flag <= 1;
    end else if(current_state == CONV_INIT) begin
        output_flag <= 0;
    
    // mode 1 - deconvolution
    end else if(current_state == DECONV_MAX) begin
        output_flag <= 1;
    end
end



always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
        out_value <= 0;
    end else if (output_flag) begin
        out_valid <= 1;
        out_value <= max_reg[0];
    end else begin
        out_valid <= 0;
        out_value <= 0;
    end
end

endmodule

//==========================================//
//             Memory Module                //
//==========================================//
// 32 * 32 * 16 single-port SRAM
module sram_1024x16_inst(A, DO, DI, CK, WEB, OE, CS);
input [13:0] A;
input [7:0] DI;
input CK, CS, OE, WEB;
output [7:0] DO;

    SRAM_32_32_16 U0(
        .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .A4(A[4]), .A5(A[5]), .A6(A[6]),
        .A7(A[7]), .A8(A[8]), .A9(A[9]), .A10(A[10]), .A11(A[11]), .A12(A[12]), .A13(A[13]), 
        .DO0(DO[0]), .DO1(DO[1]), .DO2(DO[2]), .DO3(DO[3]), 
        .DO4(DO[4]), .DO5(DO[5]), .DO6(DO[6]), .DO7(DO[7]), 
        .DI0(DI[0]), .DI1(DI[1]), .DI2(DI[2]), .DI3(DI[3]), 
        .DI4(DI[4]), .DI5(DI[5]), .DI6(DI[6]), .DI7(DI[7]), 
        .CK(CK), .WEB(WEB), .OE(OE), .CS(CS)
    );
endmodule

// // 5 * 5 * 16 single-port SRAM
module sram_32x16_inst(A, DO, DI, CK, WEB, OE, CS);
input [8:0] A;
input [7:0] DI;
input CK, CS, OE, WEB;
output [7:0] DO;

    SRAM_5_5_16 U1(
        .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .A4(A[4]), 
        .A5(A[5]), .A6(A[6]), .A7(A[7]), .A8(A[8]), 
        .DO0(DO[0]), .DO1(DO[1]), .DO2(DO[2]), .DO3(DO[3]), 
        .DO4(DO[4]), .DO5(DO[5]), .DO6(DO[6]), .DO7(DO[7]), 
        .DI0(DI[0]), .DI1(DI[1]), .DI2(DI[2]), .DI3(DI[3]), 
        .DI4(DI[4]), .DI5(DI[5]), .DI6(DI[6]), .DI7(DI[7]), 
        .CK(CK), .WEB(WEB), .OE(OE), .CS(CS)
    );
endmodule