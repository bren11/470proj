module mem_fu_old (
    input                   reset,
    input                   clock,

    input FUNC_UNIT_PACKET  input_instr,
    input                   sel,

    output FUNC_OUTPUT      out,
	output logic      		ready
);

    FUNC_UNIT_PACKET  cur_instr;

    assign out.dest_prf = 0;
    assign out.value = cur_instr.op1_value + cur_instr.op2_value;
    assign out.rob_entry = cur_instr.rob_entry;
    assign out.branch_address = cur_instr.pc + 4;
    assign out.value_valid = cur_instr.dest_arf != 0;
    assign ready = ~out.valid;
    
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