// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: ${name}.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: ${description}
// NOTE: Auto-generated from fu_s.sv.tpl via mage-gen.py --fu-sv. Do not edit manually.

module ${name}
  import pea_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  logic                   mage_done_i,
% if arith_type in ('part_mul', 'part_add'):
    input  logic      [       2:0] part_vec_mode_i,
% endif
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
    input  logic      [N_BITS-1:0] a_i,
    input  logic      [N_BITS-1:0] b_i,
    input  fu_instr_t              instr_i,
    input  logic                   delay_sign_i,
    input  logic      [N_BITS-1:0] const_i,
    input  logic      [N_BITS-1:0] pe_res_i,
    input  logic                   ops_valid_i,
    input  logic                   pea_ready_i,
    input  logic      [      15:0] reg_acc_value_i,
    output logic                   acc_loopback_o,
    output logic                   valid_o,
    output logic                   ready_o,
% if divider_type != 'none':
    output logic      [N_BITS-1:0] rem_q_o,
% endif
    output logic      [N_BITS-1:0] res_o
);

% if divider_type != 'none':
  // gated clock
  logic              clk_cg;

% endif
  // Internal signed versions of the inputs
  logic [N_BITS-1:0] a_signed;
  logic [N_BITS-1:0] b_signed;

  assign a_signed = $signed(a_i);
  assign b_signed = $signed(b_i);
  ////////////////////////////////////////////////////////////////
  //                    Ready-Valid Handling                    //
  ////////////////////////////////////////////////////////////////

% if divider_type != 'none':
  // division ready-valid
  logic                out_div_valid;
  logic                div_input_valid;
  logic                div_instr;
% if divider_type == 'serdiv':
  logic                div_ready;
  logic                div_busy;
  logic                div_used_once;
% endif
% endif
  // accumulation ready-valid
  logic [  N_BITS-1:0] acc_cnt;
  logic                acc_valid;
  // ready-valid
  logic                valid;
% if divider_type == 'serdiv':
  logic                ready;
% endif
  logic                valid_mo_instr;
  logic                mo_instr;
  // +1 adder
  logic [  N_BITS-1:0] add_one_op1;
  logic [  N_BITS-1:0] add_one_op2;
  logic [  N_BITS-1:0] add_one_res;

% if arith_type == 'part_add':
  logic [  N_BITS-1:0] add_res;
% else:
  logic [    N_BITS:0] add_res;
% endif
  logic [  N_BITS-1:0] mul_res;
  logic [  N_BITS-1:0] shift_res;
  logic [2*N_BITS-1:0] shift_res_ext;
  logic [  N_BITS-1:0] lsh_res;

  logic [  N_BITS-1:0] mul_op1;
  logic [  N_BITS-1:0] mul_op2;

  logic [  N_BITS-1:0] lsh_op1_rev;
  logic [2*N_BITS-1:0] shift_op1;
  logic [         4:0] shift_op2;

% if arith_type == 'part_add':
  logic [  N_BITS-1:0] add_op1;
  logic [  N_BITS-1:0] add_op2;
% else:
  logic [    N_BITS:0] add_op1;
  logic [    N_BITS:0] add_op2;
% endif

  logic [  N_BITS-1:0] op1_neg;
% if arith_type != 'part_add':
  logic [  N_BITS-1:0] op2_neg;
  logic [  N_BITS-1:0] op2_neg_d1;
% endif

  logic                sign_op1;
  logic                sign_op1_d;

  logic [  N_BITS-1:0] temp_res;
  logic [  N_BITS-1:0] temp_res_neg;
  logic [  N_BITS-1:0] temp_op_reg;

% if divider_type != 'none':
  logic [  N_BITS-1:0] quotient_div;
  logic [  N_BITS-1:0] remainder_div;
  logic [  N_BITS-1:0] div_op1;
  logic [  N_BITS-1:0] div_op2;
% endif
% if arith_type == 'part_add':
  // partitioned operators
  logic [         1:0] part_op_instr;
% endif

% if divider_type != 'none':
  // div_instr is asserted when the instruction contains a division (it is used to clock gate divider)
  assign div_instr = (instr_i == DIV || instr_i == REM || instr_i == ABSDIV || instr_i == ABSREM || instr_i == CADDDIV);

