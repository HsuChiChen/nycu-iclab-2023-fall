//############################################################################
//   2023 ICLAB Fall Course
//   Final Project : single core Central Processing Unit (CPU)
//   Author        : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date          : 2024.01.08
//   Version       : v1.0
//   File Name     : CPU.v
//   Module Name   : CPU
//############################################################################
// implement with multi-cycle CPU with cache(SRAM) hit/miss mechanism
// compare with pipelined CPU, multi-cycle CPU is easier to implement due to no data hazard

module CPU(
// global signals
				clk,
			  rst_n,
		   IO_stall,
// axi write address channel
         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
// axi write data channel
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
// axi write response channel         
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
// axi read address channel 
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
      arready_m_inf,
// axi read data channel 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);

//==============================================//
//          Input & Output Declaration          //
//==============================================//
// input ports
input  wire clk, rst_n;

// output ports
output reg  IO_stall;

//================================================//
//		  AXI4 Interface Declaration              //
//================================================//
// AXI Interface wire connecttion for pseudo DRAM read/write
// Hint:
// your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
// therefore I declared output of AXI as wire in CPU

// AXI4 Parameter (You can not modify it)
parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf; // 2 * 4-bit
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf; // 2 * 32-bit
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf; // 2 * 7-bit
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf; // 2 * 3-bit
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf; // 2 * 2-bit
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf; // 2 * 1-bit
input   wire [DRAM_NUMBER-1:0]               arready_m_inf; // 2 * 1-bit
// ------------------------
// (2)	axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf; // 2 * 4-bit
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf; // 2 * 16-bit
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf; // 2 * 2-bit
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf; // 2 * 1-bit
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf; // 2 * 1-bit
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf; // 2 * 1-bit

// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf; // 4-bit
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf; // 32-bit
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf; // 3-bit
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf; // 2-bit
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf; // 7-bit
output  reg  [WRIT_NUMBER-1:0]                awvalid_m_inf; // 1-bit // change to reg
input   wire [WRIT_NUMBER-1:0]                awready_m_inf; // 1-bit
// -------------------------
// (2)	axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf; // 16-bit
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf; // 1-bit
output  reg  [WRIT_NUMBER-1:0]                 wvalid_m_inf; // 1-bit // change to reg
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf; // 1-bit
// -------------------------
// (3)	axi write response channel 
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf; // 4-bit
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf; // 2-bit
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf; // 1-bit
output  reg  [WRIT_NUMBER-1:0]                 bready_m_inf; // 1-bit // change to reg

//==============================================//
//    Split AXI4 Interface to each DRAM         //
//==============================================//
// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
wire [3:0] arid_inst, arid_data; // 4-bit
assign arid_m_inf[7:4] = arid_inst;
assign arid_m_inf[3:0] = arid_data;

wire [31:0] araddr_inst, araddr_data; // 32-bit
assign araddr_m_inf[63:32] = araddr_inst;
assign araddr_m_inf[31: 0] = araddr_data;

wire [6:0] arlen_inst, arlen_data; // 7-bit
assign arlen_m_inf[13:7] = arlen_inst;
assign arlen_m_inf[6:0]  = arlen_data;

wire [2:0] arsize_inst, arsize_data; // 3-bit
assign arsize_m_inf[5:3] = arsize_inst;
assign arsize_m_inf[2:0] = arsize_data;

wire [1:0] arburst_inst, arburst_data; // 2-bit
assign arburst_m_inf[3:2] = arburst_inst;
assign arburst_m_inf[1:0] = arburst_data;

reg arvalid_inst, arvalid_data; // 1-bit // change to reg
assign arvalid_m_inf[1] = arvalid_inst;
assign arvalid_m_inf[0] = arvalid_data;

wire arready_inst, arready_data; // 1-bit
assign arready_inst = arready_m_inf[1];
assign arready_data = arready_m_inf[0];
// ------------------------
// (2)	axi read data channel 
wire [3:0] rid_inst, rid_data; // 4-bit
assign rid_inst = rid_m_inf[7:4];
assign rid_data = rid_m_inf[3:0];

wire [15:0] rdata_inst, rdata_data; // 16-bit
assign rdata_inst = rdata_m_inf[31:16];
assign rdata_data = rdata_m_inf[15: 0];

wire [1:0] rresp_inst, rresp_data; // 2-bit
assign rresp_inst = rresp_m_inf[3:2];
assign rresp_data = rresp_m_inf[1:0];

wire rlast_inst, rlast_data; // 1-bit
assign rlast_inst = rlast_m_inf[1];
assign rlast_data = rlast_m_inf[0];

wire rvalid_inst, rvalid_data; // 1-bit
assign rvalid_inst = rvalid_m_inf[1];
assign rvalid_data = rvalid_m_inf[0];

reg rready_inst, rready_data; // 1-bit // change to reg
assign rready_m_inf[1] = rready_inst;
assign rready_m_inf[0] = rready_data;

//==============================================//
//          Constant AXI4 Interface             //
//==============================================//
// 1. read address channel
// 1-1. one master and one slave, so read address ID = 0
assign arid_inst    = 0;
assign arid_data    = 0;
// 1-2. read address of instruction memory and data memory
// 1-3 brust length = 127
assign arlen_inst   = 127;
assign arlen_data   = 127;
// 1-4. burst size = 2^1 = 2 bytes (matched with 16-bit data width in each transfer)
assign arsize_inst  = 1;
assign arsize_data  = 1;
// 1-5. brust type = 1 (incrementing burst)
assign arburst_inst = 1;
assign arburst_data = 1;
// 1-6. read address valid
// 1-7. read ready (from DRAM slave)

// 2. read data channel
// 2-1. one master and one slave, so read ID tag = 0 (from DRAM slave)
// 2-2. read data (from DRAM slave)
// 2-3. read response (from DRAM slave)
// 2-4. read last (from DRAM slave)
// 2-5. read valid (from DRAM slave)
// 2-6. read ready

//==============================================//
// 3. write address channel
// 3-1. one master and one slave, so write address ID = 0
assign awid_m_inf    = 0;
// 3-2. write address of data memory
// 3-3. burst length = 0, turn off burst mode
assign awlen_m_inf   = 0;
// 3-4. burst size = 2^1 = 2 bytes (matched with 16-bit data width in each transfer)
assign awsize_m_inf  = 1;
// 3-5. brust type = 1 (incrementing burst)
assign awburst_m_inf = 1;
// 3-6. write address valid
// 3-7. write ready (from DRAM slave)

// 4. write data channel
// 4-1. write data
// 4-2. write last
// 4-3. write valid
// 4-4. write ready (from DRAM slave)

// 5. write response channel
// 5-1. response ID tag (from DRAM slave)
// 5-2. write response (from DRAM slave)
// 5-3. write response valid (from DRAM slave)
// 5-4. response ready

//==============================================//
//        Core Register Declaration             //
//==============================================//
// Register in each core:
// There are sixteen registers in your CPU. You should not change the name of those registers.
// TA will check the value in each register when your core is not busy.
// If you change the name of registers below, you must get the fail in this lab.
reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;

// DO NOT convert those register into an array form, as it might get optimized out by the design compiler.

//==============================================//
//             Parameter and Integer            //
//==============================================//
// things to do for each instruction
// ADD             : instruction fetch -> instruction decode / register file fetch -> write back to register file -> instruction fetch
// SUB             : instruction fetch -> instruction decode / register file fetch -> write back to register file -> instruction fetch
// Set less than   : instruction fetch -> instruction decode / register file fetch -> write back to register file -> instruction fetch
// Mult            : instruction fetch -> instruction decode / register file fetch -> write back to register file -> instruction fetch
// Load            : instruction fetch -> instruction decode / register file fetch -> address calculation -> data load -> write back to register file -> instruction fetch
// Store           : instruction fetch -> instruction decode / register file fetch -> address calculation -> data store -> instruction fetch
// Branch on equal : instruction fetch -> instruction decode / register file fetch -> compare register data -> instruction fetch
// Jump            : instruction fetch -> instruction decode / compose target address -> instruction fetch

// finite state machine
// ADD             : INST_FETCH -> INST_DECODE -> EXECUTE -> WRITE_BACK -> INST_FETCH
// SUB             : INST_FETCH -> INST_DECODE -> EXECUTE -> WRITE_BACK -> INST_FETCH
// Set less than   : INST_FETCH -> INST_DECODE -> EXECUTE -> WRITE_BACK -> INST_FETCH
// Mult            : INST_FETCH -> INST_DECODE -> EXECUTE -> WRITE_BACK -> INST_FETCH
// Load            : INST_FETCH -> INST_DECODE -> EXECUTE -> DATA_LOAD  -> WRITE_BACK -> INST_FETCH
// Store           : INST_FETCH -> INST_DECODE -> EXECUTE -> DATA_STORE -> INST_FETCH
// Branch on equal : INST_FETCH -> INST_DECODE -> EXECUTE -> INST_FETCH
// Jump            : INST_FETCH -> INST_DECODE -> EXECUTE -> INST_FETCH

// instruction cache hit : INST_FETCH -> INST_FETCH_HIT1 -> INST_FETCH_HIT2 -> INST_DECODE
// instruction cache miss: INST_FETCH -> INST_FETCH_REFILL -> ... -> INST_FETCH_REFILL -> INST_FETCH_HIT1 -> INST_FETCH_HIT2 -> INST_DECODE

// data cache hit        : EXECUTE -> DATA_LOAD_HIT -> WRITE_BACK
// data cache miss       : EXECUTE -> DATA_LOAD_REFILL -> ... -> DATA_LOAD_REFILL -> DATA_LOAD_HIT -> WRITE_BACK

parameter 	INST_FETCH        = 0,
			INST_FETCH_REFILL = 1,
			INST_FETCH_HIT1   = 2,
			INST_FETCH_HIT2   = 3,
			INST_DECODE       = 4,
			EXECUTE           = 5,
			WRITE_BACK_RD     = 6,
			WRITE_BACK_RT     = 7,
			DATA_LOAD_REFILL  = 8,
			DATA_LOAD_HIT     = 9,
			DATA_STORE        = 10,
			IDLE	          = 11;

// parameter signed DRAM_OFFSET = 16'h1000;
integer i;

//==============================================//
//                 Reg Declaration              //
//==============================================//
// state register
reg [3:0] current_state;

// "signed" 11-bit current program counter
// 1st ~ 3rd MSB of 16-bit instruction is always 0, so we can discard it
// 4rd MSB of 16-bit instruction is always 1, so we can discard it
// LSB of 16-bit instruction is always 0, so we can discard it
reg signed [10:0] current_pc;

// 16-bit instruction (ie 16-bit CPU)
reg [15:0] instruction;

// "signed" 16-bit register data
reg signed [15:0] rs_data, rt_data, rd_data;

// 4-bit instruction cache tag
// {16-bit 0, 4-bit 0001 (start from DRAM address 0x1000), 4-bit tag, 7-bit instruction cache data, 1-bit 0}
reg [3:0] inst_cache_tag;

// 4-bit data cache tag
// {16-bit 0, 4-bit 0001 (start from DRAM address 0x1000), 4-bit tag, 7-bit data cache data, 1-bit 0}
reg [3:0] data_cache_tag;

// flag indicates a delay in the idle state for one cycle.
reg idle_state_delay1;

//==============================================//
//         Psedo-reg & Wire declaration         //
//==============================================//
// state register
reg [3:0] next_state;

// "signed" 11-bit next program counter
reg signed [10:0] next_pc;

// 3-bit opcode
wire [2:0] opcode;

// 4-bit register address
wire [3:0] rs, rt, rd;

// 1-bit function code
wire func;

// "signed" 5-bit immediate value
wire signed [4:0] immediate;

// 11-bit inst_address (pseudo-direct addressing)
// MSB of 13-bit address is always 1, so we can discard it
// LSB of 13-bit address is always 0, so we can discard it
wire [10:0] inst_address;

// 11-bit data address
wire [10:0] data_address;

// flag indicates instruction cache hit
wire inst_cache_hit;

// flag indicates data cache hit
wire data_cache_hit;

// data cache valid bit
reg data_cache_valid;

//==============================================//
//             Update Current State             //
//==============================================//
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) current_state <= IDLE;
	else current_state <= next_state;
