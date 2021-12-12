/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

/* Synthesis testing definition, used in DUT module instantiation */

`ifdef  SYNTH_TEST
`define DUT(mod) mod``_svsim
`else
`define DUT(mod) mod
`endif

//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////
`define XLEN 32

`define BRANCH_PREDICTOR_ON 1
`define BRANCH_PREDICTION_BITS 3
`define GLOBAL_HISTORY_SIZE `BRANCH_PREDICTION_BITS
`define BRANCH_PREDICTION_PC_BITS `BRANCH_PREDICTION_BITS
`define PREDICTION_TABLE_SIZE (1 << `BRANCH_PREDICTION_BITS)

`define CACHE_MODE //removes the byte-level interface from the memory mode, DO NOT MODIFY!
`define NUM_MEM_TAGS           15

`define MEM_DATA_BITS		   64
`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   10.0
`define SYNTH_CLOCK_PERIOD     11.5 // Clock period for synth and memory latency

`define MEM_LATENCY_IN_CYCLES (100.0/`SYNTH_CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period).  The default behavior for
// float to integer conversion is rounding to nearest

// bits for reg index
`define REG_INDEX_BITS $clog2(`XLEN)

// Number of lines in the BTB

`define BTB_NUM_LINES 32
`define BTB_IDX_BITS $clog2(`BTB_NUM_LINES)
`define BTB_TAG_BITS `XLEN-`BTB_IDX_BITS-2

// degree of superscalar
`define N 8
`define HALF_N `N/2
`define NLOG $clog2(`N)

`define ROB_NUM_ENTRIES 32
`define ROB_NUM_INDEX_BITS $clog2(`ROB_NUM_ENTRIES)

// prf defines
`define PRF_NUM_ENTRIES `ROB_NUM_ENTRIES +  `XLEN + `N
`define PRF_NUM_INDEX_BITS $clog2(`PRF_NUM_ENTRIES)

// rs defines
`define RS_NUM_ENTRIES 16
`define RS_NUM_INDEX_BITS $clog2(`RS_NUM_ENTRIES)

`define NUM_FU_TYPES	4'd4

`define NUM_ADDERS 		`N
`define NUM_MULTS		`N
`define NUM_BRANCHES	`N
`define NUM_MEMS		`N

`define LOAD_QUEUE_SIZE 12
`define STORE_QUEUE_SIZE 8
`define LOAD_QUEUE_BITS $clog2(`LOAD_QUEUE_SIZE)
`define STORE_QUEUE_BITS $clog2(`STORE_QUEUE_SIZE)
`define LSQ_INDEX_BITS $clog2(`LOAD_QUEUE_SIZE > `STORE_QUEUE_SIZE ? `LOAD_QUEUE_SIZE : `STORE_QUEUE_SIZE)

`define FUNC_UNIT_NUM `NUM_ADDERS + `NUM_MULTS + `NUM_BRANCHES + `NUM_MEMS

`define MULT_STAGES 4

`define ARF_NUM_ENTRIES `XLEN
`define ARF_NUM_INDEX_BITS $clog2(`ARF_NUM_ENTRIES)

`define RAT_SIZE `ARF_NUM_ENTRIES

`define INSTR_BUFFER_LEN    6'h13
`define IBUF_DECODE_MIN     `N



/*  I-Cache */
`define ICACHE_BLOCK_SIZE           8
`define ICACHE_NUM_LINES            16
`define ICACHE_NUM_VICTIM_ENTIRES   2
`define ICACHE_RD_PORTS             `N
`define ICACHE_WR_PORTS             1
`define ICACHE_DATA_BITS            `ICACHE_BLOCK_SIZE*8

typedef struct packed {
    logic [`XLEN-1-$clog2(`ICACHE_NUM_LINES)-$clog2(`ICACHE_BLOCK_SIZE):0] tag;
    logic [$clog2(`ICACHE_NUM_LINES)-1:0]   index;    //
    logic [$clog2(`ICACHE_BLOCK_SIZE)-1:0]  offset;   // 8 Byte blocks
} ICACHE_DMAP_ADDR;