/*  █████████  ████                    █████                   █████████             █████     ███                     
   ███▒▒▒▒▒███▒▒███                   ▒▒███                   ███▒▒▒▒▒███           ▒▒███     ▒▒▒                      
  ███     ▒▒▒  ▒███   ██████   ██████  ▒███ █████            ███     ▒▒▒   ██████   ███████   ████  ████████    ███████
 ▒███          ▒███  ███▒▒███ ███▒▒███ ▒███▒▒███  ██████████▒███          ▒▒▒▒▒███ ▒▒▒███▒   ▒▒███ ▒▒███▒▒███  ███▒▒███
 ▒███          ▒███ ▒███ ▒███▒███ ▒▒▒  ▒██████▒  ▒▒▒▒▒▒▒▒▒▒ ▒███    █████  ███████   ▒███     ▒███  ▒███ ▒███ ▒███ ▒███
 ▒▒███     ███ ▒███ ▒███ ▒███▒███  ███ ▒███▒▒███            ▒▒███  ▒▒███  ███▒▒███   ▒███ ███ ▒███  ▒███ ▒███ ▒███ ▒███
  ▒▒█████████  █████▒▒██████ ▒▒██████  ████ █████            ▒▒█████████ ▒▒████████  ▒▒█████  █████ ████ █████▒▒███████
   ▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒ ▒▒▒▒▒              ▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒    ▒▒▒▒▒  ▒▒▒▒▒ ▒▒▒▒ ▒▒▒▒▒  ▒▒▒▒▒███
                                                                                                               ███ ▒███
                                                                                                              ▒▒██████ 
                                                                                                              ▒▒▒▒▒▒  
*/
`ifndef VERILATOR
`ifndef FPGA
  // Div Clock-gating
  logic clk_cg_en;
  assign clk_cg_en = div_instr;
  tc_clk_gating div_clk_gating_cell (
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

% endif
/* 
             ████       █████████       █████     █████                   
     ███    ▒▒███      ███▒▒▒▒▒███     ▒▒███     ▒▒███                    
    ▒███     ▒███     ▒███    ▒███   ███████   ███████   ██████  ████████ 
 ███████████ ▒███     ▒███████████  ███▒▒███  ███▒▒███  ███▒▒███▒▒███▒▒███
▒▒▒▒▒███▒▒▒  ▒███     ▒███▒▒▒▒▒███ ▒███ ▒███ ▒███ ▒███ ▒███████  ▒███ ▒▒▒ 
    ▒███     ▒███     ▒███    ▒███ ▒███ ▒███ ▒███ ▒███ ▒███▒▒▒   ▒███     
    ▒▒▒      █████    █████   █████▒▒████████▒▒████████▒▒██████  █████    
            ▒▒▒▒▒    ▒▒▒▒▒   ▒▒▒▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒  ▒▒▒▒▒     
                                                                          
*/
  /*
    +1 adder shared between:
      -> the ACC, SHACC, MAX, MAXS counter
      -> the ABS operation in ABSMIN
      -> the ABS operation in SGNCSUB
  */
  always_comb begin
    add_one_op1 = '0;
    add_one_op2 = '0;
    if (instr_i == ACC || instr_i == SHACC || instr_i == MAX || instr_i == MAXS) begin
      add_one_op1 = acc_cnt;
      add_one_op2[0] = 1'b1;
% if divider_type != 'none':
    end else if (instr_i == ABSMIN || instr_i == ABSDIV || instr_i == ABSREM) begin
% else:
    end else if (instr_i == ABSMIN) begin
% endif
      add_one_op1 = sign_op1 ? op1_neg : a_signed;
      add_one_op2[0] = sign_op1 ? 1'b1 : 1'b0;
    end else if (instr_i == SGNCSUB) begin
      add_one_op1 = sign_op1_d ? temp_res_neg : temp_res;
      add_one_op2[0] = sign_op1_d ? 1'b1 : 1'b0;
    end
  end

  always_comb begin
    add_one_res = add_one_op1 + add_one_op2;
  end

/* 
 ███████████                █████                      █████     ███                             
▒▒███▒▒▒▒▒███              ▒▒███                      ▒▒███     ▒▒▒                              
 ▒███    ▒███   ██████   ███████  █████ ████  ██████  ███████   ████   ██████  ████████    █████ 
 ▒██████████   ███▒▒███ ███▒▒███ ▒▒███ ▒███  ███▒▒███▒▒▒███▒   ▒▒███  ███▒▒███▒▒███▒▒███  ███▒▒  
 ▒███▒▒▒▒▒███ ▒███████ ▒███ ▒███  ▒███ ▒███ ▒███ ▒▒▒   ▒███     ▒███ ▒███ ▒███ ▒███ ▒███ ▒▒█████ 
 ▒███    ▒███ ▒███▒▒▒  ▒███ ▒███  ▒███ ▒███ ▒███  ███  ▒███ ███ ▒███ ▒███ ▒███ ▒███ ▒███  ▒▒▒▒███
 █████   █████▒▒██████ ▒▒████████ ▒▒████████▒▒██████   ▒▒█████  █████▒▒██████  ████ █████ ██████ 
▒▒▒▒▒   ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒     ▒▒▒▒▒  ▒▒▒▒▒  ▒▒▒▒▒▒  ▒▒▒▒ ▒▒▒▒▒ ▒▒▒▒▒▒  
*/

  /*
    ACC counter:
      -> counts up to reg_acc_value_i, it is used to know how many elements to accumulate
          in the ACC instruction
      -> it is also used to know when to stop the max search in the MAX instruction
      -> acc_loopback_o is used to loop back the result of the operation to the input of the PE
  */
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      acc_cnt <= '0;
      acc_loopback_o <= 1'b0;
    end else begin
      if (instr_i == ACC || instr_i == SHACC || instr_i == MAX || instr_i == MAXS) begin
        if ((acc_cnt[15:0] == reg_acc_value_i && ops_valid_i && pea_ready_i) || mage_done_i) begin
          acc_cnt <= '0;
          acc_loopback_o <= 1'b0;
        end else if (ops_valid_i && pea_ready_i) begin
          acc_cnt <= add_one_res;
          acc_loopback_o <= 1'b1;
        end
      end else begin
        acc_cnt <= '0;
        acc_loopback_o <= 1'b0;
      end
    end
  end

  /*
    valid signal for accumulation:
      -> the acc_valid signal is asserted when (in AND):
        -> the coutner reaches the final value
        -> the inputs of the FU are valid
  */
  //assign acc_valid = (acc_cnt[15:0] == reg_acc_value_i && acc_cnt != '0 && ops_valid_i);
  assign acc_valid = (acc_cnt[15:0] == reg_acc_value_i && ops_valid_i);

% if divider_type != 'none':
/* 
 ██████████    ███               ███      █████                   
▒▒███▒▒▒▒███  ▒▒▒               ▒▒▒      ▒▒███                    
 ▒███   ▒▒███ ████  █████ █████ ████   ███████   ██████  ████████ 
 ▒███    ▒███▒▒███ ▒▒███ ▒▒███ ▒▒███  ███▒▒███  ███▒▒███▒▒███▒▒███
 ▒███    ▒███ ▒███  ▒███  ▒███  ▒███ ▒███ ▒███ ▒███████  ▒███ ▒▒▒ 
 ▒███    ███  ▒███  ▒▒███ ███   ▒███ ▒███ ▒███ ▒███▒▒▒   ▒███     
 ██████████   █████  ▒▒█████    █████▒▒████████▒▒██████  █████    
▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒    ▒▒▒▒▒    ▒▒▒▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒  ▒▒▒▒▒     
*/                                                              

  // div_input_valid is asserted when the inputs to divider are valid and the instruction has division
  assign div_input_valid = (ops_valid_i && (instr_i == DIV || instr_i == REM)) || (valid_mo_instr && (instr_i == ABSDIV || instr_i == ABSREM || instr_i == CADDDIV));

% if divider_type == 'serdiv':
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      div_busy <= 1'b0;
    end else begin
      if (out_div_valid) begin
        div_busy <= 1'b0;
      end else begin
        if (div_input_valid) begin
          div_busy <= 1'b1;
        end
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      div_used_once <= 1'b0;
    end else begin
      if (div_busy) begin
        div_used_once <= 1'b1;
      end
    end
  end

  always_comb begin
    if (div_busy) begin
      div_ready = 1'b0;
      if (out_div_valid) begin
        div_ready = 1'b1;
      end
    end else begin
      div_ready = 1'b1;
      if (div_input_valid) begin
        div_ready = 1'b0;
      end
    end
  end

% endif


% if divider_type == 'serdiv':
  ////////////////////////////////////////////////////////////////
  //               Radix-cfg Multi-cycle Divider                //
  ////////////////////////////////////////////////////////////////

  div_wrapper div_wrapper_i (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .a_i(div_op1),
      .b_i(div_op2),
      .in_valid_i(div_input_valid),
      .q_o(quotient_div),
      .r_o(remainder_div),
      .valid_o(out_div_valid)
  );

% elif divider_type == 'pipediv':
  ////////////////////////////////////////////////////////////////
  //                Radix-cfg Pipelined Divider                 //
  ////////////////////////////////////////////////////////////////

  div_wrapper_pipe div_wrapper_pipe_i (
      .clk_i(clk_cg),
      .rst_n_i(rst_n_i),
      .pea_ready_i(pea_ready_i),
      .a_i(div_op1),
      .b_i(div_op2),
      .in_valid_i(div_input_valid),
      .q_o(quotient_div),
      .r_o(remainder_div),
      .valid_o(out_div_valid)
  );

% endif

% endif

/* 
 ███████████                          █████                       █████   █████           ████   ███      █████
▒▒███▒▒▒▒▒███                        ▒▒███                       ▒▒███   ▒▒███           ▒▒███  ▒▒▒      ▒▒███ 
 ▒███    ▒███   ██████   ██████    ███████  █████ ████            ▒███    ▒███   ██████   ▒███  ████   ███████ 
 ▒██████████   ███▒▒███ ▒▒▒▒▒███  ███▒▒███ ▒▒███ ▒███  ██████████ ▒███    ▒███  ▒▒▒▒▒███  ▒███ ▒▒███  ███▒▒███ 
 ▒███▒▒▒▒▒███ ▒███████   ███████ ▒███ ▒███  ▒███ ▒███ ▒▒▒▒▒▒▒▒▒▒  ▒▒███   ███    ███████  ▒███  ▒███ ▒███ ▒███ 
 ▒███    ▒███ ▒███▒▒▒   ███▒▒███ ▒███ ▒███  ▒███ ▒███              ▒▒▒█████▒    ███▒▒███  ▒███  ▒███ ▒███ ▒███ 
 █████   █████▒▒██████ ▒▒████████▒▒████████ ▒▒███████                ▒▒███     ▒▒████████ █████ █████▒▒████████
▒▒▒▒▒   ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒▒   ▒▒▒▒▒███                 ▒▒▒       ▒▒▒▒▒▒▒▒ ▒▒▒▒▒ ▒▒▒▒▒  ▒▒▒▒▒▒▒▒ 
                                             ███ ▒███                                                          
                                            ▒▒██████                                                           
                                             ▒▒▒▒▒▒                                                            
 */                                             
  // mo_instr: asserted if PE instruction is multi-operand (2-cycle instruction)
  assign mo_instr = instr_i[4] == 1'b1 && (instr_i != BPSEL && instr_i != CLIP);

  /*
    Valid:
      -> standard case: it is asserted when both inputs are valid
      -> ACC, SHACC, MAX case: it is asserted when acc_valid is asserted
        -> NOTE: MAXS has the loopback logic, but its valid is asserted for all the outputs
      -> 2-cycle instruction case: it is assigned to valid_mo_instr (i.e. ops_valid delayed by one cycle)
% if divider_type != 'none':
      -> division instruction case: it is asserted when the output of the divider is valid

% endif
    Ready:
% if divider_type == 'serdiv':
      -> For non-division instructions: the FU is always ready
      -> For division instructions: it is asserted along with div_ready
% else:
      -> since no multi-cycle operations are available, the FU is always ready
% endif
  */
  always_comb begin
    valid = ops_valid_i;
% if divider_type == 'serdiv':
    ready = 1'b1;
    if (div_instr) begin
      valid = out_div_valid && div_used_once;
      ready = div_ready;
    end else if (mo_instr) begin
      valid = valid_mo_instr;
    end else begin
      if (instr_i == ACC || instr_i == SHACC || instr_i == MAX) begin
        valid = acc_valid;
      end
    end
% elif divider_type == 'pipediv':
    if (div_instr) begin
      valid = out_div_valid;
    end else if (mo_instr) begin
      valid = valid_mo_instr;
    end else begin
      if (instr_i == ACC || instr_i == SHACC || instr_i == MAX) begin
        valid = acc_valid;
      end
    end
% else:
    if (!mo_instr) begin
      if (instr_i == ACC || instr_i == SHACC || instr_i == MAX) begin
        valid = acc_valid;
        //valid = (reg_acc_value_i == '0) ? ops_valid_i : acc_valid;
      end
    end else begin
      valid = valid_mo_instr;
    end
% endif
  end

  // valid_mo_instr is ops_valid_i delayed by one cycle, as it is useful for 2-cycle instructions
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      valid_mo_instr <= 1'b0;
    end else begin
      if (mo_instr && pea_ready_i) begin
        valid_mo_instr <= ops_valid_i;
      end
    end
  end

  assign valid_o = valid;
% if divider_type == 'serdiv':
  assign ready_o = ready;
% else:
  assign ready_o = 1'b1;
% endif

% if arith_type == 'part_mul':
  part_mul part_mul_i (
      .mul_op1_i (mul_op1),
      .mul_op2_i (mul_op2),
      .vec_mode_i(part_vec_mode_i),
      .mul_res_o (mul_res)
  );

  // 32-bit adder
  assign add_res = add_op1 + add_op2;

% elif arith_type == 'part_add':
  // 32-bit mul
  assign mul_res = mul_op1 * mul_op2;

  part_add_sub part_add_i (
      .add_op1_i(add_op1),
      .add_op2_i(add_op2),
      .vec_mode_i(part_vec_mode_i),
      .instr_i(part_op_instr),
      .add_res_o(add_res)
  );

% else:
  // 32-bit adder
  assign add_res = add_op1 + add_op2;

  // 32-bit mul
  assign mul_res = mul_op1 * mul_op2;

% endif

  ////////////////////////////////////////////////////////////////
  //                FU Input/Output Assignments                 //
  ////////////////////////////////////////////////////////////////

  // Negated versione of a, b and temp_op_reg
  assign op1_neg    = ~a_signed;
% if arith_type != 'part_add':
  assign op2_neg    = ~b_signed;
  assign op2_neg_d1 = ~temp_op_reg;
% endif


  // 32-bit shifter
  logic shift_overflow;
  assign shift_overflow = |b_signed[N_BITS-1:5];
  assign shift_res_ext  = shift_op1 >>> shift_op2;
  assign shift_res      = shift_overflow ? '0 : shift_res_ext[31:0];

  // LHS logic
  generate
    genvar m;
    for (m = 0; m < 32; m++) begin
      assign lsh_res[31-m] = shift_res[m];
    end
  endgenerate

  generate
    genvar n;
    for (n = 0; n < 32; n++) begin
      assign lsh_op1_rev[n] = a_signed[31-n];
    end
  endgenerate

  /*
    Sign of operand a:
      -> the sign of operand a is taken
      -> it is delayed of one cycle when instruction is SGNCSUB
  */
  assign sign_op1 = a_signed[N_BITS-1];

  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      sign_op1_d <= 1'b0;
    end else begin
      if (pea_ready_i && instr_i == SGNCSUB) begin
        sign_op1_d <= sign_op1;
      end
    end
  end

  /*
    Temporary result for 2-cycle instructions:
      -> when PE has 2-cycles instruction, the temporary result is stored into a register
  */
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      temp_res <= '0;
    end else begin
      if (pea_ready_i) begin
        if (ops_valid_i) begin
% if arith_type == 'part_add':
          if (instr_i == ADDPOW) begin
            temp_res <= add_res;
          end else if (instr_i == CADDMUL) begin
            temp_res <= add_res;
          end else if (instr_i == CMULADD) begin
            temp_res <= mul_res;
          end else if (instr_i == CMULADD_PW) begin
            temp_res <= mul_res;
          end else if (instr_i == ADDCMUL) begin
            temp_res <= add_res;
          end else if (instr_i == MULCARSH) begin
            temp_res <= mul_res;
          end else if (instr_i == ABSMIN) begin
            temp_res <= add_one_res;
% if divider_type != 'none':
          end else if (instr_i == ABSDIV) begin
            temp_res <= add_one_res;
          end else if (instr_i == CADDDIV) begin
            temp_res <= add_res;
          end else if (instr_i == ABSREM) begin
            temp_res <= add_one_res;
% endif
          end else if (instr_i == SGNCSUB) begin
            temp_res <= add_res;
          end else if (instr_i == SUBPOW) begin
            temp_res <= add_res;
          end else if (instr_i == CLSHSUB) begin
            temp_res <= lsh_res;
          end
% else:
          if (instr_i == ADDPOW) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == CADDMUL) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == CMULADD) begin
            temp_res <= mul_res;
          end else if (instr_i == CMULADD_PW) begin
            temp_res <= mul_res;
          end else if (instr_i == ADDCMUL) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == MULCARSH) begin
            temp_res <= mul_res;
          end else if (instr_i == ABSMIN) begin
            temp_res <= add_one_res;
