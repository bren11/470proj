//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//   Modulename :  reservation_station.sv                                   //
//                                                                          //
//  Description :  module for a R10k scheme pipeline                        //
//                 recieves n instructions from pipeline and dispatches     //
//                 them to the functional units. Stalls if there aren't     //
//                 at least n station open and is constantly listening      //
//                 to the CDB                                               //
//////////////////////////////////////////////////////////////////////////////


module reservation_station (

input                                   reset,                  // Input to set all stations and functional packets to invalid
input                                   clock,
input  STATION          [`N-1:0]        dispatched_stations,    // Instructions being sent to the reservation station
input  CDB              [`N-1:0]        cdb_input,              // N possible CDB's, for instructions waiting on values
input  FREE_FUNC_UNITS                  avail_func_units,       // One hot signal of which functional units are ready for instructions
input [`N-1:0][`ROB_NUM_INDEX_BITS-1:0] next_entries,
input   [`N-1:0][`LSQ_INDEX_BITS-1:0]   n_lsq_index,

output logic                            rs_full,                // Outputs if there are not at least N free stations
output RS_FUNC_PACKET                   rs_to_func,              // Outputs the the functional units

//Visual debugger outputs
output STATION [`RS_NUM_ENTRIES-1:0] 	stations                                     // Current state of the rs
);

    logic [`RS_NUM_ENTRIES-1:0]      free_list;                                  // One hot encoded wire that tells us what stations are free(have invalid instructions in them)
    logic [`NUM_FU_TYPES-1:0][`RS_NUM_ENTRIES-1:0] rs_ready;                         // One hot values that show what instructions of each type are ready for execution
    logic [`N-1:0][`RS_NUM_ENTRIES-1:0] gnt_bus;                                 // Grants for what station an instruction should go to=

    RS_GNT_BUS_T rs_gnt_bus;                                                    // Wire for the priority selector, used to figure out what stations are ready to be sent to functinal unit
    FU_AVAIL_GNT_BUS_T fu_avail_gnt_bus;                                        // Wire for the priority selector, used to figure out where ready instructions should be sent to

    STATION [`RS_NUM_ENTRIES-1:0] stations_w_dispatch;                          // State of rs after dispatched instructions are added
    STATION [`RS_NUM_ENTRIES-1:0] n_stations;                                   // The next state of the rs(after dispatched instruction are
                                                                                //  added the cdb is read, and instructions are dispatched)

    parameter [3:0] num_fu [`NUM_FU_TYPES]  = {                            // Const array containing number ofs functional units for each type
        `NUM_ADDERS,
        `NUM_MULTS,
        `NUM_BRANCHES,
        `NUM_MEMS
    };

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                          INSTR HAND RAISING                              //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    //looks at rs and finds free stations (invalid)
    genvar valid_i;
    for(valid_i = 0; valid_i < `RS_NUM_ENTRIES; ++valid_i) begin:f0
        assign free_list[valid_i] = ~stations[valid_i].valid;
    end

    /* Create ready least for the reservation station for each functional unit type */
    for (genvar func_type = 0; func_type < `NUM_FU_TYPES; ++func_type) begin : f4 /* Types are enumerated in FUNC_UNIT_TYPE */

        /* Go through each reservation station */
        for(genvar rs_idx = 0; rs_idx < `RS_NUM_ENTRIES; ++rs_idx) begin : f1
            assign rs_ready[func_type][rs_idx] = stations[rs_idx].valid &       // Valid station
                   (stations[rs_idx].func_unit_type == func_type) &             // Correct FU Type (enumerated in FUNC_UNIT_TYPE)
                   (stations[rs_idx].op1_ready & stations[rs_idx].op2_ready);   // Operands are ready
        end
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                       Start EX Priority Selection                        //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    priority_selector #(`N, `RS_NUM_ENTRIES) rsps(.req(free_list), .gnt_bus(gnt_bus)); //what stations will get instructions

    /* ADD */
    priority_selector #(`NUM_ADDERS, `RS_NUM_ENTRIES) ps_rs_add (
        .req(rs_ready[ADD]),                  // Which instructions are ready for this type
        .gnt_bus(rs_gnt_bus.add_inst_gnts)          // Pick up n instr up to the number of fu's that exist
    );
    priority_selector #(`NUM_ADDERS, `NUM_ADDERS) ps_fu_add (
        .req(avail_func_units.types.adders_free),
        .gnt_bus(fu_avail_gnt_bus.add_fu_gnts)
    );

    /* MULT */
    priority_selector #(`NUM_MULTS, `RS_NUM_ENTRIES) ps_rs_mult (
        .req(rs_ready[MULT]),                  // Which instructions are ready for this type
        .gnt_bus(rs_gnt_bus.mult_inst_gnts)         // Pick up n instr up to the number of fu's that exist
    );
    priority_selector #(`NUM_MULTS, `NUM_MULTS) ps_fu_mult (
        .req(avail_func_units.types.mults_free),
        .gnt_bus(fu_avail_gnt_bus.mult_fu_gnts)
    );

    /* BRANCH */
    priority_selector #(`NUM_BRANCHES, `RS_NUM_ENTRIES) ps_rs_branch (
        .req(rs_ready[BRANCH]),                  // Which instructions are ready for this type
        .gnt_bus(rs_gnt_bus.branch_inst_gnts)       // Pick up n instr up to the number of fu's that exist
    );
    priority_selector #(`NUM_BRANCHES, `NUM_BRANCHES) ps_fu_branch (
        .req(avail_func_units.types.branches_free),
        .gnt_bus(fu_avail_gnt_bus.branch_fu_gnts)
    );

    /* MEM */
    priority_selector #(`NUM_MEMS, `RS_NUM_ENTRIES) ps_rs_mem (
        .req(rs_ready[MEM]),                  // Which instructions are ready for this type
        .gnt_bus(rs_gnt_bus.mem_inst_gnts)         // Pick up n instr up to the number of fu's that exist
    );
    priority_selector #(`NUM_MEMS, `NUM_MEMS) ps_fu_mem (
        .req(avail_func_units.types.mems_free),
        .gnt_bus(fu_avail_gnt_bus.mem_fu_gnts)
    );

    always_comb begin

        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                                Dispatch                                  //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////

        /**
         * Instruction Dispatch Implementation
         *
         * @brief   These for loops generate the next stations that will be put into
         *          the reservation states at the next rising edge. The first loop
         *
         * @input   dispatched_stations[]. These are the incoming reservation stations
         *          coming into the rs from the IDEX stage.
         *
         * @input   stations[]. These are the stations in the reservation from the
         *          previous cycle.
         *
         * @input   stations[]. These are the stations in the reservation from the
         *          previous cycle.
         *
         * @output  n_stations[]. Stations to be latched in the next clock cycle
         *
         */

        /* Adds dispatched instructions(from ID/EX) to the reservation station  */
        for(int ds_dis_i = 0; ds_dis_i < `N; ++ds_dis_i) begin
            for(int gnt_i = 0; gnt_i < `RS_NUM_ENTRIES; ++gnt_i) begin
                if(gnt_bus[ds_dis_i][gnt_i]) begin
                    stations_w_dispatch[gnt_i] = dispatched_stations[ds_dis_i];
                    stations_w_dispatch[gnt_i].rob_entry = next_entries[ds_dis_i];
                    stations_w_dispatch[gnt_i].lsq_index = n_lsq_index[ds_dis_i];
                end else if(ds_dis_i == 0) begin
                    stations_w_dispatch[gnt_i] = stations[gnt_i];
                end
            end
        end

        /* Then looks at all of the CDBs to check if any stations are looking for values and if value found sets op1/op2 */
        for(int rs_i = 0; rs_i < `RS_NUM_ENTRIES; ++rs_i) begin
                //base case cdb read
            for(int cdb_i = 0; cdb_i < `N; cdb_i = cdb_i + 1) begin
                if(cdb_i == 0) begin
                    n_stations[rs_i] = stations_w_dispatch[rs_i];
                end
                if(cdb_input[cdb_i].valid && cdb_input[cdb_i].value_valid && stations_w_dispatch[rs_i].valid) begin
                    if(~stations_w_dispatch[rs_i].op1_ready && (stations_w_dispatch[rs_i].op1_value == cdb_input[cdb_i].dest_prf)) begin
                        n_stations[rs_i].op1_ready = 1'b1;
                        n_stations[rs_i].op1_value = cdb_input[cdb_i].value;
                    end
                    if(~stations_w_dispatch[rs_i].op2_ready && (stations_w_dispatch[rs_i].op2_value == cdb_input[cdb_i].dest_prf))  begin
                        n_stations[rs_i].op2_ready = 1'b1;
                        n_stations[rs_i].op2_value = cdb_input[cdb_i].value;
                    end
                end
            end
        end


        //////////////////////////////////////////////////////////////////////////////
        //                                                                          //
        //                                 ISSUE                                    //
        //                                                                          //
        //////////////////////////////////////////////////////////////////////////////

        /**
         * Instruction Issue Implementation
         *
         * @brief   This Issue block loops through each functional unit type (e.g. mult,
         *          add, mem, etc.). From here it will go through each of the selected
         *          reservation stations routed to each functional unit type.
         *
         * @input   rs_gnt_bus. This is a three dimensional bus coming out of the priority
         *          selector going from each valid rs station of the functional unit type
         *          to number of availible functional units
         *
         * @input   `fu_avail_gnt_bus. This is another three dimensional bus coming from
         *          fromt the proity selector which choses which functional units for
         *          a given type are avaible
         *
         * @output  This combinationally updates the rs_to_func output with the selected
         *          reservation station on the bus to the intended functional unit it is
         *          being sent to. The idea is that the functional unit only has to send
         *          a bit vector of which functional units are availible, and the RS
         *          determines which busses to send instructions on to start execute.
         */

        /* Fix latch */
        rs_to_func = 0;

        /* Go through Each Functional Unit type */
        for (int func_type = 0; func_type < `NUM_FU_TYPES; ++func_type) begin /* Types are enumerated in FUNC_UNIT_TYPE */

            /* Go through each functional unit for each type */
            for (int func_unit_idx = 0; func_unit_idx < num_fu[func_type]; ++func_unit_idx) begin

                /* For each functional unit, initialize the packet sent to invalid
                   such that the functional units do not act on these values */
                case (func_type)
                    ADD:        rs_to_func.types.adders[func_unit_idx].valid   = `FALSE;
                    MULT:       rs_to_func.types.mults[func_unit_idx].valid    = `FALSE;
                    BRANCH:     rs_to_func.types.branches[func_unit_idx].valid = `FALSE;
                    MEM:       rs_to_func.types.mems[func_unit_idx].valid    = `FALSE;
                    default:    rs_to_func.types.adders[func_unit_idx].valid   = `FALSE;
                endcase

                /* Go through each granted(available) functional unit */
                for (int fu_gnt_idx = 0; fu_gnt_idx < num_fu[func_type]; ++fu_gnt_idx) begin

                    /* Go through each granted reservation station for this functional unit  */
                    for (int gnt_bus_stations_i = 0; gnt_bus_stations_i < `RS_NUM_ENTRIES; ++ gnt_bus_stations_i) begin

                        case (func_type)
                            ADD: begin
                                /* If there exists a ready station (for the given unit) and an availible funcitonal unit */
                                if ((rs_gnt_bus.add_inst_gnts[fu_gnt_idx]) &&
                                    (fu_avail_gnt_bus.add_fu_gnts[fu_gnt_idx])) begin

                                    /* Find the index of the reservation station and the functional unit available */
                                    if (rs_gnt_bus.add_inst_gnts[fu_gnt_idx][gnt_bus_stations_i] &&
                                        fu_avail_gnt_bus.add_fu_gnts[fu_gnt_idx][func_unit_idx]) begin

                                        rs_to_func.types.adders[func_unit_idx] = {
                                            `TRUE,
                                            stations[gnt_bus_stations_i].op1_value,
                                            stations[gnt_bus_stations_i].op2_value,
                                            stations[gnt_bus_stations_i].dest_arf,
                                            stations[gnt_bus_stations_i].dest_prf,
                                            stations[gnt_bus_stations_i].rob_entry,
                                            stations[gnt_bus_stations_i].offset,
                                            stations[gnt_bus_stations_i].pc,
                                            stations[gnt_bus_stations_i].lsq_index,
                                            stations[gnt_bus_stations_i].func_op_type
                                        };
                                        /* Invalidate the station for the next cycle */
                                        n_stations[gnt_bus_stations_i].valid = `FALSE;
                                    end
                                end
                            end
                            MULT: begin
                                /* If there exists a ready station (for the given unit) and an availible funcitonal unit */
                                if ((rs_gnt_bus.mult_inst_gnts[fu_gnt_idx]) &&
                                    (fu_avail_gnt_bus.mult_fu_gnts[fu_gnt_idx])) begin

                                    /* Find the index of the reservation station and the functional unit available */
                                    if (rs_gnt_bus.mult_inst_gnts[fu_gnt_idx][gnt_bus_stations_i] &&
                                        fu_avail_gnt_bus.mult_fu_gnts[fu_gnt_idx][func_unit_idx]) begin

                                        rs_to_func.types.mults[func_unit_idx] = {
                                            `TRUE,
                                            stations[gnt_bus_stations_i].op1_value,
                                            stations[gnt_bus_stations_i].op2_value,
                                            stations[gnt_bus_stations_i].dest_arf,
                                            stations[gnt_bus_stations_i].dest_prf,
                                            stations[gnt_bus_stations_i].rob_entry,
                                            stations[gnt_bus_stations_i].offset,
                                            stations[gnt_bus_stations_i].pc,
                                            stations[gnt_bus_stations_i].lsq_index,
                                            stations[gnt_bus_stations_i].func_op_type
                                        };
                                        /* Invalidate the station for the next cycle */
                                        n_stations[gnt_bus_stations_i].valid = `FALSE;
                                    end
                                end
                            end
                            BRANCH: begin
                                /* If there exists a ready station (for the given unit) and an availible funcitonal unit */
                                if ((rs_gnt_bus.branch_inst_gnts[fu_gnt_idx]) &&
                                    (fu_avail_gnt_bus.branch_fu_gnts[fu_gnt_idx])) begin

                                    /* Find the index of the reservation station and the functional unit available */
                                    if (rs_gnt_bus.branch_inst_gnts[fu_gnt_idx][gnt_bus_stations_i] &&
                                        fu_avail_gnt_bus.branch_fu_gnts[fu_gnt_idx][func_unit_idx]) begin

                                        rs_to_func.types.branches[func_unit_idx] = {
                                            `TRUE,
                                            stations[gnt_bus_stations_i].op1_value,
                                            stations[gnt_bus_stations_i].op2_value,
                                            stations[gnt_bus_stations_i].dest_arf,
                                            stations[gnt_bus_stations_i].dest_prf,
                                            stations[gnt_bus_stations_i].rob_entry,
                                            stations[gnt_bus_stations_i].offset,
                                            stations[gnt_bus_stations_i].pc,
                                            stations[gnt_bus_stations_i].lsq_index,
                                            stations[gnt_bus_stations_i].func_op_type
                                        };
                                        /* Invalidate the station for the next cycle */
                                        n_stations[gnt_bus_stations_i].valid = `FALSE;
                                    end
                                end
                            end
                            MEM: begin
                                /* If there exists a ready station (for the given unit) and an availible funcitonal unit */
                                if ((rs_gnt_bus.mem_inst_gnts[fu_gnt_idx]) &&
                                    (fu_avail_gnt_bus.mem_fu_gnts[fu_gnt_idx])) begin

                                    /* Find the index of the reservation station and the functional unit available */
                                    if (rs_gnt_bus.mem_inst_gnts[fu_gnt_idx][gnt_bus_stations_i] &&
                                        fu_avail_gnt_bus.mem_fu_gnts[fu_gnt_idx][func_unit_idx]) begin

                                        rs_to_func.types.mems[func_unit_idx] = {
                                            `TRUE,
                                            stations[gnt_bus_stations_i].op1_value,
                                            stations[gnt_bus_stations_i].op2_value,
                                            stations[gnt_bus_stations_i].dest_arf,
                                            stations[gnt_bus_stations_i].dest_prf,
                                            stations[gnt_bus_stations_i].rob_entry,
                                            stations[gnt_bus_stations_i].offset,
                                            stations[gnt_bus_stations_i].pc,
                                            stations[gnt_bus_stations_i].lsq_index,
                                            stations[gnt_bus_stations_i].func_op_type
                                        };

                                        /* Invalidate the station for the next cycle */
                                        n_stations[gnt_bus_stations_i].valid = `FALSE;
                                    end
                                end
                            end
                        endcase
                    end
                end
            end
        end
    end

    /* Check if first num entries of gnt_bus has a one */
    assign rs_full = !(gnt_bus[`N-1]);

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset)
            stations <= `SD 0;
		else begin
            stations <= `SD n_stations;
        end
	end

endmodule
