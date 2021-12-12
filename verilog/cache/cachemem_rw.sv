// cachemem32x64

`timescale 1ns/100ps

module cachemem_rw #(
  /* Parameterized Direct Mapped Cache */
    parameter NUM_RD_PORTS      = (`N+1),
    parameter NUM_WR_PORTS      =  2,
    parameter NUM_LINES         = 32,
    parameter TAG_BITS          = 24
)(
    /* Inputs */
    input clock, reset,

    input [NUM_WR_PORTS-1:0]                  wr_en,
    input DCACHE_DMAP_ADDR [NUM_WR_PORTS-1:0] wr_addr,
    input DCACHE_BLOCK [NUM_WR_PORTS-1:0]     wr_data,
    input MEM_SIZE [NUM_WR_PORTS-1:0]         wr_size,

    input [NUM_RD_PORTS-1:0] [$clog2(NUM_LINES)-1:0] rd_idx,
    input [NUM_RD_PORTS-1:0] [TAG_BITS-1:0]  rd_tag,

    /* Outputs */
    output DCACHE_BLOCK [NUM_RD_PORTS-1:0]  rd_data,
    output logic [NUM_RD_PORTS-1:0]         rd_hit
);

    /* Cache memory */
    DCACHE_BLOCK [NUM_LINES-1:0]          data;
    logic [NUM_LINES-1:0] [TAG_BITS-1:0]  tags; 
    logic [NUM_LINES-1:0]                 valids;

    /* N-Way Read - No problem */
    for (genvar i = 0; i < NUM_RD_PORTS; ++i) begin : nway_read
        assign rd_data[i] = data[rd_idx[i]];                                      
        assign rd_hit[i]  = valids[rd_idx[i]] && (tags[rd_idx[i]] == rd_tag[i]);  
    end

    /* Update Data Storage */
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            tags   <= `SD 0;
            data   <= `SD 0;
            valids <= `SD 0;
        end else begin
            for (int i = 0; i < NUM_WR_PORTS; ++i) begin
                if (wr_en[i]) begin
                    /* Make entry valid */
                    valids[wr_addr[i].index] <= `SD `TRUE;

                    /* Update Tag */
                    tags[wr_addr[i].index]   <= `SD wr_addr[i].tag;
                    
                    /* Updated Modified Data */
                    case (wr_size[i])
                        BYTE    : data[wr_addr[i].index].byte_level[ wr_addr[i].offset[2:0] ] <=` SD wr_data[i].byte_level[0];   
                        HALF    : data[wr_addr[i].index].half_level[ wr_addr[i].offset[2:1] ] <=` SD wr_data[i].half_level[0];
                        WORD    : data[wr_addr[i].index].word_level[ wr_addr[i].offset[2]   ] <=` SD wr_data[i].word_level[0];
                        DOUBLE  : data[wr_addr[i].index]                                      <=` SD wr_data[i];
                    endcase
                end
            end
        end
    end
endmodule
