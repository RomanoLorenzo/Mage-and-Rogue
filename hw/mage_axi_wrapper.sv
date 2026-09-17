// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: mage_axi_wrapper.sv
// Author: Lorenzo Romano
// Date: 02/02/2026
// Description: Wrapper for Mage converting OBI/reg to AXI interface for CVA6-Ariane communication

import agu_pkg::*;
import xbar_pkg::*;
import pea_pkg::*;
import reg_pkg::*;
import obi_pkg::*;

module mage_axi_wrapper #(
    /// AXI Address Width
    //parameter int unsigned       AxiAddrWidth = ObiCfg.AddrWidth,
    parameter int unsigned AxiAddrWidth = 32,
    /// AXI Data Width
    //parameter int unsigned       AxiDataWidth = ObiCfg.DataWidth,
    parameter int unsigned AxiDataWidth = 32,
    /// AXI ID Width
    parameter int unsigned AxiIdWidth   = 0,
    /// AXI User Width
    parameter int unsigned AxiUserWidth = 0,

    parameter int unsigned MaxTrans  = 0,
    /// The request struct of the AXI port
    parameter type         axi_req_t = logic,
    /// The response struct of the AXI port
    parameter type         axi_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    /* ----- AXI interface for data ----- */
    input  axi_req_t axi_req_i,
    output axi_rsp_t axi_rsp_o,

    output logic mage_intr_o,
    /* ----- End of AXI interface for data ----- */

    /* ----- AXI interface for controls ----- */
    input  axi_req_t axi_ctrl_req_i,
    output axi_rsp_t axi_ctrl_rsp_o
    /* ----- End of AXI interface for controls ----- */
);

  /* ----- OBI2OBI structs definition ----- */
  // Channel A Payload
  typedef struct packed {
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        we;
    logic [3:0]  be;
    logic [0:0]  aid;    // Fictitious ID
  } bridge_obi_a_chan_t;

  // OBI request
  typedef struct packed {
    // Handshaking signals
    logic               req;
    // Payload
    bridge_obi_a_chan_t a;
  } bridge_obi_req_t;

  // Channel R Payload
  typedef struct packed {
    logic [31:0] rdata;
    logic [0:0]  rid;    // Fictitious ID
    logic        err;
  } bridge_obi_r_chan_t;

  // OBI response
  typedef struct packed {
    // Handshaking signals
    logic               gnt;
    logic               rvalid;
    // Payload
    bridge_obi_r_chan_t r;
  } bridge_obi_rsp_t;

  // Interconnect signals
  bridge_obi_req_t bridge_req;
  bridge_obi_rsp_t bridge_rsp;
  /* ----- End of OBI2OBI structs definition ----- */

  /* ----- REG2REG structs definition ----- */
  // Bridge's reg request (Matching typedef.svh macro order)
  typedef struct packed {
    logic [31:0] addr;
    logic        write;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        valid;
  } bridge_reg_req_t;

  // Bridge's reg response (Matching typedef.svh macro order)
  typedef struct packed {
    logic [31:0] rdata;
    logic        error;
    logic        ready;
  } bridge_reg_rsp_t;

  // Interconnect signals
  bridge_reg_req_t bridge_reg_req;
  bridge_reg_rsp_t bridge_reg_rsp;
  /* ----- End of REG2REG structs definition ----- */

  /* ----- Mage block -----*/
  obi_pkg::obi_req_t mage_obi_req_i;
  obi_pkg::obi_resp_t mage_obi_resp_o;

  reg_pkg::reg_req_t mage_reg_req_i;
  reg_pkg::reg_rsp_t mage_reg_rsp_o;

  mage_wrapper mage_wrapper_inst (
      .clk_i  (clk_i),
      .rst_n_i(rst_ni),

      /* ----- Data stream (OBI) and Interrupts ----- */
      .slave_req_i (mage_obi_req_i),
      .slave_resp_o(mage_obi_resp_o),

      // Interrupts
      .mage_intr_o(mage_intr_o),
      /* ----- End of data stream (OBI) and Interrupts ----- */

      /* ----- Control signals (reg) ----- */
      .reg_req_i(mage_reg_req_i),
      .reg_rsp_o(mage_reg_rsp_o)
      /* ----- End of control signals (reg) ----- */
  );
  /* ----- End Mage block -----*/

  // Configuration struct for the bridge
  localparam obi_pkg::obi_cfg_t bridge_obi_cfg = '{
      UseRReady: 1'b0,
      CombGnt: 1'b1,
      AddrWidth: 32,
      DataWidth: 32,
      IdWidth: 1,  // Mandatory
      Integrity: 1'b0,
      BeFull: 1'b0,
      OptionalCfg: obi_pkg::ObiMinimalOptionalConfig
  };

  /* ----- AXI2OBI bridge block ----- */
  axi_to_obi #(
      .ObiCfg(bridge_obi_cfg),

      .obi_req_t   (bridge_obi_req_t),
      .obi_rsp_t   (bridge_obi_rsp_t),
      .obi_a_chan_t(bridge_obi_a_chan_t),
      .obi_r_chan_t(bridge_obi_r_chan_t),

      .AxiAddrWidth(AxiAddrWidth),  // AXI Address Width
      .AxiDataWidth(AxiDataWidth),  // AXI Data Width
      .AxiIdWidth  (AxiIdWidth),    // AXI ID Width
      .AxiUserWidth(AxiUserWidth),  // AXI User Width
      .MaxTrans    (MaxTrans),
      .axi_req_t   (axi_req_t),     // The request struct of the AXI port
      .axi_rsp_t   (axi_rsp_t)      // The response struct of the AXI port
  ) axi_to_obi_inst (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .testmode_i(1'b0),    // Not in test mode

      .axi_req_i(axi_req_i),
      .axi_rsp_o(axi_rsp_o),

      .obi_req_o(bridge_req),
      .obi_rsp_i(bridge_rsp),

      // Combinatorial request user assignment signals.
      // If not used, assign '0 to *_i.
      .req_aw_id_o      (),
      .req_aw_user_o    (),
      .req_w_user_o     (),
      .req_write_aid_i  ('0),
      .req_write_auser_i('0),
      .req_write_wuser_i('0),

      .req_ar_id_o     (),
      .req_ar_user_o   (),
      .req_read_aid_i  ('0),
      .req_read_auser_i('0),

      .rsp_write_aw_user_o  (),
      .rsp_write_w_user_o   (),
      .rsp_write_bank_strb_o(),
      .rsp_write_rid_o      (),
      .rsp_write_ruser_o    (),
      .rsp_write_last_o     (),
      .rsp_write_hs_o       (),
      .rsp_b_user_i         ('0),

      .rsp_read_ar_user_o    (),
      .rsp_read_size_enable_o(),
      .rsp_read_rid_o        (),
      .rsp_read_ruser_o      (),
      .rsp_r_user_i          ('0)
  );
  /* ----- End of AXI2OBI bridge block ----- */

  /* ----- AXI2reg bridge block ----- */
  axi_to_reg_v2 #(
      .AxiAddrWidth(AxiAddrWidth),
      .AxiDataWidth(AxiDataWidth),
      .AxiIdWidth  (AxiIdWidth),
      .AxiUserWidth(AxiUserWidth),
      .RegDataWidth(32),                // Mage reg bus is strictly 32-bit
      .CutMemReqs  (1'b0),
      .CutMemRsps  (1'b0),
      .axi_req_t   (axi_req_t),
      .axi_rsp_t   (axi_rsp_t),
      .reg_req_t   (bridge_reg_req_t),
      .reg_rsp_t   (bridge_reg_rsp_t)
  ) axi_to_reg_inst (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .axi_req_i(axi_ctrl_req_i),
      .axi_rsp_o(axi_ctrl_rsp_o),

      .reg_req_o(bridge_reg_req),
      .reg_rsp_i(bridge_reg_rsp),

      .reg_id_o(),  // Ignored, no returned IDs
      .busy_o  ()   // Ignored
  );
  /* ----- End of AXI2reg bridge block ----- */

  // From bridge to Mage (OBI)
  assign mage_obi_req_i.req   = bridge_req.req;
  assign mage_obi_req_i.we    = bridge_req.a.we;
  assign mage_obi_req_i.be    = bridge_req.a.be;
  assign mage_obi_req_i.addr  = bridge_req.a.addr;
  assign mage_obi_req_i.wdata = bridge_req.a.wdata;

  // From Mage to Bridge (OBI)
  assign bridge_rsp.gnt       = mage_obi_resp_o.gnt;
  assign bridge_rsp.rvalid    = mage_obi_resp_o.rvalid;
  assign bridge_rsp.r.rdata   = mage_obi_resp_o.rdata;

  assign bridge_rsp.r.err     = 1'b0;  // Mage has no error BUS
  assign bridge_rsp.r.rid     = 1'b0;  // Mage manages no IDs

  // From bridge to Mage (REG)
  assign mage_reg_req_i.valid = bridge_reg_req.valid;
  assign mage_reg_req_i.write = bridge_reg_req.write;
  assign mage_reg_req_i.wstrb = bridge_reg_req.wstrb;
  assign mage_reg_req_i.addr  = bridge_reg_req.addr;
  assign mage_reg_req_i.wdata = bridge_reg_req.wdata;

  // From Mage to Bridge (REG)
  assign bridge_reg_rsp.ready = mage_reg_rsp_o.ready;
  assign bridge_reg_rsp.error = mage_reg_rsp_o.error;
  assign bridge_reg_rsp.rdata = mage_reg_rsp_o.rdata;

endmodule : mage_axi_wrapper
