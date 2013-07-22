/**
 * This file is part of OpTiMSoC.
 *
 * OpTiMSoC is free hardware: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * As the LGPL in general applies to software, the meaning of
 * "linking" is defined as using OpTiMSoC in your projects at
 * the external interfaces.
 *
 * OpTiMSoC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with OpTiMSoC. If not, see <http://www.gnu.org/licenses/>.
 *
 * =================================================================
 *
 * The top-level debug system module.
 *
 * This module is a fully configurable top-level for a debug system, which can
 * be configured using parameters and defines. In general the defines enable
 * or disable a feature completely, parameters can be used to specify the number
 * of modules or configure features.
 *
 * (c) 2012-2013 by the author(s)
 *
 * Author(s):
 *    Philipp Wagner, mail@philipp-wagner.com
 *    Stefan Wallentowitz, stefan.wallentowitz@tum.de
 */

`include "dbg_config.vh"

`include "lisnoc_def.vh"
`include "lisnoc16_def.vh"

`include "optimsoc_def.vh"

module debug_system(
`ifdef OPTIMSOC_DEBUG_ENABLE_NCM
                    noc32_in_ready, noc32_out_flit, noc32_out_valid,
                    noc32_in_flit, noc32_in_valid, noc32_out_ready,
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
                    itm_ports_flat,
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_STM
                    stm_ports_flat,
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_NRM
                    nrm_ports_flat,
`endif
`ifdef OPTIMSOC_CLOCKDOMAINS
`ifdef OPTIMSOC_DEBUG_ENABLE_STM
                    clk_itm,
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
                    clk_stm,
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_NCM
                    clk_ncm,
`endif
`endif
   /*AUTOARG*/
   // Outputs
   dbgnoc_in_ready, dbgnoc_out_flit, dbgnoc_out_valid,
   sys_clk_disable, cpu_stall, cpu_reset, start_cpu,
   // Inputs
   clk, rst, dbgnoc_in_flit, dbgnoc_in_valid, dbgnoc_out_ready,
   sys_clk_is_halted
   );

   // ITM: number of debugged CPU cores
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
   parameter DEBUG_ITM_CORE_COUNT = 'bx;
`else
   parameter DEBUG_ITM_CORE_COUNT = 0;
`endif

   // STM: number of debugged CPU cores
`ifdef OPTIMSOC_DEBUG_ENABLE_STM
   parameter DEBUG_STM_CORE_COUNT = 'bx;
`else
   parameter DEBUG_STM_CORE_COUNT = 0;
`endif

   // NRM: number of monitored LISNoC routers
`ifdef OPTIMSOC_DEBUG_ENABLE_NRM
   parameter DEBUG_NRM_COUNT = 'bx;
`else
   parameter DEBUG_NRM_COUNT = 0;
`endif

   // NRM: monitored links per router
`ifdef OPTIMSOC_DEBUG_ENABLE_NRM
   parameter DEBUG_NRM_LINKS_PER_ROUTER = 'bx;
`else
   parameter DEBUG_NRM_LINKS_PER_ROUTER = 0;
`endif

`ifdef OPTIMSOC_DEBUG_ENABLE_NCM
   parameter DEBUG_NCM_COUNT = 1;
   parameter OPTIMSOC_DEBUG_NCM_ID = 'bx;
`else
   parameter DEBUG_NCM_COUNT = 0;
`endif

`ifdef OPTIMSOC_DEBUG_ENABLE_CTM
   parameter DEBUG_CTM_COUNT = 'bx;
`else
   parameter DEBUG_CTM_COUNT = 0;
