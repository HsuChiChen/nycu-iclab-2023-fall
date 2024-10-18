//############################################################################
//   2023 ICLAB Fall Course
//   Lab06       : Maze Router Accelerator (MRA)
//   Author      : HsuChiChen (chenneil90121@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   Date        : 2023.11.14
//   Version     : v12.0
//   File Name   : MRA.v
//   Module Name : MRA
//############################################################################

module MRA(
	// CHIP IO
	clk            	,
	rst_n          	,
	in_valid       	,
	frame_id        ,
	net_id         	,  
	loc_x          	,  
    loc_y         	,
	cost	 		,		
	busy         	,

    // AXI4 IO
	     arid_m_inf,
	   araddr_m_inf,
	    arlen_m_inf,
	   arsize_m_inf,
	  arburst_m_inf,
	  arvalid_m_inf,
	  arready_m_inf,
	
	      rid_m_inf,
	    rdata_m_inf,
	    rresp_m_inf,
	    rlast_m_inf,
	   rvalid_m_inf,
	   rready_m_inf,
	
	     awid_m_inf,
	   awaddr_m_inf,
	   awsize_m_inf,
	  awburst_m_inf,
	    awlen_m_inf,
	  awvalid_m_inf,
	  awready_m_inf,
	
	    wdata_m_inf,
	    wlast_m_inf,
	   wvalid_m_inf,
	   wready_m_inf,
	
	      bid_m_inf,
	    bresp_m_inf,
	   bvalid_m_inf,
	   bready_m_inf 
);

//==============================================//
//          Input & Output Declaration          //
//==============================================//
// << CHIP io port with system >>
input 			  	clk,rst_n;
input 			   	in_valid;
input  [4:0] 		frame_id;
input  [3:0]       	net_id;
input  [5:0]       	loc_x;
input  [5:0]       	loc_y; 
output reg [13:0] 	cost;
output wire         busy;

//================================================//
//		    AXI4 Interface Declaration		      //
//================================================//
// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
       Your AXI-4 interface could be designed as a bridge in submodule,
	   therefore I declared output of AXI as wire.  
	   Ex: AXI4_interface AXI4_INF(...);
*/

// AXI4 Parameter (You can not modify it)
parameter ID_WIDTH = 4, DATA_WIDTH = 128, ADDR_WIDTH = 32;

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output reg                   arvalid_m_inf; // change to reg
input  wire                  arready_m_inf;
output reg [ADDR_WIDTH-1:0]  araddr_m_inf;  // change to puedo-reg
// ------------------------
// (2)	axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output reg                    rready_m_inf; // change to reg
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;

// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output reg                   awvalid_m_inf; // change to reg
input  wire                  awready_m_inf;
output reg  [ADDR_WIDTH-1:0]  awaddr_m_inf; // change to puedo-reg
// -------------------------
// (2)	axi write data channel 
output reg                    wvalid_m_inf; // change to reg
input  wire                   wready_m_inf;
output wire [DATA_WIDTH-1:0]   wdata_m_inf;
output reg                     wlast_m_inf; // change to reg
// -------------------------
// (3)	axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output reg                    bready_m_inf; // change to reg
input  wire  [1:0]             bresp_m_inf;
// -----------------------------

//==============================================//
//           AXI4 parameter declaration         //
//==============================================//
// 1. read address channel
// 1-1. one master and one slave, so read address ID = 0
assign arid_m_inf    = 0;
// 1-2. read address of location map and weight map
// 1-3. burst length = 127
assign arlen_m_inf   = 127;
// 1-4. burst size = 2^4 = 16 bytes (matched with 128-bit data width in each transfer)
assign arsize_m_inf  = 4;
// 1-5. brust type = 1 (incrementing burst)
assign arburst_m_inf = 1;
// 1-6. read valid
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
// 3-2. write address of location map and weight map
// 3-3. burst length = 127
assign awlen_m_inf   = 127;
// 3-4. burst size = 2^4 = 16 bytes (matched with 128-bit data width in each transfer)
assign awsize_m_inf  = 4;
// 3-5. brust type = 1 (incrementing burst)
assign awburst_m_inf = 1;
// 3-6. write valid
// 3-7. write ready (from DRAM slave)

// 4. write data channel
// 4-1. write data
// 4-2. write last
// 4-3. write valid
// 4-4. write ready (from DRAM slave)

// 5. write response channel
// 5-1. write ID tag (from DRAM slave)
// 5-2. write response (from DRAM slave)
// 5-3. write valid (from DRAM slave)
// 5-4. write ready

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter 	IDLE              = 0,
			DRAM_READ_MAP     = 1,
			DRAM_READ_MAP_END = 2,
			RIPPLE            = 3,
			WAIT_RETRACE      = 4,
			RETRACE_FIRST     = 5,
			RETRACE           = 6,
			DRAM_WRITE_MAP    = 7,
			RIPPLE_INIT       = 8;

integer i, j;

//==============================================//
//                 reg declaration              //
//==============================================//
// state machine
reg [3:0] current_state, next_state;

