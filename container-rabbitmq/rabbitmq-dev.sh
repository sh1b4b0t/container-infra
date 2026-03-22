#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="rabbitmq-dev"
VOLUME_DATA="rabbitmq-data"
VOLUME_CONFIG="rabbitmq-config"
PORT_AMQP=5672
PORT_MGMT=15672
IMAGE="rabbitmq:4-management-alpine"
MAC_ADDRESS="02:00:00:00:00:08"
CONFIG_FILE="rabbitmq.conf"

ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|management}"
    echo ""
    echo "Comandos:"
    echo "  start       Inicia o container RabbitMQ"
    echo "  stop        Para o container"
    echo "  status      Mostra status do container"
    echo "  logs        Exibe logs do RabbitMQ"
    echo "  shell       Abre shell (sh) no container"
    echo "  reset       Remove container e volumes (CUIDADO: apaga todos os dados)"
    echo "  management  Exibe URL do Management UI"
    echo ""
    echo "Strings de conexão:"
    echo "  AMQP:       amqp://localhost:$PORT_AMQP"
    echo "  Management: http://localhost:$PORT_MGMT"
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

check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   cp .env.example .env"
        return 1
    fi
    return 0
}

get_env_var() {
    grep "^$1=" "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2-
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
        sh -c "cat > /config/$CONFIG_FILE"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando RabbitMQ..."

    check_env_file || return 1

    RABBITMQ_USER=$(get_env_var "RABBITMQ_USER")
    RABBITMQ_PASSWORD=$(get_env_var "RABBITMQ_PASSWORD")
    RABBITMQ_VHOST=$(get_env_var "RABBITMQ_VHOST")

    if check_container_running; then
        echo "Container '$CONTAINER_NAME' já está rodando."
        return 0
    fi

    if container list -a --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"; then
        echo "Container '$CONTAINER_NAME' existe mas está parado. Iniciando..."
        container start "$CONTAINER_NAME"
        echo "Container iniciado!"
        return 0
    fi

    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    create_volume_and_copy_config

    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        --network "default,mac=$MAC_ADDRESS" \
        -p "$PORT_AMQP":5672 \
        -p "$PORT_MGMT":15672 \
        -v "$VOLUME_DATA":/var/lib/rabbitmq \
        -v "$VOLUME_CONFIG":/etc/rabbitmq/conf.d:ro \
        -e RABBITMQ_DEFAULT_USER="$RABBITMQ_USER" \
        -e RABBITMQ_DEFAULT_PASS="$RABBITMQ_PASSWORD" \
        -e RABBITMQ_DEFAULT_VHOST="$RABBITMQ_VHOST" \
        -m 512M \
        "$IMAGE"

    echo ""
    echo "RabbitMQ iniciado com sucesso!"
    echo "  AMQP:       amqp://$RABBITMQ_USER:****@localhost:$PORT_AMQP"
    echo "  Inter-container: amqp://$RABBITMQ_USER:****@192.168.65.1:$PORT_AMQP"
    echo "  Management: http://localhost:$PORT_MGMT"
    echo ""
    echo "Aguarde alguns segundos para o RabbitMQ inicializar completamente."
}

cmd_stop() {
    echo "Parando RabbitMQ..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do RabbitMQ:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        RABBITMQ_USER=$(get_env_var "RABBITMQ_USER" 2>/dev/null || echo "rabbitmq")
        echo "  AMQP:       amqp://$RABBITMQ_USER:****@localhost:$PORT_AMQP"
        echo "  Inter-container: amqp://$RABBITMQ_USER:****@192.168.65.1:$PORT_AMQP"
        echo "  Management: http://localhost:$PORT_MGMT"
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi

    echo ""
    echo "Volume de dados '$VOLUME_DATA':"
    if check_volume_data_exists; then
        container volume list
    else
        echo "  Não existe"
    fi

    echo ""
    echo "Volume de config '$VOLUME_CONFIG':"
    if check_volume_config_exists; then
        echo "  Existe"
    else
        echo "  Não existe"
    fi
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

    container exec -it "$CONTAINER_NAME" sh
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

cmd_management() {
    echo "RabbitMQ Management UI:"
    echo ""
    echo "  URL:    http://localhost:$PORT_MGMT"

    if [ -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        RABBITMQ_USER=$(get_env_var "RABBITMQ_USER")
        echo "  Usuário: $RABBITMQ_USER"
    fi

    echo ""
    if check_container_running; then
        echo "  Status: RODANDO — acesse no browser"
    else
        echo "  Status: container não está rodando"
    fi
}

# ============================================
# Main
# ============================================
case "$1" in
    start)      cmd_start ;;
    stop)       cmd_stop ;;
    status)     cmd_status ;;
    logs)       cmd_logs ;;
    shell)      cmd_shell ;;
    reset)      cmd_reset ;;
    management) cmd_management ;;
    *)          print_usage; exit 1 ;;
esac
