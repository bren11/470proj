module  testbench ;
    logic                           			clock;          
	logic                           			reset;             
	logic										nuke;
	CDB           [`N-1:0]    			        cdb_in;
	IF_ID_PACKET  [`N-1:0]    			        if_id_packet_in;

	logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] rrat_entries;
	logic 				[`PRF_NUM_ENTRIES-1:0] 	rrat_free_list;
	logic 				[`PRF_NUM_ENTRIES-1:0] 	free_vector_from_rrat;
	
	ID_EX_PACKET [`N-1:0]	   			        id_packet_out;

    id_stage id(.clock, .reset, .nuke, .cdb_in, .if_id_packet_in, .rrat_entries,
                .rrat_free_list, .free_vector_from_rrat, .id_packet_out);

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

    initial begin
		clock = 0;
        $monitor("NPC: %d %d %d %d | PC: %d %d %d %d | opa_value: %d %d %d %d | opb_value: %d %d %d %d | offset_valu: %d %d %d %d | opa_ready: %d %d %d %d | arch_reg_dest: %d %d %d %d | phys_reg_dest: %d %d %d %d | alu_func: %d %d %d %d | func_unit: %d %d %d %d | cond_branch: %d %d %d %d | uncond_branch: %d %d %d %d | halt: %d %d %d %d | illegal: %d %d %d %d | csr_op: %d %d %d %d | valid: %d %d %d %d",
            id_packet_out[0].NPC, id_packet_out[1].NPC, id_packet_out[2].NPC, id_packet_out[3].NPC,
            id_packet_out[0].PC, id_packet_out[1].PC, id_packet_out[2].PC, id_packet_out[3].PC,
            id_packet_out[0].opa_value, id_packet_out[1].opa_value, id_packet_out[2].opa_value, id_packet_out[3].opa_value,
            id_packet_out[0].opb_value, id_packet_out[1].opb_value, id_packet_out[2].opb_value, id_packet_out[3].opb_value,
            id_packet_out[0].offset_value, id_packet_out[1].offset_value, id_packet_out[2].offset_value, id_packet_out[3].offset_value,
            id_packet_out[0].opa_ready, id_packet_out[1].opa_ready, id_packet_out[2].opa_ready, id_packet_out[3].opa_ready,
            id_packet_out[0].arch_reg_dest, id_packet_out[1].arch_reg_dest, id_packet_out[2].arch_reg_dest, id_packet_out[3].arch_reg_dest,
            id_packet_out[0].phys_reg_dest, id_packet_out[1].phys_reg_dest, id_packet_out[2].phys_reg_dest, id_packet_out[3].phys_reg_dest,
            id_packet_out[0].alu_func, id_packet_out[1].alu_func, id_packet_out[2].alu_func, id_packet_out[3].alu_func,
            id_packet_out[0].func_unit, id_packet_out[1].func_unit, id_packet_out[2].func_unit, id_packet_out[3].func_unit,
            id_packet_out[0].cond_branch, id_packet_out[1].cond_branch, id_packet_out[2].cond_branch, id_packet_out[3].cond_branch,
            id_packet_out[0].uncond_branch,id_packet_out[1].uncond_branch, id_packet_out[2].uncond_branch, id_packet_out[3].uncond_branch,
            id_packet_out[0].halt, id_packet_out[1].halt, id_packet_out[2].halt, id_packet_out[3].halt,
            id_packet_out[0].illegal, id_packet_out[1].illegal, id_packet_out[2].illegal, id_packet_out[3].illegal,
            id_packet_out[0].csr_op, id_packet_out[1].csr_op, id_packet_out[2].csr_op, id_packet_out[3].csr_op,
            id_packet_out[0].valid, id_packet_out[1].valid, id_packet_out[2].valid, id_packet_out[3].valid
        );

        @(negedge clock);//setup
        reset = 1;
        nuke = 0;
        rrat_free_list = ~(0);
        rrat_entries = 0;
        free_vector_from_rrat = 0;
        if_id_packet_in = 0;
        for(int i = 0; i < `N; i++)begin
            cdb_in[i].valid = `FALSE;
        end
            //**************************** ADD TESTS ********************************//

        @(negedge clock);
        reset = 0;

        for(int i = 0; i < `N; ++i) begin
            if_id_packet_in[i].valid = `TRUE;
            if_id_packet_in[i].inst = 32'h0;
        end
        @(negedge clock)

        $display("\n***PASSED***\n\n");
        $finish;
    end



endmodule