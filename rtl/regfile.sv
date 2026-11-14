`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// RISC-V integer register file (x0..x31)
//   - 2 asynchronous read ports, 1 synchronous write port
//   - x0 hardwired to zero (writes ignored, reads return 0)
//   - write-first: a read of the register being written in the same cycle
//     returns the new write data (internal bypass)
//   - fault injection on the read path (transient / observation-point faults);
//     storage contents are never modified by the fault logic
//       fault_type: 0 = none, 1 = bit-flip, 2 = stuck-at-0, 3 = stuck-at-1
// -----------------------------------------------------------------------------
module regfile #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 32,
  parameter int ADDRW = $clog2(DEPTH)
)(
  input  logic             clk,
  input  logic             we,
  input  logic [ADDRW-1:0] waddr,
  input  logic [WIDTH-1:0] wdata,
  input  logic [ADDRW-1:0] raddr1,
  input  logic [ADDRW-1:0] raddr2,
  output logic [WIDTH-1:0] rdata1,
  output logic [WIDTH-1:0] rdata2,
  input  logic             fault_enable,
  input  logic [ADDRW-1:0] fault_addr,
  input  logic [WIDTH-1:0] fault_mask,
  input  logic [1:0]       fault_type
);

  logic [WIDTH-1:0] mem [0:DEPTH-1];

  initial begin
    for (int i = 0; i < DEPTH; i++)
      mem[i] = '0;
  end

  // plain always (not always_ff): mem is also initialised by the initial block
  always @(posedge clk) begin
    if (we && waddr != '0)
      mem[waddr] <= wdata;
  end

  // Write-first bypass: same-cycle read of the register being written
  function automatic logic [WIDTH-1:0] read_raw(input logic [ADDRW-1:0] addr);
    if (we && waddr == addr)
      return wdata;
    else
      return mem[addr];
  endfunction

  function automatic logic [WIDTH-1:0] inject_fault(input logic [WIDTH-1:0] val,
                                                    input logic [ADDRW-1:0] addr);
    if (fault_enable && addr == fault_addr) begin
      case (fault_type)
        2'd1:    return val ^  fault_mask;   // bit-flip
        2'd2:    return val & ~fault_mask;   // stuck-at-0
        2'd3:    return val |  fault_mask;   // stuck-at-1
        default: return val;
      endcase
    end
    return val;
  endfunction

  // x0 is checked first, so faults targeted at x0 are architecturally masked.
  // always_comb (not assign) so the outputs also update when signals read
  // inside the functions change (mem, we, waddr, wdata, fault_*).
  always_comb begin
    rdata1 = (raddr1 == '0) ? '0 : inject_fault(read_raw(raddr1), raddr1);
    rdata2 = (raddr2 == '0) ? '0 : inject_fault(read_raw(raddr2), raddr2);
  end

endmodule

