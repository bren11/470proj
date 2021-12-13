/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

extern void print_header(string str);
extern void print_cycles();
extern void print_stage(string div, int inst, int npc, int valid_inst);
extern void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                      int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
extern void print_membus(int proc2mem_command, int mem2proc_response,
                         int proc2mem_addr_hi, int proc2mem_addr_lo,
                         int proc2mem_data_hi, int proc2mem_data_lo);
extern void print_close();

`define CACHE_MODE

module testbench;

	// variables used in the testbench
	logic 				       						clock;
	logic 				       						reset;
	logic 				[31:0] 						clock_count;
	logic 				[31:0] 						instr_count;
	logic											n_halt;
	int   				       						wb_fileno;

	logic 				[1:0]  						proc2mem_command;
	logic 				[`XLEN-1:0] 				proc2mem_addr;
	logic 				[63:0] 						proc2mem_data;
	logic 				[3:0] 						mem2proc_response;
	logic 				[63:0] 						mem2proc_data;
	logic  				[3:0] 						mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE     									proc2mem_size;
`endif
	logic  				[3:0] 						pipeline_completed_insts;
	EXCEPTION_CODE 									pipeline_error_status;
	ROB_COMMIT_PACKET	[`N-1:0] 					rob_committed_instructions;
	ROB_ENTRY 			[`ROB_NUM_ENTRIES-1:0] 		rob_entries;
	logic 				[`ROB_NUM_INDEX_BITS-1:0]  	head_index;
	PRF_ENTRY 			[`PRF_NUM_ENTRIES-1:0] 		prf_entries;

    logic 				[31:0] 						rob_hzrd_count;
    logic 				[31:0] 						rs_hzrd_count;
    logic 				[31:0] 						lsq_hzrd_count;
    logic 				[31:0] 						icache_acc_count;
    logic 				[31:0] 						icache_hits_count;
    logic 				[31:0] 						dcache_acc_count;
    logic 				[31:0] 						dcache_miss_count;
    logic 				[31:0] 						n_icache_acc_count;
    logic 				[31:0] 						n_icache_hits_count;
    logic 				[31:0] 						n_dcache_acc_count;
    logic 				[31:0] 						n_dcache_miss_count;

    //counter used for when pipeline infinite loops, forces termination
    logic [63:0] debug_counter;
	// Instantiate the Pipeline
	`DUT(pipeline) core(
		// Inputs
		.clock             			(clock),
		.reset             			(reset),
		.mem2proc_response 			(mem2proc_response),
		.mem2proc_data     			(mem2proc_data),
		.mem2proc_tag     		 	(mem2proc_tag),


		// Outputs
		.proc2mem_command  			(proc2mem_command),
		.proc2mem_addr     			(proc2mem_addr),
		.proc2mem_data     			(proc2mem_data),
		.error			   			(pipeline_error_status),
		.rob_committed_instructions	(rob_committed_instructions),
		.rob_entries				(rob_entries),
		.head_index					(head_index),
		.prf_entries				(prf_entries)
`ifndef CACHE_MODE
		.proc2mem_size     			(proc2mem_size)
`endif
	);


	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
`endif

		// Outputs

		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);

	// Generate System Clock
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

	// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
        real icache;
        real dcache;

		begin
			cpi = (clock_count + 1.0) / (instr_count - 1); /// -1 because halt instruction doesn't count
            icache = (icache_hits_count * 1.0) / icache_acc_count;
            dcache = (dcache_acc_count - dcache_miss_count * 1.0) / dcache_acc_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI %f %f %0d %0d %0d\n@@",
			          clock_count+1, (instr_count - 1), cpi, icache, dcache, rob_hzrd_count, rs_hzrd_count, lsq_hzrd_count); /// -1 because halt instruction doesn't count
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`VERILOG_CLOCK_PERIOD);
		end
	endtask  // task show_clk_count

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

	initial begin

		clock = 1'b0;
		reset = 1'b0;


		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);

		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
		$readmemh("program.mem", memory.unified_memory);
		@(posedge clock);
		@(posedge clock);
		`SD;
		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

		wb_fileno = $fopen("writeback.out");
	end

    logic [`DCACHE_RD_PORTS-1:0] prevValid;

    always_comb begin
        n_icache_acc_count = icache_acc_count;
        n_icache_hits_count = icache_hits_count;
        n_dcache_acc_count = dcache_acc_count;
        n_dcache_miss_count = dcache_miss_count;

        if (!core.if_1.ib_1.ib_structural_hazard && core.if_1.ib_1.enable) begin
            for(int i =0; i <`N; i++) begin
                if (core.if_1.ib_1.icache_hits[i]) begin
                    n_icache_hits_count = (n_icache_hits_count + 1);
                end
                n_icache_acc_count = (n_icache_acc_count + 1);
            end
        end

        for (int i = 0; i < `DCACHE_RD_PORTS; ++i) begin
            if (core.fu.mems.data_cache_1.dcache_MSHR.cache_access_v[i] && core.fu.mems.data_cache_1.dcache_MSHR.cache_access_misses[i] && ~core.fu.mems.data_cache_1.dcache_MSHR.cache_access_repeat[i]) begin
                n_dcache_miss_count = (n_dcache_miss_count + 1);
            end
            if (core.fu.mems.data_cache_1.dcache_MSHR.cache_access_v[i] && !prevValid[i]) begin
                n_dcache_acc_count = (n_dcache_acc_count + 1);
            end
        end
    end

	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
        
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
            rob_hzrd_count <= `SD 0;
			rs_hzrd_count <= `SD 0;
            lsq_hzrd_count <= `SD 0;
            icache_acc_count <= `SD 0;
			icache_hits_count <= `SD 0;
            dcache_acc_count <= `SD 0;
			dcache_miss_count <= `SD 0;
            prevValid <= `SD 0;
		end else begin
			pipeline_completed_insts = 0;
	  	  	for(int i =0; i <`N; i++)
	  	  	begin
		  	  	if(rob_committed_instructions[i].valid)
		  		begin
		  			pipeline_completed_insts += 1;
		  		end
	  	  	end
	        clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts);

            icache_acc_count <= `SD n_icache_acc_count;
            icache_hits_count <= `SD n_icache_hits_count;
            dcache_acc_count <= `SD n_dcache_acc_count;
            dcache_miss_count <= `SD n_dcache_miss_count;

            if (core.rob_structural_hazard) begin
                rob_hzrd_count <= `SD (rob_hzrd_count + 1);
            end
            if (core.rs_structural_hazard) begin
                rs_hzrd_count <= `SD (rs_hzrd_count + 1);
            end
            if (core.lsq_structural_hazard) begin
                lsq_hzrd_count <= `SD (lsq_hzrd_count + 1);
            end

            prevValid <= `SD core.fu.mems.data_cache_1.dcache_MSHR.cache_access_v;
		end
	end


	always @(negedge clock) begin
        if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
        end else begin
			`SD;
			`SD;

			// write the writeback information to writeback.out
			for(int i =0; i<`N; i++) begin
				if(rob_committed_instructions[i].valid)
					if (rob_committed_instructions[i].dest_arf == 0)
						$fdisplay(wb_fileno, "PC=%x, ---",
							rob_entries[(head_index+i)%`ROB_NUM_ENTRIES].pc
							);
					else
						$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
							rob_entries[(head_index+i)%`ROB_NUM_ENTRIES].pc,
							rob_committed_instructions[i].dest_arf,
							prf_entries[rob_committed_instructions[i].dest_prf].value
							);
			end

			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 5000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
				// 8Bytes per line, 16kB total

				$display("@@  %t : System halted\n@@", $realtime);

				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default:
						$display("@@@ System halted on unknown error code %x",
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				$fclose(wb_fileno);
				#100 $finish;
			end
            debug_counter <= debug_counter + 1;
		end  // if(reset)
	end

endmodule  // module testbench
