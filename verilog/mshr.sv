///////////////////////////////////////////////////////////////////////////
//                                                                       //
//   Modulename : Miss Statur Handler Register                           //
//                                                                       //
//  Description :                                                        //
//                                                                       //
//                                                                       //
///////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module MSHR (
    input clock, reset,
    /* Inputs Cache accesses from cache controller */
    input DCACHE_DMAP_ADDR [`DCACHE_RD_PORTS-1:0] cache_access_addrs,
    input                  [`DCACHE_RD_PORTS-1:0] cache_access_misses,
    input                  [`DCACHE_RD_PORTS-1:0] cache_access_v,

    /* Memory Bus */
    input [3:0]                             mem2proc_response,
    input [`MEM_DATA_BITS-1:0]              mem2proc_data,
    input [3:0]                             mem2proc_tag,

    input                                   mem_busy,       // If store wants to take priority

    /* Update Cache from memory response */
    output DCACHE_DMAP_ADDR           recieved_wr_addr,
    output DCACHE_BLOCK               recieved_wr_data,
    output logic                      recieved_wr_v,

    /* Memory Output Bus */
    output BUS_COMMAND                proc2mem_command,      // command sent to memory
	output logic [`XLEN-1:0]          proc2mem_addr,         // Address sent to memory

    /* Hazards */
    output logic                      structural_hzd,        // Table Full 
    output logic                      memory_hzd             // Mem request not taken
);

    /* MSHR */
    DCACHE_MSHR_ENTRY [`MSHR_NUM_ENTRIES-1:0] mshr, n_mshr;
    BUS_COMMAND mshr_mem_command;
    logic [`XLEN-1:0] mshr_mem_addr;

    /* Utility */
    logic [`DCACHE_RD_PORTS-1:0] cache_access_repeat;
    logic [`DCACHE_RD_PORTS-1:0] cache_access_repeat_mshr;
    logic [`DCACHE_RD_PORTS-1:0] cache_access_repeat_access;

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                         Choose Next Free Entries                         //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    /* Select Next Free entries */
    logic [`MSHR_NUM_ENTRIES-1:0] mshr_free;
    logic [`DCACHE_RD_PORTS-1:0][`MSHR_NUM_ENTRIES-1:0] mshr_free_gnt;
    for (genvar i = 0; i < `MSHR_NUM_ENTRIES; i++) begin : mshr_free_gen
        assign mshr_free[i] = !mshr[i].valid;
    end
    my_priority_selector #(
        .REQS  ( `DCACHE_RD_PORTS  ), 
        .WIDTH ( `MSHR_NUM_ENTRIES )
    ) free_sel (
        .clock,
        .reset,
        .req(mshr_free),
        .gnt_bus(mshr_free_gnt)
    );
    
    always_comb begin
        /* Check if access already in the table */
        cache_access_repeat_mshr = 0;
        for (int i = 0; i < `DCACHE_RD_PORTS; ++i) begin
            /* Check against existing entries */
            for (int j = 0; j < `MSHR_NUM_ENTRIES; ++j) begin
                if (mshr[j].tag == cache_access_addrs[i].tag  && 
                    mshr[j].index == cache_access_addrs[i].index &&
                    mshr[j].valid) begin

                    cache_access_repeat_mshr[i] = cache_access_v[i];
                    break;
                end
            end
        end
        /* Check against current accesses */
        cache_access_repeat_access = 0;
        for (int i = 0; i < `DCACHE_RD_PORTS; ++i) begin
            for (int j = 0; j < i; ++j) begin
                if (cache_access_addrs[i].tag == cache_access_addrs[j].tag  &&
                    cache_access_addrs[i].index == cache_access_addrs[j].index && 
                    cache_access_v[j] && cache_access_v[i]) begin

                    cache_access_repeat_access[i] = cache_access_v[i];
                    break;
                end
            end
        end

        cache_access_repeat = cache_access_repeat_access | cache_access_repeat_mshr;
    end

    /* Generate Structural Hazard */
    assign structural_hzd = ~(|mshr_free_gnt[`DCACHE_RD_PORTS-1]);

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                              Table Maintenance                           //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////
    always_comb begin
        n_mshr = mshr;
        mshr_mem_command = BUS_NONE;
        mshr_mem_addr    = 0;
        memory_hzd       = `FALSE;
        recieved_wr_addr = 0;
        recieved_wr_data = 0;
        recieved_wr_v    = `FALSE;
        
        /* Update Table based on incoming memory response */
        for (int i = 0; i < `MSHR_NUM_ENTRIES; ++i) begin
            if (!structural_hzd && mshr[i].valid && mshr[i].requested && mem2proc_tag != 0 &&
                mshr[i].mem_tag == mem2proc_tag) begin

                /* Free entry in Mem table */
                n_mshr[i].valid     = `FALSE;

                /* Output to Dcache controller */
                recieved_wr_addr = { n_mshr[i].tag, n_mshr[i].index, {$clog2(`DCACHE_BLOCK_SIZE){1'b0}} };
                recieved_wr_data = mem2proc_data;
                recieved_wr_v    = `TRUE;
            end
        end

        /* Add new cache misses to table */
        for (int i = 0; i < `DCACHE_RD_PORTS; ++i) begin
            if (cache_access_v[i] && cache_access_misses[i] && !cache_access_repeat[i]) begin
                for (int j = 0; j < `MSHR_NUM_ENTRIES; ++j) begin
                    if (mshr_free_gnt[i][j]) begin
                        n_mshr[j].tag       = cache_access_addrs[i].tag;
                        n_mshr[j].index     = cache_access_addrs[i].index;
                        n_mshr[j].mem_tag   = 0;
                        n_mshr[j].requested = `FALSE;
                        n_mshr[j].valid     = `TRUE;
                    end
                end
            end
        end

        /* Generate next memory request */
        for (int i = 0; i < `MSHR_NUM_ENTRIES; ++i) begin
            if (!mem_busy && mshr[i].valid && !mshr[i].requested) begin
                
                /* Generate Request */
                mshr_mem_command = BUS_LOAD;
                mshr_mem_addr    = { mshr[i].tag, mshr[i].index, {$clog2(`DCACHE_BLOCK_SIZE){1'b0}} };
                
                /* Update Table */
                n_mshr[i].mem_tag   =  mem2proc_response;
                n_mshr[i].requested = (mem2proc_response != 3'b000); /* Must be accepted */
                memory_hzd          = (mem2proc_response == 3'b000); 

                break;
            end
        end

    end
    
    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                Output Logic                              //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    assign proc2mem_command = mshr_mem_command;
	assign proc2mem_addr    = mshr_mem_addr; 

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
            mshr <= `SD 0;
		end else begin
            mshr <= `SD n_mshr;
		end
    end

endmodule