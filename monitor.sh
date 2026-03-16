#!/bin/bash

# ============================================
# Monitor de recursos em tempo real
# ============================================
INTERVAL=${1:-2}  # segundos entre refreshes (padrão: 2)

# Cores
BOLD='\033[1m'
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'

# Ordem preferida de exibição (containers da stack, ignorar buildkit)
STACK_ORDER="redis-dev postgres-dev litellm-dev tempo-dev otel-collector-dev prometheus-dev grafana-dev"

render() {
    local sample1="$1"
    local sample2="$2"
    local elapsed_us="$3"
    local now
    now=$(date '+%H:%M:%S')

    python3 - "$sample1" "$sample2" "$elapsed_us" "$now" "$STACK_ORDER" <<'PYEOF'
import sys, json

sample1   = json.loads(sys.argv[1])
sample2   = json.loads(sys.argv[2])
elapsed   = int(sys.argv[3])
now       = sys.argv[4]
order_str = sys.argv[5]

BOLD  = '\033[1m'
RESET = '\033[0m'
CYAN  = '\033[0;36m'
GREEN = '\033[0;32m'
YELLOW= '\033[0;33m'
RED   = '\033[0;31m'
DIM   = '\033[2m'

# Indexar por id
s1 = {c['id']: c for c in sample1}
s2 = {c['id']: c for c in sample2}

order = order_str.split()
all_ids = order + [i for i in s2 if i not in order and i != 'buildkit']

def fmt_bytes(b):
    if b >= 1073741824:
        return f'{b/1073741824:.1f}G'
    if b >= 1048576:
        return f'{b/1048576:.0f}M'
    if b >= 1024:
        return f'{b/1024:.0f}K'
    return f'{b}B'

def mem_bar(used, limit, width=12):
    pct = used / limit if limit > 0 else 0
    filled = int(pct * width)
    bar = '█' * filled + '░' * (width - filled)
    if pct >= 0.85:
        color = RED
    elif pct >= 0.65:
        color = YELLOW
    else:
        color = GREEN
    return f'{color}{bar}{RESET}'

def cpu_color(pct):
    if pct >= 50:  return RED
    if pct >= 20:  return YELLOW
    return GREEN

header  = f'  {BOLD}{CYAN}{"CONTAINER":<26} {"CPU%":>6}  {"MEM USED":>8} {"/ LIMIT":>7}  {"":12}  {"MEM%":>5}  {"PROCS":>5}{RESET}'
divider = f'  {DIM}{"─"*26} {"──────":>6}  {"────────":>8} {"───────":>7}  {"────────────":12}  {"─────":>5}  {"─────":>5}{RESET}'

print(f'\033[H\033[2J', end='')  # clear screen
print()
print(f'  {BOLD}{CYAN}════════════════════════════════════════════════════════════{RESET}')
print(f'  {BOLD}{CYAN}   Container Monitor  —  refresh {sys.argv[3][:1]}s  —  {now}              {RESET}')
print(f'  {BOLD}{CYAN}════════════════════════════════════════════════════════════{RESET}')
print()
print(header)
print(divider)

for cid in all_ids:
    if cid not in s2:
        print(f'  {DIM}{cid:<26} {"—":>6}  {"—":>8} {"—":>7}  {"":12}  {"—":>5}  {"—":>5}{RESET}')
        continue

    c2 = s2[cid]
    c1 = s1.get(cid, c2)

    delta_cpu = c2['cpuUsageUsec'] - c1['cpuUsageUsec']
    cpu_pct   = (delta_cpu / elapsed * 100) if elapsed > 0 else 0.0
    cpu_pct   = max(0.0, cpu_pct)

    mem_used  = c2['memoryUsageBytes']
    mem_lim   = c2['memoryLimitBytes']
    mem_pct   = (mem_used / mem_lim * 100) if mem_lim > 0 else 0.0
    procs     = c2['numProcesses']

    bar    = mem_bar(mem_used, mem_lim)
    cc     = cpu_color(cpu_pct)
    name   = cid.replace('-dev', '')

    print(f'  {BOLD}{name:<26}{RESET} '
          f'{cc}{cpu_pct:>5.1f}%{RESET}  '
          f'{fmt_bytes(mem_used):>8} '
          f'{DIM}/{RESET} {fmt_bytes(mem_lim):<6}  '
          f'{bar}  '
          f'{mem_pct:>4.0f}%  '
          f'{procs:>5}')

print()
print(f'  {DIM}Ctrl+C para sair{RESET}')
print()
PYEOF
}

collect() {
    container stats --no-stream --format json 2>/dev/null
}

echo -e "${CYAN}Iniciando monitor (intervalo: ${INTERVAL}s)...${RESET}"

# Primeira amostra
prev=$(collect)
prev_time=$(python3 -c "import time; print(int(time.time() * 1_000_000))")

while true; do
    sleep "$INTERVAL"

    curr=$(collect)
    curr_time=$(python3 -c "import time; print(int(time.time() * 1_000_000))")
    elapsed=$(( curr_time - prev_time ))

    render "$prev" "$curr" "$elapsed"

    prev="$curr"
    prev_time="$curr_time"
done
