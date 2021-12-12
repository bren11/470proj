module  testbench ;
    logic clock;
    logic reset;
    logic nuke;

    logic [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg1;
    logic [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg2;

    logic [`N-1:0][`REG_INDEX_BITS-1:0] arch_reg_dest;
    logic [`N-1:0]                      arch_reg_dest_valid;

    logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rrat_entries;
    logic [`PRF_NUM_ENTRIES-1:0] rrat_free_list;
    logic [`PRF_NUM_ENTRIES-1:0] free_vector_from_rrat;

    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg1;
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg2;
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] phys_reg_dest;
    logic [`PRF_NUM_ENTRIES-1:0] free_list;

    logic no_free_prf;

    //correct signals
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] correct_phys_reg1;
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] correct_phys_reg2;
    logic [`N-1:0][`PRF_NUM_INDEX_BITS-1:0] correct_phys_reg_dest;

    logic correct_no_free_prf;


    rat r(.clock, .nuke, .reset, .arch_reg1, .arch_reg2, .arch_reg_dest,
    .arch_reg_dest_valid, .rrat_entries, .rrat_free_list, .free_vector_from_rrat,
    .phys_reg1, .phys_reg2, .phys_reg_dest, .no_free_prf, .free_list_o(free_list));

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
        if(!(correct_no_free_prf == no_free_prf)) begin
            for(int i = 0; i < `N; ++i) begin
                if(!((correct_phys_reg1[i] == phys_reg1[i]) && (correct_phys_reg2[i] == phys_reg2[i]))) begin
                    finish_assert(0);
                end
            end
        end
    endtask

    initial begin
		clock = 0;
        $monitor("phys_reg1:         %d %d %d %d | phys_reg2:         %d %d %d %d | phys_reg_dest:         %d %d %d %d | no_free_prf:         %b | free_list: %b\ncorrect_phys_reg1: %d %d %d %d | correct_phys_reg2: %d %d %d %d | correct_phys_reg_dest: %d %d %d %d | correct_no_free_prf: %b\n",
            phys_reg1[0], phys_reg1[1], phys_reg1[2], phys_reg1[3], 
            phys_reg2[0], phys_reg2[1], phys_reg2[2], phys_reg2[3],
            phys_reg_dest[0], phys_reg_dest[1], phys_reg_dest[2], phys_reg_dest[3],
            no_free_prf,
            free_list,
            correct_phys_reg1[0], correct_phys_reg1[1], correct_phys_reg1[2], correct_phys_reg1[3], 
            correct_phys_reg2[0], correct_phys_reg2[1], correct_phys_reg2[2], correct_phys_reg2[3],
            correct_phys_reg_dest[0], correct_phys_reg_dest[1], correct_phys_reg_dest[2], correct_phys_reg_dest[3],
            correct_no_free_prf
        );
            

        
        for(int i = 0; i < `N; i++)begin
            arch_reg_dest_valid[i] = `FALSE;
            free_vector_from_rrat = 0;
            rrat_entries = 0;
            rrat_free_list = 0;
        end

        @(negedge clock);
        reset = 1;
        nuke = 0;
            //**************************** ADD TESTS ********************************//

        @(negedge clock); ///////TEST CASE FOR invalid entries///////////
        reset = 0;
        nuke = 0;
        @(negedge clock);
        $display("negedge");
        
        for(int i = 0; i < `N; ++i) begin
            arch_reg1[i] = 1;
            arch_reg2[i] = 2;

            arch_reg_dest_valid[i] = `FALSE;
            arch_reg_dest[i] = i;
        end
        @(negedge clock);
        $display("negedge");

        for(int i = 0; i < `N; ++i) begin
            arch_reg1[i] = 1;
            arch_reg2[i] = 2;

            arch_reg_dest_valid[i] = `TRUE;
            arch_reg_dest[i] = i;
        end
        @(negedge clock);
        $display("negedge");

        for(int i = 0; i < `N; ++i) begin
            arch_reg1[i] = 1;
            arch_reg2[i] = 2;

            arch_reg_dest_valid[i] = `FALSE;
            arch_reg_dest[i] = i;
        end
        @(negedge clock);
        $display("negedge");

        for(int i = 0; i < `N; ++i) begin
            arch_reg1[i] = 0;
            arch_reg2[i] = 3;

            arch_reg_dest_valid[i] = `FALSE;
            arch_reg_dest[i] = i;
        end
        @(negedge clock);
        $display("negedge");

        for(int i = 0; i < `N; ++i) begin
            arch_reg_dest_valid[i] = `TRUE;
        end
        for(int i = 0; i < 20; ++i) begin
            @(negedge clock);
            $display("negedge");
        end

        for(int i = 0; i < `N; ++i) begin
            arch_reg_dest_valid[i] = `FALSE;
        end
        free_vector_from_rrat[15] = `TRUE;
        free_vector_from_rrat[17] = `TRUE;
        free_vector_from_rrat[32] = `TRUE;

        @(negedge clock);
        $display("negedge");
        for(int i = 0; i < `N; ++i) begin
            arch_reg_dest_valid[i] = `TRUE;
        end
        @(negedge clock);
        $display("negedge");

        for(int i = 0; i < `N; ++i) begin
            arch_reg_dest_valid[i] = `FALSE;
        end

        nuke = 1;
        rrat_free_list = 64'd1217;
        for(int i = 0; i < `RAT_SIZE; ++i) begin
            rrat_entries[i] = i;
        end

        arch_reg1[`N-1] = 23;
        arch_reg2[`N-1] = 15;

        @(negedge clock);
        $display("negedge");
        nuke = 0;
        reset = 1;

        @(negedge clock);
        $display("negedge");

        reset = 0;

        arch_reg1[0] = 1;
        arch_reg2[0] = 1;

        arch_reg1[1] = 1;
        arch_reg2[1] = 1;

        arch_reg1[2] = 1;
        arch_reg2[2] = 1;

        arch_reg1[3] = 1;
        arch_reg2[3] = 1;

        arch_reg_dest[0] = 1;
        arch_reg_dest[1] = 1;
        arch_reg_dest[2] = 1;
        arch_reg_dest[3] = 1;

        arch_reg_dest_valid[0] = 1;
        arch_reg_dest_valid[1] = 1;
        arch_reg_dest_valid[2] = 1;
        arch_reg_dest_valid[3] = 1;


        @(negedge clock);
        $display("negedge");


        $display("\n***PASSED***\n\n");
        $finish;
    end



endmodule