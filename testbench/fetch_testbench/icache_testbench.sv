/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  icache_testbench.sv                                 //
//                                                                     //
//  Description :  This is the icahce controller and cachemem tb       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps

module testbench;

    logic reset, clock;

    /* DUT Inputs */
    ICACHE_DMAP_ADDR                                    Imem2proc_w_addr;
    logic               [`ICACHE_DATA_BITS-1:0]         Imem2proc_w_data;
    logic                                               Imem2proc_v;
    ICACHE_DMAP_ADDR    [`N-1:0]                        proc2Icache_rd_addrs;
    
    /* DUT Outputs */
    logic               [`N-1:0][`ICACHE_DATA_BITS-1:0] Icache_rd_data;
    logic               [`N-1:0]                        Icache_rd_hits;


    /* Testing instruction cache */
    icache DUT (
        .clock, .reset,
        /* Write Requests */
        .Imem2proc_w_addr,
        .Imem2proc_w_data,
        .Imem2proc_v,
        /* Read Requests */
        .proc2Icache_rd_addrs,
        .Icache_rd_data,
        .Icache_rd_hits
    ); 

    /* Clock Generator */
    always begin
		#10;
		clock = ~clock;
	end

    /* Debug Prints */
    task display_busses;
        /* Display Current write */
        $display("Write           :       VALID:%b | TAG:%h | INDEX:%h | OFFSET:%h | DATA:%h",
            Imem2proc_v, Imem2proc_w_addr.tag, Imem2proc_w_addr.index, Imem2proc_w_addr.offset, Imem2proc_w_data);

        /* Display Read Results */
		for (int i = 0; i < `N; i++) begin
            $display("Read %d:         HIT:%b | TAG:%h | INDEX:%h | OFFSET:%h | DATA:%h",
                i, Icache_rd_hits[i], proc2Icache_rd_addrs[i].tag, proc2Icache_rd_addrs[i].index, proc2Icache_rd_addrs[i].offset, Icache_rd_data[i]);
        end
        
        $display("");
	endtask

    /* Begin Test */
    initial begin
        
        $display("\n***START***\n");

        /* Reset Cache */
		reset = 1;
		clock = 0;
		@(negedge clock);
        
        reset = 0;

        $display("Check reads with all invalidated");
        Imem2proc_v = 0;
        proc2Icache_rd_addrs = 0;

        @(posedge clock)
        display_busses();
        
        @(negedge clock)
        $display("First Write and Single Read in the same cycle (Forwarding)");
        Imem2proc_v = 1;
        Imem2proc_w_addr.tag    =  25'hAA;
        Imem2proc_w_addr.index  =  4'hA;
        Imem2proc_w_addr.offset =  3'b001;
        Imem2proc_w_data = 64'h1000;
        proc2Icache_rd_addrs[0] = Imem2proc_w_addr;

        @(posedge clock) 
        display_busses();
        t1_check: assert (Icache_rd_hits[0] && Icache_rd_data[0] === 64'h1000)
            else begin $error("Should hit in the same cycle"); $finish; end
    
        @(negedge clock)
        $display("First Write and Single Read in the next cycle (Latched)");
        Imem2proc_v = 0;
        proc2Icache_rd_addrs[0] = Imem2proc_w_addr;

        @(posedge clock)
        t2_check: begin
            for (int i = 0; i < 1; ++i) begin    
                assert (Icache_rd_hits[i] && Icache_rd_data[i] === 64'h1000)
                    else begin 
                        $error("Should all be a hit"); 
                        $finish; 
                    end
            end
        end
        display_busses();

        @(negedge clock)
        $display("First Write and Multiple Reads in the next cycle (Latched)");
        Imem2proc_v = 0;
        for (int i = 0; i < `N; ++i) begin
            proc2Icache_rd_addrs[i] = Imem2proc_w_addr;
        end
        
        @(posedge clock) 
        t3_check: begin
            for (int i = 0; i < `N; ++i) begin    
                assert (Icache_rd_hits[i] && Icache_rd_data[i] === 64'h1000)
                    else begin 
                        $error("Should all be a hit"); 
                        $finish; 
                    end
            end
        end
        display_busses();

        @(negedge clock)
        $display("Second Write and Multiple Reads in the next cycle (Forwarded)");
        Imem2proc_v = 1;
        Imem2proc_w_addr.tag    =  25'hAA;
        Imem2proc_w_addr.index  =  4'hB;
        Imem2proc_w_addr.offset =  3'b010;
        Imem2proc_w_data = 64'h2000;
        for (int i = 0; i < `N-2; ++i) begin
            proc2Icache_rd_addrs[i] = Imem2proc_w_addr;
        end
        proc2Icache_rd_addrs[`N-1].tag    = 25'hAA;
        proc2Icache_rd_addrs[`N-1].index  = 4'hA;
        proc2Icache_rd_addrs[`N-1].offset = 3'b111;

        proc2Icache_rd_addrs[`N-2].tag    = 25'hCC;
        proc2Icache_rd_addrs[`N-2].index  = 4'hA;
        proc2Icache_rd_addrs[`N-2].offset = 3'b111;

        @(posedge clock) 
        display_busses();

        @(negedge clock)
        $display("Third Write overwriting (Forwarded)");
        Imem2proc_v = 1;
        Imem2proc_w_addr.tag    =  25'hBB;
        Imem2proc_w_addr.index  =  4'hA;
        Imem2proc_w_addr.offset =  3'b000;
        Imem2proc_w_data = 64'h3000;
        for (int i = 0; i < `N-2; ++i) begin
            proc2Icache_rd_addrs[i] = Imem2proc_w_addr;
        end
        proc2Icache_rd_addrs[`N-1].tag    = 25'hBB;
        proc2Icache_rd_addrs[`N-1].index  = 4'hB;
        proc2Icache_rd_addrs[`N-1].offset = 3'b010;

        proc2Icache_rd_addrs[`N-2].tag    = 25'hAA;
        proc2Icache_rd_addrs[`N-2].index  = 4'hA;
        proc2Icache_rd_addrs[`N-2].offset = 3'b101;

        @(posedge clock) 
        display_busses();

        @(negedge clock)
        $display("Third Write overwriting first (Latched) ");
        Imem2proc_v = 0;
        for (int i = 0; i < `N-2; ++i) begin
            proc2Icache_rd_addrs[i] = Imem2proc_w_addr;
        end
        proc2Icache_rd_addrs[`N-1].tag    = 25'hBB;
        proc2Icache_rd_addrs[`N-1].index  = 4'hB;
        proc2Icache_rd_addrs[`N-1].offset = 3'b010;

        proc2Icache_rd_addrs[`N-2].tag    = 25'hAA;
        proc2Icache_rd_addrs[`N-2].index  = 4'hA;
        proc2Icache_rd_addrs[`N-2].offset = 3'b101;

        @(posedge clock) 
        display_busses();

		$display("\n***PASSED***\n");
		$finish;
	end
endmodule