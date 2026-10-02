// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: ${name}.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: ${description}
// NOTE: Auto-generated from pe_s.tpl.sv via mage-gen.py --pe-sv. Do not edit manually.

module ${name}
  import pea_pkg::*;
(
    input  logic                                  clk_i,
    input  logic                                  rst_n_i,
    // overall done signal
    input  logic                                  mage_done_i,
    // instruction word
    input  logic [N_CFG_BITS_PE-1:0]              ctrl_pe_i,
    // RF values
    input  logic [              1:0]              reg_rf_value_i,
    input  logic [             15:0]              reg_acc_value_i,
    input  logic [       N_BITS-1:0]              reg_const_i,
    output logic                                  reg_pea_rf_de_o,
    output logic [       N_BITS-1:0]              reg_pea_rf_d_o,
    // overall PEA ready
    input  logic                                  pea_ready_i,
    %if bst_lvl != None and bst_lvl >= 1:
    <%  n_bp = 2 ** bst_lvl %>\
    input logic  [${n_bp}-1:0][       N_BITS-1:0] reg_bp_i,
    %elif bst_lvl != None and bst_lvl == 0:
    input logic  [       N_BITS-1:0]              reg_bp_i,
    %endif
    % if coeff == True:
    input logic [${n_m_coeffs}-1:0][N_BITS-1:0] reg_m_coeffs_i,
    %   if n_q_coeffs > 0:
    input logic [${n_q_coeffs}-1:0][N_BITS-1:0] reg_q_coeffs_i,
    %   endif
    % endif
    // neighbor data, delay operands and valid signals
    input  logic [  N_INPUTS_PE-4:0][N_BITS-1:0]  neigh_pe_op_i,
    input  logic [  N_INPUTS_PE-4:0]              neigh_pe_op_valid_i,
    input  logic [   N_NEIGH_PE-1:0][  N_BITS:0]  neigh_delay_op_i,
    input  logic [   N_NEIGH_PE-1:0]              neigh_delay_op_valid_i,
    // outputs
    output logic                                  valid_o,
    output logic                                  ready_o,
    output logic                                  delay_op_valid_o,
    output logic [         N_BITS:0]              delay_op_o,
    output logic [       N_BITS-1:0]              pe_res_o
);

  logic                                                clk_cg;
  // inputs to FU
  logic                  [     N_BITS-1:0]             op_a;
  logic                  [     N_BITS-1:0]             op_b;
  // mux selectors
  pe_mux_sel_t                                         mux_sel_a;
  pe_mux_sel_t                                         mux_sel_b;
% if has_part_vec_mode:
  // vector mode
  logic                  [            2:0]             part_vec_mode;
% endif
  // operands valid
  logic                                                op_a_valid;
  logic                                                op_b_valid;
  // delay operands signals
  delay_pe_mux_sel_t                                   delay_pe_mux_sel;
  delay_pe_op_mux_sel_t                                delay_pe_op_mux_sel;
  logic                  [       N_BITS:0]             delay_op_fu;
  logic                  [       N_BITS:0]             delay_op_out;
  logic                  [       N_BITS:0]             delay_op_out_d1;
  logic                  [       N_BITS:0]             delay_op_out_d2;
% if has_div_support:
%   if div_is_pipelined:
  logic                  [N_DIV_STAGE-1:0]             delay_op_out_d1_1;
%   else:
  logic                  [       N_BITS:0]             delay_op_out_d1_1;
%   endif
% endif
  logic                                                delay_op_valid;
  logic                                                delay_op_valid_out;
  logic                                                delay_op_valid_out_d1;
  logic                                                delay_op_valid_out_d2;
  // actual inputs to muxes
  logic                  [N_INPUTS_PE-1:0][N_BITS-1:0] operands;
  logic                  [N_INPUTS_PE-1:0]             operands_valid;
  // fu signals
  logic                                                fu_ops_valid;
  logic                                                fu_valid;
  logic                                                fu_ready;
  logic                                                multi_op_instr;
% if has_div_support:
  logic                                                div_instr;
% endif
  // accumulation signals
  logic                                                valid;
  logic                                                acc_loopback;
  // fu signals
  logic                  [     N_BITS-1:0]             fu_out;
% if has_div_support:
  logic                  [     N_BITS-1:0]             rem_q_out;
% endif
  fu_instr_t                                           fu_instr;
  // RF
  logic                                                rf_en;
  logic                  [            1:0]             rf_sel;
  logic                  [            1:0]             rf_cnt;
  logic                  [            1:0]             rf_val;
  logic                  [            4:0]             rf_cfg;
  logic                  [     N_BITS-1:0]             loopback_shacc;

  ////////////////////////////////
  //     Clock-gating cell      //
  ////////////////////////////////
