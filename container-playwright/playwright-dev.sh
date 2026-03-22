#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="playwright-dev"
VOLUME_DATA="playwright-data"
VOLUME_CONFIG="playwright-config"
PORT=3000
IMAGE="ghcr.io/mendableai/playwright-service:main-latest"
MAC_ADDRESS="02:00:00:00:00:09"
CONFIG_FILE="playwright.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset}"
    echo ""
    echo "Comandos:"
    echo "  start   Inicia o container Playwright (serviço HTTP de scraping)"
    echo "  stop    Para o container"
    echo "  status  Mostra status do container"
    echo "  logs    Exibe logs do Playwright"
    echo "  shell   Abre shell (sh) no container"
    echo "  reset   Remove container e volumes (CUIDADO: apaga todos os dados)"
    echo ""
    echo "Endpoint: http://localhost:$PORT/scrape"
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

get_config_var() {
    grep "^$1=" "$SCRIPT_DIR/$CONFIG_FILE" | cut -d= -f2-
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
    echo "Iniciando Playwright..."

    # Verificar arquivo de config
    check_config_file || return 1

    # Ler configurações
    BLOCK_MEDIA=$(get_config_var "BLOCK_MEDIA")

    # Verificar se container já está rodando
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

    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        --network "default,mac=$MAC_ADDRESS" \
        -p "$PORT":3000 \
        -v "$VOLUME_DATA":/app/data \
        -v "$VOLUME_CONFIG":/app/config:ro \
        -e BLOCK_MEDIA="$BLOCK_MEDIA" \
        -m 2G \
        "$IMAGE"

    echo ""
    echo "Playwright iniciado com sucesso!"
    echo "  Scrape endpoint: http://localhost:$PORT/scrape"
    echo "  Inter-container: http://192.168.65.1:$PORT/scrape"
    echo ""
    echo "Aguarde alguns segundos para o serviço inicializar completamente."
}

cmd_stop() {
    echo "Parando Playwright..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Playwright:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "  Scrape endpoint: http://localhost:$PORT/scrape"
        echo "  Inter-container: http://192.168.65.1:$PORT/scrape"
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

# ============================================
# Main
# ============================================
case "$1" in
    start)  cmd_start ;;
    stop)   cmd_stop ;;
    status) cmd_status ;;
    logs)   cmd_logs ;;
    shell)  cmd_shell ;;
    reset)  cmd_reset ;;
    *)      print_usage; exit 1 ;;
esac
