`timescale 1ns/100ps
module my_priority_selector ( // Inputs
                    clock,
                    reset,
                    req,
                 
                    // Outputs
                    gnt,
                    gnt_bus,
                    empty
                );

  // synopsys template
    parameter REQS  = `N;
    parameter WIDTH = `RS_NUM_ENTRIES;

    input clock;
    input reset;
    input [WIDTH-1:0] req;
                 
    // Outputs
    output logic [WIDTH-1:0] gnt;
    output logic [REQS-1:0][WIDTH-1:0] gnt_bus;
    output logic empty;

    logic [WIDTH-1:0] req_tmp;
    logic [WIDTH-1:0] gnt_tmp;
    logic [REQS-1:0][WIDTH-1:0] bus_tmp;

    logic [10:0] cnt;

    priority_selector #(REQS, WIDTH) ps(.req(req_tmp), .gnt(gnt_tmp), .gnt_bus(bus_tmp), .empty);

    always_comb begin
        if (cnt == 0) begin
            req_tmp = req;
            gnt = gnt_tmp;
            gnt_bus = bus_tmp;
        end else begin
            req_tmp = (req << cnt) | (req >> (WIDTH - cnt));
            gnt = (gnt_tmp >> cnt) | (gnt_tmp << (WIDTH - cnt));
            for (int i = 0; i < REQS; i++) begin
                gnt_bus[i] = (bus_tmp[i] >> cnt) | (bus_tmp[i] << (WIDTH - cnt));
            end
        end
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            cnt <= 0;
        end else begin
            if (cnt == (WIDTH - 1)) begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

endmodule