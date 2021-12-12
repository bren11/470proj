/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       //
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input         clock,          	        							// system clock
	input         reset,         	         							// system reset
	input         stall,      											// only go to next instruction when true

	input ID_SPEC_HISTORY_UPDATE [`N-1:0]		id_spec_history_packet,
	input							[`XLEN-1:0] corrected_branch_address,
	input 										branch_mispredict,
	input BRANCH_PREDICTION_PACKET 	[`N-1:0] 	committed_branches,		// Comitted branches
	input        					[63:0] 		mem2proc_data,          // Data coming back from instruction-memory
	input							[3:0]   	mem2proc_response,
	input							[3:0]   	mem2proc_tag,

	output logic 					[`XLEN-1:0] proc2mem_addr,      	// Address sent to memory
	output BUS_COMMAND                    		proc2mem_command,    	// command sent to memory

	// Visual debugger outputs
	output IF_ID_PACKET				[`N-1:0]  	if_packet_out,         	// Output data packet from IF going to ID, see sys_defs for signal information,
	output BTB_LINE [`BTB_NUM_LINES-1:0]  		cachemen,
	output logic  	[`N-1:0] [`XLEN-1:0]		PCs_reg,
	output logic 	[`N-1:0] [`XLEN-1:0] 		btb_addrs,
	output logic 	[`N-1:0] 			 		btb_hits,
	output logic 	[`XLEN-1:0] 		 		first_tk_addr,
	output logic	 				    		PC_enable
);
	/* Next PC Muxing and State */
	logic  [`N-1:0] [`XLEN-1:0]		NPCs_reg;
	logic  [`N-1:0] [`XLEN-1:0]		PCs_plus_4N;
	logic  [`N-1:0] [`XLEN-1:0]		n_PCs_reg;

	/* Branch Predictor */
	logic  [`N-1:0] [`BRANCH_PREDICTION_BITS-1:0] bp_indicies;
	logic  [`N-1:0] 						      taken;

	/* BTB Output Logic */			
	logic 	[$clog2(`N):0] 	num_taken, num_taken_reg;
	logic 	[`XLEN-1:0] 	first_tk_addr_reg;

	/* Instruction buffer */
	logic								   ib_structural_hazard;
	IF_BUFFER_STATION	[`N-1:0]           next_instructions;
	logic								   all_ready;
	logic [$clog2(`INSTR_BUFFER_LEN)-1:0]  ib_size;
	logic [`N-1:0]                         icache_hits;

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             Next PC/Prefetch Logic                       //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

	/* BTB Prediction  */
	btb btb_1 (
		/* Inputs */
		.clock(clock),
		.reset(reset),
		.PCs_in(PCs_plus_4N),							 	// PCs to look up
		.committed_branches(committed_branches),	    // Comitted branch instructions this cycle

		/* Outputs */
		.hits(btb_hits),								// Hit/miss for each PC in the BTB cachces
		.predicted_addresses(btb_addrs),					// Addresses returned for BTB
		.cachemen(cachemen)
	);

	/* GShare Branch Predictor */
	branch_predictor bp(
		.clock,
		.reset,
		.branch_mispredict,
		.id_spec_history_packet,
		.PC(PCs_plus_4N),
		.branch_prediction_resolves(committed_branches),
		.taken,
		.global_history_out(bp_indicies)
	);

	/* Generate bit-vector taking BTB values + i*4N */
	/* Only take the first entry */
	always_comb begin
		first_tk_addr = 0;
		num_taken = `N;
		for (int i = 0; i < `N; ++i) begin
			if (btb_hits[i]  && (taken[i])/*  || ~(`BRANCH_PREDICTOR_ON) )*/) begin
				first_tk_addr = btb_addrs[i];
				num_taken = i;
				break;
			end
		end
	end

	/* Caclulate PC + 4 for each way */
	for (genvar i = 0; i < `N; ++i) begin  : PC_plus_4_gen
		assign PCs_plus_4N[i] = (branch_mispredict)		? corrected_branch_address + (`N*4) + (i*4) :
								(num_taken_reg == `N-1) ? first_tk_addr_reg + (i*4)     : 
														  (i != 0) ? PCs_plus_4N[i-1] + 4 : PCs_reg[`N-1] + 4;      /* Or just Take PC +4 */
	end

	/* Select Next PC_reg */
	for (genvar i = 0; i < `N; ++i) begin : next_pc_reg_gen
		assign n_PCs_reg[i] = (branch_mispredict)     ? corrected_branch_address + (i*4)    :  /* Fetch miss predicted branch */
						      (i > num_taken)         ? first_tk_addr + ((i-num_taken-1)*4) :  /* Fetch predicted branch */
												        PCs_plus_4N[i];						   /* Fetch PC + 4N */
	end
	
	/* Caclulate NPCs */
	for (genvar i = 0; i < `N - 1; ++i) begin : next_pc_gen
		assign NPCs_reg[i] = PCs_reg[i+1];
	end
	assign NPCs_reg[`N-1] = n_PCs_reg[0];

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                      Instruction Buffer/Memory/Cache                     //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

	/**
	 * Instruction Buffer
	 *
	 * This circular buffer holds all instructions waiting
	 * to be decoded or waiting on the cache/memory unit
	 */
	instruction_buffer ib_1 (
		/* Inputs */
		.clock(clock),
		.reset(reset),
		.nuke(branch_mispredict),

		.mem2proc_data(mem2proc_data),
		.mem2proc_response(mem2proc_response),
		.mem2proc_tag(mem2proc_tag),

		.input_PCs(PCs_reg),
		.input_NPCs(NPCs_reg),
		.input_bp_indicies(bp_indicies),
		.input_taken(taken),

		.stall(stall),
		.enable(PC_enable),

		/* Outputs */
		.proc2mem_command(proc2mem_command),
		.proc2mem_addr(proc2mem_addr),

		.ib_structural_hazard(ib_structural_hazard),
		.ib_size,
		.icache_hits,
		.next_instrs(next_instructions),
		.all_ready
	);

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                               Output Logic                               //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

	/* Enable */
	/* The take-branch signal must override stalling (otherwise it may be lost) */
	assign PC_enable = (!ib_structural_hazard) | branch_mispredict;
	for (genvar i = 0; i < `N; ++i) begin: IF_assign_outputs
		assign if_packet_out[i].valid			= next_instructions[i].ready & !branch_mispredict;
		assign if_packet_out[i].inst			= next_instructions[i].inst;
		assign if_packet_out[i].NPC				= next_instructions[i].NPC;
		assign if_packet_out[i].PC 				= next_instructions[i].PC;
		assign if_packet_out[i].bp_indicies 	= next_instructions[i].bp_indicies;
		assign if_packet_out[i].taken			= next_instructions[i].taken;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			num_taken_reg     <= `SD `N;
			first_tk_addr_reg <= `SD  0;
			for (int i = 0; i < `N; i++)
				PCs_reg[i] <= `SD i * 4;       // initial PC value is 0
		end else if (PC_enable) begin
			PCs_reg           <= `SD n_PCs_reg; // transition to next PC
			num_taken_reg     <= `SD (branch_mispredict) ? `N : num_taken;
			first_tk_addr_reg <= `SD (branch_mispredict) ?  0 : first_tk_addr;
		end
	end

endmodule  // module if_stage
