// Copyright 2025 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: dmem_decoder.sv
// Author: Alessio Naclerio
// Date: 26/02/2025
// Description: This module handles tha access to internal SpM from both the CGRA and the external system

module dmem_decoder
  import pea_pkg::*;
  import agu_pkg::*;
(
    input                                               clk_i,
    input                                               rst_n_i,
    input  state_t                                      state_i,
    input  logic   [2:0]                                reg_block_size_i,
    input  logic   [N_STREAMS-1:0]                      reg_stream_xor_mode_i,
    /* CGRA to internal SpM */
    input  logic   [N_BANKS-1:0]                        agu_dmem_req_i,
    input  logic   [N_BANKS-1:0]                        agu_dmem_we_i,
    input  logic   [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] agu_dmem_addr_i,
    input  logic   [N_BANKS-1:0][           N_BITS-1:0] agu_dmem_wdata_i,
    /* External system to internal SpM */
    input  logic                                        ext_dmem_req_i,
    input  logic                                        ext_dmem_we_i,
    input  logic   [        3:0]                        ext_dmem_be_i,
    input  logic   [     32-1:0]                        ext_dmem_addr_i,
    input  logic   [     32-1:0]                        ext_dmem_wdata_i,
    /* Selected outputs to internal SpM */
    output logic   [N_BANKS-1:0]                        dmem_req_o,
    output logic   [N_BANKS-1:0]                        dmem_we_o,
    output logic   [N_BANKS-1:0][                  3:0] dmem_be_o,
    output logic   [N_BANKS-1:0][$clog2(BANK_SIZE)-1:0] dmem_addr_o,
    output logic   [N_BANKS-1:0][           N_BITS-1:0] dmem_wdata_o,
    output logic   [N_BANKS-1:0][           N_BITS-1:0] agu_dmem_rdata_o,
    input  logic   [N_BANKS-1:0][           N_BITS-1:0] dmem_rdata_i,
    output logic                                        ext_dmem_valid_o,
    output logic                                        ext_dmem_gnt_o,
    output logic   [     32-1:0]                        ext_dmem_rdata_o



);

<%
import math as m
word_bits = int(m.log2(num_words))
bank_bits = max(int(m.ceil(m.log2(n_age_tot))), 1)
bank_lsb = word_bits
bank_msb = bank_lsb + bank_bits - 1
addr_lrs_width = max(bank_msb + 1, 17)
%>
  logic                                 is_dmem_address;
  logic [           ${addr_lrs_width-1}:0] addr_lrs_2;
  logic [          N_BANKS-1:0]         active_banks;

  logic [          N_BANKS-1:0]         ext_dmem_req;
  logic [          N_BANKS-1:0][   3:0] ext_dmem_be;
  logic [          N_BANKS-1:0]         ext_dmem_req_d;
  logic [          N_BANKS-1:0]         ext_dmem_we;
  logic [          N_BANKS-1:0][32-1:0] ext_dmem_rdata;

  logic [$clog2(BANK_SIZE)-1:0]         addr_to_bank;


  assign addr_lrs_2 = ext_dmem_addr_i[${addr_lrs_width+1}:2];

  logic [${bank_bits-1}:0] bank_idx_raw;
  assign bank_idx_raw = addr_lrs_2[${bank_msb}:${bank_lsb}];

