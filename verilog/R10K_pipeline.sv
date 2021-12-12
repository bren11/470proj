/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  R10K_pipeline.v                                     //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __R10K_PIPELINE_V__
`define __R10K_PIPELINE_V__

`timescale 1ns/100ps

module pipeline (
	input 						        					clock,                    // System clock
	input 						        					reset,                    // System reset
	input 						[3:0]   					mem2proc_response,        // Tag from memory about current request
	input 						[63:0]  					mem2proc_data,            // Data coming back from memory
	input 						[3:0]   					mem2proc_tag,              // Tag from memory about current reply

	output logic 				[1:0]          				proc2mem_command,   // command sent to memory
	output logic 				[`XLEN-1:0]    				proc2mem_addr,      // Address sent to memory
	output logic 				[63:0]         				proc2mem_data,      // Data sent to memory
	output MEM_SIZE             							proc2mem_size,      // data size sent to memory
    output EXCEPTION_CODE       							error,

	// Testbench Outputs
	output ROB_COMMIT_PACKET	[`N-1:0]   					rob_committed_instructions,
	output ROB_ENTRY 			[`ROB_NUM_ENTRIES-1:0] 		rob_entries,
	output logic 				[`ROB_NUM_INDEX_BITS-1:0]  	head_index,
	output PRF_ENTRY 			[`PRF_NUM_ENTRIES-1:0] 		prf_entries,

	// Visual testbench outputs
	output logic                [`PRF_NUM_ENTRIES-1:0] 		rrat_free_list,
	output logic                [`PRF_NUM_ENTRIES-1:0] 		rat_free_list,
	output logic        		           				    if_id_enable,
	output IF_ID_PACKET			[`N-1:0]  					if_packet_out,
	output IF_ID_PACKET			[`N-1:0]  					if_id_packet_out,
	output BTB_LINE 			[`BTB_NUM_LINES-1:0]  		cachemen,
	output logic  				[`N-1:0] [`XLEN-1:0]		PCs_reg,
	output logic 				[`N-1:0] [`XLEN-1:0] 		btb_addrs,
	output logic 				[`N-1:0] 			 		btb_hits,
	output ID_EX_PACKET    		[`N-1:0]					id_packet_out,
	output ID_EX_PACKET    		[`N-1:0]					id_ex_packet_out,
	output logic                       						id_ex_stall,
	output logic                       						rs_structural_hazard,
	output logic 											prf_full,
	output logic 				[`XLEN-1:0] 		 		btb_first_tk_addr,
	output logic	 				    					PC_enable,
	output CDB                  [`N-1:0]    				cdb,
	output STATION 				[`RS_NUM_ENTRIES-1:0] 		reservation_stations,
	output logic 				[`ROB_NUM_INDEX_BITS-1:0]  	tail_index,
	output BRANCH_PREDICTION_PACKET    [`N-1:0]    			rob_committed_branches,
	output logic [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] 			rob_next_entries_indicies,
	output logic                                   			branch_mispredict,
	output logic                 [`XLEN-1:0] 				rob_br_mispredict_address,
	output logic                                   			rob_structural_hazard,
	output FREE_FUNC_UNITS                        		 	fu_availible_units,
	output FUNC_UNIT_OUT 									fu_out,
	output FREE_FUNC_UNITS 									fu_ready,
	output RS_FUNC_PACKET              						rs_to_func_packet,
	output logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] 	rat_entries,
	output logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] 	rrat_entries,
	logic                                   				lsq_structural_hazard,
	output LOAD_QUEUE_ENTRY [`LOAD_QUEUE_SIZE-1:0] 			load_queue,
	output STORE_QUEUE_ENTRY [`STORE_QUEUE_SIZE-1:0] 		store_queue,
	output STORES_READY                [`N-1:0]    			rob_stores_ready,
	output LSQ_IN_PACKET   [`N-1:0]						    lsq_in_packet
);

    IF_ID_PACKET	[`N-1:0]  	id_packet_in;

    logic                                   wfi_halt;


    logic   [`N-1:0][`LSQ_INDEX_BITS-1:0]   n_lsq_index;

    BUS_COMMAND                             data_proc2mem_command;
    logic           [`XLEN-1:0]             data_proc2mem_addr;
    logic           [63:0]                  data_proc2mem_data;

    BUS_COMMAND                             fetch_proc2mem_command;
    logic           [`XLEN-1:0]             fetch_proc2mem_addr;

    logic                   [`PRF_NUM_ENTRIES-1:0] rrat_free_vector;

    ROB_ENTRY [`N-1:0] id_dispatched_instrs_rob;

    ID_SPEC_HISTORY_UPDATE [`N-1:0] id_spec_history_packet;

    //////////////////////////////////////////////////
    //                                              //
    //              Memory Arbitration              //
    //                                              //
    //////////////////////////////////////////////////

    always_comb begin
        if (data_proc2mem_command == BUS_NONE) begin
            proc2mem_command = fetch_proc2mem_command;
            proc2mem_data = 0;
            proc2mem_addr = fetch_proc2mem_addr;
            proc2mem_size = DOUBLE;
        end else begin
            proc2mem_command = data_proc2mem_command;
            proc2mem_data = data_proc2mem_data;
            proc2mem_addr = data_proc2mem_addr;
            proc2mem_size = DOUBLE;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //                  IF-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    if_stage if_1 (
        .clock(clock),          	        			// system clock
        .reset(reset),         	         				// system reset
        .stall(!if_id_enable),      					// only go to next instruction when true
                                                        // makes pipeline behave as single-cycle

        .branch_mispredict(branch_mispredict),
        .corrected_branch_address(rob_br_mispredict_address),
        .committed_branches(rob_committed_branches),	// Comitted branches
        .mem2proc_data(mem2proc_data),                  // Data coming back from instruction-memory
        .mem2proc_response(mem2proc_response),
        .mem2proc_tag(mem2proc_tag),

        .proc2mem_command(fetch_proc2mem_command),    	    // command sent to memory
        .proc2mem_addr(fetch_proc2mem_addr),      	        // Address sent to memory

        .if_packet_out(if_packet_out),         	        // Output data packet from IF going to ID, see sys_defs for signal information
		.cachemen(cachemen),
		.btb_addrs(btb_addrs),
		.PCs_reg(PCs_reg),
		.btb_hits(btb_hits),
		.first_tk_addr(btb_first_tk_addr),
		.PC_enable(PC_enable),
        .id_spec_history_packet
    );



    //////////////////////////////////////////////////
    //                                              //
    //            IF/ID Pipeline Register           //
    //                                              //
    //////////////////////////////////////////////////


    // synopsys sync_set_reset "reset"
    assign if_id_enable = !(rs_structural_hazard | rob_structural_hazard | lsq_structural_hazard | data_proc2mem_command != BUS_NONE);
    always_ff @(posedge clock) begin
        if (reset || branch_mispredict) begin
            if_id_packet_out <= `SD 0;
        end else if (if_id_enable) begin
            if_id_packet_out <= `SD if_packet_out;
        end
    end
    always_comb begin
        if (if_id_enable) begin
            id_packet_in = if_id_packet_out;
            //this logic is here to invalidate instructions that are not sequentially valid
            for(int i = 1; i < `N; ++i)begin
                if(~id_packet_in[i-1].valid) begin
                    id_packet_in[i].valid = `FALSE;
                end
            end
        end else begin
            id_packet_in = 0;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //                  ID-Stage                    //
    //                                              //
    //////////////////////////////////////////////////
    id_stage id_1(
        .clock(clock),
        .reset(reset),
        .nuke(branch_mispredict),
        .cdb_in(cdb),
        .if_id_packet_in(id_packet_in),

        .rrat_entries(rrat_entries),
        .rrat_free_list(rrat_free_list),
        .free_vector_from_rrat(rrat_free_vector),
        .id_packet_out(id_packet_out),
        .no_free_prf(prf_full),
		.prf(prf_entries),
		.rat_free_list(rat_free_list),
		.rat_entries(rat_entries),
        .id_spec_history_packet
    );

    //////////////////////////////////////////////////
    //                                              //
    //            ID/EX Pipeline Register           //
    //                                              //
    //////////////////////////////////////////////////


    // synopsys sync_set_reset "reset"
    assign id_ex_stall = (rs_structural_hazard | rob_structural_hazard | lsq_structural_hazard);
    always_ff @(posedge clock) begin
        if (reset || branch_mispredict) begin
            id_ex_packet_out <= `SD 0;
        end else begin
            if (~id_ex_stall)
                id_ex_packet_out <= `SD id_packet_out;
            else begin
                for(int n_i = 0; n_i < `N; ++n_i) begin
                    for(int cdb_i = 0 ; cdb_i < `N; ++ cdb_i) begin
                        if(cdb[cdb_i].valid && cdb[cdb_i].value_valid && id_ex_packet_out[n_i].valid && (cdb[cdb_i].dest_prf == id_ex_packet_out[n_i].opa_value) && (~id_ex_packet_out[n_i].opa_ready)) begin
                            id_ex_packet_out[n_i].opa_ready <= `SD `TRUE;
                            id_ex_packet_out[n_i].opa_value <= `SD cdb[cdb_i].value;
                        end
                        if(cdb[cdb_i].valid && cdb[cdb_i].value_valid && id_ex_packet_out[n_i].valid && (cdb[cdb_i].dest_prf == id_ex_packet_out[n_i].opb_value) && (~id_ex_packet_out[n_i].opb_ready)) begin
                            id_ex_packet_out[n_i].opb_ready <= `SD `TRUE;
                            id_ex_packet_out[n_i].opb_value <= `SD cdb[cdb_i].value;
                        end
                    end
                end
            end
        end
    end

    /* Route ID_EX output to reservation stations and RoB */
    STATION [`N-1:0] id_dispatched_stations;
    always_comb begin
        for (int i = 0; i < `N; ++i) begin

            /* RS Routing */
            id_dispatched_stations[i].valid         = id_ex_packet_out[i].valid && ~id_ex_packet_out[i].halt && ~id_ex_stall 
                                                                                && ~(id_ex_packet_out[i].arch_reg_dest == 0 && id_ex_packet_out[i].func_unit == ADD);
            id_dispatched_stations[i].inst          = id_ex_packet_out[i].inst;
	        id_dispatched_stations[i].op1_ready     = id_ex_packet_out[i].opa_ready;
	        id_dispatched_stations[i].op1_value     = id_ex_packet_out[i].opa_value;
            id_dispatched_stations[i].op2_ready     = id_ex_packet_out[i].opb_ready;
	        id_dispatched_stations[i].op2_value     = id_ex_packet_out[i].opb_value;
	        id_dispatched_stations[i].dest_arf      = id_ex_packet_out[i].arch_reg_dest;
	        id_dispatched_stations[i].dest_prf      = id_ex_packet_out[i].phys_reg_dest;
	        id_dispatched_stations[i].rob_entry     = 0;
	        id_dispatched_stations[i].offset        = id_ex_packet_out[i].offset_value;
	        id_dispatched_stations[i].pc            = id_ex_packet_out[i].PC;
            id_dispatched_stations[i].func_unit_type= id_ex_packet_out[i].func_unit;
            id_dispatched_stations[i].func_op_type  = id_ex_packet_out[i].alu_func;

            /* RoB Routing */

            id_dispatched_instrs_rob[i].valid                      = id_ex_packet_out[i].valid && ~id_ex_stall;
            id_dispatched_instrs_rob[i].inst                       = id_ex_packet_out[i].inst;
            id_dispatched_instrs_rob[i].executed                   = id_ex_packet_out[i].halt || (id_ex_packet_out[i].arch_reg_dest == 0 && id_ex_packet_out[i].func_unit == ADD);
            id_dispatched_instrs_rob[i].halt                       = id_ex_packet_out[i].halt;
            id_dispatched_instrs_rob[i].dest_arf                   = id_ex_packet_out[i].arch_reg_dest;
            id_dispatched_instrs_rob[i].dest_prf                   = id_ex_packet_out[i].phys_reg_dest;
            id_dispatched_instrs_rob[i].calculated_branch_address  = 0;
            id_dispatched_instrs_rob[i].predicted_branch_address   = id_ex_packet_out[i].NPC;
            id_dispatched_instrs_rob[i].pc                         = id_ex_packet_out[i].PC;
            id_dispatched_instrs_rob[i].func_op_type               = id_ex_packet_out[i].alu_func;
            id_dispatched_instrs_rob[i].bp_indicies                = id_ex_packet_out[i].bp_indicies;

            /* LSQ Packet Routing */

            lsq_in_packet[i].valid    = id_ex_packet_out[i].valid && id_ex_packet_out[i].func_unit == MEM && ~id_ex_stall;
            lsq_in_packet[i].store    = id_ex_packet_out[i].alu_func == ALU_SB || id_ex_packet_out[i].alu_func == ALU_SH || id_ex_packet_out[i].alu_func == ALU_SW;
            lsq_in_packet[i].pc       = id_ex_packet_out[i].PC;
            lsq_in_packet[i].dest_prf = id_ex_packet_out[i].phys_reg_dest;
        end
    end


    //////////////////////////////////////////////////
    //                                              //
    //                  EX-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    reservation_station rs_1 (
        .reset(reset | branch_mispredict),                  // Input to set all stations and functional packets to invalid
        .clock(clock),
        .dispatched_stations(id_dispatched_stations),    // Instructions being sent to the reservation station
        .cdb_input(cdb),              // N possible CDB's, for instructions waiting on values
        .avail_func_units(fu_availible_units),       // One hot signal of which functional units are ready for instructions
        .next_entries(rob_next_entries_indicies),
        .n_lsq_index(n_lsq_index),
        .rs_full(rs_structural_hazard),                // Outputs if there are not at least N free stations
        .rs_to_func(rs_to_func_packet),              // Outputs the the functional units
		.stations(reservation_stations)
    );

    rob rob_1 (
        .reset(reset),                  // Input to set all stations and functional packets to invalid
        .clock(clock),
        .dispatched_entries(id_dispatched_instrs_rob),    // Instructions being sent to the reservation station
        .cdb_input(cdb),
        .n_lsq_index(n_lsq_index),
        .branch_mispredict(branch_mispredict),
        .corrected_branch_address(rob_br_mispredict_address),
        .branch_pred_packet(rob_committed_branches),
        .stores_ready(rob_stores_ready),

        .next_entries_index(rob_next_entries_indicies),
        .rob_full(rob_structural_hazard),
        .halt(wfi_halt),
        .rob_commit(rob_committed_instructions),
		.entries(rob_entries),
		.head_index(head_index),
		.tail_index(tail_index)
    );

    assign error = wfi_halt ? HALTED_ON_WFI : NO_ERROR;

    functional_unit fu(
        .reset(reset || branch_mispredict),
        .clock(clock),
        .nuke(branch_mispredict),

        .lsq_in(lsq_in_packet),
        .n_lsq_idxs(n_lsq_index),
        .next_entries(rob_next_entries_indicies),
        .stores_ready(rob_stores_ready),

        .issued_instr(rs_to_func_packet),

        .avail_func_units(fu_availible_units),
        .cdb_output(cdb),

        .mem2proc_response,        // Tag from memory about current request
	    .mem2proc_data,            // Data coming back from memory
	    .mem2proc_tag,              // Tag from memory about current reple
	    .data_proc2mem_command,   // command sent to memory
	    .data_proc2mem_addr,      // Address sent to memory
	    .data_proc2mem_data,      // Data sent to memory

        .lsq_full(lsq_structural_hazard),
		.fu_out(fu_out),
		.fu_ready(fu_ready),
		.load_queue(load_queue),
		.store_queue(store_queue)
    );

    rrat rrat_1(
        .reset(reset),
        .clock(clock),
        .rob_commited_instrs(rob_committed_instructions),

        .free_vector_for_rat(rrat_free_vector),
        .n_rrat_free_list(rrat_free_list),
        .n_rrat_entries(rrat_entries)
    );

endmodule

`endif
