.PHONY:syn syn_dv read_dv_rtl read_ddc vcs_rtl vcs_gate irun_rtl irun_gate xrun_rtl xrun_gate nWave verdi_rtl verdi_gate clean

######################################
# Set your desired file names
######################################
top_design=CC
source_file="filelist.f"	# Name of your source file
output_file="simv"      	# Desired output simulation file name
log_file="vcs.log"      	# Desired log file name
syn_tcl="syn.tcl"       	# Name of your synthesis tcl file
syn_log="syn.log"       	# Name of your synthesis log file
pt_tcl="pt.tcl"       	# Name of your synthesis tcl file
pt_log="pt.log"       	# Name of your synthesis log file

######################################
# Default Setting
######################################
num_CPU_cores=4               # Maximum Number of CPU that used for simulation/synthesis
TIMESCALE=-timescale=1ns/1fs
TIMESCALE1=-timescale 1ns/1fs
VERDI=/usr/cad/synopsys/verdi/2019.06/
DW_SIM=/usr/cad/synopsys/synthesis/cur/dw/sim_ver/
UMC018_SIM=~iclabTA01/umc018/Verilog/umc18_neg.v
UMC018_IO_SIM=~iclabTA01/umc018/Verilog/umc18io3v5v.v

######################################
# Simulation Option and Command
######################################

# =====================================
# ============== VCS ==================
# =====================================
VCS_RTL_SIM = vcs ${TIMESCALE} \
    -j${num_CPU_cores} \
    -sverilog \
    +v2k \
    -full64 \
    -Mupdate \
    -R \
    -debug_access+all \
    -y ${DW_SIM} \
    +libext+.v \
    -f ${source_file} \
    -o ${output_file} \
    -l ${log_file} \
    -P ${VERDI}/share/PLI/VCS/linux64/novas.tab \
       ${VERDI}/share/PLI/VCS/linux64/pli.a \
    +define+RTL \
    +notimingchecks 


VCS_GATE_SIM = vcs ${TIMESCALE} \
    -j${num_CPU_cores} \
    -sverilog \
    +v2k \
    -full64 \
    -Mupdate \
    -R \
    -debug_access+all \
    -f ${source_file} \
    -o ${output_file} \
    -l ${log_file} \
    -P ${VERDI}/share/PLI/VCS/linux64/novas.tab \
       ${VERDI}/share/PLI/VCS/linux64/pli.a \
	-v ${UMC018_SIM} \
    +define+GATE \
	+neg_tchk 

VCS_POST_SIM = vcs ${TIMESCALE} \
    -j${num_CPU_cores} \
    -sverilog \
    +v2k \
    -full64 \
    -Mupdate \
    -R \
    -debug_access+all \
    -f ${source_file} \
    -o ${output_file} \
    -l ${log_file} \
    -P ${VERDI}/share/PLI/VCS/linux64/novas.tab \
       ${VERDI}/share/PLI/VCS/linux64/pli.a \
    -v ${UMC018_SIM} \
	-v ${UMC018_IO_SIM} \
    +define+POST \
    +neg_tchk


# =====================================
# ============== irun =================
# =====================================
IRUN_RTL_SIM =  irun -f ${source_file} \
	-incdir ${DW_SIM} \
	-loadpli1 debpli:novas_pli_boot \
	-debug \
	-notimingchecks \
	-define RTL

IRUN_GATE_SIM =  irun -f ${source_file} \
	-override_precision \
	${TIMESCALE1} \
	-sdf_precision 1fs \
	-v ${UMC018_SIM} \
	-loadpli1 debpli:novas_pli_boot \
	-debug \
	-define GATE

IRUN_POST_SIM =  irun -f ${source_file} \
        -override_precision \
        ${TIMESCALE1} \
        -sdf_precision 1fs \
        -v ${UMC018_SIM} \
		-v ${UMC018_IO_SIM} \
        -loadpli1 debpli:novas_pli_boot \
        -debug \
		-maxdelays \
        -define POST 

# =====================================
# ============== xrun =================
# =====================================
XRUN_RTL_SIM =  xrun -f ${source_file} \
	-mcl ${num_CPU_cores} \
	-incdir ${DW_SIM} \
	-loadpli1 debpli:novas_pli_boot \
	-debug \
	-notimingchecks \
	-define RTL

XRUN_GATE_SIM =  xrun -f ${source_file} \
	-mcl ${num_CPU_cores} \
	-override_precision \
	${TIMESCALE1} \
	-sdf_precision 1fs \
	-v ${UMC018_SIM} \
	-loadpli1 debpli:novas_pli_boot \
	-debug \
	-define GATE

