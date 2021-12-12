module  testbench ;
    logic clock, reset;
    logic           [`N-1:0][`PRF_NUM_INDEX_BITS-1:0]   phys_reg1;
    logic           [`N-1:0][`PRF_NUM_INDEX_BITS-1:0]   phys_reg2;
    CDB             [`N-1:0]                            cdb_in;
    logic           [`PRF_NUM_ENTRIES-1:0]              to_free_vector; //entries to free signal from RAT
    logic           [`N-1:0][`XLEN-1:0]                 reg1_val;     // value corresponding to the inputted phys_reg1 index
    logic           [`N-1:0][`XLEN-1:0]                 reg2_val;
    logic           [`N-1:0]                            reg1_ready;
    logic           [`N-1:0]                            reg2_ready;

    //correct values
    logic    [`N-1:0][`XLEN-1:0]                        correct_reg1_val;
    logic    [`N-1:0][`XLEN-1:0]                        correct_reg2_val;
    logic    [`N-1:0]                                   correct_reg1_ready;
    logic    [`N-1:0]                                   correct_reg2_ready;

    prf p(.clock, .reset, .phys_reg1, .phys_reg2, .cdb_in, .to_free_vector, .reg1_val, .reg2_val, .reg1_ready, .reg2_ready);

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

    task check_output;
        for(int i = 0; i < `N; ++i) begin
            if(!((correct_reg1_val[i] == reg1_val[i]) && (correct_reg2_val[i] == reg2_val[i])
                && (correct_reg1_ready[i] == reg1_ready[i]) && (correct_reg2_ready[i] == reg2_ready[i]))) begin
                finish_assert(0);
            end
        end
    endtask

    initial begin
		clock = 0;
        $monitor("reg1_val:         %d %d %d %d | reg1_ready:         %d %d %d %d | reg2_val:         %d %d %d %d | reg2_ready:         %d %d %d %d\ncorrect_reg1_val: %d %d %d %d | correct_reg1_ready: %d %d %d %d | correct_reg2_val: %d %d %d %d | correct_reg2_ready: %d %d %d %d\n",
            reg1_val[0],reg1_val[1], reg1_val[2], reg1_val[3], 
            reg1_ready[0], reg1_ready[1], reg1_ready[2], reg1_ready[3],
            reg2_val[0], reg2_val[1], reg2_val[2], reg2_val[3],
            reg2_ready[0], reg2_ready[1], reg2_ready[2], reg2_ready[3],
            correct_reg1_val[0], correct_reg1_val[1], correct_reg1_val[2], correct_reg1_val[3],
            correct_reg1_ready[0], correct_reg1_ready[1], correct_reg1_ready[2], correct_reg1_ready[3],
            correct_reg2_val[0], correct_reg2_val[1], correct_reg2_val[2], correct_reg2_val[3],
            correct_reg2_ready[0], correct_reg2_ready[1], correct_reg2_ready[2], correct_reg2_ready[3]);
            
        for(int i = 0; i < `N; i++)begin
            correct_reg1_ready[i]  = `FALSE;
            correct_reg2_ready[i]  = `FALSE;
        end

        @(negedge clock);
        reset = 1;
            //**************************** ADD TESTS ********************************//

        @(negedge clock); ///////TEST CASE FOR invalid entries///////////
        reset = 0;

        to_free_vector = 0;

        for(int i = 0; i < `N; i++) begin //all entries dead
            cdb_in[i].valid = `FALSE;
        end
        for(int i = 0; i < `N; i++)begin
            phys_reg1[i] = i;
            phys_reg2[i] = i + `N; //will maybe break if PRF size is smaller then 2N
        end

        for(int i = 0; i < `N; i++)begin
            correct_reg1_val[i] = i;
            correct_reg2_val[i] = i + `N; //will maybe break if PRF size is smaller then 2N
        end
        #1;

        check_output();
        @(negedge clock); ///////TEST CASE FOR MODIFYING AN ENTRY///////////
        ////CDB DECLARATIONS
        cdb_in[`N-1].valid = `TRUE;
        cdb_in[`N-1].value_valid = `TRUE;
        cdb_in[`N-1].dest_prf = `N-1;
        cdb_in[`N-1].rob_entry = `N-1;
        cdb_in[`N-1].value = 632464;

        correct_reg1_ready[`N-1] = `TRUE;
        correct_reg1_val[`N-1] = 632464;
        #1;
        check_output();

        @(negedge clock);
        cdb_in[`N-1].valid = `FALSE;

        //setting correct value for changed rob entry
        correct_reg1_val[`N-1] = 632464;
        correct_reg1_ready[`N-1] = `TRUE;

        #1;
        check_output();

        to_free_vector[`N-1] = `TRUE;
        @(negedge clock);

        correct_reg1_val[`N-1] = `N-1;
        correct_reg1_ready = `FALSE;
        #1;
        check_output();

        @(negedge clock);

        cdb_in[0].valid = `TRUE;
        cdb_in[0].value_valid = `TRUE;
        cdb_in[0].dest_prf = 0;
        cdb_in[0].rob_entry = 0;
        cdb_in[0].value = 1254;

        cdb_in[`N-1].valid = `TRUE;
        cdb_in[`N-1].value_valid = `TRUE;
        cdb_in[`N-1].dest_prf = `N-1;
        cdb_in[`N-1].rob_entry = `N-1;
        cdb_in[`N-1].value_valid = `TRUE;
        cdb_in[`N-1].value = 4321;

        correct_reg1_val[0] = 1254;
        correct_reg1_ready[0] = `TRUE;

        correct_reg1_val[`N-1] = 4321;
        correct_reg1_ready[`N-1] = `TRUE;

        #1
        check_output();

        @(negedge clock);

        cdb_in[0].valid = `TRUE;
        cdb_in[0].value_valid = `TRUE;
        cdb_in[0].dest_prf = `N;
        cdb_in[0].rob_entry = `N;
        cdb_in[0].value = 1011;

        correct_reg2_val[0] = 1011;
        correct_reg2_ready[0] = `TRUE;

        #1
        check_output();

        $display("\n***PASSED***\n\n");
		$finish;
    end



endmodule