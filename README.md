# riscv-regfile-fault-modeling
SystemVerilog verification of a RISC-V register file with fault injection, SystemVerilog Assertions (SVA), and coverage analysis.

## Overview

A 32×32 RISC-V integer register file (x0–x31) is verified with:

- directed and constrained-random tests against a golden model,
- an **SVA checker** bound into the RTL (eight assertion groups + cover properties),
- **fault injection into the DUT** (stuck-at-0/1 single- and multi-bit, bit-flip) with a fault-free golden model, so a fault only counts as *detected* when a checker actually catches it in the design,
- functional coverage with explicit bins,
- a one-command Questa regression, and
- multi-seed runs to show the results are stable.

The design was also synthesized to a DE10-Lite FPGA for on-board fault demonstration (UC Davis EEC 283 team project). The SVA checker, DUT-side fault campaign, and regression are Camille Chang's extension for the M.S. comprehensive exam report.

## Repository layout

```
rtl/regfile.sv                     register file + read-path fault injector
rtl/regfile_sva.sv                 SVA checker (bound from each testbench)
tb/tb_regfile_cv.sv                directed tests + 10k random, golden model
tb/fault_tb_common.svh             shared fault-campaign harness
tb/tb_regfile_singlebit_fullcov.sv 2048 single-bit stuck-at (random + activating data)
tb/tb_regfile_singlebit_random.sv  random single-bit stuck-at
tb/tb_regfile_mulbit_random.sv     random 2–4-bit stuck-at
tb/tb_regfile_bitflip_fullcov.sv   1024 exhaustive bit-flips
tb/tb_regfile_bitflip_random.sv    random bit-flips (+NUM_FAULTS)
sim/run_regression.sh              compile + run everything, pass/fail summary (terminal)
sim/seeds.do                       re-run seed-dependent tests with seeds 1-5 (Questa GUI)
```

## Design

- Parameterized `WIDTH = 32`, `DEPTH = 32`
- Two asynchronous read ports, one synchronous write port
- **Write-first**: a same-cycle read of the register being written returns the new data (internal bypass)
- x0 hardwired to zero: writes ignored, reads return 0
- Fault injector on the read path (`fault_type`: 0 none, 1 bit-flip, 2 stuck-at-0, 3 stuck-at-1). Storage is never modified, which models transient/observation-point faults and matches the FPGA demo.

## Assertions (`rtl/regfile_sva.sv`)

| ID | Property | Checks |
|----|----------|--------|
| A1 | `raddr == 0 \|-> rdata == 0` (both ports) | x0 reads zero |
| A2 | `mem[0] == 0` | x0 storage never written |
| A3 | `we && waddr != 0 \|=> mem[$past(waddr)] == $past(wdata)` | write lands |
| A4 | `!(we && waddr == k) \|=> mem[k] == $past(mem[k])` (k = 1..31) | registers hold value |
| A5 | `raddr != 0 \|-> rdata == expected(storage or bypass)` | read data correct |
| A6 | `we && waddr != 0 && raddr == waddr \|-> rdata == wdata` | write-first |
| A7 | `fault_enable && raddr != fault_addr \|-> rdata == expected` | fault isolation |
| A8 | `!$isunknown(raddr) \|-> !$isunknown(rdata)` | no X on read data |

Cover properties: same-cycle collision, both ports on one address, back-to-back writes, write to x0, faulty read, fault masked at x0.

Each assertion has a failure counter; the fault testbenches read the counters to record which assertions caught each fault.

## Running

### Questa (full regression)
```
cd sim
./run_regression.sh [seed]
cat logs/summary.txt
```

### Questa GUI (single test)
Compile once:
```
vlib work
vlog -sv +incdir+tb rtl/regfile.sv rtl/regfile_sva.sv tb/*.sv
```
Then run a test from the transcript, and unload it before starting the next one:
```
vsim tb_regfile_cv
run -all
quit -sim
```
Plusargs: `+NUM_VECTORS=<n>` for `tb_regfile_cv`, `+NUM_FAULTS=<n>` for the random fault tests. Use `-sv_seed <n>` to change the random seed.
Don't use `quit -f` in the GUI, because it closes Questa.

### Questa GUI (multi-seed)
```
do sim/seeds.do
```
Runs `tb_regfile_singlebit_fullcov`, `tb_regfile_mulbit_random` (200 faults) and `tb_regfile_bitflip_random` (1,000 faults) with seeds 1-5, and writes the summary lines to `seed_results.txt`.

### Recommended order
1. `tb_regfile_cv`: the design and the assertion checker must agree (0 errors, 0 assertion failures) before fault results mean anything.
2. `tb_regfile_bitflip_fullcov`: has a known exact answer (992 activated / 32 masked), which validates the fault harness.
3. The remaining fault tests.

