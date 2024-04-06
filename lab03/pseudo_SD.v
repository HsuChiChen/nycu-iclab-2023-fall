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
//   File Name   : pseudo_SD.v
//   Module Name : pseudo_SD
//   Release version : v1.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module pseudo_SD (
    clk,
    MOSI,
    MISO
);

input clk;
input MOSI;
output reg MISO;

//////////////////////////////////////////////////////////////////////

// register for command
reg [63:0] SD [0:65535];
reg [5:0] CMD;
reg [31:0] addr_sd;
reg [39:0] CRC7_input;
reg [6:0] CRC7_receive;

// register for data block
reg [7:0]  start_token;
reg [63:0] read_write_sd_data;
reg [15:0] CRC16_CCITT_receive;
reg [7:0]  data_respone;

// parameter and variable
parameter SD_p_r = "../00_TESTBED/SD_init.dat";
real CYCLE = `CYCLE_TIME;
integer i; // loop counter
integer t; // time at random
integer latency; // wait latency

//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////

// SPEC SD-1: Command format should be correct.
// SPEC SD-2: The address should be within the legal range (0~65535).
// SPEC SD-3: CRC-7 check should be correct.
// SPEC SD-4: CRC-16-CCITT check should be correct.
// SPEC SD-5: Time between each transmission should be correct. (Only integer time units is allowed).

// read SD_init.dat initial signals
initial begin
    // read SD_init.dat
    $readmemh(SD_p_r, SD);

    // MISO is 1
    MISO = 1'b1;

    // register for command
    CMD = 0;
    addr_sd = 0;
    CRC7_receive = 0;

    // register for data block
    start_token = 8'hFE;
    read_write_sd_data = 0;
    CRC16_CCITT_receive = 0;
    data_respone = 8'b00000101;
end

// read MOSI
always @(negedge clk) begin
    // start bit is 0
    if (MOSI === 1'b0) begin
       read_write_task;
    end
    // else idle
end

//////////////////////////////////////////////////////////////////////
// command format
// type                    valid value
// 1-bit start bit         0
// 1-bit transmission bit  1
// 6-bit CMD               17 (for read) or 24 (for write)
// 32-bit addr_sd          0 ~ 65535
// 7-bit CRC-7             CRC7({start bit, transmission bit, CMD, addr_sd})
// 1-bit end bit           1

task read_write_task; begin
    #CYCLE; // 1 cycles

    // 1-bit transmission bit should be 1
    if(MOSI === 1'b0) begin
        command_fail_task;
    end
    #CYCLE; // 1 cycle

    // 6-bit CMD
    for(i = 0; i < 6; i = i + 1) begin
        CMD = (CMD << 1) + MOSI; // operator precedence : + is prior to <<
        #CYCLE; // 1 cycle
    end

    // 32-bit addr_sd
    for(i = 0; i < 32; i = i + 1) begin
        addr_sd = (addr_sd << 1) + MOSI;
        #CYCLE; // 1 cycle
    end

    // verify if address of DRAM is within the legal range (0 ~ 65535)
    if(addr_sd > 65535) begin
        $display("************************************************************");
        $display("*                          FAIL!                            *");    
        $display("*                      SPEC SD-2 FAIL                       *");
        $display("************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    // 7-bit CRC-7
    for(i = 0; i < 7; i = i + 1) begin
        CRC7_receive = (CRC7_receive << 1) + MOSI;
        #CYCLE; // 1 cycle
    end

    // verify if CRC-7 is correct
    CRC7_input = {2'b01, CMD, addr_sd};
    if(CRC7_receive !== CRC7(CRC7_input)) begin
        $display("************************************************************");
        $display("*                          FAIL!                            *");    
        $display("*                      SPEC SD-3 FAIL                       *");
        $display("************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    // end bit should be 1
    if(MOSI === 1'b0) begin
        command_fail_task;
    end

    #CYCLE; // 1 cycle
    // wait 0 ~ 8 units, units = 8 cycles
    // in other words, wait 0 ~ 64 cycles
    t = $urandom_range(0, 8);
    repeat(8 * t) #CYCLE;

    // response 8-bit 0 from SD card
    for(i = 0; i < 8; i = i + 1) begin
        MISO = 0;
        #CYCLE; // 1 cycle
    end
    MISO = 1;

    if(CMD == 17) begin
        read_task;
    end
    else if(CMD == 24) begin
        write_task;
    end
    else begin
        command_fail_task;
    end
end endtask

//////////////////////////////////////////////////////////////////////
// data format in read task
// type                    valid value
// 8-bit start token       0xFE
// 64-bit data block       data from SD[addr_sd]
// 16-bit CRC-16-CCITT     CRC16_CCITT(data block)

task read_task; begin
    // wait 1 ~ 32 units, units = 8 cycles
    // in other words, wait 8 ~ 256 cycles
    t = $urandom_range(1, 32);
    repeat(8 * t) #CYCLE;

    // 8-bit start token
    for(i = 0; i < 8; i = i + 1) begin
        MISO = start_token[7-i]; // MSB first
        #CYCLE; // 1 cycle
    end

    // 64-bit data block
    read_write_sd_data = SD[addr_sd];
    for(i = 0; i < 64; i = i + 1) begin
        MISO = read_write_sd_data[63-i]; // MSB first
        #CYCLE; // 1 cycle
    end

    // 16-bit CRC-16-CCITT
    CRC16_CCITT_receive = CRC16_CCITT(read_write_sd_data);
    for(i = 0; i < 16; i = i + 1) begin
        MISO = CRC16_CCITT_receive[15-i]; // MSB first
        #CYCLE; // 1 cycle
    end

    // return to idle
    MISO = 1;
end endtask

// data format in write task
// type                    valid value
// 8-bit start token       0xFE
// 64-bit data block       data from MOSI
// 16-bit CRC-16-CCITT     CRC16_CCITT(data block)

task write_task; begin
    // wait 1 ~ 32 units, units = 8 cycles
    // in other words, wait 8 ~ 256 cycles
    // 8-bit start token should be 8'hFE = 8'b11111110
    wait_data_block_task;

    // 64-bit data block
    for(i = 0; i < 64; i = i + 1) begin
        read_write_sd_data = (read_write_sd_data << 1) + MOSI;
        #CYCLE; // 1 cycle
    end

    // 16-bit CRC-16-CCITT
    for(i = 0; i < 16; i = i + 1) begin
        CRC16_CCITT_receive = (CRC16_CCITT_receive << 1) + MOSI;
        #CYCLE; // 1 cycle
    end

    // verify if CRC-16-CCITT is correct
    if(CRC16_CCITT_receive !== CRC16_CCITT(read_write_sd_data)) begin
        $display("************************************************************");
        $display("*                          FAIL!                            *");    
        $display("*                      SPEC SD-4 FAIL                       *");
        $display("************************************************************");
        repeat(2) #CYCLE;
        $finish;
    end
    
    // wait 0 units, units = 8 cycles
    // in other words, wait 0 cycles
    // reg [7:0] data_respone = 8'b00000101;
    for(i = 0; i < 8; i = i + 1) begin
        MISO = data_respone[7-i]; // MSB first
        #CYCLE; // 1 cycle
    end

    // busy : keep low until finish writing
    // wait 0 ~ 32 units, units = 8 cycles
    // in other words, wait 0 ~ 256 cycles
    t = $urandom_range(0, 32);
    MISO = 0;
    repeat(8 * t) #CYCLE;
    
    // write data to SD card
    SD[addr_sd] = read_write_sd_data;

    // return to idle
    MISO = 1;
end endtask

// wait 1 ~ 32 units, units = 8 cycles
// in other words, wait 8 ~ 256 cycles
// 8-bit start token should be 8'hFE = 8'b11111110
// until MISO = 0, we can identify the start token

task wait_data_block_task; begin
    latency = 0;
    while(MOSI !== 0) begin
        @(negedge clk);
        latency = latency + 1;
    end
    
    // SPEC SD-5: Time between each transmission should be correct. (Only integer time units is allowed).
    if(latency > (256 + 8)) begin
        $display("********************************************************");     
        $display("                  SPEC SD-5 FAIL                        ");
        $display("*  The wait latency are over 256 cycles  at %8t   *",$time);//over max
        $display("********************************************************");
        repeat(2) #CYCLE;
        $finish;
    end else if(latency < (8 + 8)) begin
        $display("********************************************************");     
        $display("                  SPEC SD-5 FAIL                        ");
        $display("*  The wait latency are less than 8 cycles  at %8t   *",$time);//over max
        $display("********************************************************");
        repeat(2) #CYCLE;
        $finish;
    end else if((latency - 8) % 8 !== 0) begin
        $display("********************************************************");
        $display("                  SPEC SD-5 FAIL                        ");
        $display("*  The wait latency are not multiple of 8 cycles  at %8t   *",$time);//over max
        $display("********************************************************");
        repeat(2) #CYCLE;
        $finish;
    end

    #CYCLE; // 1 cycle
end endtask

//////////////////////////////////////////////////////////////////////

task command_fail_task; begin
    $display("************************************************************");
    $display("*                          FAIL!                            *");    
    $display("*                      SPEC SD-1 FAIL                       *");
    $display("************************************************************");
    repeat(2) #CYCLE;
    $finish;
end endtask

//////////////////////////////////////////////////////////////////////
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

endmodule
