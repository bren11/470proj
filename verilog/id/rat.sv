module rat (
    input clock,
    input reset,
    input nuke,

    //look-up
    input [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg1,

    input [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg2,

    input [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg_dest,
    input [`N-1:0]                      arch_reg_dest_valid,

    input [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rrat_entries,
    input [`PRF_NUM_ENTRIES-1:0] rrat_free_list,                //current free list of the rrat
    input [`PRF_NUM_ENTRIES-1:0] free_vector_from_rrat,         //list that goes to RAT and PRF to tell which entries
                                                                //to free based on new rrat state

    output logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg1,
    output logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg2,
    output logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg_dest,

    output logic no_free_prf, //output for if the prf is full

    // Visual testbench outputs
    output logic [`PRF_NUM_ENTRIES-1:0] free_list_o,
	output logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rat_entries
);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  THIS MODULE DOES NOT INVALID OUTPUT IF THERE IS A STALL, IF WE WOULD LIKE IT TO WE NEED TO ADD THAT //
    //////////////////////////////////////////////////////////////////////////////////////////////////////////


    logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] n_rat_entries;

    logic [`PRF_NUM_ENTRIES-1:0] free_list;
    logic [`PRF_NUM_ENTRIES-1:0] n_free_list;
    assign free_list_o = free_list;

    // deals with the case that an instruction needs the destreg prf of the instruction before him
    // but on the same cycle
    RAT_FORWARD_PACKET [`N-1:0] forward_packet;

    logic [`N-1:0][`PRF_NUM_ENTRIES-1:0] gnt_bus;

    // selector to determine which to take for each instruction
    // how do we generate N priority selectors (an array?)


    // choose what the destreg of each instruction will be renamed to
    my_priority_selector #(`N, `PRF_NUM_ENTRIES) prf_free_ps(
        .clock,
        .reset,.req(free_list), .gnt_bus(gnt_bus)); //what stations will get instructions

    assign no_free_prf = !free_list;

    for(genvar n_i = 0; n_i < `N; ++n_i) begin
        always_comb begin

            // the base case is to just use the value in the table
            phys_reg1[n_i] = rat_entries[arch_reg1[n_i]];
            phys_reg2[n_i] = rat_entries[arch_reg2[n_i]];

            // if we can find the entry being modified by a orevious instruction then use the value placed by that instruction instead
            for(int n_prev_i = 0; n_prev_i < n_i; ++n_prev_i) begin
                // will it take advantage of the short circuited and and only check valid to know if default case is used?
                if(forward_packet[n_prev_i].valid && forward_packet[n_prev_i].changed_arch_reg == arch_reg1[n_i]) begin
                    phys_reg1[n_i] = forward_packet[n_prev_i].arch_reg_new_prf;
                end
                if(forward_packet[n_prev_i].valid && forward_packet[n_prev_i].changed_arch_reg == arch_reg2[n_i]) begin
                    phys_reg2[n_i] = forward_packet[n_prev_i].arch_reg_new_prf;
                end
            end

            // update the references for the forward packet

            forward_packet[n_i].valid = `FALSE;
            forward_packet[n_i].changed_arch_reg = 0;
            if(n_i < `N-1) begin
                forward_packet[n_i].valid = arch_reg_dest_valid[n_i] && (arch_reg_dest[n_i] != 0);
                forward_packet[n_i].changed_arch_reg = arch_reg_dest[n_i];
            end


                // we need to decide the new dest_prf for each instruction and pass
                // that to the next instructins in a daisy chain so they can try the
                // previous instructions first before going to the table
                // is there a faster way to do this bc this seems slow
        end
    end

    always_comb begin
        n_rat_entries = rat_entries;
        n_free_list = free_list;

        //default so it doesn't produce a latch
        phys_reg_dest = 0;

        //fix the rat for the new incoming dest reg
        for(int n_i = 0; n_i < `N; ++n_i) begin
            forward_packet[n_i].arch_reg_new_prf = 0;
            for(int gnt_i = 0; gnt_i < `PRF_NUM_ENTRIES; ++gnt_i) begin
                if( arch_reg_dest_valid[n_i] && gnt_bus[n_i][gnt_i] && arch_reg_dest[n_i] != 0) begin
                    n_free_list[gnt_i] = 1'b0;
                    
                    n_rat_entries[arch_reg_dest[n_i]] = gnt_i;
                    phys_reg_dest[n_i] = gnt_i;

                    forward_packet[n_i].arch_reg_new_prf = gnt_i;
                end
            end
        end


        //if somethings freed in the rrat then free it here
        //free_vector2prf = 0;

        for(int prf_i = 0; prf_i < `PRF_NUM_ENTRIES; ++prf_i) begin
            if(free_vector_from_rrat[prf_i]) begin
                n_free_list[prf_i] = 1'b1;
            end
        end


    end


    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            rat_entries <= `SD 0;
            free_list <= `SD ~(0);
        end else if(nuke) begin
            rat_entries <= `SD rrat_entries;
            free_list <= `SD rrat_free_list;
        end else if(~no_free_prf) begin
            rat_entries <= `SD n_rat_entries;
            free_list <= `SD n_free_list;
        end else begin
            free_list <= `SD n_free_list;
        end
    end

endmodule
