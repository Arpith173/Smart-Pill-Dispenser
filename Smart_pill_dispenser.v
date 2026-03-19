module smart_pill_dispenser (
    input  wire clk,        // 100 MHz system clock
    input  wire rst,        // Active-high reset
    output wire servo_pwm   // PWM output to servo motor
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    wire [20:0] pwm_counter;   // Period counter (0 to 1,999,999)
    wire        period_tick;   // Pulse at each 20 ms boundary (unused but available)
    wire [7:0]  position;      // Servo position from controller FSM

    //=========================================================================
    // Module Instantiations
    //=========================================================================

    // --- Clock Divider (PWM Period Counter) ---
    // Generates a free-running 21-bit counter that wraps every 20 ms.
    // This counter drives the PWM comparison in the PWM generator.
    clock_divider #(
        .PERIOD_CYCLES (2_000_000)  // 20 ms at 100 MHz
    ) u_clock_divider (
        .clk         (clk),
        .rst         (rst),
        .counter     (pwm_counter),
        .period_tick (period_tick)
    );

    // --- Servo Controller (FSM + Timing) ---
    // Generates timed position transitions:
    //   0° (5s) -> 45° (10s) -> 90° (15s) -> 135° (5s) -> repeat
    servo_controller #(
        .CLK_FREQ (100_000_000)  // 100 MHz
    ) u_servo_controller (
        .clk      (clk),
        .rst      (rst),
        .position (position)
    );

    // --- PWM Generator ---
    // Maps 8-bit position to pulse width and generates PWM signal.
    //   position=0   -> 1.00 ms pulse (0°)
    //   position=128 -> 1.50 ms pulse (90°)
    //   position=255 -> 1.99 ms pulse (≈180°)
    pwm_generator #(
        .MIN_PULSE   (100_000),  // 1.0 ms at 100 MHz
        .PULSE_RANGE (100_000)   // 1.0 ms range
    ) u_pwm_generator (
        .clk      (clk),
        .rst      (rst),
        .position (position),
        .counter  (pwm_counter),
        .pwm_out  (servo_pwm)
    );

endmodule
