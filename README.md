# 💊 Smart Pill Dispenser — FPGA Servo Control System

A fully synthesizable Verilog-based servo motor control system designed for the **Digilent Nexys 4 DDR** (Xilinx Artix-7 XC7A100T) FPGA. The system drives a standard hobby servo through a timed sequence of angular positions, simulating an automated pill dispensing mechanism.

![Language](https://img.shields.io/badge/Language-Verilog-blue)
![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7-green)
![Board](https://img.shields.io/badge/Board-Nexys%204%20DDR-orange)
![License](https://img.shields.io/badge/License-MIT-brightgreen)

---

## 📖 Overview

This project implements a **50 Hz PWM servo controller** that rotates a servo motor through a predefined sequence of angles (0° → 45° → 90° → 135° → 0°), each held for a configurable duration. It is designed as a building block for automated pill dispensing, where each angle corresponds to a compartment position.

### Key Features

- ✅ **Fully synthesizable** — No behavioral-only constructs; ready for hardware
- ✅ **Modular design** — Clean separation into Clock Divider, PWM Generator, Servo Controller, and Top-level wrapper
- ✅ **Parameterized** — All timing and PWM constants are configurable via parameters
- ✅ **FPGA best practices** — Synchronous reset, one-hot FSM encoding, pipelined arithmetic, no latches
- ✅ **Comprehensive testbench** — Automated self-checking simulation with reduced parameters for fast verification
- ✅ **Ready-to-use constraints** — XDC file included for the Nexys 4 DDR board

```

## 📂 Project Structure

```
servo_control/
├── rtl/                            # Synthesizable RTL source files
│   ├── smart_pill_dispenser.v      # Top-level module
│   ├── clock_divider.v             # PWM period counter (20 ms / 50 Hz)
│   ├── pwm_generator.v             # 8-bit position → PWM pulse width
│   └── servo_controller.v          # FSM with timed angle transitions
├── sim/                            # Simulation
│   └── tb_smart_pill_dispenser.v   # Self-checking testbench
└── constraints/                    # FPGA constraints
    └── nexys4.xdc                  # Pin assignments for Nexys 4 DDR
```

---

## ⚙️ Module Descriptions

### `smart_pill_dispenser` (Top Module)
The top-level wrapper that instantiates and interconnects all sub-modules. Exposes only three ports: `clk`, `rst`, and `servo_pwm`.

### `clock_divider`
A free-running 21-bit counter that wraps every **2,000,000 cycles** (20 ms at 100 MHz), producing a 50 Hz period reference for PWM generation. Also outputs a single-cycle `period_tick` pulse at each period boundary.

> **Note:** This is *not* a traditional clock divider — it generates a counter and synchronous enable, avoiding clock domain crossing issues.

### `pwm_generator`
Maps an 8-bit position input (0–255) to a servo pulse width (1.0 ms – 2.0 ms) using FPGA-friendly bit-shift arithmetic:

| Position | Angle  | Pulse Width |
|----------|--------|-------------|
| 0        | 0°     | 1.00 ms     |
| 64       | ~45°   | 1.25 ms     |
| 128      | ~90°   | 1.50 ms     |
| 192      | ~135°  | 1.75 ms     |
| 255      | ~180°  | ~2.00 ms    |

**Formula:** `pulse_width = MIN_PULSE + (position × PULSE_RANGE) >> 8`

Uses a **2-stage pipeline** for timing closure on the multiply-and-add path.

### `servo_controller`
A **one-hot encoded FSM** that cycles through four servo positions with configurable hold durations:

| State   | Position | Angle | Hold Duration |
|---------|----------|-------|---------------|
| ST_0DEG | 0        | 0°    | 5 seconds     |
| ST_45DEG| 64       | 45°   | 10 seconds    |
| ST_90DEG| 128      | 90°   | 15 seconds    |
| ST_135DEG| 192     | 135°  | 5 seconds     |

**Total cycle time:** 35 seconds (then repeats)

On **reset**, the servo immediately returns to 0° and the timer restarts.

---

## 🔌 Hardware Setup

### Target Board
**Digilent Nexys 4 DDR** (Artix-7 XC7A100T-1CSG324C)

### Pin Assignments

| Signal      | FPGA Pin | Board Location          |
|-------------|----------|--------------------------|
| `clk`       | E3       | 100 MHz on-board oscillator |
| `rst`       | N17      | BTNC (Center push button)  |
| `servo_pwm` | C17      | Pmod JA Pin 1 (top-left)   |

### Servo Wiring

| Connection         | Wire Color (typical) | Source               |
|--------------------|-----------------------|----------------------|
| Signal (JA Pin 1)  | Orange / White        | FPGA Pmod JA         |
| Ground (JA Pin 5)  | Brown / Black         | FPGA Pmod JA GND     |
| Power (5V)         | Red                   | **External 5V supply** |

> ⚠️ **WARNING:** Do **NOT** power the servo from the FPGA's 3.3V Pmod supply.  
> Servos draw >500 mA and require 5V. Use an external power supply with a **common ground** connection to the FPGA.

---

## 🚀 Getting Started

### Prerequisites
- **Xilinx Vivado** (2020.2 or later recommended)
- Digilent Nexys 4 DDR board
- Standard hobby servo motor (e.g., SG90, MG996R)
- External 5V power supply for the servo

### Synthesis & Implementation (Vivado)

1. Create a new Vivado project targeting **xc7a100tcsg324-1**
2. Add all RTL files from `rtl/` as design sources
3. Add `constraints/nexys4.xdc` as a constraints file
4. Set `smart_pill_dispenser` as the top module
5. Run **Synthesis → Implementation → Generate Bitstream**
6. Program the FPGA via Hardware Manager

### Simulation

#### Vivado Simulator
1. Add all RTL files and `sim/tb_smart_pill_dispenser.v` as simulation sources
2. Set `tb_smart_pill_dispenser` as the top simulation module
3. Run Behavioral Simulation

#### Icarus Verilog (Open Source)
```bash
cd sim
iverilog -o tb.vvp tb_smart_pill_dispenser.v \
    ../rtl/smart_pill_dispenser.v \
    ../rtl/clock_divider.v \
    ../rtl/pwm_generator.v \
    ../rtl/servo_controller.v
vvp tb.vvp
gtkwave tb_dump.vcd   # View waveforms
```

---

## 🧪 Testbench

The testbench (`tb_smart_pill_dispenser.v`) uses **scaled-down parameters** (CLK_FREQ = 1,000 instead of 100,000,000) to reduce simulation time by ~100,000×, while preserving all logic behavior.

### Tests Performed

| # | Test                          | Description                                  |
|---|-------------------------------|----------------------------------------------|
| 1 | Reset Behavior                | PWM = LOW and position = 0 during reset      |
| 2 | PWM Activity                  | PWM toggles (not stuck HIGH or LOW)          |
| 3 | 0° → 45° Transition           | Position = 64 after 5s equivalent            |
| 4 | 45° → 90° Transition          | Position = 128 after 10s equivalent          |
| 5 | 90° → 135° Transition         | Position = 192 after 15s equivalent          |
| 6 | 135° → 0° Transition (Cycle)  | Position returns to 0 after 5s equivalent    |
| 7 | Mid-Operation Reset           | Reset during operation returns to 0° safely  |

---

## 📐 Design Decisions

| Decision | Rationale |
|----------|-----------|
| **One-hot FSM encoding** | Better timing performance on Xilinx FPGAs; uses more flip-flops but fewer LUTs |
| **Bit-shift division (>>8)** | Avoids hardware divider; maps position 0–255 to pulse range efficiently |
| **2-stage pipeline in PWM** | Breaks multiply-add critical path for timing closure at 100 MHz |
| **Synchronous reset** | Xilinx-recommended practice; avoids issues with asynchronous reset trees |
| **Non-blocking assignments** | Sequential logic uses `<=`; combinational logic uses `=` — prevents simulation mismatches |
| **Counter-based "clock divider"** | Avoids clock domain crossing issues endemic to gated-clock designs |

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🤝 Acknowledgments

- [Digilent Nexys 4 DDR Reference Manual](https://digilent.com/reference/programmable-logic/nexys-4-ddr/start)
- Xilinx Artix-7 FPGA family documentation
- Standard servo PWM timing specifications (50 Hz, 1–2 ms pulse width)