`endif

   parameter SYSTEM_IDENTIFIER = 'bx;

   // NoC interface (32 bit flit payload, aka lisnoc)
   parameter NOC_FLIT_DATA_WIDTH = 32;
   parameter NOC_FLIT_TYPE_WIDTH = 2;
   localparam NOC_FLIT_WIDTH = NOC_FLIT_DATA_WIDTH + NOC_FLIT_TYPE_WIDTH;

   // TODO: only relevant for NCM
   parameter NOC_VCHANNELS = 3;
   parameter NOC_USED_VCHANNEL = 0;

   // Debug NoC interface (16 bit flit payload, aka lisnoc16)
   parameter DBG_NOC_DATA_WIDTH = `FLIT16_CONTENT_WIDTH;
   parameter DBG_NOC_FLIT_TYPE_WIDTH = `FLIT16_TYPE_WIDTH;
   localparam DBG_NOC_FLIT_WIDTH = DBG_NOC_DATA_WIDTH + DBG_NOC_FLIT_TYPE_WIDTH;
   parameter DBG_NOC_PH_DEST_WIDTH = `FLIT16_DEST_WIDTH;
   parameter DBG_NOC_PH_CLASS_WIDTH = `PACKET16_CLASS_WIDTH;
   localparam DBG_NOC_PH_ID_WIDTH = DBG_NOC_DATA_WIDTH - DBG_NOC_PH_DEST_WIDTH - DBG_NOC_PH_CLASS_WIDTH;
   parameter DBG_NOC_VCHANNELS = 1;
   parameter DBG_NOC_USED_VCHANNEL = 0;

   // Debug NoC router FIFO length
   parameter DBG_NOC_ROUTER_IN_FIFO_LENGTH = 4;
   parameter DBG_NOC_ROUTER_OUT_FIFO_LENGTH = 4;

   /*
    * Number of routers in the Debug NoC
    * - 1 x External Interface
    * - 1 x TCM
    * - 1 x CTM (optional)
    * - DEBUG_NCM_COUNT x NCM (1 or zero)
    * - DEBUG_ITM_CORE_COUNT x ITM
    * - DEBUG_STM_CORE_COUNT x STM
    * - DEBUG_NRM_COUNT x NRM
    */
   localparam DBG_NOC_ROUTER_COUNT = 2 +
                                     DEBUG_NCM_COUNT +
                                     DEBUG_CTM_COUNT +
                                     DEBUG_ITM_CORE_COUNT +
                                     DEBUG_STM_CORE_COUNT +
                                     DEBUG_NRM_COUNT;

   input    clk;
   input    rst;

   // Debug NoC connection to the "outside world".
   input [DBG_NOC_FLIT_WIDTH-1:0]   dbgnoc_in_flit;
   input [DBG_NOC_VCHANNELS-1:0]    dbgnoc_in_valid;
   output [DBG_NOC_VCHANNELS-1:0]   dbgnoc_in_ready;
   output [DBG_NOC_FLIT_WIDTH-1:0]  dbgnoc_out_flit;
   output [DBG_NOC_VCHANNELS-1:0]   dbgnoc_out_valid;
   input [DBG_NOC_VCHANNELS-1:0]    dbgnoc_out_ready;

   // NoC interface. Connect this to an external module of a system.
   // It allows bi-directional communication between the regular NoC and the
   // Debug NoC.
`ifdef OPTIMSOC_DEBUG_ENABLE_NCM
   input [NOC_FLIT_WIDTH-1:0]   noc32_in_flit;
   input [NOC_VCHANNELS-1:0]    noc32_in_valid;
   output [NOC_VCHANNELS-1:0]   noc32_in_ready;
   output [NOC_FLIT_WIDTH-1:0]  noc32_out_flit;
   output [NOC_VCHANNELS-1:0]   noc32_out_valid;
   input [NOC_VCHANNELS-1:0]    noc32_out_ready;

   wire [NOC_FLIT_WIDTH-1:0]    noc32_in_flit_cdc;
   wire [NOC_VCHANNELS-1:0]     noc32_in_valid_cdc;
   wire [NOC_VCHANNELS-1:0]     noc32_in_ready_cdc;
   wire [NOC_FLIT_WIDTH-1:0]    noc32_out_flit_cdc;
   wire [NOC_VCHANNELS-1:0]     noc32_out_valid_cdc;
   wire [NOC_VCHANNELS-1:0]     noc32_out_ready_cdc;
 `ifdef OPTIMSOC_CLOCKDOMAINS
   input                        clk_ncm;
 `endif
