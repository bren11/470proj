///////////////////////////////////////////////////////////////////////////
//                                                                       //
//   Modulename :  data cache controller                                 //
//                                                                       //
//  Description : This is a write through no write allocate cache. This  //
//                module assumes that the bus requests are not blocked   //
//                                                                       //
//                                                                       //
///////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module dcache (
    input clock, reset, nuke,
    
    /* Updates from memory bus */
    input  [3:0]                                    mem2proc_response,     
    input  [`MEM_DATA_BITS-1:0]                     mem2proc_data,
    input  [3:0]                                    mem2proc_tag,    

    /* Store Requests */
    input  DCACHE_DMAP_ADDR                         str_w_addr,     
    input  DCACHE_BLOCK                             str_w_data,
    input  MEM_SIZE                                 str_w_size,            // Size of store sent to memory
    input                                           str_v,

    /* Read Requests */
    input  DCACHE_DMAP_ADDR [`LSQ_NUM_LOADS-1:0]    proc2Dcache_rd_addrs,   // Load Target Address
    input                   [`LSQ_NUM_LOADS-1:0]    proc2Dcache_rd_v,       // Valid Load?

    /* Read Outputs */
    output DCACHE_BLOCK[`LSQ_NUM_LOADS-1:0]               Dcache_rd_data,        // value is memory[proc2Icache_addr]
    output logic [`LSQ_NUM_LOADS-1:0]                     Dcache_rd_hits,        // when this is high
    output logic                                          Dcache_str_accepted,   // when this is high

    /* Bus Requests */
    output BUS_COMMAND                                    proc2mem_command,      // command sent to memory
	output logic [`XLEN-1:0]                              proc2mem_addr,         // Address sent to memory
	output DCACHE_BLOCK                                   proc2mem_data,         // Data sent to memory
    output MEM_SIZE                                       proc2mem_size,         // data size sent to memory
    
    output logic                                          structural_hazard,
    output logic                                          MSHR_memory_hzd
); 

    /* Cache Parameters */
    localparam OFFSET_BITS = $clog2(`DCACHE_BLOCK_SIZE);
    localparam INDEX_BITS  = $clog2(`DCACHE_NUM_LINES);
    localparam TAG_BITS    = `DCACHE_TAG_BITS;

    /* Address Splicing */
    logic  [`LSQ_NUM_LOADS-1:0][TAG_BITS-1:0]   rd_tags;
    logic  [`LSQ_NUM_LOADS-1:0][INDEX_BITS-1:0] rd_indices;

    /* Cachemem */
    DCACHE_BLOCK [`LSQ_NUM_LOADS-1:0]                 Dcachemem_rd_data;
    logic [`LSQ_NUM_LOADS-1:0]                        Dcachemem_rd_hits;
    logic                                             str_cachemem_hit;
    DCACHE_BLOCK                                      str_cachemem_data;

    /* MHSR */
    DCACHE_DMAP_ADDR MSHR_cachemem_wr_addr;
    DCACHE_BLOCK MSHR_cachemem_wr_data;
    logic MSHR_cachemem_wr_v;
    BUS_COMMAND MSHR_proc2mem_command;
	logic [`XLEN-1:0] MSHR_proc2mem_addr;
    logic MSHR_structural_hzd;
    
    logic Dcache_str_try_write;

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                            Address Slicing                               //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    for (genvar i = 0; i < `LSQ_NUM_LOADS; ++i) begin: icache_addr_slicing
        assign rd_tags[i]    = proc2Dcache_rd_addrs[i].tag;
        assign rd_indices[i] = proc2Dcache_rd_addrs[i].index;
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                     MSHR                                 //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * MSHR
     * - This module handles the oustanding misses
     * - Allows non blocking cache
     * - Watches memory bus for incoming tag match
     * - Updates cachemem on tag match 
     */
    MSHR dcache_MSHR (
        /* Inputs */
        .clock   ( clock ), 
        .reset   ( reset | nuke ),

        .cache_access_addrs ( { str_w_addr       , proc2Dcache_rd_addrs } ),
        .cache_access_misses( {!str_cachemem_hit , ~Dcache_rd_hits      } ),
        .cache_access_v     ( { str_v            , proc2Dcache_rd_v     } ),

        .mem2proc_response  ( mem2proc_response     ),
        .mem2proc_data      ( mem2proc_data         ),
        .mem2proc_tag       ( mem2proc_tag          ),

        .mem_busy           ( Dcache_str_accepted   ),

        /* Ouputs */
        .recieved_wr_addr   ( MSHR_cachemem_wr_addr ),
        .recieved_wr_data   ( MSHR_cachemem_wr_data ),
        .recieved_wr_v      ( MSHR_cachemem_wr_v    ),

        .proc2mem_command   ( MSHR_proc2mem_command ),
        .proc2mem_addr      ( MSHR_proc2mem_addr    ),

        .structural_hzd     ( MSHR_structural_hzd   ),
        .memory_hzd         ( MSHR_memory_hzd       )
    );

    
    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                               Cache Memory                               //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    cachemem_rw #(
        .NUM_RD_PORTS   ( `DCACHE_RD_PORTS   ),  
        .NUM_WR_PORTS   ( `DCACHE_WR_PORTS   ),      
        .NUM_LINES      ( `DCACHE_NUM_LINES  ),
        .TAG_BITS       ( `DCACHE_TAG_BITS   )
    ) D_cachemem (
        /* Inputs */
        .clock   ( clock ), 
        .reset   ( reset ),
        
        .wr_en   ( { Dcache_str_accepted , MSHR_cachemem_wr_v    } ),
        .wr_addr ( { proc2mem_addr       , MSHR_cachemem_wr_addr } ), 
        .wr_data ( { proc2mem_data       , MSHR_cachemem_wr_data } ),
        .wr_size ( { DOUBLE              , DOUBLE                } ),  

        .rd_idx  ( { rd_indices          ,  str_w_addr.index } ), 
        .rd_tag  ( { rd_tags             ,  str_w_addr.tag   } ),

        /* Outputs */
        .rd_data ( { Dcachemem_rd_data , str_cachemem_data } ),
        .rd_hit  ( { Dcachemem_rd_hits , str_cachemem_hit  } )
    );

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                             Memory Bus Logic                             //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    /* Store must wait until block is a hit unless data is blocksize (8bytes) */
    assign Dcache_str_try_write = (str_cachemem_hit || (str_w_size == DOUBLE)) && str_v;

    assign structural_hazard = MSHR_structural_hzd;

    /* Prioritize Stores on memory bus over MSHR */
    always_comb begin

        /* Load cache block */
        proc2mem_command = MSHR_proc2mem_command;
	    proc2mem_addr    = MSHR_proc2mem_addr;
	    proc2mem_data    = 0;
        proc2mem_size    = DOUBLE;
        Dcache_str_accepted = `FALSE;
        
        /* Write store to mem*/
        if (Dcache_str_try_write) begin /* To make sure this is write of if address needs to be shifted based on size */
            proc2mem_command = BUS_STORE;
	        proc2mem_addr    = { str_w_addr[`XLEN-1:3] , 3'h0} ;
            proc2mem_data    = str_cachemem_data;
            Dcache_str_accepted = mem2proc_response != 0;
            case (str_w_size)
                BYTE   : proc2mem_data.byte_level[str_w_addr.offset[2:0]] = str_w_data.byte_level[0];
                HALF   : proc2mem_data.half_level[str_w_addr.offset[2:1] ] = str_w_data.half_level[0];
                WORD   : proc2mem_data.word_level[str_w_addr.offset[2]   ] = str_w_data.word_level[0];
                DOUBLE : proc2mem_data                                     = str_w_data;
            endcase
        end
    end

    //////////////////////////////////////////////////////////////////////////////
    //                                                                          //
    //                                  Forwarding                              //
    //                                                                          //
    //////////////////////////////////////////////////////////////////////////////

    /* Forward Data being written this cycle */
    /* This also removes redundant MSHR requests */
    always_comb begin

        /* Default with cachemem outputs */
        Dcache_rd_data = Dcachemem_rd_data;
        Dcache_rd_hits = Dcachemem_rd_hits & proc2Dcache_rd_v;

        /* Check for matches with stores and mem responses coming in */
        for (int i = 0; i < `LSQ_NUM_LOADS; ++i) begin: dcache_forwarding

            /* Prioritize stores in same cycle over updates from memory */
            if (str_w_addr.tag   == proc2Dcache_rd_addrs[i].tag && str_v &&  Dcache_str_accepted  &&    
                str_w_addr.index == proc2Dcache_rd_addrs[i].index) begin
                /* Forward store data  */
                Dcache_rd_hits[i] = `TRUE;

                case (str_w_size)
                    BYTE   : Dcache_rd_data[i].byte_level[str_w_addr.offset[2-:2]] = str_w_data.byte_level[0];
                    HALF   : Dcache_rd_data[i].half_level[str_w_addr.offset[2-:1]] = str_w_data.half_level[0];
                    WORD   : Dcache_rd_data[i].word_level[str_w_addr.offset[2]   ] = str_w_data.word_level[0];
                    DOUBLE : Dcache_rd_data[i]                                     = str_w_data;
                endcase

            end else if (MSHR_cachemem_wr_addr.tag   == proc2Dcache_rd_addrs[i].tag && MSHR_cachemem_wr_v &&
                         MSHR_cachemem_wr_addr.index == proc2Dcache_rd_addrs[i].index) begin 
                /* Forward MSHR data from memory response */
                Dcache_rd_hits[i] = `TRUE;
                Dcache_rd_data[i] = MSHR_cachemem_wr_data; 

            end
        end
    end


endmodule




