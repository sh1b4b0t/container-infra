#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="google-tasks-dev"
VOLUME_DATA="google-tasks-data"
VOLUME_CONFIG="google-tasks-config"
PORT=8080
IMAGE_NAME="google-tasks-mcp:latest"
MAC_ADDRESS="02:00:00:00:00:08"
CONFIG_FILE="config.yaml"
ENV_FILE=".env"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|build|auth|test}"
    echo ""
    echo "Comandos:"
    echo "  start         Constrói (se necessário) e inicia o servidor MCP"
    echo "  stop          Para o container"
    echo "  status        Mostra status do container e volumes"
    echo "  logs          Exibe logs do servidor"
    echo "  shell         Abre shell no container"
    echo "  reset         Remove container e volumes (CUIDADO: apaga token de auth)"
    echo "  build         Constrói a imagem Docker localmente"
    echo "  auth          Executa o fluxo de autenticação OAuth2 do Google"
    echo "  test          Testa se o servidor MCP está respondendo"
    echo ""
    echo "Endpoint MCP: http://localhost:$PORT/mcp"
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

check_image_exists() {
    container image list 2>/dev/null | grep -q "google-tasks-mcp"
}

get_env_var() {
    grep "^$1=" "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2-
}

check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   cp .env.example .env"
        return 1
    fi
    return 0
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
        sh -c "cat > /config/$CONFIG_FILE"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_build() {
    echo "Construindo imagem '$IMAGE_NAME'..."
    container build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    echo "✅ Imagem construída com sucesso!"
}

cmd_start() {
    echo "Iniciando Google Tasks MCP..."

    if ! check_env_file; then
        return 1
    fi

    if ! check_config_file; then
        return 1
    fi

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

    # Construir imagem se não existir
    if ! check_image_exists; then
        echo "Imagem '$IMAGE_NAME' não encontrada. Construindo..."
        cmd_build
    fi

    # Criar volume de dados se não existir
    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    # Criar volume de config e copiar configuração
    create_volume_and_copy_config

    # Ler credenciais do .env
    GOOGLE_CLIENT_ID=$(get_env_var "GOOGLE_CLIENT_ID")
    GOOGLE_CLIENT_SECRET=$(get_env_var "GOOGLE_CLIENT_SECRET")

    # Criar e iniciar container
    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        --network "default,mac=$MAC_ADDRESS" \
        -p "$PORT":8080 \
        -v "$VOLUME_DATA":/app/data \
        -v "$VOLUME_CONFIG":/app/config:ro \
        -e GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
        -e GOOGLE_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET" \
        -e TOKEN_FILE=/app/data/token.json \
        -e PORT=8080 \
        -m 512M \
        "$IMAGE_NAME"

    echo ""
    echo "Google Tasks MCP iniciado com sucesso!"
    echo "Endpoint MCP: http://localhost:$PORT/mcp"
    echo ""
    echo "Se ainda não autenticou, execute: $0 auth"
}

cmd_stop() {
    echo "Parando Google Tasks MCP..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Google Tasks MCP:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "Endpoint MCP: http://localhost:$PORT/mcp"
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi

    echo ""
    echo "Volume de dados '$VOLUME_DATA':"
    if check_volume_data_exists; then
        echo "  Existe"
        # Verificar se token existe
        TOKEN_CHECK=$(container run --rm \
            -v "$VOLUME_DATA":/app/data \
            alpine:latest \
            sh -c "[ -f /app/data/token.json ] && echo 'autenticado' || echo 'não autenticado'" 2>/dev/null || echo "erro")
        echo "  Auth: $TOKEN_CHECK"
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

    echo ""
    echo "Imagem '$IMAGE_NAME':"
    if check_image_exists; then
        echo "  Existe"
    else
        echo "  Não existe — execute: $0 build"
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

    container exec -it "$CONTAINER_NAME" /bin/sh
}

cmd_reset() {
    echo "⚠️  ATENÇÃO: Isso vai remover o container, volumes e o token de autenticação!"
    read -p "Tem certeza? (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Operação cancelada."
        return 0
    fi

    container stop "$CONTAINER_NAME" 2>/dev/null || true
    container delete "$CONTAINER_NAME" 2>/dev/null || true
    container volume delete "$VOLUME_DATA" 2>/dev/null || true
    container volume delete "$VOLUME_CONFIG" 2>/dev/null || true

    echo "Reset completo. Execute '$0 auth' para autenticar e '$0 start' para iniciar."
}

cmd_auth() {
    echo "Iniciando fluxo de autenticação OAuth2 do Google..."

    if ! check_env_file; then
        return 1
    fi

    # Garantir que imagem existe
    if ! check_image_exists; then
        echo "Imagem '$IMAGE_NAME' não encontrada. Construindo..."
        cmd_build
    fi

    # Criar volume de dados se não existir
    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    GOOGLE_CLIENT_ID=$(get_env_var "GOOGLE_CLIENT_ID")
    GOOGLE_CLIENT_SECRET=$(get_env_var "GOOGLE_CLIENT_SECRET")

    if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
        echo "❌ GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET devem estar configurados no .env"
        return 1
    fi

    echo ""
    echo "Um servidor local será iniciado na porta 8090 para receber o callback."
    echo "Copie a URL exibida abaixo e abra no navegador para autorizar o acesso."
    echo ""

    container run --rm -it \
        -p 8090:8090 \
        -v "$VOLUME_DATA":/app/data \
        -e GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
        -e GOOGLE_CLIENT_SECRET="$GOOGLE_CLIENT_SECRET" \
        -e TOKEN_FILE=/app/data/token.json \
        "$IMAGE_NAME" \
        python src/auth.py
}

cmd_test() {
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    echo "Testando servidor MCP Google Tasks..."
    echo ""

    # FastMCP Streamable HTTP: initialize session first
    init_response=$(curl -s -D - -w "\n%{http_code}" \
        -X POST "http://localhost:$PORT/mcp" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' 2>/dev/null)

    http_code=$(echo "$init_response" | tail -n1)
    session_id=$(echo "$init_response" | grep -i "mcp-session-id:" | tr -d '\r' | awk '{print $2}')

    if [ "$http_code" != "200" ] || [ -z "$session_id" ]; then
        echo "❌ Servidor não respondeu corretamente (HTTP $http_code)"
        echo "   Verifique os logs: $0 logs"
        return 1
    fi

    # List tools using session
    tools_response=$(curl -s -w "\n%{http_code}" \
        -X POST "http://localhost:$PORT/mcp" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "mcp-session-id: $session_id" \
        -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' 2>/dev/null)

    tools_code=$(echo "$tools_response" | tail -n1)

    if [ "$tools_code" = "200" ]; then
        echo "✅ Servidor MCP respondendo em http://localhost:$PORT/mcp"
        echo ""
        echo "Ferramentas disponíveis:"
        echo "$tools_response" | sed '$d' | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | while read -r tool; do
            echo "  - $tool"
        done
    else
        echo "❌ Servidor não respondeu corretamente (HTTP $tools_code)"
        echo "   Verifique os logs: $0 logs"
        return 1
    fi
}

# ============================================
# Main
# ============================================
case "$1" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    status)  cmd_status ;;
    logs)    cmd_logs ;;
    shell)   cmd_shell ;;
    reset)   cmd_reset ;;
    build)   cmd_build ;;
    auth)    cmd_auth ;;
    test)    cmd_test ;;
    *)       print_usage; exit 1 ;;
esac