end

//==============================================//
//             Calculate Next State             //
//==============================================//
always @(*) begin
	case(current_state)
		// initial state
		IDLE: next_state = INST_FETCH;

		// 1. instruction fetch (IF stage)
		// judge instruction cache hit or miss
		INST_FETCH: begin
			if(inst_cache_hit) next_state = INST_FETCH_HIT1;
			else next_state = INST_FETCH_REFILL;
		end

		// If instruction cache miss, load all instructions from DRAM to SRAM and update the data cache tag
		// Then, read the desired instruction from SRAM
		INST_FETCH_REFILL: begin
			if(rlast_inst) next_state = INST_FETCH_HIT1;
			else next_state = INST_FETCH_REFILL;
		end

		// read instruction from SRAM first cycle
		INST_FETCH_HIT1: next_state = INST_FETCH_HIT2;

		// read instruction from SRAM second cycle
		INST_FETCH_HIT2: next_state = INST_DECODE;
	
		// 2. decode instruction and fetch register data (ID / RF stage)
		INST_DECODE: next_state = EXECUTE;

		// 3. execute instruction (EX stage)
		EXECUTE: begin
			// load instruction
			// data cache hit
			if(opcode == 3'b010 && data_cache_hit) next_state = DATA_LOAD_HIT;
			// data cache miss
			else if(opcode == 3'b010) next_state = DATA_LOAD_REFILL;

			// store instruction
			else if(opcode == 3'b011) next_state = DATA_STORE;

			// branch on equal instruction
			// jump instruction
			else if(opcode[2] == 1) next_state = INST_FETCH;
			
			// add, sub, set less than, mult instruction (R-type)
			else next_state = WRITE_BACK_RD;
		end

		// 4. memory access (MEM stage)
		// If data cache miss, load all data from DRAM to SRAM and update the data cache tag
		// Then, read the desired data from SRAM
		DATA_LOAD_REFILL: begin
			if(rlast_data) next_state = DATA_LOAD_HIT;
			else next_state = DATA_LOAD_REFILL;
		end

		// read data from SRAM to register
		DATA_LOAD_HIT: next_state = WRITE_BACK_RT;

		// write data from register to SRAM and DRAM (store instruction)
		DATA_STORE: begin
			if(bvalid_m_inf && bready_m_inf) next_state = INST_FETCH;
			else next_state = DATA_STORE;
		end

		// 5. write back (WB stage)
		// write back to register destination (add, sub, set less than, mult instruction)
		WRITE_BACK_RD: next_state = INST_FETCH;
		// write back to register target (load instruction)
		WRITE_BACK_RT: next_state = INST_FETCH;

		default: next_state = IDLE; // illegal state
	endcase
end

//==============================================//
//        Update Current Program Counter        //
//==============================================//
// current program counter
always @(posedge clk or negedge rst_n) begin
	// start from DRAM instruction address 0x1000
	if(!rst_n) begin
		current_pc <= 0;
	// update next_pc when instruction fetch is done
	end else if(current_state == EXECUTE) begin
		current_pc <= next_pc;
	end
end

// calculate next program counter
always @(*) begin
	if(opcode == 3'b101) begin
		// jump instruction
		// 16-bit address = {current_pc[15:12], 11-bit address, 1-bit 0}
		next_pc = {4'b0001, inst_address};
	end else if(opcode == 3'b100 && rs_data == rt_data) begin
		// branch on equal instruction
		// brach target = current_pc + 1 + immediate
		next_pc = current_pc + 1 + immediate;
	end else begin
		// other instruction
		next_pc = current_pc + 1;
	end
end

//==============================================//
//               Instruction Fetch              //
//==============================================//
// if instruction cache hit (ie tag match), read instruction from SRAM
// If instruction cache miss, load all instructions from DRAM to SRAM and update the data cache tag
// Then, read the desired instruction from SRAM

// update instruction cache tag after cache hit or cache refill (after cache miss)
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_cache_tag <= 1; // instruction cache must miss in the initial
	end else if(current_state == INST_FETCH_HIT1) begin
		inst_cache_tag <= current_pc[10:7];
	end
end

// instruction cache hit - tag match
assign inst_cache_hit = inst_cache_tag == current_pc[10:7];

//=============================================================//
//   Refill Instruction Cache (DRAM -> SRAM) When Cache Miss   //
//=============================================================//
// 1-2. read address of instruction memory
// In brust mode, only need to give an initial address
// 32-bit read address
// 16-bit 0, 4-bit 0001 (start from DRAM address 0x1000), 4-bit tag, 7-bit cache data, 1-bit 0
assign araddr_inst = {16'd0, 4'b001, current_pc[10:7], 8'b0};


// 1-6. read address valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		arvalid_inst <= 0;
	// after sending the read address to the DRAM, it's ready to receive the read instruction from the DRAM
	end else if(arvalid_inst && arready_inst) begin
		arvalid_inst <= 0;
	// instruction cache miss, then start reading instruction from DRAM to SRAM
	end else if(current_state == INST_FETCH && next_state == INST_FETCH_REFILL) begin
		arvalid_inst <= 1;
	end
end

// 2-6. read ready
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rready_inst <= 0;
	// after sending the read address to the DRAM, it's ready to receive the read instruction from the DRAM
	end else if(arvalid_inst && arready_inst) begin
		rready_inst <= 1;
	// complete reading all the instruction from the DRAM in burst mode
	end else if(rlast_inst) begin
		rready_inst <= 0;
	end
end

//==============================================//
//        Instruction Cache (SRAM) Module       //
//==============================================//
// address
reg [6:0] sram_inst_address;
// data in
wire [15:0] sram_inst_in;
// data out
wire [15:0] sram_inst_out;
// write enable (active low)
wire sram_inst_wen;

SUMA180_128X16X1BM1_inst SRAM_inst(	.A(sram_inst_address), .DO(sram_inst_out), .DI(sram_inst_in), 
									.CK(clk), .WEB(sram_inst_wen), .OE(1'b1), .CS(1'b1));

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		sram_inst_address <= 0;
	// read disired instruction (SRAM -> register) in one cycle
	end else if(next_state == INST_FETCH_HIT1) begin
		sram_inst_address <= current_pc[6:0];
	
	// write all instructions (DRAM -> SRAM) in burst mode
	end else if(rready_inst && rvalid_inst) begin
		sram_inst_address <= sram_inst_address + 1;
	
	// reset address to 0 after reading all instructions (DRAM -> SRAM)
	end else begin
		sram_inst_address <= 0;
	end
end

// add dummy mux to avoid timing violation
// assign sram_inst_in = rdata_inst;
// DRAM data out -> SRAM data in
assign sram_inst_in = (current_state == INST_FETCH_REFILL) ? rdata_inst : 0;

// write data (DRAM -> SRAM) in burst mode
assign sram_inst_wen = !(rready_inst && rvalid_inst);

// SRAM data out -> instruction register
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		instruction <= 0;
	end else if(current_state == INST_FETCH_HIT2) begin
		instruction <= sram_inst_out;
	end
end

//==============================================//
//  Instruction decode & Register File Fetch    //
//==============================================//
// 1. instruction decode
assign opcode       = instruction[15:13];
assign rs           = instruction[12: 9];
assign rt           = instruction[ 8: 5];
assign rd           = instruction[ 4: 1];
assign func         = instruction[    0];
assign immediate    = instruction[ 4: 0];
assign inst_address = instruction[11: 1];
// MSB of 13-bit address is always 1, so we can discard it
// LSB of 13-bit address is always 0, so we can discard it

// 2. register file fetch
// register sorce data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rs_data <= 0;
	else if (current_state == INST_DECODE) begin
		case(rs)
			0:  rs_data <= core_r0 ;
			1:  rs_data <= core_r1 ;
			2:  rs_data <= core_r2 ;
			3:  rs_data <= core_r3 ;
			4:  rs_data <= core_r4 ;
			5:  rs_data <= core_r5 ;
			6:  rs_data <= core_r6 ;
			7:  rs_data <= core_r7 ;
			8:  rs_data <= core_r8 ;
			9:  rs_data <= core_r9 ;
			10: rs_data <= core_r10;
			11: rs_data <= core_r11;
			12: rs_data <= core_r12;
			13: rs_data <= core_r13;
			14: rs_data <= core_r14;
			15: rs_data <= core_r15;
		endcase
	end
end

// register target data
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) rt_data <= 0;
	else if (current_state == INST_DECODE) begin
		case(rt)
			0:  rt_data <= core_r0 ;
			1:  rt_data <= core_r1 ;
			2:  rt_data <= core_r2 ;
			3:  rt_data <= core_r3 ;
			4:  rt_data <= core_r4 ;
			5:  rt_data <= core_r5 ;
			6:  rt_data <= core_r6 ;
			7:  rt_data <= core_r7 ;
			8:  rt_data <= core_r8 ;
			9:  rt_data <= core_r9 ;
			10: rt_data <= core_r10;
			11: rt_data <= core_r11;
			12: rt_data <= core_r12;
			13: rt_data <= core_r13;
			14: rt_data <= core_r14;
			15: rt_data <= core_r15;
		endcase
	end
end

//==============================================//
//                   Execute                    //
//==============================================//
// register destination data
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) rd_data <= 0;
	else if(current_state == EXECUTE) begin
		if(opcode == 3'b000) begin
			if(func == 1'b0) begin
				// add instruction
				rd_data <= rs_data + rt_data;
			end else begin
				// sub instruction
				rd_data <= rs_data - rt_data;
			end
		end else if(opcode == 3'b001) begin
				if(func == 1'b0) begin
					// set less than instruction
					if(rs_data < rt_data) rd_data <= 16'h0001;
					else rd_data <= 16'h0000;
				end else begin
					// mult instruction
					rd_data <= rs_data * rt_data;
			end
		end
	end
end

//==============================================//
//         Memory Access - Data Load            //
//==============================================//
// if data cache hit (ie tag match), read data from SRAM
// If data cache miss, load all data from DRAM to SRAM and update the data cache tag
// Then, read the desired data from SRAM

// update data cache tag after cache hit or cache refill (after cache miss)
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_cache_tag <= 0;
	end else if(current_state == DATA_LOAD_HIT) begin
		data_cache_tag <= data_address[10:7];
	end
end

// data cache valid bit
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_cache_valid <= 0;  // initial instruction cache must miss
	end else if(current_state == DATA_LOAD_HIT) begin
		data_cache_valid <= 1;
	end
end

// data cache hit - tag match and valid bit is 1
assign data_cache_hit = (data_cache_tag == data_address[10:7]) && data_cache_valid;


//======================================================//
//   Refill Data Cache (DRAM -> SRAM) When Cache Miss   //
//======================================================//
// 1-2. read address of data memory
// In brust mode, only need to give an initial address
// 32-bit read address
// 16-bit 0, 4-bit 0001 (start from DRAM address 0x1000), 4-bit tag, 7-bit cache data, 1-bit 0
assign araddr_data = {16'd0, 4'b001, data_address[10:7], 8'b0};

// 1-6. read address valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		arvalid_data <= 0;
	// after sending the read address to the DRAM, it's ready to receive the read data from the DRAM
	end else if(arvalid_data && arready_data) begin
		arvalid_data <= 0;
	// data cache miss, then start reading data from DRAM to SRAM
	end else if(current_state == EXECUTE && next_state == DATA_LOAD_REFILL) begin
		arvalid_data <= 1;
	end
end

// 2-6. read ready
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rready_data <= 0;
	// after sending the read address to the DRAM, it's ready to receive the read data from the DRAM
	end else if(arvalid_data && arready_data) begin
		rready_data <= 1;
	// complete reading all the data from the DRAM in burst mode
	end else if(rlast_data) begin
		rready_data <= 0;
	end
end

//==============================================//
//           Data Cache (SRAM) Module           //
//==============================================//
// address
reg [6:0] sram_data_address;
// data in
wire [15:0] sram_data_in;
// data out
wire signed [15:0] sram_data_out;
// write enable (active low)
wire sram_data_wen;

SUMA180_128X16X1BM1_inst SRAM_data(	.A(sram_data_address), .DO(sram_data_out), .DI(sram_data_in), 
									.CK(clk), .WEB(sram_data_wen), .OE(1'b1), .CS(1'b1));

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		sram_data_address <= 0;
	// read disired data (SRAM -> register) in one cycle
	end else if(next_state == DATA_LOAD_HIT) begin
		sram_data_address <= data_address[6:0];
	// write all data (DRAM -> SRAM) in burst mode
	end else if(rready_data && rvalid_data) begin
		sram_data_address <= sram_data_address + 1;
	// store data (register -> SRAM) in one cycle
	end else if(current_state == DATA_STORE) begin
		sram_data_address <= data_address[6:0];
	// reset address to 0 after reading all data (DRAM -> SRAM)
	end else begin
		sram_data_address <= 0;
	end
end

// load data (DRAM data out -> SRAM data in) in burst mode
// store data (rt register -> SRAM) in one cycle
assign sram_data_in = (current_state == DATA_STORE) ? rt_data : rdata_data;

// write data (DRAM -> SRAM) in burst mode
// store data (register -> SRAM) in one cycle when data cache hit
assign sram_data_wen = !((rready_data && rvalid_data) || (current_state == DATA_STORE && data_cache_hit));

//=================================================//
//  Memory Access - Data Store (Register -> DRAM)  //
//================================================//
// directly write data from register to DRAM

// data address = (rs_data + immediate + DRAM_OFFSET_div2) * 2
assign data_address = rs_data + immediate;

// 3-2. write address of data memory
// In brust mode, only need to give an initial address
// 32-bit write address
// 16-bit 0, 4-bit 0001 (start from DRAM address 0x1000), 11-bit data_address, 1-bit 0
assign awaddr_m_inf = {16'd0, 4'b0001, data_address, 1'b0};

// 3-6. write address valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		awvalid_m_inf <= 0;
	// after sending the write address to the DRAM, it's ready to give write data from the DRAM
	end else if(awvalid_m_inf && awready_m_inf) begin
		awvalid_m_inf <= 0;
	// write data (register -> DRAM) in one cycle
	end else if(next_state == DATA_STORE && current_state != DATA_STORE) begin
		awvalid_m_inf <= 1;
	end
end

// 4-1. write data
// write rt_data (register -> DRAM)
assign wdata_m_inf = rt_data;

// 4-2. write last
// last write data is also the first write data
assign wlast_m_inf = wvalid_m_inf;

// 4-3. write valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		wvalid_m_inf <= 0;
	// wait for the DRAM to be ready to receive the write data
	end else if(wready_m_inf && wvalid_m_inf) begin
		wvalid_m_inf <= 0;
	// after sending the write address to the DRAM, it's ready to write data to the DRAM
	end else if(awvalid_m_inf && awready_m_inf) begin
		wvalid_m_inf <= 1;
	end
end

// 5-4. response ready
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		bready_m_inf <= 0;
	// finish writing data to DRAM
	end else if(bready_m_inf && bvalid_m_inf) begin
		bready_m_inf <= 0;
	// after sending the write address to the DRAM, it's ready to receive the response from the DRAM
	end else if(awvalid_m_inf && awready_m_inf) begin
		bready_m_inf <= 1;
	end
end

//==============================================//
//         Write Back to Register File          //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
		core_r0  <= 0;
		core_r1  <= 0;
		core_r2  <= 0;
		core_r3  <= 0;
		core_r4  <= 0;
		core_r5  <= 0;
		core_r6  <= 0;
		core_r7  <= 0;
		core_r8  <= 0;
		core_r9  <= 0;
		core_r10 <= 0;
		core_r11 <= 0;
		core_r12 <= 0;
		core_r13 <= 0;
		core_r14 <= 0;
		core_r15 <= 0;
	// write back to register destination (add, sub, set less than, mult instruction)
	end else if (current_state == WRITE_BACK_RD) begin
		case(rd)
			0:  core_r0  <= rd_data;
			1:  core_r1  <= rd_data;
			2:  core_r2  <= rd_data;
			3:  core_r3  <= rd_data;
			4:  core_r4  <= rd_data;
			5:  core_r5  <= rd_data;
			6:  core_r6  <= rd_data;
			7:  core_r7  <= rd_data;
			8:  core_r8  <= rd_data;
			9:  core_r9  <= rd_data;
			10: core_r10 <= rd_data;
			11: core_r11 <= rd_data;
			12: core_r12 <= rd_data;
			13: core_r13 <= rd_data;
			14: core_r14 <= rd_data;
			15: core_r15 <= rd_data;	
		endcase
	// write back to register target (load instruction)
	end else if (current_state == WRITE_BACK_RT) begin
		case(rt)
			0:  core_r0  <= sram_data_out;
			1:  core_r1  <= sram_data_out;
			2:  core_r2  <= sram_data_out;
			3:  core_r3  <= sram_data_out;
			4:  core_r4  <= sram_data_out;
			5:  core_r5  <= sram_data_out;
			6:  core_r6  <= sram_data_out;
			7:  core_r7  <= sram_data_out;
			8:  core_r8  <= sram_data_out;
			9:  core_r9  <= sram_data_out;
			10: core_r10 <= sram_data_out;
			11: core_r11 <= sram_data_out;
			12: core_r12 <= sram_data_out;
			13: core_r13 <= sram_data_out;
			14: core_r14 <= sram_data_out;
			15: core_r15 <= sram_data_out;
		endcase
	end
end

//==============================================//
//               Output Control                 //
//==============================================//
// flag indicates a delay in the idle state for one cycle.
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) idle_state_delay1 <= 0;
	else idle_state_delay1 <= current_state == IDLE;
end

// IO_stall
// Pull high when core is busy
// Pull low for one cycle whenever you finished an instruction
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) IO_stall <= 1'b1;
	else if(current_state == INST_FETCH && !idle_state_delay1) IO_stall <= 1'b0;
	else IO_stall <= 1'b1;
end

endmodule

//================================================//
//                Memory IP - SRAM                //
//================================================//
// 128 word * 16 bit SRAM
// 128 = 2^7 cache line (=cache address)
// 16  = 2^4 byte per cache line for 16-bit instruction or data width

// total DRAM address = 2^11 * 16-bit = 2^12 byte
// Thorefore, we need 2(11 - 7) = 2^4 = 16 bit cache tag
module SUMA180_128X16X1BM1_inst(A, DO, DI, CK, WEB, OE, CS);

input [6:0] A;
input [15:0] DI;
input CK, CS, OE, WEB;
output [15:0] DO;

    SUMA180_128X16X1BM1 U0(
		// 7-bit address
        .A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .A4(A[4]), .A5(A[5]), .A6(A[6]),
        
		// 16-bit data out
		.DO0(DO[0]), .DO1(DO[1]), .DO2(DO[2]), .DO3(DO[3]),
        .DO4(DO[4]), .DO5(DO[5]), .DO6(DO[6]), .DO7(DO[7]),
		.DO8(DO[8]), .DO9(DO[9]), .DO10(DO[10]), .DO11(DO[11]),
		.DO12(DO[12]), .DO13(DO[13]), .DO14(DO[14]), .DO15(DO[15]),

		// 16-bit data in
        .DI0(DI[0]), .DI1(DI[1]), .DI2(DI[2]), .DI3(DI[3]),
        .DI4(DI[4]), .DI5(DI[5]), .DI6(DI[6]), .DI7(DI[7]),
		.DI8(DI[8]), .DI9(DI[9]), .DI10(DI[10]), .DI11(DI[11]),
		.DI12(DI[12]), .DI13(DI[13]), .DI14(DI[14]), .DI15(DI[15]), 
        
		// control signal
		.CK(CK), .WEB(WEB), .OE(OE), .CS(CS)
    );

endmodule