/* D-Cache*/
`define LSQ_NUM_LOADS  `NUM_MEMS // TODO: make sure this is still right
`define LSQ_NUM_STORES  1

`define DCACHE_BLOCK_SIZE           8
`define DCACHE_NUM_LINES            32
`define DCACHE_RD_PORTS             `LSQ_NUM_LOADS + `LSQ_NUM_STORES
`define DCACHE_WR_PORTS             `LSQ_NUM_STORES + 1	// (<=1 store) + (<=1 updated cache block)
`define DCACHE_DATA_BITS            `DCACHE_BLOCK_SIZE*8
`define DCACHE_TAG_BITS				`XLEN - $clog2(`DCACHE_NUM_LINES) - $clog2(`DCACHE_BLOCK_SIZE)
`define DCACHE_MEMS_PER_BLOCK		`DCACHE_BLOCK_SIZE/8
`define DCACHE_BLOCK_BITS		    `DCACHE_BLOCK_SIZE/8

typedef struct packed {
    logic [`DCACHE_TAG_BITS-1:0] 	 	    tag;
    logic [$clog2(`DCACHE_NUM_LINES)-1:0]   index;
    logic [$clog2(`DCACHE_BLOCK_SIZE)-1:0]  offset;   // 8 Byte blocks
} DCACHE_DMAP_ADDR;

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} DCACHE_BLOCK;

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

`define MSHR_NUM_ENTRIES `LSQ_NUM_LOADS + 12
typedef struct packed {
	/* Block Address */
	logic [`DCACHE_TAG_BITS-1:0]               tag;
	logic [$clog2(`DCACHE_NUM_LINES)-1:0]      index;

	/* Miss Logic */
	logic [3:0]  mem_tag;
	logic  valid;
	logic  requested;
} DCACHE_MSHR_ENTRY;

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;


//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
typedef enum logic [5:0] {
	ALU_ADD     = 6'h00,
	ALU_SUB     = 6'h01,
	ALU_SLT     = 6'h02,
	ALU_SLTU    = 6'h03,
	ALU_AND     = 6'h04,
	ALU_OR      = 6'h05,
	ALU_XOR     = 6'h06,
	ALU_SLL     = 6'h07,
	ALU_SRL     = 6'h08,
	ALU_SRA     = 6'h09,
	ALU_MUL     = 6'h0a,
	ALU_MULH    = 6'h0b,
	ALU_MULHSU  = 6'h0c,
	ALU_MULHU   = 6'h0d,
	ALU_REM     = 6'h0e,
	ALU_REMU    = 6'h0f,
	ALU_LB		= 6'h10,
	ALU_LH		= 6'h11,
	ALU_LW		= 6'h12,
	ALU_LBU		= 6'h13,
	ALU_LHU		= 6'h14,
	ALU_SB		= 6'h15,
	ALU_SH		= 6'h16,
	ALU_SW		= 6'h17,
	ALU_JAL		= 6'h18,
	ALU_JALR	= 6'h19,
	ALU_BEQ		= 6'h1a,
	ALU_BNE		= 6'h1b,
	ALU_BLT		= 6'h1c,
	ALU_BGE		= 6'h1d,
	ALU_BLTU	= 6'h1e,
	ALU_BGEU	= 6'h1f
} ALU_FUNC;



//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0

//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;
//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	//TODO HOW DO WE DO WITH NPC and WHAT DOES IT MEAN
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC
	logic [`BRANCH_PREDICTION_BITS-1:0] bp_indicies;
	logic taken;
} IF_ID_PACKET;


//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value
	logic [`XLEN-1:0] rs2_value;    // reg B value

	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction

	logic [4:0] dest_reg_idx;  // destination (writeback) register index
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} ID_EX_PACKET_OLD;

typedef enum logic [1:0] {
	ADD		= 2'd0,
	MULT	= 2'd1,
	BRANCH	= 2'd2,
	MEM		= 2'd3
} FUNC_UNIT_TYPE;


typedef struct packed {
	logic [`XLEN-1:0] 	NPC;   // PC + 4
	logic [`XLEN-1:0] 	PC;    // PC

	logic [`XLEN-1:0] 	opa_value;    // reg A value
	logic [`XLEN-1:0] 	opb_value;    // reg B value
	logic [`XLEN-1:0]	offset_value; //immidiate from instruction
	logic 		 		opa_ready;
	logic				opb_ready;

	INST inst;                 // instruction

	logic [`ARF_NUM_INDEX_BITS-1:0]		arch_reg_dest;
	logic [`PRF_NUM_INDEX_BITS-1:0] 	phys_reg_dest;  // destination (writeback) register index
	ALU_FUNC    		alu_func;      // ALU function select (ALU_xxx *)
	FUNC_UNIT_TYPE		func_unit;
	logic [`BRANCH_PREDICTION_BITS-1:0] bp_indicies;
	logic       		cond_branch;   // is inst a conditional branch?
	logic       		uncond_branch; // is inst an unconditional branch?
	logic       		halt;          // is this a halt?
	logic       		illegal;       // is this instruction illegal?
	logic       		csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       		valid;         // is inst a valid instruction to be counted for CPI calculation
} ID_EX_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] alu_result; // alu_result
	logic [`XLEN-1:0] NPC; //pc + 4
	logic             take_branch; // is this a taken branch?
	//pass throughs from decode stage
	logic [`XLEN-1:0] rs2_value;
	logic             rd_mem, wr_mem;
	logic [4:0]       dest_reg_idx;
	logic             halt, illegal, csr_op, valid;
	logic [2:0]       mem_size; // byte, half-word or word
} EX_MEM_PACKET;

typedef struct packed {
	logic [`NUM_ADDERS-1:0][`RS_NUM_ENTRIES-1:0] add_inst_gnts;
	logic [`NUM_MULTS-1:0][`RS_NUM_ENTRIES-1:0] mult_inst_gnts;
	logic [`NUM_BRANCHES-1:0][`RS_NUM_ENTRIES-1:0] branch_inst_gnts;
	logic [`NUM_MEMS-1:0][`RS_NUM_ENTRIES-1:0] mem_inst_gnts;
} RS_GNT_BUS_T;

typedef struct packed {
	logic [`NUM_ADDERS-1:0][`NUM_ADDERS-1:0] add_fu_gnts;
	logic [`NUM_MULTS-1:0][`NUM_MULTS-1:0] mult_fu_gnts;
	logic [`NUM_BRANCHES-1:0][`NUM_BRANCHES-1:0] branch_fu_gnts;
	logic [`NUM_MEMS-1:0][`NUM_MEMS-1:0] mem_fu_gnts;
} FU_AVAIL_GNT_BUS_T;


typedef struct packed {
	logic							valid;
	INST  							inst; 		// For visual debugger
	logic 							op1_ready;
	logic [`XLEN-1:0]				op1_value;
	logic							op2_ready;
	logic [`XLEN-1:0]				op2_value;
	logic [`ARF_NUM_INDEX_BITS-1:0]	dest_arf;
	logic [`PRF_NUM_INDEX_BITS-1:0]	dest_prf;
	logic [`ROB_NUM_INDEX_BITS-1:0] rob_entry;
	logic [`XLEN-1:0] 				offset;
	logic [`XLEN-1:0] 				pc;
	logic [`LSQ_INDEX_BITS-1:0] 	lsq_index;
	FUNC_UNIT_TYPE 					func_unit_type;
	ALU_FUNC						func_op_type;
} STATION;

typedef struct packed {
	logic 							valid;
	logic [`XLEN-1:0]				op1_value;
	logic [`XLEN-1:0]				op2_value;
	logic [`ARF_NUM_INDEX_BITS-1:0]	dest_arf;
	logic [`PRF_NUM_INDEX_BITS-1:0]	dest_prf;
	logic [`ROB_NUM_INDEX_BITS-1:0]	rob_entry;
	logic [`XLEN-1:0] 				offset;
	logic [`XLEN-1:0] 				pc;
	logic [`LSQ_INDEX_BITS-1:0] 	lsq_index;
	ALU_FUNC						func_op_type;
} FUNC_UNIT_PACKET;

typedef struct packed {
	logic 							valid;
	logic [`PRF_NUM_INDEX_BITS-1:0] dest_prf;
	logic [`ROB_NUM_INDEX_BITS-1:0] rob_entry;
	logic [`XLEN-1:0]				branch_address;
	logic [`XLEN-1:0] 				value;
	logic							value_valid;
} FUNC_OUTPUT;

typedef union packed {
	FUNC_UNIT_PACKET [`FUNC_UNIT_NUM-1:0] rs_to_func;
	struct packed {
		FUNC_UNIT_PACKET	[`NUM_ADDERS-1:0]	adders;
		FUNC_UNIT_PACKET	[`NUM_MULTS-1:0]	mults;
		FUNC_UNIT_PACKET	[`NUM_BRANCHES-1:0]	branches;
		FUNC_UNIT_PACKET	[`NUM_MEMS-1:0]		mems;
	} types;
} RS_FUNC_PACKET;

