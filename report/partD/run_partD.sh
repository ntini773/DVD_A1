#!/usr/bin/env bash
# run_partD.sh - Part D: run LibreLane at 3.5, 4.0, ... ns (+0.5 ns after each setup failure)
# until setup slack >= 0, DRC = 0 and LVS = 0. Saves one metrics file per attempt.
#
# Run INSIDE the IIC-OSIC-TOOLS container, from the repo root:
#   docker exec -it iic-osic bash
#   cd /foss/designs/mult4_team07 && bash report/partD/run_partD.sh [start_ns] [max_ns]
# Example: bash report/partD/run_partD.sh 3.5 8.0
set -uo pipefail
# The container default PDK is ihp-sg13g2, so --pdk sky130A is required below.
START="${1:-3.5}"; MAX="${2:-8.0}"
OUT=report/partD; mkdir -p "$OUT/attempts" pnr/runs
: > "$OUT/attempts.tsv"
echo -e "clock_ns\ttag\tsetup_ws\thold_ws\tdrc\tlvs\tinstances\tcore_area\twirelength\tresult" >> "$OUT/attempts.tsv"

P="$START"
while awk "BEGIN{exit !($P <= $MAX)}"; do
  TAG="p${P/./p}ns"
  echo "==> CLOCK_PERIOD = $P ns (run tag $TAG)"
  cat > "pnr/config_$TAG.json" <<JSON
{
  "DESIGN_NAME": "mult_array",
  "VERILOG_FILES": ["dir::../rtl/full_adder.v", "dir::../rtl/mult_array.v"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": $P,
  "FP_SIZING": "absolute",
  "DIE_AREA": [0, 0, 150, 150]
}
JSON
  ( cd pnr && librelane --pdk sky130A --scl sky130_fd_sc_hd --run-tag "$TAG" --overwrite "config_$TAG.json" ) > "pnr/runs/$TAG.log" 2>&1
  mv "pnr/config_$TAG.json" "$OUT/attempts/config_$TAG.json"
  M="pnr/runs/$TAG/final/metrics.json"
  [[ -f "$M" ]] || M=$(ls -t pnr/runs/$TAG/*/state_out.json 2>/dev/null | head -1)
  python3 - "$P" "$TAG" "$M" "$OUT" >> "$OUT/attempts.tsv" <<'PY'
import json,sys
p,tag,mf,out=sys.argv[1:5]
try:
    m=json.load(open(mf)); m=m.get("metrics",m)
except Exception: m={}
g=lambda k:m.get(k)
ws=g("timing__setup__ws"); drc=g("route__drc_errors"); lvs=g("design__lvs_error__count")
ok = ws is not None and ws>=0 and drc==0 and lvs==0
if m: json.dump(m,open(f"{out}/attempts/metrics_{tag}.json","w"),indent=1)
print("\t".join(str(x) for x in [p,tag,ws,g("timing__hold__ws"),drc,lvs,g("design__instance__count"),g("design__core__area"),g("route__wirelength"),"PASS" if ok else "FAIL"]))
PY
  tail -1 "$OUT/attempts.tsv"
  tail -1 "$OUT/attempts.tsv" | grep -q PASS && break
  P=$(awk "BEGIN{print $P+0.5}")
done
echo "Table: $OUT/attempts.tsv"
