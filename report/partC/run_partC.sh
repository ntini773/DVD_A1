#!/usr/bin/env bash
# run_partC.sh - Part C: OpenSTA at 10 ns, then at T_min. Saves logs and reports in sta/.
# Run INSIDE the IIC-OSIC-TOOLS container, from the repo root:
#   docker exec -it iic-osic bash
#   cd /foss/designs/mult4_team07 && bash report/partC/run_partC.sh
set -euo pipefail
export PDK_ROOT=${PDK_ROOT:-/foss/pdks}
STA_PERIOD=10.0 STA_REPORT=sta/timing_10ns.rpt sta -exit sta/sta.tcl 2>&1 | tee sta/sta_10ns.log
WS=$(grep -m1 -A1 "worst slack" sta/sta_10ns.log | grep -oE -- '-?[0-9]+\.[0-9]+' | head -1 || true)
echo "Worst slack at 10 ns: $WS  (T_min = 10 - slack; set TMIN below to rerun)"
TMIN=${TMIN:-2.60}
STA_PERIOD=$TMIN STA_REPORT=sta/timing_tmin.rpt sta -exit sta/sta.tcl 2>&1 | tee sta/sta_tmin.log
