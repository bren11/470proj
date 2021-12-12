/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rrat.sv                                             //
//                                                                     //
//  Description :  Retirement rat maintains the architectural mappings //
//                 to prf entries.                                     //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

module rrat (
    input  reset, clock,
    input ROB_COMMIT_PACKET [`N-1:0]                        rob_commited_instrs,

    output logic [`PRF_NUM_ENTRIES-1:0]                     free_vector_for_rat,
    output logic [`PRF_NUM_ENTRIES-1:0]                     n_rrat_free_list,
    output logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0]   n_rrat_entries 
);

    /* Next State */
    logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rrat_entries;
    logic [`RAT_SIZE-1:0]                          rrat_valid, n_rrat_valid;
    logic [`PRF_NUM_ENTRIES-1:0] rrat_free_list;

    /* Free and allocate entries based on rob commits. Update free lists */
    always_comb begin
        
        free_vector_for_rat = 0;
        n_rrat_free_list = rrat_free_list;
        n_rrat_entries = rrat_entries;
        n_rrat_valid = rrat_valid;

        for (int inst_i = 0; inst_i < `N; ++inst_i) begin
            if (rob_commited_instrs[inst_i].valid && rob_commited_instrs[inst_i].dest_arf != 0) begin
                /* Tell RAT to free overwritten entry*/
                if (n_rrat_valid[rob_commited_instrs[inst_i].dest_arf]) begin //
                    free_vector_for_rat[ n_rrat_entries[ rob_commited_instrs[inst_i].dest_arf ] ] = `TRUE;
                end

                /* Free and allocate entries in free list */
                if(n_rrat_valid[rob_commited_instrs[inst_i].dest_arf]) begin
                    n_rrat_free_list[ n_rrat_entries[ rob_commited_instrs[inst_i].dest_arf ]] = `TRUE;
                end
                n_rrat_free_list[ rob_commited_instrs[inst_i].dest_prf ] = `FALSE;

                /* Validate arch reg on first and every write after */
                n_rrat_valid[rob_commited_instrs[inst_i].dest_arf] = `TRUE;

                /* Update mapping based on rob commit */
                n_rrat_entries[rob_commited_instrs[inst_i].dest_arf] = rob_commited_instrs[inst_i].dest_prf;
                
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            rrat_entries   <= `SD 0;
            rrat_free_list <= `SD ~(0); //changed to one, since all entries should be free at start
            rrat_valid     <= `SD 0;
        end else begin
            rrat_entries   <= `SD n_rrat_entries;
            rrat_free_list <= `SD n_rrat_free_list;
            rrat_valid     <= `SD n_rrat_valid;
        end
    end

endmodule