`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Exhaustive single-bit stuck-at campaign
//   2 polarities x 32 registers x 32 bits = 2048 fault sites
//   Pass 1 (random data)     : data is random, so a stuck-at is only activated
//                              when the stored bit differs from the stuck value
//   Pass 2 (activating data) : the data bit is forced to the opposite of the
//                              stuck value, so every fault outside x0 is activated
// -----------------------------------------------------------------------------
module tb_regfile_singlebit_fullcov;

  `include "fault_tb_common.svh"

  logic [1:0] cv_type;
  int         cv_addr, cv_bit;

  covergroup stuck_cov;
    cp_type : coverpoint cv_type { bins sa0 = {F_SA0}; bins sa1 = {F_SA1}; }
    cp_addr : coverpoint cv_addr { bins addr[] = {[0:DEPTH-1]}; }
    cp_bit  : coverpoint cv_bit  { bins bits[] = {[0:WIDTH-1]}; }
    x_all   : cross cp_type, cp_addr, cp_bit;                    // 2048 bins
  endgroup
  stuck_cov cov = new();

  task automatic sweep(input bit activating_data);
    bit act, sb, sva;
    logic [WIDTH-1:0] mask, data;
    for (int t = 0; t < 2; t++) begin
      for (int a = 0; a < DEPTH; a++) begin
        for (int b = 0; b < WIDTH; b++) begin
          logic [1:0] ft;
          ft   = (t == 0) ? F_SA0 : F_SA1;
          mask = 32'b1 << b;
          data = $urandom();
          if (activating_data)
            data = (ft == F_SA0) ? (data | mask) : (data & ~mask);
          run_fault(ft, a[ADDRW-1:0], mask, data, act, sb, sva);
          cv_type = ft; cv_addr = a; cv_bit = b;
          cov.sample();
        end
      end
    end
  endtask

  initial begin
    tb_init();

    $display("=== Pass 1: single-bit stuck-at, random data ===");
    sweep(1'b0);
    print_summary("Single-bit stuck-at, RANDOM data (2048 faults)");
    $display("Functional coverage (type x addr x bit, 2048 bins): %0.2f%%", cov.get_coverage());

    n_injected = 0; n_activated = 0; n_masked = 0; n_sb_det = 0;
    n_sva_det = 0; n_escaped = 0; n_false = 0;
    dut.u_sva.n_a5_read = 0;  dut.u_sva.n_a3_write = 0;
    dut.u_sva.n_a4_hold = 0;  dut.u_sva.n_a7_isolation = 0;

    $display("=== Pass 2: single-bit stuck-at, activating data ===");
    sweep(1'b1);
    print_summary("Single-bit stuck-at, ACTIVATING data (2048 faults)");
    $display("Functional coverage (type x addr x bit, 2048 bins): %0.2f%%", cov.get_coverage());
    $finish;
  end

endmodule


