`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Functional verification of regfile (no faults)
//   Part 1: four directed tests (x0 pinning, write/read, write-read collision,
//           multi-cycle overwrite), checked on both read ports
//   Part 2: constrained-random test, +NUM_VECTORS=<n> (default 10000), checked
//           every cycle against a golden model with write-first semantics
//   The SVA checker is bound into the DUT and must report zero failures.
// -----------------------------------------------------------------------------
module tb_regfile_cv;

  localparam int WIDTH = 32;
  localparam int DEPTH = 32;
  localparam int ADDRW = $clog2(DEPTH);

  logic             clk = 1'b0;
  logic             we;
  logic [ADDRW-1:0] waddr, raddr1, raddr2;
  logic [WIDTH-1:0] wdata;
  logic [WIDTH-1:0] rdata1, rdata2;
  logic             fault_enable;
  logic [ADDRW-1:0] fault_addr;
  logic [WIDTH-1:0] fault_mask;
  logic [1:0]       fault_type;

  logic [WIDTH-1:0] golden_mem [0:DEPTH-1];
  int unsigned      n_checks = 0;
  int unsigned      n_errors = 0;
  int               num_vectors = 10000;

  regfile #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (.*);
  bind regfile regfile_sva #(.WIDTH(WIDTH), .DEPTH(DEPTH)) u_sva (.*);

  always #5 clk = ~clk;

  // ---- functional coverage for the random phase ----------------------------
  covergroup func_cov @(posedge clk);
    cp_we     : coverpoint we;
    cp_waddr  : coverpoint waddr  iff (we) { bins addr[] = {[0:DEPTH-1]}; }
    cp_raddr1 : coverpoint raddr1 { bins addr[] = {[0:DEPTH-1]}; }
    cp_raddr2 : coverpoint raddr2 { bins addr[] = {[0:DEPTH-1]}; }
    cp_coll   : coverpoint (we && waddr != '0 && (raddr1 == waddr || raddr2 == waddr)) {
                  bins no_collision = {0}; bins collision = {1}; }
    cp_x0w    : coverpoint (we && waddr == '0) { bins write_x0 = {1}; }
  endgroup
  func_cov cov;

  // ---- reference model --------------------------------------------------------
  // Value a read port must show *before* the clock edge (write-first bypass)
  function automatic logic [WIDTH-1:0] model_read(input logic [ADDRW-1:0] a);
    if (a == '0)                return '0;
    else if (we && waddr == a)  return wdata;
    else                        return golden_mem[a];
  endfunction

  task automatic check_ports(input string tag);
    logic [WIDTH-1:0] e1, e2;
    e1 = model_read(raddr1);
    e2 = model_read(raddr2);
    n_checks += 2;
    if (rdata1 !== e1) begin
      n_errors++;
      $error("[%s] port1 x%0d: got %h expected %h", tag, raddr1, rdata1, e1);
    end
    if (rdata2 !== e2) begin
      n_errors++;
      $error("[%s] port2 x%0d: got %h expected %h", tag, raddr2, rdata2, e2);
    end
  endtask

  // Drive one cycle on the negedge, check just after, commit at the posedge
  task automatic cycle(input logic             w_en,
                       input logic [ADDRW-1:0] w_addr,
                       input logic [WIDTH-1:0] w_data,
                       input logic [ADDRW-1:0] r1,
                       input logic [ADDRW-1:0] r2,
                       input string            tag);
    @(negedge clk);
    we = w_en; waddr = w_addr; wdata = w_data; raddr1 = r1; raddr2 = r2;
    #1 check_ports(tag);
    @(posedge clk);
    if (w_en && w_addr != '0) golden_mem[w_addr] = w_data;
  endtask

  initial begin
    we = 1'b0; waddr = '0; wdata = '0; raddr1 = '0; raddr2 = '0;
    fault_enable = 1'b0; fault_addr = '0; fault_mask = '0; fault_type = 2'd0;
    for (int i = 0; i < DEPTH; i++) golden_mem[i] = '0;
    void'($value$plusargs("NUM_VECTORS=%d", num_vectors));

    // ---------------- Part 1: directed tests ----------------
    $display("=== Directed tests ===");
    // 1. x0 pinning
    cycle(1, 5'd0,  32'hDEAD_BEEF, 5'd0,  5'd0,  "T1 write x0");
    cycle(0, 5'd0,  32'h0,         5'd0,  5'd0,  "T1 read x0");
    // 2. basic write / read-back
    cycle(1, 5'd5,  32'h1234_ABCD, 5'd0,  5'd0,  "T2 write x5");
    cycle(0, 5'd0,  32'h0,         5'd5,  5'd5,  "T2 read x5");
    // 3. same-cycle write/read collision (write-first)
    cycle(1, 5'd7,  32'hCAFE_BABE, 5'd7,  5'd7,  "T3 collision x7");
    cycle(0, 5'd0,  32'h0,         5'd7,  5'd0,  "T3 read x7 after");
    // 4. multi-cycle overwrite
    cycle(1, 5'd10, 32'h1111_1111, 5'd0,  5'd0,  "T4 write #1");
    cycle(1, 5'd10, 32'h3333_3333, 5'd0,  5'd0,  "T4 write #2");
    cycle(1, 5'd10, 32'h5555_5555, 5'd0,  5'd0,  "T4 write #3");
    cycle(0, 5'd0,  32'h0,         5'd10, 5'd10, "T4 read x10");
    $display("Directed tests: %0d errors", n_errors);

    // ---------------- Part 2: randomized test ----------------
    $display("=== Randomized test: %0d vectors ===", num_vectors);
    cov = new();
    repeat (num_vectors) begin
      logic [ADDRW-1:0] wa, r1, r2;
      wa = $urandom_range(0, DEPTH-1);
      r1 = $urandom_range(0, DEPTH-1);
      // ~1 in 8 cycles force a collision so write-first is exercised often
      if ($urandom_range(0, 7) == 0) r1 = wa;
      r2 = $urandom_range(0, DEPTH-1);
      cycle($urandom_range(0, 1), wa, $urandom(), r1, r2, "RAND");
    end

    @(negedge clk);
    $display("==================================================================");
    $display(" Checks: %0d   Scoreboard errors: %0d   Assertion failures: %0d",
             n_checks, n_errors, dut.u_sva.total_fails());
    $display(" Functional coverage (random phase): %0.2f%%", cov.get_coverage());
    $display("==================================================================");
    if (n_errors == 0 && dut.u_sva.total_fails() == 0)
      $display("TEST PASSED");
    else
      $display("TEST FAILED");
    $finish;
  end

endmodule
