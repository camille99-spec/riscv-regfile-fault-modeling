`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// SystemVerilog Assertion (SVA) checker for regfile
//
// Bound into the regfile instance from each testbench (see note at the bottom),
// so the RTL is unchanged and the same checker runs in every testbench.
//
// Assertion groups
//   A1  x0 reads zero on both ports                     (architectural rule)
//   A2  x0 storage is never written                     (architectural rule)
//   A3  a write updates the target register next cycle  (storage)
//   A4  unwritten registers hold their value            (storage)
//   A5  read port returns storage / bypass data         (read path)
//   A6  write-first on same-cycle read/write collision  (read path)
//   A7  a fault on register k never disturbs reads of other registers
//                                                       (fault-injector isolation)
//   A8  read data is never X/Z when the address is known
//
// Every assertion has a failure counter. Fault-injection testbenches read the
// counters to see which assertions caught each fault, and set report_en = 0 to
// silence the per-cycle $error messages during a campaign.
// -----------------------------------------------------------------------------
module regfile_sva #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 32,
  parameter int ADDRW = $clog2(DEPTH)
)(
  input logic             clk,
  input logic             we,
  input logic [ADDRW-1:0] waddr,
  input logic [WIDTH-1:0] wdata,
  input logic [ADDRW-1:0] raddr1,
  input logic [ADDRW-1:0] raddr2,
  input logic [WIDTH-1:0] rdata1,
  input logic [WIDTH-1:0] rdata2,
  input logic             fault_enable,
  input logic [ADDRW-1:0] fault_addr,
  input logic [WIDTH-1:0] fault_mask,
  input logic [1:0]       fault_type,
  input logic [WIDTH-1:0] mem [0:DEPTH-1]
);

  // ---- control / statistics -------------------------------------------------
  bit report_en = 1'b1;          // testbench may clear this during campaigns

  int unsigned n_a1_x0_read   = 0;
  int unsigned n_a2_x0_store  = 0;
  int unsigned n_a3_write     = 0;
  int unsigned n_a4_hold      = 0;
  int unsigned n_a5_read      = 0;
  int unsigned n_a6_wfirst    = 0;
  int unsigned n_a7_isolation = 0;
  int unsigned n_a8_no_x      = 0;

  // Fault-free value a read port should return (storage + write-first bypass).
  // Everything is passed as an argument so that, inside a concurrent
  // assertion, all values are the sampled (pre-clock-edge) values.
  function automatic logic [WIDTH-1:0] exp_read(input logic [ADDRW-1:0] a,
                                                input logic             w_en,
                                                input logic [ADDRW-1:0] w_addr,
                                                input logic [WIDTH-1:0] w_data,
                                                input logic [WIDTH-1:0] stored);
    if (a == '0)                   return '0;
    else if (w_en && w_addr == a)  return w_data;
    else                           return stored;
  endfunction
  `define EXP1 exp_read(raddr1, we, waddr, wdata, mem[raddr1])
  `define EXP2 exp_read(raddr2, we, waddr, wdata, mem[raddr2])

  // ---- A1: x0 reads as zero ------------------------------------------------
  a1_x0_read_p1: assert property (@(posedge clk) (raddr1 == '0) |-> (rdata1 == '0))
    else begin n_a1_x0_read++; if (report_en) $error("A1: x0 read on port 1 returned %h", rdata1); end
  a1_x0_read_p2: assert property (@(posedge clk) (raddr2 == '0) |-> (rdata2 == '0))
    else begin n_a1_x0_read++; if (report_en) $error("A1: x0 read on port 2 returned %h", rdata2); end

  // ---- A2: x0 storage never changes ----------------------------------------
  a2_x0_storage: assert property (@(posedge clk) mem[0] == '0)
    else begin n_a2_x0_store++; if (report_en) $error("A2: mem[0] = %h", mem[0]); end

  // ---- A3: write lands in the target register ------------------------------
  a3_write_update: assert property (@(posedge clk)
      (we && waddr != '0) |=> (mem[$past(waddr)] == $past(wdata)))
    else begin n_a3_write++; if (report_en) $error("A3: write to x%0d not stored", $past(waddr)); end

  // ---- A4: registers that are not written hold their value -----------------
  for (genvar k = 1; k < DEPTH; k++) begin : g_hold
    a4_hold: assert property (@(posedge clk)
        !(we && waddr == k) |=> (mem[k] == $past(mem[k])))
      else begin n_a4_hold++; if (report_en) $error("A4: x%0d changed without a write", k); end
  end

  // ---- A5: read ports return the stored (or bypassed) value ----------------
  a5_read_p1: assert property (@(posedge clk) (raddr1 != '0) |-> (rdata1 == `EXP1))
    else begin n_a5_read++; if (report_en) $error("A5: port1 read of x%0d returned wrong data", $sampled(raddr1)); end
  a5_read_p2: assert property (@(posedge clk) (raddr2 != '0) |-> (rdata2 == `EXP2))
    else begin n_a5_read++; if (report_en) $error("A5: port2 read of x%0d returned wrong data", $sampled(raddr2)); end

  // ---- A6: write-first on a same-cycle collision ---------------------------
  a6_wfirst_p1: assert property (@(posedge clk)
      (we && waddr != '0 && raddr1 == waddr) |-> (rdata1 == wdata))
    else begin n_a6_wfirst++; if (report_en) $error("A6: port1 collision on x%0d got %h exp %h", raddr1, rdata1, wdata); end
  a6_wfirst_p2: assert property (@(posedge clk)
      (we && waddr != '0 && raddr2 == waddr) |-> (rdata2 == wdata))
    else begin n_a6_wfirst++; if (report_en) $error("A6: port2 collision on x%0d got %h exp %h", raddr2, rdata2, wdata); end

  // ---- A7: fault isolation - other registers are unaffected ----------------
  a7_isolation_p1: assert property (@(posedge clk)
      (fault_enable && raddr1 != fault_addr) |-> (rdata1 == `EXP1))
    else begin n_a7_isolation++; if (report_en) $error("A7: fault on x%0d disturbed x%0d", fault_addr, raddr1); end
  a7_isolation_p2: assert property (@(posedge clk)
      (fault_enable && raddr2 != fault_addr) |-> (rdata2 == `EXP2))
    else begin n_a7_isolation++; if (report_en) $error("A7: fault on x%0d disturbed x%0d", fault_addr, raddr2); end

  // ---- A8: no X/Z on read data ---------------------------------------------
  a8_no_x_p1: assert property (@(posedge clk) !$isunknown(raddr1) |-> !$isunknown(rdata1))
    else begin n_a8_no_x++; if (report_en) $error("A8: X on rdata1"); end
  a8_no_x_p2: assert property (@(posedge clk) !$isunknown(raddr2) |-> !$isunknown(rdata2))
    else begin n_a8_no_x++; if (report_en) $error("A8: X on rdata2"); end

  // ---- Cover properties: did the stimulus reach the interesting cases? ------
  c1_collision:      cover property (@(posedge clk) we && waddr != '0 && (raddr1 == waddr || raddr2 == waddr));
  c2_same_addr:      cover property (@(posedge clk) raddr1 == raddr2 && raddr1 != '0);
  c3_back_to_back:   cover property (@(posedge clk) (we && waddr != '0) ##1 (we && waddr == $past(waddr)));
  c4_write_x0:       cover property (@(posedge clk) we && waddr == '0 && wdata != '0);
  c5_fault_read:     cover property (@(posedge clk) fault_enable && fault_type != 2'd0 && raddr1 == fault_addr && raddr1 != '0);
  c6_fault_x0_mask:  cover property (@(posedge clk) fault_enable && fault_type != 2'd0 && fault_addr == '0 && raddr1 == '0);

  // Total of all assertion failures (handy for testbench snapshots)
  function automatic int unsigned total_fails();
    return n_a1_x0_read + n_a2_x0_store + n_a3_write + n_a4_hold +
           n_a5_read + n_a6_wfirst + n_a7_isolation + n_a8_no_x;
  endfunction

  `undef EXP1
  `undef EXP2

  final begin
    $display("---- regfile_sva summary (%m) ----");
    $display("A1 x0 read zero      : %0d failures", n_a1_x0_read);
    $display("A2 x0 storage zero   : %0d failures", n_a2_x0_store);
    $display("A3 write update      : %0d failures", n_a3_write);
    $display("A4 register hold     : %0d failures", n_a4_hold);
    $display("A5 read data         : %0d failures", n_a5_read);
    $display("A6 write-first       : %0d failures", n_a6_wfirst);
    $display("A7 fault isolation   : %0d failures", n_a7_isolation);
    $display("A8 no X on read data : %0d failures", n_a8_no_x);
  end

endmodule

// The checker is attached from inside each testbench with:
//   bind regfile regfile_sva #(.WIDTH(WIDTH), .DEPTH(DEPTH)) u_sva (.*);
// (a bind inside a module is picked up reliably by Questa and EDA Playground;
//  a file-scope bind can be dropped when files compile as separate units)
