module testbench ;
    logic reset, clock, rs_full, nuke;  
	RS_FUNC_PACKET issued_instr;
    FREE_FUNC_UNITS avail_func_units;
    CDB [`N-1:0] cdb_output;
	LSQ_IN_PACKET   [`N-1:0]    lsq_in_packet;
	logic   [`N-1:0][`LSQ_INDEX_BITS-1:0]   n_lsq_index;
	logic [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] rob_next_entries_indicies;
	STORES_READY                [`N-1:0]    rob_stores_ready;

	logic [3:0]   mem2proc_response;        // Tag from memory about current request
	logic [63:0]  mem2proc_data;            // Data coming back from memory
	logic [3:0]   mem2proc_tag;              // Tag from memory about current reply
	logic           [1:0]                   data_proc2mem_command;
    logic           [`XLEN-1:0]             data_proc2mem_addr;
    logic           [63:0]                  data_proc2mem_data;
    logic                                   lsq_structural_hazard;

    functional_unit fu(
		.reset(reset), 
		.clock(clock), 
        .nuke(nuke),

        .lsq_in(lsq_in_packet),
        .n_lsq_idxs(n_lsq_index),
        .next_entries(rob_next_entries_indicies),
        .stores_ready(rob_stores_ready),
        
        .issued_instr(issued_instr), 
		.avail_func_units(avail_func_units), 
		.cdb_output(cdb_output),

        .mem2proc_response(mem2proc_response),        // Tag from memory about current request
	    .mem2proc_data(mem2proc_data),            // Data coming back from memory
	    .mem2proc_tag(mem2proc_tag),              // Tag from memory about current reple
	    .data_proc2mem_command(data_proc2mem_command),   // command sent to memory
	    .data_proc2mem_addr(data_proc2mem_addr),      // Address sent to memory
	    .data_proc2mem_data(data_proc2mem_data),      // Data sent to memory

        .lsq_full(lsq_structural_hazard)
	);

    always begin
		#10;
		clock = ~clock;
	end

	task check_empty;
		for (int i = 0; i < `N; i++) begin
			assert (~cdb_output[i].valid);
		end
	endtask

	function finish_assert;
		input in;
		begin
			if(~in) begin
				$error("\n***FAILED***\n\n");
				$finish;
			end
		end
	endfunction
	
	initial begin
		$monitor("Issued valid: %h%h%h%h | free: %h | CDB valid: %b%b%b%b",
			{issued_instr.types.adders[3].valid, issued_instr.types.adders[2].valid, issued_instr.types.adders[1].valid, issued_instr.types.adders[0].valid},
			{issued_instr.types.mults[3].valid, issued_instr.types.mults[2].valid, issued_instr.types.mults[1].valid, issued_instr.types.mults[0].valid},
			{issued_instr.types.branches[3].valid, issued_instr.types.branches[2].valid, issued_instr.types.branches[1].valid, issued_instr.types.branches[0].valid},
			{issued_instr.types.mems[3].valid, issued_instr.types.mems[2].valid, issued_instr.types.mems[1].valid, issued_instr.types.mems[0].valid},
			avail_func_units.frees, 
			cdb_output[0].valid, cdb_output[1].valid,cdb_output[2].valid,cdb_output[3].valid
		);
		reset = 1;
		clock = 0;
		issued_instr.rs_to_func = 0;
		nuke = 0;
		lsq_in_packet = 0;
		rob_next_entries_indicies = 0;
		rob_stores_ready = 0;

		//reset module
		@(negedge clock);
		reset = 0;

		@(posedge clock);
		check_empty();

		@(negedge clock);
		issued_instr.types.adders[0] = {
			`TRUE,
			32'd1,
			32'd3,
			6'h1,
			5'h1,
			32'h8,
			32'h8,
			ALU_ADD
		};

		@(posedge clock);
		check_empty();

		@(negedge clock);
		issued_instr.types.adders[0] = {
			`TRUE,
			32'h3,
			32'h1,
			6'h2,
			5'h1,
			32'h8,
			32'h8,
			ALU_SUB
		};

		@(posedge clock);
		assert(cdb_output[0].valid);
		assert(~cdb_output[1].valid);
		assert(~cdb_output[2].valid);
		assert(~cdb_output[3].valid);
		assert(cdb_output[0].dest_prf == 6'h1);
		assert(cdb_output[0].value == 32'h4);

		@(negedge clock);
		issued_instr.types.adders[0].valid = `FALSE;

		@(posedge clock);
		assert(cdb_output[0].valid);
		assert(~cdb_output[1].valid);
		assert(~cdb_output[2].valid);
		assert(~cdb_output[3].valid);
		assert(cdb_output[0].dest_prf == 6'h2);
		assert(cdb_output[0].value == 32'h2);

		@(posedge clock);
		check_empty();

		@(negedge clock);
		issued_instr.types.adders[0] = {
			`TRUE,
			32'h3,
			32'h1,
			6'h3,
			5'h1,
			32'h8,
			32'h8,
			ALU_AND
		};
		issued_instr.types.adders[1] = {
			`TRUE,
			32'h3,
			32'h1,
			6'h4,
			5'h1,
			32'h8,
			32'h8,
			ALU_OR
		};
		issued_instr.types.adders[2] = {
			`TRUE,
			32'h3,
			32'h1,
			6'h5,
			5'h1,
			32'h8,
			32'h8,
			ALU_XOR
		};
		issued_instr.types.adders[3] = {
			`TRUE,
			32'h3,
			32'h1,
			6'h6,
			5'h1,
			32'h8,
			32'h8,
			ALU_SLL
		};
		issued_instr.types.mults[0] = {
			`TRUE,
			32'h3,
			32'h2,
			6'hB,
			5'h1,
			32'h8,
			32'h8,
			ALU_MUL
		};

		@(negedge clock);
		issued_instr.rs_to_func = 0;

		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);
		@(posedge clock);

		$display("\n***PASSED***\n\n");
		$finish;
	end
endmodule