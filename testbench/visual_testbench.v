/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  visual_testbench.v                                  //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline        //
//                   for the visual debugger                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

extern void initcurses(int,int,int,int,int,int,int,int,int,int,int,int);
extern void flushpipe();
extern void waitforresponse();
extern void initmem();
extern int get_instr_at_pc(int);
extern int not_valid_pc(int);

module testbench();

  // Registers and wires used in the testbench
  logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;

	logic [1:0]  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE     proc2mem_size;
`endif
	logic  [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic        pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;


	logic [`XLEN-1:0] if_NPC_out;
	logic [31:0] if_IR_out;
	logic        if_valid_inst_out;
	logic [`XLEN-1:0] if_id_NPC;
	logic [31:0] if_id_IR;
	logic        if_id_valid_inst;
	logic [`XLEN-1:0] id_ex_NPC;
	logic [31:0] id_ex_IR;
	logic        id_ex_valid_inst;

	ROB_COMMIT_PACKET	[`N-1:0] 					rob_committed_instructions;
	ROB_ENTRY 			[`ROB_NUM_ENTRIES-1:0] 		rob_entries;
	logic 				[`ROB_NUM_INDEX_BITS-1:0]  	head_index;
	PRF_ENTRY 			[`PRF_NUM_ENTRIES-1:0] 		prf_entries;
    logic               [`PRF_NUM_ENTRIES-1:0] 		rrat_free_list;
    logic               [`PRF_NUM_ENTRIES-1:0] 		rat_free_list;
	logic        	           				    	if_id_enable;
	IF_ID_PACKET		[`N-1:0]  					if_packet_out;
	IF_ID_PACKET		[`N-1:0]  					if_id_packet_out;
	BTB_LINE 			[`BTB_NUM_LINES-1:0]  		cachemen;
	logic  				[`N-1:0] [`XLEN-1:0]		PCs_reg;
	logic 				[`N-1:0] [`XLEN-1:0] 		btb_addrs;
	logic 				[`N-1:0] 			 		btb_hits;
	ID_EX_PACKET    	[`N-1:0]					id_packet_out;
	ID_EX_PACKET 		[`N-1:0]					id_ex_packet_out;
	logic                       					id_ex_stall;
	logic                       					rs_structural_hazard;
	logic 											prf_full;
	logic 				[`XLEN-1:0] 		 		btb_first_tk_addr;
	logic	 				    					PC_enable;
	CDB                 [`N-1:0]    				cdb;
	STATION [`RS_NUM_ENTRIES-1:0] 					reservation_stations;
	logic 				[`ROB_NUM_INDEX_BITS-1:0]  	tail_index;
	BRANCH_PREDICTION_PACKET    [`N-1:0]    		rob_committed_branches;
	logic [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] 		rob_next_entries_indicies;
	logic                                   		branch_mispredict;
	logic                 [`XLEN-1:0] 				rob_br_mispredict_address;
	logic                                   		rob_structural_hazard;
	FREE_FUNC_UNITS                        		 	fu_availible_units;
	FUNC_UNIT_OUT 									fu_out;
	FREE_FUNC_UNITS 								fu_ready;
	RS_FUNC_PACKET              					rs_to_func_packet;
	logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] 	rat_entries;
	logic [`RAT_SIZE-1:0][`PRF_NUM_INDEX_BITS-1:0] 	rrat_entries;
	logic                                   		lsq_structural_hazard;
	LOAD_QUEUE_ENTRY [`LOAD_QUEUE_SIZE-1:0] 		load_queue;
	STORE_QUEUE_ENTRY [`STORE_QUEUE_SIZE-1:0] 		store_queue;
	STORES_READY                [`N-1:0]    		rob_stores_ready;
	LSQ_IN_PACKET   [`N-1:0]						lsq_in_packet;

  //counter used for when pipeline infinite loops, forces termination
  logic [63:0] debug_counter;
	// Instantiate the Pipeline
	pipeline pipeline_0(
		// Inputs
		.clock             (clock),
		.reset             (reset),
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag),


		// Outputs
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
		.proc2mem_size     (proc2mem_size),
		.error			   (pipeline_error_status),

		.rob_committed_instructions	(rob_committed_instructions),
		.rob_entries				(rob_entries),
		.head_index					(head_index),
		.prf_entries				(prf_entries),
		.rrat_free_list				(rrat_free_list),
		.rat_free_list				(rat_free_list),
		.if_id_enable				(if_id_enable),
		.if_packet_out				(if_packet_out),
		.if_id_packet_out			(if_id_packet_out),
		.cachemen					(cachemen),
		.PCs_reg					(PCs_reg),
		.btb_addrs					(btb_addrs),
		.btb_hits					(btb_hits),
		.id_packet_out				(id_packet_out),
		.id_ex_packet_out			(id_ex_packet_out),
		.id_ex_stall				(id_ex_stall),
		.rs_structural_hazard		(rs_structural_hazard),
		.prf_full					(prf_full),
		.btb_first_tk_addr			(btb_first_tk_addr),
		.PC_enable					(PC_enable),
		.cdb						(cdb),
		.reservation_stations		(reservation_stations),
		.tail_index					(tail_index),
		.rob_committed_branches		(rob_committed_branches),
		.rob_next_entries_indicies	(rob_next_entries_indicies),
		.branch_mispredict			(branch_mispredict),
		.rob_br_mispredict_address	(rob_br_mispredict_address),
		.rob_structural_hazard		(rob_structural_hazard),
		.fu_availible_units			(fu_availible_units),
		.fu_out						(fu_out),
		.fu_ready					(fu_ready),
		.rs_to_func_packet			(rs_to_func_packet),
		.rat_entries				(rat_entries),
		.rrat_entries				(rrat_entries),
		.lsq_structural_hazard(lsq_structural_hazard),
		.load_queue(load_queue),
		.store_queue(store_queue),
		.rob_stores_ready(rob_stores_ready),
		.lsq_in_packet(lsq_in_packet)
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
  always
  begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clock = ~clock;
  end

  // Count the number of posedges and number of instructions completed
  // till simulation ends
  always @(posedge clock)
  begin
    if(reset)
    begin
	  clock_count <= `SD 0;
	  instr_count <= `SD 0;
    end
    else
    begin
	  pipeline_completed_insts = 0;
	  for(int i =0; i <`N; i++)
	  begin
	  	if(rob_committed_instructions[i].valid)
		begin
			pipeline_completed_insts += 1;
		end
	  end
      clock_count <= `SD (clock_count + 1);
      instr_count <= `SD (instr_count + pipeline_completed_insts); //TODO: update this
    end
  end

  initial
  begin
    clock = 0;
    reset = 0;

    // Call to initialize visual debugger
    // *Note that after this, all stdout output goes to visual debugger*
    // each argument is number of registers/signals for the group
    initcurses(`N, `PRF_NUM_ENTRIES, `BTB_NUM_LINES, `RS_NUM_ENTRIES, `ROB_NUM_ENTRIES, `NUM_ADDERS,
		 		`NUM_BRANCHES, `NUM_MULTS, `NUM_MEMS, `LOAD_QUEUE_SIZE, `STORE_QUEUE_SIZE, `RAT_SIZE);

    // Pulse the reset signal
    reset = 1'b1;
    @(posedge clock);
    @(posedge clock);

    // Read program contents into memory array
    $readmemh("program.mem", memory.unified_memory);

    @(posedge clock);
    @(posedge clock);
    `SD;
    // This reset is at an odd time to avoid the pos & neg clock edges
    reset = 1'b0;
  end

  always @(negedge clock)
  begin
    if(!reset)
    begin
      `SD;
      `SD;

      // deal with any halting conditions
      if(pipeline_error_status!=NO_ERROR)
      begin
        #100
        $display("\nDONE\n");
        waitforresponse();
        flushpipe();
        $finish;
      end

    end
  end

  // This block is where we dump all of the signals that we care about to
  // the visual debugger.  Notice this happens at *every* clock edge.
  always @(clock) begin
    #2;

    // Dump clock and time onto stdout
    $display("c%h%7.0d",clock,clock_count);
    $display("t%8.0f",$time);
    $display("z%h",reset);

    // dump PRF contents
    for(int i = 0; i <`PRF_NUM_ENTRIES; i=i+1)
    begin
	  $display("av 		%d:1:%h", i, prf_entries[i].ready); 	//Is this prf value ready
	  $display("ar 		%d:1:%h", i, rat_free_list[i]);	 	//Is this prf in the RAT free list
	  $display("aR 		%d:1:%h", i, rrat_free_list[i]);			//Is this prf in the RRAT free free_list
      $display("avalue 	%d:8:%h", i, prf_entries[i].value);	//Value of the PRF
    end

    // Dump interesting register/signal contents onto stdout
    // format is "<reg group prefix><name> <width in hex chars>:<data>"
    // Current register groups (and prefixes) are:
    // f: IF   d: ID   e: EX   m: MEM    w: WB  v: misc. reg
    // g: IF/ID   h: ID/EX  i: EX/MEM  j: MEM/WB   r:RS   b:CDB
	// c: Clock t:time z:reset a:prf p:ipieline
	// k: RAT K: RRAT R: ROB F:Functional units

    // IF signals (6) - prefix 'f'
	for(int i = 0; i < `N; i++)
	begin
		$display("fif_valid %d:1:%h",      	i,if_packet_out[i].valid);
	    $display("fNPC 		%d:8:%h",       i,if_packet_out[i].NPC);
	    $display("fIR 		%d:8:%h",       i,if_packet_out[i].inst);
	    $display("fPC_reg 	%d:8:%h",       i,PCs_reg[i]);
		$display("fBTB_hit 	%d:1:%h",       i,btb_hits[i]);
		$display("fpred_adr %d:8:%h",       i,btb_addrs[i]);
	end

	// Dumping BTB state - prefix 'B'
	for(int i = 0; i < `BTB_NUM_LINES; i++)
	begin
		$display("Bvalid 	%d:1:%h",      	i,cachemen[i].valid);
		$display("Btag 		%d:7:%h",      	i,cachemen[i].tag);
	    $display("Baddr 	%d:8:%h",      	i,cachemen[i].addr);
	end

    // IF/ID signals (4) - prefix 'g'
	for(int i = 0; i < `N; i++)
	begin
	    $display("gNPC 		%d:16:%h",      i,if_id_packet_out[i].NPC);
	    $display("gIR 		%d:8:%h",       i,if_id_packet_out[i].inst);
		$display("gvalid 	%d:1:%h",       i,if_id_packet_out[i].valid);
	end

    // ID signals (13) - prefix 'd'
	for(int i = 0; i < `N; i++)
	begin
	    $display("dopa_val 	%d:8:%h",      i,id_packet_out[i].opa_value);
	    $display("dopb_val 	%d:8:%h",      i,id_packet_out[i].opb_value);
		$display("doffset 	%d:1:%h",      i,id_packet_out[i].offset_value);
	    $display("dopa_rdy	%d:1:%h",      i,id_packet_out[i].opa_ready);
	    $display("dopb_rdy 	%d:1:%h",      i,id_packet_out[i].opb_ready);
	    $display("ddest_arf %d:2:%h",      i,id_packet_out[i].arch_reg_dest);
	    $display("ddest_prf %d:2:%h",      i,id_packet_out[i].phys_reg_dest);
	    $display("dalu_func %d:2:%h",      i,id_packet_out[i].alu_func);
	    $display("dfunc_unt %d:2:%h",      i,id_packet_out[i].func_unit);
	    $display("dcond_br 	%d:1:%h",      i,id_packet_out[i].cond_branch);
	    $display("ducond_br %d:1:%h",      i,id_packet_out[i].uncond_branch);
	    $display("dhalt 	%d:1:%h",      i,id_packet_out[i].halt);
	    $display("dillegal 	%d:1:%h",      i,id_packet_out[i].illegal);
	    $display("dvalid 	%d:1:%h",      i,id_packet_out[i].valid);
	end

    // ID/EX signals (17) - prefix 'h'
	for(int i = 0; i < `N; i++)
	begin
	    $display("hNPC 		%d:16:%h",		i,id_ex_packet_out[i].NPC);
	    $display("hIR 		%d:8:%h",       i,id_ex_packet_out[i].inst);
	    $display("hopa_val 	%d:8:%h",       i,id_ex_packet_out[i].opa_value);
	    $display("hopb_val 	%d:8:%h",       i,id_ex_packet_out[i].opb_value);
	    $display("hoffset 	%d:8:%h",       i,id_ex_packet_out[i].offset_value);
	    $display("hopa_rdy 	%d:1:%h",       i,id_ex_packet_out[i].opa_ready);
	    $display("hopb_rdy 	%d:1:%h",       i,id_ex_packet_out[i].opb_ready);
	    $display("hdest_arf %d:2:%h",      	i,id_ex_packet_out[i].arch_reg_dest);
	    $display("hdest_prf %d:2:%h",      	i,id_ex_packet_out[i].phys_reg_dest);
	    $display("halu_func %d:2:%h",      	i,id_ex_packet_out[i].alu_func);
	    $display("hfunc_unt %d:2:%h",      	i,id_ex_packet_out[i].func_unit);
	    $display("hcond_br 	%d:1:%h",       i,id_ex_packet_out[i].cond_branch);
	    $display("hucond_br %d:1:%h",     	i,id_ex_packet_out[i].uncond_branch);
	    $display("hhalt 	%d:1:%h",       i,id_ex_packet_out[i].halt);
	    $display("hillegal 	%d:1:%h",       i,id_ex_packet_out[i].illegal);
	    $display("hvalid 	%d:1:%h",       i,id_ex_packet_out[i].valid);
	    $display("hcsr_op 	%d:1:%h",       i,id_ex_packet_out[i].csr_op);
	end

    // Misc signals - prefix 'v'
    $display("vcompleted 	1:%h",     		pipeline_completed_insts);
    $display("vpipe_err 	1:%h",      	pipeline_error_status);
    $display("vprf_full 	1:%h",      	prf_full);
    $display("vrs_full 		1:%h",       	rs_structural_hazard);
    $display("vlsq_full 	1:%h",       	lsq_structural_hazard);
    $display("vif_id_en 	1:%h",      	if_id_enable);
	$display("vPC_en 		1:%h",      	PC_enable);
	$display("vid_ex_en 	1:%h",		   !id_ex_stall);
    $display("vbtb_1tad 	1:%h",      	btb_first_tk_addr);
	$display("vImem_adr  	8:%h",   		proc2mem_addr);


	//Dump CDB content
	for(int i = 0; i < `N; i=i+1)
    begin
	  $display("Cvalid 		%d:1:%h", i, cdb[i].valid);
	  $display("Cdest_prf 	%d:2:%h", i, cdb[i].dest_prf);
      $display("Crob_ent 	%d:2:%h", i, cdb[i].rob_entry);
      $display("Cbr_addr 	%d:8:%h", i, cdb[i].branch_address);
      $display("Cvalue 		%d:8:%h", i, cdb[i].value);
      $display("Cvalue_v 	%d:1:%h", i, cdb[i].value_valid);
    end

	// RS State
	for(int i = 0; i < `RS_NUM_ENTRIES; i=i+1)
    begin
		$display("rvalid 	%d:1:%h", i, reservation_stations[i].valid);
		$display("rinst 	%d:1:%h", i, reservation_stations[i].inst);
		$display("rop1_r 	%d:1:%h", i, reservation_stations[i].op1_ready);
		$display("rop1_v 	%d:8:%h", i, reservation_stations[i].op1_value);
		$display("rop2_r 	%d:1:%h", i, reservation_stations[i].op2_ready);
		$display("rop2_v 	%d:8:%h", i, reservation_stations[i].op2_value);
		$display("rdest_arf %d:5:%h", i, reservation_stations[i].dest_arf);
		$display("rdest_prf %d:5:%h", i, reservation_stations[i].dest_prf);
		$display("rrob_e 	%d:2:%h", i, reservation_stations[i].rob_entry);
		$display("roffset 	%d:8:%h", i, reservation_stations[i].offset);
		$display("rpc 		%d:8:%h", i, reservation_stations[i].pc);
		$display("rlqs_idx 	%d:2:%h", i, reservation_stations[i].lsq_index);
		$display("rfu_type 	%d:2:%h", i, reservation_stations[i].func_unit_type);
		$display("rfop_type %d:2:%h", i, reservation_stations[i].func_op_type);
	end

	//ROB State
	for(int i = 0; i < `ROB_NUM_ENTRIES; i=i+1)
    begin
		$display("Rsvalid 		%d:1:%h", i, rob_entries[i].valid);
		$display("Rsinst		%d:1:%h", i, rob_entries[i].inst);
		$display("Rsexecuted 	%d:1:%h", i, rob_entries[i].executed);
		$display("Rshalt	 	%d:1:%h", i, rob_entries[i].halt);
		$display("Rsdest_arf 	%d:2:%h", i, rob_entries[i].dest_arf);
		$display("Rsdest_prf 	%d:2:%h", i, rob_entries[i].dest_prf);
		$display("Rscalc_ba  	%d:8:%h", i, rob_entries[i].calculated_branch_address);
		$display("Rspred_ba  	%d:8:%h", i, rob_entries[i].predicted_branch_address);
		$display("Rspc  	 	%d:8:%h", i, rob_entries[i].pc);
		$display("Rslsq_idx 	%d:8:%h", i, rob_entries[i].lsq_index);
		$display("Rsfop_type 	%d:2:%h", i, rob_entries[i].func_op_type);
		$display("Rsbp_indic 	%d:2:%h", i, rob_entries[i].bp_indicies);
	end

	//ROB output signals
	for(int i = 0; i < `N; i=i+1)
    begin
		$display("RSbpp_v 		%d:1:%h", i, rob_committed_branches[i].valid);
		$display("RSbpp_c 		%d:1:%h", i, rob_committed_branches[i].correct);
		$display("RSbpp_badr 	%d:8:%h", i, rob_committed_branches[i].branch_address);
		$display("RSbpp_pc  	%d:8:%h", i, rob_committed_branches[i].pc);
		$display("RSrcp_v  		%d:1:%h", i, rob_committed_instructions[i].valid);
		$display("RSrcp_darf  	%d:5:%h", i, rob_committed_instructions[i].dest_arf);
		$display("RSrcp_dprf 	%d:5:%h", i, rob_committed_instructions[i].dest_prf);
		$display("RSn_e_idx 	%d:2:%h", i, rob_next_entries_indicies[i]);
		$display("RSst_rdy_v 	%d:2:%h", i, rob_stores_ready[i].valid);
		$display("RSst_rdy_i 	%d:2:%h", i, rob_stores_ready[i].lsq_index);
	end

	//ROB misc signals
    $display("Rmrob_full 1:%h",      rob_structural_hazard);
    $display("Rmbr_mispr 1:%h",      branch_mispredict);
    $display("Rmc_br_adr 8:%h",      rob_br_mispredict_address);
    $display("Rmrob_head 2:%h",      head_index);
    $display("Rmrob_tail 2:%h",      tail_index);

	// Each functional unit has a current instruction, ready, and func out
	for(int i = 0; i < `NUM_ADDERS; i=i+1)
    begin
		//Adders
		$display("Fafree 		%d:1:%h", i, fu_availible_units.types.adders_free[i]);
		$display("Faready	 	%d:1:%h", i, fu_ready.types.adders_free[i]);
		$display("Fai_valid 	%d:1:%h", i, rs_to_func_packet.types.adders[i].valid);
		$display("Fai_op1_v 	%d:8:%h", i, rs_to_func_packet.types.adders[i].op1_value);
		$display("Fai_op2_v 	%d:8:%h", i, rs_to_func_packet.types.adders[i].op2_value);
		$display("Fai_d_prf 	%d:5:%h", i, rs_to_func_packet.types.adders[i].dest_prf);
		$display("Fai_rob_e 	%d:5:%h", i, rs_to_func_packet.types.adders[i].rob_entry);
		$display("Fai_offset	%d:2:%h", i, rs_to_func_packet.types.adders[i].offset);
		$display("Fai_pc 		%d:8:%h", i, rs_to_func_packet.types.adders[i].pc);
		$display("Fai_op_typ 	%d:2:%h", i, rs_to_func_packet.types.adders[i].func_op_type);
		$display("Fao_valid 	%d:1:%h", i, fu_out.types.adders[i].valid);
		$display("Fao_d_prf 	%d:5:%h", i, fu_out.types.adders[i].dest_prf);
		$display("Fao_rob_e 	%d:5:%h", i, fu_out.types.adders[i].rob_entry);
		$display("Fao_br_ad 	%d:8:%h", i, fu_out.types.adders[i].branch_address);
		$display("Fao_value 	%d:8:%h", i, fu_out.types.adders[i].value);
		$display("Fao_v_val 	%d:1:%h", i, fu_out.types.adders[i].value_valid);
	end

	for(int i = 0; i < `NUM_BRANCHES; i=i+1)
    begin
		//Branches
		$display("Fbfree 		%d:1:%h", i, fu_availible_units.types.branches_free[i]);
		$display("Fbready	 	%d:1:%h", i, fu_ready.types.branches_free[i]);
		$display("Fbi_valid 	%d:1:%h", i, rs_to_func_packet.types.branches[i].valid);
		$display("Fbi_op1_v 	%d:8:%h", i, rs_to_func_packet.types.branches[i].op1_value);
		$display("Fbi_op2_v 	%d:8:%h", i, rs_to_func_packet.types.branches[i].op2_value);
		$display("Fbi_d_prf 	%d:5:%h", i, rs_to_func_packet.types.branches[i].dest_prf);
		$display("Fbi_rob_e 	%d:5:%h", i, rs_to_func_packet.types.branches[i].rob_entry);
		$display("Fbi_offset	%d:2:%h", i, rs_to_func_packet.types.branches[i].offset);
		$display("Fbi_pc 		%d:8:%h", i, rs_to_func_packet.types.branches[i].pc);
		$display("Fbi_op_typ 	%d:2:%h", i, rs_to_func_packet.types.branches[i].func_op_type);
		$display("Fbo_valid 	%d:1:%h", i, fu_out.types.branches[i].valid);
		$display("Fbo_d_prf 	%d:5:%h", i, fu_out.types.branches[i].dest_prf);
		$display("Fbo_rob_e 	%d:5:%h", i, fu_out.types.branches[i].rob_entry);
		$display("Fbo_br_ad 	%d:8:%h", i, fu_out.types.branches[i].branch_address);
		$display("Fbo_value 	%d:8:%h", i, fu_out.types.branches[i].value);
		$display("Fbo_v_val 	%d:1:%h", i, fu_out.types.branches[i].value_valid);
	end

	for(int i = 0; i < `NUM_MULTS; i=i+1)
    begin
		//Mults
		$display("Fcfree 		%d:1:%h", i, fu_availible_units.types.mults_free[i]);
		$display("Fcready	 	%d:1:%h", i, fu_ready.types.mults_free[i]);
		$display("Fci_valid 	%d:1:%h", i, rs_to_func_packet.types.mults[i].valid);
		$display("Fci_op1_v 	%d:8:%h", i, rs_to_func_packet.types.mults[i].op1_value);
		$display("Fci_op2_v 	%d:8:%h", i, rs_to_func_packet.types.mults[i].op2_value);
		$display("Fci_d_prf 	%d:5:%h", i, rs_to_func_packet.types.mults[i].dest_prf);
		$display("Fci_rob_e 	%d:5:%h", i, rs_to_func_packet.types.mults[i].rob_entry);
		$display("Fci_offset	%d:2:%h", i, rs_to_func_packet.types.mults[i].offset);
		$display("Fci_pc 		%d:8:%h", i, rs_to_func_packet.types.mults[i].pc);
		$display("Fci_op_typ 	%d:2:%h", i, rs_to_func_packet.types.mults[i].func_op_type);
		$display("Fco_valid 	%d:1:%h", i, fu_out.types.mults[i].valid);
		$display("Fco_d_prf 	%d:5:%h", i, fu_out.types.mults[i].dest_prf);
		$display("Fco_rob_e 	%d:5:%h", i, fu_out.types.mults[i].rob_entry);
		$display("Fco_br_ad 	%d:8:%h", i, fu_out.types.mults[i].branch_address);
		$display("Fco_value 	%d:8:%h", i, fu_out.types.mults[i].value);
		$display("Fco_v_val 	%d:1:%h", i, fu_out.types.mults[i].value_valid);
	end

	for(int i = 0; i < `NUM_MEMS; i=i+1)
	begin
		//Mem
		$display("Fdfree 		%d:1:%h", i, fu_availible_units.types.mems_free[i]);
		$display("Fdready	 	%d:1:%h", i, fu_ready.types.mems_free[i]);
		$display("Fdi_valid 	%d:1:%h", i, rs_to_func_packet.types.mems[i].valid);
		$display("Fdi_op1_v 	%d:8:%h", i, rs_to_func_packet.types.mems[i].op1_value);
		$display("Fdi_op2_v 	%d:8:%h", i, rs_to_func_packet.types.mems[i].op2_value);
		$display("Fdi_d_prf 	%d:5:%h", i, rs_to_func_packet.types.mems[i].dest_prf);
		$display("Fdi_rob_e 	%d:5:%h", i, rs_to_func_packet.types.mems[i].rob_entry);
		$display("Fdi_offset	%d:2:%h", i, rs_to_func_packet.types.mems[i].offset);
		$display("Fdi_pc 		%d:8:%h", i, rs_to_func_packet.types.mems[i].pc);
		$display("Fdi_op_typ 	%d:2:%h", i, rs_to_func_packet.types.mems[i].func_op_type);
		$display("Fdo_valid 	%d:1:%h", i, fu_out.types.mems[i].valid);
		$display("Fdo_d_prf 	%d:5:%h", i, fu_out.types.mems[i].dest_prf);
		$display("Fdo_rob_e 	%d:5:%h", i, fu_out.types.mems[i].rob_entry);
		$display("Fdo_br_ad 	%d:8:%h", i, fu_out.types.mems[i].branch_address);
		$display("Fdo_value 	%d:8:%h", i, fu_out.types.mems[i].value);
		$display("Fdo_v_val 	%d:1:%h", i, fu_out.types.mems[i].value_valid);
	end

	for(int i = 0; i < `LOAD_QUEUE_SIZE; i=i+1)
	begin
		//Mem
		$display("Llvalid 		%d:1:%h", i, load_queue[i].valid);
		$display("Llout_rdy	 	%d:1:%h", i, load_queue[i].out_ready);
		$display("Llrdy_mem 	%d:1:%h", i, load_queue[i].ready_for_mem);
		$display("Llhas_addr	%d:8:%h", i, load_queue[i].has_address);
		$display("Llrob_ent 	%d:5:%h", i, load_queue[i].rob_entry);
		$display("Llpc 			%d:5:%h", i, load_queue[i].pc);
		$display("Lldest_prf	%d:2:%h", i, load_queue[i].dest_prf);
		$display("Lltgt_addr 	%d:8:%h", i, load_queue[i].target_address);
		$display("Llvalue 		%d:2:%h", i, load_queue[i].value);
		$display("Llage_mtch 	%d:1:%h", i, load_queue[i].age_addr_match);
		$display("Llmem_size 	%d:1:%h", i, load_queue[i].mem_size);
	end

	for(int i = 0; i < `STORE_QUEUE_SIZE; i=i+1)
	begin
		//Mem
		$display("Lsvalid 		%d:1:%h", i, store_queue[i].valid);
		$display("Lsout_rdy		%d:1:%h", i, store_queue[i].out_ready);
		$display("Lsrdy_mem 	%d:1:%h", i, store_queue[i].ready_for_mem);
		$display("Lshas_addr 	%d:8:%h", i, store_queue[i].has_address);
		$display("Lsrob_ent		%d:5:%h", i, store_queue[i].rob_entry);
		$display("Lspc 			%d:5:%h", i, store_queue[i].pc);
		$display("Lstgt_addr 	%d:8:%h", i, store_queue[i].target_address);
		$display("Lsvalue 		%d:2:%h", i, store_queue[i].value);
		$display("Lsmem_size 	%d:1:%h", i, store_queue[i].mem_size);
	end

	// LSQ_IN signals
	for(int i = 0; i < `N; i=i+1)
    begin
		$display("Livalid 		%d:1:%h", i, lsq_in_packet[i].valid);
		$display("Listore 		%d:1:%h", i, lsq_in_packet[i].store);
		$display("Lidest_prf 	%d:2:%h", i, lsq_in_packet[i].dest_prf);
		$display("LiPC		  	%d:8:%h", i, lsq_in_packet[i].pc);
	end

	// Dumping RAT
	for(int i = 0; i < `RAT_SIZE; i=i+1)
    begin
		$display("k %h", rat_entries[i]);
	end

	// Dumping RRAT
	for(int i = 0; i < `RAT_SIZE; i=i+1)
    begin
		$display("K %h", rrat_entries[i]);
	end

    // must come last
    $display("break");

    // This is a blocking call to allow the debugger to control when we
    // advance the simulation
    waitforresponse();
	end
endmodule
