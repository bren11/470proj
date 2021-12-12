module branch_fu (
    input                   reset,
    input                   clock,

    input FUNC_UNIT_PACKET  input_instr,
    input                   sel,

    output FUNC_OUTPUT      out,
	output logic      		ready
);

    FUNC_UNIT_PACKET  cur_instr;

    wire signed [`XLEN-1:0] signed_op1, signed_op2;
    assign signed_op1 = cur_instr.op1_value;
	assign signed_op2 = cur_instr.op2_value;

    assign out.rob_entry = cur_instr.rob_entry;
    assign ready = ~out.valid;

    always_comb begin
		case(cur_instr.func_op_type)
			ALU_JAL: begin
                out.branch_address = cur_instr.pc + cur_instr.offset;
				out.value = cur_instr.pc + 4;
				out.dest_prf = cur_instr.dest_prf;
                out.value_valid = cur_instr.dest_arf != 0;
            end 
            ALU_JALR: begin
                out.branch_address = cur_instr.op1_value + cur_instr.offset;
                out.branch_address[1:0] = 2'b00;
				out.value = cur_instr.pc + 4;
				out.dest_prf = cur_instr.dest_prf;
                out.value_valid = cur_instr.dest_arf != 0;
            end 
            ALU_BEQ: begin
                out.branch_address = (cur_instr.op1_value == cur_instr.op2_value) ?
                    cur_instr.pc + cur_instr.offset : cur_instr.pc + 4;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end 
            ALU_BNE: begin
                out.branch_address = (~(cur_instr.op1_value == cur_instr.op2_value)) ?
                    cur_instr.pc + cur_instr.offset : cur_instr.pc + 4;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end 
            ALU_BLT: begin
                out.branch_address = (signed_op1 < signed_op2) ?
                    cur_instr.pc + cur_instr.offset : cur_instr.pc + 4;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end 
            ALU_BGE: begin
                out.branch_address = (signed_op1 >= signed_op2) ?
                    cur_instr.pc + cur_instr.offset : cur_instr.pc + 4;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end 
            ALU_BLTU: begin
                out.branch_address = (cur_instr.op1_value < cur_instr.op2_value) ?
                    cur_instr.pc + cur_instr.offset : cur_instr.pc + 4;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end 
            ALU_BGEU: begin
                out.branch_address = (cur_instr.op1_value >= cur_instr.op2_value) ?
                    cur_instr.pc + cur_instr.offset : cur_instr.pc + 4;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end 
            default: begin
                out.branch_address = 0;
				out.value = 0;
				out.dest_prf = 0;
                out.value_valid = `FALSE;
            end
		endcase
	end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            cur_instr <= `SD 0;
            out.valid <= `SD 1'b0;
        end else if (input_instr.valid) begin
            cur_instr <= `SD input_instr;
            out.valid <= `SD 1'b1;
        end else if (sel) begin
            out.valid <= `SD 1'b0;
        end
    end

endmodule