// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: part_add_sub.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: packed SIMD partitioned mul and add, with precision expanded up to 32 bit always 

module part_madd
  import pea_pkg::*;
(
    input logic [31:0] add_op1_i,
    input logic [31:0] add_op2_i,
    input logic [31:0] mul_op1_i,
    input logic [31:0] mul_op2_i,
    input logic [31:0] coeff_m_i,
    input logic [31:0] coeff_q_i,
    input logic [1:0] vec_mode_i,
    input logic [2:0] instr_i,  //000: ADD, 001: MUL, 010: MAC, 011: PWL, 100: NOP
    output logic [31:0] add_res_o,
    output logic [31:0] mul_res_o
);

  // MUL dest
  logic [15:0] mul_3_16_res;
  logic [31:0] mul_2_32_res;
  logic [31:0] mul_1_32_res;
  logic [31:0] mul_0_32_res;

  // MUL src
  logic [ 7:0] mul_3_16_src1;
  logic [ 7:0] mul_3_16_src2;
  logic [15:0] mul_2_32_src1;
  logic [15:0] mul_2_32_src2;
  logic [15:0] mul_1_32_src1;
  logic [15:0] mul_1_32_src2;
  logic [15:0] mul_0_32_src1;
  logic [15:0] mul_0_32_src2;


  // ADD dest
  logic [15:0] add_1_16_res;
  logic [31:0] add_0_32_res;
  logic [31:0] add_2_32_res;
  logic [31:0] add_3_32_res;

  // ADD src
  logic [16:0] add_1_16_src1;
  logic [16:0] add_1_16_src2;
  logic [31:0] add_0_32_src1;
  logic [31:0] add_0_32_src2;
  logic [31:0] add_2_32_src1;
  logic [31:0] add_2_32_src2;
  logic [31:0] add_3_32_src1;
  logic [31:0] add_3_32_src2;

  // Vector Mode
  logic        vec_mode_8;
  logic        vec_mode_16;
  logic        vec_mode_32;

  ////////////////////////////////
  //        Vector Mode         //
  ////////////////////////////////
  always_comb begin
    vec_mode_8  = (vec_mode_i == 2'b01);
    vec_mode_16 = (vec_mode_i == 2'b10);
    vec_mode_32 = (vec_mode_i == 2'b00);
  end


  // Mux src for MUL3
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension
        mul_3_16_src1 = {{8{mul_op1_i[31]}}, mul_op1_i[31:24]};
        mul_3_16_src2 = {{8{mul_op2_i[31]}}, mul_op2_i[31:24]};

      end else begin

        mul_3_16_src1 = '0;
        mul_3_16_src2 = '0;

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension for Xi[31:24] * mi[31:24]
        mul_3_16_src1 = {{8{mul_op1_i[31]}}, mul_op1_i[31:24]};
        mul_3_16_src2 = {{8{coeff_m_i[31]}}, coeff_m_i[31:24]};

      end else begin

        mul_3_16_src1 = '0;
        mul_3_16_src2 = '0;

      end

    end else begin

      mul_3_16_src1 = '0;
      mul_3_16_src2 = '0;

    end
  end

  // Mux src for MUL2
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension
        mul_2_16_src1 = {{8{mul_op1_i[23]}}, mul_op1_i[23:16]};
        mul_2_16_src2 = {{8{mul_op2_i[23]}}, mul_op2_i[23:16]};

      end else if (vec_mode_32) begin

        // mul Ah * Bl for vec_mode_32
        mul_2_16_src1 = mul_op1_i[31:16];
        mul_2_16_src2 = mul_op2_i[15:0];

      end else begin

        mul_2_16_src1 = '0;
        mul_2_16_src2 = '0;

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension for Xi[23:16] * mi[23:16]
        mul_2_16_src1 = {{8{mul_op1_i[23]}}, mul_op1_i[23:16]};
        mul_2_16_src2 = {{8{coeff_m_i[23]}}, coeff_m_i[23:16]};

      end else if (vec_mode_32) begin

        // mul Ah * Bl for vec_mode_32 where Bl is mi[15:0]
        mul_2_16_src1 = mul_op1_i[31:16];
        mul_2_16_src2 = coeff_m_i[15:0];

      end else begin

        mul_2_16_src1 = '0;
        mul_2_16_src2 = '0;

      end

    end else if (instr_i == 3'b011) begin  // MUL

      // mul Ah * Bl for vec_mode_32
      mul_2_16_src1 = mul_op1_i[31:16];
      mul_2_16_src2 = mul_op2_i[15:0];

    end else begin

      mul_2_16_src1 = '0;
      mul_2_16_src2 = '0;

    end
  end

  // Mux src for MUL1
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension
        mul_1_16_src1 = {{8{mul_op1_i[15]}}, mul_op1_i[15:8]};
        mul_1_16_src2 = {{8{mul_op2_i[15]}}, mul_op2_i[15:8]};

      end else if (vec_mode_32) begin

        // mul Al * Bh for vec_mode_32
        mul_1_16_src1 = mul_op1_i[15:0];
        mul_1_16_src2 = mul_op2_i[31:16];

      end else begin  //vec_mode_16

        // mul on 2 INT16 for vec_mode_16
        mul_1_16_src1 = mul_op1_i[31:16];
        mul_1_16_src2 = mul_op2_i[31:16];

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension for Xi[15:8] * mi[15:8]
        mul_1_16_src1 = mul_op1_i[15:8];
        mul_1_16_src2 = coeff_m_i[15:8];

      end else if (vec_mode_32) begin

        // mul Al * Bh for vec_mode_32 where Bh is mi[31:16]
        mul_1_16_src1 = mul_op1_i[15:0];
        mul_1_16_src2 = coeff_m_i[31:16];

      end else begin  //vec_mode_16

        // mul on 2 INT16 for vec_mode_16 for Xi[31:16] * mi[31:16]                
        mul_1_16_src1 = mul_op1_i[31:16];
        mul_1_16_src2 = coeff_m_i[31:16];

      end

    end else if (instr_i == 3'b011) begin  // MUL

      // mul Al * Bh
      mul_1_16_src1 = mul_op1_i[15:0];
      mul_1_16_src2 = mul_op2_i[31:16];

    end else begin

      mul_1_16_src1 = '0;
      mul_1_16_src2 = '0;

    end
  end

  // Mux src for MUL0
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // mul on 2 INT8 with sign extension
        mul_0_16_src1 = {{8{mul_op1_i[7]}}, mul_op1_i[7:0]};
        mul_0_16_src2 = {{8{mul_op2_i[7]}}, mul_op2_i[7:0]};

      end else begin

        // mul Al * Bl for vec_mode_32, or mul on 2 INT16 for vec_mode_16
        mul_0_16_src1 = mul_op1_i[15:0];
        mul_0_16_src2 = mul_op2_i[15:0];

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        // mul on 2 INT8 for Xi[7:0] * mi[7:0] with sign extension
        mul_0_16_src1 = {{8{mul_op1_i[7]}}, mul_op1_i[7:0]};
        mul_0_16_src2 = {{8{coeff_m_i[7]}}, coeff_m_i[7:0]};

      end else if (vec_mode_32) begin

        // mul Al * Bl, where Bl is mi[15:0]
        mul_0_16_src1 = mul_op1_i[15:0];
        mul_0_16_src2 = coeff_m_i[15:0];

      end else begin  //vec_mode_16

        // mul on 2 INT16 for Xi[15:0] * mi[15:0] with sign extension
        mul_0_16_src1 = mul_op1_i[15:0];
        mul_0_16_src2 = coeff_m_i[15:0];

      end

    end else if (instr_i == 3'b011) begin  // MUL

      // mul Al * Bl for vec_mode_32
      mul_0_16_src1 = mul_op1_i[15:0];
      mul_0_16_src2 = mul_op2_i[15:0];

    end else begin

      mul_0_16_src1 = '0;
      mul_0_16_src2 = '0;

    end
  end

  // Mux src for ADD0
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // add A[7:0] * B[7:0] + A[15:8] * B[15:8] with sign extension
        add_0_32_src1 = {{16{mul_0_32_res[15]}}, mul_0_32_res[15:0]};
        add_0_32_src2 = {{16{mul_1_32_res[15]}}, mul_1_32_res[15:0]};

      end else if (vec_mode_16) begin

        // add A[15:0] * B[15:0] + A[31:16] * B[31:16] for vec_mode_16
        add_0_32_src1 = mul_0_32_res;
        add_0_32_src2 = mul_1_32_res;

      end else begin  // vec_mode_32

        // (Al * Bh) + (Ah * Bl) for vec_mode_32
        add_0_32_src1 = mul_1_32_res;
        add_0_32_src2 = mul_2_32_res;

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        // add Xi[7:0] * mi[7:0] + qi[7:0] with sign extension
        add_0_32_src1 = {{16{mul_0_32_res[15]}}, mul_0_32_res[15:0]};
        add_0_32_src2 = {{24{coeff_q_i[7]}}, coeff_q_i[7:0]};

      end else if (vec_mode_16) begin

        // add Xi[15:0] * mi[15:0] + qi[15:0] for vec_mode_16 with sign extension
        add_0_32_src1 = mul_0_32_res;
        add_0_32_src2 = {{16{coeff_q_i[15]}}, coeff_q_i[15:0]};

      end else begin  //vec_mode_32

        // (Al * Bh) + (Ah * Bl) for vec_mode_32
        add_0_32_src1 = mul_1_32_res;
        add_0_32_src2 = mul_2_32_res;

      end

    end else if (instr_i == 3'b000) begin  // ADD

      // add on 2 INT32
      add_0_32_src1 = add_op1_i;
      add_0_32_src2 = add_op2_i;

    end else if (instr_i == 3'b001) begin  // MUL

      // (Al * Bh) + (Ah * Bl) for vec_mode_32
      add_0_32_src1 = mul_1_32_res;
      add_0_32_src2 = mul_2_32_res;

    end else begin

      add_0_32_src1 = '0;
      add_0_32_src2 = '0;

    end
  end

  // Mux src for ADD1
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // add A[31:24] * B[31:24] + A[23:16] * B[23:16] with sign extension
        add_1_16_src1 = {{1{mul_2_32_res[15]}}, mul_2_32_res[15:0]};
        add_1_16_src2 = {{1{mul_3_16_res[15]}}, mul_3_16_res[15:0]};

      end else begin  //vec_mode_16 and vec_mode_32

        add_1_16_src1 = '0;
        add_1_16_src2 = '0;

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        // add Xi[23:16] * mi[23:16] + qi[23:16] with sign extension
        add_1_16_src1 = {{1{mul_1_32_res[15]}}, mul_1_32_res[15:0]};
        add_1_16_src2 = {{8{coeff_q_i[15]}}, coeff_q_i[15:8]};

      end else begin  //vec_mode_32 and vec_mode_16

        add_1_16_src1 = '0;
        add_1_16_src2 = '0;

      end

    end else begin

      add_1_16_src1 = '0;
      add_1_16_src2 = '0;

    end
  end


  // Mux src for ADD2
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        // add A[31:24] * B[31:24] + A[23:16] * B[23:16] (+) A[15:8] * B[15:8] + A[7:0] * B[7:0]
        add_2_32_src1 = add_0_32_res;
        add_2_32_src2 = {{15{add_1_16_res[16]}}, add_1_16_res[16:0]};

      end else if (vec_mode_16) begin

        // accumulation for vec_mode_16, add A[31:16] * B[31:16] + A[15:0] * B[15:0] (+) feedback_acc_op
        add_2_32_src1 = feedback_acc_op;
        add_2_32_src2 = add_0_32_res;

      end else begin

        add_2_32_src1 = mul_0_32_res;
        add_2_32_src2 = {add_0_32_res[31:16], {{8{1'b0}}}};

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        add_2_32_src1 = {{16{mul_2_32_res[15]}}, mul_2_32_res[15:0]};
        add_2_32_src2 = {{24{coeff_q_i[23]}}, coeff_q_i[23:16]};

      end else if (vec_mode_32) begin

        add_2_32_src1 = mul_0_32_res;
        add_2_32_src2 = {add_0_32_res[31:16], {{8{1'b0}}}};

      end else begin  //vec_mode_16

        // add Xi[31:24] * mi[31:24] + qi[31:24] for vec_mode_16 with sign extension
        add_2_32_src1 = mul_1_32_res;
        add_2_32_src2 = {{16{coeff_q_i[31]}}, coeff_q_i[31:24]};

      end

    end else if (instr_i == 3'b001) begin  // MUL

      add_2_32_src1 = mul_0_32_res;
      add_2_32_src2 = {add_0_32_res[31:16], {{8{1'b0}}}};

    end else begin

      add_2_32_src1 = '0;
      add_2_32_src2 = '0;

    end
  end

  // Mux src for ADD3
  always_comb begin
    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8 || vec_mode_32) begin

        add_3_32_src1 = feedback_acc_op;
        add_3_32_src2 = add_2_32_res;

      end else begin

        add_3_32_src1 = '0;
        add_3_32_src2 = '0;

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        add_3_32_src1 = {{16{mul_3_16_res[15]}}, mul_3_16_res[15:0]};
        add_3_32_src2 = {{24{coeff_q_i[31]}}, coeff_q_i[31:24]};

      end else if (vec_mode_32) begin

        add_3_32_src1 = add_2_32_res;
        add_3_32_src2 = coeff_q_i;

      end else begin  //vec_mode_16

        add_3_32_src1 = '0;
        add_3_32_src2 = '0;

      end

    end else begin

      add_3_32_src1 = '0;
      add_3_32_src2 = '0;

    end
  end


  // result selection

  always_comb begin

    if (instr_i == 3'b010) begin  // MAC

      if (vec_mode_8) begin

        mul_res_o = '0;
        add_res_o = add_3_32_res;

      end else if (vec_mode_16) begin

        mul_res_o = '0;
        add_res_o = add_2_32_res;

      end else begin  // vec_mode_32

        mul_res_o = '0;
        add_res_o = add_2_32_res;

      end

    end else if (instr_i == 3'b011) begin  // PWL

      if (vec_mode_8) begin

        mul_res_o = '0;
        add_res_o = add_3_32_src1;

      end else if (vec_mode_16) begin

        mul_res_o = {mul_1_16_src1, mul_0_16_src1};
        add_res_o = add_2_32_src1;

      end else begin  // vec_mode_32

        mul_res_o = mul_0_16_src1;
        add_res_o = add_2_32_src1;

      end

    end else if (instr_i == 3'b000) begin  // ADD

      mul_res_o = '0;
      add_res_o = add_0_32_res;

    end else if (instr_i == 3'b001) begin  // MUL

      mul_res_o = add_2_32_res;
      add_res_o = '0;

    end else begin

      mul_res_o = '0;
      add_res_o = '0;

    end

  end


endmodule
