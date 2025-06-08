# Weakcore

My simple and weak RV32I soft core for learning purpose.

## Architecture

```
Instruction Fetch => Instruction Decode => Execution => Write Back
```

Bus operations are performed at execution stage.

- Both ID and WB takes one cycle always.
- EXE takes one cycle without bus operations involved.
- Bus operations take at least two cycles.

## Simulation Environment

### Requirements

- Verilator 5
- Lua 5.4: To run the testbench written in Lua.
- [Verilua](https://github.com/ziyao233/verilua): To generate binding for
  verilated code.

### Verilate the core and build Lua module

```shell
verilua buildpkg weakcore
# Generates obj_dir/Vweakcore.so
```

`-DDUMP` should be specified if you want a signal trace.

### Run with the test bench

```shell
LUA_CPATH=obj_dir/?.so lua5.4 bench.lua <BINARY_TO_BE_LOADED>
```

A binary could be loaded into the simulated memory when starting the simulation,
taking the 5050 program in `examples/` as example,

```shell
$ LUA_CPATH=obj_dir/?.so lua5.4 bench.lua examples/test.bin
5050 (0x13ba)
```

`bench.lua` recognizes several environment variables for debugging purpose,

- `DEBUG_BUS`: Log all performed bus operations.
- `DUMP`: Enable signal tracing.
- `MAXCYCLE`: Limitation of consumed clock cycles. Simulation will be
  terminated if the limitation is exceeded. Useful for getting a complete
  dump when the core falls in a dead loop.

### Details

Weakcore always starts execution from address `0x0` when reset is deasserted.

The simulation environment provides a 64KiB RAM starting from `0x0`. There are
also some special bus addresses serving for IO and debugging purposes,

- `0x80000000`: Values written are printed to terminal.
- `0x80000004`: Values written are printed to terminal as ASCII characters.
- `0x80000008`: Writing to the address terminates simulation.

## Port of riscv-tests

There's [a port of riscv-tests](https://github.com/ziyao233/weakcore-rvtests)
for Weakcore's simulation environment, and weakcore passes all rv32ui tests
except the one testing against misaligned memory access, which isn't supported
by weakcore.
