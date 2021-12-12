module testbench ;
    logic reset, clock, rs_full;  
    STATION [`N-1:0] dispatched_stations;
    CDB [`N-1:0] cdb_input;
    FREE_FUNC_UNITS avail_func_units;
    RS_FUNC_PACKET rs_to_func;

	logic [36:0][5:0] req = {6'h00, 6'h01, 6'h02, 6'h03, 6'h04, 6'h05, 6'h06, 6'h07, 
							 6'h08, 6'h09, 6'h0a, 6'h0b, 6'h0c, 6'h0d, 6'h0e, 6'h0f, 
							 6'h10, 6'h11, 6'h12, 6'h13, 6'h14, 6'h15, 6'h16, 6'h17, 
						 	 6'h18, 6'h19, 6'h1a, 6'h1b, 6'h1c, 
							 6'h32, 6'h33, 6'h34, 6'h35, 6'h36, 6'h37, 6'h38, 6'h39};
	
	logic [36:0] reqDone = 37'd0;

    reservation_station rs(.reset, .clock, .rs_full, .dispatched_stations, .cdb_input, .avail_func_units, .rs_to_func);

    always begin
		#10;
		clock = ~clock;
	end

	function finish_assert;
		input in;
		begin
			if(~in) begin
				$error("\n***FAILED***\n\n");
				$finish;
			end
		end
	endfunction

	task check_empty;
		finish_assert(~rs_full);
		for (int i = 0; i < `NUM_ADDERS; i++) begin
			finish_assert(~rs_to_func.adders[i].valid);
			finish_assert(~rs_to_func.mults[i].valid);
			finish_assert(~rs_to_func.branches[i].valid);
			finish_assert(~rs_to_func.mems[i].valid);
		end
	endtask

	task inc_disp;
		dispatched_stations[0].dest_prf += 4;
		dispatched_stations[1].dest_prf += 4;
		dispatched_stations[2].dest_prf += 4;
		dispatched_stations[3].dest_prf += 4;
		dispatched_stations[0].op1_value = $random;
		dispatched_stations[1].op1_value = $random;
		dispatched_stations[2].op1_value = $random;
		dispatched_stations[3].op1_value = $random;
	endtask

	function check;
  		input [15:0] valid_in;
  		begin
    		for (int i = 0; i < `NUM_ADDERS; i++) begin
				logic [3:0] found;
				found = {~valid_in[i + 12], ~valid_in[i + 8], ~valid_in[i + 4], ~valid_in[i]};
				finish_assert(rs_to_func.adders[i].valid == valid_in[i]);
				finish_assert(rs_to_func.mults[i].valid == valid_in[i + 4]);
				finish_assert(rs_to_func.branches[i].valid == valid_in[i + 8]);
				finish_assert(rs_to_func.mems[i].valid == valid_in[i + 12]);
				for (int k = 0; k < 37; k++) begin
					if (rs_to_func.adders[i].valid && rs_to_func.adders[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[0] = 1'b1;
					end else if (rs_to_func.mults[i].valid && rs_to_func.mults[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[1] = 1'b1;
					end else if (rs_to_func.branches[i].valid && rs_to_func.branches[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[2] = 1'b1;
					end else if (rs_to_func.mems[i].valid && rs_to_func.mems[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[3] = 1'b1;
					end
				end
				finish_assert(&found);
			end
  		end
	endfunction
	
	initial begin
		$monitor("Dispatch valid: %b%b%b%b | CDB valid: %b%b%b%b | Avail func: %h%h%h%h | Funct valid: %b %b %b %b",
			dispatched_stations[0].valid, dispatched_stations[1].valid, dispatched_stations[2].valid, dispatched_stations[3].valid,
			cdb_input[0].valid, cdb_input[1].valid, cdb_input[2].valid, cdb_input[3].valid, 
			avail_func_units.adders_free, avail_func_units.mults_free, avail_func_units.branches_free, avail_func_units.mems_free,
			rs_to_func.adders[0].valid, rs_to_func.adders[1].valid, rs_to_func.adders[2].valid, rs_to_func.adders[3].valid);
		reset = 1;
		clock = 0;
		dispatched_stations = 0;
		cdb_input = 0;
		avail_func_units = 0;

		//reset module
		@(negedge clock);
		reset = 0;

		@(negedge clock);
		check_empty();

		//**************************** ADD TESTS ********************************//

		dispatched_stations[0] = {
			`TRUE,
			`FALSE,
			32'd3,
			`FALSE,
			32'd2,
			6'h01,
			ADD,
			ALU_ADD
		};

		@(negedge clock);
		check_empty();

		//dispatched_stations[1].valid = `FALSE;
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			32'd3,
			`FALSE,
			32'd4,
			6'h02,
			ADD,
			ALU_ADD
		};

		//still no valid instructions
		@(negedge clock);
		check_empty();

		//dispatched_stations[0].valid = `FALSE;
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			32'd3,
			`TRUE,
			32'd4,
			6'h03,
			ADD,
			ALU_ADD
		};

		@(negedge clock);
		check_empty();

		avail_func_units.adders_free = 4'b1;
		dispatched_stations[0].valid = `FALSE;
		//dispatched_stations[1].valid = `FALSE;

		//check to make sure only commits instructions that are ready
		@(posedge clock);
		finish_assert(~rs_full);
		//finish_assert(~rs_to_func.adders[0].valid);
		//finish_assert(~rs_to_func.adders[3].valid);
		//finish_assert(~rs_to_func.adders[1].valid);
		finish_assert(rs_to_func.adders[0].valid);
		finish_assert(rs_to_func.adders[0] == {
			`TRUE,
			32'd3,
			32'd4,
			6'h03,
			ALU_ADD
		});
		for (int i = 2; i < `NUM_ADDERS; i++) begin
			finish_assert(~rs_to_func.mults[i].valid);
			finish_assert(~rs_to_func.branches[i].valid);
			finish_assert(~rs_to_func.mems[i].valid);
		end

		$display("\n***PASSED***\n\n");
		$finish;
	end
endmodule