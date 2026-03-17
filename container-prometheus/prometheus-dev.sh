#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="prometheus-dev"
VOLUME_DATA="prometheus-data"
VOLUME_CONFIG="prometheus-config"
PORT=9090
IMAGE="prom/prometheus:v3.2.1"
MAC_ADDRESS="02:00:00:00:00:05"
CONFIG_FILE="prometheus.yml"

OTEL_COLLECTOR_CONTAINER="otel-collector-dev"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|test}"
    echo ""
    echo "Comandos:"
    echo "  start   Inicia o container Prometheus"
    echo "  stop    Para o container"
    echo "  status  Mostra status do container"
    echo "  logs    Exibe logs do Prometheus"
    echo "  shell   Abre shell no container"
    echo "  reset   Remove container e volumes (CUIDADO: apaga todos os dados)"
    echo "  test    Testa conectividade com o Prometheus"
    echo ""
    echo "Endpoints:"
    echo "  HTTP API: http://localhost:$PORT"
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
    if ! container list --quiet 2>/dev/null | grep -q "^$OTEL_COLLECTOR_CONTAINER$"; then
        echo "❌ Dependência '$OTEL_COLLECTOR_CONTAINER' não está rodando."
        echo "   Inicie primeiro: cd ../container-otel-collector && ./otel-collector-dev.sh start"
        return 1
    fi
    echo "   ✅ $OTEL_COLLECTOR_CONTAINER está rodando"
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

    local otel_ip
    otel_ip=$(get_container_ip "$OTEL_COLLECTOR_CONTAINER")

    if [ -z "$otel_ip" ]; then
        echo "❌ Não foi possível detectar o IP do OTEL Collector."
        return 1
    fi

    echo "   IP do OTEL Collector detectado: $otel_ip"

    echo "Copiando configuração para o volume..."
    sed "s/192\.168\.64\.1:8889/${otel_ip}:8889/g" "$SCRIPT_DIR/$CONFIG_FILE" | container run --rm -i \
        -v "$VOLUME_CONFIG":/config \
        alpine:latest \
        sh -c "cat > /config/prometheus.yml"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando Prometheus..."

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

    # Criar volume de dados se não existir
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
        --network "default,mac=$MAC_ADDRESS" \
        -p "$PORT":9090 \
        -v "$VOLUME_DATA":/prometheus \
        -v "$VOLUME_CONFIG":/etc/prometheus:ro \
        -m 512M \
        "$IMAGE" \
        --config.file=/etc/prometheus/prometheus.yml \
        --storage.tsdb.path=/prometheus \
        --web.console.libraries=/usr/share/prometheus/console_libraries \
        --web.console.templates=/usr/share/prometheus/consoles

    echo ""
    echo "Prometheus iniciado com sucesso!"
    echo "HTTP API: http://localhost:$PORT"
    echo ""
    echo "Aguarde alguns segundos para o Prometheus inicializar completamente."
}

cmd_stop() {
    echo "Parando Prometheus..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Prometheus:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "HTTP API: http://localhost:$PORT"
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
    echo "⚠️  ATENÇÃO: Isso vai remover o container e todos os dados!"
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

    echo "Testando conectividade com Prometheus..."
    echo ""

    echo "1. Verificando /-/ready..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/-/ready 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        echo "   ✅ Prometheus está pronto (HTTP $http_code)"
    else
        echo "   ❌ Prometheus não está pronto (HTTP $http_code)"
        return 1
    fi

    echo ""
    echo "✅ Todos os testes passaram!"
    echo ""
    echo "Acesse o Prometheus em: http://localhost:$PORT"
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
