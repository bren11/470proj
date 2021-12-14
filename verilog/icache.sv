///////////////////////////////////////////////////////////////////////////
//                                                                       //
//   Modulename :  instruction cache controller                          //
//                                                                       //
//  Description :  This cache is 128 byte cache (16x8) with an allocate  //
//                 on write policy. There is a victim cache as well with //
//                 two 8 byte blocks.                                    //
//                                                                       //
//                                                                       //
///////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module icache(
    input clock, reset,
    /* Write Requests */
    input  ICACHE_DMAP_ADDR                         Imem2proc_w_addr,     // Tag allocated
    input  [`ICACHE_DATA_BITS-1:0]                  Imem2proc_w_data,
    input                                           Imem2proc_v,
    /* Read Requests */
    input  ICACHE_DMAP_ADDR [`N-1:0]                proc2Icache_rd_addrs,
    output logic [`N-1:0][`ICACHE_DATA_BITS-1:0]    Icache_rd_data,         // value is memory[proc2Icache_addr]
    output logic            [`N-1:0]                Icache_rd_hits         // when this is high
); 
    /* Cache Parameters */
    localparam OFFSET_BITS = $clog2(`ICACHE_BLOCK_SIZE);
    localparam INDEX_BITS  = $clog2(`ICACHE_NUM_LINES);
    localparam TAG_BITS    = `XLEN - INDEX_BITS - OFFSET_BITS;

    /* Victim Cache */
    logic  [`ICACHE_NUM_VICTIM_ENTIRES-1:0][INDEX_BITS-1:0] evicted_index;
    logic  [`ICACHE_NUM_VICTIM_ENTIRES-1:0][TAG_BITS-1:0]   evicted_;

    /* Address Splicing */
    logic  [`N-1:0][TAG_BITS-1:0]   rd_tags;
    logic  [`N-1:0][INDEX_BITS-1:0] rd_indices;
    logic  [TAG_BITS-1:0]           wr_tag;
    logic  [INDEX_BITS-1:0]         wr_index;

    /* I/0 */
    logic [`N-1:0][`ICACHE_DATA_BITS-1:0] Icachemem_rd_data;
    logic [`N-1:0]                        Icachemem_rd_hits;
    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                            Address Slicing                               //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    assign wr_tag   = Imem2proc_w_addr.tag;
    assign wr_index = Imem2proc_w_addr.index;
    for (genvar i = 0; i < `N; ++i) begin: icache_addr_slicing
        assign rd_tags[i]    = proc2Icache_rd_addrs[i].tag;
        assign rd_indices[i] = proc2Icache_rd_addrs[i].index;
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                            Data Forwarding                               //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    for (genvar i = 0; i < `N; ++i) begin: icache_forwarding

        /* Create Hits */
        assign Icache_rd_hits[i] = (Imem2proc_w_addr.tag   == proc2Icache_rd_addrs[i].tag && Imem2proc_v &&
                                    Imem2proc_w_addr.index == proc2Icache_rd_addrs[i].index) ? `TRUE :
                                    Icachemem_rd_hits[i];

        /* Forward Data from write */
        assign Icache_rd_data[i] = (Imem2proc_w_addr.tag   == proc2Icache_rd_addrs[i].tag && Imem2proc_v &&
                                    Imem2proc_w_addr.index == proc2Icache_rd_addrs[i].index) ? Imem2proc_w_data :
                                    Icachemem_rd_data[i];
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                               Cache Memory                               //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    cachemem #(
        .NUM_RD_PORTS   (`N),
        .NUM_WR_PORTS   ( 1),
        .NUM_LINES      (`ICACHE_NUM_LINES),
        .BLOCK_SIZE     (`ICACHE_BLOCK_SIZE),
        .DATA_BITS      (64),
        .TAG_BITS       (TAG_BITS)
    )_cachemem (
        /* Inputs */
        .clock(clock), 
        .reset(reset),
        
        .wr_en(Imem2proc_v),
        .wr_idx(wr_index), 
        .wr_tag(wr_tag),
        .wr_data(Imem2proc_w_data), 

        .rd_idx(rd_indices), 
        .rd_tag(rd_tags),

        /* Outputs */
        .rd_data(Icachemem_rd_data),
        .rd_hit(Icachemem_rd_hits)
    );

endmodule




