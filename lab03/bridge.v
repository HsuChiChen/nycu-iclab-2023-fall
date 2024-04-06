//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2023 ICLAB Fall Course
//   Lab03      : BRIDGE
//   Author     : Ting-Yu Chang
//                
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : BRIDGE_encrypted.v
//   Module Name : BRIDGE
//   Release version : v1.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module BRIDGE(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    direction,
    addr_dram,
    addr_sd,
    // Output Signals
    out_valid,
    out_data,
    // DRAM Signals
    AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY,
	AR_READY, R_VALID, R_RESP, R_DATA, AW_READY, W_READY, B_VALID, B_RESP,
    // SD Signals
    MISO,
    MOSI
);

// Input Signals
input clk, rst_n;
input in_valid;
input direction;
input [12:0] addr_dram;
input [15:0] addr_sd;

// Output Signals
output reg out_valid;
output reg [7:0] out_data;

// DRAM Signals
// write address channel
output reg [31:0] AW_ADDR;
output reg AW_VALID;
input AW_READY;
// write data channel
output reg W_VALID;
output reg [63:0] W_DATA;
input W_READY;
// write response channel
input B_VALID;
input [1:0] B_RESP;
output reg B_READY;
// read address channel
output reg [31:0] AR_ADDR;
output reg AR_VALID;
input AR_READY;
// read data channel
input [63:0] R_DATA;
input R_VALID;
input [1:0] R_RESP;
output reg R_READY;

// SD Signals
input MISO;
output reg MOSI;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
parameter   IDLE                   = 5'd0,
            READ                   = 5'd1,
            DRAM_READ_VALID        = 5'd2, // direction = 0: DRAM -> SD, ie. read operation of DRAM
            DRAM_READ_READY        = 5'd3,
            SD_COMMAND             = 5'd4,
            SD_WAIT_RESPONSE       = 5'd5,
            SD_WAIT_DATA           = 5'd6,
            SD_WAIT_DATA_END       = 5'd7,
            SD_WAIT_DATA_READ      = 5'd8, // direction = 1: SD -> DRAM, ie. read  operation of SD
            SD_DATA_READ           = 5'd9,
            SD_DATA_WRITE          = 5'd10, // direction = 0: DRAM -> SD, ie. write operation of SD
            SD_DATA_WRITE_END      = 5'd11,
            SD_WAIT_RESPONSE_2     = 5'd12,
            SD_WAIT_RESPONSE_2_END = 5'd13,
            OUT_VALID              = 5'd14,
            // direction = 1: SD -> DRAM, ie. read  operation of SD
            SD_DATA_READ_END       = 5'd15,
            DRAM_WRITE_VALID       = 5'd16,
            DRAM_WRITE_READY       = 5'd17,
            DRAM_WRITE_RESPONSE    = 5'd18;


//==============================================//
//            FSM State Declaration             //
//==============================================//
reg [4:0] current_state, next_state;

//==============================================//
//           reg & wire declaration             //
//==============================================//
// counter for SD_COMMAND, SD_WAIT_DATA, SD_WAIT_RESPONSE_2, OUT_VALID
reg [10:0] counter;

// read data from pattern.v in the beginning
reg [12:0] addr_dram_reg;
reg [15:0] addr_sd_reg;
reg direction_reg;

// read data of DRAM
reg [63:0] transfer_data;

// write command to SD
reg [39:0] CRC7_input;
wire [47:0] SD_read_write_cmd;
reg [47:0] SD_read_write_cmd_reg;

// write data to SD
wire [87:0] SD_write_data;
reg [87:0] SD_write_data_reg;

