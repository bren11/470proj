module adder_fu (
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

    assign out.dest_prf = cur_instr.dest_prf;
    assign out.rob_entry = cur_instr.rob_entry;
    assign out.branch_address = cur_instr.pc + 4;
    assign out.value_valid = cur_instr.dest_arf != 0;
    assign ready = ~out.valid;
    
    always_comb begin
        case(cur_instr.func_op_type)
            ALU_ADD:    out.value = cur_instr.op1_value   +   cur_instr.op2_value;
            ALU_SUB:    out.value = cur_instr.op1_value   -   cur_instr.op2_value;
            ALU_SLT:    out.value = signed_op1            <   signed_op2;
            ALU_SLTU:   out.value = cur_instr.op1_value   <   cur_instr.op2_value;
            ALU_AND:    out.value = cur_instr.op1_value   &   cur_instr.op2_value;
            ALU_OR:     out.value = cur_instr.op1_value   |   cur_instr.op2_value;
            ALU_XOR:    out.value = cur_instr.op1_value   ^   cur_instr.op2_value;
            ALU_SLL:    out.value = cur_instr.op1_value   <<  cur_instr.op2_value[4:0];
            ALU_SRL:    out.value = cur_instr.op1_value   >>  cur_instr.op2_value[4:0];
            ALU_SRA:    out.value = signed_op1            >>> cur_instr.op2_value[4:0];
            default:    out.value = 0;
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