module mult_fu (
	input                   reset,
    input                   clock,

    input FUNC_UNIT_PACKET  input_instr,
    input                   sel,

    output FUNC_OUTPUT      out,
	output logic      		ready
);

	FUNC_UNIT_PACKET  cur_instr, n_cur_instr;

	logic [1:0] sign;
	logic m_reset, n_m_reset;
	wire m_done;
	logic m_start, n_m_start;
	logic [(2*`XLEN)-1:0] mult_out;

	logic n_out_valid, n_ready;

	assign m_start = ~ready;

	mult #(.XLEN(`XLEN), .NUM_STAGE(`MULT_STAGES)) multiplier(
		.clock(clock), 
		.reset(m_reset), 
		.start(m_start), 
		.sign(sign), 
		.mcand(cur_instr.op1_value),
		.mplier(cur_instr.op2_value), 
		.product(mult_out),
		.done(m_done)
	);

	assign out.dest_prf = cur_instr.dest_prf;
	assign out.rob_entry = cur_instr.rob_entry;
	assign out.branch_address = cur_instr.pc + 4;
    assign out.value_valid = cur_instr.dest_arf != 0;

	always_comb begin
		case(cur_instr.func_op_type)
			ALU_MUL: begin
				out.value = mult_out[`XLEN-1:0];
				sign = {cur_instr.op2_value[31], cur_instr.op1_value[31]};
			end ALU_MULH: begin
				out.value = mult_out[2*`XLEN-1:`XLEN];
				sign = {cur_instr.op2_value[31], cur_instr.op1_value[31]};
			end ALU_MULHSU: begin
				out.value = mult_out[2*`XLEN-1:`XLEN];
				sign = {1'b0, cur_instr.op1_value[31]};
			end ALU_MULHU: begin
				out.value = mult_out[2*`XLEN-1:`XLEN];
				sign = 2'b00;
			end default: begin
				out.value = 0;
				sign = 2'b00;
			end
		endcase
	end

	always_comb begin
		n_cur_instr = cur_instr;
		n_m_reset = `FALSE;
		n_ready = ready;
		n_out_valid = out.valid;

        if (sel) begin
            n_out_valid = `FALSE;
			n_ready = `TRUE;
        end else if (m_done && ~ready && ~m_reset) begin
            n_out_valid = `TRUE;
        end
		if (input_instr.valid) begin
            n_cur_instr = input_instr;
			n_m_reset = `TRUE;
			n_ready = `FALSE;
		end
	end

	always_ff @(posedge clock) begin
        if (reset) begin
			cur_instr <= `SD 0;
            out.valid <= `SD `FALSE;
			m_reset <= `SD `TRUE;
			ready <= `SD `TRUE;
        end else begin
			cur_instr <= `SD n_cur_instr;
            out.valid <= `SD n_out_valid;
			m_reset <= `SD n_m_reset;
			ready <= `SD n_ready;
		end
    end

endmodule
`ifndef __MULT_SV__
`define __MULT_SV__
module mult #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
				input clock, reset,
				input start,
				input [1:0] sign,
				input [XLEN-1:0] mcand, mplier,
				
				output [(2*XLEN)-1:0] product,
				output done
			);
	logic [(2*XLEN)-1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_products;
	logic [NUM_STAGE:0] internal_dones;

	assign mcand_in  = sign[0] ? {{XLEN{mcand[XLEN-1]}}, mcand}   : {{XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{XLEN{mplier[XLEN-1]}}, mplier} : {{XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 'h0;
	assign internal_dones[0]    = start;

	assign done    = internal_dones[NUM_STAGE];
	assign product = internal_products[NUM_STAGE];

	genvar i;
	for (i = 0; i < NUM_STAGE; ++i) begin : mstage
		mult_stage #(.XLEN(XLEN), .NUM_STAGE(NUM_STAGE)) ms (
			.clock(clock),
			.reset(reset),
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),
			.product_out(internal_products[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end
endmodule

module mult_stage #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
					input clock, reset, start,
					input [(2*XLEN)-1:0] mplier_in, mcand_in,
					input [(2*XLEN)-1:0] product_in,

					output logic done,
					output logic [(2*XLEN)-1:0] mplier_out, mcand_out,
					output logic [(2*XLEN)-1:0] product_out
				);

	parameter NUM_BITS = (2*XLEN)/NUM_STAGE;

	logic [(2*XLEN)-1:0] prod_in_reg, partial_prod, next_partial_product, partial_prod_unsigned;
	logic [(2*XLEN)-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[(NUM_BITS-1):0] * mcand_in;

	assign next_mplier = {{(NUM_BITS){1'b0}},mplier_in[2*XLEN-1:(NUM_BITS)]};
	assign next_mcand  = {mcand_in[(2*XLEN-1-NUM_BITS):0],{(NUM_BITS){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= `SD product_in;
		partial_prod     <= `SD next_partial_product;
		mplier_out       <= `SD next_mplier;
		mcand_out        <= `SD next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done     <= `SD 1'b0;
		end else begin
			done     <= `SD start;
		end
	end

endmodule
`endif //__MULT_SV__
