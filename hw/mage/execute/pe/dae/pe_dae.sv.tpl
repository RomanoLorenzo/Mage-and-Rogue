// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: pe_dae.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module is the main building block of the Processing Element Array (PEA) for the CGRA in Decoupled Access-Execute mode

module pe_dae
  import pea_pkg::*;
(
    input  logic                                 clk_i,
    input  logic                                 rst_n_i,
    input  logic                                 start_d_i,
    input  logic [  N_INPUTS_PE-1:0][N_BITS-1:0] pe_op_i,
%if format_full == 1:
    input  logic                                 acc_match_i,
%endif
    input  logic [N_CFG_BITS_PE-1:0]             ctrl_pe_i,
%if has_delay_pe == 1:
    input  logic [   N_NEIGH_PE-1:0][N_BITS-1:0] neigh_delay_op_i,
    output logic [       N_BITS-1:0]             delay_op_o,
%endif
    output logic [       N_BITS-1:0]             pe_res_o
);
  logic                            clk_cg;

  // inputs/ouputs of FU
  logic      [         N_BITS-1:0] op_a;
  logic      [         N_BITS-1:0] op_b;
  logic      [         N_BITS-1:0] fu_out;

  // configuration signals
  logic      [LOG_N_INPUTS_PE-1:0] mux_a_sel;
  logic      [LOG_N_INPUTS_PE-1:0] mux_b_sel;
%if format_part == 1:
  logic      [                1:0] vec_mode;
%endif
  fu_instr_t                       fu_instr;
%if has_delay_pe == 1:
  delay_pe_mux_sel_t                          delay_pe_mux_sel;
  delay_pe_op_mux_sel_t                       delay_pe_op_mux_sel;
  delay_pe_mux_sel_t                          delay_fwd_sel;
  pe_mux_sel_t                                delay_in_pe_sel;
  logic                 [                1:0] delay_depth;
  // delay operands signals
  logic                 [         N_BITS-1:0] delay_op_fu;
  logic                 [         N_BITS-1:0] delay_op_fwd;
  logic                 [         N_BITS-1:0] delay_op_pe_in;
  logic                 [         N_BITS-1:0] delay_op_out;
  logic                 [3:0][    N_BITS-1:0] delay_pipe;
%endif

    // fu signals
%if has_delay_pe == 1:
    logic                                       multi_op_instr;
%endif

  ////////////////////////////////
  //     Clock-gating cell      //
  ////////////////////////////////
