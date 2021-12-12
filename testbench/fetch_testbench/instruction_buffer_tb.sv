/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  instruction_buffer_testbench.v                      //
//                                                                     //
//  Description :  Testbench for instruction buffers.                  //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`define CACHE_MODE
`define DEBUG

module testbench;
	logic        clock;
	logic        reset;

	/* DUT Inputs */
	logic 				[3:0] 					mem2proc_response;
	logic 				[63:0] 					mem2proc_data;
	logic 				[3:0] 					mem2proc_tag;
	logic 										stall;
	logic										nuke;
	logic										enable;
	logic 				[`N-1:0] [`XLEN-1:0]	input_PCs;
    logic 				[`N-1:0] [`XLEN-1:0]	input_NPCs;
	
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

	logic [`N-1:0]       icache_hits;
	MEM_SIZE     								proc2mem_size;
	logic [$clog2(`INSTR_BUFFER_LEN)-1:0]		ib_size;
	logic                                		ib_structural_hazard;
	IF_BUFFER_STATION	[`N-1:0]    			next_instrs;
	logic										all_ready;
	

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
	
	mem memory (
		/* Inputs */
		.clk               (clock),
		.proc2mem_command  (proc2mem_TB_command),
		.proc2mem_addr     (proc2mem_TB_addr),
		.proc2mem_data     (proc2mem_TB_data),

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
	instruction_buffer DUT (
		/* Inputs */
		.clock,
		.reset,
		.nuke,

		.mem2proc_data,          
		.mem2proc_response,
		.mem2proc_tag,

		.input_PCs,
		.input_NPCs,

		.stall,
		.enable,                  

		/* Ouputs */
		.proc2mem_command(proc2mem_DUT_command),    // command sent to memory
		.proc2mem_addr(proc2mem_DUT_addr),      	// Address sent to memory

		.icache_hits,
		.ib_size,
		.ib_structural_hazard,
		.next_instrs,
		.all_ready
	);

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             DUT Helper functions                         //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////
	

	task disp_next_if_stations;
		begin
			$display("\n@@@ IF_BUFFER_SIZE: %02dd, %4b",ib_size, icache_hits);
			for (int i = 0; i < `N; ++i) begin
				$display("STATION:%02d | REQUESTED:%01b | READY:%01b | MEM_TAG:%02d | PC:%04h | NPC:%04h | INST:%08h",
						i, 
						next_instrs[i].requested, 
						next_instrs[i].ready, 
						next_instrs[i].mem_tag, 
						next_instrs[i].PC, 
						next_instrs[i].NPC, 
						next_instrs[i].inst
					);
			end
			$display("@@@\n");
		end
	endtask  // task show_mem_with_decimal
	

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                 Testbench                                //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////

	/* Generate System Clock */
	always begin
		#10;
		clock = ~clock;
	end

	`define VERBOSE
	initial begin
		
		clock = 0;
		nuke = 0;
        proc2mem_command = BUS_NONE;
		mem_busy = new(1);
        $display("\nSTARTING IBUFFER_TESTBENH (MEM_DELAY=%0d CYCLES)", `MEM_LATENCY_IN_CYCLES);

		`ifdef VERBOSE
		$monitor("proc2mem_command:%09s|proc2mem_addr:%08h|mem2proc_response:%02d|mem2proc_tag:%02d|mem2procdata:%08h", 
			proc2mem_command, proc2mem_addr, mem2proc_response, mem2proc_tag, mem2proc_data);
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
		
		/* Reset the processor */
		proc2mem_command = BUS_NONE;
		@(negedge clock)
		reset = 0;
		@(negedge clock)
		reset = 1;
		@(negedge clock)
		reset = 0;
		stall = 0;
		enable = 1;

		/**
		 * Test 1
		 * - Input `N addresses and wait for them to become valid 
		 */
		for (int passes = 0; passes < 3; passes++) begin
			for (int test_num = 0; test_num < 4; ++test_num) begin
				for (int i = 0; i < `N; ++i) begin
					input_PCs[i]  = (i * 4)     + test_num*(4*`N);
					input_NPCs[i] = (i * 4 + 4) + test_num*(4*`N);
				end
				@(posedge clock);
				disp_next_if_stations();
				@(negedge clock);
			end
		end

		/* Wait for first round */
		enable = 0;
		pclk(15); 
		disp_next_if_stations();
		@(posedge clock);
		disp_next_if_stations();

		/**
		 * Test 2
		 * - Now check caching
		 */
		 @(negedge clock)
		 enable = 1;
		 for (int passes = 0; passes < 3; passes++) begin
			for (int test_num = 0; test_num < 3; ++test_num) begin
				for (int i = 0; i < `N; ++i) begin
					input_PCs[i]  = (i * 4)     + test_num*(4*`N);
					input_NPCs[i] = (i * 4 + 4) + test_num*(4*`N);
				end
				@(posedge clock);
				disp_next_if_stations();
				@(negedge clock);
			end
		end

		/* Wait for first round */
		enable = 0;
		pclk(15); 
		disp_next_if_stations();

		
		$finish;
	end

endmodule 
