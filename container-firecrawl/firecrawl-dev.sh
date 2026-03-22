#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="firecrawl-dev"
VOLUME_DATA="firecrawl-data"
VOLUME_CONFIG="firecrawl-config"
PORT=3002
IMAGE="ghcr.io/mendableai/firecrawl:main-latest"
MAC_ADDRESS="02:00:00:00:00:0a"
CONFIG_FILE="firecrawl.conf"

ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Containers de dependência
REDIS_CONTAINER="redis-dev"
RABBITMQ_CONTAINER="rabbitmq-dev"
PLAYWRIGHT_CONTAINER="playwright-dev"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|provision|test}"
    echo ""
    echo "Comandos:"
    echo "  start       Inicia o container Firecrawl"
    echo "  stop        Para o container"
    echo "  status      Mostra status do container e dependências"
    echo "  logs        Exibe logs do Firecrawl"
    echo "  shell       Abre shell (sh) no container"
    echo "  reset       Remove container e volumes (CUIDADO: apaga todos os dados)"
    echo "  provision   Cria usuário firecrawl no RabbitMQ (executar antes de start)"
    echo "  test        Testa a API do Firecrawl"
    echo ""
    echo "Endpoint: http://localhost:$PORT/v1"
    echo "Bull UI:  http://localhost:$PORT/admin/<BULL_AUTH_KEY>/queues"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$1$"
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

get_config_var() {
    grep "^$1=" "$SCRIPT_DIR/$CONFIG_FILE" | cut -d= -f2-
}

get_container_ip() {
    container inspect "$1" 2>/dev/null \
        | grep -o '"ipv4Address":"[^"]*"' | head -1 \
        | cut -d'"' -f4 | cut -d'/' -f1 | tr -d '\\'
}

