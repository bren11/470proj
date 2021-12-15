`timescale 1ns/100ps


//implements a gselect branch predictor
module local_branch_predictor(
input clock, reset, branch_mispredict,
input   logic [`N-1:0][`XLEN-1:0]           PC,
input   BRANCH_PREDICTION_PACKET[`N-1:0]      branch_prediction_resolves,
input   ID_SPEC_HISTORY_UPDATE [`N-1:0]      id_spec_history_packet,

output  logic [`N-1:0]            taken,
output  [`N-1:0][`BRANCH_PREDICTION_BITS-1:0]    global_history_out
);

    logic [`LOCAL_PREDICTOR_SIZE-1:0][1:0]   prediction_table;
    logic [`LOCAL_PREDICTOR_SIZE-1:0][1:0]   n_prediction_table;

    logic [`N-1:0][`BRANCH_PREDICTION_BITS-1:0]    bp_indicies;

    logic [`N-1:0][`LOCAL_PREDICTOR_BITS-1:0] index;

    for(genvar i = 0; i < `N; ++i) begin
        assign global_history_out[i] = 0;
    end

    // lookup and update the branch update info
    for(genvar n_i = 0; n_i < `N; ++n_i) begin
        assign bp_indicies[n_i] = branch_prediction_resolves[n_i].pc[`LOCAL_PREDICTOR_BITS+1:2];
        
        //get the taken predictions for the current pc's and histories
        assign taken[n_i] = prediction_table[bp_indicies[n_i]][1];
    end

    //update the table based on previous branch packets
    always_comb begin
        n_prediction_table = prediction_table;
        for(int n_i = 0; n_i < `N; ++n_i) begin

            index[n_i] = branch_prediction_resolves[n_i].pc[`BRANCH_PREDICTION_BITS+1:2];

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
    end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
            //Initialize the table to weakly not taken
            for(int i = 0; i <  `PREDICTION_TABLE_SIZE; ++i) begin
                prediction_table[i] <= `SD 2'd2;
            end
		end else begin
            prediction_table <= `SD n_prediction_table;
        end
	end

endmodule

//implements a gselect branch predictor
module localHist_branch_predictor(
input clock, reset, branch_mispredict,
input   logic [`N-1:0][`XLEN-1:0]           PC,
input   BRANCH_PREDICTION_PACKET[`N-1:0]      branch_prediction_resolves,
input   ID_SPEC_HISTORY_UPDATE [`N-1:0]      id_spec_history_packet,

output  logic [`N-1:0]            taken,
output  [`N-1:0][`BRANCH_PREDICTION_BITS-1:0]    global_history_out
);

    logic [`LOCAL_BHT_SIZE-1:0][`LOCAL_HISTORY_SIZE-1:0]    local_history;
    logic [`LOCAL_BHT_SIZE-1:0][`LOCAL_HISTORY_SIZE-1:0]    n_local_history;
    logic [`LOCAL_PHT_SIZE-1:0][1:0]   prediction_table;
    logic [`LOCAL_PHT_SIZE-1:0][1:0]   n_prediction_table;

    logic [`N-1:0][`BRANCH_PREDICTION_BITS-1:0]    bp_indicies;

    logic [`N-1:0][`LOCAL_HISTORY_SIZE-1:0] pht_index;

    for(genvar i = 0; i < `N; ++i) begin
        assign global_history_out[i] = local_history;
    end

    // lookup and update the branch update info
    for(genvar n_i = 0; n_i < `N; ++n_i) begin
        assign bp_indicies[n_i] = branch_prediction_resolves[n_i].pc[`LOCAL_HISTORY_SIZE+1:2];
        
        //get the taken predictions for the current pc's and histories
        assign taken[n_i] = prediction_table[bp_indicies[n_i]][1];
    end

    //update the table based on previous branch packets
    always_comb begin
        n_local_history = local_history;

        n_prediction_table = prediction_table;
        for(int n_i = 0; n_i < `N; ++n_i) begin

            pht_index[n_i] = local_history[branch_prediction_resolves[n_i].pc[`BRANCH_PREDICTION_BITS+1:2]];

            if(branch_prediction_resolves[n_i].valid) begin
                if(branch_prediction_resolves[n_i].taken) begin
                    if(n_prediction_table[pht_index[n_i]] < 2'd3) begin
                        n_prediction_table[pht_index[n_i]] += 2'd1;
                    end
                end else begin
                    if(n_prediction_table[pht_index[n_i]] > 2'd0) begin
                        n_prediction_table[pht_index[n_i]] -= 2'd1;
                    end
                end
                n_local_history[branch_prediction_resolves[n_i].pc[`BRANCH_PREDICTION_BITS+1:2]] = (local_history[branch_prediction_resolves[n_i].pc[`BRANCH_PREDICTION_BITS+1:2]] << 1) | branch_prediction_resolves[n_i].taken;
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
            local_history <= `SD 0;
		end else begin
            prediction_table <= `SD n_prediction_table;
            local_history <= `SD n_local_history;
        end
	end

endmodule