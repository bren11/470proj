module rob(
    input                                           reset,                  // Input to set all stations and functional packets to invalid
    input                                           clock,
    input  ROB_ENTRY        [`N-1:0]                dispatched_entries,    // Instructions being sent to the reservation station
    input  CDB              [`N-1:0]                cdb_input,
    input   [`N-1:0][`LSQ_INDEX_BITS-1:0]           n_lsq_index,

    output logic                                    branch_mispredict,
    output logic [`N-1:0][`ROB_NUM_INDEX_BITS-1:0]  next_entries_index,
    output logic [`XLEN-1:0]                          corrected_branch_address,
    output STORES_READY [`N-1:0]                    stores_ready,
    output logic                                    rob_full,
    output logic                                    halt,

    output BRANCH_PREDICTION_PACKET[`N-1:0]         branch_pred_packet,
    output ROB_COMMIT_PACKET [`N-1:0]               rob_commit,

	// Testbench outputs
	output ROB_ENTRY [`ROB_NUM_ENTRIES-1:0] 		entries,
	output logic [`ROB_NUM_INDEX_BITS-1:0] 			head_index,

	// Visual debugger outputs
	output logic [`ROB_NUM_INDEX_BITS-1:0] 			tail_index
);

    logic n_halt;
    ROB_ENTRY [`ROB_NUM_ENTRIES-1:0] n_entries;
    logic [`ROB_NUM_INDEX_BITS-1:0] n_head_index, n_tail_index;
    STORES_READY [`N-1:0] n_stores_ready;

    for (genvar n_i = 0; n_i < `N; n_i++) begin
        assign next_entries_index[n_i] = ((tail_index + n_i) >= `ROB_NUM_ENTRIES) ?
                                          (tail_index + n_i) - `ROB_NUM_ENTRIES :
                                          (tail_index + n_i);
    end

    //currently only not full if there are N open spots
    //SET FULL FLAG//
    always_comb begin
        if(head_index > tail_index || (head_index == tail_index && entries[head_index].valid)) begin
            rob_full = (head_index - tail_index) < `N;
        end else begin
            rob_full = (`ROB_NUM_ENTRIES - (tail_index - head_index)) < `N;
        end
    end
    /////////////////

    wire [`N-1:0] dispatched_valid;

    for (genvar i = 0; i < `N; i++) begin
        assign dispatched_valid[i] = dispatched_entries[i].valid;
    end

    always_comb begin
        //TODO: check if this is slow or not
        n_tail_index = tail_index;
		for (int i = 0; i < `N; ++i) begin
			if (dispatched_valid[i]) begin
                n_tail_index = ((n_tail_index + 1) >= `ROB_NUM_ENTRIES) ?
                                (n_tail_index + 1 - `ROB_NUM_ENTRIES) :
                                (n_tail_index + 1);
            end
		end
    end
    //////////////

    always_comb begin

        int index;
        //CDB LISTEN & DISPATCH//

        // Fix latch
        corrected_branch_address = 0;

        n_entries = entries;
        for(int ds_dis_i = 0; (~rob_full) && (ds_dis_i < `N); ++ds_dis_i) begin
            n_entries[next_entries_index[ds_dis_i]] = dispatched_entries[ds_dis_i];
            n_entries[next_entries_index[ds_dis_i]].lsq_index = n_lsq_index[ds_dis_i];
        end

        for(int cdb_i = 0; cdb_i < `N; ++cdb_i) begin
            if(cdb_input[cdb_i].valid) begin
                n_entries[cdb_input[cdb_i].rob_entry].executed = `TRUE;
                n_entries[cdb_input[cdb_i].rob_entry].calculated_branch_address = cdb_input[cdb_i].branch_address;
            end
        end

        //COMMIT//
        n_head_index = head_index;
        branch_mispredict = `FALSE;
        branch_pred_packet = 0;
        rob_commit = 0;
        n_halt = halt;
        for(int n_i = 0; n_i < `N; ++n_i) begin

            index = (head_index + n_i >= `ROB_NUM_ENTRIES) ?
                        head_index + n_i - `ROB_NUM_ENTRIES :
                        head_index + n_i;
            if (index == tail_index && ~entries[index].valid) break;
            if(entries[index].executed) begin
                rob_commit[n_i] = {
                    `TRUE,
                    entries[index].dest_arf,
                    entries[index].dest_prf
                };
                n_entries[index].valid = `FALSE;

                if (entries[index].halt) begin
                    n_halt = `TRUE;
                    n_entries[index].executed = `FALSE;
                    break;
                end

                n_head_index = ((n_head_index + 1) >= `ROB_NUM_ENTRIES) ? 0 : n_head_index + 1;

                case (entries[index].func_op_type)
                    ALU_JAL, ALU_JALR, ALU_BEQ, ALU_BNE,
                    ALU_BLT, ALU_BGE, ALU_BLTU, ALU_BGEU: begin
                        //FILL IN THE BRANCH PACKET TO UPDATE BTB AND PREDICTOR
                        branch_pred_packet[n_i].valid = `TRUE;
                        branch_pred_packet[n_i].branch_address = entries[index].calculated_branch_address;
                        branch_pred_packet[n_i].pc = entries[index].pc;
                        branch_pred_packet[n_i].bp_indicies = entries[index].bp_indicies;

                        branch_pred_packet[n_i].taken = (entries[index].calculated_branch_address != (entries[index].pc+4));
                        
                        if(entries[index].calculated_branch_address == 
                            entries[index].predicted_branch_address) begin
                            branch_pred_packet[n_i].correct = `TRUE;

                        end else begin
                            branch_pred_packet[n_i].correct = `FALSE;
                            corrected_branch_address = entries[index].calculated_branch_address;
                            branch_mispredict = `TRUE;
                            break;
                        end
                        ///
                    end

                endcase
            end else begin
                break;
            end
        end

        n_stores_ready = 0;
        for(int n_i = 0; n_i < `N; ++n_i) begin
            index = (n_head_index + n_i >= `ROB_NUM_ENTRIES) ?
                        n_head_index + n_i - `ROB_NUM_ENTRIES :
                        n_head_index + n_i;
            if ((index == n_tail_index && ~n_entries[index].valid) || n_entries[index].halt) break;
            case (n_entries[index].func_op_type)
                ALU_JAL, ALU_JALR, ALU_BEQ, ALU_BNE,
                ALU_BLT, ALU_BGE, ALU_BLTU, ALU_BGEU: begin 
                    if(!n_entries[index].executed || (n_entries[index].executed && (n_entries[index].calculated_branch_address != n_entries[index].predicted_branch_address))) begin
                        break;
                    end
                end
                ALU_SB, ALU_SH, ALU_SW: begin 
                    n_stores_ready[n_i] = {
                        `TRUE,
                        n_entries[index].lsq_index
                    };
                end
                ALU_LB, ALU_LH, ALU_LW,
                ALU_LBU, ALU_LHU: begin 
                    if (!n_entries[index].executed) begin
                        break;
                    end
                end
            endcase
        end
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || branch_mispredict) begin
            entries <= `SD 0;
            head_index <= `SD 0;
            tail_index <= `SD 0;
            halt <= `SD `FALSE;
            stores_ready <= `SD 0;
		end else begin
            entries <= `SD n_entries;
            head_index <= `SD n_head_index;
            tail_index <= `SD n_tail_index;
            halt <= `SD n_halt;
            stores_ready <= `SD n_stores_ready;
        end
	end

endmodule
