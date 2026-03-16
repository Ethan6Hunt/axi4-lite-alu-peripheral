# AXI4-Lite ALU Peripheral

A custom AXI4-Lite slave peripheral implementing a 32-bit ALU,
designed in Verilog and verified in Xilinx Vivado 2024.1 on Zynq-7000.

## Architecture
Zynq PS (ARM Cortex-A9) → AXI Interconnect → AXI4-Lite ALU Peripheral (PL)

## Features
- Full AXI4-Lite slave — all 5 channels (AW, W, B, AR, R) with valid/ready handshaking
- 32-bit ALU: ADD, SUB, AND, OR operations
- Overflow detection on ADD/SUB
- 5-register memory-mapped interface
- Self-checking testbench — 5/5 tests passing in XSim
- Integrated with Zynq-7000 PS via IP Integrator (base address 0x4000_0000)

## Register Map
| Offset | Register  | Access | Description             |
|--------|-----------|--------|-------------------------|
| 0x00   | OPERAND_A | R/W    | First operand           |
| 0x04   | OPERAND_B | R/W    | Second operand          |
| 0x08   | OP_SEL    | R/W    | 0=ADD 1=SUB 2=AND 3=OR  |
| 0x0C   | RESULT    | RO     | ALU result (live)       |
| 0x10   | STATUS    | RO     | Bit[0] = overflow flag  |

## Simulation Results
```
[TEST 1] ADD:  25 + 17 = 42          → PASS
[TEST 2] SUB:  100 - 44 = 56         → PASS
[TEST 3] AND:  0xF0F0F0F0 & 0x0F0F0F0F = 0x00000000  → PASS
[TEST 4] OR:   0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF  → PASS
[TEST 5] ADD overflow: 0xFFFFFFFF + 1 → PASS
```

## Resource Utilization (xc7z020clg400-1)
| Resource | Used |
|----------|------|
| LUTs     | 216  |
| FFs      | 107  |
| CARRY4   | 33   |
| DSP48    | 0    |
| BRAM     | 0    |

## File Structure
| File | Description |
|------|-------------|
| `alu_core.v` | Pure combinational 32-bit ALU |
| `axi4_lite_slave.v` | AXI4-Lite slave wrapper with register map |
| `axi_alu_top.v` | Top-level module |
| `tb_axi_alu.v` | Self-checking testbench |

## Tools
- Xilinx Vivado 2024.1
- Target: xc7z020clg400-1 (Zynq-7000)
- Simulator: XSim (behavioral simulation)
- Language: Verilog
