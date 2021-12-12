/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  if_testbench.v                                      //
//                                                                     //
//  Description :  Testbench module for the if stage of the processor  //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

`define CACHE_MODE

module if_testbench;

    /* Utility */
	logic        clock;
	logic        reset;

    /* DUT Inputs */
	logic         stall;      										// only go to next instruction when true
	BRANCH_PREDICTION_PACKET 	[`N-1:0] 	committed_branches;		// Comitted branches
	logic        			    [63:0] 		mem2proc_data;          // Data coming back from instruction-memory
	logic					    [3:0]   	mem2proc_response;
	logic					    [3:0]   	mem2proc_tag;
	logic									branch_mispredict;
	logic 						[`XLEN-1:0]	corrected_branch_address;

    /* DUT Ouputs */
	logic 					    [1:0]  		proc2mem_command;    	// command sent to memory
	logic 					    [`XLEN-1:0] proc2mem_addr;      	// Address sent to memory
	IF_ID_PACKET				[`N-1:0]  	if_packet_out;        	// Output data packet from IF going to ID, see sys_defs for signal informati    son 

    /* Utility */
    logic        					[63:0]  proc2mem_data;
	//////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                 Data Memory                              //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////
    assign proc2mem_data = 0;
	mem memory (
		/* Inputs */
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),

		/* Outputs */
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);
    

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
    
    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                    DUT                                   //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    if_stage DUT_IF(
        /* Inputs */
        .clock,
        .reset,
        .stall,
		
		.branch_mispredict,
        .corrected_branch_address,
        .committed_branches,
        .mem2proc_data,
        .mem2proc_response,
        .mem2proc_tag,
    
        /* Outputs */
        .proc2mem_command,
        .proc2mem_addr,
    
        .if_packet_out
    );		
    
    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             DUT Helper functions                         //
    //                                                                          //
	//////////////////////////////////////////////////////////////////////////////
	
	task disp_if_packet_outs;
		begin
			$display("\n@@@ BRANCH?: VALID:%01b, ADDR:%08h",branch_mispredict, corrected_branch_address);
			for (int i = 0; i < `N; ++i) begin
				$display("STATION:%02d | VALID:%01b | PC:%04h | NPC:%04h | INST:%08h",
						i, 
						if_packet_out[i].valid, 
						if_packet_out[i].PC, 
						if_packet_out[i].NPC, 
						if_packet_out[i].inst
					);
			end
			$display("@@@\n");
		end
	endtask  // task show_mem_with_decimal
    
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
    
    // Generate System Clock
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
    end

	initial begin
	
		clock = 1'b0;
		reset = 1'b0;
		stall = 1;
		committed_branches = 0;
		branch_mispredict = 0;
		corrected_branch_address = 0;

		/* Pulse the reset signal */
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
        
        /* Flash Memory */
		$readmemh("testbench/fetch_testbench/if_tb_program.mem", memory.unified_memory);
		show_mem_with_decimal(0, `MEM_SIZE_IN_BYTES);

		@(posedge clock);
		@(posedge clock);
		`SD;		
		reset = 1'b0;
		stall = 0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
		
		pclk(25);
		@(negedge clock)
		branch_mispredict = 1;
		corrected_branch_address = 32'h8;
		@(negedge clock)
		branch_mispredict = 0;
		pclk(25);

        /* Start */
        $finish;
	end

	always_ff @(posedge clock) begin
		disp_if_packet_outs();
	end

endmodule
