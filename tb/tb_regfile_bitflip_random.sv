`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Randomized single-bit flip campaign
//   +NUM_FAULTS=<n>  number of random flips (default 10000)
// Coverage uses explicit bins for the 32 bit positions; with the previous
// auto-binned `int`, all 32 positions fell into one of 64 auto bins and the
// reported coverage was stuck near 34% regardless of the number of faults.
// -----------------------------------------------------------------------------
module tb_regfile_bitflip_random;

  `include "fault_tb_common.svh"

  int cv_addr, cv_bit;

  covergroup flip_cov;
    cp_addr : coverpoint cv_addr { bins addr[] = {[0:DEPTH-1]}; }
    cp_bit  : coverpoint cv_bit  { bins bits[] = {[0:WIDTH-1]}; }
    x_all   : cross cp_addr, cp_bit;                             // 1024 bins
  endgroup
  flip_cov cov = new();

  int num_faults = 10000;

  initial begin
    bit act, sb, sva;
    logic [ADDRW-1:0] fa;
    int               fb;

    tb_init();
    void'($value$plusargs("NUM_FAULTS=%d", num_faults));
    $display("=== Random bit-flip campaign: %0d faults ===", num_faults);

    repeat (num_faults) begin
      fa = $urandom_range(0, DEPTH-1);
      fb = $urandom_range(0, WIDTH-1);
      run_fault(F_FLIP, fa, 32'b1 << fb, $urandom(), act, sb, sva);
      cv_addr = fa; cv_bit = fb;
      cov.sample();
    end

    print_summary($sformatf("Random single-bit flip (%0d faults)", num_faults));
    $display("Functional coverage (overall)       : %0.2f%%", cov.get_coverage());
    $display("Functional coverage (addr x bit)    : %0.2f%%", cov.x_all.get_coverage());
    $finish;
  end

endmodule
