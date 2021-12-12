`timescale 1ns/100ps


//implements a gselect branch predictor
module branch_predictor(
input clock, reset, branch_mispredict,
input   logic [`N-1:0][`XLEN-1:0]           PC,
input   BRANCH_PREDICTION_PACKET[`N-1:0]      branch_prediction_resolves,
input   ID_SPEC_HISTORY_UPDATE [`N-1:0]      id_spec_history_packet,

output  logic [`N-1:0]            taken,
output  [`N-1:0][`BRANCH_PREDICTION_BITS-1:0]    global_history_out
);

    logic [`GLOBAL_HISTORY_SIZE-1:0]    global_history;
    logic [`GLOBAL_HISTORY_SIZE-1:0]    n_global_history;
    logic [`PREDICTION_TABLE_SIZE-1:0][1:0]   prediction_table;
    logic [`PREDICTION_TABLE_SIZE-1:0][1:0]   n_prediction_table;

    logic [`N-1:0][`BRANCH_PREDICTION_BITS-1:0]    bp_indicies;

    logic [`GLOBAL_HISTORY_SIZE-1:0] corrected_history; //history if there is a mispredict

    logic [`N-1:0][`BRANCH_PREDICTION_BITS-1:0] index;

    for(genvar i = 0; i < `N; ++i) begin
        assign global_history_out[i] = global_history;
    end

    always_comb begin
        corrected_history = 0;
        for (int i = 0; i < `N; ++i) begin
            if(branch_prediction_resolves[i].valid) begin
                corrected_history = branch_prediction_resolves[i].bp_indicies << 1;
                corrected_history[0] = branch_prediction_resolves[i].taken;
            end
        end
    end

    // lookup and update the branch update info
    for(genvar n_i = 0; n_i < `N; ++n_i) begin
        assign bp_indicies[n_i] = global_history ^ PC[n_i][`BRANCH_PREDICTION_PC_BITS + 1:2];
        
        //get the taken predictions for the current pc's and histories
        assign taken[n_i] = prediction_table[bp_indicies[n_i]][1];
    end

    //update the table based on previous branch packets
    always_comb begin
        n_global_history = global_history;

        n_prediction_table = prediction_table;
        for(int n_i = 0; n_i < `N; ++n_i) begin

            index[n_i] = branch_prediction_resolves[n_i].pc ^ branch_prediction_resolves[n_i].bp_indicies;

            if(branch_prediction_resolves[n_i].valid) begin
                if(branch_prediction_resolves[n_i].taken) begin
                    if(n_prediction_table[index[n_i]] < 2'd3) begin
                        n_prediction_table[index[n_i]] += 2'd1;
                    end
                end else begin
                    if(n_prediction_table[index[n_i]] > 2'd0) begin
                        n_prediction_table[index[n_i]] -= 2'd1;
                    end
                end
            end
        end

        //update the history based on the incoming branch resolves
        for(int n_i = 0; n_i < `N; ++n_i) begin
            if(id_spec_history_packet[n_i].valid) begin
                n_global_history = global_history << 1;
                n_global_history[0] = id_spec_history_packet[n_i].taken;
            end 
        end
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
            //Initialize the table to weakly not taken
            for(int i = 0; i <  `PREDICTION_TABLE_SIZE; ++i) begin
                prediction_table[i] <= `SD 2'd2;
            end
            global_history <= `SD ~(0);
		end else if (branch_mispredict) begin
            prediction_table <= `SD n_prediction_table;
            global_history <= `SD corrected_history;
        end else begin
            prediction_table <= `SD n_prediction_table;
            global_history <= `SD n_global_history;
        end
	end

endmodule