/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  dcache_testbench.sv                                 //
//                                                                     //
//  Description :  This is the dcache controller and cachemem_rw tb    //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`define DEBUG

module testbench;

    logic clock, reset;

    /* Updates from memory bus */
    logic  [3:0]                mem2proc_response;     
    logic  [`MEM_DATA_BITS-1:0] mem2proc_data;
    logic  [3:0]                mem2proc_tag;    

    /* Store Requests */
    DCACHE_DMAP_ADDR      str_w_addr;     
    logic [`MEM_DATA_BITS-1:0]  str_w_data;
    MEM_SIZE              str_w_size;            // Size of store sent to memory
    logic                 str_v;

    /* Read Requests */
    DCACHE_DMAP_ADDR [`LSQ_NUM_LOADS-1:0]    proc2Dcache_rd_addrs;   // Load Target Address
    logic            [`LSQ_NUM_LOADS-1:0]    proc2Dcache_rd_v;       // Valid Load?

    /* Read Outputs */
    logic [`LSQ_NUM_LOADS-1:0][`MEM_DATA_BITS-1:0] Dcache_rd_data;        // value is memory[proc2Icache_addr]
    logic [`LSQ_NUM_LOADS-1:0]                     Dcache_rd_hits;        // when this is high
    logic                                          Dcache_str_accepted;   // when this is high

    /* Bus Requests */
    /* DUT Outputs */
	BUS_COMMAND				  					proc2mem_command;
	BUS_COMMAND				  					proc2mem_DUT_command;
	BUS_COMMAND				  					proc2mem_TB_command;

	logic 				[`XLEN-1:0]				proc2mem_addr;
	logic 				[`XLEN-1:0]				proc2mem_DUT_addr;
	logic 				[`XLEN-1:0]				proc2mem_TB_addr;

	logic 				[63:0] 					proc2mem_data;
	logic 				[63:0] 					proc2mem_DUT_data;
    logic 				[63:0] 					proc2mem_TB_data;
    

    MEM_SIZE                   proc2mem_size;
    MEM_SIZE                   proc2mem_DUT_size;
    MEM_SIZE                   proc2mem_TB_size;

    
	logic                      structural_hazard;
	logic					   MSHR_memory_hzd;


    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                          Helper Memory Functions                         //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

	 // Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal

	logic [`XLEN-1:0] temp;

	semaphore mem_busy;

	// Non-blocking task to send store to memory
	task automatic write_memory(input logic[`XLEN-1:0] addr, input logic[63:0] data, input MEM_SIZE size);
		logic [3:0] tag;
		fork 
		begin		
			tag = 4'b0;
			mem_busy.get(1); // acquire lock on memory bus
			while(tag == 0) begin // keep trying until we get a non-zero (valid) tag
				proc2mem_addr = addr; // store's address
				proc2mem_command = BUS_STORE; // store command
				proc2mem_data = data; // data input
				proc2mem_size = size; // size parameter (WORD or DOUBLE)
				@(posedge clock); // wait until next posedge to check signal
				tag = mem2proc_response; // save response as tag
			end

			proc2mem_command = BUS_NONE; // turn off command when done
			mem_busy.put(1); // unlock memory bus
			
			// "Wait" for transaction to return (writes do not have to wait as they are instantly observable
			$display("\n@@ %2d:ST of size %6s to address:%8h=%8h at t=%0d", tag, size.name(), addr, data, $time);
		end 
		join_none
	endtask

	// Non-blocking task to send load to memory
	task automatic read_memory(input logic[`XLEN-1:0] addr, output logic[63:0] data, input MEM_SIZE size);
		logic [3:0] tag;
		fork 
		begin
			tag = 4'b0;
			mem_busy.get(1); // acquire lock on memory bus
			while(tag == 0) begin // keep trying until we get a non-zero (valid) tag
				proc2mem_addr = addr; // load's address
				proc2mem_command = BUS_LOAD; // load command
				proc2mem_size = size; // size parameter
				@(posedge clock); // wait until next posedge to check signal
				tag = mem2proc_response; // save response as tag
			end
			proc2mem_command = BUS_NONE; // turn off command when done
			mem_busy.put(1); // unlock memory bus
			
			// Wait for transaction to return
			$display("\n@@ %2d:RD of size %6s to address:%8h at time=%0d", tag, size.name(), addr, $time);
			@(negedge clock);
			while(tag != mem2proc_tag) begin // transaction finishes when mem tag matches this transaction's tag
				@(posedge clock);
			end
			data = mem2proc_data; // save the data
			$display("\n@@ %2d:Loaded 0x%08h=%8h at time=%0d", tag, addr, mem2proc_data, $time);
		end 
		join_none
	endtask

	task automatic nclk(input int n);
		while( n-- > 0) begin
			@(negedge clock);
		end
	endtask

	task automatic pclk(input int n);
		while( n-- > 0) begin
			@(posedge clock);
		end
	endtask


    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                 Data Memory                              //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////
    
    assign proc2mem_TB_addr    = (proc2mem_command != BUS_NONE) ? proc2mem_addr    : proc2mem_DUT_addr;
	assign proc2mem_TB_data    = (proc2mem_command != BUS_NONE) ? proc2mem_data    : proc2mem_DUT_data;
    assign proc2mem_TB_command = (proc2mem_command != BUS_NONE) ? proc2mem_command : proc2mem_DUT_command;
    assign proc2mem_TB_size    = (proc2mem_command != BUS_NONE) ? proc2mem_size    : proc2mem_DUT_size;
	
	mem memory (
		/* Inputs */
		.clk               (clock),
		.proc2mem_command  (proc2mem_TB_command),
		.proc2mem_addr     (proc2mem_TB_addr),
		.proc2mem_data     (proc2mem_TB_data),
//		.proc2mem_size	   (proc2mem_TB_size),

		/* Outputs */
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                    DUT                                   //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////
    
    dcache DUT (
        .clock, 
        .reset,
        
        /* Updates from memory bus */
        .mem2proc_response,     
        .mem2proc_data,
        .mem2proc_tag,    
    
        /* Store Requests */
        .str_w_addr,     
        .str_w_data,
        .str_w_size,            // Size of store sent to memory
        .str_v,
    
        /* Read Requests */
        .proc2Dcache_rd_addrs,   // Load Target Address
        .proc2Dcache_rd_v,       // Valid Load?
    
        /* Read Outputs */
        .Dcache_rd_data,        // value is memory[proc2Icache_addr]
        .Dcache_rd_hits,        // when this is high
        .Dcache_str_accepted,   // when this is high
    
        /* Bus Requests */
        .proc2mem_command(proc2mem_DUT_command),      // command sent to memory
        .proc2mem_addr(proc2mem_DUT_addr),         // Address sent to memory
        .proc2mem_data(proc2mem_DUT_data),         // Data sent to memory
        .proc2mem_size(proc2mem_DUT_size),         // data size sent to memory
        
		.structural_hazard,
		.MSHR_memory_hzd
	); 
	
	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             DUT Helper functions                         //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////
	

	task display_dcache;
		/* Display Current write */
		$display("DCACHE STATE:   STRUCTURAL HAZARD: %01b | MEMORY_HAZARD: %01b", 
			structural_hazard, 
			MSHR_memory_hzd
		);
 
        $display("Store  :          VALID:%01b | TAG:%06h | INDEX:%02h | OFFSET:%02h | DATA:%16h | HIT:%01b | SIZE:%d",
			str_v, 
			str_w_addr.tag, 
			str_w_addr.index, 
			str_w_addr.offset, 
			str_w_data, 
			Dcache_str_accepted,
			str_w_size
		);

        /* Display Read Results */
		for (int i = 0; i < `N; i++) begin
            $display("Read %02d:          VALID:%01b | TAG:%06h | INDEX:%02h | OFFSET:%02h | DATA:%16h | HIT:%01b ",
				i, 
				proc2Dcache_rd_v[i], 
				proc2Dcache_rd_addrs[i].tag, 
				proc2Dcache_rd_addrs[i].index, 
				proc2Dcache_rd_addrs[i].offset, 
				Dcache_rd_data[i],
				Dcache_rd_hits[i]
			);
        end
        
        $display("");
	endtask

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                 Testbench                                //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////

	/* Helper Function */

	/* Generate System Clock */
	always begin
		#10;
		clock = ~clock;
	end

	`define VERBOSE
	initial begin

        clock = 0;
        proc2mem_command = BUS_NONE;
		mem_busy = new(1);

		str_v = 0;
		str_w_addr = 0;
		proc2Dcache_rd_v = 0;
		proc2Dcache_rd_addrs = 0;

        $display("\n Initializing DCACHE Test Bench (MEM_DELAY=%0d CYCLES)....", `MEM_LATENCY_IN_CYCLES);

		`ifdef VERBOSE
		$monitor("proc2mem_command:%09s|proc2mem_addr:%08h|proc2mem_size:%07s|mem2proc_response:%02d|mem2proc_tag:%02d|mem2procdata:%08h|proc2memdata:%08h", 
			proc2mem_TB_command, proc2mem_TB_addr, proc2mem_DUT_size, mem2proc_response, mem2proc_tag, mem2proc_data,proc2mem_TB_data);
		`endif

		/* Initialize memory */
		write_memory(32'h00000000, 64'h0000000200000001, DOUBLE);
		write_memory(32'h00000008, 64'h0000000400000003, DOUBLE);
		write_memory(32'h00000010, 64'h0000000600000005, DOUBLE);
		write_memory(32'h00000018, 64'h0000000800000007, DOUBLE);
		write_memory(32'h00000020, 64'h0000000A00000009, DOUBLE);
		write_memory(32'h00000028, 64'h0000000C0000000B, DOUBLE);
		write_memory(32'h00000030, 64'h0000000E0000000D, DOUBLE);
		write_memory(32'h00000038, 64'h000000100000000F, DOUBLE);
		write_memory(32'h00000040, 64'h0000001200000011, DOUBLE);
		write_memory(32'h00000048, 64'h0000001400000013, DOUBLE);
		write_memory(32'h00000050, 64'h0000001600000015, DOUBLE);
		write_memory(32'h00000058, 64'h0000001800000017, DOUBLE);
		write_memory(32'h00000060, 64'h0000001A00000019, DOUBLE);
		write_memory(32'h00000068, 64'h0000001C0000001B, DOUBLE);
		write_memory(32'h00000070, 64'h0000001E0000001D, DOUBLE);
		write_memory(32'h00000078, 64'h000000200000001F, DOUBLE);
		write_memory(32'h00000080, 64'h0000002200000021, DOUBLE);
		write_memory(32'h00000088, 64'h0000002400000023, DOUBLE);
		write_memory(32'h00000090, 64'h0000002600000025, DOUBLE);
		write_memory(32'h00000098, 64'h0000002800000027, DOUBLE);
		write_memory(32'h000000a0, 64'h0000002A00000029, DOUBLE);
		write_memory(32'h000000a8, 64'h0000002C0000002B, DOUBLE);
		write_memory(32'h000000b0, 64'h0000002E0000002D, DOUBLE);

		/* Wait for requests */
		pclk(1000); 
		show_mem_with_decimal(0, `MEM_SIZE_IN_BYTES);

		$display("\n***START***\n");
		
		/* Reset the processor */
		proc2mem_command = BUS_NONE;
		@(negedge clock)
		reset = 0;
		@(negedge clock)
		reset = 1;
		@(negedge clock)
		reset = 0;
		$display("\n***DEASSERTING RESET***\n");
		@(posedge clock)
		display_dcache();

		@(negedge clock)
		str_v = 0;
		proc2Dcache_rd_v[0] = `TRUE;
		proc2Dcache_rd_addrs[0] = 32'h00000000;
		proc2Dcache_rd_v[1] = `TRUE;
		proc2Dcache_rd_addrs[1] = 32'h00000004;
		proc2Dcache_rd_v[2] = `TRUE;
		proc2Dcache_rd_addrs[2] = 32'h00000008;
		pclk(20); 
		display_dcache();

		/* Test 1 */
		for (int i = 0; i < `N; i++) begin
			assert(Dcache_rd_hits[i]);
        end
		assert(Dcache_rd_data[0] == 64'h0000000200000001);
		assert(Dcache_rd_data[1] == 64'h0000000200000001);
		assert(Dcache_rd_data[2] == 64'h0000000400000003);

		/* Test 2 */ 
		@(negedge clock);
		@(negedge clock);
		str_v = `TRUE;
		str_w_addr = 32'h00000004;
		str_w_data = 32'h00000010;
		str_w_size = WORD;

		@(posedge clock)
		display_dcache();

		@(negedge clock)
	    str_v = `FALSE;

		@(posedge clock)
		display_dcache();


		/* Test 3 */ 
		@(negedge clock);
		@(negedge clock);
		str_v = `TRUE;
		str_w_addr = 32'h00000004;
		str_w_data = 32'h00000010;
		str_w_size = WORD;

		@(posedge clock)
		display_dcache();

		@(negedge clock)
	    str_v = `FALSE;

		@(posedge clock)
		display_dcache();


		/* Test 4 */ 
		@(negedge clock);
		@(negedge clock);
		str_v = `TRUE;
		str_w_addr = 32'h00000009;
		str_w_data = 64'hA1;
		str_w_size = BYTE;

		@(posedge clock)
		display_dcache();

		@(negedge clock)
	    str_v = `FALSE;

		@(posedge clock)
		display_dcache();


		/* Test 5 */ 
		@(negedge clock);
		@(negedge clock);
		str_v = `TRUE;
		str_w_addr = 32'h00000011;
		str_w_data = 64'hB1;
		str_w_size = BYTE;

		@(posedge clock)
		display_dcache();

		pclk(15);
		@(negedge clock)
	    str_v = `FALSE;

		@(posedge clock)
		display_dcache();

		pclk(10); 
		show_mem_with_decimal(0, `MEM_SIZE_IN_BYTES);

		$finish;
	end
endmodule