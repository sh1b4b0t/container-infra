#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="tempo-dev"
VOLUME_DATA="tempo-data"
VOLUME_CONFIG="tempo-config"
PORT=3200
PORT_OTLP_GRPC=4317
PORT_OTLP_HTTP=4318
IMAGE="grafana/tempo:2.6.1"
MAC_ADDRESS="02:00:00:00:00:03"
CONFIG_FILE="tempo.yaml"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|test}"
    echo ""
    echo "Comandos:"
    echo "  start   Inicia o container Tempo"
    echo "  stop    Para o container"
    echo "  status  Mostra status do container"
    echo "  logs    Exibe logs do Tempo"
    echo "  shell   Abre shell no container"
    echo "  reset   Remove container e volumes (CUIDADO: apaga todos os traces)"
    echo "  test    Testa conectividade com o Tempo"
    echo ""
    echo "Endpoints:"
    echo "  HTTP API: http://localhost:$PORT"
    echo "  OTLP gRPC: localhost:$PORT_OTLP_GRPC"
    echo "  OTLP HTTP: http://localhost:$PORT_OTLP_HTTP"
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

create_volume_and_copy_config() {
    if ! check_volume_config_exists; then
        echo "Criando volume '$VOLUME_CONFIG'..."
        container volume create "$VOLUME_CONFIG"
    fi

    echo "Copiando configuração para o volume..."
    cat "$SCRIPT_DIR/$CONFIG_FILE" | container run --rm -i \
        -v "$VOLUME_CONFIG":/config \
        alpine:latest \
        sh -c "cat > /config/tempo.yaml"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando Grafana Tempo..."

    check_config_file || return 1

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
        -p "$PORT":3200 \
        -p "$PORT_OTLP_GRPC":4317 \
        -p "$PORT_OTLP_HTTP":4318 \
        -v "$VOLUME_DATA":/var/tempo \
        -v "$VOLUME_CONFIG":/etc/tempo:ro \
        -m 512M \
        "$IMAGE" \
        -config.file=/etc/tempo/tempo.yaml

    echo ""
    echo "Grafana Tempo iniciado com sucesso!"
    echo "HTTP API:   http://localhost:$PORT"
    echo "OTLP gRPC:  localhost:$PORT_OTLP_GRPC"
    echo "OTLP HTTP:  http://localhost:$PORT_OTLP_HTTP"
    echo ""
    echo "Aguarde alguns segundos para o Tempo inicializar completamente."
}

cmd_stop() {
    echo "Parando Grafana Tempo..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Grafana Tempo:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "HTTP API:   http://localhost:$PORT"
        echo "OTLP gRPC:  localhost:$PORT_OTLP_GRPC"
        echo "OTLP HTTP:  http://localhost:$PORT_OTLP_HTTP"
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
    echo "⚠️  ATENÇÃO: Isso vai remover o container e todos os traces!"
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

    echo "Testando conectividade com Grafana Tempo..."
    echo ""

    echo "1. Verificando /ready..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ready 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        echo "   ✅ Tempo está pronto (HTTP $http_code)"
    else
        echo "   ❌ Tempo não está pronto (HTTP $http_code)"
        return 1
    fi

    echo ""
    echo "2. Verificando /api/echo..."
    local echo_response
    echo_response=$(curl -s http://localhost:$PORT/api/echo 2>/dev/null)

    if [ -n "$echo_response" ]; then
        echo "   ✅ API respondendo: $echo_response"
    else
        echo "   ⚠️  /api/echo sem resposta"
    fi

    echo ""
    echo "✅ Todos os testes passaram!"
    echo ""
    echo "Para enviar traces, configure seu OpenTelemetry SDK:"
    echo "  OTLP gRPC: localhost:$PORT_OTLP_GRPC"
    echo "  OTLP HTTP: http://localhost:$PORT_OTLP_HTTP"
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
