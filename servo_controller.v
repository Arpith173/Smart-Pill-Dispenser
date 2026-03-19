//=============================================================================
// Module:      servo_controller
// Description: Finite State Machine (FSM) that generates timed servo position
//              transitions for the smart pill dispenser.
//
// Sequence (cumulative time from start):
//   t = 0s   : 0°   (position = 0)     - Home / dispenser closed
//   t = 5s   : 45°  (position = 64)    - Quarter open
//   t = 15s  : 90°  (position = 128)   - Half open
//   t = 30s  : 135° (position = 192)   - Three-quarter open
//   t = 35s  : Return to 0° and repeat
//
// Position-to-Angle Mapping (verified):
//   position = N  ->  angle = N/255 * 180°
//   position = 0   ->  0°       (pulse = 1.00 ms)
//   position = 64  ->  45.2°  ≈ 45°   (pulse = 1.25 ms)
//   position = 128 ->  90.4°  ≈ 90°   (pulse = 1.50 ms)
//   position = 192 -> 135.5° ≈ 135°  (pulse = 1.75 ms)
//
// Timing Calculation (100 MHz clock):
//   1 second = 100,000,000 clock cycles
//   State durations:
//     STATE_0DEG:   5s  = 500,000,000 cycles  (29 bits)
//     STATE_45DEG:  10s = 1,000,000,000 cycles (30 bits)
//     STATE_90DEG:  15s = 1,500,000,000 cycles (31 bits)
//     STATE_135DEG: 5s  = 500,000,000 cycles  (29 bits)
//   Total cycle:   35s = 3,500,000,000 cycles (32 bits)
//
// Reset Behavior:
//   On reset assertion, servo immediately returns to 0° (position = 0).
//   Timer and state machine are reset to initial state.
//
// Parameters:
//   CLK_FREQ - Clock frequency in Hz (default: 100,000,000)
//=============================================================================

module servo_controller #(
    parameter CLK_FREQ = 100_000_000  // 100 MHz
)(
    input  wire       clk,       // 100 MHz system clock
    input  wire       rst,       // Active-high synchronous reset
    output reg  [7:0] position   // Servo position output (0-255)
);

    //=========================================================================
    // State Encoding (one-hot for better FPGA performance)
    //=========================================================================
    localparam [3:0] ST_0DEG   = 4'b0001;  // 0°   - Home position
    localparam [3:0] ST_45DEG  = 4'b0010;  // 45°  - Quarter open
    localparam [3:0] ST_90DEG  = 4'b0100;  // 90°  - Half open
    localparam [3:0] ST_135DEG = 4'b1000;  // 135° - Three-quarter open

    //=========================================================================
    // Timing Duration Constants
    //=========================================================================
    // Duration each state is held before transitioning to the next.
    // Using individual durations (not cumulative) for cleaner FSM design.
    //
    // Note: Subtract 1 because counter starts at 0.
    //   e.g., 5s = 500,000,000 cycles, counter goes 0 to 499,999,999
    //=========================================================================
    localparam [31:0] DUR_0DEG   = CLK_FREQ * 5  - 1;  //  5s at 0°
    localparam [31:0] DUR_45DEG  = CLK_FREQ * 10 - 1;  // 10s at 45°  (5s to 15s)
    localparam [31:0] DUR_90DEG  = CLK_FREQ * 15 - 1;  // 15s at 90°  (15s to 30s)
    localparam [31:0] DUR_135DEG = CLK_FREQ * 5  - 1;  //  5s at 135° (30s to 35s)

    //=========================================================================
    // Position Constants
    //=========================================================================
    localparam [7:0] POS_0DEG   = 8'd0;    // 0°
    localparam [7:0] POS_45DEG  = 8'd64;   // 45°
    localparam [7:0] POS_90DEG  = 8'd128;  // 90°
    localparam [7:0] POS_135DEG = 8'd192;  // 135°

    //=========================================================================
    // FSM Registers
    //=========================================================================
    reg [3:0]  state;
    reg [31:0] timer;

    // Duration mux - selected based on current state (combinational)
    reg [31:0] current_duration;
    always @(*) begin
        case (state)
            ST_0DEG:   current_duration = DUR_0DEG;
            ST_45DEG:  current_duration = DUR_45DEG;
            ST_90DEG:  current_duration = DUR_90DEG;
            ST_135DEG: current_duration = DUR_135DEG;
            default:   current_duration = DUR_0DEG;
        endcase
    end

    //=========================================================================
    // FSM Sequential Logic
    //=========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state    <= ST_0DEG;
            timer    <= 32'd0;
            position <= POS_0DEG;
        end else begin
            case (state)
                ST_0DEG: begin
                    position <= POS_0DEG;
                    if (timer == current_duration) begin
                        state <= ST_45DEG;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                ST_45DEG: begin
                    position <= POS_45DEG;
                    if (timer == current_duration) begin
                        state <= ST_90DEG;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                ST_90DEG: begin
                    position <= POS_90DEG;
                    if (timer == current_duration) begin
                        state <= ST_135DEG;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                ST_135DEG: begin
                    position <= POS_135DEG;
                    if (timer == current_duration) begin
                        state <= ST_0DEG;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                default: begin
                    // Safe recovery from invalid state
                    state    <= ST_0DEG;
                    timer    <= 32'd0;
                    position <= POS_0DEG;
                end
            endcase
        end
    end

endmodule
