#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="otel-collector-dev"
VOLUME_DATA="otel-collector-data"
VOLUME_CONFIG="otel-collector-config"
PORT=4315
PORT_HTTP=4316
PORT_METRICS=8888
PORT_PROMETHEUS=8889
IMAGE="otel/opentelemetry-collector-contrib:0.122.0"
CONFIG_FILE="otel-collector.yaml"

TEMPO_CONTAINER="tempo-dev"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|test}"
    echo ""
    echo "Comandos:"
    echo "  start   Inicia o container OTEL Collector"
    echo "  stop    Para o container"
    echo "  status  Mostra status do container"
    echo "  logs    Exibe logs do OTEL Collector"
    echo "  shell   Abre shell no container"
    echo "  reset   Remove container e volumes"
    echo "  test    Testa conectividade com o OTEL Collector"
    echo ""
    echo "Endpoints:"
    echo "  gRPC receive:      localhost:$PORT"
    echo "  HTTP receive:      http://localhost:$PORT_HTTP"
    echo "  Self-metrics:      http://localhost:$PORT_METRICS/metrics"
    echo "  Prometheus scrape: http://localhost:$PORT_PROMETHEUS/metrics"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"
}

check_volume_data_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_DATA$"
}

check_volume_config_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_CONFIG$"
}

check_config_file() {
    if [ ! -f "$SCRIPT_DIR/$CONFIG_FILE" ]; then
        echo "❌ Arquivo '$CONFIG_FILE' não encontrado."
        return 1
    fi
    return 0
}

check_dependencies() {
    echo "Verificando dependências..."

    if ! container list --quiet 2>/dev/null | grep -q "^$TEMPO_CONTAINER$"; then
        echo "❌ Dependência '$TEMPO_CONTAINER' não está rodando."
        echo "   Inicie o container-tempo primeiro: cd ../container-tempo && ./tempo-dev.sh start"
        return 1
    fi

    echo "   ✅ $TEMPO_CONTAINER está rodando"
    return 0
}

get_container_ip() {
    container inspect "$1" 2>/dev/null \
        | grep -o '"ipv4Address":"[^"]*"' | head -1 \
        | cut -d'"' -f4 | cut -d'/' -f1 | tr -d '\\'
}

create_volume_and_copy_config() {
    if ! check_volume_config_exists; then
        echo "Criando volume '$VOLUME_CONFIG'..."
        container volume create "$VOLUME_CONFIG"
    fi

    local tempo_ip
    tempo_ip=$(get_container_ip "$TEMPO_CONTAINER")

    if [ -z "$tempo_ip" ]; then
        echo "❌ Não foi possível detectar o IP do Tempo."
        return 1
    fi

    echo "   IP do Tempo detectado: $tempo_ip"

    echo "Copiando configuração para o volume..."
    sed "s/192\.168\.64\.1:4317/${tempo_ip}:4317/g" "$SCRIPT_DIR/$CONFIG_FILE" | container run --rm -i \
        -v "$VOLUME_CONFIG":/config \
        alpine:latest \
        sh -c "cat > /config/otel-collector.yaml"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando OTEL Collector..."

    check_config_file || return 1
    check_dependencies || return 1

    # Verificar se container já existe e está rodando
    if check_container_running; then
        echo "Container '$CONTAINER_NAME' já está rodando."
        return 0
    fi

    # Verificar se container existe mas está parado
    if container list -a --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"; then
        echo "Container '$CONTAINER_NAME' existe mas está parado. Iniciando..."
        container start "$CONTAINER_NAME"
        echo "Container iniciado!"
        return 0
    fi

    # Criar volume de dados se não existir (para consistência com o padrão)
    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    # Criar volume de config e copiar configuração
    create_volume_and_copy_config

    # Criar e iniciar container
    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT":4315 \
        -p "$PORT_HTTP":4316 \
        -p "$PORT_METRICS":8888 \
        -p "$PORT_PROMETHEUS":8889 \
        -v "$VOLUME_CONFIG":/etc/otel:ro \
        -m 256M \
        "$IMAGE" \
        --config=/etc/otel/otel-collector.yaml

    echo ""
    echo "OTEL Collector iniciado com sucesso!"
    echo "gRPC receive:      localhost:$PORT"
    echo "HTTP receive:      http://localhost:$PORT_HTTP"
    echo "Self-metrics:      http://localhost:$PORT_METRICS/metrics"
    echo "Prometheus scrape: http://localhost:$PORT_PROMETHEUS/metrics"
    echo ""
    echo "Aguarde alguns segundos para o OTEL Collector inicializar completamente."
}

cmd_stop() {
    echo "Parando OTEL Collector..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do OTEL Collector:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "gRPC receive:      localhost:$PORT"
        echo "HTTP receive:      http://localhost:$PORT_HTTP"
        echo "Self-metrics:      http://localhost:$PORT_METRICS/metrics"
        echo "Prometheus scrape: http://localhost:$PORT_PROMETHEUS/metrics"
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi

    echo ""
    echo "Volume de dados '$VOLUME_DATA':"
    check_volume_data_exists && container volume list | grep "$VOLUME_DATA" || echo "  Não existe"

    echo ""
    echo "Volume de config '$VOLUME_CONFIG':"
    check_volume_config_exists && echo "  Existe" || echo "  Não existe"
}

cmd_logs() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 1
    fi

    container logs -f "$CONTAINER_NAME"
}

cmd_shell() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    container exec -it "$CONTAINER_NAME" /bin/sh
}

cmd_reset() {
    echo "⚠️  ATENÇÃO: Isso vai remover o container e os volumes!"
    read -p "Tem certeza? (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Operação cancelada."
        return 0
    fi

    container stop "$CONTAINER_NAME" 2>/dev/null || true
    container delete "$CONTAINER_NAME" 2>/dev/null || true
    container volume delete "$VOLUME_DATA" 2>/dev/null || true
    container volume delete "$VOLUME_CONFIG" 2>/dev/null || true

    echo "Reset completo. Use '$0 start' para criar um novo container."
}

cmd_test() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    echo "Testando conectividade com OTEL Collector..."
    echo ""

    echo "1. Verificando self-metrics em :$PORT_METRICS/metrics..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT_METRICS/metrics 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        echo "   ✅ OTEL Collector está pronto (HTTP $http_code)"
    else
        echo "   ❌ OTEL Collector não está pronto (HTTP $http_code)"
        return 1
    fi

    echo ""
    echo "✅ Todos os testes passaram!"
    echo ""
    echo "Para enviar telemetria, configure o OpenTelemetry SDK:"
    echo "  OTLP gRPC: localhost:$PORT"
    echo "  OTLP HTTP: http://localhost:$PORT_HTTP"
    echo ""
    echo "Variável de ambiente para Claude Code:"
    echo "  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:$PORT_HTTP"
}

# ============================================
# Main
# ============================================
case "$1" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    shell)
        cmd_shell
        ;;
    reset)
        cmd_reset
        ;;
    test)
        cmd_test
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
