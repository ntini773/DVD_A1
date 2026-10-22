# 4-bit Array Multiplier - RTL to GDSII (SKY130)

## Team
| Name | Roll number |
|------|-------------|
| bhargav | 2023112014 |
| nitin | 2023112026 |

## Environment
- Tools: IIC-OSIC-TOOLS Docker image (or: pixi + Nix native install)
- PDK: sky130A, standard cell library sky130_fd_sc_hd

## Commands run (in order)

### Setup
```bash
./setup_repo.sh mult4_team07
```

### Part A - RTL design and verification
```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
gtkwave mult.vcd
```

### Part B - Synthesis

### Part C - Static timing analysis

### Part D - Physical design
| Attempt | CLOCK_PERIOD (ns) | Setup slack (ns) | DRC | LVS | Result |
|---------|-------------------|------------------|-----|-----|--------|

## Use of AI tools
<!-- Say which parts used AI help, as the assignment requires. -->