%for s, b_cnt in enumerate(n_age_per_stream_ds):
  <%
    b_s = 0 if b_cnt == 1 else int(m.log2(b_cnt))
    k_s = sum(n_age_per_stream_ds[:s])
  %>
  %if b_cnt == 1:
  logic stream_${s}_sel;
  assign stream_${s}_sel = (bank_idx_raw == ${bank_bits}'d${k_s});
  %else:
  logic stream_${s}_sel;
  logic [${b_s - 1}:0] stream_${s}_rel_bank;
  logic [${b_s + word_bits - 1}:0] stream_${s}_waddr;
  logic [${word_bits - 1}:0] stream_${s}_ba_interleaved;
  logic [${b_s - 1}:0] stream_${s}_bi_interleaved;
  logic [${b_s - 1}:0] stream_${s}_bi_xor;
  logic [${b_s - 1}:0] stream_${s}_bi_sel;
  logic [${word_bits - 1}:0] stream_${s}_ba_sel;
  logic stream_${s}_sn;

  assign stream_${s}_sel = (bank_idx_raw >= ${bank_bits}'d${k_s} && bank_idx_raw <= ${bank_bits}'d${k_s + b_cnt - 1});
  assign stream_${s}_rel_bank = bank_idx_raw - ${bank_bits}'d${k_s};
  assign stream_${s}_waddr = { stream_${s}_rel_bank, addr_lrs_2[${word_bits - 1}:0] };
  assign stream_${s}_ba_interleaved = stream_${s}_waddr[${b_s + word_bits - 1}:${b_s}];
  assign stream_${s}_bi_interleaved = stream_${s}_waddr[${b_s - 1}:0];
  assign stream_${s}_sn = ^stream_${s}_ba_interleaved;
  assign stream_${s}_bi_xor = stream_${s}_bi_interleaved ^ (stream_${s}_sn << ${b_s - 1});

  assign stream_${s}_bi_sel = (reg_block_size_i[2] && reg_stream_xor_mode_i[${s}]) ? stream_${s}_bi_xor : stream_${s}_bi_interleaved;
  assign stream_${s}_ba_sel = stream_${s}_ba_interleaved;
  %endif
%endfor

  always_comb begin
    active_banks = '0;
    addr_to_bank = '0;

    if (reg_block_size_i[1:0] == 2'b00) begin
      addr_to_bank = addr_lrs_2[$clog2(BANK_SIZE)-1:0];
%for i in range(n_age_tot):
      active_banks[${i}] = (bank_idx_raw == ${bank_bits}'d${i}) ? 1'b1 : 1'b0;
%endfor
    end else begin
%for s, b_cnt in enumerate(n_age_per_stream_ds):
  <%
    b_s = 0 if b_cnt == 1 else int(m.log2(b_cnt))
    k_s = sum(n_age_per_stream_ds[:s])
  %>
  %if b_cnt == 1:
      if (stream_${s}_sel) begin
        addr_to_bank = addr_lrs_2[$clog2(BANK_SIZE)-1:0];
        active_banks[${k_s}] = 1'b1;
      end
  %else:
      if (stream_${s}_sel) begin
        addr_to_bank = stream_${s}_ba_sel;
    %for j in range(b_cnt):
      <% b_idx = k_s + j %>
        active_banks[${b_idx}] = (stream_${s}_bi_sel == ${b_s}'d${j}) ? 1'b1 : 1'b0;
    %endfor
      end
  %endif
%endfor
    end
  end

    always_comb begin
    is_dmem_address = (ext_dmem_addr_i[32-1:32-4] == 4'b1111) ? 1'b1 : 1'b0;

    if (is_dmem_address == 1'b1) begin

      if (active_banks[0]) begin
        ext_dmem_req = {${n_age_tot-1}'d0, ext_dmem_req_i};
  %for i in range (1, n_age_tot):
      end else if (active_banks[${i}]) begin
    %if n_age_tot - i -1 == 0:
        ext_dmem_req = {ext_dmem_req_i, ${i}'b0};
    %else:
        ext_dmem_req = {${n_age_tot - i -1}'b0, ext_dmem_req_i, ${i}'b0};
    %endif
  %endfor
      end else begin
        ext_dmem_req = '0;
      end

      for (int i = 0; i < N_BANKS; i++) begin
        ext_dmem_we[i] = ext_dmem_req[i] & ext_dmem_we_i;
        ext_dmem_be[i] = ext_dmem_be_i;
      end

    end else begin
      ext_dmem_req = '0;
      ext_dmem_we  = '0;
      ext_dmem_be  = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      ext_dmem_req_d   <= '0;
      ext_dmem_valid_o <= '0;
      ext_dmem_gnt_o   <= '0;
    end else begin
      ext_dmem_valid_o <= |ext_dmem_req;
      ext_dmem_gnt_o   <= |ext_dmem_req;
      ext_dmem_req_d   <= ext_dmem_req;
    end
  end


  //Based on the state, select the right inputs to feed to the internal SpM
  always_comb begin
    case (state_i)

      /*
        In the EXEC state:
          > The CGRA can read/write to banks
          > The external system can read/write to banks
        However:
          ! The CGRA and the external systems MUST interact with different sets of banks
      */

      EXEC: begin

        // SpM accepts requests from AGU and external system
        dmem_req_o = agu_dmem_req_i | ext_dmem_req;

        for (int i = 0; i < N_BANKS; i++) begin

          // SpM WE chosen based on external request bit
          dmem_we_o[i] = (ext_dmem_req[i] == 1'b1) ? ext_dmem_we[i] : agu_dmem_we_i[i];

          // SpM BE chosen based on external request bit
          dmem_be_o[i] = (ext_dmem_req[i] == 1'b1) ? ext_dmem_be[i] : 4'b1111;

          // SpM address chosen based on external request bit
          dmem_addr_o[i] = (ext_dmem_req[i] == 1'b1) ? addr_to_bank : agu_dmem_addr_i[i];

          // SpM write data chosen based on external request bit
          dmem_wdata_o[i] = (ext_dmem_req[i] == 1'b1) ? ext_dmem_wdata_i : agu_dmem_wdata_i[i];
        end

        // SpM read data towards external system based on external request bit
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata[i] = {32{ext_dmem_req_d[i]}} & dmem_rdata_i[i];
        end

        ext_dmem_rdata_o = '0;
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata_o |= ext_dmem_rdata[i];
        end

        // SpM read data towards PEA based on AGEs valid bits
        for (int i = 0; i < N_BANKS; i++) begin
          agu_dmem_rdata_o[i] = dmem_rdata_i[i];
        end

      end

      /*
        In the IDLE state:
          > The CGRA CANNOT read/write to banks
          > The external system can read/write to banks
      */

      default: begin
        // SpM accepts requests from external system
        dmem_req_o = ext_dmem_req;

        // SpM accepts WE from external system
        dmem_we_o  = ext_dmem_we;

        // SpM accepts BE from external system
        dmem_be_o  = ext_dmem_be;

        for (int i = 0; i < N_BANKS; i++) begin

          // SpM address chosen based on external request bit
          dmem_addr_o[i]  = (ext_dmem_req[i] == 1'b1) ? addr_to_bank : '0;

          // SpM write data is taken from external system
          dmem_wdata_o[i] = ext_dmem_wdata_i;
        end

        // SpM read data towards external system based on external request bit
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata[i] = {32{ext_dmem_req_d[i]}} & dmem_rdata_i[i];
        end

        ext_dmem_rdata_o = '0;
        for (int i = 0; i < N_BANKS; i++) begin
          ext_dmem_rdata_o |= ext_dmem_rdata[i];
        end

        // SpM read data towards PEA is alaways 0
        agu_dmem_rdata_o = '0;
      end
    endcase
  end


endmodule : dmem_decoder