XRUN_POST_SIM =  xrun -f ${source_file} \
		-mcl ${num_CPU_cores} \
        -override_precision \
        ${TIMESCALE1} \
        -sdf_precision 1fs \
        -v ${UMC018_SIM} \
		-v ${UMC018_IO_SIM} \
        -loadpli1 debpli:novas_pli_boot \
        -debug \
        -define POST 

# =====================================
# ============= verdi =================
# =====================================
nWave_ON = nWave -ssf *.fsdb

VERDI_RTL_ON = verdi -ssf *.fsdb \
	-sv \
	-f ${source_file} \
    	-nologo           \
	+define+RTL	  \
	+v2k \
	-autoalias

VERDI_GATE_ON = verdi -ssf *.fsdb \
	-sv \
	-f ${source_file} \
    	-nologo           \
	+define+GATE	  \
	+v2k \
	-autoalias

# =====================================
# ========== Design Compiler ==========
# =====================================
DC_shell = dcnxt_shell -f ${syn_tcl} \
	-x "set_host_options -max_cores ${num_CPU_cores}" \
    -output_log_file ${syn_log}

DC_shell_gui = dcnxt_shell -f ${syn_tcl} \
	-x "set_host_options -max_cores ${num_CPU_cores}" \
    -output_log_file ${syn_log} \
	-gui

Read_DC_shell_gui = dcnxt_shell -x 'read_sverilog ${top_design}.v' -gui
Read_DDC_shell_gui = dcnxt_shell -x "read_ddc ${top_design}_SYN.ddc" -gui

# =====================================
# ========== Prime Time		 ==========
# =====================================
PT_shell = pt_shell -f ${pt_tcl} \
	-x "set_host_options -max_cores ${num_CPU_cores}" \
    -output_log_file ${pt_log}

# =====================================
# ==========   INNOVUS APR   ==========
# =====================================

INNOVUS_INIT = innovus -cpus ${num_CPU_cores} \
	-init ./cmd/run_apr.cmd \
	-log ./log/run_apr.log \
	-cmd ./log/run_apr.cmdlog
 
# =====================================	
# ============= clean =================
# =====================================
clean_vcs = rm -rf *.fsdb ./csrc *.log simv* *.sdf.X *.key
clean_irun = rm -rf *.fsdb *.sdf.X ./INCA_libs *.history *.log
clean_xrun = rm -rf *.fsdb *.sdf.X ./xcelium.d *.history *.log
clean_verdi = rm -rf ./nWaveLog ./verdiLog *.conf *.rc *.log
clean_syn = rm -rf ./Netlist/*.* ./Report/*.* *.log alib* *.svf dwsvf* *.ddc *.pvl *.syn *.mr
clean_power = rm -rf vcd.out ./fsdb2vcdLog ./Report/*
clean_apr = rm -rf checkDesign \
            rm -rf *.log \
            rm -rf *.rpt* \
            rm -rf *.CCOPT.spec \
            rm -rf *.checkPlace \
            rm -rf ./StreamOut/* CHIP_SYN.v \
            rm -rf *.globals \
            rm -rf extLogDir \
            rm -rf ./log/* \
            rm -rf ./DBS/* \
            rm -rf ./timingReports/* \
            rm -rf *.bin
# =====================================

vcs_rtl:
	${VCS_RTL_SIM}

vcs_gate:
	${VCS_GATE_SIM}

vcs_post:
	${VCS_POST_SIM}

irun_rtl:
	${IRUN_RTL_SIM}

irun_gate:
	${IRUN_GATE_SIM}

irun_post:
	${IRUN_POST_SIM}

xrun_rtl:
	${XRUN_RTL_SIM}

xrun_gate:
	${XRUN_GATE_SIM}

xrun_post:
	${XRUN_POST_SIM}

syn:
	${DC_shell}

syn_dv:
	${DC_shell_gui}

read_dv_rtl:
	${Read_DC_shell_gui}

read_ddc:
	${Read_DDC_shell_gui}

pt:
	${PT_shell}

nWave:
	${nWave_ON}

verdi_rtl:
	${VERDI_RTL_ON}

verdi_gate:
	${VERDI_GATE_ON}

apr_init:
	${INNOVUS_INIT}


clean:
	${clean_vcs}
	${clean_irun}
	${clean_xrun}
	${clean_verdi}
	${clean_syn}
	${clean_power}
	${clean_apr}