//==============================================//
//           CRC Calculation Module             //
//==============================================//
// CRC-7 function
function automatic [6:0] CRC7;  // Return 7-bit result
    input [39:0] data;  // 40-bit data input
    reg [6:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 7'h9;  // x^7 + x^3 + 1

    begin
        crc = 7'd0;
        for (i = 0; i < 40; i = i + 1) begin
            data_in = data[39-i];
            data_out = crc[6];
            crc = crc << 1;  // Shift the CRC
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC7 = crc;
    end
endfunction

// CRC-16-CCITT function
function automatic [15:0] CRC16_CCITT; // Return 16-bit result
    input [63:0] data; // 64-bit data input
    reg [15:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 16'h1021;  // x^16 + x^12 + x^5 + 1
    
    begin
        crc = 16'd0;
        for (i = 0; i < 64; i = i + 1) begin
            data_in = data[63-i];
            data_out = crc[15];
            crc = crc << 1;  // Shift the CRC
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC16_CCITT = crc;
    end
endfunction

//==============================================//
//             FSM State Transition             //
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
            // direction = 1: SD -> DRAM, ie. read  operation of SD
            if(direction_reg) next_state = SD_COMMAND;
            // direction = 0: DRAM -> SD, ie. write operation of SD
            else next_state = DRAM_READ_VALID;
        end
        DRAM_READ_VALID: begin
            if(AR_READY) next_state = DRAM_READ_READY;
            else next_state = DRAM_READ_VALID;
        end
        DRAM_READ_READY: begin
            if(R_VALID) next_state = SD_COMMAND;
            else next_state = DRAM_READ_READY;
        end
        SD_COMMAND: begin
            if(counter == 47) next_state = SD_WAIT_RESPONSE;
            else next_state = SD_COMMAND;
        end
        SD_WAIT_RESPONSE: begin
            if(MISO) next_state = SD_WAIT_RESPONSE;
            else next_state = SD_WAIT_DATA; // response from SD is 0
        end
        SD_WAIT_DATA: begin
            if(counter == 12)begin
                next_state = SD_WAIT_DATA_END;
            end
            else next_state = SD_WAIT_DATA;
        end
        SD_WAIT_DATA_END : begin
            // direction = 1: SD -> DRAM, ie. read  operation of SD
            if(direction_reg) next_state = SD_WAIT_DATA_READ;
            // direction = 0: DRAM -> SD, ie. write operation of SD
            else next_state = SD_DATA_WRITE;
        end
        SD_DATA_WRITE: begin
            if(counter == 87) next_state = SD_DATA_WRITE_END;
            else next_state = SD_DATA_WRITE;
        end
        SD_DATA_WRITE_END: begin
            next_state = SD_WAIT_RESPONSE_2;
        end
        SD_WAIT_RESPONSE_2: begin
            if(counter > 8 && MISO == 1) next_state = SD_WAIT_RESPONSE_2_END;
            else next_state = SD_WAIT_RESPONSE_2;
        end
        SD_WAIT_RESPONSE_2_END: begin
            next_state = OUT_VALID;
        end
        // direction = 1: SD -> DRAM, ie. read  operation of SD
        SD_WAIT_DATA_READ: begin
            if(MISO == 0) next_state = SD_DATA_READ;
            else next_state = SD_WAIT_DATA_READ;
        end
        SD_DATA_READ: begin
            if(counter == 63) next_state = DRAM_WRITE_VALID;
            else next_state = SD_DATA_READ;
        end
        DRAM_WRITE_VALID: begin
            if(AW_READY) next_state = DRAM_WRITE_READY;
            else next_state = DRAM_WRITE_VALID;
        end
        DRAM_WRITE_READY: begin
            if(W_READY) next_state = DRAM_WRITE_RESPONSE;
            else next_state = DRAM_WRITE_READY;
        end
        DRAM_WRITE_RESPONSE: begin
            if(B_VALID) next_state = OUT_VALID;
            else next_state = DRAM_WRITE_RESPONSE;
        end
        // final state
        OUT_VALID: begin
            if(counter == 7) next_state = IDLE;
            else next_state = OUT_VALID;
        end
        default: next_state = IDLE; // illegal state
    endcase
end

//==============================================//
//     READ PATTERN.v and store in register     //
//==============================================//

// address register of DRAM and SD
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr_dram_reg <= 0;
        addr_sd_reg <= 0;
        direction_reg <= 0;
    end
    else if(current_state == IDLE && next_state == READ) begin
        addr_dram_reg <= addr_dram;
        addr_sd_reg <= addr_sd;
        direction_reg <= direction;
    end
end

//==============================================//
//                  Read DRAM                   //
//==============================================//

// read address channel of DRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        AR_ADDR <= 0;
        AR_VALID <= 0;
    end
    else if(current_state == DRAM_READ_VALID && next_state != DRAM_READ_READY) begin
        AR_ADDR <= addr_dram_reg;
        AR_VALID <= 1;
    end
    else begin
        AR_ADDR <= 0;
        AR_VALID <= 0;
    end
end

// read data channel of DRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        R_READY <= 0;
    end else if(next_state ==  DRAM_READ_READY || (current_state == DRAM_READ_READY && next_state != SD_COMMAND)) begin
        R_READY <= 1;
    end else begin
        R_READY <= 0;
    end
end

// read data channel of DRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        transfer_data <= 0;
    end else if(current_state == DRAM_READ_READY && R_VALID) begin
        transfer_data <= R_DATA;
    end else if (current_state == SD_DATA_READ) begin
        transfer_data <= (transfer_data << 1) | MISO;
    end else if(current_state == IDLE) begin
        transfer_data <= 0;
    end
    // remain the data until the next read
end

//==============================================//
//             Write Command to SD             //
//==============================================//

// write command to SD
always @(*) begin
    // direction = 1: SD -> DRAM, ie. read  operation of SD
    if(direction_reg) begin
        CRC7_input = {2'b01, 6'd17, 16'b0, addr_sd_reg};  // expand addr_sd_reg from 16-bit to 32-bit
    // direction = 0: DRAM -> SD, ie. write operation of SD
    end else begin
        CRC7_input = {2'b01, 6'd24, 16'b0, addr_sd_reg}; // expand addr_sd_reg from 16-bit to 32-bit
    end
end

assign SD_read_write_cmd = {CRC7_input, CRC7(CRC7_input), 1'b1};

// SD_read_write_cmd register
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        SD_read_write_cmd_reg <= 0;
    end
    else if(next_state == SD_COMMAND) begin
        SD_read_write_cmd_reg <= SD_read_write_cmd;
    end
end

//==============================================//
//             Write Data to SD                 //
//==============================================//

// write data to SD
assign SD_write_data = {8'hFE, transfer_data, CRC16_CCITT(transfer_data)};

// SD_write_data register
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        SD_write_data_reg <= 0;
    end
    else if(next_state == SD_DATA_WRITE) begin
        SD_write_data_reg <= SD_write_data;
    end
end

//==============================================//
//                   counter                    //
//==============================================//

// counter for SD_COMMAND, SD_WAIT_DATA, SD_WAIT_RESPONSE_2, OUT_VALID, SD_READ_DATA
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter <= 0;
    end
    else if(current_state == SD_COMMAND         || current_state == SD_WAIT_DATA
         || current_state == SD_WAIT_RESPONSE_2 || current_state == OUT_VALID
         || current_state == SD_DATA_READ       || current_state == SD_DATA_WRITE) begin
        counter <= counter + 1;
    end else begin
        counter <= 0;
    end
end

//==============================================//
//                 MOSI Output                 //
//==============================================//

// output MOSI
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        MOSI <= 1;
    end else if(current_state == SD_COMMAND) begin
        MOSI <= SD_read_write_cmd_reg[47 - counter];
    end else if (current_state == SD_DATA_WRITE) begin
        MOSI <= SD_write_data_reg[87 - counter];
    end else begin
        MOSI <= 1;
    end
end

//==============================================//
//            Write Data to DRAM                //
//==============================================//

// write address channel of DRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  begin
        AW_ADDR <= 0;
        AW_VALID <= 0;
    end else if(current_state == DRAM_WRITE_VALID && next_state != DRAM_WRITE_READY) begin
        AW_ADDR <= addr_dram_reg;
        AW_VALID <= 1;
    end else begin
        AW_ADDR <= 0;
        AW_VALID <= 0;
    end
end

// write data channel of DRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        W_DATA <= 0;
        W_VALID <= 0;
    end else if( next_state ==  DRAM_WRITE_READY || (current_state == DRAM_WRITE_READY && next_state != DRAM_WRITE_RESPONSE)) begin
        W_DATA <= transfer_data;
        W_VALID <= 1;
    end else begin
        W_DATA <= 0;
        W_VALID <= 0;
    end
end

// write response channel of DRAM
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        B_READY <= 0;
    end else if((current_state == DRAM_WRITE_READY || current_state == DRAM_WRITE_RESPONSE) && next_state != OUT_VALID) begin
        B_READY <= 1;
    end else begin
        B_READY <= 0;
    end
end

//==============================================//
//                 bridge output                //
//==============================================//

// output out_valid
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
    end else if(current_state == OUT_VALID) begin
        out_valid <= 1;
    end else begin
        out_valid <= 0;
    end
end

// output out_data
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_data <= 0;
    end else if(current_state == OUT_VALID && counter == 0) begin
        out_data <= transfer_data[63:56];
    end else if(current_state == OUT_VALID && counter == 1) begin
        out_data <= transfer_data[55:48];
    end else if(current_state == OUT_VALID && counter == 2) begin
        out_data <= transfer_data[47:40];
    end else if(current_state == OUT_VALID && counter == 3) begin
        out_data <= transfer_data[39:32];
    end else if(current_state == OUT_VALID && counter == 4) begin
        out_data <= transfer_data[31:24];
    end else if(current_state == OUT_VALID && counter == 5) begin
        out_data <= transfer_data[23:16];
    end else if(current_state == OUT_VALID && counter == 6) begin
        out_data <= transfer_data[15:8];
    end else if(current_state == OUT_VALID && counter == 7) begin
        out_data <= transfer_data[7:0];
    end else begin
        out_data <= 0;
    end
end


endmodule