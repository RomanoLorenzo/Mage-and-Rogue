# Mage: a decoupled access-execute CGRA tailored for static control kernels

Mage is a Coarse-Grained Reconfigurable Architecture (CGRA) designed to accelerate static control kernels (i.e. kernels whose control flow does not feature data-dependent branches and can be determined at compile-time) by decoupling memory access from actual data computation. By offloading memory access management to a dedicated Address Generation Unit (AGU), Mage allows its Processing Element Array (PEA) to focus exclusively on data processing.

![Mage Architecture Overview](doc/images/Mage.png)

## About

Modern applications in the signal processing and machine learning domains demand architectures that combine flexibility with energy efficiency. At kernel level, static control flow and affine memory access patterns are key characteristics of these applications. While CGRAs can combine flexibility with energy efficiency, traditional approaches to these architectures often overlook a fundamental question: *can a subset of applications be identified that would benefit most from CGRA acceleration?*

Mage focuses on static control kernels as, thanks to their key characteristics (i.e. *static control flow*
and *affine memory access patterns*) they are particularly well-suited for CGRA acceleration. In addition, Mage leverages the *Decoupled Access-Execute* computation paradigm, which allows Mage to employ a dedicated unit (the AGU) tailored for address computation. By imposing a well-defined data layout (*Generalised Memory Partitioning Scheme (GMP)*) within the internal multi-bank Scratchpad Memory (SpM), multiple Address Generation Engines (AGE) inside Mage's AGU can access the SpM without incurring in conflict, thus achieving high bandwidth towards the PEA, which only focuses on data-related computation.

## Architecture Overview

The main components of Mage are the following:

### 1. Address Generation Unit (AGU)
It is in charge of computing addresses to access the internal multi-bank scratchpad memory, and it consists of:

- **Hardware Loop Unit (HLU):**  
  The HLU computes iteration variables (IVs) for up to four nested loops, which are essential for generating the affine address patterns typical of SCPs.
- **Address Generation Engines (AGEs):**  
  AGEs are configured via a 32-bit word to compute GMP-compliant addresses for up to 4D access to arrays.
- **Control and Dispatch:**  
  A Hardware Loop Dispatcher Unit (HLDU) selects the appropriate IVs from the Hardware Loop Register File (HLRF) and directs them to the AGEs. This mechanism ensures that load/store operations are issued correctly based on the control flow dictated by the IVs.

### 2. Processing Element Array (PEA)
- **2D Mesh Structure:**  
  The PEA is a grid of lightweight processing elements, each with a configurable functional unit. The PEs are designed to perform arithmetic and bitwise operations on 32-bit data. They also provide support for packed SIMDY operations on reduced-precision (8 or 16 bit-wide) operands.

### 3. Crossbars and Data Streams
- **Interconnection Strategy:**  
  Instead of a fully connected crossbar system, Mage employs smaller crossbar subsystems that link groups of AGEs, memory banks, and PEA I/O registers. This grouping facilitates the formation of distinct data streams for load and store operations, ensuring that address and data paths are efficiently managed with minimal conflict.

### 4. Multi-Bank Memory Subsystem
- **Generalized Memory Partitioning (GMP):**  
  Within the internal scratchpad memory (SpM), arrays are mapped across multiple banks using the GMP scheme, which distributes data blocks in a way that minimizes access conflicts and maximizes memory bandwidth.


## Struttura della repo

L'infrastruttura di build e dipendenze è ora organizzata come segue:

1. **Vendoring selettivo (`vendor/*.vendor.hjson`):**
   - Non viene utilizzato FuseSoC per scaricare i sorgenti esterni, bensì lo script OpenTitan `util/vendor.py`.
   - I file `.vendor.hjson` specificano i repository Git a monte, il commit/tag di riferimento (`rev`) e un campo `mapping:` che estrae chirurgicamente solo i singoli file necessari (es. in `pulp_platform_tech_cells_generic.vendor.hjson` viene mappato solo `src/rtl/mage_tc_sram.sv`).
   - Il target `make re-vendor` (o `re-vendor-quick`) popola la directory locale `vendor/` e congela gli hash nei file `.lock.hjson`.

2. **Generazione RTL e Registri (`mage-gen` / `regtool`):**
   - `util/mage-gen.py` genera i file `.sv` definitivi partendo dai template `.sv.tpl` e dalla configurazione hardware.
   - `util/regtool.py`genera l'interfaccia registri `mage_regs.hjson` e il file `mage_reg_top.sv`.

3. **Gestione con Bender e Manifest (`Bender.yml`):**
   - `Bender.yml` non dichiara dipendenze esterne dinamiche (il blocco `dependencies:` è assente), bensì agisce da **manifest statico**: elenca in `sources: files:` tutti i file necessari (sia i vendorizzati sia i file interni di Mage) in ordine topologico di compilazione (prima i package `*_pkg.sv`, poi le primitive, i sottomoduli di accesso/calcolo, la memoria, fino ai wrapper top-level).
   - I target `make flist` e `make flist-relative` eseguono `bender script flist` per produrre il file `Flist.mage`.

4. **Validazione Standalone (`waivers.vlt`):**
   - Il target `make check-verilator` compila `hw/mage_axi_wrapper.sv` con Verilator in modalità `--lint-only`. Eseguendo il comando, il linting in modalità standalone **passa con successo (exit code 0)**.

### Dipendenze
Questo progetto dipende da:
- `lowRISC/opentitan` @ commit hash: `47a0f4798febd9e53dd131ef8c8c2b0255d8c139`
- `pulp-platform/axi_obi` @ version: `v0.1.0`
- `pulp-platform/axi` @ version: `v0.39.8`
- `pulp-platform/common_cells` @ version: `v1.38.0`
- `pulp-platform/obi` @ version: `v0.1.7`
- `pulp-platform/register_interface` @ version: `v0.4.7`
- `pulp-platform/tech_cells_generic` @ version: `v0.2.11`

## Comandi
Dalla root ./ esegui:
- `make re-vendor`: scaricare/aggiornare le dipendenze.
- `make mage-gen`: generare la configurazione di mage specificata nella variabile `MAGE_CFG_HJSON` del `Makefile`.
- `make flist-local`: genera `Flist-local.mage` per compilazione locale di Verilator a partire dal `Bender-local.yml` file.
- `make check-verilator`: controlla che tutti i file compilino e le dipendenze siano risolte. Archivia i _Warning_ in `verilator_lint.log`. Nota: il file `waivers.vlt` è lasciato vuoto on-purpose per segnalare tutti i warnings.
- `make clean-repo`: per cancellare le cartelle di build e sintesi e cancellare i file/cartelle gitignorati.