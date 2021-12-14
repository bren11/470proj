# make          <- runs simv (after compiling simv if needed)
# make all      <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be
# similar to the information in those scripts but that seems hard to avoid.
#
#


SOURCE = test_fc.s

CRT = crt.s
LINKERS = linker.lds
ASLINKERS = aslinker.lds

DEBUG_FLAG = -g
CFLAGS =  -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align
OFLAGS = -O3
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases
OBJDFLAGS = -SD -M numeric,no-aliases

##########################################################################
# IF YOU AREN'T USING A CAEN MACHINE, CHANGE THIS TO FALSE OR OVERRIDE IT
CAEN = 1
##########################################################################
ifeq (1, $(CAEN))
	GCC = riscv gcc
	OBJDUMP = riscv objdump
	AS = riscv as
	ELF2HEX = riscv elf2hex
else
	GCC = riscv64-unknown-elf-gcc
	OBJDUMP = riscv64-unknown-elf-objdump
	AS = riscv64-unknown-elf-as
	ELF2HEX = elf2hex
endif

N_NUM = 4
ROB_NUM = 32
RS_NUM = 16
CACHE_NUM = 16
MEM_NUM = 100

VCS = vcs -V -sverilog +vc -Mupdate -line -full64 +vcs+vcdpluson -cm line+tgl+branch 
VCS += +define+N=$(N_NUM)+RS_NUM_ENTRIES=$(RS_NUM)+ROB_NUM_ENTRIES=$(ROB_NUM)+ICACHE_NUM_LINES=$(CACHE_NUM)+DCACHE_NUM_LINES=$(CACHE_NUM)+
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

# For visual debugger
VISFLAGS = -lncurses -lpanel

# SIMULATION CONFIG