//==============================================//
// input register
// net_total_num
reg [3:0] net_total_num;

// net proccess number
reg [3:0] net_num_cur;

// 1-bit source or sink
reg source_or_sink_input;

// 5-bit frame id from 0 to 31
reg [4:0] frame_id_reg;

// 4-bit net id from 1 to 15
// one frame has at most 15 nets
reg [3:0] net_id_reg[0:14];

// 6-bit x location of source from 0 to 63
reg [5:0] source_x_reg[0:14];

// 6-bit y location of source from 0 to 63
reg [5:0] source_y_reg[0:14];

// 6-bit x location of sink from 0 to 63
reg [5:0] sink_x_reg[0:14];

// 6-bit y location of sink from 0 to 63
reg [5:0] sink_y_reg[0:14];

//==============================================//
// read weight map in ripple state and wait retrace state
// flag for done of reading weight map
reg read_weight_map_done;

//==============================================//
// ripple state
// add register to rvalid_m_inf
reg blocked [0:31];

// delay 1 cycle of rvalid_m_inf
reg rvaild_m_inf_delay1;

// delay 1 cycle of ripple state
reg ripple_state_delay1;

// delay 2 cycle of ripple state
reg ripple_state_delay2;

// location map
reg [1:0] loc_map_reg[0:63][0:63];

// path count of Lee's algorithm used in ripple state and retrace state
reg [1:0] path_count;

//==============================================//
// retrace state
// current retrace location
reg [5:0] retrace_row, retrace_col;

// add register to retrace_row and retrace_col in location map
reg [5:0] retrace_row_delay1, retrace_col_delay1;

// flag for write retrace path of location map from register to SRAM
reg retrace_write_loc;

//================================================//
// address and data of SRAM
// address of SRAM
reg [6:0] addr_loc, addr_weight;

// data out register of SRAM
reg [127:0] data_out_loc_reg;
// reg [127:0] data_out_weight_reg;

//==============================================//
// after first write, pull down 1 cycle in order to wait SRAM data out delay
reg first_write_pull_down;

//==============================================//
// in_valid delay 1 cycle used in busy signal condition
reg in_valid_delay1;

//==============================================//
//       psedo-reg wire declaration             //
//==============================================//
// retrace state
// currrnt source location
wire [5:0] source_col_cur, source_row_cur;
// current sink location
wire [5:0] sink_col_cur, sink_row_cur;
// current net id
wire [3:0] net_id_cur;

// retrace candidate - left, right, upper, lower
wire [6:0] retrace_row_minus1, retrace_col_minus1;
wire [6:0] retrace_row_plus1, retrace_col_plus1;

// write location back to SRAM
reg [127:0] write_loc_back;

// select 4-bit data from 128-bit data of weight map
wire [3:0] weight_cur;

//==============================================//
// address and data of SRAM
// address of SRAM
wire [6:0] addr_loc_wire, addr_weight_wire;

// calculate next address
reg [6:0] addr_loc_next;

// data out of SRAM
wire [127:0] data_out_loc, data_out_weight;

// data in of SRAM
wire [127:0] data_in_loc, data_in_weight;

// control signal of SRAM
// write enable of SRAM
reg web_loc, web_weight;

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
			// when input is valid, start read frame id, net id, source/sink location from pattern
			if(in_valid) next_state = DRAM_READ_MAP;
			else next_state = current_state;
		end

		// read location map from DRAM to SRAM with AXI4 protocol
		DRAM_READ_MAP: begin
			// when last data of location map is read, start ripple
			if(rlast_m_inf) next_state = DRAM_READ_MAP_END;
			else next_state = current_state;
		end
		// wait last data of location map to be read
		DRAM_READ_MAP_END: begin
			next_state = RIPPLE;
		end
		// ripple from source to sink and read weight map from DRAM to SRAM simultaneously
		RIPPLE: begin
			// when ripple reaches sink, start wait retrace
			if(loc_map_reg[sink_row_cur][sink_col_cur][1]) next_state = WAIT_RETRACE;
			else next_state = current_state;
		end

		// wait for reading weight map from DRAM to SRAM
		WAIT_RETRACE: begin
			// when read weight map is done, start retrace
			if(read_weight_map_done) next_state = RETRACE_FIRST;
			else next_state = current_state;
		end

		// retrace from sink to source
		// find adjacent blocks of sink at the beginning of retrace
		RETRACE_FIRST: begin
			next_state = RETRACE;
		end

		// retrace from adjacent blocks of sink to source
		RETRACE: begin
			// when current retrace location reaches source
			if(retrace_row == source_row_cur && retrace_col == source_col_cur) begin
				// when all nets are processed, start write location map to DRAM
				if(net_num_cur + 1 == net_total_num) next_state = DRAM_WRITE_MAP;
				// when there are still nets to be processed, start ripple and it needs to initialize ripple blocks to 0
				else next_state = RIPPLE_INIT;
			end else begin
				next_state = current_state;
			end
		end

		// initialize ripple blocks to 0
		RIPPLE_INIT: begin
			next_state = RIPPLE;
		end

		// write location map from SRAM to DRAM with AXI4 protocol
		DRAM_WRITE_MAP: begin
			// when DRAM sends write response, turn to idle
			if(bvalid_m_inf) next_state = IDLE;
			else next_state = current_state;
		end

		default: next_state = IDLE; // illegal state
	endcase