//IF WE CHANGE NUMBERS OF FUNCTIONAL UNITS, CHANGE RS AS WELL
typedef union packed {
	logic [`FUNC_UNIT_NUM-1:0] frees;
	struct packed {
		logic [`NUM_ADDERS-1:0] adders_free;
		logic [`NUM_MULTS-1:0] mults_free;
		logic [`NUM_BRANCHES-1:0] branches_free;
		logic [`NUM_MEMS-1:0] mems_free;
	} types;
} FREE_FUNC_UNITS;

typedef union packed {
	logic [`FUNC_UNIT_NUM-1:0] select;
	struct packed {
		logic [`NUM_ADDERS-1:0] adders;
		logic [`NUM_MULTS-1:0] mults;
		logic [`NUM_BRANCHES-1:0] branches;
		logic [`NUM_MEMS-1:0] mems;
	} types;
}FUNC_UNIT_SEL;

typedef union packed {
	FUNC_OUTPUT [`FUNC_UNIT_NUM-1:0] outputs;
	struct packed {
		FUNC_OUTPUT [`NUM_ADDERS-1:0] adders;
		FUNC_OUTPUT [`NUM_MULTS-1:0] mults;
		FUNC_OUTPUT [`NUM_BRANCHES-1:0] branches;
		FUNC_OUTPUT [`NUM_MEMS-1:0] mems;
	} types;
}FUNC_UNIT_OUT;

typedef struct packed {
	logic valid;
	logic [`PRF_NUM_INDEX_BITS-1:0] dest_prf;
	logic [`ROB_NUM_INDEX_BITS-1:0] rob_entry;
	logic [`XLEN-1:0]				branch_address;
	logic [`XLEN-1:0]				value;
	logic							value_valid;
} CDB;

typedef struct packed {
	logic ready;
	logic [`XLEN-1:0] value;
} PRF_ENTRY;

