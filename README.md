# riscv-regfile-fault-modeling
SystemVerilog DV of a RISC-V register file with fault injection and coverage analysis

# RISC-V Register File Verification and Fault Modeling

This project implements and verifies a 32×32 RISC-V-compatible register file in **SystemVerilog**. It includes directed and randomized tests, fault injection (stuck-at, bit-flip), and functional coverage analysis using simulation tools like **EDA Playground** and **QuestaSim**.

## Features

- RISC-V-compliant 32×32 register file
- Functional verification with directed and randomized testbenches
- Dual-read / single-write support with write-first semantics
- Register x0 hardwired to zero (per RISC-V spec)
- Fault modeling with:
  - Stuck-at-0 and stuck-at-1 faults (single and multi-bit)
  - Bit-flip faults (randomized and deterministic)
- Functional and fault coverage metrics
- Regression test automation


## Simulation Setup

### Prerequisites

- SystemVerilog simulator: [QuestaSim](https://eda.sw.siemens.com/en-US/ic/questa/) or [EDA Playground](https://edaplayground.com)
- (Optional) GTKWave for waveform visualization
- Git, make (for script-based runs)

### Run Instructions

#### Using EDA Playground:
1. Upload `regfile.sv` and `tb_regfile.sv`
2. Set tool to **Questa / ModelSim**
3. Enable waveform and run simulation

#### Using Questa:
'cd tb
vlog ../rtl/regfile.sv tb_regfile_cv.sv
vsim -c work.tb_regfile_cv -do "run -all; quit"'

## Fault Injection Types:
- Stuck-at Faults: Force register bits to 0 or 1 and detect mismatches
- Multi-bit Faults: Inject burst errors (e.g., 3 bits in x27) to simulate radiation hits
- Bit-Flip Faults: Flip bits randomly or deterministically to emulate soft errors


## References:
1. Tollec et al., Exploration of fault effects on formal RISC-V models, IEEE FDTC 2022
2. Molina-Robles et al., Functional verification flow for RISC-V, IEEE PRIME-LA 2020
3. Barbirotta et al., Fault resilience analysis of RISC-V design, IEEE DFT 2020
4. Liew Y.H., RISC-V design verification with UVM, UTAR Thesis 2022

## Authors:
1. Camille Chang — tyuchang@ucdavis.edu
2. Chi-Yun (William) Wang — cywwang@ucdavis.edu
3. Yating Chang — cyating@ucdavis.edu
4. Zherong Yu — zryu@ucdavis.edu

## License
This project is released for academic and educational use. For commercial or research adoption, please contact the authors.

## Acknowledgments
Thanks to the UC Davis EEC 283 course and faculty for guidance on functional verification methodology and simulation tooling.