end

// delay 1 and 2 cycle of ripple state
always @(posedge clk) begin
	ripple_state_delay1 <= current_state == RIPPLE;
	ripple_state_delay2 <= ripple_state_delay1;
end

//==============================================//
//           Input Register Block               //
//==============================================//
// input is source or sink
always @(posedge clk) begin
	if(in_valid) source_or_sink_input <= ~source_or_sink_input;
	else source_or_sink_input <= 1; // initialize to source
end

// net total number
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		net_total_num <= 0;
	end else if(current_state == IDLE) begin
		net_total_num <= 0;
	end else if(in_valid && ~source_or_sink_input) begin
		net_total_num <= net_total_num + 1;
	end
end

// 5-bit frame id from 0 to 31
always @(posedge clk) begin
	if(in_valid) frame_id_reg <= frame_id;
end

// input is source
always @(posedge clk) begin
	if(in_valid && source_or_sink_input) begin
		net_id_reg[net_total_num] <= net_id;
		source_x_reg[net_total_num] <= loc_x;
		source_y_reg[net_total_num] <= loc_y;
	end
end

// input is sink
always @(posedge clk) begin
	if(in_valid && ~source_or_sink_input) begin
		sink_x_reg[net_total_num] <= loc_x;
		sink_y_reg[net_total_num] <= loc_y;
	end
end

// net proccess number
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		net_num_cur <= 0;
	// initialize to 0
	end else if(current_state == IDLE) begin
		net_num_cur <= 0;
	// end of retrace state
	end else if(current_state == RIPPLE_INIT)begin
		net_num_cur <= net_num_cur + 1;
	end
end

// current source location
assign source_col_cur = source_x_reg[net_num_cur];
assign source_row_cur = source_y_reg[net_num_cur];

// current sink location
assign sink_col_cur = sink_x_reg[net_num_cur];
assign sink_row_cur = sink_y_reg[net_num_cur];

// current net id
assign net_id_cur = net_id_reg[net_num_cur];

//===============================================//
//        Read DRAM with AXI4 protocol 	         //
//===============================================//
// 1-2. read address of location map and weight map
// In brust mode, only need to give an initial address
always @(*) begin
	// If read valid is high, give read address
	if(arvalid_m_inf) begin
		// read location lap from DRAM to SRAM
		if(current_state == DRAM_READ_MAP) begin
			// 32-bit read address
			// 16-bit 1, 5-bit frame id, 11-bit 0
			araddr_m_inf = {16'd1, frame_id_reg, 11'd0};

		// read weight map from DRAM to SRAM
		end else begin
			// 32-bit read address
			// 16-bit 2, 5-bit frame id, 11-bit 0
			araddr_m_inf =  {16'd2, frame_id_reg, 11'd0};
		end
	
	// If read address is not valid, give idle address
	end else begin
		araddr_m_inf = 0;
	end 
end

// 1-6. read valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		arvalid_m_inf <= 0;
	// after sending the read address to the DRAM, it's ready to receive the read data from the DRAM
	end else if(arvalid_m_inf && arready_m_inf) begin
		arvalid_m_inf <= 0;
	// 1. start reading location map and weight map from DRAM to SRAM
	end else if(current_state == IDLE && next_state == DRAM_READ_MAP) begin
		arvalid_m_inf <= 1;
	// 2. start reading weight map from DRAM to SRAM
	end else if(current_state == DRAM_READ_MAP && rlast_m_inf) begin
		arvalid_m_inf <= 1;
	end
end

// 2-6. read ready
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rready_m_inf <= 0;
	// after sending the read address to the DRAM, it's ready to receive the read data from the DRAM
	end else if(arvalid_m_inf && arready_m_inf) begin
		rready_m_inf <= 1;
	// complete reading all the data from the DRAM in burst mode
	end else if(rlast_m_inf) begin
		rready_m_inf <= 0;
	end
end

// flag for done of reading weight map
always @(posedge clk) begin
	if(current_state == IDLE) begin
		read_weight_map_done <= 0;
	end else if(rlast_m_inf && current_state != DRAM_READ_MAP) begin
		read_weight_map_done <= 1;
	end
end

//===============================================//
//         Write DRAM with AXI4 protocol         //
//===============================================//
// 3-2. write address of location map
// In brust mode, only need to give an initial address
always @(*) begin
	// If write valid is high, give read address
	if(awvalid_m_inf) begin
		// write location lap from SRAM to DRAM
		// 32-bit read address
		// 16-bit 1, 5-bit frame id, 11-bit 0
		awaddr_m_inf = {16'd1, frame_id_reg, 11'd0};
	
	// If read address is not valid, give idle address
	end else begin
		awaddr_m_inf = 0;
	end 
end

