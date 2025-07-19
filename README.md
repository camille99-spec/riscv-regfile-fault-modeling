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
```
# Compile RTL and testbench vlog 
../rtl/regfile.sv ../tb/tb_regfile_cv.sv
# Simulate vsim
-c work.tb_regfile_cv -do "run -all; quit"
```


## Fault Injection Types:
- Stuck-at Faults: Force register bits to 0 or 1 and detect mismatches
- Multi-bit Faults: Inject burst errors (e.g., 3 bits in x27) to simulate radiation hits
- Bit-Flip Faults: Flip bits randomly or deterministically to emulate soft errors

## Results
The RISC-V register file successfully passed all functional tests, including both directed and randomized verification scenarios. Directed tests confirmed architectural correctness for key behaviors such as:
- Writes to general-purpose registers
- Enforcement of x0 hardwiring
- Read-after-write behavior (write-first semantics)
- Overwrite scenarios and simultaneous access patterns

### Functional Verification
A randomized test campaign of 10,000 stimuli vectors demonstrated 100% functional correctness with no assertion failures. The golden model mirrored every transaction, enabling cycle-accurate output comparison with the DUT. All mismatches were automatically flagged, and zero errors were reported during simulation.

### Fault Injection Performance
Fault Type	Total Cases	Detection Rate	Functional Coverage	Sim Time
Single-Bit Stuck-at	2048	~51%	100%	~12.3 ms
Multi-Bit Stuck-at	~100	>97%	>97%	~14.6 ms
Bit-Flip (Deterministic)	1024	100%	100%	~20.5 µs
Bit-Flip (Randomized)	10,000+	~98%	~34%	~27.8 ms

- Deterministic Bit-Flip Faults achieved 100% detection and 100% coverage, validating all bit locations across the 32×32 register array.
- Multi-bit faults revealed edge cases and latent propagation paths that were not visible in single-bit scenarios.
- Random bit-flip tests showed diminishing returns in coverage despite high injection counts, indicating the importance of strategic fault modeling.
- 
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