`ifndef VERILATOR
`ifndef FPGA
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

  always_comb begin
    if (acc_loopback && fu_instr != SHACC) begin
      mux_sel_a = SELF;
    end else begin
      mux_sel_a = pe_mux_sel_t'(ctrl_pe_i[OP_A_SEL_MSB : OP_A_SEL_LSB]);
    end
    mux_sel_b = pe_mux_sel_t'(ctrl_pe_i[OP_B_SEL_MSB : OP_B_SEL_LSB]);
  end

% if has_part_vec_mode:
  assign part_vec_mode = ctrl_pe_i[VEC_MODE_SEL_MSB : VEC_MODE_SEL_LSB];
% endif
  assign fu_instr          = fu_instr_t'(ctrl_pe_i[INSTR_SEL_MSB : INSTR_SEL_LSB]);
  assign rf_cfg            = ctrl_pe_i[RF_SEL_MSB : RF_SEL_LSB];
  assign delay_pe_mux_sel     = delay_pe_mux_sel_t'(ctrl_pe_i[DELAY_PE_SEL_MSB : DELAY_PE_SEL_LSB]);
  assign delay_pe_op_mux_sel  = delay_pe_op_mux_sel_t'(ctrl_pe_i[DELAY_PE_OP_SEL_MSB : DELAY_PE_OP_SEL_LSB]);

  always_comb begin
    if (acc_loopback) begin
      loopback_shacc = pe_res_o;
    end else begin
      loopback_shacc = '0;
    end
  end

  ////////////////////////////////////////////////////////////////
  //                 Muxes inputs construction                  //
  ////////////////////////////////////////////////////////////////

  always_comb begin
    for (int i = 0; i < N_INPUTS_PE - 3; i++) begin
      operands[i]       = neigh_pe_op_i[i];
      operands_valid[i] = neigh_pe_op_valid_i[i];
    end
    operands[N_INPUTS_PE-3]       = pe_res_o;
    operands_valid[N_INPUTS_PE-3] = valid_o;
    operands[N_INPUTS_PE-2]       = reg_const_i;
    operands_valid[N_INPUTS_PE-2] = 1'b1;
    operands[N_INPUTS_PE-1]       = delay_op_fu[N_BITS-1:0];
    operands_valid[N_INPUTS_PE-1] = delay_op_valid;
  end

  ////////////////////////////////////////////////////////////////
  //                       Operand Selection                    //
  ////////////////////////////////////////////////////////////////

  assign op_a       = (mux_sel_a == RF && rf_sel == 2'b00 && reg_pea_rf_de_o) ? reg_pea_rf_d_o : operands[mux_sel_a];
  assign op_b       = (mux_sel_b == RF && rf_sel == 2'b00 && reg_pea_rf_de_o) ? reg_pea_rf_d_o : operands[mux_sel_b];
  assign op_a_valid = (mux_sel_a == SELF) ? 1'b1 : operands_valid[mux_sel_a];
  assign op_b_valid = (mux_sel_b == SELF) ? 1'b1 : operands_valid[mux_sel_b];
  assign fu_ops_valid = op_a_valid && op_b_valid;

  ////////////////////////////////////////////////////////////////
  //                   1-entry Register File                    //
  ////////////////////////////////////////////////////////////////

  assign rf_en  = rf_cfg[0];
  assign rf_sel = rf_cfg[2:1];
  assign rf_val = rf_cfg[4:3];

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (~rst_n_i) begin
      rf_cnt <= '0;
    end else begin
      if (rf_en && operands_valid[STREAM_IN0] && pea_ready_i) begin
        if (rf_cnt == reg_rf_value_i) begin
          rf_cnt <= '0;
        end else begin
          rf_cnt <= rf_cnt + 1;
        end
      end
    end
  end

  always_comb begin
    reg_pea_rf_de_o = '0;
    reg_pea_rf_d_o  = '0;
    if (rf_en && pea_ready_i) begin
      if (rf_sel == 2'b00) begin
        reg_pea_rf_de_o = operands_valid[STREAM_IN0] && (rf_cnt == rf_val);
        reg_pea_rf_d_o  = operands[STREAM_IN0];
      end else if (rf_sel == 2'b01) begin
        reg_pea_rf_de_o = operands_valid[mux_sel_a];
        reg_pea_rf_d_o  = operands[mux_sel_a];
      end
      if (rf_sel == 2'b10) begin
        reg_pea_rf_de_o = operands_valid[mux_sel_b];
        reg_pea_rf_d_o  = operands[mux_sel_b];
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                         Functional Unit                    //
  ////////////////////////////////////////////////////////////////
  ${fu_module} ${fu_inst} (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .mage_done_i,
% if has_part_vec_mode:
      .part_vec_mode_i(part_vec_mode),
% endif
%if bst_lvl != None and bst_lvl >= 1:
<%  n_bp = 2 ** bst_lvl %>\
      .reg_bp_i,
%elif bst_lvl != None and bst_lvl == 0:
      .reg_bp_i,
%endif
% if coeff == True:
      .reg_m_coeffs_i,
%   if n_q_coeffs > 0:
      .reg_q_coeffs_i,
%   endif
% endif
      .a_i(op_a),
      .b_i(op_b),
      .delay_sign_i(delay_op_fu[N_BITS]),
      .const_i(reg_const_i),
      .pe_res_i(loopback_shacc),
      .reg_acc_value_i,
      .pea_ready_i,
      .ops_valid_i(fu_ops_valid),
      .valid_o(fu_valid),
      .ready_o(fu_ready),
% if has_div_support:
      .rem_q_o(rem_q_out),
% endif
      .acc_loopback_o(acc_loopback),
      .instr_i(fu_instr),
      .res_o(fu_out)
  );

  ////////////////////////////////////////////////////////////////
  //                    Delay Operand Selection                 //
  ////////////////////////////////////////////////////////////////

% if has_div_support:
  assign div_instr = (fu_instr == DIV || fu_instr == REM || fu_instr == ABSDIV || fu_instr == ABSREM || fu_instr == CADDDIV);

% endif
  assign delay_op_fu    = neigh_delay_op_i[delay_pe_mux_sel];
  assign delay_op_valid = neigh_delay_op_valid_i[delay_pe_mux_sel];

% if has_div_support:
  always_comb begin
    delay_op_out = (delay_pe_op_mux_sel == D_PE_RES) ? ((fu_instr == DIV || fu_instr == REM || fu_instr == ABSDIV || fu_instr == ABSREM) ? {delay_op_fu[N_BITS], rem_q_out} : {delay_op_fu[N_BITS], fu_out}) : (
                   (delay_pe_op_mux_sel == D_PE_OP_A) ? {delay_op_fu[N_BITS], op_a} : (
                   (delay_pe_op_mux_sel == D_PE_OP_B) ? {delay_op_fu[N_BITS], op_b} : delay_op_fu
                  ));
    delay_op_valid_out = (delay_pe_op_mux_sel == D_PE_RES || div_instr) ? fu_valid : (
                   (delay_pe_op_mux_sel == D_PE_OP_A) ? op_a_valid : (
                   (delay_pe_op_mux_sel == D_PE_OP_B) ? op_b_valid : delay_op_valid
                  ));
  end

  assign multi_op_instr = (fu_instr == ABSDIV || fu_instr == ABSMIN || fu_instr[4] == 1'b1) && (fu_instr != BPSEL && fu_instr != CLIP);
% else:
  always_comb begin
    delay_op_out = (delay_pe_op_mux_sel == D_PE_RES) ?  {delay_op_fu[N_BITS], fu_out} : (
                   (delay_pe_op_mux_sel == D_PE_OP_A) ? {delay_op_fu[N_BITS], op_a} : (
                   (delay_pe_op_mux_sel == D_PE_OP_B) ? {delay_op_fu[N_BITS], op_b} : delay_op_fu
                  ));
    delay_op_valid_out = (delay_pe_op_mux_sel == D_PE_RES) ? fu_valid : (
                         (delay_pe_op_mux_sel == D_PE_OP_A) ? op_a_valid : (
                         (delay_pe_op_mux_sel == D_PE_OP_B) ? op_b_valid : delay_op_valid
                         ));
  end

  assign multi_op_instr = fu_instr[4] == 1'b1 && (fu_instr != BPSEL && fu_instr != CLIP);
% endif

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_out_d1 <= '0;
      delay_op_out_d2 <= '0;
    end else begin
      if (!mage_done_i && pea_ready_i) begin
        delay_op_out_d1 <= delay_op_out;
        delay_op_out_d2 <= delay_op_out_d1;
      end
    end
  end

% if has_div_support:
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_out_d1_1 <= '0;
    end else begin
%   if div_is_pipelined:
      if (div_instr && !mage_done_i && pea_ready_i) begin
        for (int i = 0; i < N_DIV_STAGE; i++) begin
          if (i == 0) begin
            delay_op_out_d1_1[i] <= delay_op_out_d1[N_BITS];
          end else begin
            delay_op_out_d1_1[i] <= delay_op_out_d1_1[i-1];
          end
        end
      end
%   else:
      if (div_instr && delay_op_valid_out && pea_ready_i) begin
        delay_op_out_d1_1 <= delay_op_out_d1;
      end
%   endif
    end
  end

% endif
  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      delay_op_valid_out_d1 <= 1'b0;
      delay_op_valid_out_d2 <= 1'b0;
    end else begin
      if (!mage_done_i && pea_ready_i) begin
        delay_op_valid_out_d1 <= delay_op_valid_out;
        delay_op_valid_out_d2 <= delay_op_valid_out_d1;
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                   Delay Operand Output Mux                 //
  ////////////////////////////////////////////////////////////////

% if has_div_support:
  always_comb begin
    if (!div_instr) begin
      if (delay_pe_op_mux_sel == D_PE_RES && multi_op_instr) begin
        delay_op_o       = {delay_op_out_d2[N_BITS], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel == D_PE_RES && !multi_op_instr) begin
        delay_op_o       = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel != D_PE_RES && multi_op_instr) begin
        delay_op_o       = delay_op_out_d2;
        delay_op_valid_o = delay_op_valid_out_d2;
      end else begin
        delay_op_o       = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end
    end else begin
%   if div_is_pipelined:
      if (delay_pe_op_mux_sel == D_PE_RES && multi_op_instr) begin
        delay_op_o       = {delay_op_out_d1_1[N_DIV_STAGE-1], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel == D_PE_RES && !multi_op_instr) begin
        delay_op_o       = {delay_op_out_d1_1[N_DIV_STAGE-2], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else if (delay_pe_op_mux_sel != D_PE_RES && !multi_op_instr) begin
        delay_op_o       = {delay_op_out_d1_1[N_DIV_STAGE-2], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else begin
        delay_op_o       = {delay_op_out_d1_1[N_DIV_STAGE-1], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end
%   else:
      delay_op_o       = {delay_op_out_d1_1[N_BITS], delay_op_out_d1[N_BITS-1:0]};
      delay_op_valid_o = delay_op_valid_out_d1;
%   endif
    end
  end
% else:
  always_comb begin
    if (delay_pe_op_mux_sel == D_PE_RES) begin
      if (multi_op_instr) begin
        delay_op_o       = {delay_op_out_d2[N_BITS], delay_op_out_d1[N_BITS-1:0]};
        delay_op_valid_o = delay_op_valid_out_d1;
      end else begin
        delay_op_o       = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end
    end else begin
      if (multi_op_instr) begin
        delay_op_o       = delay_op_out_d2;
        delay_op_valid_o = delay_op_valid_out_d2;
      end else begin
        delay_op_o       = delay_op_out_d1;
        delay_op_valid_o = delay_op_valid_out_d1;
      end
    end
  end
% endif

  ////////////////////////////////////////////////////////////////
  //                      Output Register                       //
  ////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      pe_res_o <= '0;
    end else begin
      if (!mage_done_i) begin
        if (fu_instr == NOP) begin
          pe_res_o <= '0;
% if has_div_support and div_is_pipelined:
        end else if ((pea_ready_i && fu_valid) || ((fu_instr == ACC || fu_instr == MAX) && fu_ops_valid && pea_ready_i)) begin
% else:
        end else if ((pea_ready_i && fu_valid) || ((fu_instr == ACC || fu_instr == SHACC || fu_instr == MAX) && fu_ops_valid && pea_ready_i)) begin
% endif
          pe_res_o <= fu_out;
        end else begin
          pe_res_o <= pe_res_o;
        end
      end else begin
        pe_res_o <= '0;
      end
    end
  end

  ////////////////////////////////////////////////////////////////
  //                       Output Ready/Valid                   //
  ////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_cg, negedge rst_n_i) begin
    if (!rst_n_i) begin
      valid <= '0;
    end else begin
      if (!mage_done_i) begin
        if (fu_instr == NOP) begin
          valid <= 1'b0;
        end else if (pea_ready_i) begin
          valid <= fu_valid;
        end else begin
          valid <= valid_o;
        end
      end else begin
        valid <= 1'b0;
      end
    end
  end

  assign valid_o = valid;
  assign ready_o = fu_ready;

endmodule
