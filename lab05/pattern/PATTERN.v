`define CYCLE_TIME 5.5

module PATTERN(
    clk,
    rst_n,
    in_valid,
    in_valid2,
    mode,
    matrix,
    matrix_size,
    matrix_idx,
    out_valid,
    out_value
);
output reg clk, rst_n, in_valid, in_valid2;
output reg mode;
output reg[7:0] matrix;
output reg[3:0] matrix_idx;
output reg[1:0] matrix_size;
input out_valid;
input out_value;

//======================================
//      PARAMETERS & VARIABLES
//======================================
// User modification
parameter PATNUM = 100;
integer   SEED = 587;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 100000;

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
parameter MAX_IMAGE_SIZE = 32;
parameter KERNEL_SIZE = 5;
parameter IMAGE_NUM = 16;
parameter INDEX_NUM = 16;
parameter MAX_POOL_SIZE = 2;
parameter OUTPUT_BIT = 20;
parameter OUTPUT_MIN = -2**(20-1);
parameter INPUT_MAX = 2**(8-1)-1;
parameter INPUT_MIN = -2**(8-1);
integer _image[0:IMAGE_NUM-1][0:MAX_IMAGE_SIZE-1][0:MAX_IMAGE_SIZE-1];
integer _kernel[0:IMAGE_NUM-1][0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
integer _conv[0:MAX_IMAGE_SIZE-KERNEL_SIZE+1-1][0:MAX_IMAGE_SIZE-KERNEL_SIZE+1-1];
integer _maxPool[0:(MAX_IMAGE_SIZE-KERNEL_SIZE+1)/2-1][0:(MAX_IMAGE_SIZE-KERNEL_SIZE+1)/2-1];
integer _deConv[0:MAX_IMAGE_SIZE+KERNEL_SIZE-1-1][0:MAX_IMAGE_SIZE+KERNEL_SIZE-1-1];
integer _iIdx, _kIdx;
integer _size;
integer _mode;

// PATTERN
integer set;
integer _goldSize;
reg signed[OUTPUT_BIT-1:0] _gold[0:MAX_IMAGE_SIZE+KERNEL_SIZE-1-1][0:MAX_IMAGE_SIZE+KERNEL_SIZE-1-1];
reg signed[OUTPUT_BIT-1:0] _your[0:MAX_IMAGE_SIZE+KERNEL_SIZE-1-1][0:MAX_IMAGE_SIZE+KERNEL_SIZE-1-1];


task _dumpMatrix;
    integer _idx;
    integer _row;
    integer _col;
    reg[5*8:1] _line5  = "_____";
    reg[6*8:1] _line6  = "______";
    reg[5*8:1] _space5 = "     ";
    reg[6*8:1] _space6 = "      ";
begin
    file_out = $fopen("image.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n\n", pat);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Option ]\n");
    $fwrite(file_out, "[========]\n\n");
    $fwrite(file_out, "[ size ] %-1d\n", _size);
    $fwrite(file_out, "[ mode ] %-1d / ", _mode);
    if(_mode === 2'd0) $fwrite(file_out, "[ Convolution ][ Max pooling ]");
    if(_mode === 2'd1) $fwrite(file_out, "[ Transposed Convolution ]");
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=======]\n");
    $fwrite(file_out, "[ Image ]\n");
    $fwrite(file_out, "[=======]\n\n");

    for(_idx=0 ; _idx<IMAGE_NUM ; _idx=_idx+1) begin
        // column index : [#0] **1 **2 **3
        $fwrite(file_out, "[#%2d] ", _idx);
        for(_col=0 ; _col<_size ; _col=_col+1) $fwrite(file_out, "%4d ",_col);
        $fwrite(file_out, "\n");
        // seperating line : _________________
        $fwrite(file_out, "%0s", _line6);
        for(_col=0 ; _col<_size ; _col=_col+1) $fwrite(file_out, "%0s", _line5);
        $fwrite(file_out, "\n");
        // row index | element :  0| **1 **2 **3
        for(_row=0 ; _row<_size ; _row=_row+1) begin
            $fwrite(file_out, "  %2d| ",_row);
            for(_col=0 ; _col<_size ; _col=_col+1) begin
                $fwrite(file_out, "%4d ", _image[_idx][_row][_col]);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end
    $fclose(file_out);
end endtask

task _dumpKernel;
    integer _idx;
    integer _row;
    integer _col;
    reg[5*8:1] _line5  = "_____";
    reg[6*8:1] _line6  = "______";
    reg[5*8:1] _space5 = "     ";
    reg[6*8:1] _space6 = "      ";
begin
    file_out = $fopen("kernel.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n\n", pat);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Kernel ]\n");
    $fwrite(file_out, "[========]\n\n");

    for(_idx=0 ; _idx<IMAGE_NUM ; _idx=_idx+1) begin
        // column index : [#0] **1 **2 **3
        $fwrite(file_out, "[#%2d] ", _idx);
        for(_col=0 ; _col<KERNEL_SIZE ; _col=_col+1) $fwrite(file_out, "%4d ",_col);
        $fwrite(file_out, "\n");
        // seperating line : _________________
        $fwrite(file_out, "%0s", _line6);
        for(_col=0 ; _col<KERNEL_SIZE ; _col=_col+1) $fwrite(file_out, "%0s", _line5);
        $fwrite(file_out, "\n");
        // row index | element :  0| **1 **2 **3
        for(_row=0 ; _row<KERNEL_SIZE ; _row=_row+1) begin
            $fwrite(file_out, "  %2d| ",_row);
            for(_col=0 ; _col<KERNEL_SIZE ; _col=_col+1) begin
                $fwrite(file_out, "%4d ", _kernel[_idx][_row][_col]);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end
    $fclose(file_out);
end endtask

task _dumpDefault; begin
    file_out = $fopen("convolution.txt", "w");
    $fclose(file_out);
    file_out = $fopen("maxpool.txt", "w");
    $fclose(file_out);
    file_out = $fopen("deConvolution.txt", "w");
    $fclose(file_out);
    file_out = $fopen("yourOutput.txt", "w");
    $fclose(file_out);
end endtask

task _dumpConvolution;
    integer _idx;
    integer _row;
    integer _col;
    integer _convSize;
    reg[5*8:1] _line5  = "_____";
    reg[6*8:1] _line6  = "______";
    reg[5*8:1] _space5 = "     ";
    reg[6*8:1] _space6 = "      ";
begin
    file_out = $fopen("convolution.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n", pat);
    $fwrite(file_out, "[SET NO. %4d]\n\n", set);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=============]\n");
    $fwrite(file_out, "[ Convolution ]\n");
    $fwrite(file_out, "[=============]\n\n");
    $fwrite(file_out, "[ image  index ] %-1d\n", _iIdx);
    $fwrite(file_out, "[ kernel index ] %-1d\n", _kIdx);
    $fwrite(file_out, "\n");

    _convSize = _size-KERNEL_SIZE+1;
    $fwrite(file_out, "[***] ");
    for(_col=0 ; _col<_convSize ; _col=_col+1) $fwrite(file_out, "%4d ",_col);
    $fwrite(file_out, "\n");
    // seperating line : _________________
    $fwrite(file_out, "%0s", _line6);
    for(_col=0 ; _col<_convSize ; _col=_col+1) $fwrite(file_out, "%0s", _line5);
    $fwrite(file_out, "\n");
    // row index | element :  0| **1 **2 **3
    for(_row=0 ; _row<_convSize ; _row=_row+1) begin
        $fwrite(file_out, "  %2d| ",_row);
        for(_col=0 ; _col<_convSize ; _col=_col+1) begin
            $fwrite(file_out, "%4d ", _conv[_row][_col]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
    $fclose(file_out);
end endtask

task _dumpMaxPool;
    integer _idx;
    integer _row;
    integer _col;
    integer _maxPoolSize;
    reg[5*8:1] _line5  = "_____";
    reg[6*8:1] _line6  = "______";
    reg[5*8:1] _space5 = "     ";
    reg[6*8:1] _space6 = "      ";
begin
    file_out = $fopen("maxpool.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n", pat);
    $fwrite(file_out, "[SET NO. %4d]\n\n", set);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[==========]\n");
    $fwrite(file_out, "[ Max Pool ]\n");
    $fwrite(file_out, "[==========]\n\n");
    $fwrite(file_out, "\n");

    _maxPoolSize = (_size-KERNEL_SIZE+1)/2;
    $fwrite(file_out, "[***] ");
    for(_col=0 ; _col<_maxPoolSize ; _col=_col+1) $fwrite(file_out, "%4d ",_col);
    $fwrite(file_out, "\n");
    // seperating line : _________________
    $fwrite(file_out, "%0s", _line6);
    for(_col=0 ; _col<_maxPoolSize ; _col=_col+1) $fwrite(file_out, "%0s", _line5);
    $fwrite(file_out, "\n");
    // row index | element :  0| **1 **2 **3
    for(_row=0 ; _row<_maxPoolSize ; _row=_row+1) begin
        $fwrite(file_out, "  %2d| ",_row);
        for(_col=0 ; _col<_maxPoolSize ; _col=_col+1) begin
            $fwrite(file_out, "%4d ", _maxPool[_row][_col]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
    $fclose(file_out);
end endtask

task _dumpDeConvolution;
    integer _idx;
    integer _row;
    integer _col;
    integer _deConvSize;
    reg[5*8:1] _line5  = "_____";
    reg[6*8:1] _line6  = "______";
    reg[5*8:1] _space5 = "     ";
    reg[6*8:1] _space6 = "      ";
begin
    file_out = $fopen("deConvolution.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n", pat);
    $fwrite(file_out, "[SET NO. %4d]\n\n", set);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========================]\n");
    $fwrite(file_out, "[ Transposed Convolution ]\n");
    $fwrite(file_out, "[========================]\n\n");
    $fwrite(file_out, "[ image  index ] %-1d\n", _iIdx);
    $fwrite(file_out, "[ kernel index ] %-1d\n", _kIdx);
    $fwrite(file_out, "\n");

    _deConvSize = _size+KERNEL_SIZE-1;
    $fwrite(file_out, "[***] ");
    for(_col=0 ; _col<_deConvSize ; _col=_col+1) $fwrite(file_out, "%4d ",_col);
    $fwrite(file_out, "\n");
    // seperating line : _________________
    $fwrite(file_out, "%0s", _line6);
    for(_col=0 ; _col<_deConvSize ; _col=_col+1) $fwrite(file_out, "%0s", _line5);
    $fwrite(file_out, "\n");
    // row index | element :  0| **1 **2 **3
    for(_row=0 ; _row<_deConvSize ; _row=_row+1) begin
        $fwrite(file_out, "  %2d| ",_row);
        for(_col=0 ; _col<_deConvSize ; _col=_col+1) begin
            $fwrite(file_out, "%4d ", _deConv[_row][_col]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
    $fclose(file_out);
end endtask

task _dumpYourOutput;
    integer _row;
    integer _col;
    reg[5*8:1] _line5  = "_____";
    reg[6*8:1] _line6  = "______";
    reg[5*8:1] _space5 = "     ";
    reg[6*8:1] _space6 = "      ";
begin
    file_out = $fopen("yourOutput.txt", "w");

    // Pattern info
    $fwrite(file_out, "[PAT NO. %4d]\n", pat);
    $fwrite(file_out, "[SET NO. %4d]\n\n", set);

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=============]\n");
    $fwrite(file_out, "[ Your Output ]\n");
    $fwrite(file_out, "[=============]\n\n");
    $fwrite(file_out, "\n");

    $fwrite(file_out, "[***] ");
    for(_col=0 ; _col<_goldSize ; _col=_col+1) $fwrite(file_out, "%4d ",_col);
    $fwrite(file_out, "\n");
    // seperating line : _________________
    $fwrite(file_out, "%0s", _line6);
    for(_col=0 ; _col<_goldSize ; _col=_col+1) $fwrite(file_out, "%0s", _line5);
    $fwrite(file_out, "\n");
    // row index | element :  0| **1 **2 **3
    for(_row=0 ; _row<_goldSize ; _row=_row+1) begin
        $fwrite(file_out, "  %2d| ",_row);
        for(_col=0 ; _col<_goldSize ; _col=_col+1) begin
            $fwrite(file_out, "%4d ", _your[_row][_col]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
    $fclose(file_out);
end endtask

task _randMatrixData;
    integer _range;
    integer _idx;
    integer _row;
    integer _col;
begin
    _size = 2 ** ({$random(SEED)} % 3 + 3); // 8, 16, 32
    for(_idx=0 ; _idx<IMAGE_NUM ; _idx=_idx+1) begin
        for(_row=0 ; _row<_size ; _row=_row+1) begin
            for(_col=0 ; _col<_size ; _col=_col+1) begin
                _range = pat < 10 ? {$random(SEED)} % 3 : {$random(SEED)}%(INPUT_MAX-INPUT_MIN+1) + INPUT_MIN;
                _image[_idx][_row][_col] = _range;
            end
        end
    end
    for(_idx=0 ; _idx<IMAGE_NUM ; _idx=_idx+1) begin
        for(_row=0 ; _row<KERNEL_SIZE ; _row=_row+1) begin
            for(_col=0 ; _col<KERNEL_SIZE ; _col=_col+1) begin
                _range = pat < 10 ? {$random(SEED)} % 3 : {$random(SEED)}%(INPUT_MAX-INPUT_MIN+1) + INPUT_MIN;
                _kernel[_idx][_row][_col] = _range;
            end
        end
    end
end endtask

task _randIndex;begin
    _iIdx = {$random(SEED)} % IMAGE_NUM;
    _kIdx = {$random(SEED)} % IMAGE_NUM;
    _mode = {$random(SEED)} % 2;
end endtask

task _clearOutput;
    integer _row;
    integer _col;
begin
    for (_row=0 ; _row<MAX_IMAGE_SIZE-KERNEL_SIZE+1 ; _row=_row+1)
        for (_col=0 ; _col<MAX_IMAGE_SIZE-KERNEL_SIZE+1; _col=_col+1)
            _conv[_row][_col] = 0;
    for (_row=0 ; _row<(MAX_IMAGE_SIZE-KERNEL_SIZE+1)/2 ; _row=_row+1)
        for (_col=0 ; _col<(MAX_IMAGE_SIZE-KERNEL_SIZE+1)/2; _col=_col+1)
            _maxPool[_row][_col] = 0;
    for (_row=0 ; _row<MAX_IMAGE_SIZE+KERNEL_SIZE-1 ; _row=_row+1)
        for (_col=0 ; _col<MAX_IMAGE_SIZE+KERNEL_SIZE-1; _col=_col+1)
            _deConv[_row][_col] = 0;
    for (_row=0 ; _row<MAX_IMAGE_SIZE+KERNEL_SIZE-1 ; _row=_row+1)
        for (_col=0 ; _col<MAX_IMAGE_SIZE+KERNEL_SIZE-1; _col=_col+1)
            _gold[_row][_col] = 0;
    for (_row=0 ; _row<MAX_IMAGE_SIZE+KERNEL_SIZE-1 ; _row=_row+1)
        for (_col=0 ; _col<MAX_IMAGE_SIZE+KERNEL_SIZE-1; _col=_col+1)
            _your[_row][_col] = 0;
end endtask

task _doConv;
    input integer iIdx;
    input integer kIdx;
    integer sum;
    integer _row;
    integer _col;
    integer _kRow;
    integer _kCol;
    integer _outSize;
begin
    _outSize = _size-KERNEL_SIZE+1;
    for (_row=0 ; _row<_outSize ; _row=_row+1) begin
        for (_col=0 ; _col<_outSize; _col=_col+1) begin
            sum = 0;
            for (_kRow=0 ; _kRow < KERNEL_SIZE ; _kRow=_kRow+1) begin
                for (_kCol=0 ; _kCol<KERNEL_SIZE ; _kCol=_kCol+1) begin
                    sum = sum + _image[iIdx][_row + _kRow][_col + _kCol] * _kernel[kIdx][_kRow][_kCol];
                end
            end
            _conv[_row][_col] = sum;
        end
    end
end endtask

task _doMaxPool;
    integer _max;
    integer _row;
    integer _col;
    integer _pRow;
    integer _pCol;
    integer _outSize;
begin
    _outSize = (_size-KERNEL_SIZE+1)/2;
    for(_row=0 ; _row<_outSize ; _row=_row+1) begin
        for(_col=0 ; _col<_outSize ; _col=_col+1) begin
            _max = OUTPUT_MIN;
            for(_pRow=0 ; _pRow<MAX_POOL_SIZE ; _pRow=_pRow+1) begin
                for(_pCol=0 ; _pCol<MAX_POOL_SIZE ; _pCol=_pCol+1) begin
                    _max = _max > _conv[MAX_POOL_SIZE*_row+_pRow][MAX_POOL_SIZE*_col+_pCol] ? _max : _conv[MAX_POOL_SIZE*_row+_pRow][MAX_POOL_SIZE*_col+_pCol];
                end
            end
            _maxPool[_row][_col] = _max;
            _gold[_row][_col] = _max;
        end
    end
    _goldSize = (_size-KERNEL_SIZE+1)/2;
end endtask

task _doDeConv;
    input integer iIdx;
    input integer kIdx;
    integer _row;
    integer _col;
    integer _kRow;
    integer _kCol;
begin
    for(_row=0 ; _row<_size ; _row=_row+1) begin
        for(_col=0 ; _col<_size ; _col=_col+1) begin
            for(_kRow=0 ; _kRow<KERNEL_SIZE ; _kRow=_kRow+1) begin
                for(_kCol=0 ; _kCol<KERNEL_SIZE ; _kCol=_kCol+1) begin
                    _deConv[_row+_kRow][_col+_kCol] = _deConv[_row+_kRow][_col+_kCol] + _image[iIdx][_row][_col] * _kernel[kIdx][_kRow][_kCol];
                    _gold[_row+_kRow][_col+_kCol] = _gold[_row+_kRow][_col+_kCol] + _image[iIdx][_row][_col] * _kernel[kIdx][_kRow][_kCol];
                end
            end
        end
    end
    _goldSize = _size+KERNEL_SIZE-1;
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
        for(set=0 ; set<INDEX_NUM ; set=set+1) begin
            input_task;
            cal_task;
            wait_task;
            check_task;
            // Print Pass Info and accumulate the total latency
            $display("%0sPASS PATTERN NO.%4d/SET NO.%2d, %0sCycles: %3d%0s",txt_blue_prefix, pat, set, txt_green_prefix, exe_lat, reset_color);
        end
    end
    pass_task;
end endtask

//**************************************
//      Reset Task
//**************************************
task reset_task; begin

    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    in_valid2 = 0;
    mode = 'dx;
    matrix = 'dx;
    matrix_idx = 'dx;
    matrix_size = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if (out_valid !== 0 || out_value !== 0) begin
        $display("==========================================================================");
        $display("    Output signal should be 0 at %-12d ps  ", $time*1000);
        $display("==========================================================================");
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

//**************************************
//      Input Task
//**************************************
task input_task;
    integer _idx;
    integer _row;
    integer _col;
begin
    _clearOutput;
    if(set == 0) begin
        _randMatrixData;
        // Give matrix
        repeat(({$random(SEED)} % 5 + 1)) @(negedge clk);
        for (_idx=0 ; _idx<IMAGE_NUM ; _idx=_idx+1) begin
            for (_row=0 ; _row<_size ; _row=_row+1) begin
                for (_col=0 ; _col<_size; _col=_col+1) begin
                    if(_idx===0 && _row===0 && _col===0) begin
                        if(_size===8) matrix_size = 2'd0;
                        else if(_size===16) matrix_size = 2'd1;
                        else if(_size===32) matrix_size = 2'd2;
                    end
                    matrix = _image[_idx][_row][_col];
                    in_valid = 1;
                    check_out_valid;
                    @(negedge clk);
                    matrix = 'dx;
                    matrix_size = 'dx;
                    in_valid = 0;
                end
            end
        end
        for (_idx=0 ; _idx<IMAGE_NUM ; _idx=_idx+1) begin
            for (_row=0 ; _row<KERNEL_SIZE ; _row=_row+1) begin
                for (_col=0 ; _col<KERNEL_SIZE; _col=_col+1) begin
                    matrix = _kernel[_idx][_row][_col];
                    in_valid = 1;
                    check_out_valid;
                    @(negedge clk);
                    matrix = 'dx;
                    in_valid = 0;
                end
            end
        end
    end
    // Give index
    _randIndex;
    repeat(({$random(SEED)} % 3 + 1)) @(negedge clk);
    for (_idx=0 ; _idx<2 ; _idx=_idx+1) begin
        if(_idx===0) mode = _mode;
        if(_idx===0) matrix_idx = _iIdx;
        if(_idx===1) matrix_idx = _kIdx;
        in_valid2 = 1;
        check_out_valid;
        @(negedge clk);
        mode = 'dx;
        matrix_idx = 'dx;
        in_valid2 = 0;
    end
    _dumpMatrix;
    _dumpKernel;
end endtask

task check_out_valid; begin
    if (out_valid !== 0 || out_value !== 0) begin
        $display("==========================================================================");
        $display("    Output signal should be 0 at %-12d ps  ", $time*1000);
        $display("==========================================================================");
        repeat(5) @(negedge clk);
        $finish;
    end
end endtask

//**************************************
//      Wait Task
//**************************************
task wait_task; begin
    exe_lat = -1;
    while (out_valid !== 1) begin
        if (out_value !== 0) begin
            $display("==========================================================================");
            $display("    Output signal should be 0 at %-12d ps  ", $time*1000);
            $display("==========================================================================");
            repeat(5) @(negedge clk);
            $finish;
        end
        if (exe_lat == DELAY) begin
            $display("==========================================================================");
            $display("    The execution latency at %-12d ps is over %5d cycles  ", $time*1000, DELAY);
            $display("==========================================================================");
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
task cal_task; begin
    _dumpDefault;
    if(_mode===0) begin
        _doConv(_iIdx, _kIdx);
        _doMaxPool;
        _dumpConvolution;
        _dumpMaxPool;
    end
    else begin
        _doDeConv(_iIdx, _kIdx);
        _dumpDeConvolution;
    end
end endtask

//**************************************
//      Check Task
//**************************************
task check_task;
    integer _row;
    integer _col;
    integer _bit;
    integer _totalCycle;
begin
    out_lat = 0;
    _totalCycle = OUTPUT_BIT*_goldSize*_goldSize;
    while(out_valid === 1) begin
        if (out_lat===_totalCycle) begin
            $display("==========================================================================");
            $display("    Out cycles is less than %-2d at %-12d ps ", _totalCycle, $time*1000);
            $display("==========================================================================");
            repeat(5) @(negedge clk);
            $finish;
        end
        _bit = out_lat%OUTPUT_BIT;
        _row = (out_lat/OUTPUT_BIT)/_goldSize;
        _col = (out_lat/OUTPUT_BIT)%_goldSize;
        _your[_row][_col][_bit] = out_value;
        out_lat = out_lat + 1;
        @(negedge clk);
    end
    if (out_lat<_totalCycle) begin
        $display("==========================================================================");
        $display("    Out cycles is less than %-2d at %-12d ps ", _totalCycle, $time*1000);
        $display("==========================================================================");
        repeat(5) @(negedge clk);
        $finish;
    end
    for (_row=0 ; _row<_goldSize ; _row=_row+1) begin
        for (_col=0 ; _col<_goldSize; _col=_col+1) begin
            if(_gold[_row][_col] !== _your[_row][_col]) begin
                $display("==========================================================================");
                $display("    Out is not correct at %-12d ps ", $time*1000);
                $display("==========================================================================");
                $display("[row, col] = [%2d, %2d]", _row, _col);
                _dumpYourOutput;
                repeat(5) @(negedge clk);
                $finish;
            end
        end
    end
    tot_lat = tot_lat + exe_lat;
end endtask

//**************************************
//      PASS Task
//**************************************
task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask

endmodule