`ifndef VERILATOR
`ifndef FPGA
  // PE Clock-gating
  logic clk_cg_en;
  assign clk_cg_en = ~(fu_instr == NOP);
  tc_clk_gating pe_clk_gating_cell (
      .clk_i(clk_i),
      .en_i(clk_cg_en),
      .test_en_i(1'b0),
      .clk_o(clk_cg)
  );
`else
  assign clk_cg = clk_i;
`endif
`else
  assign clk_cg = clk_i;
`endif

  ////////////////////////////////
  //      PE Configuration      //
  ////////////////////////////////
  assign mux_a_sel = pe_mux_sel_t'(ctrl_pe_i[OP_A_SEL_MSB : OP_A_SEL_LSB]);
  assign mux_b_sel = pe_mux_sel_t'(ctrl_pe_i[OP_B_SEL_MSB : OP_B_SEL_LSB]);
  assign fu_instr  = fu_instr_t'(ctrl_pe_i[INSTR_SEL_MSB : INSTR_SEL_LSB]);
%if format_part == 1:
  assign vec_mode  = ctrl_pe_i[VEC_MODE_SEL_MSB : VEC_MODE_SEL_LSB];
%endif
%if has_delay_pe == 1:
  assign delay_pe_mux_sel    = delay_pe_mux_sel_t'(ctrl_pe_i[DELAY_PE_SEL_MSB : DELAY_PE_SEL_LSB]);
  assign delay_pe_op_mux_sel = delay_pe_op_mux_sel_t'(ctrl_pe_i[DELAY_PE_OP_SEL_MSB : DELAY_PE_OP_SEL_LSB]);
  assign delay_fwd_sel       = delay_pe_mux_sel_t'(ctrl_pe_i[DELAY_FWD_SEL_MSB : DELAY_FWD_SEL_LSB]);
  assign delay_in_pe_sel     = pe_mux_sel_t'(ctrl_pe_i[DELAY_IN_PE_SEL_MSB : DELAY_IN_PE_SEL_LSB]);
  assign delay_depth         = ctrl_pe_i[DELAY_DEPTH_MSB : DELAY_DEPTH_LSB];
%endif

  ////////////////////////////////
  //        PE Operands         //
  ////////////////////////////////
%if has_delay_pe == 1:
  logic [N_INPUTS_PE-1:0][N_BITS-1:0] pe_op_ext;

  always_comb begin
    pe_op_ext           = pe_op_i;
    pe_op_ext[DELAY_OP] = delay_op_fu;
  end

  assign op_a = pe_op_ext[mux_a_sel];
  assign op_b = pe_op_ext[mux_b_sel];
%else:
  assign op_a = pe_op_i[mux_a_sel];
  assign op_b = pe_op_i[mux_b_sel];
%endif

%if has_delay_pe == 1:
  ////////////////////////////////
  //  Delay Operand Selection   //
  ////////////////////////////////

  // multi_op_instr is asserted when the instruction is a multi-operand one
  assign multi_op_instr = fu_instr[4] == 1'b1;

  /*
    Selection of delay-operand to be fed to FU:
      -> it can be chosen among four input delay-operands
        -> D_UP
        -> D_LEFT
        -> D_RIGHT
        -> D_DOWN

      -> The chosen delay-operand is fed to FU
  */

  // delayed operand selection to be fed to FU:
  assign delay_op_fu    = neigh_delay_op_i[delay_pe_mux_sel];
  // delayed operand selection for forwarding:
  assign delay_op_fwd   = neigh_delay_op_i[delay_fwd_sel];
  // direct PE regular input selection to be ingested into delay channel:
  assign delay_op_pe_in = pe_op_i[delay_in_pe_sel];

  /* Output delay data selection:
    ->  delay_op_out = fu_out          if delay_pe_op_mux_sel == D_PE_RES
    ->  delay_op_out = op_a            if delay_pe_op_mux_sel == D_PE_OP_A
    ->  delay_op_out = op_b            if delay_pe_op_mux_sel == D_PE_OP_B
    ->  delay_op_out = delay_op_fwd    if delay_pe_op_mux_sel == D_DELAY_OP
    ->  delay_op_out = delay_op_pe_in  if delay_pe_op_mux_sel == D_PE_INPUT
    ->  delay_op_out = '0              else
  */
  always_comb begin
    case (delay_pe_op_mux_sel)
      D_PE_RES:   delay_op_out = fu_out;
      D_PE_OP_A:  delay_op_out = op_a;
      D_PE_OP_B:  delay_op_out = op_b;
      D_DELAY_OP: delay_op_out = delay_op_fwd;
      D_PE_INPUT: delay_op_out = delay_op_pe_in;
      default:    delay_op_out = '0;
    endcase
  end

  /*
    Delay-operand pipeline:
      -> 1 to 4 cycles configurable delay depth
  */
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_pipe <= '0;
    end else begin
      delay_pipe[0] <= delay_op_out;
      delay_pipe[1] <= delay_pipe[0];
      delay_pipe[2] <= delay_pipe[1];
      delay_pipe[3] <= delay_pipe[2];
    end
  end

  always_comb begin
    case (delay_depth)
      2'b00:   delay_op_o = delay_pipe[0];  // 1-cycle delay
      2'b01:   delay_op_o = delay_pipe[1];  // 2-cycle delay
      2'b10:   delay_op_o = delay_pipe[2];  // 3-cycle delay
      2'b11:   delay_op_o = delay_pipe[3];  // 4-cycle delay
      default: delay_op_o = delay_pipe[0];
    endcase
  end
%endif

  ////////////////////////////////
  //      Functional Unit       //
  ////////////////////////////////
%if gemm_computation == 1:
  %if format_full == 1:
    fu_dae_full_gemm fu_dae_full_gemm_i  (
        .a_i(op_a),
        .b_i(op_b),
        .acc_match_i(acc_match_i),
        .pe_res_i(pe_res_o),
        .instr_i(fu_instr),
        .res_o(fu_out)
    );
  %elif format_part == 1:
    fu_dae_part_gemm fu_dae_part_gemm_i (
        .clk_i(clk_cg),
        .rst_n_i(rst_n_i),
        .a_i(op_a),
        .b_i(op_b),
        .instr_i(fu_instr),
        .vec_mode_i(vec_mode),
        .res_o(fu_out)
    );
  %endif
%elif activation_computation == 1:
    fu_dae_full_act fu_dae_full_act (
        .clk_i(clk_cg),
        .rst_n_i(rst_n_i),
        .a_i(op_a),
        .b_i(op_b),
        .delay_sign_i(delay_op_fu[N_BITS]),
        .const_i(pe_op_i[CONSTANT]),
        .pe_res_i(pe_res_o),
        .acc_match_i(acc_match_i),
        .instr_i(fu_instr),
        .res_o(fu_out)
    );
%endif

  ////////////////////////////////
  //         PE Outputs         //
  ////////////////////////////////
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      pe_res_o <= 0;
    end else begin
      if (start_d_i) begin
        pe_res_o <= fu_out;
      end else begin
        pe_res_o <= '0;
      end
    end
  end

endmodule
