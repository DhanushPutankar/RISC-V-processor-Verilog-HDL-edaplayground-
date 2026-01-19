# Custom RISC-V Pipelined Processor (RV32I Subset)

## Overview
This project implements a **custom 32-bit RISC-V–inspired pipelined processor** using **SystemVerilog**.  
The design follows a **5-stage pipeline architecture (IF, ID, EX, MEM, WB)** with explicit pipeline registers and a simplified control strategy.

The processor supports a **subset of the RV32I instruction set**, focusing on arithmetic, logical, load, and store operations.  
Simulation and verification are performed using **Cadence Xcelium (xrun)** and EDA Playground.

---

## Architecture
The processor is organized as a classic 5-stage pipelined datapath with dedicated pipeline registers between stages.

![Custom RISC-V Pipeline Architecture](docs/architecture_diagram.png)

### Pipeline Stages
- **Instruction Fetch (IF)**  
  Fetches instructions from instruction memory using a program counter that increments by 4.

- **Instruction Decode (ID)**  
  Decodes the instruction, reads source registers, generates control signals, and computes immediate values.

- **Execute (EX)**  
  Performs ALU operations and address calculations using a dedicated ALU control unit.

- **Memory Access (MEM)**  
  Handles data memory read and write operations for load and store instructions.

- **Write Back (WB)**  
  Writes ALU results or memory data back to the register file.

### Pipeline Registers
- IF/ID  
- ID/EX  
- EX/MEM  
- MEM/WB  

The pipeline is intentionally kept simple and does not include hazard detection or branch handling logic.

---

## Supported Instruction Subset

### R-Type Instructions
- ADD, SUB  
- AND, OR, XOR  
- SLL, SRL, SRA  
- SLT, SLTU  

### I-Type Instructions
- ADDI and ALU immediate operations

### Memory Instructions
- LW (Load Word)  
- SW (Store Word)

---

## Not Implemented
The following features are **not included** in this version of the processor:

- Branch instructions (BEQ, BNE, etc.)
- Jump instructions (JAL, JALR)
- Hazard detection and forwarding
- Pipeline stalling or flushing
- Cache or MMU
- Interrupts and exceptions

These omissions are intentional to keep the design **educational, modular, and easy to analyze**.

---

## Design Characteristics
- 32-bit datapath
- Explicit 5-stage pipeline implementation
- Asynchronous instruction and data memory reads
- Synchronous register file and data memory writes
- Register x0 is hardwired to zero
- Simplified PC logic (PC + 4 only)

---

## File Structure
