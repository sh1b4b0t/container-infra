#!/bin/bash

# ============================================
# Status de todos os containers da stack
# ============================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

check_container() {
    container list --quiet 2>/dev/null | grep -q "^$1$"
}

check_port() {
    curl -s --connect-timeout 1 "http://localhost:$1" -o /dev/null -w "%{http_code}" 2>/dev/null
}

check_tcp_port() {
    # Returns 0 if port is open
    (echo >/dev/tcp/localhost/"$1") 2>/dev/null
}

container_ip() {
    container inspect "$1" 2>/dev/null \
        | grep -o '"ipv4Address":"[^"]*"' | head -1 \
        | cut -d'"' -f4 | cut -d'/' -f1 | tr -d '\\'
}

status_icon() {
    if [ "$1" = "up" ]; then
        echo -e "${GREEN}✅ RODANDO${RESET}"
    else
        echo -e "${RED}❌ PARADO${RESET}"
    fi
}

port_icon() {
    if [ "$1" = "ok" ]; then
        echo -e "${GREEN}✅${RESET}"
    else
        echo -e "${RED}❌${RESET}"
    fi
}

echo ""
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${CYAN}   Stack Status — container-infra               ${RESET}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════${RESET}"
echo ""

# ─────────────────────────────────────────────
# Redis
# ─────────────────────────────────────────────
echo -e "${BOLD}Redis${RESET}"
if check_container "redis-dev"; then
    IP=$(container_ip "redis-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    if check_tcp_port 6379 2>/dev/null; then
        echo -e "  Porta 6379: $(port_icon ok)  redis://localhost:6379"
    else
        echo -e "  Porta 6379: $(port_icon fail)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 6379: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# PostgreSQL
# ─────────────────────────────────────────────
echo -e "${BOLD}PostgreSQL${RESET}"
if check_container "postgres-dev"; then
    IP=$(container_ip "postgres-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    if check_tcp_port 5432 2>/dev/null; then
        echo -e "  Porta 5432: $(port_icon ok)  postgresql://localhost:5432"
    else
        echo -e "  Porta 5432: $(port_icon fail)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 5432: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# LiteLLM
# ─────────────────────────────────────────────
echo -e "${BOLD}LiteLLM Proxy${RESET}"
if check_container "litellm-dev"; then
    IP=$(container_ip "litellm-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    HTTP=$(check_port 4000)
    if [ "$HTTP" = "200" ] || [ "$HTTP" = "401" ] || [ "$HTTP" = "307" ]; then
        echo -e "  Porta 4000: $(port_icon ok)  http://localhost:4000/v1"
    else
        echo -e "  Porta 4000: $(port_icon fail)  (HTTP $HTTP)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 4000: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# Tempo
# ─────────────────────────────────────────────
echo -e "${BOLD}Grafana Tempo${RESET}"
if check_container "tempo-dev"; then
    IP=$(container_ip "tempo-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    HTTP=$(check_port 3200/ready)
    if [ "$HTTP" = "200" ]; then
        echo -e "  Porta 3200: $(port_icon ok)  http://localhost:3200  (HTTP API)"
    else
        echo -e "  Porta 3200: $(port_icon fail)  (HTTP $HTTP)"
    fi
    if check_tcp_port 4317 2>/dev/null; then
        echo -e "  Porta 4317: $(port_icon ok)  localhost:4317          (OTLP gRPC)"
    else
        echo -e "  Porta 4317: $(port_icon fail)  localhost:4317          (OTLP gRPC)"
    fi
    if check_tcp_port 4318 2>/dev/null; then
        echo -e "  Porta 4318: $(port_icon ok)  http://localhost:4318   (OTLP HTTP)"
    else
        echo -e "  Porta 4318: $(port_icon fail)  http://localhost:4318   (OTLP HTTP)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 3200: $(port_icon fail)"
    echo -e "  Porta 4317: $(port_icon fail)"
    echo -e "  Porta 4318: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# OTEL Collector
# ─────────────────────────────────────────────
echo -e "${BOLD}OTEL Collector${RESET}"
if check_container "otel-collector-dev"; then
    IP=$(container_ip "otel-collector-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    if check_tcp_port 4315 2>/dev/null; then
        echo -e "  Porta 4315: $(port_icon ok)  localhost:4315          (OTLP gRPC)"
    else
        echo -e "  Porta 4315: $(port_icon fail)  localhost:4315          (OTLP gRPC)"
    fi
    if check_tcp_port 4316 2>/dev/null; then
        echo -e "  Porta 4316: $(port_icon ok)  http://localhost:4316   (OTLP HTTP)"
    else
        echo -e "  Porta 4316: $(port_icon fail)  http://localhost:4316   (OTLP HTTP)"
    fi
    HTTP=$(check_port 8889/metrics)
    if [ "$HTTP" = "200" ]; then
        echo -e "  Porta 8889: $(port_icon ok)  http://localhost:8889   (Prometheus scrape)"
    else
        echo -e "  Porta 8889: $(port_icon fail)  (HTTP $HTTP)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 4315: $(port_icon fail)"
    echo -e "  Porta 4316: $(port_icon fail)"
    echo -e "  Porta 8889: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# Prometheus
# ─────────────────────────────────────────────
echo -e "${BOLD}Prometheus${RESET}"
if check_container "prometheus-dev"; then
    IP=$(container_ip "prometheus-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    HTTP=$(check_port 9090/-/ready)
    if [ "$HTTP" = "200" ]; then
        echo -e "  Porta 9090: $(port_icon ok)  http://localhost:9090"
    else
        echo -e "  Porta 9090: $(port_icon fail)  (HTTP $HTTP)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 9090: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# Grafana
# ─────────────────────────────────────────────
echo -e "${BOLD}Grafana${RESET}"
if check_container "grafana-dev"; then
    IP=$(container_ip "grafana-dev")
    echo -e "  Container:  $(status_icon up)  (IP: $IP)"
    HTTP=$(check_port 3000/api/health)
    if [ "$HTTP" = "200" ]; then
        echo -e "  Porta 3000: $(port_icon ok)  http://localhost:3000"
    else
        echo -e "  Porta 3000: $(port_icon fail)  (HTTP $HTTP)"
    fi
else
    echo -e "  Container:  $(status_icon down)"
    echo -e "  Porta 3000: $(port_icon fail)"
fi
echo ""

# ─────────────────────────────────────────────
# Resumo
# ─────────────────────────────────────────────
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════${RESET}"

TOTAL=7
RUNNING=0
for c in redis-dev postgres-dev litellm-dev tempo-dev otel-collector-dev prometheus-dev grafana-dev; do
    check_container "$c" && RUNNING=$((RUNNING + 1))
done

if [ "$RUNNING" -eq "$TOTAL" ]; then
    echo -e "${BOLD}  Stack: ${GREEN}✅ Todos os $TOTAL containers rodando${RESET}"
elif [ "$RUNNING" -eq 0 ]; then
    echo -e "${BOLD}  Stack: ${RED}❌ Nenhum container rodando${RESET}"
else
    echo -e "${BOLD}  Stack: ${YELLOW}⚠️  $RUNNING/$TOTAL containers rodando${RESET}"
fi

echo -e "${BOLD}${CYAN}════════════════════════════════════════════════${RESET}"
echo ""
