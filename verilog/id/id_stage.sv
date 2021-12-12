module id_stage(
	input                           			clock,
	input                           			reset,
	input										nuke, //signal from rob, (a mispredicted branch)
	input CDB           [`N-1:0]    			cdb_in,
	input IF_ID_PACKET  [`N-1:0]    			if_id_packet_in,

	input [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rrat_entries, //coppied over to rat during a nuke
	input 				[`PRF_NUM_ENTRIES-1:0] 	rrat_free_list, //free list from rrat, used in rat for nuke
	input 				[`PRF_NUM_ENTRIES-1:0] 	free_vector_from_rrat, //a one hot list used as a command to free specific prf entries

	output ID_EX_PACKET [`N-1:0]	   			id_packet_out,

	// Visual debugger outputs
	output logic 								no_free_prf,
	output PRF_ENTRY 	[`PRF_NUM_ENTRIES-1:0] 	prf,
	output logic 		[`PRF_NUM_ENTRIES-1:0]  rat_free_list,
	output logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rat_entries,
	output ID_SPEC_HISTORY_UPDATE[`N-1:0] id_spec_history_packet
);

	ALU_OPA_SELECT 	[`N-1:0] 						opa_select;
    ALU_OPB_SELECT 	[`N-1:0] 						opb_select;

	logic          	[`N-1:0]  						dest_reg_valid;
    FUNC_UNIT_TYPE  [`N-1:0]    					func_unit;
    ALU_FUNC        [`N-1:0]    					alu_func;

    logic           [`N-1:0]    					cond_branch, uncond_branch;
    logic           [`N-1:0]    					csr_op;
    logic           [`N-1:0]    					halt;
	logic           [`N-1:0]    					illegal;
	logic           [`N-1:0]   					 	valid_inst;

    decoder dec(
		.if_packet(if_id_packet_in),
		.opa_select,
		.opb_select,
        .func_unit,
		.alu_func,
		.cond_branch,
		.uncond_branch,
		.csr_op,
		.halt,
        .illegal,
		.valid_inst,
		.dest_reg_valid
	);

	logic [`N-1:0]            valid_branch;
	
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg1;
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg2;
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg_dest;

	logic [`PRF_NUM_ENTRIES-1:0] free_vector_from_rat;


	logic [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg1;
	logic [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg2;

	logic [`N-1:0][`REG_INDEX_BITS-1:0] dest_reg;

	for(genvar n_i = 0; n_i < `N; ++n_i) begin
		assign arch_reg1[n_i] = if_id_packet_in[n_i].inst.r.rs1;
		assign arch_reg2[n_i] = if_id_packet_in[n_i].inst.r.rs2;

		assign dest_reg[n_i] = if_id_packet_in[n_i].inst.r.rd;
	end

	rat r(
		.clock,
	 	.reset,
		.nuke,
		.arch_reg1,
		.arch_reg2,
		.arch_reg_dest(dest_reg),
		.arch_reg_dest_valid(dest_reg_valid),
		.rrat_entries,
		.rrat_free_list,
		.free_vector_from_rrat,
		.phys_reg1,
		.phys_reg2,
		.phys_reg_dest,
		.no_free_prf,
		.free_list_o(rat_free_list),
		.rat_entries
	);


    logic   [`N-1:0][`XLEN-1:0]   				reg1_val;
    logic   [`N-1:0][`XLEN-1:0]   				reg2_val;
	logic   [`N-1:0]               				reg1_ready;
	logic   [`N-1:0]                			reg2_ready;

	logic [`PRF_NUM_ENTRIES-1:0] free_vector2prf;
	assign free_vector2prf = ~nuke ? free_vector_from_rrat : rrat_free_list;

	prf prf_(
		.clock,
		.reset,
		.phys_reg1,
		.phys_reg2,
		.cdb_in,
		.to_free_vector(free_vector2prf),
		.reg1_val,
		.reg2_val,
		.reg1_ready,
		.reg2_ready,
		.prf
	);


	for(genvar n_i = 0; n_i < `N; ++n_i) begin

		
		assign id_packet_out[n_i].NPC = if_id_packet_in[n_i].NPC;
		assign id_packet_out[n_i].PC = if_id_packet_in[n_i].PC;

		//decide opa and opb based on select signal
		//TODO: OFFSET NEEDS TO BE ITS OWN FIELD
		always_comb begin
			// Fix latch
			id_packet_out[n_i].offset_value = 0;

			id_packet_out[n_i].opa_value = 0;
			id_packet_out[n_i].opa_ready = 0;

			id_packet_out[n_i].opb_value = 0;
			id_packet_out[n_i].opb_ready = 0;
			

			case (opa_select[n_i])
				OPA_IS_RS1: begin
					id_packet_out[n_i].opa_value = reg1_val[n_i];
					id_packet_out[n_i].opa_ready = reg1_ready[n_i];
					if (arch_reg1[n_i] == 0) begin
						id_packet_out[n_i].opa_ready = `TRUE;
						id_packet_out[n_i].opa_value = 0;
					end
				end
				OPA_IS_NPC: begin
					id_packet_out[n_i].opa_value = reg1_val[n_i];
					id_packet_out[n_i].opa_ready = reg1_ready[n_i];
				end
				OPA_IS_PC: begin
					id_packet_out[n_i].opa_value = if_id_packet_in[n_i].PC;
					id_packet_out[n_i].opa_ready = `TRUE;
				end
				OPA_IS_ZERO: begin
					id_packet_out[n_i].opa_value = 0;
					id_packet_out[n_i].opa_ready = `TRUE;
				end
			endcase

			case (opb_select[n_i]) //added to also include offset_field output
				OPB_IS_RS2: begin
					id_packet_out[n_i].opb_value = arch_reg2[n_i] == 0 ? 0 : reg2_val[n_i];
					id_packet_out[n_i].opb_ready = arch_reg2[n_i] == 0 ? `TRUE : reg2_ready[n_i];
				end
				OPB_IS_I_IMM: begin
					id_packet_out[n_i].offset_value = `RV32_signext_Iimm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_value = `RV32_signext_Iimm(if_id_packet_in[n_i].inst); //put here just incase opb is used for offset :)
					id_packet_out[n_i].opb_ready = `TRUE; //I instruction has no opb Value;
				end
				OPB_IS_S_IMM: begin
					id_packet_out[n_i].offset_value = `RV32_signext_Simm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_value = arch_reg2[n_i] == 0 ? 0 : reg2_val[n_i];
					id_packet_out[n_i].opb_ready = arch_reg2[n_i] == 0 ? `TRUE : reg2_ready[n_i];
				end
				OPB_IS_B_IMM: begin
					id_packet_out[n_i].offset_value = `RV32_signext_Bimm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_value = arch_reg2[n_i] == 0 ? 0 : reg2_val[n_i];
					id_packet_out[n_i].opb_ready = arch_reg2[n_i] == 0 ? `TRUE : reg2_ready[n_i];
				end
				OPB_IS_U_IMM: begin
					id_packet_out[n_i].offset_value = `RV32_signext_Uimm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_value = `RV32_signext_Uimm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_ready = `TRUE;
				end
				OPB_IS_J_IMM: begin
					id_packet_out[n_i].offset_value = `RV32_signext_Jimm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_value = `RV32_signext_Jimm(if_id_packet_in[n_i].inst);
					id_packet_out[n_i].opb_ready = `TRUE;
				end
			endcase
		end

		assign id_packet_out[n_i].inst = if_id_packet_in[n_i].inst;
		assign id_packet_out[n_i].phys_reg_dest = phys_reg_dest[n_i];
		assign id_packet_out[n_i].alu_func = alu_func[n_i];
		assign id_packet_out[n_i].func_unit = func_unit[n_i];
		assign id_packet_out[n_i].cond_branch = cond_branch[n_i];
		assign id_packet_out[n_i].uncond_branch = uncond_branch[n_i];
		assign id_packet_out[n_i].halt = halt[n_i];
		assign id_packet_out[n_i].illegal = illegal[n_i];
		assign id_packet_out[n_i].csr_op = csr_op[n_i];
		assign id_packet_out[n_i].arch_reg_dest = dest_reg_valid[n_i] ? if_id_packet_in[n_i].inst.r.rd : 0;

		//add mux later on for branches and other things to invalidate instructions
		assign id_packet_out[n_i].valid = if_id_packet_in[n_i].valid && ~illegal[n_i];

		assign id_packet_out[n_i].bp_indicies = if_id_packet_in[n_i].bp_indicies;


		assign id_spec_history_packet[n_i].valid = cond_branch[n_i] || uncond_branch[n_i];
		assign id_spec_history_packet[n_i].taken = if_id_packet_in[n_i].taken;
		assign id_spec_history_packet[n_i].PC = if_id_packet_in[n_i].PC; //just for debug

	end

endmodule // module id_stage