// 3-6. write valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		awvalid_m_inf <= 0;
	// after sending the write address to the DRAM, it's ready to give write data from the DRAM
	end else if(awvalid_m_inf && awready_m_inf) begin
		awvalid_m_inf <= 0;
	// write location map from SRAM to DRAM
	end else if(current_state == RETRACE && next_state == DRAM_WRITE_MAP) begin
		awvalid_m_inf <= 1;
	end
end

// 4-1. write data
// write location map from SRAM to DRAM
assign wdata_m_inf = data_out_loc_reg;

// 4-2. write last
// wlast_m_inf
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		wlast_m_inf <= 0;
	// wlast_m_inf is high in one cycle
	end else if(wlast_m_inf && wready_m_inf) begin
		wlast_m_inf <= 0;
	// last data of location map to be written to DRAM
	end else if(wvalid_m_inf && addr_loc == 127) begin
		wlast_m_inf <= 1;
	end
end

// 4-3. write valid
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		wvalid_m_inf <= 0;
	// last data of location map to be written to DRAM
	end else if(wready_m_inf && (wlast_m_inf || first_write_pull_down)) begin
		wvalid_m_inf <= 0;
	// after sending the write address to the DRAM, it's ready to write data to the DRAM
	end else if((awvalid_m_inf && awready_m_inf) || wready_m_inf) begin
		wvalid_m_inf <= 1;
	end
end

// first write pull down 1 cycle
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		first_write_pull_down <= 0;
	end else if(current_state == IDLE) begin
		first_write_pull_down <= 1;
	end else if(first_write_pull_down && wready_m_inf) begin
		first_write_pull_down <= 0;
	end
end

// 5-4. response ready
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		bready_m_inf <= 0;
	// last data of location map to be written to DRAM
	end else if(wlast_m_inf) begin
		bready_m_inf <= 1;
	// complete writing all the data to the DRAM in burst mode
	end else if(bvalid_m_inf) begin
		bready_m_inf <= 0;
	end
end

//================================================//
//	    SRAM for location map and weight map      //
//================================================//
// location map
// 64 blocks * 2 blocks * 128 bits single-port SRAM
sram_128x128_inst LOCATION_MAP(.A(addr_loc_wire), .DO(data_out_loc), .DI(data_in_loc), .CK(clk), .WEB(web_loc), .OE(1'b1), .CS(1'b1));

// weight map
// 64 blocks * 2 blocks * 128 bits single-port SRAM
sram_128x128_inst WEIGHT_MAP(.A(addr_weight_wire), .DO(data_out_weight), .DI(data_in_weight), .CK(clk), .WEB(web_weight), .OE(1'b1), .CS(1'b1));

//==============================================//
//           Location Map SRAM control          //
//==============================================//
// calculate next address of sequential logic
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		addr_loc <= 0;
	// initialize to 0
	end else if(current_state == IDLE) begin
		addr_loc <= 0;
	// increment address when rvaild_m_inf is high
	end else if(rvalid_m_inf && current_state == DRAM_READ_MAP) begin
		addr_loc <= addr_loc_next;
	// initialize to 0
	end else if(current_state == WAIT_RETRACE) begin
		addr_loc <= 0;
	// increment address when wready_m_inf is high
	end else if(wready_m_inf) begin
		addr_loc <= addr_loc_next;
	end
end

// calculate next address of combination logic
always @(*) begin
	// read mode
	if(rvalid_m_inf && current_state == DRAM_READ_MAP) begin
		addr_loc_next = addr_loc + 1;
	// write mode
	end else if(wready_m_inf) begin
		addr_loc_next = addr_loc + 1;
	end else begin
		addr_loc_next = addr_loc;
	end
end

// address
// {retrace_row, retrace_col[5]} in retrace state
// addr_loc_next                 in dram write map state
// addr_loc                      in dram read map state (ie other states)
assign addr_loc_wire =	(current_state == RETRACE)? {retrace_row, retrace_col[5]} : 
						(current_state == DRAM_WRITE_MAP)? addr_loc_next : addr_loc;

// data in
// write_loc_back in retrace state
// rdata_m_inf    in dram read map state (ie other states)
assign data_in_loc = (current_state == RETRACE)? write_loc_back : rdata_m_inf;

// data out
// add register to data out
always @(posedge clk) begin
	data_out_loc_reg <= data_out_loc;
end

// control signal
// write enable
always @(*) begin
	// write mode - read location map from DRAM to SRAM
	if(rvalid_m_inf && current_state == DRAM_READ_MAP) begin
		web_loc = 0;
	// write mode - write retrace path from register to SRAM
	end else if(current_state == RETRACE && retrace_write_loc) begin
		web_loc = 0;
	// read mode
	end else begin
		web_loc = 1;
	end
end

//================================================//
//           Weight Map SRAM control             //
//================================================//
// calculate next address
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		addr_weight <= 0;
	// initialize to 0
	end else if(current_state == IDLE) begin
		addr_weight <= 0;
	// increment address
	end else if(rvalid_m_inf && current_state != DRAM_READ_MAP) begin
		addr_weight <= addr_weight + 1;
	end
end

