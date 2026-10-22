#!/usr/bin/env python3
"""update_readme.py - refresh the command sections of README.md, task by task.

Run from the repo root:   python3 update_readme.py
Safe to run again: it replaces its own sections and leaves your team table and
the "Use of AI tools" section alone. Your old README is saved as .git/README.md.bak
(inside .git, so it is never committed).

Edit the text in SECTIONS below if a command you ran differs from what is written.
"""
import pathlib
import shutil
import sys

README = pathlib.Path("README.md")
if not README.exists():
    sys.exit("README.md not found. Run this from the repo root.")

SECTIONS = {}

# --------------------------------------------------------------------------- environment
SECTIONS["## Environment"] = """## Environment
- OS: Ubuntu 22.04, native install (no Docker)
- Simulation, synthesis, timing (Parts A to C): pixi environment with iverilog, yosys, openroad (OpenSTA) and gtkwave
- Physical design (Part D): LibreLane, installed with Nix
- PDK: sky130A (`$PDK_ROOT/sky130A`), standard cell library sky130_fd_sc_hd, typical corner tt_025C_1v80
- Used instead of the IIC-OSIC-TOOLS Docker image. Tool versions can differ slightly from the Docker image, so small differences in numbers are possible.
"""

# --------------------------------------------------------------------------- setup
SECTIONS["### Setup"] = """### Setup
```bash
cd ~/eda/designs
./setup_repo.sh mult4_team07      # creates folders, .gitignore, README, full_adder.v, first commits
cd mult4_team07
echo $PDK_ROOT $PDK              # check: sky130A
```
"""

# --------------------------------------------------------------------------- part A
SECTIONS["### Part A"] = """### Part A - RTL design and verification

**Task 1 - full adder** (`rtl/full_adder.v`, `assign` statements only)
```bash
iverilog -g2012 -o /dev/null rtl/full_adder.v
```

**Task 2 - array multiplier** (`rtl/mult_array.v`: 16 AND gates, 12 `full_adder` instances, 16 flip-flops, no `*`)
```bash
iverilog -g2012 -o /dev/null rtl/full_adder.v rtl/mult_array.v
```

**Task 3 - testbench** (`tb/tb_mult.v`: 10 ns clock, 2 reset cycles, 256 vectors, 2-cycle wait, writes `mult.vcd`)

**Task 4 - simulate until PASS**
```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
gtkwave mult.vcd
```
Result: `PASS: 256 vectors checked, 0 errors`  (saved in `report/partA/pass_line.txt`)

**Task 5 - own example and waveform** (roll number digit used: FILL_IN, so A = digit + 5, B = 7, or 9 if A = 7)
```bash
bash report/partA/run_partA.sh <last_digit>
gtkwave report/partA/example.vcd --script report/partA/gtkwave_view.tcl
```
Saved in `report/partA/`: `hand_example.txt`, `example_result.txt`, `waveform.png` (latency marked), `tb_example.v`.

**Task 6 - check that the testbench catches errors** (sum changed to `a ^ b`, then undone)
```bash
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tail -3
git checkout rtl/full_adder.v
```
Result: `FAIL: 256 vectors checked, 95 errors`  (saved in `report/partA/fail_line.txt`; `run_partA.sh` repeats this on a temporary copy)

**Block diagram:** `report/partA/block_diagram.png` (16 AND, 12 full adders, 16 flip-flops)

**Commit**
```bash
git add rtl tb report/partA
git commit -m "Part A: RTL, testbench, results"
```
"""

# --------------------------------------------------------------------------- part B
SECTIONS["### Part B"] = """### Part B - Logic synthesis with Yosys

**Task 1 - write and run `synth/synth.tcl`** (7 steps: read_verilog, synth -flatten, dfflibmap, abc, opt_clean, stat, write_verilog)
```bash
yosys -c synth/synth.tcl
```
Writes `synth/mult_array_netlist.v` and `synth/mult_array_stat.rpt`.

**Task 2 - fill the Part B table** from `synth/mult_array_stat.rpt`
(the script below builds it: `report/partB/results_table.md`)

**Task 3 - simulate the synthesized netlist**
```bash
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \\
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```
Result: see `report/partB/netlist_pass_line.txt`

**All three tasks in one go** (runs the commands above and saves results in `report/partB/`)
```bash
bash report/partB/run_partB.sh
```

**Commit**
```bash
git add synth report/partB
git commit -m "Part B: synthesis, netlist, stat report, netlist simulation"
```
"""

# --------------------------------------------------------------------------- placeholders
SECTIONS["### Part C"] = """### Part C - Static timing analysis
(not done yet)
"""
SECTIONS["### Part D"] = """### Part D - Physical design
(not done yet)

| Attempt | CLOCK_PERIOD (ns) | Setup slack (ns) | DRC | LVS | Result |
|---------|-------------------|------------------|-----|-----|--------|
"""

# Sections that already hold real content are never overwritten by a placeholder.
PLACEHOLDERS = {"### Part C", "### Part D"}


def is_heading(line: str, level_prefix: str) -> bool:
    """True if the line starts a heading at the same level or higher."""
    if level_prefix.startswith("### "):
        return line.startswith("### ") or line.startswith("## ")
    return line.startswith("## ")


def replace_section(text: str, key: str, block: str) -> str:
    lines = text.splitlines()
    start = next((i for i, l in enumerate(lines) if l.startswith(key)), None)
    block_lines = block.rstrip("\n").splitlines() + [""]
    if start is None:
        # not there yet: insert before "## Use of AI tools" if present, else at the end
        ai = next((i for i, l in enumerate(lines) if l.startswith("## Use of AI")), None)
        pos = ai if ai is not None else len(lines)
        return "\n".join(lines[:pos] + block_lines + lines[pos:]) + "\n"
    end = start + 1
    while end < len(lines) and not is_heading(lines[end], key):
        end += 1
    existing = "\n".join(lines[start:end])
    if key in PLACEHOLDERS and "(not done yet)" not in existing:
        return text                      # you already wrote real content here
    return "\n".join(lines[:start] + block_lines + lines[end:]) + "\n"


text = README.read_text()
backup = pathlib.Path(".git/README.md.bak") if pathlib.Path(".git").is_dir() else pathlib.Path("README.md.bak")
shutil.copy(README, backup)

if "## Commands run (in order)" not in text:
    ai = text.find("## Use of AI")
    heading = "## Commands run (in order)\n\n"
    text = (text[:ai] + heading + text[ai:]) if ai >= 0 else text.rstrip("\n") + "\n\n" + heading

for key, block in SECTIONS.items():
    text = replace_section(text, key, block)

README.write_text(text)
print(f"README.md updated (backup: {backup}). Sections written:")
for key in SECTIONS:
    print("  ", key)
print("Check the text marked FILL_IN and fix any command that differs from what you ran.")
