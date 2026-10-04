// Copyright 2026 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: tb_mage_axi_wrapper.cpp
// Description: Minimal C++ wrapper / testbench for top-level mage_axi_wrapper.
//              Exercises reset and idle clock cycles to verify C++ compilation,
//              linking, and runtime initialization stability.

#include <iostream>
#include <memory>
#include <cstdlib>
#include <cstring>
#include <verilated.h>
#include "Vmage_axi_wrapper.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    auto top = std::make_unique<Vmage_axi_wrapper>();

    std::cout << "[VERILATOR C++ TB] Starting mage_axi_wrapper testbench..." << std::endl;

    // 1. Initialize input signals
    top->clk_i = 0;
    top->rst_ni = 0;
    std::memset(&top->axi_req_i, 0, sizeof(top->axi_req_i));
    std::memset(&top->axi_ctrl_req_i, 0, sizeof(top->axi_ctrl_req_i));

    // 2. Reset sequence: 10 full clock cycles (20 half-cycles) with active-low reset asserted
    for (int i = 0; i < 20; ++i) {
        top->clk_i = !top->clk_i;
        top->eval();
    }

    // 3. Deassert reset (active low)
    top->rst_ni = 1;

    // 4. Run for 20 full clock cycles (40 half-cycles) in idle state
    for (int i = 0; i < 40; ++i) {
        top->clk_i = !top->clk_i;
        top->eval();
    }

    std::cout << "[VERILATOR C++ TB] mage_axi_wrapper compiled, linked, and simulated successfully!" << std::endl;
    top->final();
    return EXIT_SUCCESS;
}