typedef struct packed{
	logic valid;
	logic [`REG_INDEX_BITS-1:0] changed_arch_reg;
	logic [`XLEN-1:0]			arch_reg_new_prf;
}RAT_FORWARD_PACKET;

typedef struct packed{
	logic valid;
	logic [`ARF_NUM_INDEX_BITS-1:0] dest_arf;
	logic [`PRF_NUM_INDEX_BITS-1:0] dest_prf;
}ROB_COMMIT_PACKET;

typedef struct packed {
	logic							valid;
	INST  							inst; 		// For visual debugger
	logic							executed;
	logic 							halt;
	logic [`ARF_NUM_INDEX_BITS-1:0]	dest_arf;
	logic [`PRF_NUM_INDEX_BITS-1:0]	dest_prf;
	logic [`XLEN-1:0]				calculated_branch_address;
	logic [`XLEN-1:0]				predicted_branch_address;
	logic [`XLEN-1:0]				pc;
	logic [`LSQ_INDEX_BITS-1:0] 	lsq_index;
	ALU_FUNC						func_op_type;
	logic [`BRANCH_PREDICTION_BITS-1:0] bp_indicies;
} ROB_ENTRY;

typedef struct packed {
	logic valid;
	logic correct;
	logic [`XLEN-1:0]	branch_address;
	logic [`XLEN-1:0]				pc;
	logic taken;
	logic [`BRANCH_PREDICTION_BITS-1:0] bp_indicies;
} BRANCH_PREDICTION_PACKET;