HEADERS     = $(wildcard *.svh)
TESTBENCH   = $(wildcard testbench/testbench.sv)
TESTBENCH  += $(wildcard testbench/*.c)
PIPEFILES   = $(wildcard verilog/*.sv)
PIPEFILES   += $(wildcard verilog/func/*.sv)
PIPEFILES   += $(wildcard verilog/id/*.sv)
PIPEFILES   += $(wildcard verilog/utility/*.v)
PIPEFILES	+= $(wildcard verilog/cache/cachemem_rw.sv)
CACHEFILES  = $(wildcard verilog/cache/cachemem.sv)
TESTBENCHFULL = testbench/mem.sv  \
		testbench/testbench.sv	\
		testbench/pipe_print.c

SIMFILES    = $(PIPEFILES) $(CACHEFILES)

# SYNTHESIS CONFIG
SYNTH_DIR = ./synth

export HEADERS
export PIPEFILES
export CACHEFILES

export CACHE_NAME = cachemem
export PIPELINE_NAME = pipeline

PIPELINE  = $(SYNTH_DIR)/$(PIPELINE_NAME).vg
SYNFILES  = $(PIPELINE)
CACHE     = $(SYNTH_DIR)/$(CACHE_NAME).vg

VTUBER = testbench/mem.sv  \
		testbench/visual_testbench.v \
		testbench/visual_c_hooks.cpp \
		testbench/pipe_print.c

# Passed through to .tcl scripts:
export CLOCK_NET_NAME = clock
export RESET_NET_NAME = reset
export CLOCK_PERIOD   = 11.5	# TODO: You will need to make match SYNTH_CLOCK_PERIOD in sys_defs
                                #       and make this more aggressive

################################################################################
## RULES
################################################################################

# Default target:
all:    simv
	./simv | tee program.out

.PHONY: all

# Simulation:

sim:	simv
	./simv | tee sim_program.out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCHFULL)
	$(VCS) $^ -o simv

vis_simv:	$(HEADERS) $(SIMFILES) $(VTUBER)
		$(VCS) $(VISFLAGS) $(HEADERS) $(VTUBER) $(SIMFILES) -o vis_simv
		./vis_simv

.PHONY: sim

# Programs

compile: $(CRT) $(LINKERS)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
	$(GCC) $(CFLAGS) $(DEBUG_FLAG) $(CRT) $(SOURCE) -T $(LINKERS) -o program.debug.elf
assemble: $(ASLINKERS)
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf
	cp program.elf program.debug.elf
disassemble: program.debug.elf
	$(OBJDUMP) $(OBJFLAGS) program.debug.elf > program.dump
	$(OBJDUMP) $(OBJDFLAGS) program.debug.elf > program.debug.dump
	rm program.debug.elf
hex: program.elf
	$(ELF2HEX) 8 8192 program.elf > program.mem

program: compile disassemble hex
	@:

debug_program:
	gcc -lm -g -std=gnu11 -DDEBUG $(SOURCE) -o debug_bin
assembly: assemble disassemble hex
	@:

# Debugging

dve:	simv
	./simv -gui &

dve_syn:	syn_simv
	./syn_simv -gui &

dve_rs:	rs
	./simv -gui &

dve_fu:	fu
	./simv -gui &

dve_lsq:	lsq
	./simv -gui &

dve_dcache:	dcache
	./simv -gui &

dve_rob:	rob
	./simv -gui &

dve_ibuffer:	ibuffer
	./simv -gui &

dve_if_stage:	if_stage
	./simv -gui &

dve_rat:	rat
	./simv -gui &

dve_decoder:	decoder
	./simv -gui &

dve_id_stage:	id_stage
	./simv -gui &

.PHONY: dve dve_syn

clean:
	rm -rf *simv *simv.daidir csrc vcs.key program.out *.key
	rm -rf vis_simv vis_simv.daidir
	rm -rf dve* inter.vpd DVEfiles
	rm -rf syn_simv syn_simv.daidir *syn_program.out
	rm -rf synsimv synsimv.daidir csrc vcdplus.vpd vcs.key synprog.out pipeline.out writeback.out vc_hdrs.h
	rm -f *.elf *.dump *.mem debug_bin

nuke:	clean
	rm -rf synth/*.vg synth/*.rep synth/*.ddc synth/*.chk synth/*.log synth/*.syn
	rm -rf synth/*.out command.log synth/*.db synth/*.svf synth/*.mr synth/*.pvl

# New stuff


export RS_SIMFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/reservation_station.sv	testbench/rs_testbench.sv
export RS_SYNFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/reservation_station.sv
export RS = $(SYNTH_DIR)/reservation_station.vg

export ROB_SIMFILES	=	verilog/rob.sv	testbench/rob_testbench.sv
export ROB_SYNFILES	=	verilog/rob.sv	
export ROB = $(SYNTH_DIR)/rob.vg

export FU_SIMFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/func/functional_unit.sv	verilog/func/adder.sv	verilog/func/branch.sv	verilog/lsq.sv	verilog/func/mult.sv	testbench/fu_testbench.sv
export FU_SYNFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/func/functional_unit.sv	verilog/func/adder.sv	verilog/func/branch.sv	verilog/lsq.sv	verilog/func/mult.sv
export FU = $(SYNTH_DIR)/functional_unit.vg

export DCACHE_TESTBENCH =	testbench/mem.sv testbench/dcache_testbench.sv
export DCACHE_SIMFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v verilog/cache/cachemem_rw.sv	verilog/mshr.sv	verilog/dcache.sv
export DCACHE_SYNFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v verilog/cache/cachemem_rw.sv	verilog/mshr.sv	verilog/dcache.sv	
export DCACHE = $(SYNTH_DIR)/dcache.vg

export LSQ_TESTBENCH   =	testbench/mem.sv testbench/lsq_testbench.sv
export LSQ_SIMFILES	   =	$(DCACHE_SIMFILES)	verilog/lsq.sv	
export LSQ_SYNFILES	   =	$(DCACHE_SYNFILES)	verilog/lsq.sv
export LSQ = $(SYNTH_DIR)/lsq.vg

rs:	$(HEADERS)	$(RS_SIMFILES)
	$(VCS) $^ -o simv

fu:	$(HEADERS)	$(FU_SIMFILES)
	$(VCS) $^ -o simv
	./simv | tee program.out

lsq:	$(HEADERS)	$(LSQ_SIMFILES) $(LSQ_TESTBENCH)
	$(VCS) +lint=TFIPC-L $^ -o simv
	./simv | tee program.out

rob:	$(HEADERS)	$(ROB_SIMFILES)
	$(VCS) $^ -o simv
	./simv | tee program.out

dcache:	$(HEADERS)	$(DCACHE_SIMFILES) $(DCACHE_TESTBENCH)
	$(VCS) $^ -o simv
	./simv | tee program.out

#PRF RULES

export PRF_SIMFILES	=	verilog/id/prf.sv	testbench/prf_testbench.sv
export PRF_SYNFILES	=	verilog/id/prf.sv
export PRF = $(SYNTH_DIR)/prf.vg

prf:	$(HEADERS)	$(PRF_SIMFILES)
	$(VCS) $^ -o simv
	./simv | tee program.out

syn_prf:	syn_simv_prf
	./syn_simv_prf | tee syn_program.out

syn_simv_prf:	$(HEADERS)	$(PRF)	testbench/prf_testbench.sv
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv_prf

$(PRF):	$(PRF_SYNFILES)	$(SYNTH_DIR)/prf.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./prf.tcl | tee prf_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(PRF)

#

#RAT RULES

export RAT_SIMFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/id/rat.sv	testbench/rat_testbench.sv
export RAT_SYNFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/id/rat.sv
export RAT = $(SYNTH_DIR)/rat.vg

rat:	$(HEADERS)	$(RAT_SIMFILES)
	$(VCS) $^ -o simv
	./simv | tee program.out

syn_rat:	syn_simv_rat
	./syn_simv_rat | tee syn_program.out

syn_simv_rat:	$(HEADERS)	$(RAT)	testbench/rat_testbench.sv
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv_rat

$(RAT):	$(RAT_SYNFILES)	$(SYNTH_DIR)/rat.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./rat.tcl | tee rat_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(RAT)

#

#DECODER RULES

export DECODER_SIMFILES	=	verilog/id/decoder.sv testbench/decoder_testbench.sv
export DECODER_SYNFILES	=	verilog/id/decoder.sv
export DECODER = $(SYNTH_DIR)/decoder.vg

decoder:	$(HEADERS)	$(DECODER_SIMFILES)
	$(VCS) $^ -o simv

syn_decoder:	syn_simv_decoder
	./syn_simv_decoder | tee syn_program.out

syn_simv_decoder:	$(HEADERS)	$(DECODER)	testbench/decoder_testbench.sv
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv_decoder

$(DECODER):	$(DECODER_SYNFILES)	$(SYNTH_DIR)/decoder.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./decoder.tcl | tee decoder_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(DECODER)

#

export ID_STAGE_SIMFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/id/rat.sv	verilog/id/prf.sv	verilog/id/decoder.sv	verilog/id/id_stage.sv	testbench/id_stage_testbench.sv
export ID_STAGE_SYNFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v	verilog/id/rat.sv	verilog/id/prf.sv	verilog/id/decoder.sv	verilog/id/id_stage.sv
export ID_STAGE = $(SYNTH_DIR)/id_stage.vg
export BRANCH_PREDICTOR_SIMFILES	=	verilog/id/branch_predictor.sv

branch_predictor:	$(HEADERS)	$(ID_STAGE_SIMFILES)
	$(VCS) $^ -o simv

export ID_STAGE_SIMFILES	=	verilog/utility/wand_sel.v	verilog/utility/ps.v verilog/id/branch_predictor.sv	verilog/id/rat.sv	verilog/id/prf.sv	verilog/id/decoder.sv	verilog/id/id_stage.sv	testbench/id_stage_testbench.sv

id_stage:	$(HEADERS)	$(ID_STAGE_SIMFILES)
	$(VCS) $^ -o simv

# Fetch Testing
syn_id_stage:	syn_simv_id_stage
	./syn_simv_id_stage | tee syn_program.out

syn_simv_id_stage:	$(HEADERS)	$(ID_STAGE)	testbench/id_stage_testbench.sv
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv_id_stage

$(ID_STAGE):	$(ID_STAGE_SYNFILES)	$(SYNTH_DIR)/id_stage.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./id_stage.tcl | tee id_stage_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(ID_STAGE)

#################
# Fetch Testing #
#################
export ICACHE_SIMFILES  = verilog/cache/cachemem.sv verilog/icache.sv
export ICACHE_TESTBENCH = testbench/fetch_testbench/icache_testbench.sv
ICACHE  = $(SYNTH_DIR)/icache.vg
icache:	$(HEADERS) $(ICACHE_SIMFILES) $(ICACHE_TESTBENCH)
	$(VCS) $^ -o icache_syn_simv
	./icache_syn_simv | tee program.out

icache_syn:	icache_syn_simv
	./icache_syn_simv | tee icache_syn_program.out

icache_syn_simv:	$(HEADERS) $(ICACHE) $(ICACHE_TESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o icache_syn_simv

$(ICACHE):	$(ICACHE_SIMFILES)	$(SYNTH_DIR)/icache.tcl 
	cd $(SYNTH_DIR) && dc_shell-t -f ./icache.tcl | tee icache_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(ICACHE)

export IBUFFER_SIMFILES  = $(ICACHE_SIMFILES) verilog/instruction_buffer.sv
export IBUFFER_TESTBENCH = testbench/mem.sv testbench/fetch_testbench/instruction_buffer_tb.sv
IBUFFER  = $(SYNTH_DIR)/instruction_buffer.vg
ibuffer:	$(HEADERS) $(IBUFFER_SIMFILES) $(IBUFFER_TESTBENCH)
	$(VCS) $^ -o simv
	./simv | tee program.out

ibuffer_syn:	ibuffer_syn_simv
	./ibuffer_syn_simv | tee ibuffer_syn_program.out

ibuffer_syn_simv:	$(HEADERS) $(IBUFFER) $(IBUFFER_TESTBENCH)
	$(VCS) +memcbk $(HEADERS) $(IBUFFER) $(IBUFFER_TESTBENCH) $(LIB) -o ibuffer_syn_simv

$(IBUFFER):	$(IBUFFER_SIMFILES)	$(SYNTH_DIR)/instruction_buffer.tcl 
	cd $(SYNTH_DIR) && dc_shell-t -f ./instruction_buffer.tcl | tee ibuffer_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(IBUFFER)


# Synthesis
$(FU):	$(FU_SYNFILES)	$(SYNTH_DIR)/functional_unit.tcl 
	cd $(SYNTH_DIR) && dc_shell-t -f ./functional_unit.tcl | tee functional_unit_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(FU)

syn_fu:	syn_simv_fu
	./syn_simv_fu | tee syn_program.out

syn_simv_fu:	$(HEADERS)	$(FU)	testbench/fu_testbench.sv
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv_fu

export IF_STAGE_SIMFILES	=	$(IBUFFER_SIMFILES) verilog/btb.sv verilog/if_stage.sv
export IF_STAGE_TESTBENCH	=	testbench/mem.sv testbench/fetch_testbench/if_testbench.sv
IF_STAGE  = $(SYNTH_DIR)/if_stage.vg
if_stage:	$(HEADERS)	$(IF_STAGE_SIMFILES) $(IF_STAGE_TESTBENCH)
	$(VCS) $^ -o simv
	./simv | tee program.out
	
if_stage_syn:	if_stage_syn_simv
	./if_stage_syn_simv | tee if_stage_syn_program.out

if_stage_syn_simv:	$(HEADERS) $(IF_STAGE) $(IF_STAGE_TESTBENCH)
	$(VCS) +memcbk $^ $(LIB) -o if_stage_syn_simv

$(IF_STAGE):	$(IF_STAGE_SIMFILES)	$(SYNTH_DIR)/if_stage.tcl 
	cd $(SYNTH_DIR) && dc_shell-t -f ./if_stage.tcl | tee if_stage_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(IF_STAGE)

dcache_syn:	dcache_syn_simv
	./dcache_syn_simv | tee dcache_syn_program.out

dcache_syn_simv:	$(HEADERS) $(DCACHE) $(DCACHE_TESTBENCH)
	$(VCS) +memcbk +lint=TFIPC-L $^ $(LIB) -o dcache_syn_simv

lsq_syn:	lsq_syn_simv
	./lsq_syn_simv | tee lsq_syn_program.out

lsq_syn_simv:	$(HEADERS) $(LSQ) $(LSQ_TESTBENCH)
	$(VCS) +memcbk +lint=TFIPC-L $^ $(LIB) -o lsq_syn_simv

# RS testing
syn_rs:	syn_simv_rs
	./syn_simv_rs | tee syn_program.out

$(ROB):	$(ROB_SYNFILES)	$(SYNTH_DIR)/rob.tcl 
	cd $(SYNTH_DIR) && dc_shell-t -f ./rob.tcl | tee rob_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(ROB)

$(RS):	$(RS_SYNFILES)	$(SYNTH_DIR)/reservation_station.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./reservation_station.tcl | tee reservation_station_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(RS)

$(LSQ):	$(LSQ_SYNFILES)	$(SYNTH_DIR)/lsq.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./lsq.tcl | tee lsq_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(LSQ)

$(DCACHE):	$(DCACHE_SYNFILES)	$(SYNTH_DIR)/dcache.tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./dcache.tcl | tee dcache.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(DCACHE)

$(CACHE): $(CACHEFILES) $(SYNTH_DIR)/$(CACHE_NAME).tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./$(CACHE_NAME).tcl | tee $(CACHE_NAME)_synth.out

$(PIPELINE): $(SIMFILES)	$(CACHE)	$(SYNTH_DIR)/$(PIPELINE_NAME).tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./$(PIPELINE_NAME).tcl | tee $(PIPELINE_NAME)_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(PIPELINE)

syn_all:	syn_simv
	./syn_simv | tee syn_program.out

syn_simv:	$(HEADERS) $(SYNFILES)	$(SYNTH_DIR)/$(PIPELINE_NAME)_svsim.sv $(TESTBENCHFULL)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv

syn_vis_simv:	$(HEADERS) $(SYNFILES)	$(SYNTH_DIR)/$(PIPELINE_NAME)_svsim.sv  $(VTUBER)
	$(VCS) $(VISFLAGS) $(VTUBER) $(SYNFILES) -o syn_vis_simv
		./syn_vis_simv

syn:	syn_simv
	./syn_simv | tee syn_program.out

.PHONY: syn
