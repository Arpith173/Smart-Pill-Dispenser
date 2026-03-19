 //=============================================================================
// Module:      pwm_generator
// Description: Generates a PWM signal for servo motor control.
//              Maps an 8-bit position input (0-255) to a pulse width
//              corresponding to servo angles 0° to 180°.
//
// Servo Timing (at 100 MHz / 10 ns per clock cycle):
//   0°   -> 1.00 ms pulse -> 100,000 cycles
//   90°  -> 1.50 ms pulse -> 150,000 cycles
//   180° -> 2.00 ms pulse -> 200,000 cycles
//
// Mapping Formula:
//   pulse_width = MIN_PULSE + (position * PULSE_RANGE) >> 8
//
//   Using bit-shift division by 256 (FPGA-friendly, no hardware divider):
//     position=0:   100,000 + 0       = 100,000  (1.00 ms)
//     position=64:  100,000 + 25,000  = 125,000  (1.25 ms = 45°)
//     position=128: 100,000 + 50,000  = 150,000  (1.50 ms = 90°)
//     position=192: 100,000 + 75,000  = 175,000  (1.75 ms = 135°)
//     position=255: 100,000 + 99,609  = 199,609  (≈2.00 ms ≈ 180°)
//
// Parameters:
//   MIN_PULSE   - Minimum pulse width in clock cycles (1 ms default)
//   PULSE_RANGE - Range of pulse width in clock cycles (1 ms default)
//=============================================================================

module pwm_generator #(
    parameter MIN_PULSE   = 100_000,  // 1.0 ms at 100 MHz
    parameter PULSE_RANGE = 100_000   // 1.0 ms range (1 ms to 2 ms)
)(
    input  wire        clk,       // 100 MHz system clock
    input  wire        rst,       // Active-high synchronous reset
    input  wire [7:0]  position,  // Servo position input (0 = 0°, 255 = 180°)
    input  wire [20:0] counter,   // Period counter from clock_divider
    output reg         pwm_out    // PWM output to servo
);

    //=========================================================================
    // Pulse Width Calculation (Pipelined for timing closure)
    //=========================================================================
    // Stage 1: Multiply position by PULSE_RANGE
    //   Max product: 255 * 100,000 = 25,500,000 (needs 25 bits)
    // Stage 2: Bit-shift right by 8 (divide by 256) and add MIN_PULSE
    //   Max result: 100,000 + 99,609 = 199,609 (fits in 18 bits / 21-bit reg)
    //
    // Two-stage pipeline adds 20 ns latency - negligible since position
    // changes on the order of seconds.
    //=========================================================================

    reg  [24:0] product_stage1;  // Pipeline stage 1: raw product
    reg  [20:0] pulse_width;     // Pipeline stage 2: final pulse width

    always @(posedge clk) begin
        if (rst) begin
            product_stage1 <= 25'd0;
            pulse_width    <= MIN_PULSE[20:0];
        end else begin
            // Stage 1: Multiply (synthesizer infers DSP48 or LUT-based multiplier)
            product_stage1 <= position * PULSE_RANGE[16:0];
            // Stage 2: Shift and add
            pulse_width    <= MIN_PULSE[20:0] + {4'd0, product_stage1[24:8]};
        end
    end

    //=========================================================================
    // PWM Output Generation
    //=========================================================================
    // Compare period counter against calculated pulse width:
    //   counter < pulse_width  ->  PWM = HIGH (servo pulse active)
    //   counter >= pulse_width ->  PWM = LOW  (remainder of 20 ms period)
    //
    // This guarantees:
    //   - PWM is HIGH only during the pulse width portion
    //   - PWM is LOW for the rest of the 20 ms period
    //   - No constant HIGH or constant LOW conditions (pulse_width > 0 always)
    //   - Correct 50 Hz frequency (driven by clock_divider's counter)
    //=========================================================================

    always @(posedge clk) begin
        if (rst)
            pwm_out <= 1'b0;
        else
            pwm_out <= (counter < pulse_width) ? 1'b1 : 1'b0;
    end

endmodule
 