// address
// {retrace_row, retrace_col[5]} in retrace state
// addr_weight                   in dram read map state (ie other states)
assign addr_weight_wire = (current_state == RETRACE)? {retrace_row, retrace_col[5]} : addr_weight;

// data in
// rdata_m_inf in dram read map state (ie all states)
// add dummy selection to fix hold time violation
// assign data_in_weight = rdata_m_inf; // hold time violation occurs
assign data_in_weight = (rvalid_m_inf)? rdata_m_inf : 0;

// unused register
// data out
// always @(posedge clk) begin
// 	data_out_weight_reg <= data_out_weight;
// end

// control signal
// write enable
always @(*) begin
	// write mode - read weight map from DRAM to SRAM
	if(rvalid_m_inf && current_state != DRAM_READ_MAP) begin
		web_weight = 0;
	// read mode - other states
	end else begin
		web_weight = 1;
	end
end

//==============================================//
//                Ripple Block                  //
//==============================================//
// delay 1 cycle of rvaild_m_inf
always @(posedge clk) begin
	rvaild_m_inf_delay1 <= rvalid_m_inf;
end

// add register after calculation of blocked
always @(posedge clk) begin
	for(i = 0; i < 32; i = i + 1) begin
		// if 4-bit data is 0, then it's empty
		// if 4-bit data has any 1, then it's block
		blocked[i] <= |rdata_m_inf[i * 4 +: 4];
	end
end

// add register to retrace_row and retrace_col
always @(posedge clk) begin
	retrace_row_delay1 <= retrace_row;
	retrace_col_delay1 <= retrace_col;
end

// reg [1:0] loc_map_reg[0:63][0:63];
// 0 : empty
// 1 : block
// 2 : state 1 of Lee's algorithm
// 3 : state 2 of Lee's algorithm

