module testbench ;
    logic reset, clock;
    ROB_ENTRY [`N-1:0] dispatched_entries;
	CDB [`N-1:0] cdb_input;

    logic branch_mispredict, rob_full;
    logic [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] next_entries_index;
    logic [`XLEN:0] corrected_branch_address;
	BRANCH_PREDICTION_PACKET [`N-1:0] branch_pred_packet;
    ROB_COMMIT_PACKET [`N-1:0] rob_commit;

    rob rob1(
		.reset(reset),
		.clock(clock),
		.dispatched_entries(dispatched_entries),
		.cdb_input(cdb_input),
		.branch_mispredict(branch_mispredict),
		.rob_full(rob_full),
		.next_entries_index(next_entries_index),
		.corrected_branch_address(corrected_branch_address),
		.branch_pred_packet(branch_pred_packet),
		.rob_commit(rob_commit)
	);

    always begin
		#10;
		clock = ~clock;
	end

	task check_empty;
		assert(~branch_mispredict);
		assert(~rob_full);
		for (int i = 0; i < `N; i++) begin
			assert (~branch_pred_packet[i].valid);
			assert (~rob_commit[i].valid);
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
		$monitor("Issued valid: %b%b%b%b | CDB valid: %b%b%b%b",
			dispatched_entries[0].valid, dispatched_entries[1].valid, dispatched_entries[2].valid, dispatched_entries[3].valid,
			cdb_input[0].valid, cdb_input[1].valid,cdb_input[2].valid,cdb_input[3].valid
		);
		reset = 1;
		clock = 0;
		dispatched_entries = 0;
		cdb_input = 0;


		//reset module
		@(negedge clock);
		reset = 0;

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h00);

		@(negedge clock);
		dispatched_entries[0] = {
			`TRUE,
			`FALSE,
			`FALSE,
			5'h00,
			6'h00,
			32'd0,
			32'd4,
			32'd0,
			3'd0,
			ALU_AND
		};

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h00);

		@(negedge clock);
		dispatched_entries[0].valid = `FALSE;
		cdb_input = {
			`TRUE,
			6'h00,
			5'h00,
			32'd4,
			32'd69,
			`TRUE
		};

		@(posedge clock);
		@(posedge clock);
		assert(~branch_mispredict);
		assert(~rob_full);
		for (int i = 0; i < `N; i++) begin
			assert (~branch_pred_packet[i].valid);
		end
		assert(rob_commit[0].valid);
		assert(rob_commit[0].dest_arf == 5'h00);
		assert(rob_commit[0].dest_prf == 6'h00);
		assert(next_entries_index[0] == 5'h01);

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_entries[0] = {
			`TRUE,
			`FALSE,
			`FALSE,
			5'h01,
			6'h01,
			32'd0,
			32'd8,
			32'd4,
			3'd0,
			ALU_SUB
		};

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h01);

		@(negedge clock);
		dispatched_entries[0].valid = `FALSE;
		cdb_input = {
			`TRUE,
			6'h01,
			5'h01,
			32'd8,
			32'd69,
			`TRUE
		};

		@(posedge clock);
		@(posedge clock);
		assert(~branch_mispredict);
		assert(~rob_full);
		for (int i = 0; i < `N; i++) begin
			assert (~branch_pred_packet[i].valid);
		end
		assert(rob_commit[0].valid);
		assert(rob_commit[0].dest_arf == 5'h01);
		assert(rob_commit[0].dest_prf == 6'h01);
		assert(next_entries_index[0] == 5'h02);

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_entries[0] = {
			`TRUE,
			`FALSE,
			`FALSE,
			5'h02,
			6'h02,
			32'd0,
			32'd20,
			32'd8,
			3'd0,
			ALU_JAL
		};

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h02);

		@(negedge clock);
		dispatched_entries[0].valid = `FALSE;

		@(negedge clock);
		cdb_input = {
			`TRUE,
			6'h02,
			5'h02,
			32'd20,
			32'd8,
			`TRUE
		};

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h03);

		@(posedge clock);
		assert(~branch_mispredict);
		assert(~rob_full);
		for (int i = 1; i < `N; i++) begin
			assert (~branch_pred_packet[i].valid);
		end
		assert(branch_pred_packet[0].valid);
		assert(branch_pred_packet[0].branch_address == 32'd20);
		assert(branch_pred_packet[0].pc == 32'd8);
		assert(branch_pred_packet[0].correct);
		assert(rob_commit[0].valid);
		assert(rob_commit[0].dest_arf == 5'h02);
		assert(rob_commit[0].dest_prf == 6'h02);

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_entries[0] = {
			`TRUE,
			`FALSE,
			`FALSE,
			5'h03,
			6'h03,
			32'd0,
			32'd16,
			32'd12,
			3'd0,
			ALU_JAL
		};

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h03);

		@(negedge clock);
		dispatched_entries[0].valid = `FALSE;

		@(negedge clock);
		cdb_input = {
			`TRUE,
			6'h03,
			5'h03,
			32'd24,
			32'd8,
			`TRUE
		};

		@(posedge clock);
		check_empty();
		assert(next_entries_index[0] == 5'h04);

		@(posedge clock);
		assert(branch_mispredict);
		assert(~rob_full);
		for (int i = 1; i < `N; i++) begin
			assert (~branch_pred_packet[i].valid);
		end
		assert(branch_pred_packet[0].valid);
		assert(branch_pred_packet[0].branch_address == 32'd24);
		assert(branch_pred_packet[0].pc == 32'd12);
		assert(~branch_pred_packet[0].correct);
		assert(rob_commit[0].valid);
		assert(rob_commit[0].dest_arf == 5'h03);
		assert(rob_commit[0].dest_prf == 6'h03);

		@(posedge clock);
		@(posedge clock);

		$display("\n***PASSED***\n\n");
		$finish;
	end
endmodule