# ThinPad RV32I Pipelined Processor

A five-stage RISC-V processor implemented in SystemVerilog and deployed on
ThinPad FPGA hardware. The design runs an interactive supervisor monitor over
UART, accesses external memory through a Wishbone bus, and adds an instruction
cache and a next-PC prediction table to reduce fetch and control-flow stalls.

This README explains what the project does, how an instruction moves through
the hardware, how the optional performance features work, how to open and run
the design, and which limitations remain.

## Project at a glance

| Item | Details |
| --- | --- |
| Target platform | ThinPad FPGA board |
| HDL | SystemVerilog and Verilog |
| Processor | RV32I subset used by the course monitor |
| Pipeline | IF, ID, EX, MEM, WB |
| Main optimizations | 8-set/8-way instruction cache and 8 x 4 next-PC predictor |
| Bus | Two-master Wishbone arbiter and three-slave address router |
| I/O | UART console, base SRAM, extension SRAM, Flash interface |
| Build tool | Vivado 2019.2 project |
| FPGA part in project | `xc7a100tfgg676-2L` |

## What the design does

After reset, the program counter starts at `0x8000_0000`, where the monitor
program is loaded into base SRAM. The processor fetches and executes the
monitor while exposing registers, memory, assembly loading, and program
execution commands through a UART console.

Every instruction passes through five pipeline stages:

1. **IF** predicts the next program counter and fetches an instruction, either
   from the instruction cache or from Wishbone memory.
2. **ID** decodes the instruction, reads the register file, and selects forwarded
   operands when a younger result is still moving through the pipeline.
3. **EX** performs arithmetic, compares branch operands, and produces branch or
   jump targets.
4. **MEM** performs load/store transactions through the Wishbone bus.
5. **WB** writes ALU or load results back to the register file.

Memory accesses are split between two SRAM banks, while UART is mapped as a
memory-mapped peripheral. This allows software running on the core to interact
with the board without a separate soft-core or host CPU.

## System architecture

![System architecture](docs/assets/system-architecture.png)

The processor is the Wishbone master. Its instruction and data requests are
arbitrated with a second master, then routed to one of three slaves:

- base SRAM;
- extension SRAM;
- UART controller.

The board-level wrapper connects these buses to the physical SRAM, Flash, UART,
switches, LEDs, and display pins. A PLL generates the supporting clocks and
holds each clock domain in reset until it locks.

## Pipeline implementation

### Stage registers

The pipeline uses explicit registers between stages rather than a single
multi-cycle state machine. Each boundary carries the data and control signals
required by later stages.

| Stage | Main work | Important state |
| --- | --- | --- |
| IF | PC prediction, cache lookup, instruction fetch | `if_pc`, `if_pc_fetch`, `if_instruct` |
| ID | Decode and register read | `id_instruct`, `id_rs1_addr`, `id_rs2_addr`, control signals |
| EX | ALU result, branch decision, jump target | `exe_data_a`, `exe_data_b`, `exe_alu_y`, `exe_branch` |
| MEM | Load/store and Wishbone transaction | `mem_wb_we`, load data, memory control |
| WB | Register writeback | `wb_waddr`, `wb_wdata`, `wb_we` |

The detailed signal handoff is summarized in
[`docs/pipeline-stage-table.md`](docs/pipeline-stage-table.md).

### Register forwarding and hazards

The execute stage can produce a value before it has reached writeback. To avoid
an unnecessary stall, the ID stage selects the newest available operand from:

1. the EX-stage result;
2. the MEM-stage result;
3. the WB-stage result;
4. the register file.

The hazard controller also handles cases that forwarding cannot solve. A memory
transaction stalls the front of the pipeline, while a control-flow redirect
flushes younger instructions.

## Instruction-cache design

The instruction cache is implemented inside `pipeline.sv` using register arrays:

- **8 sets**, selected by `PC[4:2]`;
- **8 ways per set**;
- a 27-bit tag from `PC[31:5]`;
- access counters used to choose a replacement way;
- direct instruction delivery on a hit;
- Wishbone fill on a miss.

Each set tracks how many ways are valid. Until a set is full, a miss fills the
next free way. Once full, the cache replaces the way with the smallest access
count. A `FENCE.I` instruction invalidates the cached instruction state so that
newly written code is not fetched from a stale entry.

The report includes waveforms showing cache hits, fills, replacement counters,
and `FENCE.I` handling:

![Instruction-cache hit waveform](docs/assets/wave-icache-hit.png)

## Next-PC prediction

The predictor is a small set-associative table in `pc_mux.sv`:

- 8 sets selected by `PC[4:2]`;
- 4 entries per set;
- each entry stores the source PC tag and the predicted next PC;
- misses populate an entry using FIFO replacement;
- a valid entry predicts its stored target;
- an invalid or unmatched entry falls back to `PC + 4`.

The prediction is checked when the corresponding instruction reaches EX. If the
actual next PC differs, the pipeline redirects the PC, flushes younger
instructions, and updates the predictor.

![Next-PC prediction waveform](docs/assets/wave-branch-target-buffer.png)

## Wishbone bus and peripherals

### Bus path

`wb_arbiter_2.v` combines two Wishbone masters into one request stream.
`wb_mux_3.v` then routes each request according to its address.

| Address range | Destination |
| --- | --- |
| `0x8000_0000` - `0x803F_FFFF` | Base SRAM |
| `0x8040_0000` - `0x807F_FFFF` | Extension SRAM |
| `0x1000_0000` - `0x1000_FFFF` | UART controller |

### UART monitor

The UART controller uses a 115200 baud configuration and exposes status and data
registers through Wishbone. The included monitor image supports operations such
as reading registers, displaying memory, loading a program, and starting user
code.

