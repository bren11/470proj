/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  lsq_testbench.sv                                    //
//                                                                     //
//  Description :  This tb test the lsq, dcache controller, and mshr   //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`define VERBOSE

module testbench ;

	logic clock, reset, nuke;

	LSQ_IN_PACKET [`N-1:0] lsq_in;
	logic [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] next_entries;
    STORES_READY [`N-1:0] stores_ready;

    FUNC_UNIT_PACKET [`NUM_MEMS-1:0] input_instr;
	logic            [`NUM_MEMS-1:0] sel;


    FUNC_OUTPUT     [`NUM_MEMS-1:0] out;
	logic      	   [`NUM_MEMS-1:0]  ready;

    logic [3:0]   mem2proc_response;        // Tag from memory about current request
	logic [63:0]  mem2proc_data;            // Data coming back from memory
	logic [3:0]   mem2proc_tag;              // Tag from memory about current reply

	MEM_SIZE				  					proc2mem_size;

	BUS_COMMAND				  					proc2mem_command;
	BUS_COMMAND				  					proc2mem_DUT_command;
	BUS_COMMAND				  					proc2mem_TB_command;

	logic 				[`XLEN-1:0]				proc2mem_addr;
	logic 				[`XLEN-1:0]				proc2mem_DUT_addr;
	logic 				[`XLEN-1:0]				proc2mem_TB_addr;

	logic 				[63:0] 					proc2mem_data;
	logic 				[63:0] 					proc2mem_DUT_data;
    logic 				[63:0] 					proc2mem_TB_data;

	STORE_QUEUE_ENTRY [`STORE_QUEUE_SIZE-1:0] store_queue;
	LOAD_QUEUE_ENTRY [`LOAD_QUEUE_SIZE-1:0] load_queue;

    logic [`N-1:0][`LSQ_INDEX_BITS-1:0] n_lsq_idxs;

    logic lsq_full;

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                 Data Memory                              //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////
	
	/* Need to mux between memory tasks and DUT */
    assign proc2mem_TB_addr    = (proc2mem_command != BUS_NONE) ? proc2mem_addr    : proc2mem_DUT_addr;
	assign proc2mem_TB_data    = (proc2mem_command != BUS_NONE) ? proc2mem_data    : proc2mem_DUT_data;
    assign proc2mem_TB_command = (proc2mem_command != BUS_NONE) ? proc2mem_command : proc2mem_DUT_command;
	
	/* Memory Provided */
	mem memory (
		/* Inputs */
		.clk (clock),
		.proc2mem_command  ( proc2mem_TB_command ),
		.proc2mem_addr     ( proc2mem_TB_addr    ),
		.proc2mem_data     ( proc2mem_TB_data    ),

		/* Outputs */
		.mem2proc_response,
		.mem2proc_data,
		.mem2proc_tag
	);

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                    DUT                                   //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

	lsq LSQ_DUT (
		.clock,
		.reset,
		.nuke,
	
		.lsq_in,
		.next_entries,
		.stores_ready,
	
		.input_instr,
		.sel,
	
		.out,
		.ready,
	
		.mem2proc_response, // Tag from memory about current request
		.mem2proc_data,     // Data coming back from memory
		.mem2proc_tag,      // Tag from memory about current reply
	
		.proc2mem_command ( proc2mem_DUT_command ), // command sent to memory
		.proc2mem_addr    ( proc2mem_DUT_addr    ), // Address sent to memory
		.proc2mem_data    ( proc2mem_DUT_data    ), // Data sent to memory
	
		.n_lsq_idxs,
	
		.lsq_full,
		.store_queue,
		.load_queue
	);

	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             DUT Helper functions                         //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////
	

	task display_lsq;
		
		$display("Store Queue:");
		for (int i = 0; i < `STORE_QUEUE_SIZE; ++i) begin
			$display("|VALID:%01b|OUT_READY:%1b|READY_MEM:%1b|HAS_ADDR:%01b|ROB:%02h|PC:%08h|ADDR:%08h|VAL:%08h|MEM_SIZE:%01h|",
				store_queue[i].valid,
				store_queue[i].out_ready,
				store_queue[i].ready_for_mem,
				store_queue[i].has_address,
				store_queue[i].rob_entry,
				store_queue[i].pc,
				store_queue[i].target_address,
				store_queue[i].value,
				store_queue[i].mem_size
			);
		end
		$display("Load Queue:");
		for (int i = 0; i < `LOAD_QUEUE_SIZE; ++i) begin
			$display("|VALID:%01b|OUT_READY:%1b|READY_MEM:%1b|HAS_ADDR:%01b|ROB:%02h|PC:%08h|DEST_PRF:%02h|ADDR:%08h|VAL:%08h|MEM_SIZE:%01h|AGE:%08b|",
				load_queue[i].out_ready,
				load_queue[i].valid,
				load_queue[i].ready_for_mem,
				load_queue[i].has_address,
				load_queue[i].rob_entry,
				load_queue[i].pc,
				load_queue[i].dest_prf,
				load_queue[i].target_address,
				load_queue[i].value,
				load_queue[i].mem_size,
				load_queue[i].age_addr_match
			);
		end
		$display("Ouputs:");
		for (int i = 0; i < `NUM_MEMS; ++i) begin
			$display("|VALID:%01b|ROB:%02h|DEST_PRF:%02h|VAL:%08h|VAL_VALID:%01b|",
				out[i].valid,
				out[i].rob_entry,
				out[i].dest_prf,
				out[i].value,
				out[i].value_valid
			);
		end

        $display("");
	endtask

	task check_empty;
		assert(~lsq_full);
	endtask

	function finish_assert;
		input in;
		begin
			if(~in) begin
				$error("\n***FAILED***\n\n");
				$finish;
			end
		end
	endfunction

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
    //                                 Testbench                                //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////

    always begin
		#10;
		clock = ~clock;
	end
	

	initial begin
		
		`ifdef VERBOSE
			$monitor("proc2mem_command:%09s|proc2mem_addr:%08h|mem2proc_response:%02d|mem2proc_tag:%02d|mem2procdata:%08h|proc2memdata:%08h", 
				proc2mem_TB_command, 
				proc2mem_TB_addr, 
				mem2proc_response, 
				mem2proc_tag, 
				mem2proc_data,
				proc2mem_TB_data
			);
		`endif

		reset = 1;
		clock = 0;
		nuke = 0;
		lsq_in = 0;
		stores_ready = 0;
		input_instr = 0;
		next_entries = 0;
		sel = 0;
		proc2mem_command = BUS_NONE;
		mem_busy = new(1);

		$display("\n Initializing LSQ Test Bench (MEM_DELAY=%0d CYCLES)....", `MEM_LATENCY_IN_CYCLES);

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
		
		/***** DISPATCHING *****/

		/* Add a single store */
		@(negedge clock);
		@(negedge clock);
		reset = 0;
		lsq_in[0].valid    = `TRUE;
		lsq_in[0].store    = `TRUE;
		lsq_in[0].dest_prf = 5'h01;
		lsq_in[0].pc       = 32'd4;

		@(negedge clock)
		lsq_in[0].valid    = `FALSE;
		display_lsq();

		/* Add a load between the stores */
		@(negedge clock);
		reset = 0;
		lsq_in[0].valid    = `TRUE;
		lsq_in[0].store    = `FALSE;
		lsq_in[0].dest_prf = 5'h01;
		lsq_in[0].pc       = 32'd4;
		lsq_in[1].valid    = `TRUE;
		lsq_in[1].store    = `FALSE;
		lsq_in[1].dest_prf = 5'h01;
		lsq_in[1].pc       = 32'd8;

		@(negedge clock)
		lsq_in[0].valid    = `FALSE;
		lsq_in[1].valid    = `FALSE;
		display_lsq();

		/* Add same store again */
		@(negedge clock);
		lsq_in[0].valid    = `TRUE;
		lsq_in[0].store    = `TRUE;
		lsq_in[0].dest_prf = 5'h02;
		lsq_in[0].pc       = 32'd4;
		lsq_in[1].valid    = `TRUE;
		lsq_in[1].store    = `TRUE;
		lsq_in[1].dest_prf = 5'h03;
		lsq_in[1].pc       = 32'd8;


		@(negedge clock)
		lsq_in[0].valid    = `FALSE;
		lsq_in[1].valid    = `FALSE;
		display_lsq();

		/* Add same load after the stores */
		@(negedge clock);
		reset = 0;
		lsq_in[0].valid    = `TRUE;
		lsq_in[0].store    = `FALSE;
		lsq_in[0].dest_prf = 5'h01;
		lsq_in[0].pc       = 32'd4;
		lsq_in[1].valid    = `TRUE;
		lsq_in[1].store    = `FALSE;
		lsq_in[1].dest_prf = 5'h01;
		lsq_in[1].pc       = 32'd8;

		@(negedge clock)
		lsq_in[0].valid    = `FALSE;
		lsq_in[1].valid    = `FALSE;
		display_lsq();

		/* Make sure store does not go if ready */
		@(negedge clock);
		stores_ready[0] = {
			`TRUE,
			3'h0
		};


		/***** ISSUING *****/

		/* Give a load it's address */
		@(negedge clock);
		input_instr[0].valid    	= `TRUE;
		input_instr[0].op1_value	= 32'd10;
		input_instr[0].op2_value	= 32'd02;
		input_instr[0].dest_prf		= 6'h01;
		input_instr[0].rob_entry	= 5'h02;
		input_instr[0].offset		= 32'd6;
		input_instr[0].pc			= 32'd08;
		input_instr[0].lsq_index	= 3'd00;
		input_instr[0].func_op_type	= ALU_LW;
		input_instr[1].valid    	= `TRUE;
		input_instr[1].op1_value	= 32'd10;
		input_instr[1].op2_value	= 32'd02;
		input_instr[1].dest_prf		= 6'h01;
		input_instr[1].rob_entry	= 5'h02;
		input_instr[1].offset		= 32'd6;
		input_instr[1].pc			= 32'd08;
		input_instr[1].lsq_index	= 3'd01;
		input_instr[1].func_op_type	= ALU_LW;

		@(negedge clock);
		input_instr[0].valid    	= `FALSE;
		@(negedge clock);
		display_lsq();

		/* Give a store it's address */
		@(negedge clock);
		input_instr[0].valid    	= `TRUE;
		input_instr[0].op1_value	= 32'h70; /* Different address, so age of loads should update */
		input_instr[0].op2_value	= 32'd00;
		input_instr[0].dest_prf		= 6'h01;
		input_instr[0].rob_entry	= 5'h02;
		input_instr[0].offset		= 32'h0;
		input_instr[0].pc			= 32'd04;
		input_instr[0].lsq_index	= 3'd01;
		input_instr[0].func_op_type	= ALU_SW;

		@(negedge clock);
		input_instr[0].valid    	= `FALSE;
		@(negedge clock);
		display_lsq();

		/* Give a store it's address so that a load forwards */
		@(negedge clock);
		input_instr[0].valid    	= `TRUE;
		input_instr[0].op1_value	= 32'h10;
		input_instr[0].op2_value	= 32'd00;
		input_instr[0].dest_prf		= 6'h01;
		input_instr[0].rob_entry	= 5'h02;
		input_instr[0].offset		= 32'h0;
		input_instr[0].pc			= 32'd04;
		input_instr[0].lsq_index	= 3'd02;
		input_instr[0].func_op_type	= ALU_SW;

		@(negedge clock);
		input_instr[0].valid    	= `FALSE;
		@(negedge clock);
		display_lsq();
		@(negedge clock);
		display_lsq();

		pclk(100); 
		$display("\n***PASSED***\n\n");
		$finish;
	end
endmodule