% if divider_type != 'none':
          end else if (instr_i == ABSDIV) begin
            temp_res <= add_one_res;
          end else if (instr_i == CADDDIV) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == ABSREM) begin
            temp_res <= add_one_res;
% endif
          end else if (instr_i == SGNCSUB) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == SUBPOW) begin
            temp_res <= add_res[N_BITS:1];
          end else if (instr_i == CLSHSUB) begin
            temp_res <= lsh_res;
          end
% endif
        end
      end
    end
  end

  // negated temp_res
  assign temp_res_neg = ~temp_res;

  /*
    Temporary operand:
      -> for some 2-cycle instructions, one of the input operands must be stored into a register,
          as it will be useful for the operation to be done in the second cycle of the instruction
  */
  always_ff @(posedge clk_i, negedge rst_n_i) begin
    if (!rst_n_i) begin
      temp_op_reg <= '0;
    end else begin
      if (pea_ready_i) begin
% if divider_type != 'none':
        if (instr_i == CADDMUL || instr_i == CMULADD || instr_i == CMULADD_PW || instr_i == ABSMIN || instr_i == CLSHSUB || instr_i == ABSDIV || instr_i == ABSREM || instr_i == CADDDIV) begin
% else:
        if (instr_i == CADDMUL || instr_i == CMULADD || instr_i == CMULADD_PW || instr_i == ABSMIN || instr_i == CLSHSUB) begin
