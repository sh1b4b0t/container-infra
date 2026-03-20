#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="image-scan-dev"
VOLUME_DATA="image-scan-models"   # Model weights (sam3.pt ~3.4 GB)
PORT=8081
IMAGE="image-scan:dev"

ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LITELLM_CONTAINER="litellm-dev"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 <comando>"
    echo ""
    echo "Comandos:"
    echo "  start          Inicia o container"
    echo "  stop           Para o container"
    echo "  status         Mostra status e volumes"
    echo "  logs           Segue os logs em tempo real"
    echo "  shell          Shell interativo dentro do container"
    echo "  build          Build da imagem Docker local"
    echo "  install-model  Copia src/sam3.pt para o volume de modelos"
    echo "  reset          Remove container e volume de modelos ⚠️"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"
}

check_volume_data_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_DATA$"
}

check_image_exists() {
    container image list 2>/dev/null | grep -q "image-scan"
}

get_env_var() {
    grep "^$1=" "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2-
}

check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   cp .env.example .env && nano .env"
        return 1
    fi
    return 0
}

check_dependencies() {
    if ! container list --quiet 2>/dev/null | grep -q "^$LITELLM_CONTAINER$"; then
        echo "⚠️  LiteLLM '$LITELLM_CONTAINER' não está rodando."
        echo "   VLM fallback estará indisponível."
        echo "   Para iniciar: cd ../container-litellm && ./litellm-dev.sh start"
    fi
    return 0
}

# ============================================
# Comandos
# ============================================
cmd_build() {
    echo "Buildando imagem '$IMAGE'..."
    container build -t "$IMAGE" "$SCRIPT_DIR"
    echo "Build concluído: $IMAGE"
}

cmd_install_model() {
    echo "Instalando model weights no volume '$VOLUME_DATA'..."
    MODEL_SRC="$SCRIPT_DIR/src/sam3.pt"

    if [ ! -f "$MODEL_SRC" ]; then
        echo "❌ Arquivo 'src/sam3.pt' não encontrado."
        echo "   Baixe o modelo SAM-3 e coloque em container-image-scan/src/sam3.pt"
        echo "   Download via ultralytics:"
        echo "     uv run python -c \"from ultralytics import SAM; SAM('sam2.1_l.pt')\""
        echo "   Ou: https://docs.ultralytics.com/pt/models/sam-3/"
        return 1
    fi

    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    echo "Copiando sam3.pt para o volume (~3.4 GB — aguarde)..."
    cat "$MODEL_SRC" | container run --rm -i \
        -v "$VOLUME_DATA":/models \
        alpine:latest \
        sh -c "cat > /models/sam3.pt"

    echo "✅ Model weights instalados em '$VOLUME_DATA'."
}

cmd_start() {
    echo "Iniciando Image Scan MCP..."

    check_env_file || return 1

    if ! check_image_exists; then
        echo "❌ Imagem '$IMAGE' não encontrada. Execute primeiro:"
        echo "   $0 build"
        return 1
    fi

    check_dependencies

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
        echo "⚠️  Volume '$VOLUME_DATA' não existe — SAM-3 falhará, VLM será usado como fallback."
        echo "   Para instalar os model weights: $0 install-model"
        container volume create "$VOLUME_DATA"
    fi

    LITELLM_URL=$(get_env_var "LITELLM_URL")
    LITELLM_API_KEY=$(get_env_var "LITELLM_API_KEY")
    LITELLM_MODEL=$(get_env_var "LITELLM_MODEL")

    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT":8081 \
        -v "$VOLUME_DATA":/models:ro \
        -e SAM3_MODEL_PATH=/models/sam3.pt \
        -e LITELLM_URL="$LITELLM_URL" \
        -e LITELLM_API_KEY="$LITELLM_API_KEY" \
        -e LITELLM_MODEL="$LITELLM_MODEL" \
        -e PORT=8081 \
        -m 4G \
        "$IMAGE"

    echo ""
    echo "✅ Image Scan MCP iniciado!"
    echo "   MCP endpoint: http://localhost:$PORT/mcp"
    echo "   Aguarde ~10s para o modelo SAM-3 carregar."
}

cmd_stop() {
    echo "Parando Image Scan..."
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi
    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Image Scan MCP:"
    echo ""
    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "MCP endpoint: http://localhost:$PORT/mcp"
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi
    echo ""
    printf "Volume de modelos '%s': " "$VOLUME_DATA"
    check_volume_data_exists && echo "Existe" || echo "NÃO EXISTE (execute: $0 install-model)"
    printf "Imagem '%s': " "$IMAGE"
    check_image_exists && echo "Existe" || echo "NÃO EXISTE (execute: $0 build)"
}

cmd_logs() {
    check_container_running || { echo "Container não está rodando."; return 1; }
    container logs -f "$CONTAINER_NAME"
}

cmd_shell() {
    check_container_running || { echo "Container não está rodando. Use '$0 start' primeiro."; return 1; }
    container exec -it "$CONTAINER_NAME" /bin/sh
}

cmd_reset() {
    echo "⚠️  ATENÇÃO: Remove o container e o volume de modelos (3.4 GB serão perdidos)!"
    read -p "Tem certeza? (y/N): " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Operação cancelada."; return 0; }

    container stop "$CONTAINER_NAME" 2>/dev/null || true
    container delete "$CONTAINER_NAME" 2>/dev/null || true
    container volume delete "$VOLUME_DATA" 2>/dev/null || true

    echo "Reset completo. Para reinstalar os weights: $0 install-model"
}

# ============================================
# Main
# ============================================
case "$1" in
    start)         cmd_start ;;
    stop)          cmd_stop ;;
    status)        cmd_status ;;
    logs)          cmd_logs ;;
    shell)         cmd_shell ;;
    build)         cmd_build ;;
    reset)         cmd_reset ;;
    install-model) cmd_install_model ;;
    *)             print_usage; exit 1 ;;
esac