always @(posedge clk) begin
	// read location map from DRAM simultaneously
	if(rvaild_m_inf_delay1 && (current_state == DRAM_READ_MAP || current_state == DRAM_READ_MAP_END)) begin
		// read into last row, 2 column, ie from (63, 32) to (63, 63)
		for(i = 32; i < 64; i = i + 1) begin
			// if 4-bit data is 0, then it's empty
			// if 4-bit data has any 1, then it's block
			loc_map_reg[63][i] <= {1'b0, blocked[i - 32]};
		end

		// shift left by 32 bits, ie from 2 column to 1 column
		for(i = 0; i < 64; i = i + 1) begin
			for(j = 0; j < 32; j = j + 1) begin
				loc_map_reg[i][j] <= loc_map_reg[i][j + 32];
			end
		end

		// shift left by 32 bits, ie from (i + 1) row and 1 column to i row and 2 column
		for(i = 0; i < 63; i = i + 1) begin
			for(j = 32; j < 64; j = j + 1) begin
				loc_map_reg[i][j] <= loc_map_reg[i + 1][j - 32];
			end
		end
	
	// set current sink to 0 at the 2 cycle of ripple state
	// ie ripple_state = 1, ripple_state_delay1 = 1, ripple_state_delay2 = 0
	end else if(ripple_state_delay1 && ~ripple_state_delay2) begin
		loc_map_reg[sink_row_cur][sink_col_cur] <= 0;

	// set current source to 2 at the 1 cycle of ripple state
	// ie ripple_state = 1, ripple_state_delay1 = 0
	end else if(current_state == RIPPLE && ~ripple_state_delay1) begin
		loc_map_reg[source_row_cur][source_col_cur] <= 2;
	
	// Lee's algorithmn
	end else if(current_state == RIPPLE) begin
		// 1 ~ 62 row, 1 ~ 62 column
		for(i = 1; i < 63; i = i + 1) begin
			for(j = 1; j < 63; j = j + 1) begin
				// if current block is empty and adjacent blocks is state 1 or state 2
				// 4 adjacent blocks : left (i, j - 1), right (i, j + 1), upper (i + 1, j), lower (i - 1, j)
				// then set current block to state 1 or state 2 depending on path count
				if(loc_map_reg[i][j] == 0 &&  (loc_map_reg[i][j - 1][1] | loc_map_reg[i][j + 1][1] | loc_map_reg[i + 1][j][1] | loc_map_reg[i - 1][j][1])) begin
					loc_map_reg[i][j] <= {1'b1, path_count[1]};
				end
			end
		end

		// 0 row and 63 row, 1 ~ 62 column
		for(j = 1; j < 63; j = j + 1) begin
			// 3 adjacent blocks : left (0, j - 1), right (1, j + 1), lower (1, j)
			if(loc_map_reg[0][j] == 0 && (loc_map_reg[0][j - 1][1] | loc_map_reg[0][j + 1][1] | loc_map_reg[1][j][1])) begin
				loc_map_reg[0][j] <= {1'b1, path_count[1]};
			end

			// 3 adjacent blocks : left (63, j - 1), right (63, j + 1), upper (62, j)
			if(loc_map_reg[63][j] == 0 && (loc_map_reg[63][j - 1][1] | loc_map_reg[63][j + 1][1] | loc_map_reg[62][j][1])) begin
				loc_map_reg[63][j] <= {1'b1, path_count[1]};
			end
		end

		// 1 ~ 62 row, 0 column and 63 column
		for(i = 1; i < 63; i = i + 1) begin
			// 3 adjacent blocks : right (i, 1), upper (i + 1, 0), lower (i - 1, 0)
			if(loc_map_reg[i][0] == 0 && (loc_map_reg[i][1][1] | loc_map_reg[i + 1][0][1] | loc_map_reg[i - 1][0][1])) begin
				loc_map_reg[i][0] <= {1'b1, path_count[1]};
			end

			// 3 adjacent blocks : left (i, 62), upper (i + 1, 63), lower (i - 1, 63)
			if(loc_map_reg[i][63] == 0 && (loc_map_reg[i][62][1] | loc_map_reg[i + 1][63][1] | loc_map_reg[i - 1][63][1])) begin
				loc_map_reg[i][63] <= {1'b1, path_count[1]};
			end
		end

		// 0 row and 0 column
		// 2 adjacent blocks : right (0, 1), lower (1, 0)
		if(loc_map_reg[0][0] == 0 && (loc_map_reg[0][1][1] | loc_map_reg[1][0][1])) begin
			loc_map_reg[0][0] <= {1'b1, path_count[1]};
		end

		// 0 row and 63 column
		// 2 adjacent blocks : left (0, 62), lower (1, 63)
		if(loc_map_reg[0][63] == 0 && (loc_map_reg[0][62][1] | loc_map_reg[1][63][1])) begin
			loc_map_reg[0][63] <= {1'b1, path_count[1]};
		end

		// 63 row and 0 column
		// 2 adjacent blocks : right (63, 1), upper (62, 0)
		if(loc_map_reg[63][0] == 0 && (loc_map_reg[63][1][1] | loc_map_reg[62][0][1])) begin
			loc_map_reg[63][0] <= {1'b1, path_count[1]};
		end

		// 63 row and 63 column
		// 2 adjacent blocks : left (63, 62), upper (62, 63)
		if(loc_map_reg[63][63] == 0 && (loc_map_reg[63][62][1] | loc_map_reg[62][63][1])) begin
			loc_map_reg[63][63] <= {1'b1, path_count[1]};
		end
	
	// set path to 1 at the retrace state
	end else if(current_state == RETRACE) begin
		loc_map_reg[retrace_row_delay1][retrace_col_delay1] <= 1;
	
	// after retracing, initialize ripple blocks to 0
	end else if(current_state == RIPPLE_INIT) begin
		for(i = 0; i < 64; i = i + 1) begin
			for(j = 0; j < 64; j = j + 1) begin
				if(loc_map_reg[i][j][1]) begin
					loc_map_reg[i][j] <= 0;
				end
			end
		end
	end
end

// path count
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		path_count <= 0;
	// initialize to 0
	end else if(current_state == IDLE || current_state == RIPPLE_INIT) begin
		path_count <= 0;
	// transition from ripple state to retrace state
	end else if(current_state == RIPPLE && next_state == WAIT_RETRACE) begin
		// 0 -> 3, 1 -> 2, 2 -> 1, 3 -> 0
		path_count <= ~path_count;
	// ripple state
	end else if(current_state == RIPPLE) begin
		path_count <= path_count + 1;
	// retrace state
	end else if(current_state == RETRACE_FIRST || (current_state == RETRACE && retrace_write_loc)) begin
		path_count <= path_count + 1;
	end
end

//================================================//
//	               Retrace Block                  //
//================================================//
assign retrace_row_minus1 = retrace_row - 1; // upper
assign retrace_col_minus1 = retrace_col - 1; // left
assign retrace_row_plus1  = retrace_row + 1; // lower
assign retrace_col_plus1  = retrace_col + 1; // right

// flip retrace_write_loc every cycle in retrace state
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		retrace_write_loc <= 0;
	end else if(current_state == RETRACE) begin
		retrace_write_loc <= ~retrace_write_loc;
	// initialize to 0, ie read SRAM in the first cycle of retrace state
	end else begin
		retrace_write_loc <= 0;
	end
end

// location map
reg [1:0] loc_map_reg_up, loc_map_reg_down, loc_map_reg_left;


// direction of next retrace location
always @(posedge clk) begin
	loc_map_reg_up   <= loc_map_reg[retrace_row_plus1[5:0]][retrace_col];
	loc_map_reg_down <= loc_map_reg[retrace_row_minus1[5:0]][retrace_col];
	loc_map_reg_left <= loc_map_reg[retrace_row][retrace_col_plus1[5:0]];
end

always @(posedge clk) begin
	// set sink as the initial retrace location
	if(current_state == RIPPLE) begin
		retrace_row <= sink_row_cur;
		retrace_col <= sink_col_cur;
	// retrace next location of sink at the beginning of retrace state
	// retrace when retrace_write_loc = 1
	end else if(current_state == RETRACE_FIRST || (current_state == RETRACE && retrace_write_loc)) begin
		// retrace priority : down (y + 1) > up (y - 1) > right (x + 1) > left (x - 1)

		// down (y + 1)
		// retrace_row_plus1 < 0 means it's out of bound
		if(!retrace_row_plus1[6] && loc_map_reg_up == {1'b1, path_count[1]}) begin
			retrace_row <= retrace_row_plus1[5:0];
		// up (y - 1)
		// retrace_row_minus1 < 0 means it's out of bound
		end else if(!retrace_row_minus1[6] && loc_map_reg_down == {1'b1, path_count[1]}) begin
			retrace_row <= retrace_row_minus1[5:0];
		// right (x + 1)
		// retrace_col_plus1 < 0 means it's out of bound
		end else if(!retrace_col_plus1[6] && loc_map_reg_left == {1'b1, path_count[1]}) begin
			retrace_col <= retrace_col_plus1[5:0];
		// left (x - 1)
		end else begin
			retrace_col <= retrace_col_minus1[5:0];
		end
	end
end

// select 4-bit data from 128-bit data of location map
// replace 4-bit data with current net id
always @(*) begin
	for(i = 0; i < 32; i = i + 1) begin
		if(retrace_col[4:0] == i) begin
			// replace 4-bit data with current net id
			write_loc_back[i*4 +: 4] = net_id_cur;
		end else begin
			// remain the same value
			// write_loc_back[i*4 +: 4] = data_out_loc_reg[i*4 +: 4];
			// output directly assign to input, without register
			write_loc_back[i*4 +: 4] = data_out_loc[i*4 +: 4];
		end
	end
end

// select 4-bit data from 128-bit data of weight map
assign weight_cur = data_out_weight[retrace_col[4:0]*4 +: 4];

//==============================================//
//           Output Block                       //
//==============================================//
// total cost
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cost <= 0;
	// initialize to 0
	end else if(current_state == IDLE) begin
		cost <= 0;
	// add weight of current block to total cost
	end else if(current_state == RETRACE && retrace_write_loc) begin
		cost <= cost + weight_cur;
	end
end

// output busy
// in_valid delay 1 cycle
always@(posedge clk)begin
	in_valid_delay1 <= in_valid;
end

// busy
assign busy = !(in_valid_delay1 || current_state == IDLE);

endmodule

//==========================================//
//             Memory Module                //
//==========================================//
// 128 blocks * 128 bits single-port SRAM
module sram_128x128_inst(A, DO, DI, CK, WEB, OE, CS);
input [6:0] A;
input [127:0] DI;
input CK, CS, OE, WEB;
output [127:0] DO;

	SUMA180_128X128X1BM1 U0 (
		// address
		.A0(A[0]), .A1(A[1]), .A2(A[2]), .A3(A[3]), .A4(A[4]), .A5(A[5]), .A6(A[6]),
		
		// data out
		.DO0(DO[0]), .DO1(DO[1]), .DO2(DO[2]), .DO3(DO[3]), .DO4(DO[4]), .DO5(DO[5]), .DO6(DO[6]), .DO7(DO[7]),
		.DO8(DO[8]), .DO9(DO[9]), .DO10(DO[10]), .DO11(DO[11]), .DO12(DO[12]), .DO13(DO[13]), .DO14(DO[14]), .DO15(DO[15]),
		.DO16(DO[16]), .DO17(DO[17]), .DO18(DO[18]), .DO19(DO[19]), .DO20(DO[20]), .DO21(DO[21]), .DO22(DO[22]), .DO23(DO[23]),
		.DO24(DO[24]), .DO25(DO[25]), .DO26(DO[26]), .DO27(DO[27]), .DO28(DO[28]), .DO29(DO[29]), .DO30(DO[30]), .DO31(DO[31]),
		.DO32(DO[32]), .DO33(DO[33]), .DO34(DO[34]), .DO35(DO[35]), .DO36(DO[36]), .DO37(DO[37]), .DO38(DO[38]), .DO39(DO[39]),
		.DO40(DO[40]), .DO41(DO[41]), .DO42(DO[42]), .DO43(DO[43]), .DO44(DO[44]), .DO45(DO[45]), .DO46(DO[46]), .DO47(DO[47]),
		.DO48(DO[48]), .DO49(DO[49]), .DO50(DO[50]), .DO51(DO[51]), .DO52(DO[52]), .DO53(DO[53]), .DO54(DO[54]), .DO55(DO[55]),
		.DO56(DO[56]), .DO57(DO[57]), .DO58(DO[58]), .DO59(DO[59]), .DO60(DO[60]), .DO61(DO[61]), .DO62(DO[62]), .DO63(DO[63]),
		.DO64(DO[64]), .DO65(DO[65]), .DO66(DO[66]), .DO67(DO[67]), .DO68(DO[68]), .DO69(DO[69]), .DO70(DO[70]), .DO71(DO[71]),
		.DO72(DO[72]), .DO73(DO[73]), .DO74(DO[74]), .DO75(DO[75]), .DO76(DO[76]), .DO77(DO[77]), .DO78(DO[78]), .DO79(DO[79]),
		.DO80(DO[80]), .DO81(DO[81]), .DO82(DO[82]), .DO83(DO[83]), .DO84(DO[84]), .DO85(DO[85]), .DO86(DO[86]), .DO87(DO[87]),
		.DO88(DO[88]), .DO89(DO[89]), .DO90(DO[90]), .DO91(DO[91]), .DO92(DO[92]), .DO93(DO[93]), .DO94(DO[94]), .DO95(DO[95]),
		.DO96(DO[96]), .DO97(DO[97]), .DO98(DO[98]), .DO99(DO[99]), .DO100(DO[100]), .DO101(DO[101]), .DO102(DO[102]), .DO103(DO[103]),
		.DO104(DO[104]), .DO105(DO[105]), .DO106(DO[106]), .DO107(DO[107]), .DO108(DO[108]), .DO109(DO[109]), .DO110(DO[110]), .DO111(DO[111]),
		.DO112(DO[112]), .DO113(DO[113]), .DO114(DO[114]), .DO115(DO[115]), .DO116(DO[116]), .DO117(DO[117]), .DO118(DO[118]), .DO119(DO[119]),
		.DO120(DO[120]), .DO121(DO[121]), .DO122(DO[122]), .DO123(DO[123]), .DO124(DO[124]), .DO125(DO[125]), .DO126(DO[126]), .DO127(DO[127]),
		
		// data in
		.DI0(DI[0]), .DI1(DI[1]), .DI2(DI[2]), .DI3(DI[3]), .DI4(DI[4]), .DI5(DI[5]), .DI6(DI[6]), .DI7(DI[7]),
		.DI8(DI[8]), .DI9(DI[9]), .DI10(DI[10]), .DI11(DI[11]), .DI12(DI[12]), .DI13(DI[13]), .DI14(DI[14]), .DI15(DI[15]),
		.DI16(DI[16]), .DI17(DI[17]), .DI18(DI[18]), .DI19(DI[19]), .DI20(DI[20]), .DI21(DI[21]), .DI22(DI[22]), .DI23(DI[23]),
		.DI24(DI[24]), .DI25(DI[25]), .DI26(DI[26]), .DI27(DI[27]), .DI28(DI[28]), .DI29(DI[29]), .DI30(DI[30]), .DI31(DI[31]),
		.DI32(DI[32]), .DI33(DI[33]), .DI34(DI[34]), .DI35(DI[35]), .DI36(DI[36]), .DI37(DI[37]), .DI38(DI[38]), .DI39(DI[39]),
		.DI40(DI[40]), .DI41(DI[41]), .DI42(DI[42]), .DI43(DI[43]), .DI44(DI[44]), .DI45(DI[45]), .DI46(DI[46]), .DI47(DI[47]),
		.DI48(DI[48]), .DI49(DI[49]), .DI50(DI[50]), .DI51(DI[51]), .DI52(DI[52]), .DI53(DI[53]), .DI54(DI[54]), .DI55(DI[55]),
		.DI56(DI[56]), .DI57(DI[57]), .DI58(DI[58]), .DI59(DI[59]), .DI60(DI[60]), .DI61(DI[61]), .DI62(DI[62]), .DI63(DI[63]),
		.DI64(DI[64]), .DI65(DI[65]), .DI66(DI[66]), .DI67(DI[67]), .DI68(DI[68]), .DI69(DI[69]), .DI70(DI[70]), .DI71(DI[71]),
		.DI72(DI[72]), .DI73(DI[73]), .DI74(DI[74]), .DI75(DI[75]), .DI76(DI[76]), .DI77(DI[77]), .DI78(DI[78]), .DI79(DI[79]),
		.DI80(DI[80]), .DI81(DI[81]), .DI82(DI[82]), .DI83(DI[83]), .DI84(DI[84]), .DI85(DI[85]), .DI86(DI[86]), .DI87(DI[87]),
		.DI88(DI[88]), .DI89(DI[89]), .DI90(DI[90]), .DI91(DI[91]), .DI92(DI[92]), .DI93(DI[93]), .DI94(DI[94]), .DI95(DI[95]),
		.DI96(DI[96]), .DI97(DI[97]), .DI98(DI[98]), .DI99(DI[99]), .DI100(DI[100]), .DI101(DI[101]), .DI102(DI[102]), .DI103(DI[103]),
		.DI104(DI[104]), .DI105(DI[105]), .DI106(DI[106]), .DI107(DI[107]), .DI108(DI[108]), .DI109(DI[109]), .DI110(DI[110]), .DI111(DI[111]),
		.DI112(DI[112]), .DI113(DI[113]), .DI114(DI[114]), .DI115(DI[115]), .DI116(DI[116]), .DI117(DI[117]), .DI118(DI[118]), .DI119(DI[119]),
		.DI120(DI[120]), .DI121(DI[121]), .DI122(DI[122]), .DI123(DI[123]), .DI124(DI[124]), .DI125(DI[125]), .DI126(DI[126]), .DI127(DI[127]),

		// control signal
		.CK(CK), .WEB(WEB), .OE(OE), .CS(CS)
	);

endmodule