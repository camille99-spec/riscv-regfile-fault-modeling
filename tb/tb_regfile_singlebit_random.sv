`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Randomized single-bit stuck-at campaign
//   +NUM_FAULTS=<n>  number of random faults (default 200)
//   +SEED handled by the simulator (e.g. vsim -sv_seed 7)
// -----------------------------------------------------------------------------
module tb_regfile_singlebit_random;

  `include "fault_tb_common.svh"

  logic [1:0] cv_type;
  int         cv_addr, cv_bit;

  covergroup stuck_cov;
    cp_type : coverpoint cv_type { bins sa0 = {F_SA0}; bins sa1 = {F_SA1}; }
    cp_addr : coverpoint cv_addr { bins addr[] = {[0:DEPTH-1]}; }
    cp_bit  : coverpoint cv_bit  { bins bits[] = {[0:WIDTH-1]}; }
    x_type_addr : cross cp_type, cp_addr;                        // 64 bins
  endgroup
  stuck_cov cov = new();

  int num_faults = 200;

  initial begin
    bit act, sb, sva;
    logic [1:0]       ft;
    logic [ADDRW-1:0] fa;
    int               fb;
    logic [WIDTH-1:0] mask;

    tb_init();
    void'($value$plusargs("NUM_FAULTS=%d", num_faults));
    $display("=== Random single-bit stuck-at campaign: %0d faults ===", num_faults);

    repeat (num_faults) begin
      ft   = ($urandom_range(0, 1) == 0) ? F_SA0 : F_SA1;
      fa   = $urandom_range(0, DEPTH-1);
      fb   = $urandom_range(0, WIDTH-1);
      mask = 32'b1 << fb;
      run_fault(ft, fa, mask, $urandom(), act, sb, sva);
      cv_type = ft; cv_addr = fa; cv_bit = fb;
      cov.sample();
    end

    print_summary($sformatf("Random single-bit stuck-at (%0d faults)", num_faults));
    $display("Functional coverage (overall)     : %0.2f%%", cov.get_coverage());
    $display("Functional coverage (type x addr) : %0.2f%%", cov.x_type_addr.get_coverage());
    $display("Functional coverage (bit)         : %0.2f%%", cov.cp_bit.get_coverage());
    $finish;
  end

endmodule
