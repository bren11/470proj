module  testbench ;
    logic clock;

    IF_ID_PACKET [`N-1:0]     if_packet;
	
	ALU_OPA_SELECT 	[`N-1:0]  						opa_select;
	ALU_OPB_SELECT 	[`N-1:0]  						opb_select;
    FUNC_UNIT_TYPE 	[`N-1:0]  						func_unit;
	ALU_FUNC       	[`N-1:0]  						alu_func;
	logic 			[`N-1:0]       					cond_branch, uncond_branch;
	logic 			[`N-1:0]           				csr_op;   
	             			           									
	logic 			[`N-1:0]           				halt;     
	logic 			[`N-1:0]           				illegal;    
	logic 			[`N-1:0]           				valid_inst;

    ALU_OPA_SELECT 	[`N-1:0]  						correct_opa_select;
	ALU_OPB_SELECT 	[`N-1:0]  						correct_opb_select;
    FUNC_UNIT_TYPE 	[`N-1:0]  						correct_func_unit;
	ALU_FUNC       	[`N-1:0]  						correct_alu_func;
	logic 			[`N-1:0]       					correct_cond_branch, correct_uncond_branch;
	logic 			[`N-1:0]           				correct_csr_op;   
	             			           									
	logic 			[`N-1:0]           				correct_halt;     
	logic 			[`N-1:0]           				correct_illegal;   
	logic 			[`N-1:0]           				correct_valid_inst;

    decoder dec(.if_packet, .opa_select, .opb_select, .func_unit, .alu_func,
                .cond_branch, .uncond_branch, .csr_op, .halt, .illegal, .valid_inst);

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

    /*
    task check_output;
        if(!(correct_no_free_prf == no_free_prf)) begin
            for(int i = 0; i < `N; ++i) begin
                if(!((correct_phys_reg1[i] == phys_reg1[i]) && (correct_phys_reg2[i] == phys_reg2[i]))) begin
                    finish_assert(0);
                end
            end
        end
    endtask
    */

    initial begin
		clock = 0;
        $monitor("opa_select:         %s %s %s %s | opb_select:         %s %s %s %s | func_unit:         %s %s %s %s | alu_func:         %s %s %s %s | cond_branch:         %b %b %b %b | uncond_branch:         %b %b %b %b | csr_op:         %b %b %b %b | halt:         %b %b %b %b | illegal:         %b %b %b %b | valid_inst:         %b %b %b %b\ncorrect_opa_select: %s %s %s %s | correct_opb_select: %s %s %s %s | correct_func_unit: %s %s %s %s | correct_alu_func: %s %s %s %s | correct_cond_branch: %b %b %b %b | correct_uncond_branch: %b %b %b %b | correct_csr_op: %b %b %b %b | correct_halt: %b %b %b %b | correct_illegal: %b %b %b %b | correct_valid_inst: %b %b %b %b",
            opa_select[0], opa_select[1], opa_select[2], opa_select[3],
            opb_select[0], opb_select[1], opb_select[2], opb_select[3],
            func_unit[0], func_unit[1], func_unit[2], func_unit[3],
            alu_func[0], alu_func[1], alu_func[2], alu_func[3],
            cond_branch[0], cond_branch[1], cond_branch[2], cond_branch[3],
            uncond_branch[0], uncond_branch[1], uncond_branch[2], uncond_branch[3],
            csr_op[0], csr_op[1], csr_op[2], csr_op[3],
            halt[0], halt[1], halt[2], halt[3],
            illegal[0], illegal[1], illegal[2], illegal[3],
            valid_inst[0], valid_inst[1], valid_inst[2], valid_inst[3],

            correct_opa_select[0], correct_opa_select[1], correct_opa_select[2], correct_opa_select[3],
            correct_opb_select[0], correct_opb_select[1], correct_opb_select[2], correct_opb_select[3],
            correct_func_unit[0], correct_func_unit[1], correct_func_unit[2], correct_func_unit[3],
            correct_alu_func[0], correct_alu_func[1], correct_alu_func[2], correct_alu_func[3],
            correct_cond_branch[0], correct_cond_branch[1], correct_cond_branch[2], correct_cond_branch[3],
            correct_uncond_branch[0], correct_uncond_branch[1], correct_uncond_branch[2], correct_uncond_branch[3],
            correct_csr_op[0], correct_csr_op[1], correct_csr_op[2], correct_csr_op[3],
            correct_halt[0], correct_halt[1], correct_halt[2], correct_halt[3],
            correct_illegal[0], correct_illegal[1], correct_illegal[2], correct_illegal[3],
            correct_valid_inst[0], correct_valid_inst[1], correct_valid_inst[2], correct_valid_inst[3],
        );

        @(negedge clock);

            //**************************** ADD TESTS ********************************//

        if_packet[0].valid = `TRUE;
        if_packet[0].PC = 0;
        if_packet[0].NPC = 1;

        if_packet[0].inst = `RV32_ADDI;
        if_packet[0].inst.i.imm = 12'd10;
        if_packet[0].inst.i.rs1 = 5'd4;
        if_packet[0].inst.i.rd = 5'd10;

        @(negedge clock);

        if_packet[0].valid = `TRUE;
        if_packet[0].PC = 4;
        if_packet[0].NPC = 5;

        if_packet[0].inst = `RV32_LW;
        if_packet[0].inst.i.imm = 12'd100;
        if_packet[0].inst.i.rs1 = 5'd10;
        if_packet[0].inst.i.rd = 5'd11;

        @(negedge clock);

        if_packet[0].valid = `TRUE;
        if_packet[0].PC = 4;
        if_packet[0].NPC = 5;

        if_packet[0].inst = `RV32_BNE;
        if_packet[0].inst.b.of = 0;
        if_packet[0].inst.b.f = 0;
        if_packet[0].inst.b.s = 0;
        if_packet[0].inst.b.et = 4'd12;
        if_packet[0].inst.b.rs1 = 5'd10;
        if_packet[0].inst.b.rs2 = 5'd5;

        @(negedge clock);



        $display("\n***PASSED***\n\n");
        $finish;
    end



endmodule