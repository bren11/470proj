module functional_unit (
    input reset,
    input clock,
    input nuke,

    input LSQ_IN_PACKET [`N-1:0] lsq_in,
    input [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] next_entries,
    input STORES_READY [`N-1:0] stores_ready,

    input RS_FUNC_PACKET issued_instr,

    output FREE_FUNC_UNITS avail_func_units,
    output CDB [`N-1:0] cdb_output,

    input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply

	output BUS_COMMAND          data_proc2mem_command,   // command sent to memory
	output logic [`XLEN-1:0]    data_proc2mem_addr,      // Address sent to memory
	output logic [63:0]         data_proc2mem_data,      // Data sent to memory

    output logic [`N-1:0][`LSQ_INDEX_BITS-1:0] n_lsq_idxs,

    output logic lsq_full,
	//Visual testbench outputs
	output FUNC_UNIT_OUT fu_out,
	output FREE_FUNC_UNITS fu_ready,
	output LOAD_QUEUE_ENTRY [`LOAD_QUEUE_SIZE-1:0] load_queue,
	output STORE_QUEUE_ENTRY [`STORE_QUEUE_SIZE-1:0] store_queue
);

    wire [`FUNC_UNIT_NUM-1:0] output_ready;
    wire [`N-1:0][`FUNC_UNIT_NUM-1:0] ready_gnt_bus;
    FUNC_UNIT_SEL fu_sel;

    adder_fu adders [`NUM_ADDERS-1:0](
        .reset,
        .clock,
        .input_instr(issued_instr.types.adders),
        .sel(fu_sel.types.adders),
        .out(fu_out.types.adders),
        .ready(fu_ready.types.adders_free)
    );
    mult_fu mults [`NUM_MULTS-1:0](
        .reset,
        .clock,
        .input_instr(issued_instr.types.mults),
        .sel(fu_sel.types.mults),
        .out(fu_out.types.mults),
        .ready(fu_ready.types.mults_free)
    );
    branch_fu branches [`NUM_BRANCHES-1:0](
        .reset,
        .clock,
        .input_instr(issued_instr.types.branches),
        .sel(fu_sel.types.branches),
        .out(fu_out.types.branches),
        .ready(fu_ready.types.branches_free)
    );
    lsq mems (
        .reset(reset && ~nuke),
        .clock,
        .nuke(nuke),
        .lsq_in,
        .next_entries,
        .stores_ready,
        .input_instr(issued_instr.types.mems),
        .sel(fu_sel.types.mems),
        .out(fu_out.types.mems),
        .ready(fu_ready.types.mems_free),
        .mem2proc_response,        // Tag from memory about current request
	    .mem2proc_data,            // Data coming back from memory
	    .mem2proc_tag,              // Tag from memory about current reple
	    .proc2mem_command(data_proc2mem_command),   // command sent to memory
	    .proc2mem_addr(data_proc2mem_addr),      // Address sent to memory
	    .proc2mem_data(data_proc2mem_data),      // Data sent to memory
        .n_lsq_idxs,
        .lsq_full,
		.load_queue,
		.store_queue
    );

    genvar valid_i;
    for (valid_i = 0; valid_i < `FUNC_UNIT_NUM; valid_i++) begin
        assign output_ready[valid_i] = fu_out.outputs[valid_i].valid;
    end

    my_priority_selector #(`N, `FUNC_UNIT_NUM) ps_cdb_sel (
        .clock,
        .reset,
        .req(output_ready),
        .gnt_bus(ready_gnt_bus)
    );

    always_comb begin
        fu_sel.select = 0;
        cdb_output = 0;
        for(int cdb_i = 0; cdb_i < `N; ++cdb_i) begin
            for(int func_i = 0; func_i < `FUNC_UNIT_NUM; ++func_i) begin
                if (ready_gnt_bus[cdb_i][func_i]) begin
                    cdb_output[cdb_i] = {
                        `TRUE,
                        fu_out.outputs[func_i].dest_prf,
                        fu_out.outputs[func_i].rob_entry,
                        fu_out.outputs[func_i].branch_address,
                        fu_out.outputs[func_i].value,
                        fu_out.outputs[func_i].value_valid
                    };
                    fu_sel.select[func_i] = `TRUE;
                end
            end
        end
    end

    assign avail_func_units.frees = fu_ready.frees | fu_sel;
endmodule