check_dependencies() {
    local ok=0

    if ! check_container_running "$REDIS_CONTAINER"; then
        echo "❌ Redis '$REDIS_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-redis && ./redis-dev.sh start"
        ok=1
    fi

    if ! check_container_running "$RABBITMQ_CONTAINER"; then
        echo "❌ RabbitMQ '$RABBITMQ_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-rabbitmq && ./rabbitmq-dev.sh start"
        ok=1
    fi

    if ! check_container_running "$PLAYWRIGHT_CONTAINER"; then
        echo "❌ Playwright '$PLAYWRIGHT_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-playwright && ./playwright-dev.sh start"
        ok=1
    fi

    return $ok
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
cmd_provision() {
    echo "Provisionando infraestrutura para Firecrawl..."
    echo ""

    check_env_file || return 1

    FIRECRAWL_RABBITMQ_USER=$(get_env_var "FIRECRAWL_RABBITMQ_USER")
    FIRECRAWL_RABBITMQ_PASS=$(get_env_var "FIRECRAWL_RABBITMQ_PASS")
    FIRECRAWL_RABBITMQ_VHOST=$(get_env_var "FIRECRAWL_RABBITMQ_VHOST")

    # --- RabbitMQ ---
    if ! check_container_running "$RABBITMQ_CONTAINER"; then
        echo "❌ RabbitMQ '$RABBITMQ_CONTAINER' não está rodando. Inicie-o primeiro."
        return 1
    fi

    echo "RabbitMQ: criando vhost '$FIRECRAWL_RABBITMQ_VHOST'..."
    container exec "$RABBITMQ_CONTAINER" rabbitmqctl add_vhost "$FIRECRAWL_RABBITMQ_VHOST" 2>/dev/null \
        || echo "  Vhost '$FIRECRAWL_RABBITMQ_VHOST' já existe."

    echo "RabbitMQ: criando usuário '$FIRECRAWL_RABBITMQ_USER'..."
    container exec "$RABBITMQ_CONTAINER" rabbitmqctl add_user \
        "$FIRECRAWL_RABBITMQ_USER" "$FIRECRAWL_RABBITMQ_PASS" 2>/dev/null || {
        echo "  Usuário já existe. Atualizando senha..."
        container exec "$RABBITMQ_CONTAINER" rabbitmqctl change_password \
            "$FIRECRAWL_RABBITMQ_USER" "$FIRECRAWL_RABBITMQ_PASS"
    }

    echo "RabbitMQ: configurando permissões no vhost '$FIRECRAWL_RABBITMQ_VHOST'..."
    container exec "$RABBITMQ_CONTAINER" rabbitmqctl set_permissions \
        -p "$FIRECRAWL_RABBITMQ_VHOST" \
        "$FIRECRAWL_RABBITMQ_USER" ".*" ".*" ".*"

    echo ""
    echo "✅ Provisionamento concluído!"
    echo ""
    echo "  RabbitMQ:"
    echo "    Vhost:   $FIRECRAWL_RABBITMQ_VHOST"
    echo "    Usuário: $FIRECRAWL_RABBITMQ_USER"
    echo "    URL:     amqp://$FIRECRAWL_RABBITMQ_USER:****@192.168.65.1:5672/$FIRECRAWL_RABBITMQ_VHOST"
    echo ""
    echo "  Redis (DB 1, sem autenticação):"
    echo "    URL:     redis://192.168.65.1:6379/1"
    echo ""
    echo "  Playwright:"
    echo "    URL:     http://192.168.65.1:3000/scrape"
}

cmd_start() {
    echo "Iniciando Firecrawl..."

    check_env_file || return 1
    check_dependencies || return 1

    if check_container_running "$CONTAINER_NAME"; then
        echo "Container '$CONTAINER_NAME' já está rodando."
        return 0
    fi

    if container list -a --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"; then
        echo "Container '$CONTAINER_NAME' existe mas está parado. Iniciando..."
        container start "$CONTAINER_NAME"
        echo "Container iniciado!"
        return 0
    fi

    # Detectar IPs das dependências
    REDIS_IP=$(get_container_ip "$REDIS_CONTAINER")
    RABBITMQ_IP=$(get_container_ip "$RABBITMQ_CONTAINER")
    PLAYWRIGHT_IP=$(get_container_ip "$PLAYWRIGHT_CONTAINER")

    if [ -z "$REDIS_IP" ] || [ -z "$RABBITMQ_IP" ] || [ -z "$PLAYWRIGHT_IP" ]; then
        echo "❌ Não foi possível detectar IPs das dependências."
        echo "   redis=$REDIS_IP  rabbitmq=$RABBITMQ_IP  playwright=$PLAYWRIGHT_IP"
        return 1
    fi

    echo "IPs detectados: redis=$REDIS_IP rabbitmq=$RABBITMQ_IP playwright=$PLAYWRIGHT_IP"

    # Ler variáveis do .env
    TEST_API_KEY=$(get_env_var "TEST_API_KEY")
    BULL_AUTH_KEY=$(get_env_var "BULL_AUTH_KEY")
    FIRECRAWL_RABBITMQ_USER=$(get_env_var "FIRECRAWL_RABBITMQ_USER")
    FIRECRAWL_RABBITMQ_PASS=$(get_env_var "FIRECRAWL_RABBITMQ_PASS")
    FIRECRAWL_RABBITMQ_VHOST=$(get_env_var "FIRECRAWL_RABBITMQ_VHOST")

    # Ler configurações de performance
    NUM_WORKERS=$(get_config_var "NUM_WORKERS_PER_QUEUE")
    MAX_JOBS=$(get_config_var "MAX_CONCURRENT_JOBS")

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
        -p "$PORT":3002 \
        -v "$VOLUME_DATA":/app/data \
        -v "$VOLUME_CONFIG":/app/config:ro \
        -e PORT=3002 \
        -e HOST=0.0.0.0 \
        -e USE_DB_AUTHENTICATION=false \
        -e REDIS_URL="redis://${REDIS_IP}:6379/1" \
        -e REDIS_RATE_LIMIT_URL="redis://${REDIS_IP}:6379/1" \
        -e PLAYWRIGHT_MICROSERVICE_URL="http://${PLAYWRIGHT_IP}:3000/scrape" \
        -e NUQ_RABBITMQ_URL="amqp://${FIRECRAWL_RABBITMQ_USER}:${FIRECRAWL_RABBITMQ_PASS}@${RABBITMQ_IP}:5672/${FIRECRAWL_RABBITMQ_VHOST}" \
        -e TEST_API_KEY="$TEST_API_KEY" \
        -e BULL_AUTH_KEY="$BULL_AUTH_KEY" \
        -e NUM_WORKERS_PER_QUEUE="$NUM_WORKERS" \
        -e MAX_CONCURRENT_JOBS="$MAX_JOBS" \
        -e FLY_PROCESS_GROUP=app \
        -m 2G \
        "$IMAGE"

    echo ""
    echo "Firecrawl iniciado com sucesso!"
    echo "  API:     http://localhost:$PORT/v1"
    echo "  Bull UI: http://localhost:$PORT/admin/$BULL_AUTH_KEY/queues"
    echo ""
    echo "Aguarde ~10s para o serviço inicializar. Use '$0 logs' para acompanhar."
}

cmd_stop() {
    echo "Parando Firecrawl..."

    if ! check_container_running "$CONTAINER_NAME"; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Firecrawl:"
    echo ""

    echo -n "  firecrawl-dev:        "
    if check_container_running "$CONTAINER_NAME"; then
        echo "✅ RODANDO"
    else
        echo "❌ PARADO"
    fi

    echo ""
    echo "Dependências:"
    echo -n "  redis-dev:            "
    check_container_running "$REDIS_CONTAINER" && echo "✅ Rodando" || echo "❌ Parado"
    echo -n "  rabbitmq-dev:         "
    check_container_running "$RABBITMQ_CONTAINER" && echo "✅ Rodando" || echo "❌ Parado"
    echo -n "  playwright-dev:       "
    check_container_running "$PLAYWRIGHT_CONTAINER" && echo "✅ Rodando" || echo "❌ Parado"

    if check_container_running "$CONTAINER_NAME"; then
        echo ""
        BULL_AUTH_KEY=$(get_env_var "BULL_AUTH_KEY" 2>/dev/null || echo "")
        echo "  API:     http://localhost:$PORT/v1"
        [ -n "$BULL_AUTH_KEY" ] && echo "  Bull UI: http://localhost:$PORT/admin/$BULL_AUTH_KEY/queues"
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
    if ! check_container_running "$CONTAINER_NAME"; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 1
    fi

    container logs -f "$CONTAINER_NAME"
}

cmd_shell() {
    if ! check_container_running "$CONTAINER_NAME"; then
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

    echo "Reset completo. Use '$0 provision && $0 start' para recriar."
}

cmd_test() {
    if ! check_container_running "$CONTAINER_NAME"; then
        echo "Container '$CONTAINER_NAME' não está rodando. Use '$0 start' primeiro."
        return 1
    fi

    check_env_file || return 1
    TEST_API_KEY=$(get_env_var "TEST_API_KEY")

    echo "Testando Firecrawl API..."
    echo ""

    echo "1. Health check..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/v1/health" 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ]; then
        echo "   ✅ /v1/health OK"
    else
        echo "   ❌ /v1/health falhou (HTTP $http_code)"
        echo "   Use '$0 logs' para ver os detalhes."
        return 1
    fi

    echo ""
    echo "2. Testando scrape..."
    local scrape_code
    scrape_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "http://localhost:$PORT/v1/scrape" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"url":"https://example.com","formats":["markdown"]}' 2>/dev/null || echo "000")

    if [ "$scrape_code" = "200" ]; then
        echo "   ✅ Scrape OK"
    else
        echo "   ❌ Scrape falhou (HTTP $scrape_code)"
        return 1
    fi

    echo ""
    echo "✅ Todos os testes passaram!"
}

# ============================================
# Main
# ============================================
case "$1" in
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    status)    cmd_status ;;
    logs)      cmd_logs ;;
    shell)     cmd_shell ;;
    reset)     cmd_reset ;;
    provision) cmd_provision ;;
    test)      cmd_test ;;
    *)         print_usage; exit 1 ;;
esac