typedef struct packed {
    logic valid;
    logic [`BTB_TAG_BITS-1:0] tag;
    logic [`XLEN-1:0] addr;
} BTB_LINE;

typedef struct packed {
	logic requested;		// Has been requested to icache/memory
	logic ready;			// Ready to be decoded
    INST  inst;				// Instruction from memory
	logic [`XLEN-1:0] NPC;	// Why do we need this
	logic [`XLEN-1:0] PC;	// Address of instruction
	logic [3:0] mem_tag;
	logic [`BRANCH_PREDICTION_BITS-1:0] bp_indicies;
	logic						taken;
} IF_BUFFER_STATION;

typedef struct packed {
	logic valid;		// Has been requested to icache/memory
	logic store;			// Ready to be decoded
	logic [`PRF_NUM_INDEX_BITS-1:0]	dest_prf;
	logic [`XLEN-1:0]				pc;
} LSQ_IN_PACKET;

typedef struct packed {
	logic valid;		// Has been requested to icache/memory
	logic [`LSQ_INDEX_BITS-1:0] lsq_index;			// Ready to be decoded
} STORES_READY;

typedef enum logic [2:0] {
	MEM_BYTE    = 3'h0,
	MEM_HALF    = 3'h1,
	MEM_WORD    = 3'h2,
	MEM_U_BYTE  = 3'h4,
	MEM_U_HALF  = 3'h5
} MEM_OP_TYPE;

typedef struct packed {
	logic valid;
	logic out_ready;
	logic ready_for_mem;
	logic has_address;
	logic [`ROB_NUM_INDEX_BITS-1:0] rob_entry;
	logic [`XLEN-1:0]				pc;
	DCACHE_DMAP_ADDR target_address;
	logic [`XLEN-1:0] value;
	MEM_OP_TYPE	      mem_size;
} STORE_QUEUE_ENTRY;

typedef struct packed {
	logic valid;
	logic out_ready;
	logic ready_for_mem;
	logic has_address;
	logic [`ROB_NUM_INDEX_BITS-1:0] rob_entry;
	logic [`XLEN-1:0]				pc;
	logic [`PRF_NUM_INDEX_BITS-1:0]	dest_prf;
	DCACHE_DMAP_ADDR target_address;
	logic [`XLEN-1:0] value;
	MEM_OP_TYPE	      mem_size;
	logic [`STORE_QUEUE_SIZE-1:0] age_addr_match;
} LOAD_QUEUE_ENTRY;

typedef union packed {
	logic [`LOAD_QUEUE_SIZE+`STORE_QUEUE_SIZE-1:0] united;
	struct packed {
		logic [`LOAD_QUEUE_SIZE-1:0] loads;
		logic [`STORE_QUEUE_SIZE-1:0] stores;
	} types;
} LSQ_OUT_READY;

typedef struct packed{
	logic valid;
	logic taken;
	logic [`XLEN-1:0] PC;
} ID_SPEC_HISTORY_UPDATE;

`endif // __SYS_DEFS_VH__