### EDA Playground
Put `regfile.sv` and `regfile_sva.sv` in the design pane and one testbench (plus `fault_tb_common.svh` for the fault tests) in the testbench pane. Select Questa/ModelSim, set the top to the testbench module, and run.

## Fault-campaign metrics

Every fault experiment writes clean data, then enables the fault and reads the register. Each run reports:

- **activated** – the fault actually changes the read value. A stuck-at whose bit already holds the stuck value, or any fault on x0, is *masked*.
- **scoreboard detected** – DUT output ≠ fault-free golden model.
- **assertion detected** – at least one SVA fired during the faulty read.
- **escape** – activated but not caught; **false** – a checker fired on a masked fault. Both must be 0 for a test to pass.

## Results (QuestaSim 2024.1)

**Functional (`tb_regfile_cv`):** 4 directed tests plus 10,000 random cycles, 20,020 port checks, 0 scoreboard errors, 0 assertion failures, 100% functional coverage.

Cover-property hits in the random run: collision 879, same-address dual read 293, back-to-back writes 80, write to x0 148. The two fault cover properties are only reachable in the fault tests.

**Fault campaigns (default seed):**

| Campaign | Faults | Activated | Scoreboard det. | SVA det. | Escapes | Cross cov. |
|---|---|---|---|---|---|---|
| Stuck-at single, random data | 2048 | 1040 | 1040 | 1040 | 0 | 100% |
| Stuck-at single, activating data | 2048 | 1984 | 1984 | 1984 | 0 | 100% |
| Stuck-at single, random | 200 | 97 | 97 | 97 | 0 | 95.31% |
| Stuck-at multi-bit, random | 200 | 166 | 166 | 166 | 0 | 95.31% |
| Bit-flip, exhaustive | 1024 | 992 | 992 | 992 | 0 | 100% |
| Bit-flip, random | 100 | 98 | 98 | 98 | 0 | 9.47% |
| Bit-flip, random | 1000 | 968 | 968 | 968 | 0 | 63.48% |
| Bit-flip, random | 10000 | 9723 | 9723 | 9723 | 0 | 100% |

False detections were 0 in every campaign. Assertion A5 (read data) fired exactly once per activated fault. A3/A4 (storage), A7 (isolation) and A1 (x0) never fired, so the checker places every fault in the read path and confirms that faults stay isolated and x0 is immune.

**Seed sensitivity (default seed + seeds 1-5):**

| Metric | Range | Mean | Expected |
|---|---|---|---|
| Stuck-at, random data: activated / 2048 | 980-1040 | 994.5 | 992 |
| Multi-bit stuck-at: activated / 200 | 161-175 | 167.0 | 165.4 |
| Bit-flip 1,000: addr x bit coverage | 59.57-63.48% | 61.73% | 62.4% |

Across 43,100 injected faults over six seeds, all 35,592 activated faults were caught by both the scoreboard and the assertions, with no escapes or false alarms.

**Key finding:** whether a stuck-at fault is detected depends mainly on the data written before injection (about 50% activated with random data, 96.9% with complementary data), not on the checkers. Every activated fault was caught.

## Fixes in this revision

- The fault ports were not connected in any testbench, and faults were applied to the golden model instead of the DUT. They are now connected, and the golden model stays fault-free.
- `fault_type` was 1 bit in the testbenches but 2 bits in the RTL. It now uses the RTL encoding.
- Random bit-flip coverage used an auto-binned `int`, which pinned coverage near 34%. Explicit bins replace it.
- `tb_regfile_singlebit_fullcov` counted matches as "detected" and skipped x0. Both are corrected.
- Restored the write-first bypass, which the repo RTL had lost.
- Read outputs now use `always_comb`, so fault and storage changes propagate to the outputs.
- Added the missing directed/random testbench, the SVA checker, the regression script, and the multi-seed script.
- The SVA `mem` port is declared `input var` to remove a vopt warning.

## References
1. S. Tollec et al., "Exploration of fault effects on formal RISC-V microarchitecture models," FDTC 2022.
2. R. Molina-Robles et al., "A compact functional verification flow for a RISC-V 32I based core," PRIME-LA 2020.
3. Y. H. Liew, "Verification of RISC-V design with Universal Verification Methodology (UVM)," UTAR, 2022.
4. S. Ahmadi-Pour, V. Herdt, R. Drechsler, "Constrained random verification for RISC-V: overview, evaluation and discussion," MBMV 2021.
5. M. Barbirotta et al., "Fault resilience analysis of a RISC-V microprocessor design through a dedicated UVM environment," DFT 2020.

## Authors
Camille Chang, Chi-Yun (William) Wang, Yating Chang, Zherong Yu — UC Davis

## License
Academic and educational use. Contact the authors for other uses.

## Acknowledgments
UC Davis EEC 283 course and faculty.