`endif

   // ITM: CPU core debugging interface
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
   input [DEBUG_ITM_CORE_COUNT*`DEBUG_ITM_PORTWIDTH-1:0] itm_ports_flat;
 `ifdef OPTIMSOC_CLOCKDOMAINS
   input [DEBUG_ITM_CORE_COUNT-1:0]                      clk_itm;
 `endif
`endif

   // STM: CPU core debugging interface
`ifdef OPTIMSOC_DEBUG_ENABLE_STM
   input [DEBUG_STM_CORE_COUNT*`DEBUG_STM_PORTWIDTH-1:0] stm_ports_flat;
 `ifdef OPTIMSOC_CLOCKDOMAINS
   input [DEBUG_ITM_CORE_COUNT-1:0]                      clk_stm;
 `endif
`endif

   // NRM: NoC Router data
   // Connect these signals to a link of a LISNoC router for monitoring those
   // links.
`ifdef OPTIMSOC_DEBUG_ENABLE_NRM
   input [DEBUG_NRM_COUNT*DEBUG_NRM_LINKS_PER_ROUTER*DEBUG_NRM_PORTWIDTH-1:0] nrm_ports_flat;
`endif

   // disable (halt) system clock
   output sys_clk_disable;
   input  sys_clk_is_halted;
   // the individual sys_clk_disable signals for the submodules
   wire [DEBUG_ITM_CORE_COUNT+DEBUG_STM_CORE_COUNT+DEBUG_NRM_COUNT-1:0] sys_clk_disable_sub;
`ifdef OPTIMSOC_DEBUG_NO_CLOCK_GATING
   assign sys_clk_disable = 0;
`else
   assign sys_clk_disable =| sys_clk_disable_sub;
`endif

   // CPU control
   output cpu_stall;
   output cpu_reset;
   output start_cpu;

   // wires to connect modules to the local ports of the Debug NoC routers
   wire [DBG_NOC_ROUTER_COUNT*DBG_NOC_FLIT_WIDTH-1:0] dbg_link_in_flit;
   wire [DBG_NOC_ROUTER_COUNT*DBG_NOC_VCHANNELS-1:0]  dbg_link_in_valid;
   wire [DBG_NOC_ROUTER_COUNT*DBG_NOC_VCHANNELS-1:0]  dbg_link_in_ready;
   wire [DBG_NOC_ROUTER_COUNT*DBG_NOC_FLIT_WIDTH-1:0] dbg_link_out_flit;
   wire [DBG_NOC_ROUTER_COUNT*DBG_NOC_VCHANNELS-1:0]  dbg_link_out_valid;
   wire [DBG_NOC_ROUTER_COUNT*DBG_NOC_VCHANNELS-1:0]  dbg_link_out_ready;

   // global timestamp
   wire [`DBG_TIMESTAMP_WIDTH-1:0] timestamp;

   // Global Timestamp Provider (GTS)
   global_timestamp_provider
      u_gts(.clk(clk),
            .rst(rst),
            .timestamp(timestamp));

   // Debug NoC: a uni-directional ring with DBG_NOC_ROUTER_COUNT routers
   lisnoc_uni_ring
      #(.routers(DBG_NOC_ROUTER_COUNT),
        .flit_data_width(DBG_NOC_DATA_WIDTH),
        .flit_type_width(DBG_NOC_FLIT_TYPE_WIDTH),
        .ph_dest_width(DBG_NOC_PH_DEST_WIDTH),
        .vchannels(DBG_NOC_VCHANNELS),
        .router_in_fifo_length(DBG_NOC_ROUTER_IN_FIFO_LENGTH),
        .router_out_fifo_length(DBG_NOC_ROUTER_OUT_FIFO_LENGTH))
      u_dbg_ring (.clk(clk),
                  .rst(rst),

                  .local_out_flit(dbg_link_out_flit),
                  .local_out_valid(dbg_link_out_valid),
                  .local_out_ready(dbg_link_out_ready),
                  .local_in_flit(dbg_link_in_flit),
                  .local_in_valid(dbg_link_in_valid),
                  .local_in_ready(dbg_link_in_ready));

   // External interface
   // Debug NoC address: `DBG_NOC_ADDR_EXTERNALIF
   // The local port of the router are simply routed out of this module for
   // connection to the USB interface.
   assign dbg_link_in_flit[((`DBG_NOC_ADDR_EXTERNALIF+1)*DBG_NOC_FLIT_WIDTH)-1:`DBG_NOC_ADDR_EXTERNALIF*DBG_NOC_FLIT_WIDTH] = dbgnoc_in_flit[DBG_NOC_FLIT_WIDTH-1:0];
   assign dbg_link_in_valid[((`DBG_NOC_ADDR_EXTERNALIF+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_EXTERNALIF*DBG_NOC_VCHANNELS] = dbgnoc_in_valid[DBG_NOC_VCHANNELS-1:0];
   assign dbgnoc_in_ready[DBG_NOC_VCHANNELS-1:0] = dbg_link_in_ready[((`DBG_NOC_ADDR_EXTERNALIF+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_EXTERNALIF*DBG_NOC_VCHANNELS];
   assign dbgnoc_out_flit[DBG_NOC_FLIT_WIDTH-1:0] = dbg_link_out_flit[((`DBG_NOC_ADDR_EXTERNALIF+1)*DBG_NOC_FLIT_WIDTH)-1:`DBG_NOC_ADDR_EXTERNALIF*DBG_NOC_FLIT_WIDTH];
   assign dbgnoc_out_valid[DBG_NOC_VCHANNELS-1:0] = dbg_link_out_valid[((`DBG_NOC_ADDR_EXTERNALIF+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_EXTERNALIF*DBG_NOC_VCHANNELS];
   assign dbg_link_out_ready[((`DBG_NOC_ADDR_EXTERNALIF+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_EXTERNALIF*DBG_NOC_VCHANNELS] = dbgnoc_out_ready[DBG_NOC_VCHANNELS-1:0];

   // TCM
   // Debug NoC address: `DBG_NOC_ADDR_TCM
   tcm
      #(.SYSTEM_IDENTIFIER(SYSTEM_IDENTIFIER),
        .MODULE_COUNT(DEBUG_ITM_CORE_COUNT + DEBUG_STM_CORE_COUNT + DEBUG_NRM_COUNT + DEBUG_CTM_COUNT + DEBUG_NCM_COUNT))
      u_tcm(.clk(clk),
            .rst(rst),
            .sys_clk_is_halted(sys_clk_is_halted),

            .dbgnoc_out_flit(dbg_link_in_flit[((`DBG_NOC_ADDR_TCM+1)*DBG_NOC_FLIT_WIDTH)-1:`DBG_NOC_ADDR_TCM*DBG_NOC_FLIT_WIDTH]),
            .dbgnoc_out_valid(dbg_link_in_valid[((`DBG_NOC_ADDR_TCM+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_TCM*DBG_NOC_VCHANNELS]),
            .dbgnoc_out_ready(dbg_link_in_ready[((`DBG_NOC_ADDR_TCM+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_TCM*DBG_NOC_VCHANNELS]),

            .dbgnoc_in_flit(dbg_link_out_flit[((`DBG_NOC_ADDR_TCM+1)*DBG_NOC_FLIT_WIDTH)-1:`DBG_NOC_ADDR_TCM*DBG_NOC_FLIT_WIDTH]),
            .dbgnoc_in_valid(dbg_link_out_valid[((`DBG_NOC_ADDR_TCM+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_TCM*DBG_NOC_VCHANNELS]),
            .dbgnoc_in_ready(dbg_link_out_ready[((`DBG_NOC_ADDR_TCM+1)*DBG_NOC_VCHANNELS)-1:`DBG_NOC_ADDR_TCM*DBG_NOC_VCHANNELS]),

            .start_cpu(start_cpu),
            .cpu_stall(cpu_stall),
            .cpu_reset(cpu_reset));

   localparam DBG_NOC_ADDR_CTM = `DBG_NOC_ADDR_DYN_START;
   localparam DBG_NOC_ADDR_NCM = DBG_NOC_ADDR_CTM + DEBUG_CTM_COUNT;
   localparam DBG_NOC_ADDR_ITM = DBG_NOC_ADDR_NCM + DEBUG_NCM_COUNT;
   localparam DBG_NOC_ADDR_STM = DBG_NOC_ADDR_ITM + DEBUG_ITM_CORE_COUNT;
   localparam DBG_NOC_ADDR_NRM = DBG_NOC_ADDR_STM + DEBUG_STM_CORE_COUNT;

   // CTM
`ifdef OPTIMSOC_DEBUG_ENABLE_CTM
   ctm
      u_ctm(.clk(clk),
            .rst(rst),

            .dbgnoc_out_flit  (dbg_link_in_flit[((DBG_NOC_ADDR_CTM+1)*DBG_NOC_FLIT_WIDTH)-1:DBG_NOC_ADDR_CTM*DBG_NOC_FLIT_WIDTH]),
            .dbgnoc_out_valid (dbg_link_in_valid[((DBG_NOC_ADDR_CTM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_CTM*DBG_NOC_VCHANNELS]),
            .dbgnoc_out_ready (dbg_link_in_ready[((DBG_NOC_ADDR_CTM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_CTM*DBG_NOC_VCHANNELS]),

            .dbgnoc_in_flit   (dbg_link_out_flit[((DBG_NOC_ADDR_CTM+1)*DBG_NOC_FLIT_WIDTH)-1:DBG_NOC_ADDR_CTM*DBG_NOC_FLIT_WIDTH]),
            .dbgnoc_in_valid  (dbg_link_out_valid[((DBG_NOC_ADDR_CTM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_CTM*DBG_NOC_VCHANNELS]),
            .dbgnoc_in_ready  (dbg_link_out_ready[((DBG_NOC_ADDR_CTM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_CTM*DBG_NOC_VCHANNELS]));
`endif //  `ifdef OPTIMSOC_DEBUG_ENABLE_CTM

`ifdef OPTIMSOC_DEBUG_ENABLE_NCM
   ncm
      #(.LISNOC32_EXT_IF_ADDR(OPTIMSOC_DEBUG_NCM_ID))
   u_ncm(.clk(clk),
         .rst(rst),
         .sys_clk_is_halted(sys_clk_is_halted),

         .dbgnoc_out_flit  (dbg_link_in_flit[((DBG_NOC_ADDR_NCM+1)*DBG_NOC_FLIT_WIDTH)-1:DBG_NOC_ADDR_NCM*DBG_NOC_FLIT_WIDTH]),
         .dbgnoc_out_valid (dbg_link_in_valid[((DBG_NOC_ADDR_NCM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_NCM*DBG_NOC_VCHANNELS]),
         .dbgnoc_out_ready (dbg_link_in_ready[((DBG_NOC_ADDR_NCM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_NCM*DBG_NOC_VCHANNELS]),

         .dbgnoc_in_flit   (dbg_link_out_flit[((DBG_NOC_ADDR_NCM+1)*DBG_NOC_FLIT_WIDTH)-1:DBG_NOC_ADDR_NCM*DBG_NOC_FLIT_WIDTH]),
         .dbgnoc_in_valid  (dbg_link_out_valid[((DBG_NOC_ADDR_NCM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_NCM*DBG_NOC_VCHANNELS]),
         .dbgnoc_in_ready  (dbg_link_out_ready[((DBG_NOC_ADDR_NCM+1)*DBG_NOC_VCHANNELS)-1:DBG_NOC_ADDR_NCM*DBG_NOC_VCHANNELS]),

         .noc32_in_flit   (noc32_in_flit_cdc),
         .noc32_in_valid  (noc32_in_valid_cdc),
         .noc32_in_ready  (noc32_in_ready_cdc),

         .noc32_out_flit  (noc32_out_flit_cdc),
         .noc32_out_valid (noc32_out_valid_cdc),
         .noc32_out_ready (noc32_out_ready_cdc));

 `ifdef OPTIMSOC_CLOCKDOMAINS
   wire                            noc32_out_empty;
   wire [NOC_VCHANNELS-1:0]        noc32_out_fifo_valid;
   assign noc32_out_valid = {NOC_VCHANNELS{~noc32_out_empty}} & noc32_out_fifo_valid;
   wire                            noc32_out_full;
   assign noc32_out_ready_cdc = {NOC_VCHANNELS{~noc32_out_full}};

   cdc_fifo
      #(.DW(NOC_FLIT_WIDTH+NOC_VCHANNELS),
        .ADDRSIZE(2))
      u_fifo_noc32_out(// Outputs
                        .wr_full            (noc32_out_full),
                        .rd_empty           (noc32_out_empty),
                        .rd_data            ({noc32_out_fifo_valid,noc32_out_flit}),
                        // Inputs
                        .wr_clk             (clk),
                        .rd_clk             (clk_ncm),
                        .wr_rst             (~rst),
                        .rd_rst             (~rst),
                        .rd_en              (|noc32_out_ready),
                        .wr_en              (|noc32_out_valid_cdc),
                        .wr_data            ({noc32_out_valid_cdc,noc32_out_flit_cdc}));

   wire                            noc32_in_empty;
   wire [NOC_VCHANNELS-1:0]        noc32_in_fifo_valid;
   assign noc32_in_valid_cdc = {NOC_VCHANNELS{~noc32_out_empty}} & noc32_in_fifo_valid;
   wire                            noc32_in_full;
   assign noc32_in_ready = {NOC_VCHANNELS{~noc32_in_full}};

   cdc_fifo
     #(.DW                              (NOC_FLIT_WIDTH+NOC_VCHANNELS),
       .ADDRSIZE                        (2))
   u_fifo_noc32_in(// Outputs
                  .wr_full            (noc32_in_full),
                  .rd_empty           (noc32_in_empty),
                  .rd_data            ({noc32_in_fifo_valid,noc32_in_flit_cdc}),
                  // Inputs
                  .wr_clk             (clk_ncm),
                  .rd_clk             (clk),
                  .wr_rst             (~rst),
                  .rd_rst             (~rst),
                  .rd_en              (|noc32_in_ready_cdc),
                  .wr_en              (|noc32_in_valid),
                  .wr_data            ({noc32_in_valid,noc32_in_flit}));
 `else // !`ifdef OPTIMSOC_CLOCKDOMAINS
   assign noc32_out_valid     = noc32_out_valid_cdc;
   assign noc32_out_flit      = noc32_out_flit_cdc;
   assign noc32_out_ready_cdc = noc32_out_ready;

   assign noc32_in_valid_cdc = noc32_in_valid;
   assign noc32_in_flit_cdc  = noc32_in_flit;
   assign noc32_in_ready     = noc32_in_ready_cdc;
 `endif // !`ifdef OPTIMSOC_CLOCKDOMAINS
`endif

   genvar                          i;
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
   generate
      for (i=0;i<DEBUG_ITM_CORE_COUNT;i=i+1) begin : gen_itm
         // ITM for CT 0 CPU 0 (ID 0)
         // Debug NoC address: `DBG_NOC_ADDR_DYN_START
         itm
           #(.CORE_ID(i))
         u_itm(.clk(clk),
               .rst(rst),
 `ifdef OPTIMSOC_CLOCKDOMAINS
               .clk_cdc (clk_itm[i]),
 `endif
               .dbgnoc_out_flit(dbg_link_in_flit[(((DBG_NOC_ADDR_ITM+i)+1)*DBG_NOC_FLIT_WIDTH)-1:(DBG_NOC_ADDR_ITM+i)*DBG_NOC_FLIT_WIDTH]),
               .dbgnoc_out_valid(dbg_link_in_valid[(((DBG_NOC_ADDR_ITM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_ITM+i)*DBG_NOC_VCHANNELS]),
               .dbgnoc_out_ready(dbg_link_in_ready[(((DBG_NOC_ADDR_ITM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_ITM+i)*DBG_NOC_VCHANNELS]),

               .dbgnoc_in_flit(dbg_link_out_flit[(((DBG_NOC_ADDR_ITM+i)+1)*DBG_NOC_FLIT_WIDTH)-1:(DBG_NOC_ADDR_ITM+i)*DBG_NOC_FLIT_WIDTH]),
               .dbgnoc_in_valid(dbg_link_out_valid[(((DBG_NOC_ADDR_ITM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_ITM+i)*DBG_NOC_VCHANNELS]),
               .dbgnoc_in_ready(dbg_link_out_ready[(((DBG_NOC_ADDR_ITM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_ITM+i)*DBG_NOC_VCHANNELS]),

               .timestamp(timestamp),

               .trace_port(itm_ports_flat[(i+1)*`DEBUG_ITM_PORTWIDTH-1:i*`DEBUG_ITM_PORTWIDTH]),
               .sys_clk_is_halted (sys_clk_is_halted),
               .trigger_in (1'b0),

               .sys_clk_disable(sys_clk_disable_sub[i]));
      end // for (i=0;i<DEBUG_ITM_CORE_COUNT;i=i+1)
   endgenerate
`endif

`ifdef OPTIMSOC_DEBUG_ENABLE_STM
   generate
      for (i=0;i<DEBUG_STM_CORE_COUNT;i=i+1) begin : gen_stm
         stm
           #(.CORE_ID(i))
         u_stm(.clk(clk),
               .rst(rst),
 `ifdef OPTIMSOC_CLOCKDOMAINS
               .clk_cdc (clk_stm[i]),
 `endif
               .dbgnoc_out_flit(dbg_link_in_flit[(((DBG_NOC_ADDR_STM+i)+1)*DBG_NOC_FLIT_WIDTH)-1:(DBG_NOC_ADDR_STM+i)*DBG_NOC_FLIT_WIDTH]),
               .dbgnoc_out_valid(dbg_link_in_valid[(((DBG_NOC_ADDR_STM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_STM+i)*DBG_NOC_VCHANNELS]),
               .dbgnoc_out_ready(dbg_link_in_ready[(((DBG_NOC_ADDR_STM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_STM+i)*DBG_NOC_VCHANNELS]),

               .dbgnoc_in_flit(dbg_link_out_flit[(((DBG_NOC_ADDR_STM+i)+1)*DBG_NOC_FLIT_WIDTH)-1:(DBG_NOC_ADDR_STM+i)*DBG_NOC_FLIT_WIDTH]),
               .dbgnoc_in_valid(dbg_link_out_valid[(((DBG_NOC_ADDR_STM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_STM+i)*DBG_NOC_VCHANNELS]),
               .dbgnoc_in_ready(dbg_link_out_ready[(((DBG_NOC_ADDR_STM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_STM+i)*DBG_NOC_VCHANNELS]),

               .timestamp(timestamp),

               .trace_port(stm_ports_flat[(i+1)*`DEBUG_STM_PORTWIDTH-1:i*`DEBUG_STM_PORTWIDTH]),
               .sys_clk_is_halted (sys_clk_is_halted),

               .sys_clk_disable(sys_clk_disable_sub[DEBUG_ITM_CORE_COUNT+i]));
      end // for (i=0;i<DEBUG_STM_CORE_COUNT;i=i+1)
   endgenerate
`endif

`ifdef OPTIMSOC_DEBUG_ENABLE_NRM
   generate
      // NRM for all LISNoC routers (32 bit, the regular NoC)
      // Debug NoC addresses: from (`DBG_NOC_ADDR_DYN_START + 5) to (`DBG_NOC_ADDR_DYN_START + DEBUG_NRM_COUNT + 2)
      for (i = 0; i < DEBUG_NRM_COUNT; i = i + 1) begin : gen_nrm
         // unflatten signals for one router (still containing multiple links per router)
         wire [DEBUG_NRM_LINKS_PER_ROUTER*NOC_FLIT_WIDTH-1:0] flit;
         wire [DEBUG_NRM_LINKS_PER_ROUTER*NOC_VCHANNELS-1:0]  valid;
         wire [DEBUG_NRM_LINKS_PER_ROUTER*NOC_VCHANNELS-1:0]  ready;

         assign flit = monitored_noc_link_flit_flat[((i+1)*DEBUG_NRM_LINKS_PER_ROUTER*NOC_FLIT_WIDTH)-1:i*DEBUG_NRM_LINKS_PER_ROUTER*NOC_FLIT_WIDTH];
         assign valid = monitored_noc_link_valid_flat[((i+1)*DEBUG_NRM_LINKS_PER_ROUTER*NOC_VCHANNELS)-1:i*DEBUG_NRM_LINKS_PER_ROUTER*NOC_VCHANNELS];
         assign ready = monitored_noc_link_ready_flat[((i+1)*DEBUG_NRM_LINKS_PER_ROUTER*NOC_VCHANNELS)-1:i*DEBUG_NRM_LINKS_PER_ROUTER*NOC_VCHANNELS];

         nrm
            #(.ROUTER_ID(i),
              .MONITORED_LINK_COUNT(DEBUG_NRM_LINKS_PER_ROUTER))
            u_nrm(.clk(clk),
                  .rst(rst),

                  .dbgnoc_out_flit(dbg_link_in_flit[(((DBG_NOC_ADDR_NRM+i)+1)*DBG_NOC_FLIT_WIDTH)-1:(DBG_NOC_ADDR_NRM+i)*DBG_NOC_FLIT_WIDTH]),
                  .dbgnoc_out_valid(dbg_link_in_valid[(((DBG_NOC_ADDR_NRM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_NRM+i)*DBG_NOC_VCHANNELS]),
                  .dbgnoc_out_ready(dbg_link_in_ready[(((DBG_NOC_ADDR_NRM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_NRM+i)*DBG_NOC_VCHANNELS]),

                  .dbgnoc_in_flit(dbg_link_out_flit[(((DBG_NOC_ADDR_NRM+i)+1)*DBG_NOC_FLIT_WIDTH)-1:(DBG_NOC_ADDR_NRM+i)*DBG_NOC_FLIT_WIDTH]),
                  .dbgnoc_in_valid(dbg_link_out_valid[(((DBG_NOC_ADDR_NRM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_NRM+i)*DBG_NOC_VCHANNELS]),
                  .dbgnoc_in_ready(dbg_link_out_ready[(((DBG_NOC_ADDR_NRM+i)+1)*DBG_NOC_VCHANNELS)-1:(DBG_NOC_ADDR_NRM+i)*DBG_NOC_VCHANNELS]),

                  .timestamp(timestamp),
                  .sys_clk_disable(sys_clk_disable_sub[DEBUG_ITM_CORE_COUNT+DEBUG_STM_CORE_COUNT+i]),

                  .noc32_router_link_in_flit(flit),
                  .noc32_router_link_in_ready(ready),
                  .noc32_router_link_in_valid(valid));
      end
   endgenerate
`endif
endmodule
