// cachemem32x64

`timescale 1ns/100ps

module cachemem #(
  /* Parameterized Direct Mapped Cache */
  parameter NUM_RD_PORTS      = `N,
  parameter NUM_WR_PORTS      =  1,
  parameter NUM_LINES         = 16,
  parameter BLOCK_SIZE        =  8,
  parameter DATA_BITS         = 64,
  parameter TAG_BITS          = 25
)(
  /* Inputs */
  input clock, reset,
  input [NUM_WR_PORTS-1:0] wr_en,
  input [NUM_WR_PORTS-1:0] [$clog2(NUM_LINES)-1:0] wr_idx,
  input [NUM_RD_PORTS-1:0] [$clog2(NUM_LINES)-1:0] rd_idx,
  input [NUM_WR_PORTS-1:0] [TAG_BITS-1:0]  wr_tag,
  input [NUM_RD_PORTS-1:0] [TAG_BITS-1:0]  rd_tag,
  input [NUM_WR_PORTS-1:0] [DATA_BITS-1:0] wr_data,

  /* Outputs */
  output logic [NUM_RD_PORTS-1:0] [63:0] rd_data,
  output logic [NUM_RD_PORTS-1:0] rd_hit
);

  /* Cache memory */
  logic [NUM_LINES-1:0] [DATA_BITS-1:0] data;
  logic [NUM_LINES-1:0] [TAG_BITS-1:0]  tags; 
  logic [NUM_LINES-1:0]                 valids;

  /* N-Way Read - No problem */
  for (genvar i = 0; i < NUM_RD_PORTS; ++i) begin : nway_read
    assign rd_data[i]   = data[rd_idx[i]];                                      
    assign rd_hit[i]    = valids[rd_idx[i]] && (tags[rd_idx[i]] == rd_tag[i]);  
  end

  /* Update valid on write */
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if(reset) begin
      valids <= `SD 0;
    end else begin 
      for (int i = 0; i < NUM_WR_PORTS; ++i) begin
        if (wr_en[i])
          valids[wr_idx[i]] <= `SD 1;
      end
    end
  end
  
  /* Update Data Storage */
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if (reset) begin
      tags   <= `SD 0;
      data   <= `SD 0;
    end else begin
      for (int i = 0; i < NUM_WR_PORTS; ++i) begin
        if (wr_en[i]) begin
          data[wr_idx[i]] <= `SD wr_data[i];
          tags[wr_idx[i]] <= `SD wr_tag[i];
        end
      end
    end
  end

endmodule
