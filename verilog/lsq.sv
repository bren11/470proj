module lsq (
    input clock,
    input reset,
    input nuke,

    input LSQ_IN_PACKET [`N-1:0]            lsq_in,
    input [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] next_entries,
    input STORES_READY [`N-1:0]             stores_ready,

    input FUNC_UNIT_PACKET [`NUM_MEMS-1:0]  input_instr, // what's this?
    input                  [`NUM_MEMS-1:0]  sel,

    output FUNC_OUTPUT     [`NUM_MEMS-1:0]  out,
	output logic      	   [`NUM_MEMS-1:0]  ready,

    input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply

	output BUS_COMMAND      proc2mem_command,   // command sent to memory
	output DCACHE_DMAP_ADDR proc2mem_addr,      // Address sent to memory
	output DCACHE_BLOCK     proc2mem_data,      // Data sent to memory

    output logic [`N-1:0][`LSQ_INDEX_BITS-1:0] n_lsq_idxs,

    output logic lsq_full,

	//Visual debugger outputs
	output LOAD_QUEUE_ENTRY [`LOAD_QUEUE_SIZE-1:0] load_queue,
	output STORE_QUEUE_ENTRY [`STORE_QUEUE_SIZE-1:0] store_queue
);

    /* Store Queue */
    STORE_QUEUE_ENTRY [`STORE_QUEUE_SIZE-1:0] n_store_queue;
    logic [`STORE_QUEUE_BITS-1:0] str_head, str_tail, n_str_head, n_str_tail;

    /* Load Queue */
    LOAD_QUEUE_ENTRY [`LOAD_QUEUE_SIZE-1:0] n_load_queue;

    /* Dcache */
    DCACHE_DMAP_ADDR            str_w_addr;     
    logic [`MEM_DATA_BITS-1:0]  str_w_data;
    MEM_SIZE                    str_w_size;
    logic                       str_v;
    logic                       dcache_hzd;
    logic                       dcache_structural_hzd;
    logic                       MSHR_memory_hzds;

    DCACHE_DMAP_ADDR [`LSQ_NUM_LOADS-1:0]  proc2Dcache_rd_addrs;
    logic            [`LSQ_NUM_LOADS-1:0]  proc2Dcache_rd_v;

    DCACHE_BLOCK [`LSQ_NUM_LOADS-1:0]      Dcache_rd_data;
    logic [`LSQ_NUM_LOADS-1:0]             Dcache_rd_hits;
    logic                                  Dcache_str_accepted;

    /* Memory */
    MEM_SIZE proc2mem_size;

    /* Utility */
    logic load_q_full, store_q_full;

    FUNC_UNIT_PACKET [`NUM_MEMS-1:0] cur_instr;
    FUNC_OUTPUT     [`NUM_MEMS-1:0]  n_out;

    assign ready = ~(0);

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                      Circular Buffer Next Pointer Logic                  //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////


    /* Choose Next Loads to add to functional unit */
    logic [`LOAD_QUEUE_SIZE-1:0] open_load_spaces;
    logic [`N-1:0][`LOAD_QUEUE_SIZE-1:0] open_load_gnt;
    for (genvar valid_i = 0; valid_i < `LOAD_QUEUE_SIZE; valid_i++) begin
        assign open_load_spaces[valid_i] = ~load_queue[valid_i].valid;
    end
    priority_selector #(`N, `LOAD_QUEUE_SIZE) open_sel (
        .req(open_load_spaces),
        .gnt_bus(open_load_gnt)
    );

    /* Choose loads to */
    logic [`LOAD_QUEUE_SIZE-1:0] load_out_rdy;
    logic [`NUM_MEMS-1:0][`LOAD_QUEUE_SIZE-1:0] load_out_gnt;
    for (genvar ready_i = 0; ready_i < `LOAD_QUEUE_SIZE; ready_i++) begin
        assign load_out_rdy[ready_i] = load_queue[ready_i].out_ready && load_queue[ready_i].valid;
    end
    priority_selector #(`NUM_MEMS, `LOAD_QUEUE_SIZE) ready_sel (
        .req(load_out_rdy),
        .gnt_bus(load_out_gnt)
    );

    /* Choose loads to */
    logic [`LOAD_QUEUE_SIZE-1:0] load_mem_rdy;
    logic [`NUM_MEMS-1:0][`LOAD_QUEUE_SIZE-1:0] load_mem_gnt;
    for (genvar ready_i = 0; ready_i < `LOAD_QUEUE_SIZE; ready_i++) begin
        assign load_mem_rdy[ready_i] = load_queue[ready_i].ready_for_mem && ~load_queue[ready_i].out_ready && load_queue[ready_i].valid;
    end
    priority_selector #(`LSQ_NUM_LOADS, `LOAD_QUEUE_SIZE) mem_sel (
        .req(load_mem_rdy),
        .gnt_bus(load_mem_gnt)
    );

    
    /* Structural Hazard Logic */
    assign load_q_full = ~(|open_load_gnt[`N-1]);
    assign lsq_full = load_q_full || store_q_full;
    always_comb begin
        if(str_head > str_tail || (str_head == str_tail && store_queue[str_head].valid)) begin
            store_q_full = (str_head - str_tail) < `N;
        end else begin
            store_q_full = (`STORE_QUEUE_SIZE - (str_tail - str_head)) < `N;
        end
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                        LOAD STORE QUEUE MAINTENAINCE                     //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////
    
    always_comb begin

        int index1, index2;
        
        /* Base Cases */
        n_str_tail = str_tail;
        n_str_head = str_head;
        n_store_queue = store_queue;
        n_load_queue = load_queue;

        str_w_addr  = 0;
        str_w_data  = 0;
        str_w_size  = DOUBLE;
        str_v       = `FALSE;
        n_lsq_idxs = 0;

        proc2Dcache_rd_addrs = 0;

        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                          Add Dispatched Instructions                     //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////
        for (int i = 0; i < `N; ++i) begin
            if (lsq_in[i].valid && lsq_in[i].store) begin

                /* Store Next Indices for ROB/RS */
                n_lsq_idxs[i] = n_str_tail;

                /* Add to Store Queue */
                n_store_queue[n_str_tail].valid         = `TRUE;
                n_store_queue[n_str_tail].out_ready     = `FALSE;
                n_store_queue[n_str_tail].ready_for_mem = `FALSE;
                n_store_queue[n_str_tail].has_address   = `FALSE;
                n_store_queue[n_str_tail].rob_entry     = next_entries[i];
                n_store_queue[n_str_tail].pc            = lsq_in[i].pc;

                /* Increment tail */
                n_str_tail = ((n_str_tail + 1) >= `STORE_QUEUE_SIZE) ? (0) : (n_str_tail + 1);
            end
            if (lsq_in[i].valid && !lsq_in[i].store) begin

                /* Store Next Indices for ROB/RS */
                for (int j = 0; j < `LOAD_QUEUE_SIZE; j++) begin
                    if (open_load_gnt[i][j]) begin
                        n_lsq_idxs[i] = j;

                        /* Add to Store Queue */
                        n_load_queue[j].valid           = `TRUE;
                        n_load_queue[j].out_ready       = `FALSE;
                        n_load_queue[j].ready_for_mem   = `FALSE;
                        n_load_queue[j].has_address     = `FALSE;
                        n_load_queue[j].rob_entry       = next_entries[i];
                        n_load_queue[j].dest_prf        = lsq_in[i].dest_prf;
                        n_load_queue[j].pc              = lsq_in[i].pc;

                        /* At dispatch, load address is unkown set all stores to potential conflicts */
                        for (int k = 0; k < `STORE_QUEUE_SIZE; k++) begin
                            if (n_store_queue[k].valid) begin
                                n_load_queue[j].age_addr_match[k] = `TRUE;
                            end
                        end
                    end
                end
            end
        end

        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                          Update Issued Instructions                      //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////

        for (int i = 0; i < `NUM_MEMS; i++) begin
            if (cur_instr[i].valid) begin

                /* Update issued stores */
                if (cur_instr[i].func_op_type == ALU_SB || cur_instr[i].func_op_type == ALU_SH || cur_instr[i].func_op_type == ALU_SW) begin
                    
                    /* Update Entry */
                    n_store_queue[cur_instr[i].lsq_index].target_address = cur_instr[i].offset + cur_instr[i].op1_value;
                    n_store_queue[cur_instr[i].lsq_index].has_address = `TRUE;
                    n_store_queue[cur_instr[i].lsq_index].value = cur_instr[i].op2_value;
                    
                    /* Determine Size */
                    case (cur_instr[i].func_op_type)
                        ALU_SB : n_store_queue[cur_instr[i].lsq_index].mem_size = MEM_BYTE;
                        ALU_SH : n_store_queue[cur_instr[i].lsq_index].mem_size = MEM_HALF;
                        ALU_SW : n_store_queue[cur_instr[i].lsq_index].mem_size = MEM_WORD;
                    endcase

                    if (n_store_queue[cur_instr[i].lsq_index].has_address && n_load_queue[cur_instr[i].lsq_index].target_address >= 32'h10000) begin
                        n_store_queue[cur_instr[i].lsq_index].value     = 32'hdeadbeef;
                        n_store_queue[cur_instr[i].lsq_index].out_ready = `TRUE;
                    end
                    
                    /* Update load age vectors if new store resolves as different address */
                    for (int j = 0; j < `LOAD_QUEUE_SIZE; j++) begin
                        if (load_queue[j].valid) begin
                            if (n_load_queue[j].has_address && n_store_queue[cur_instr[i].lsq_index].mem_size == n_load_queue[j].mem_size && n_load_queue[j].target_address != n_store_queue[cur_instr[i].lsq_index].target_address)
                                n_load_queue[j].age_addr_match[cur_instr[i].lsq_index] = `FALSE;
                        end
                    end

                /* Update issued loads */
                end else begin

                    /* Update Entry */
                    n_load_queue[cur_instr[i].lsq_index].target_address = cur_instr[i].offset + cur_instr[i].op1_value;
                    n_load_queue[cur_instr[i].lsq_index].has_address = `TRUE;

                    /* Determine Size */
                    case (cur_instr[i].func_op_type)
                        ALU_LB  : n_load_queue[cur_instr[i].lsq_index].mem_size = MEM_BYTE;
                        ALU_LBU : n_load_queue[cur_instr[i].lsq_index].mem_size = MEM_U_BYTE;
                        ALU_LH  : n_load_queue[cur_instr[i].lsq_index].mem_size = MEM_HALF;
                        ALU_LHU : n_load_queue[cur_instr[i].lsq_index].mem_size = MEM_U_HALF;
                        ALU_LW  : n_load_queue[cur_instr[i].lsq_index].mem_size = MEM_WORD;
                    endcase

                    /* Exception Handler */
                    if (n_load_queue[cur_instr[i].lsq_index].has_address && n_load_queue[cur_instr[i].lsq_index].target_address >= 32'h10000) begin
                        n_load_queue[cur_instr[i].lsq_index].value     = 32'hdeadbeef;
                        n_load_queue[cur_instr[i].lsq_index].out_ready = `TRUE;
                    end

                    /* Update load age vectors when load's target address is resolved */
                    for (int j = 0; j < `STORE_QUEUE_SIZE; j++) begin
                        if (store_queue[j].valid) begin
                            if (n_store_queue[j].has_address && n_store_queue[j].mem_size == n_load_queue[cur_instr[i].lsq_index].mem_size && n_store_queue[j].target_address != n_load_queue[cur_instr[i].lsq_index].target_address)
                                n_load_queue[cur_instr[i].lsq_index].age_addr_match[j] = `FALSE;
                        end
                    end
                end
            end
        end

        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                    Send ready instructions to mem                        //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////

        for (int i = 0; i < `LOAD_QUEUE_SIZE; i++) begin
            if (load_queue[i].valid && load_queue[i].has_address) begin

                /* Determine youngest instruction (index1) that is older than the load that might conflict */
                index1 = `STORE_QUEUE_SIZE;
                if (str_head < str_tail || (str_tail == str_head && ~store_queue[str_head].valid)) begin
                    for (int j = 0; j < str_tail; j++) begin
                        if(j >= str_head && load_queue[i].age_addr_match[j]) index1 = j;
                    end
                end else begin
                    for (int j = 0; j < `STORE_QUEUE_SIZE; j++) begin
                        if(j >= str_head && load_queue[i].age_addr_match[j]) index1 = j;
                    end
                    for (int j = 0; j < str_tail; j++) begin
                        if(load_queue[i].age_addr_match[j]) index1 = j;
                    end
                end

                /* If the youngest store older than load had valid store address match, then forward value */
                if (~(index1 == `STORE_QUEUE_SIZE) && store_queue[index1].has_address && store_queue[index1].mem_size == n_load_queue[i].mem_size) begin
                    n_load_queue[i].value = store_queue[index1].value;
                    n_load_queue[i].out_ready = `TRUE;
                /* If there is no conflict go to memory */
                end else if (index1 == `STORE_QUEUE_SIZE) begin
                    n_load_queue[i].ready_for_mem = `TRUE;
                end
                /* Otherwise, load will staty in the queue */
            end
        end
        
        /* Choose up to N stores to go to memory */
        for (int i = 0; i < `N; i++) begin
            if (stores_ready[i].valid && store_queue[stores_ready[i].lsq_index].has_address) begin
                n_store_queue[stores_ready[i].lsq_index].ready_for_mem = `TRUE;
            end
        end

        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                         Prepare Dcache packets                           //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////

        /* Choose first store in program order (index2) */
        index2 = `STORE_QUEUE_SIZE;
        for (int j = `N-1; j >= 0; j--) begin
            if (stores_ready[j].valid && ~store_queue[stores_ready[j].lsq_index].out_ready)
                index2 = stores_ready[j].lsq_index;
        end

        str_v = `FALSE;

        /* If at least one store has value ready, deallocate entry and pass to output */
        if (~(index2 == `STORE_QUEUE_SIZE) && store_queue[index2].ready_for_mem) begin
            
            /* Send Store to cache */
            str_w_addr  = store_queue[index2].target_address;    
            str_w_data  = store_queue[index2].value;
            str_w_size  = MEM_SIZE'(store_queue[index2].mem_size[1:0]);
            str_v       = `TRUE;

            /* Output and deallocate IFF cache can accept, otherwise wait */
            if (Dcache_str_accepted) begin
                n_store_queue[index2].out_ready = `TRUE;
            end
        end

        for (int i = 0; i < `LSQ_NUM_LOADS; i++) begin
            proc2Dcache_rd_v[i] = `FALSE;
            if (!dcache_structural_hzd) begin
                for (int j = 0; j < `LOAD_QUEUE_SIZE; j++) begin
                    if (load_mem_gnt[i][j]) begin

                        /* Send to cache */
                        proc2Dcache_rd_addrs[i] = load_queue[j].target_address;
                        proc2Dcache_rd_v[i]     = `TRUE;

                        /* If hit set to output */
                        if (Dcache_rd_hits[i]) begin
                            n_load_queue[j].out_ready   = `TRUE;
                            case(n_load_queue[j].mem_size)
                                MEM_BYTE, MEM_U_BYTE: n_load_queue[j].value = {{(`XLEN-8){`FALSE}}, Dcache_rd_data[i].byte_level[ load_queue[j].target_address.offset[2:0]   ]};
                                MEM_HALF, MEM_U_HALF: n_load_queue[j].value = {{(`XLEN-16){`FALSE}}, Dcache_rd_data[i].half_level[ load_queue[j].target_address.offset[2:1]   ]};
                                MEM_WORD: n_load_queue[j].value = Dcache_rd_data[i].word_level[ load_queue[j].target_address.offset[2]   ];
                            endcase
                        end
                    end
                end
            end
        end

        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                Finish execution of done instructions                     //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////

        n_out = out;

        //TODO: can increase amout of stores out
        for (int i = 0; i < `NUM_MEMS; i++) begin
            if (~out[i].valid) begin
                /* Choose first store in program order (index2) */
                index2 = `STORE_QUEUE_SIZE;
                for (int j = `N-1; j >= 0; j--) begin
                    if (stores_ready[j].valid && store_queue[stores_ready[j].lsq_index].out_ready)
                        index2 = stores_ready[j].lsq_index;
                end

                /* If at least one store has value ready, deallocate entry and pass to output */
                if (i == (`NUM_MEMS-1) && ~(index2 == `STORE_QUEUE_SIZE) && store_queue[index2].valid) begin

                    /* Assign Outputs */                            
                    n_out[i].valid            = `TRUE;
                    n_out[i].dest_prf         = 0;
                    n_out[i].value            = 0;
                    n_out[i].rob_entry        = store_queue[index2].rob_entry;
                    n_out[i].branch_address   = store_queue[index2].pc + 4;
                    n_out[i].value_valid      = `FALSE;
                    
                    /* Allocate Entry and move sq head pointer */
                    n_store_queue[index2] = 0;
                    n_str_head = (str_head + 1) < `STORE_QUEUE_SIZE ? str_head + 1 : 0;
                    for (int j = 0; j < `LOAD_QUEUE_SIZE; j++) begin
                        n_load_queue[j].age_addr_match[index2] = `FALSE;
                    end
                end else begin /* Pass Load to output for all but last entry */
                    for (int j = 0; j < `LOAD_QUEUE_SIZE; j++) begin
                        if (load_out_gnt[i][j]) begin

                            /* Declare this output as valid */
                            n_out[i].valid            = `TRUE;

                            /* Assign Outputs */
                            n_out[i].dest_prf         = load_queue[j].dest_prf;
                            n_out[i].rob_entry        = load_queue[j].rob_entry;
                            n_out[i].branch_address   = load_queue[j].pc + 4;
                            n_out[i].value_valid      = `TRUE;

                            /* compute value */
                            case (load_queue[j].mem_size)
                                MEM_BYTE   : n_out[i].value = {{(`XLEN-8){load_queue[j].value[7]}}, load_queue[j].value[7:0]};
                                MEM_HALF   : n_out[i].value = {{(`XLEN-16){load_queue[j].value[15]}}, load_queue[j].value[15:0]};
                                MEM_WORD   : n_out[i].value = load_queue[j].value;
                                MEM_U_BYTE : n_out[i].value = {{(`XLEN-8){`FALSE}}, load_queue[j].value[7:0]};
                                MEM_U_HALF : n_out[i].value = {{(`XLEN-16){`FALSE}}, load_queue[j].value[15:0]};
                            endcase

                            /* De-allocate entry */
                            n_load_queue[j] = 0;
                        end
                    end
                end
            end
        end
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                   DCACHE                                 //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////\

    dcache data_cache_1 (
        .clock, 
        .reset,
        .nuke,
        
        /* Updates from memory bus */
        .mem2proc_response,     
        .mem2proc_data,
        .mem2proc_tag,    
    
        /* Store Requests */
        .str_w_addr,     
        .str_w_data,
        .str_w_size,
        .str_v,
    
        /* Read Requests */
        .proc2Dcache_rd_addrs,
        .proc2Dcache_rd_v, 
    
        /* Read Outputs */
        .Dcache_rd_data,
        .Dcache_rd_hits,
        .Dcache_str_accepted,
    
        /* Bus Requests */
        .proc2mem_command,
        .proc2mem_addr,
        .proc2mem_data,
        .proc2mem_size,
        
        /* Structural Hazards */
		.structural_hazard ( dcache_structural_hzd ),         /* MSHR Full   */
		.MSHR_memory_hzd   ( MSHR_memory_hzds      )        /* Memory Full */
	); 

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || nuke) begin
			store_queue <= `SD 0;
            load_queue  <= `SD 0;
            str_head    <= `SD 0;
            str_tail    <= `SD 0;
            cur_instr   <= `SD 0;
            out         <= `SD 0;
		end else begin
            store_queue <= `SD n_store_queue;
            load_queue  <= `SD n_load_queue;
            str_head    <= `SD n_str_head;
            str_tail    <= `SD n_str_tail;
            cur_instr   <= `SD input_instr;
            for (int i = 0; i < `NUM_MEMS; i++) begin
                if (sel[i]) begin
                    out[i].valid <= `SD `FALSE;
                    out[i].dest_prf <= `SD 0;
                    out[i].rob_entry <= `SD 0;
                    out[i].branch_address <= `SD 0;
                    out[i].value <= `SD 0;
                    out[i].value_valid <= `SD 0;
                end else begin
                    out[i] <= `SD n_out[i];
                end
            end
		end
    end

endmodule
