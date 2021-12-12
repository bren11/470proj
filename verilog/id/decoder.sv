/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  id_stage.v                                          //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      //
//                 decode the instruction fetch register operands, and //
//                 compute immediate operand (if applicable)           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps


  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_ID_PACKET [`N-1:0]     if_packet,

	output ALU_OPA_SELECT 	[`N-1:0]  						opa_select,
	output ALU_OPB_SELECT 	[`N-1:0]  						opb_select,
    output FUNC_UNIT_TYPE 	[`N-1:0]  						func_unit,
	output ALU_FUNC       	[`N-1:0]  						alu_func,
	output logic 			[`N-1:0]       					cond_branch, uncond_branch,
	output logic 			[`N-1:0]           				csr_op,    // used for CSR operations, we only used this as
	             			           									//a cheap way to get the return code out
	output logic 			[`N-1:0]           				halt,      // non-zero on a halt
	output logic 			[`N-1:0]           				illegal,    // non-zero on an illegal instruction
	output logic 			[`N-1:0]           				valid_inst,  // for counting valid instructions executed
	output logic			[`N-1:0]						dest_reg_valid
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)

);

	INST [`N-1:0] inst;
	logic [`N-1:0] valid_inst_in;

    for(genvar n_i = 0; n_i < `N; ++n_i) begin

        assign inst[n_i]          = if_packet[n_i].inst;
        assign valid_inst_in[n_i] = if_packet[n_i].valid;
        assign valid_inst[n_i]    = valid_inst_in[n_i] & ~illegal[n_i];


		always_comb begin
			// default control values:
			// - valid instructions must override these defaults as necessary.
			//	 opa_select, opb_select, and alu_func should be set explicitly.
			// - invalid instructions should clear valid_inst.
			// - These defaults are equivalent to a noop
			// * see sys_defs.vh for the constants used here
			opa_select[n_i] = OPA_IS_RS1;
			opb_select[n_i] = OPB_IS_RS2;
            func_unit[n_i] = ADD;
			alu_func[n_i] = ALU_ADD;
			csr_op[n_i] = `FALSE;
			//rd_mem[n_i] = `FALSE;
			//wr_mem[n_i] = `FALSE;
			cond_branch[n_i] = `FALSE;
			uncond_branch[n_i] = `FALSE;
			dest_reg_valid[n_i] = `FALSE;
			halt[n_i] = `FALSE;
			illegal[n_i] = `FALSE;
			if(valid_inst_in[n_i]) begin
				casez (inst[n_i])
					`RV32_LUI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opa_select[n_i] = OPA_IS_ZERO;
						opb_select[n_i] = OPB_IS_U_IMM;
                        //ADD
					end
					`RV32_AUIPC: begin
						dest_reg_valid[n_i]   = `TRUE;
						opa_select[n_i] = OPA_IS_PC;
						opb_select[n_i] = OPB_IS_U_IMM;
						alu_func[n_i] = ALU_ADD;
                        //ADD
					end
					`RV32_JAL: begin
						dest_reg_valid[n_i]      = `TRUE;
						opa_select[n_i]    = OPA_IS_PC;
						opb_select[n_i]    = OPB_IS_J_IMM;
						uncond_branch[n_i] = `TRUE;
                        func_unit[n_i]     = BRANCH;
						alu_func[n_i]	= ALU_JAL;
					end
					`RV32_JALR: begin
						dest_reg_valid[n_i]      = `TRUE;
						opa_select[n_i]    = OPA_IS_RS1;
						opb_select[n_i]    = OPB_IS_I_IMM;
						uncond_branch[n_i] = `TRUE;
                        func_unit[n_i]     = BRANCH;
						alu_func[n_i]	= ALU_JALR;
					end
					`RV32_BEQ: begin
						opb_select[n_i]  = OPB_IS_B_IMM;
						cond_branch[n_i] = `TRUE;
                        func_unit[n_i]   = BRANCH;
						alu_func[n_i]	= ALU_BEQ;
					end `RV32_BNE: begin
						opb_select[n_i]  = OPB_IS_B_IMM;
						cond_branch[n_i] = `TRUE;
                        func_unit[n_i]   = BRANCH;
						alu_func[n_i]	= ALU_BNE;
					end `RV32_BLT: begin
						opb_select[n_i]  = OPB_IS_B_IMM;
						cond_branch[n_i] = `TRUE;
                        func_unit[n_i]   = BRANCH;
						alu_func[n_i]	= ALU_BLT;
					end `RV32_BGE: begin
						opb_select[n_i]  = OPB_IS_B_IMM;
						cond_branch[n_i] = `TRUE;
                        func_unit[n_i]   = BRANCH;
						alu_func[n_i]	= ALU_BGE;
					end `RV32_BLTU: begin
						opb_select[n_i]  = OPB_IS_B_IMM;
						cond_branch[n_i] = `TRUE;
                        func_unit[n_i]   = BRANCH;
						alu_func[n_i]	= ALU_BLTU;
					end `RV32_BGEU: begin
						opb_select[n_i]  = OPB_IS_B_IMM;
						cond_branch[n_i] = `TRUE;
                        func_unit[n_i]   = BRANCH;
						alu_func[n_i]	= ALU_BGEU;
					end
					`RV32_LB: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]	= ALU_LB;
                        func_unit[n_i]  = MEM;
					end
					`RV32_LH: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]	= ALU_LH;
                        func_unit[n_i]  = MEM;
					end
					`RV32_LW: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]	= ALU_LW;
                        func_unit[n_i]  = MEM;
					end
					`RV32_LBU: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]	= ALU_LBU;
                        func_unit[n_i]  = MEM;
					end
					`RV32_LHU: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]	= ALU_LHU;
                        func_unit[n_i]  = MEM;
					end
					`RV32_SB: begin
						opb_select[n_i] = OPB_IS_S_IMM;
						alu_func[n_i]	= ALU_SB;
                        func_unit[n_i]  = MEM;
					end
					`RV32_SH: begin
						opb_select[n_i] = OPB_IS_S_IMM;
						alu_func[n_i]	= ALU_SH;
                        func_unit[n_i]  = MEM;
					end
					`RV32_SW: begin
						opb_select[n_i] = OPB_IS_S_IMM;
						alu_func[n_i]	= ALU_SW;
                        func_unit[n_i]  = MEM;
					end
					`RV32_ADDI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
                        //ADD
					end
					`RV32_SLTI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_SLT;
                        //ADD
					end
					`RV32_SLTIU: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_SLTU;
                        //ADD
					end
					`RV32_ANDI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_AND;
                        //ADD
					end
					`RV32_ORI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_OR;
                        //ADD
					end
					`RV32_XORI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_XOR;
                        //ADD
					end
					`RV32_SLLI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_SLL;
                        //ADD
					end
					`RV32_SRLI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_SRL;
                        //ADD
					end
					`RV32_SRAI: begin
						dest_reg_valid[n_i]   = `TRUE;
						opb_select[n_i] = OPB_IS_I_IMM;
						alu_func[n_i]   = ALU_SRA;
                        //ADD
					end
					`RV32_ADD: begin
						dest_reg_valid[n_i]   = `TRUE;
                        //ADD
					end
					`RV32_SUB: begin
						dest_reg_valid[n_i]  = `TRUE;
						alu_func[n_i]   = ALU_SUB;
                        //ADD
					end
					`RV32_SLT: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_SLT;
                        //ADD
					end
					`RV32_SLTU: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_SLTU;
                        //ADD
					end
					`RV32_AND: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_AND;
                        //ADD
					end
					`RV32_OR: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_OR;
                        //ADD
					end
					`RV32_XOR: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_XOR;
                        //ADD
					end
					`RV32_SLL: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_SLL;
                        //ADD
					end
					`RV32_SRL: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_SRL;
                        //ADD
					end
					`RV32_SRA: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_SRA;
                        //ADD
					end
					`RV32_MUL: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_MUL;
                        func_unit[n_i]  = MULT;
					end
					`RV32_MULH: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_MULH;
                        func_unit[n_i]  = MULT;
					end
					`RV32_MULHSU: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_MULHSU;
                        func_unit[n_i]  = MULT;
					end
					`RV32_MULHU: begin
						dest_reg_valid[n_i]   = `TRUE;
						alu_func[n_i]   = ALU_MULHU;
                        func_unit[n_i]  = MULT;
					end
					`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
						csr_op[n_i] = `TRUE;
					end
					`WFI: begin
						halt[n_i] = `TRUE;
					end
					default: illegal[n_i] = `TRUE;

			endcase // casez (inst)
			end // if(valid_inst_in)
		end // always
	end
endmodule // decoder
