
///////////////////////////////////////////////////////////////////////////
//                                                                       //
//   Modulename :  instruction buffer                                    //
//                                                                       //
//  Description :   The instruction buffer is a circular buffer that     //
//                  contains instructions waiting to either be decoded   //
//                  or retrieved from memory.                            //
//                                                                       //
//                                                                       //
///////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps


module instruction_buffer (
    input                                       clock,
    input                                       reset,
    input                                       nuke,

    input        					[63:0] 		mem2proc_data,          // Data coming back from instruction-memory
	input							[3:0]   	mem2proc_response,
	input							[3:0]   	mem2proc_tag,

    input[`N-1:0] [`XLEN-1:0]	                input_PCs,
    input[`N-1:0] [`XLEN-1:0]	                input_NPCs,
    input[`N-1:0] [`BRANCH_PREDICTION_BITS-1:0] input_bp_indicies,
    input[`N-1:0]                               input_taken,

    input                                       stall,                  // Stall commands for memory bus arbitration purposes
    input                                       enable,

	output BUS_COMMAND                    		proc2mem_command,    	// command sent to memory
	output logic 					[`XLEN-1:0] proc2mem_addr,      	// Address sent to memory

    output logic                                ib_structural_hazard,
    output logic [$clog2(`INSTR_BUFFER_LEN)-1:0]ib_size,
    output logic [`N-1:0]                       icache_hits,
    
    output IF_BUFFER_STATION        [`N-1:0]    next_instrs,
    output logic                                all_ready
);
    /* Buffer */
    IF_BUFFER_STATION [`INSTR_BUFFER_LEN-1:0] 		    instr_buffer, n_instr_buffer;
	logic 			  [$clog2(`INSTR_BUFFER_LEN)-1:0]   ib_head, n_ib_head;
	logic 			  [$clog2(`INSTR_BUFFER_LEN)-1:0]   ib_tail, n_ib_tail;
    logic                                               ib_size_hazard;
    logic     [`N-1:0][$clog2(`INSTR_BUFFER_LEN)-1:0]   insert_indices;

    
    /* I-Cache */
    logic [`N-1:0][63:0] icache_data;
    logic [`XLEN-1:0]    updated_mem_address;
    logic [63:0]         updated_mem_data;
    logic                updated_mem_valid;

    /* Utility */
    logic [`INSTR_BUFFER_LEN-1:0][$clog2(`INSTR_BUFFER_LEN)-1:0] index;
    logic [`INSTR_BUFFER_LEN-1:0]                                valid;
    logic [`N-1:0] ready_for_decode;
    

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             I-Cache Controller                           //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    /* Cache controller */
    icache ic_1 (
        /* Inputs */
        .clock(clock),
        .reset(reset),

        .Imem2proc_w_addr(updated_mem_address),
        .Imem2proc_w_data(updated_mem_data),
        .Imem2proc_v(updated_mem_valid),

        .proc2Icache_rd_addrs(input_PCs),

        /* Outputs */
        .Icache_rd_data(icache_data), 
        .Icache_rd_hits(icache_hits)
     );
 
    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             Instruction Queue                            //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    /* Structural Hazards */
    always_comb begin
        if(ib_head > ib_tail) begin
            ib_size_hazard = (ib_head - ib_tail) <= `N;
            ib_size = `INSTR_BUFFER_LEN - (ib_head - ib_tail);
        end else begin
            ib_size_hazard = (`INSTR_BUFFER_LEN - (ib_tail - ib_head)) <= `N;
            ib_size =  (ib_tail - ib_head);
        end
		ib_structural_hazard = ib_size_hazard;
    end

    /* Calculate Next Indicies */
    for (genvar n_i = 0; n_i < `N; n_i++) begin: get_next_indces
        assign insert_indices[n_i] = ((ib_tail + n_i) >= `INSTR_BUFFER_LEN) ? 
                                          (ib_tail + n_i) - `INSTR_BUFFER_LEN :
                                          (ib_tail + n_i);
    end

    /* Calculate Iterator order */
    for (genvar i = 0; i < `INSTR_BUFFER_LEN; ++i) begin: circ_buffer_gen
        /* Circular Buffer Index Calc */
        assign index[i]   = (ib_head + i >= `INSTR_BUFFER_LEN) ? 
                             ib_head + i - `INSTR_BUFFER_LEN :
                             ib_head + i;

        /* Check within range */
        assign valid[i] = (ib_head == ib_tail) ? `FALSE :
                          (ib_head > ib_tail) ?
                                    (i >= ib_head) || (i < ib_tail):
                                    (i >= ib_head) && (i < ib_tail);
    end

    /* Calculate next tail pointers */
    always_comb begin
        n_ib_tail = ib_tail;

        /* Nothing will be added if there is a hazard */
        if (!ib_structural_hazard && enable) begin
            n_ib_tail = ((ib_tail + `N) >= `INSTR_BUFFER_LEN) ? 
                                            ((ib_tail + `N) - `INSTR_BUFFER_LEN) :  
                                            (ib_tail + `N);
        end
    end

    /* Update logic */
    always_comb begin
        n_instr_buffer = instr_buffer;
        proc2mem_command = BUS_NONE;
        proc2mem_addr = 0;
        updated_mem_valid = `FALSE;
        updated_mem_data = 0;
        updated_mem_address = 0;

        /* Add Instructions to Buffer */
        if (!ib_structural_hazard && enable) begin
            for (int i = 0; i < `N; ++i) begin
                n_instr_buffer[insert_indices[i]].PC = input_PCs[i];
                n_instr_buffer[insert_indices[i]].NPC = input_NPCs[i];
                n_instr_buffer[insert_indices[i]].bp_indicies = input_bp_indicies[i];
                n_instr_buffer[insert_indices[i]].taken = input_taken[i];

                if (icache_hits[i]) begin
                    n_instr_buffer[insert_indices[i]].ready     = `TRUE;
                    n_instr_buffer[insert_indices[i]].requested = `TRUE;
                    n_instr_buffer[insert_indices[i]].inst      = (input_PCs[i][2]) ? icache_data[i][63:`XLEN] : icache_data[i][`XLEN-1:0];
                end else begin
                    n_instr_buffer[insert_indices[i]].ready = `FALSE;
                    n_instr_buffer[insert_indices[i]].requested = `FALSE;
                end
            end
        end

        for (int i = 0; i < `INSTR_BUFFER_LEN; ++i) begin

            /* Watch memory bus for incoming tag matches */
            if (valid[index[i]] &&
                instr_buffer[index[i]].mem_tag == mem2proc_tag && /* Tag matches */ 
                mem2proc_tag != 0 &&                              /* Valid tag */
                instr_buffer[index[i]].requested &&
                !instr_buffer[index[i]].ready) begin           /* Valid request -> tag match is valid */
                
                /* Update Cache */
                updated_mem_valid   = `TRUE;
                updated_mem_data    = mem2proc_data;
                updated_mem_address = { instr_buffer[index[i]].PC[`XLEN-1:3], 3'b0};
            
                /* Update Instruction Buffer */
                n_instr_buffer[index[i]].ready = `TRUE; 
                n_instr_buffer[index[i]].inst  = (instr_buffer[index[i]].PC[2]) ? mem2proc_data[63:`XLEN] : mem2proc_data[`XLEN-1:0];
           
            end else if (valid[index[i]] && updated_mem_valid &&
                { instr_buffer[index[i]].PC[`XLEN-1:3], 3'b0} == updated_mem_address) begin 
                
                n_instr_buffer[index[i]].ready = `TRUE; 
                n_instr_buffer[index[i]].inst  = (instr_buffer[index[i]].PC[2]) ? updated_mem_data[63:`XLEN] : updated_mem_data[`XLEN-1:0];
            end
        end

        /* Generate New Requests */
        for (int i = 0; i < `INSTR_BUFFER_LEN; ++i) begin

            if (valid[index[i]] && !stall && 
                !instr_buffer[index[i]].requested &&
                !instr_buffer[index[i]].ready) begin

                    /* Send memory request */
                    proc2mem_command = BUS_LOAD;
                    proc2mem_addr = { instr_buffer[index[i]].PC[`XLEN-1:3] , 3'h0 };
                    
                    /* Update Station */
                    n_instr_buffer[index[i]].mem_tag   = mem2proc_response;
                    n_instr_buffer[index[i]].requested = (mem2proc_response != 0);  /* Must be accepted */
                    break;
            end
        end

        /* Update others with same request */
        for (int i = 0; i < `INSTR_BUFFER_LEN; ++i) begin
            if (valid[index[i]] && !stall && 
                !instr_buffer[index[i]].requested &&
                !instr_buffer[index[i]].ready &&
                proc2mem_command == BUS_LOAD &&
                { instr_buffer[index[i]].PC[`XLEN-1:3] , 3'b0 } ==  proc2mem_addr &&
                mem2proc_response != 0) begin
                    
                    /* Update Station mem tag as well*/
                    n_instr_buffer[index[i]].mem_tag   = mem2proc_response;
                    n_instr_buffer[index[i]].requested = `TRUE;
            end
        end
    end

    /* Output Logic */
    assign all_ready = &ready_for_decode && (ib_head != ib_tail);
    for (genvar i = 0; i < `N; ++i) begin : ibuf_output
        assign next_instrs[i] = instr_buffer[index[i]];
        assign ready_for_decode[i] = instr_buffer[index[i]].ready;
    end

    /* Dispatch everthing that is contiguously valid */
    always_comb begin
        n_ib_head = ib_head;
        if (!stall) begin
            if (all_ready) begin
                n_ib_head = ((ib_head + `N) >= `INSTR_BUFFER_LEN) ? 
                                        (ib_head + `N) - `INSTR_BUFFER_LEN :
                                        (ib_head + `N);
            end else begin
                for (int i = 0; i < `N; ++i) begin
                    if (!ready_for_decode[i]) begin
                        n_ib_head = ((ib_head + i) >= `INSTR_BUFFER_LEN) ? 
                                        (ib_head + i) - `INSTR_BUFFER_LEN :
                                        (ib_head + i);
                        break;
                    end
                end
            end
        end
    end

    /* Send up to N instructions to ID */
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | nuke) begin
            instr_buffer <= `SD 0;
            ib_head      <= `SD 0;
            ib_tail      <= `SD 0;
        end else begin
            instr_buffer <= `SD n_instr_buffer;
            ib_head      <= `SD n_ib_head;
            ib_tail      <= `SD n_ib_tail;
        end
    end

endmodule