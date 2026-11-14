`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Exhaustive single-bit flip campaign: 32 registers x 32 bits = 1024 faults
// A flip always changes the value, so every fault is activated except on x0,
// where the hardwired zero masks it.
// -----------------------------------------------------------------------------
module tb_regfile_bitflip_fullcov;

  `include "fault_tb_common.svh"

  int cv_addr, cv_bit;

  covergroup flip_cov;
    cp_addr : coverpoint cv_addr { bins addr[] = {[0:DEPTH-1]}; }
    cp_bit  : coverpoint cv_bit  { bins bits[] = {[0:WIDTH-1]}; }
    x_all   : cross cp_addr, cp_bit;                             // 1024 bins
  endgroup
  flip_cov cov = new();

  initial begin
    bit act, sb, sva;
    tb_init();
    $display("=== Exhaustive bit-flip sweep (1024 faults) ===");
    for (int a = 0; a < DEPTH; a++) begin
      for (int b = 0; b < WIDTH; b++) begin
        run_fault(F_FLIP, a[ADDRW-1:0], 32'b1 << b, $urandom(), act, sb, sva);
        cv_addr = a; cv_bit = b;
        cov.sample();
      end
    end
    print_summary("Exhaustive single-bit flip (1024 faults)");
    $display("Functional coverage (addr x bit, 1024 bins): %0.2f%%", cov.get_coverage());
    $finish;
  end

endmodule