![FPGA monitor running](docs/assets/fpga-demo-sanitized.png)

### SRAM model and board integration

During simulation, `sram_model.v` models the external memory interface. On the
board, `sram_controller.sv` converts Wishbone transactions into active-low SRAM
chip-select, output-enable, write-enable, byte-enable, address, and data signals.

## Instruction support

The decoder is sized for the monitor and benchmark programs used by the course;
it is **not a complete implementation of every ratified RV32I instruction**.

| Format | Instructions implemented |
| --- | --- |
| U-type | `LUI`, `AUIPC` |
| J-type | `JAL`, `JALR` |
| Branch | `BEQ`, `BNE` |
| Load | `LB`, `LW` |
| Store | `SB`, `SW` |
| I-type ALU | `ADDI`, `ANDI`, `ORI`, `SLLI`, `SRLI` |
| R-type ALU | `ADD`, `AND`, `OR`, `XOR` |
| Extension operations | `ANDN`, `XNOR`, `SBCLR` |
| Fetch coherence | `FENCE.I` |

The three extension operations are defined by the course specification.
Instruction encoding and pipeline behavior are implemented in
`decoder.sv`, `alu.sv`, and `pipeline.sv`.

## Performance

The original 50 MHz benchmark run compared a baseline implementation with the
final instruction-cache and predictor version.

| Workload | Baseline | Final implementation | Interpretation |
| --- | ---: | ---: | --- |
| 1PTB | did not complete | 6.711 s | completed |
| 2DCT | 24.159 s | 13.757 s | 1.76x faster |
| 3CCT | did not complete | 5.369 s | completed |
| 4MDCT | did not complete | 20.133 s | completed |
| CryptoNight | 2.286 s | 1.846 s | 1.24x faster |

These are historical results from the original course benchmark environment.
They demonstrate that the optimized design completed all five workloads while
the baseline did not finish three of them. The repository does not contain a
portable benchmark runner or separate “cache-only” and “predictor-only”
baselines, so the combined result cannot be attributed precisely to one
optimization.

## Build and run

### Requirements

- Xilinx Vivado 2019.2 or a compatible version;
- a ThinPad board matching the included constraints;
- Python 3 for the repository audit script.

### FPGA build

1. Open [`thinpad_top.xpr`](thinpad_top.xpr) in Vivado.
2. Confirm that the active part is `xc7a100tfgg676-2L`.
3. Generate or upgrade the PLL IP if Vivado requests it.
4. Run synthesis, implementation, and bitstream generation.
5. Program the board and connect to the UART interface at 115200 baud.

The synthesis top module is `thinpad_top`.

### Simulation

1. Open the project in Vivado.
2. Set the simulation top to `tb` and run behavioral simulation.
3. The base-RAM image is loaded from
   `thinpad_top.srcs/sim_1/new/testcase/kernel.bin`.
4. Open `tb_behav.wcfg` to restore the saved waveform layout.

The testbench also accepts optional extension-RAM and Flash images through the
paths near the top of `tb.sv`. Those images are not required for the basic
monitor simulation.

### Repository audit

Run a source-reference and accidental-private-path check with:

```bash
python scripts/audit_repo.py
```

This verifies that files referenced by the Vivado project exist and that common
absolute-user-path or private-IPv4 patterns have not been introduced. It does
not replace RTL simulation or synthesis.

## Repository map

```text
.
|-- README.md
|-- LICENSE
|-- NOTICE.md
|-- thinpad_top.xpr
|-- tb_behav.wcfg
|-- docs/
|   |-- design-report.zh-CN.md
|   |-- pipeline-stage-table.md
|   |-- publishing-checklist.md
|   `-- assets/
|-- scripts/
|   `-- audit_repo.py
`-- thinpad_top.srcs/
    |-- constrs_1/new/             Board constraints
    |-- sources_1/
    |   |-- ip/pll_example/        Vivado PLL IP
    |   `-- new/
    |       |-- arbiter/           Wishbone arbitration
    |       `-- common/            LFSR support modules
    `-- sim_1/
        |-- imports/               Flash initialization data
        `-- new/
            |-- include/           Device-model configuration
            `-- testcase/          Monitor and test programs
```

## Important modules

| Module | Purpose |
| --- | --- |
| `pipeline.sv` | Pipeline registers, forwarding, stalls, instruction cache, and data path |
| `pc_mux.sv` | Next-PC selection and predictor table |
| `hazard_controller.sv` | RAW, memory, and control-hazard control |
| `decoder.sv` | Instruction decode and immediate generation |
| `alu.sv` | Arithmetic and logic execution |
| `regfile.sv` | General-purpose register file |
| `thinpad_top.sv` | Board-level integration |
| `sram_controller.sv` | Wishbone-to-SRAM conversion |
| `uart_controller.sv` | UART register interface |
| `wb_arbiter_2.v` | Two-master Wishbone arbitration |
| `wb_mux_3.v` | Three-destination address routing |

## Current limitations

- The decoder implements the instruction subset required by the supplied
  monitor and tests, not every RV32I instruction.
- The instruction cache has no dedicated hardware hit/miss performance counters.
- The original repository does not include isolated cache-only or
  predictor-only baselines.
- The benchmark timings have not been re-run in a portable automated harness.
- The included simulation and board flow depend on ThinPad device models,
  constraints, and Vivado conventions.

## Documentation and licensing

The detailed Chinese design report, including forwarding, cache, prediction,
and waveform explanations, is available at
[`docs/design-report.zh-CN.md`](docs/design-report.zh-CN.md).

Original project code and documentation are covered by the
[MIT License](LICENSE). Device models, Xilinx IP metadata, and other third-party
files retain their original notices; see [NOTICE.md](NOTICE.md).
