//=============================================================================
// Module:      clock_divider
// Description: PWM period counter for servo motor control.
//              Generates a free-running counter (0 to PERIOD_CYCLES-1) that
//              wraps every 20 ms (50 Hz) at 100 MHz input clock.
//              Also outputs a single-cycle tick at the start of each period.
//
// Note:        This is NOT a clock divider in the traditional sense.
//              It does NOT generate a divided clock signal (which would cause
//              clock domain crossing issues on FPGAs). Instead, it produces
//              a counter and a synchronous enable pulse - proper FPGA practice.
//
// Parameters:
//   PERIOD_CYCLES - Number of clock cycles per PWM period.
//                   Default: 2,000,000 (20 ms at 100 MHz / 10 ns per cycle)
//
// Clock:   100 MHz (10 ns period)
// Period:  20 ms = 20,000,000 ns / 10 ns = 2,000,000 cycles
//=============================================================================

module clock_divider #(
    parameter PERIOD_CYCLES = 2_000_000  // 20 ms at 100 MHz
)(
    input  wire        clk,         // 100 MHz system clock
    input  wire        rst,         // Active-high synchronous reset
    output reg  [20:0] counter,     // Free-running period counter [0, PERIOD_CYCLES-1]
    output reg         period_tick  // Single-cycle pulse at period boundary
);

    // Counter width: ceil(log2(2,000,000)) = 21 bits (2^21 = 2,097,152)

    always @(posedge clk) begin
        if (rst) begin
            counter     <= 21'd0;
            period_tick <= 1'b0;
        end else begin
            if (counter == PERIOD_CYCLES - 1) begin
                counter     <= 21'd0;
                period_tick <= 1'b1;
            end else begin
                counter     <= counter + 21'd1;
                period_tick <= 1'b0;
            end
        end
    end

endmodule
