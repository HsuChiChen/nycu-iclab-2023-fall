`timescale 1ns/1ps

`include "PATTERN.v"
`ifdef RTL
  `include "CC.v"
`endif
`ifdef GATE
  `include "CC_SYN.v"
`endif
	  		  	
module TESTBED;

wire         clk, rst_n, in_valid;
wire  [7:0]  xi, yi;
wire  [1:0]  mode;

wire         out_valid;
wire  [7:0]  xo, yo;
initial begin
  `ifdef RTL
    $fsdbDumpfile("CC.fsdb");
	  $fsdbDumpvars(0,"+mda");
    $fsdbDumpvars();
  `endif
  `ifdef GATE
    $sdf_annotate("CC_SYN.sdf", u_CC);
    $fsdbDumpfile("CC_SYN.fsdb");
	  $fsdbDumpvars(0,"+mda");
    $fsdbDumpvars();    
  `endif
end

`ifdef RTL
CC u_CC(
    .clk            (   clk          ),
    .rst_n          (   rst_n        ),
    .in_valid       (   in_valid     ),
    .mode           (     mode       ),	
    .xi             (       xi       ),
    .yi             (       yi       ),

    .out_valid      (   out_valid    ),
    .xo             (       xo       ),
	.yo             (       yo       )
);
`endif	

`ifdef GATE
CC u_CC(
    .clk            (   clk          ),
    .rst_n          (   rst_n        ),
    .in_valid       (   in_valid     ),
    .mode           (     mode       ),	
    .xi             (       xi       ),
    .yi             (       yi       ),

    .out_valid      (   out_valid    ),
    .xo             (       xo       ),
	.yo             (       yo       )
);
`endif	

PATTERN u_PATTERN(
    .clk            (   clk          ),
    .rst_n          (   rst_n        ),
    .in_valid       (   in_valid     ),
    .mode           (     mode       ),	
    .xi             (       xi       ),
    .yi             (       yi       ),

    .out_valid      (   out_valid    ),
    .xo             (       xo       ),
	.yo             (       yo       )
);
  
 
endmodule
