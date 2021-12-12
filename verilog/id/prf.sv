/////////// TODO: ASK BREHOB ABOUT R0 ////////////

module prf(
    input                       	                        clock,
    input                   	                            reset,

    input           	[`N-1:0][`PRF_NUM_INDEX_BITS-1:0]   phys_reg1,
    input           	[`N-1:0][`PRF_NUM_INDEX_BITS-1:0]   phys_reg2,
    input CDB       	[`N-1:0]                            cdb_in,

    input           	[`PRF_NUM_ENTRIES-1:0]              to_free_vector,  //entries to free signal from RAT


    output logic    	[`N-1:0][`XLEN-1:0]                 reg1_val,     // value corresponding to the inputted phys_reg1 index
    output logic    	[`N-1:0][`XLEN-1:0]                 reg2_val,      // value corresponding to the inputted phys_reg2 index
    output logic    	[`N-1:0]                            reg1_ready,
    output logic    	[`N-1:0]                            reg2_ready,
	output PRF_ENTRY 	[`PRF_NUM_ENTRIES-1:0] 				prf

);

    /*
    we need to look at if for loops are resolving write conflicts in a way that is fast
    */

    // struct for prf values and next prf values
    PRF_ENTRY [`PRF_NUM_ENTRIES-1:0] n_prf;

    // index into the prf and check the cdb for ships passing in the night
    for(genvar n_i = 0; n_i < `N; ++n_i) begin

        always_comb begin

            if(prf[phys_reg1[n_i]].ready) begin
                reg1_val[n_i] = prf[phys_reg1[n_i]].value;
                reg1_ready[n_i] = `TRUE;
            end else begin
                reg1_val[n_i] = phys_reg1[n_i];
                reg1_ready[n_i] = `FALSE;
            end

            if(prf[phys_reg2[n_i]].ready) begin
                reg2_val[n_i] = prf[phys_reg2[n_i]].value;
                reg2_ready[n_i] = `TRUE;
            end else begin
                reg2_val[n_i] = phys_reg2[n_i];
                reg2_ready[n_i] = `FALSE;

            end


                /*ships passing in the night (feel free to remove)
                        )_)  )_)  )_)
                        )___))___))___)\
                    )____)____)_____)\\
                    _____|____|____|____\\\__
            ---------\                   /---------
            ^^^^^ ^^^^^^^^^^^^^^^^^^^^^
                ^^^^      ^^^^     ^^^    ^^
                    ^^^^      ^^^
                    */
            for(int cdb_i = 0; cdb_i < `N; ++cdb_i) begin
                if(cdb_in[cdb_i].value_valid && cdb_in[cdb_i].valid && (cdb_in[cdb_i].dest_prf == phys_reg1[n_i])) begin
                    reg1_val[n_i] = cdb_in[cdb_i].value;
                    reg1_ready[n_i] = `TRUE;
                end
                if(cdb_in[cdb_i].value_valid && cdb_in[cdb_i].valid && (cdb_in[cdb_i].dest_prf == phys_reg2[n_i])) begin
                    reg2_val[n_i] = cdb_in[cdb_i].value;
                    reg2_ready[n_i] = `TRUE;
                end
            end
        end
    end


    // update the prf from the cdb and free any values the RAT tells us to free
    always_comb begin
        n_prf = prf;

        for(int cdb_i = 0; cdb_i < `N; ++cdb_i) begin
            if(cdb_in[cdb_i].valid && cdb_in[cdb_i].value_valid) begin
                n_prf[cdb_in[cdb_i].dest_prf].ready = `TRUE;
                n_prf[cdb_in[cdb_i].dest_prf].value = cdb_in[cdb_i].value;
            end
        end

        for(int prf_i = 0; prf_i < `PRF_NUM_ENTRIES; ++prf_i) begin
            if(to_free_vector[prf_i]) begin
                n_prf[prf_i].ready = `FALSE;
            end
        end
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset)
            prf <= `SD 0;
		else begin
            prf <= `SD n_prf;
        end
	end

endmodule