% endif
          temp_op_reg <= b_signed;
        end else if (instr_i == SGNCSUB) begin
          temp_op_reg <= a_signed;
        end
      end
    end
  end

  /*
    FU Instructions
  */
  always_comb begin

% if arith_type == 'part_add':
    add_op1 = '0;
    add_op2 = '0;
    mul_op1 = '0;
    mul_op2 = '0;
    shift_op1 = '0;
    shift_op2 = '0;
% if divider_type != 'none':
    div_op1 = '0;
    div_op2 = '0;
% endif
    part_op_instr = 2'b00;  // default to ADD
% else:
    add_op1   = '0;
    add_op2   = '0;
    mul_op1   = '0;
    mul_op2   = '0;
    shift_op1 = '0;
    shift_op2 = '0;
% if divider_type != 'none':
    div_op1   = '0;
    div_op2   = '0;
% endif
% endif

    case (instr_i)
      NOP: begin
        add_op1   = '0;
        add_op2   = '0;
        mul_op1   = '0;
        mul_op2   = '0;
% if divider_type != 'none':
        div_op1   = '0;
        div_op2   = '0;
% endif
        shift_op1 = '0;
        shift_op2 = '0;
      end

//add arith_type handling
% if bst_lvl != None:
      BPSEL: begin
% if bst_lvl == 0: 
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = reg_bp_i;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {~reg_bp_i, 1'b1};
%endif
% else:
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = reg_bp_i[b_signed[${bst_lvl}-1:0]];
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {~(reg_bp_i[b_signed[${bst_lvl}-1:0]]), 1'b1};
% endif
% endif
      end
%endif

% if divider_type != 'none':
      DIV: begin
        div_op1 = a_signed;
        div_op2 = b_signed;
      end

      REM: begin
        div_op1 = a_signed;
        div_op2 = b_signed;
      end

% endif
      ACC: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b10;  // ACC
% else:
        add_op1 = {a_signed, 1'b0};
        add_op2 = {b_signed, 1'b0};
% endif
      end

      ADD: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1 = {a_signed, 1'b0};
        add_op2 = {b_signed, 1'b0};
% endif
      end

      ABS: begin
% if arith_type == 'part_add':
        add_op1 = op1_neg;
        add_op2 = 32'd1;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {op1_neg, 1'b0};
        add_op2 = {32'd1, 1'b0};
% endif
      end

      SUB: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
% endif
      end

      MUL: begin
        mul_op1 = a_signed;
        mul_op2 = b_signed;
      end

      MAXS: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
% endif
      end

      MIN: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
% endif
      end

      MAX: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
% endif
      end

      ARSH: begin
        shift_op1 = {{32{a_signed[N_BITS-1]}}, a_signed};
        shift_op2 = b_signed[4:0];
      end

      LRSH: begin
        shift_op1 = {32'd0, a_signed};
        shift_op2 = b_signed[4:0];
      end

      LSH: begin
        shift_op1 = {32'd0, lsh_op1_rev};
        shift_op2 = b_signed[4:0];
      end

      ADDPOW: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1 = {a_signed, 1'b0};
        add_op2 = {b_signed, 1'b0};
% endif
        mul_op1 = temp_res;
        mul_op2 = temp_res;
      end

      SUBPOW: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {a_signed, 1'b1};
        add_op2 = {op2_neg, 1'b1};
% endif
        mul_op1 = temp_res;
        mul_op2 = temp_res;
      end

      ADDCMUL: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1 = {a_signed, 1'b0};
        add_op2 = {b_signed, 1'b0};
% endif
        mul_op1 = temp_res;
        mul_op2 = const_i;
      end

      CADDMUL: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = const_i;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1 = {a_signed, 1'b0};
        add_op2 = {const_i, 1'b0};
% endif
        mul_op1 = temp_res;
        mul_op2 = temp_op_reg;
      end

      CMULADD: begin
        mul_op1 = a_signed;
% if arith_type == 'part_add':
        add_op1 = temp_res;
        add_op2 = temp_op_reg;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1 = {temp_res, 1'b0};
        add_op2 = {temp_op_reg, 1'b0};
% endif
        mul_op2 = const_i;
      end

% if coeff == True:
      CMULADD_PW: begin

        mul_op1 = a_signed;

% if arith_type == 'part_add':

        add_op1 = temp_res;

%   if n_q_coeffs > 0:
        add_op2 = reg_q_coeffs_i[temp_op_reg[$clog2(${n_q_coeffs})-1:0]];
%   else:
        add_op2 = reg_m_coeffs_i[temp_op_reg[$clog2(${n_m_coeffs})-1:0]];
%   endif

        part_op_instr = 2'b00;  // ADD

% else:

        add_op1 = {temp_res, 1'b0};

%   if n_q_coeffs > 0:
        add_op2 = {reg_q_coeffs_i[temp_op_reg[$clog2(${n_q_coeffs})-1:0]], 1'b0};
%   else:
        add_op2 = {reg_m_coeffs_i[temp_op_reg[$clog2(${n_m_coeffs})-1:0]], 1'b0};
%   endif

% endif

% if n_q_coeffs > 0:
        mul_op2 = reg_m_coeffs_i[b_signed[$clog2(${n_m_coeffs})-1:0]];
% else:
        mul_op2 = b_signed;
% endif

      end
%endif

      MULCARSH: begin
        mul_op1   = a_signed;
        mul_op2   = b_signed;
        shift_op1 = {{32{temp_res[N_BITS-1]}}, temp_res};
        shift_op2 = const_i[4:0];
      end

      CLSHSUB: begin
        shift_op1 = {32'd0, lsh_op1_rev};
        shift_op2 = const_i[4:0];
% if arith_type == 'part_add':
        add_op1 = temp_res;
        add_op2 = temp_op_reg;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1   = {temp_res, 1'b1};
        add_op2   = {op2_neg_d1, 1'b1};
% endif
      end

      ABSMIN: begin
% if arith_type == 'part_add':
        add_op1 = temp_res;
        add_op2 = temp_op_reg;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {temp_res, 1'b1};
        add_op2 = {op2_neg_d1, 1'b1};
% endif
      end

      SHACC: begin
        shift_op1 = {{32{pe_res_i[N_BITS-1]}}, pe_res_i};
        shift_op2 = a_signed[4:0];
% if arith_type == 'part_add':
        add_op1 = shift_res;
        add_op2 = b_signed;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1   = {shift_res, 1'b0};
        add_op2   = {b_signed, 1'b0};
% endif
      end

% if divider_type != 'none':
      ABSDIV: begin
        div_op1 = temp_res;
        div_op2 = temp_op_reg;
      end

      CADDDIV: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = const_i;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1 = {a_signed, 1'b0};
        add_op2 = {const_i, 1'b0};
% endif
        div_op1 = temp_op_reg;
        div_op2 = temp_res;
      end

      ABSREM: begin
        div_op1 = temp_res;
        div_op2 = temp_op_reg;
      end

% endif
      SGNCSUB: begin
% if arith_type == 'part_add':
        add_op1 = const_i;
        add_op2 = b_signed;
        part_op_instr = 2'b01;  // SUB
% else:
        add_op1 = {const_i, 1'b1};
        add_op2 = {op2_neg, 1'b1};
% endif
      end

      default: begin
% if arith_type == 'part_add':
        add_op1 = a_signed;
        add_op2 = b_signed;
        part_op_instr = 2'b00;  // ADD
% else:
        add_op1   = {a_signed, 1'b0};
        add_op2   = {b_signed, 1'b0};
% endif
        mul_op1   = a_signed;
        mul_op2   = b_signed;
        shift_op1 = {{32{a_signed[N_BITS-1]}}, a_signed};
        shift_op2 = b_signed[4:0];
      end
    endcase
  end


  always_comb begin
    case (instr_i)
      NOP: res_o = 0;
% if arith_type == 'part_add':
<%  add_slice = '' %>
<%  add_msb   = 'N_BITS-1' %>
% else:
<%  add_slice = '[N_BITS:1]' %>
<%  add_msb   = 'N_BITS' %>
% endif
      ADD:  res_o = add_res${add_slice};
      ACC:  res_o = add_res${add_slice};
      MUL:  res_o = mul_res;
      SUB:  res_o = add_res${add_slice};
      LSH:  res_o = lsh_res;
      ARSH: res_o = shift_res;
      LRSH: res_o = shift_res;
% if bst_lvl != None:
      <%bst_rem = 31 - bst_lvl%>
% if bst_lvl == 0:
      BPSEL: res_o = (add_res[${add_msb}] || (|add_res) == 1'b0) ? {{31{1'b0}}, 1'b0} : {{31{1'b0}}, 1'b1};
% else:
      BPSEL: res_o = (add_res[${add_msb}] || (|add_res) == 1'b0) ? {{${bst_rem}{1'b0}}, b_signed[${bst_lvl-1}:0], 1'b0} : {{{${bst_rem}{1'b0}}, b_signed[${bst_lvl-1}:0], 1'b1}};
% endif
% endif
      MAX:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[${add_msb}] != a_signed[N_BITS-1]) ? b_signed : a_signed) :
                                                  ((add_res[${add_msb}] == a_signed[N_BITS-1]) ? b_signed : a_signed);
      MAXS:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[${add_msb}] != a_signed[N_BITS-1]) ? b_signed : a_signed) :
                                                  ((add_res[${add_msb}] == a_signed[N_BITS-1]) ? b_signed : a_signed);
      MIN:
      res_o = (a_signed[N_BITS-1] == 1'b0) ? ((add_res[${add_msb}] != a_signed[N_BITS-1]) ? a_signed : b_signed) :
                                                  ((add_res[${add_msb}] == a_signed[N_BITS-1]) ? a_signed : b_signed);
      ABS:  res_o = sign_op1 ? add_res${add_slice} : a_signed;
% if divider_type != 'none':
      DIV:  res_o = quotient_div;
      REM:  res_o = remainder_div;
% endif
      ADDPOW: res_o = mul_res;
      SUBPOW: res_o = mul_res;
% if divider_type != 'none':
      ABSDIV:  res_o = quotient_div;
% endif
      SHACC: res_o = add_res${add_slice};
% if divider_type != 'none':
      ABSREM:  res_o = remainder_div;
      CADDDIV: res_o = quotient_div;
% endif
      CADDMUL: res_o = mul_res;
      ADDCMUL: res_o = mul_res;
      CMULADD: res_o = add_res${add_slice};
      CMULADD_PW: res_o = add_res${add_slice};
      CLSHSUB: res_o = add_res${add_slice};
      MULCARSH: res_o = shift_res;
      ABSMIN: res_o = (add_res[${add_msb}]) ? temp_res : temp_op_reg;
      SGNCSUB: res_o = (|temp_op_reg == 1'b0) ? '0 : add_one_res;
      SGNSEL: res_o = delay_sign_i ? b_i : a_i;
      default: res_o = 0;
    endcase
  end

% if divider_type != 'none':
  /*
    rem_q_o:
      -> assigned to REMAINDER if the main result is the quotient
      -> assigned to QUOTIENT if the main result is the remainder
  */
  assign rem_q_o = (instr_i == DIV || instr_i == ABSDIV || instr_i == CADDDIV) ? remainder_div : ((instr_i == REM || instr_i == ABSREM) ? quotient_div : 0);

% endif
endmodule
