///////////////////////////////////////////////////////////////////////////
//                                                                       //
//   Modulename :  btb                                                   //
//                                                                       //
//  Description :   Branch target bufffer for branch address prediction  //
//                  Can take in as many as N requests and N updates in   //
//                  one clock cycle. In this case the BTB is fully       //
//                  tagged                                               //
//                                                                       //
//                                                                       //
///////////////////////////////////////////////////////////////////////////

//`define IGNORE_BTB

`timescale 1ns/100ps

module btb (
    input                                               reset,
    input                                               clock,
    input           [`N-1:0] [`XLEN-1:0]                PCs_in,
    input   BRANCH_PREDICTION_PACKET [`N-1:0]           committed_branches,

    output  logic   [`N-1:0]                            hits,
    output  logic   [`N-1:0] [`XLEN-1:0]                predicted_addresses,

	// Visual debugger outputs
	output BTB_LINE [`BTB_NUM_LINES-1:0]  				cachemen
);

    /* Cache structure */
    BTB_LINE [`BTB_NUM_LINES-1:0]  n_cachemen;

`ifdef IGNORE_BTB
    /* Act like nothing is in the BTB ever */
    assign hits = 0;
    assign predicted_addresses = 0;
`else

    /* Generate Next cache values */
    always_comb begin
        n_cachemen = cachemen;
        for (int i = 0; i < `N; ++i) begin /* Up to N branches committing */
            if (committed_branches[i].valid && committed_branches[i].taken) begin
                n_cachemen[ committed_branches[i].pc[`BTB_IDX_BITS+1:2] ].tag   = committed_branches[i].pc[`XLEN-1:`BTB_IDX_BITS+2];
                n_cachemen[ committed_branches[i].pc[`BTB_IDX_BITS+1:2] ].addr  = committed_branches[i].branch_address;
                n_cachemen[ committed_branches[i].pc[`BTB_IDX_BITS+1:2] ].valid = `TRUE;
            end
        end
    end

    /* Read with forwarded values */
    for (genvar i = 0; i < `N; ++i) begin : forwarded_gen
        assign predicted_addresses[i] = n_cachemen[ PCs_in[i][`BTB_IDX_BITS+1:2] ].addr; /* Index using PC regs */
        assign hits[i] = n_cachemen[PCs_in[i][`BTB_IDX_BITS+1:2]].valid &&
                        (n_cachemen[PCs_in[i][`BTB_IDX_BITS+1:2]].tag == PCs_in[i][`XLEN-1:`BTB_IDX_BITS+2]);
    end

    /* Update Data Storage */
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            cachemen <= `SD 0;
        end else begin
            cachemen <= `SD n_cachemen;
        end
    end

`endif

endmodule
