// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: mage_axi_wrapper.sv
// Author: Lorenzo Romano
// Date: 02/02/2026
// Description: Wrapper for Mage converting OBI/reg to AXI interface for CVA6-Ariane communication

`include "axi/typedef.svh"

import agu_pkg::*;
import xbar_pkg::*;
import pea_pkg::*;
import reg_pkg::*;
import obi_pkg::*;

/// Default AXI payload definitions when instantiated as standalone or top
`AXI_TYPEDEF_ALL_CT(default_axi, default_axi_req_t, default_axi_rsp_t, logic [31:0], logic [0:0], logic [31:0], logic [3:0], logic [0:0])

/// Wrapper converting Mage memory and control interfaces into standard AXI4+ATOP ports.
module mage_axi_wrapper #(
  /// AXI Address Width
  parameter int unsigned AxiAddrWidth = 32,
  /// AXI Data Width
  parameter int unsigned AxiDataWidth = 32,
  /// AXI ID Width (minimum 1 to avoid negative vector ranges)
  parameter int unsigned AxiIdWidth   = 1,
  /// AXI User Width
  parameter int unsigned AxiUserWidth = 1,
  /// Maximum outstanding transactions
  parameter int unsigned MaxTrans     = 1,
  /// The request struct of the AXI port
  parameter type         axi_req_t    = default_axi_req_t,
  /// The response struct of the AXI port
  parameter type         axi_rsp_t    = default_axi_rsp_t
) (
  /// Clock input
  input  logic     clk_i,
  /// Asynchronous reset, active low
  input  logic     rst_ni,

  /// AXI4 interface for data stream (DAE mode), request input
  input  axi_req_t axi_req_i,
  /// AXI4 interface for data stream (DAE mode), response output
  output axi_rsp_t axi_rsp_o,

  /// Mage interrupt output
  output logic     mage_intr_o,

  /// AXI4 interface for register configuration, request input
  input  axi_req_t axi_ctrl_req_i,
  /// AXI4 interface for register configuration, response output
  output axi_rsp_t axi_ctrl_rsp_o
);

  /////////////////////////
  //  OBI Structs & Net  //
  /////////////////////////

  /// OBI Channel A Optional Payload (matching ObiMinimalOptionalConfig user widths)
  typedef struct packed {
    logic [0:0] auser;
    logic [0:0] wuser;
  } bridge_obi_a_optional_t;

  /// OBI Channel A Payload
  typedef struct packed {
    logic [31:0]            addr;
    logic [31:0]            wdata;
    logic                   we;
    logic [3:0]             be;
    logic [0:0]             aid;
    bridge_obi_a_optional_t a_optional;
  } bridge_obi_a_chan_t;

  /// OBI Request
  typedef struct packed {
    logic               req;
    bridge_obi_a_chan_t a;
  } bridge_obi_req_t;

  /// OBI Channel R Optional Payload
  typedef struct packed {
    logic [0:0] ruser;
  } bridge_obi_r_optional_t;

  /// OBI Channel R Payload
  typedef struct packed {
    logic [31:0]            rdata;
    logic [0:0]             rid;
    logic                   err;
    bridge_obi_r_optional_t r_optional;
  } bridge_obi_r_chan_t;

  /// OBI Response
  typedef struct packed {
    logic               gnt;
    logic               rvalid;
    bridge_obi_r_chan_t r;
  } bridge_obi_rsp_t;

  bridge_obi_req_t bridge_req;
  bridge_obi_rsp_t bridge_rsp;

  /////////////////////////
  //  REG Structs & Net  //
  /////////////////////////

  /// Bridge Register Interface Request (aligned to reg_pkg::reg_req_t order)
  typedef struct packed {
    logic        valid;
    logic        write;
    logic [3:0]  wstrb;
    logic [31:0] addr;
    logic [31:0] wdata;
  } bridge_reg_req_t;

  /// Bridge Register Interface Response (aligned to reg_pkg::reg_rsp_t order)
  typedef struct packed {
    logic        error;
    logic        ready;
    logic [31:0] rdata;
  } bridge_reg_rsp_t;

  bridge_reg_req_t bridge_reg_req;
  bridge_reg_rsp_t bridge_reg_rsp;

  /////////////////////////
  //  Mage Core Signals  //
  /////////////////////////

  obi_pkg::obi_req_t   mage_obi_req_i;
  obi_pkg::obi_resp_t  mage_obi_resp_o;

  reg_pkg::reg_req_t   mage_reg_req_i;
  reg_pkg::reg_rsp_t   mage_reg_rsp_o;

  mage_wrapper mage_wrapper_inst (
    .clk_i        (clk_i),
    .rst_n_i      (rst_ni),
    .slave_req_i  (mage_obi_req_i),
    .slave_resp_o (mage_obi_resp_o),
    .mage_intr_o  (mage_intr_o),
    .reg_req_i    (mage_reg_req_i),
    .reg_rsp_o    (mage_reg_rsp_o)
  );

  /////////////////////////
  //  AXI to OBI Bridge  //
  /////////////////////////

  localparam obi_pkg::obi_cfg_t BridgeObiCfg = '{
    UseRReady:   1'b0,
    CombGnt:     1'b0,
    AddrWidth:   32,
    DataWidth:   32,
    IdWidth:     1,
    Integrity:   1'b0,
    BeFull:      1'b0,
    OptionalCfg: obi_pkg::ObiMinimalOptionalConfig
  };

  axi_to_obi #(
    .ObiCfg       (BridgeObiCfg),
    .obi_req_t    (bridge_obi_req_t),
    .obi_rsp_t    (bridge_obi_rsp_t),
    .obi_a_chan_t (bridge_obi_a_chan_t),
    .obi_r_chan_t (bridge_obi_r_chan_t),
    .AxiAddrWidth (AxiAddrWidth),
    .AxiDataWidth (AxiDataWidth),
    .AxiIdWidth   (AxiIdWidth),
    .AxiUserWidth (AxiUserWidth),
    .MaxTrans     (MaxTrans),
    .axi_req_t    (axi_req_t),
    .axi_rsp_t    (axi_rsp_t)
  ) i_axi_to_obi (
    .clk_i                 (clk_i),
    .rst_ni                (rst_ni),
    .testmode_i            (1'b0),
    .axi_req_i             (axi_req_i),
    .axi_rsp_o             (axi_rsp_o),
    .obi_req_o             (bridge_req),
    .obi_rsp_i             (bridge_rsp),
    .req_aw_id_o           (),
    .req_aw_user_o         (),
    .req_w_user_o          (),
    .req_write_aid_i       ('0),
    .req_write_auser_i     ('0),
    .req_write_wuser_i     ('0),
    .req_ar_id_o           (),
    .req_ar_user_o         (),
    .req_read_aid_i        ('0),
    .req_read_auser_i      ('0),
    .rsp_write_aw_user_o   (),
    .rsp_write_w_user_o    (),
    .rsp_write_bank_strb_o (),
    .rsp_write_rid_o       (),
    .rsp_write_ruser_o     (),
    .rsp_write_last_o      (),
    .rsp_write_hs_o        (),
    .rsp_b_user_i          ('0),
    .rsp_read_ar_user_o    (),
    .rsp_read_size_enable_o(),
    .rsp_read_rid_o        (),
    .rsp_read_ruser_o      (),
    .rsp_r_user_i          ('0)
  );

  /////////////////////////
  //  AXI to Reg Bridge  //
  /////////////////////////

  axi_to_reg_v2 #(
    .AxiAddrWidth (AxiAddrWidth),
    .AxiDataWidth (AxiDataWidth),
    .AxiIdWidth   (AxiIdWidth),
    .AxiUserWidth (AxiUserWidth),
    .RegDataWidth (32),
    .CutMemReqs   (1'b1),
    .CutMemRsps   (1'b1),
    .axi_req_t    (axi_req_t),
    .axi_rsp_t    (axi_rsp_t),
    .reg_req_t    (bridge_reg_req_t),
    .reg_rsp_t    (bridge_reg_rsp_t)
  ) i_axi_to_reg (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .axi_req_i    (axi_ctrl_req_i),
    .axi_rsp_o    (axi_ctrl_rsp_o),
    .reg_req_o    (bridge_reg_req),
    .reg_rsp_i    (bridge_reg_rsp),
    .reg_id_o     (),
    .busy_o       ()
  );

  ///////////////////////////////////////
  //  Interface Multiplexing & Wiring  //
  ///////////////////////////////////////

  // From bridge to Mage (OBI)
  assign mage_obi_req_i.req   = bridge_req.req;
  assign mage_obi_req_i.we    = bridge_req.a.we;
  assign mage_obi_req_i.be    = bridge_req.a.be;
  assign mage_obi_req_i.addr  = bridge_req.a.addr;
  assign mage_obi_req_i.wdata = bridge_req.a.wdata;

  // From Mage to bridge (OBI)
  assign bridge_rsp.gnt                 = mage_obi_resp_o.gnt;
  assign bridge_rsp.rvalid              = mage_obi_resp_o.rvalid;
  assign bridge_rsp.r.rdata             = mage_obi_resp_o.rdata;
  assign bridge_rsp.r.err               = 1'b0;
  assign bridge_rsp.r.rid               = 1'b0;
  assign bridge_rsp.r.r_optional.ruser  = 1'b0;

  // From bridge to Mage (REG)
  assign mage_reg_req_i.valid = bridge_reg_req.valid;
  assign mage_reg_req_i.write = bridge_reg_req.write;
  assign mage_reg_req_i.wstrb = bridge_reg_req.wstrb;
  assign mage_reg_req_i.addr  = bridge_reg_req.addr;
  assign mage_reg_req_i.wdata = bridge_reg_req.wdata;

  // From Mage to bridge (REG)
  assign bridge_reg_rsp.ready = mage_reg_rsp_o.ready;
  assign bridge_reg_rsp.error = mage_reg_rsp_o.error;
  assign bridge_reg_rsp.rdata = mage_reg_rsp_o.rdata;

endmodule : mage_axi_wrapper