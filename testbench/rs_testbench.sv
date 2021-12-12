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
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
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
				finish_assert(rs_to_func.types.adders[i].valid == valid_in[i]);
				finish_assert(rs_to_func.types.mults[i].valid == valid_in[i + 4]);
				finish_assert(rs_to_func.types.branches[i].valid == valid_in[i + 8]);
				finish_assert(rs_to_func.types.mems[i].valid == valid_in[i + 12]);
				for (int k = 0; k < 37; k++) begin
					if (rs_to_func.types.adders[i].valid && rs_to_func.types.adders[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[0] = 1'b1;
					end else if (rs_to_func.types.mults[i].valid && rs_to_func.types.mults[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[1] = 1'b1;
					end else if (rs_to_func.types.branches[i].valid && rs_to_func.types.branches[i].dest_prf == req[k]) begin
						reqDone[k] = 1'b1;
						found[2] = 1'b1;
					end else if (rs_to_func.types.mems[i].valid && rs_to_func.types.mems[i].dest_prf == req[k]) begin
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
			avail_func_units.types.adders_free, avail_func_units.types.mults_free, avail_func_units.types.branches_free, avail_func_units.types.mems_free,
			rs_to_func.types.adders[0].valid, rs_to_func.types.adders[1].valid, rs_to_func.types.adders[2].valid, rs_to_func.types.adders[3].valid);
		reset = 1;
		clock = 0;
		dispatched_stations = 0;
		cdb_input = 0;
		avail_func_units.types = 0;

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

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
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

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
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

		avail_func_units.types.adders_free = 4'b0110;
		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1].valid = `FALSE;

		//check to make sure only commits instructions that are ready
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(~rs_to_func.types.adders[0].valid);
		finish_assert(~rs_to_func.types.adders[3].valid);
		finish_assert(~rs_to_func.types.adders[1].valid);
		finish_assert(rs_to_func.types.adders[2].valid);
		finish_assert(rs_to_func.types.adders[2] == {
			`TRUE,
			32'd3,
			32'd4,
			6'h03,
			ALU_ADD
		});
		for (int i = 2; i < `NUM_ADDERS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock)
		avail_func_units.types.adders_free = 4'b0001;
		avail_func_units.types.mults_free = 4'b1110;
		cdb_input[0] = {
			`TRUE,
			6'h02,
			32'd32
		};
		cdb_input[1] = {
			`TRUE,
			6'h03,
			32'd35
		};
		cdb_input[2] = {
			`TRUE,
			6'h04,
			32'd37
		};

		//shouldn't output anything until cycle after cdb update
		@(posedge clock);
		check_empty();

		//check that it doesnt commit more instructions than alu's are available
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.adders[0] == {
			`TRUE,
			32'h23,
			32'h20,
			6'h01,
			ALU_ADD
		});
		finish_assert(~rs_to_func.types.adders[1].valid);
		finish_assert(~rs_to_func.types.adders[3].valid);
		finish_assert(~rs_to_func.types.adders[2].valid);
		for (int i = 1; i < `NUM_ADDERS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock);
		avail_func_units.types.adders_free = 4'b0000;
		cdb_input[0].valid = `FALSE;
		cdb_input[1].valid = `FALSE;
		cdb_input[2].valid = `FALSE;

		//cant execute if no ready functional units
		@(posedge clock);
		check_empty();

		@(negedge clock)
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			32'd9,
			`FALSE,
			32'd3,
			6'h04,
			ADD,
			ALU_ADD
		};
		cdb_input[0] = {
			`TRUE,
			6'h03,
			32'd8
		};
		avail_func_units.types.adders_free = 4'b0101;

		//can accept data and output data in the same cycle
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.adders[2] == {
			`TRUE,
			32'd3,
			32'h25,
			6'h02,
			ALU_ADD
		});
		finish_assert(~rs_to_func.types.adders[1].valid);
		finish_assert(~rs_to_func.types.adders[3].valid);
		finish_assert(~rs_to_func.types.adders[0].valid);
		for (int i = 1; i < `NUM_ADDERS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_stations[0].valid = `FALSE;

		//can accept an instruction and read its value from cdb at the same time
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.adders[2] == {
			`TRUE,
			32'd9,
			32'd8,
			6'h04,
			ALU_ADD
		});
		finish_assert(~rs_to_func.types.adders[1].valid);
		finish_assert(~rs_to_func.types.adders[3].valid);
		finish_assert(~rs_to_func.types.adders[0].valid);
		for (int i = 1; i < `NUM_ADDERS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end
		@(negedge clock);
		check_empty();

		//**************************** MULT TESTS ********************************//

		avail_func_units.types.mults_free = 4'b0000;

		dispatched_stations[0] = {
			`TRUE,
			`FALSE,
			32'd3,
			`FALSE,
			32'd2,
			6'h01,
			MULT,
			ALU_MUL
		};

		@(negedge clock);
		check_empty();

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			32'd3,
			`FALSE,
			32'd4,
			6'h02,
			MULT,
			ALU_MUL
		};

		//still no valid instructions
		@(negedge clock);
		check_empty();

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			32'd3,
			`TRUE,
			32'd4,
			6'h03,
			MULT,
			ALU_MUL
		};

		@(negedge clock);
		check_empty();

		avail_func_units.types.mults_free = 4'b0110;
		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1].valid = `FALSE;

		//check to make sure only commits instructions that are ready
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(~rs_to_func.types.mults[0].valid);
		finish_assert(~rs_to_func.types.mults[3].valid);
		finish_assert(~rs_to_func.types.mults[1].valid);
		finish_assert(rs_to_func.types.mults[2].valid);
		finish_assert(rs_to_func.types.mults[2] == {
			`TRUE,
			32'd3,
			32'd4,
			6'h03,
			ALU_MUL
		});
		for (int i = 2; i < `NUM_MULTS; i++) begin
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock)
		avail_func_units.types.mults_free = 4'b0001;
		avail_func_units.types.adders_free = 4'b1110;
		cdb_input[0] = {
			`TRUE,
			6'h02,
			32'd32
		};
		cdb_input[1] = {
			`TRUE,
			6'h03,
			32'd35
		};
		cdb_input[2] = {
			`TRUE,
			6'h04,
			32'd37
		};

		//shouldn't output anything until cycle after cdb update
		@(posedge clock);
		check_empty();

		//check that it doesnt commit more instructions than alu's are available
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.mults[0] == {
			`TRUE,
			32'h23,
			32'h20,
			6'h01,
			ALU_MUL
		});
		finish_assert(~rs_to_func.types.mults[1].valid);
		finish_assert(~rs_to_func.types.mults[3].valid);
		finish_assert(~rs_to_func.types.mults[2].valid);
		for (int i = 1; i < `NUM_MULTS; i++) begin
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock);
		avail_func_units.types.mults_free = 4'b0000;
		cdb_input[0].valid = `FALSE;
		cdb_input[1].valid = `FALSE;
		cdb_input[2].valid = `FALSE;

		//cant execute if no ready functional units
		@(posedge clock);
		check_empty();

		@(negedge clock)
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			32'd9,
			`FALSE,
			32'd3,
			6'h04,
			MULT,
			ALU_MUL
		};
		cdb_input[0] = {
			`TRUE,
			6'h03,
			32'd8
		};
		avail_func_units.types.mults_free = 4'b0101;

		//can accept data and output data in the same cycle
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.mults[2] == {
			`TRUE,
			32'd3,
			32'h25,
			6'h02,
			ALU_MUL
		});
		finish_assert(~rs_to_func.types.mults[1].valid);
		finish_assert(~rs_to_func.types.mults[3].valid);
		finish_assert(~rs_to_func.types.mults[0].valid);
		for (int i = 1; i < `NUM_MULTS; i++) begin
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_stations[0].valid = `FALSE;

		//can accept an instruction and read its value from cdb at the same time
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.mults[2] == {
			`TRUE,
			32'd9,
			32'd8,
			6'h04,
			ALU_MUL
		});
		finish_assert(~rs_to_func.types.mults[1].valid);
		finish_assert(~rs_to_func.types.mults[3].valid);
		finish_assert(~rs_to_func.types.mults[0].valid);
		for (int i = 1; i < `NUM_MULTS; i++) begin
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end
		@(negedge clock);
		check_empty();

		//**************************** BRANCH TESTS ********************************//

		avail_func_units.types.branches_free = 4'b0000;

		dispatched_stations[0] = {
			`TRUE,
			`FALSE,
			32'd3,
			`FALSE,
			32'd2,
			6'h01,
			BRANCH,
			ALU_BR
		};

		@(negedge clock);
		check_empty();

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			32'd3,
			`FALSE,
			32'd4,
			6'h02,
			BRANCH,
			ALU_BR
		};

		//still no valid instructions
		@(negedge clock);
		check_empty();

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			32'd3,
			`TRUE,
			32'd4,
			6'h03,
			BRANCH,
			ALU_BR
		};

		@(negedge clock);
		check_empty();

		avail_func_units.types.branches_free = 4'b0110;
		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1].valid = `FALSE;

		//check to make sure only commits instructions that are ready
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(~rs_to_func.types.branches[0].valid);
		finish_assert(~rs_to_func.types.branches[3].valid);
		finish_assert(~rs_to_func.types.branches[1].valid);
		finish_assert(rs_to_func.types.branches[2].valid);
		finish_assert(rs_to_func.types.branches[2] == {
			`TRUE,
			32'd3,
			32'd4,
			6'h03,
			ALU_BR
		});
		for (int i = 2; i < `NUM_BRANCHES; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock)
		avail_func_units.types.branches_free = 4'b0001;
		avail_func_units.types.mults_free = 4'b1110;
		cdb_input[0] = {
			`TRUE,
			6'h02,
			32'd32
		};
		cdb_input[1] = {
			`TRUE,
			6'h03,
			32'd35
		};
		cdb_input[2] = {
			`TRUE,
			6'h04,
			32'd37
		};

		//shouldn't output anything until cycle after cdb update
		@(posedge clock);
		check_empty();

		//check that it doesnt commit more instructions than alu's are available
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.branches[0] == {
			`TRUE,
			32'h23,
			32'h20,
			6'h01,
			ALU_BR
		});
		finish_assert(~rs_to_func.types.branches[1].valid);
		finish_assert(~rs_to_func.types.branches[3].valid);
		finish_assert(~rs_to_func.types.branches[2].valid);
		for (int i = 1; i < `NUM_BRANCHES; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock);
		avail_func_units.types.branches_free = 4'b0000;
		cdb_input[0].valid = `FALSE;
		cdb_input[1].valid = `FALSE;
		cdb_input[2].valid = `FALSE;

		//cant execute if no ready functional units
		@(posedge clock);
		check_empty();

		@(negedge clock)
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			32'd9,
			`FALSE,
			32'd3,
			6'h04,
			BRANCH,
			ALU_BR
		};
		cdb_input[0] = {
			`TRUE,
			6'h03,
			32'd8
		};
		avail_func_units.types.branches_free = 4'b0101;

		//can accept data and output data in the same cycle
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.branches[2] == {
			`TRUE,
			32'd3,
			32'h25,
			6'h02,
			ALU_BR
		});
		finish_assert(~rs_to_func.types.branches[1].valid);
		finish_assert(~rs_to_func.types.branches[3].valid);
		finish_assert(~rs_to_func.types.branches[0].valid);
		for (int i = 1; i < `NUM_BRANCHES; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_stations[0].valid = `FALSE;

		//can accept an instruction and read its value from cdb at the same time
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.branches[2] == {
			`TRUE,
			32'd9,
			32'd8,
			6'h04,
			ALU_BR
		});
		finish_assert(~rs_to_func.types.branches[1].valid);
		finish_assert(~rs_to_func.types.branches[3].valid);
		finish_assert(~rs_to_func.types.branches[0].valid);
		for (int i = 1; i < `NUM_BRANCHES; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
			finish_assert(~rs_to_func.types.mems[i].valid);
		end
		@(negedge clock);
		check_empty();

		//**************************** MEM TESTS ********************************//

		avail_func_units.types.mems_free = 4'b0000;

		dispatched_stations[0] = {
			`TRUE,
			`FALSE,
			32'd3,
			`FALSE,
			32'd2,
			6'h01,
			MEM,
			ALU_SW
		};

		@(negedge clock);
		check_empty();

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			32'd3,
			`FALSE,
			32'd4,
			6'h02,
			MEM,
			ALU_SW
		};

		//still no valid instructions
		@(negedge clock);
		check_empty();

		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			32'd3,
			`TRUE,
			32'd4,
			6'h03,
			MEM,
			ALU_SW
		};

		@(negedge clock);
		check_empty();

		avail_func_units.types.mems_free = 4'b0110;
		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1].valid = `FALSE;

		//check to make sure only commits instructions that are ready
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(~rs_to_func.types.mems[0].valid);
		finish_assert(~rs_to_func.types.mems[3].valid);
		finish_assert(~rs_to_func.types.mems[1].valid);
		finish_assert(rs_to_func.types.mems[2].valid);
		finish_assert(rs_to_func.types.mems[2] == {
			`TRUE,
			32'd3,
			32'd4,
			6'h03,
			ALU_SW
		});
		for (int i = 2; i < `NUM_MEMS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
		end

		@(negedge clock)
		avail_func_units.types.mems_free = 4'b0001;
		avail_func_units.types.mults_free = 4'b1110;
		cdb_input[0] = {
			`TRUE,
			6'h02,
			32'd32
		};
		cdb_input[1] = {
			`TRUE,
			6'h03,
			32'd35
		};
		cdb_input[2] = {
			`TRUE,
			6'h04,
			32'd37
		};

		//shouldn't output anything until cycle after cdb update
		@(posedge clock);
		check_empty();

		//check that it doesnt commit more instructions than alu's are available
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.mems[0] == {
			`TRUE,
			32'h23,
			32'h20,
			6'h01,
			ALU_SW
		});
		finish_assert(~rs_to_func.types.mems[1].valid);
		finish_assert(~rs_to_func.types.mems[3].valid);
		finish_assert(~rs_to_func.types.mems[2].valid);
		for (int i = 1; i < `NUM_MEMS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
		end

		@(negedge clock);
		avail_func_units.types.mems_free = 4'b0000;
		cdb_input[0].valid = `FALSE;
		cdb_input[1].valid = `FALSE;
		cdb_input[2].valid = `FALSE;

		//cant execute if no ready functional units
		@(posedge clock);
		check_empty();

		@(negedge clock)
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			32'd9,
			`FALSE,
			32'd3,
			6'h04,
			MEM,
			ALU_SW
		};
		cdb_input[0] = {
			`TRUE,
			6'h03,
			32'd8
		};
		avail_func_units.types.mems_free = 4'b0101;

		//can accept data and output data in the same cycle
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.mems[2] == {
			`TRUE,
			32'd3,
			32'h25,
			6'h02,
			ALU_SW
		});
		finish_assert(~rs_to_func.types.mems[1].valid);
		finish_assert(~rs_to_func.types.mems[3].valid);
		finish_assert(~rs_to_func.types.mems[0].valid);
		for (int i = 1; i < `NUM_MEMS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
		end

		@(negedge clock);
		cdb_input[0].valid = `FALSE;
		dispatched_stations[0].valid = `FALSE;

		//can accept an instruction and read its value from cdb at the same time
		@(posedge clock);
		finish_assert(~rs_full);
		finish_assert(rs_to_func.types.mems[2] == {
			`TRUE,
			32'd9,
			32'd8,
			6'h04,
			ALU_SW
		});
		finish_assert(~rs_to_func.types.mems[1].valid);
		finish_assert(~rs_to_func.types.mems[3].valid);
		finish_assert(~rs_to_func.types.mems[0].valid);
		for (int i = 1; i < `NUM_MEMS; i++) begin
			finish_assert(~rs_to_func.types.mults[i].valid);
			finish_assert(~rs_to_func.types.branches[i].valid);
			finish_assert(~rs_to_func.types.adders[i].valid);
		end
		@(negedge clock);
		check_empty();

		//**************************** FILLING RS TESTS ********************************//
		dispatched_stations[0] = {
			`TRUE,
			`TRUE,
			$random,
			`FALSE,
			32'd6,
			6'h00,
			ADD,
			ALU_ADD
		};
		dispatched_stations[1] = {
			`TRUE,
			`TRUE,
			$random,
			`FALSE,
			32'd6,
			6'h01,
			MULT,
			ALU_MUL
		};
		dispatched_stations[2] = {
			`TRUE,
			`TRUE,
			$random,
			`FALSE,
			32'd6,
			6'h02,
			BRANCH,
			ALU_ADD
		};
		dispatched_stations[3] = {
			`TRUE,
			`TRUE,
			$random,
			`FALSE,
			32'd6,
			6'h03,
			MEM,
			ALU_REM
		};

		avail_func_units.types = {
			4'hf,
			4'hf,
			4'hf,
			4'hf
		};
		@(negedge clock);
		check_empty();

		inc_disp();

		@(negedge clock);
		check_empty();
		
		inc_disp();
		
		@(negedge clock);
		check_empty();
		
		inc_disp();
		
		@(negedge clock);
		check_empty();
		
		inc_disp();
		
		@(negedge clock);
		check_empty();
		
		inc_disp();
		
		@(negedge clock);
		check_empty();
		
		inc_disp();
		
		@(negedge clock);
		check_empty();
		
		dispatched_stations[0].dest_prf += 4;
		dispatched_stations[1].valid = `FALSE;
		dispatched_stations[2].valid = `FALSE;
		dispatched_stations[3].valid = `FALSE;

		@(negedge clock);
		dispatched_stations[0].valid = `FALSE;

		//will throw error when rs is full
		@(posedge clock);
		finish_assert(rs_full);
		
		@(negedge clock);
		cdb_input[2] = {
			`TRUE,
			6'h06,
			$random
		};

		//send bogus invalid instuctions
		@(negedge clock);
		cdb_input[0].value = $random;
		cdb_input[1].value = $random;
		cdb_input[2].value = $random;
		cdb_input[3].value = $random;
		dispatched_stations[0].dest_prf = 6'd47;
		dispatched_stations[0].dest_prf = 6'd48;
		dispatched_stations[0].dest_prf = 6'd49;
		dispatched_stations[0].dest_prf = 6'd50;

		//make sure it outputs all instructions available
		@(posedge clock);
		check(16'hffff);

		@(negedge clock);
		finish_assert(~rs_full);
		cdb_input[2].value = $random;
		dispatched_stations[0].valid = `TRUE;
		dispatched_stations[0].dest_prf = 6'h32;
		dispatched_stations[1].valid = `TRUE;
		dispatched_stations[1].dest_prf = 6'h33;
		dispatched_stations[2].valid = `TRUE;
		dispatched_stations[2].dest_prf = 6'h34;
		dispatched_stations[3].valid = `TRUE;
		dispatched_stations[3].dest_prf = 6'h35;
		avail_func_units.types = {
			4'h4,
			4'h4,
			4'h4,
			4'h4
		};

		//make sure can input again once not full anymore
		@(posedge clock);
		finish_assert(~rs_full);
		check(16'h4444);

		@(negedge clock);
		cdb_input[2].valid = `FALSE;
		cdb_input[2].value = $random;
		inc_disp();
		avail_func_units.types = {
			4'h0,
			4'h0,
			4'h0,
			4'h0
		};
		

		//can overwrite old data and still retrieve it.
		@(posedge clock);
		check_empty();

		@(negedge clock);
		dispatched_stations[0].valid = `FALSE;
		dispatched_stations[1].valid = `FALSE;
		dispatched_stations[2].valid = `FALSE;
		dispatched_stations[3].valid = `FALSE;
		avail_func_units.types = {
			4'hf,
			4'hf,
			4'hf,
			4'hf
		};
		cdb_input[2].valid = `TRUE;
		cdb_input[2].value = $random;

		@(posedge clock);
		finish_assert(~rs_full);
		check(16'hdddf);

		@(posedge clock);
		finish_assert(~rs_full);
		check(16'h8888);

		@(posedge clock);
		check_empty();
		finish_assert(&reqDone);

		$display("\n***PASSED***\n\n");
		$finish;
	end
endmodule