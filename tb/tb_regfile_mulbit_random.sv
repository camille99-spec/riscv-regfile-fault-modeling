`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Randomized multi-bit stuck-at campaign (2-4 bits per fault, burst-style)
//   +NUM_FAULTS=<n>  number of random faults (default 200)
// -----------------------------------------------------------------------------
module tb_regfile_mulbit_random;

  `include "fault_tb_common.svh"

  logic [1:0] cv_type;
  int         cv_addr, cv_nbits;

  covergroup multi_cov;
    cp_type  : coverpoint cv_type  { bins sa0 = {F_SA0}; bins sa1 = {F_SA1}; }
    cp_addr  : coverpoint cv_addr  { bins addr[] = {[0:DEPTH-1]}; }
    cp_nbits : coverpoint cv_nbits { bins two = {2}; bins three = {3}; bins four = {4}; }
    x_type_addr : cross cp_type, cp_addr;                        // 64 bins
  endgroup
  multi_cov cov = new();

  int num_faults = 200;

  initial begin
    bit act, sb, sva;
    logic [1:0]       ft;
    logic [ADDRW-1:0] fa;
    logic [WIDTH-1:0] mask;
    int               want_bits;

    tb_init();
    void'($value$plusargs("NUM_FAULTS=%d", num_faults));
    $display("=== Random multi-bit stuck-at campaign: %0d faults ===", num_faults);

    repeat (num_faults) begin
      ft        = ($urandom_range(0, 1) == 0) ? F_SA0 : F_SA1;
      fa        = $urandom_range(0, DEPTH-1);
      want_bits = $urandom_range(2, 4);
      mask      = '0;
      while ($countones(mask) < want_bits)          // distinct bit positions
        mask[$urandom_range(0, WIDTH-1)] = 1'b1;
      run_fault(ft, fa, mask, $urandom(), act, sb, sva);
      cv_type = ft; cv_addr = fa; cv_nbits = want_bits;
      cov.sample();
    end

    print_summary($sformatf("Random multi-bit stuck-at (%0d faults)", num_faults));
    $display("Functional coverage (overall)     : %0.2f%%", cov.get_coverage());
    $display("Functional coverage (type x addr) : %0.2f%%", cov.x_type_addr.get_coverage());
    $finish;
  end

endmodule

