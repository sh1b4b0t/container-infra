#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="grafana-dev"
VOLUME_DATA="grafana-data"
VOLUME_CONFIG="grafana-config"
PORT=3000
IMAGE="grafana/grafana:11.4.0"
MAC_ADDRESS="02:00:00:00:00:06"
CONFIG_FILE="datasources.yaml"

# Dependências
TEMPO_CONTAINER="tempo-dev"
PROMETHEUS_CONTAINER="prometheus-dev"

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset}"
    echo ""
    echo "Comandos:"
    echo "  start   Inicia o container Grafana"
    echo "  stop    Para o container"
    echo "  status  Mostra status do container"
    echo "  logs    Exibe logs do Grafana"
    echo "  shell   Abre shell no container"
    echo "  reset   Remove container e volumes (CUIDADO: apaga dashboards e configurações)"
    echo ""
    echo "URL: http://localhost:$PORT"
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
    local ok=0
    if ! container list --quiet 2>/dev/null | grep -q "^$TEMPO_CONTAINER$"; then
        echo "❌ Dependência '$TEMPO_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-tempo && ./tempo-dev.sh start"
        ok=1
    else
        echo "   ✅ $TEMPO_CONTAINER está rodando"
    fi
    if ! container list --quiet 2>/dev/null | grep -q "^$PROMETHEUS_CONTAINER$"; then
        echo "❌ Dependência '$PROMETHEUS_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-prometheus && ./prometheus-dev.sh start"
        ok=1
    else
        echo "   ✅ $PROMETHEUS_CONTAINER está rodando"
    fi
    return $ok
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

    local tempo_ip prometheus_ip
    tempo_ip=$(get_container_ip "$TEMPO_CONTAINER")
    prometheus_ip=$(get_container_ip "$PROMETHEUS_CONTAINER")

    if [ -z "$tempo_ip" ]; then
        echo "❌ Não foi possível detectar o IP do Tempo."
        return 1
    fi
    if [ -z "$prometheus_ip" ]; then
        echo "❌ Não foi possível detectar o IP do Prometheus."
        return 1
    fi

    echo "   IP do Tempo detectado: $tempo_ip"
    echo "   IP do Prometheus detectado: $prometheus_ip"

    echo "Copiando datasources para o volume..."
    sed \
        -e "s|192\.168\.64\.1:3200|${tempo_ip}:3200|g" \
        -e "s|192\.168\.64\.1:9090|${prometheus_ip}:9090|g" \
        "$SCRIPT_DIR/$CONFIG_FILE" | container run --rm -i \
        -v "$VOLUME_CONFIG":/config \
        alpine:latest \
        sh -c "cat > /config/datasources.yaml"

    echo "Configuração copiada com sucesso."
}

# ============================================
# Comandos
# ============================================
cmd_start() {
    echo "Iniciando Grafana..."

    check_config_file || return 1
    check_dependencies

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

    # Criar volume de config e copiar datasources
    create_volume_and_copy_config

    # Criar e iniciar container
    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        --network "default,mac=$MAC_ADDRESS" \
        -p "$PORT":3000 \
        -v "$VOLUME_DATA":/var/lib/grafana \
        -v "$VOLUME_CONFIG":/etc/grafana/provisioning/datasources:ro \
        -e GF_AUTH_ANONYMOUS_ENABLED=true \
        -e GF_AUTH_ANONYMOUS_ORG_ROLE=Admin \
        -e GF_FEATURE_TOGGLES_ENABLE=traceqlEditor \
        -m 256M \
        "$IMAGE"

    echo ""
    echo "Grafana iniciado com sucesso!"
    echo "URL: http://localhost:$PORT"
    echo ""
    echo "Aguarde alguns segundos para o Grafana inicializar completamente."
    echo "Login: admin / admin (ou acesso anônimo como Admin)"
}

cmd_stop() {
    echo "Parando Grafana..."

    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi

    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do Grafana:"
    echo ""

    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "URL: http://localhost:$PORT"
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

    echo ""
    echo "Dependências:"
    echo -n "  Tempo ($TEMPO_CONTAINER): "
    container list --quiet 2>/dev/null | grep -q "^$TEMPO_CONTAINER$" && echo "✅ Rodando" || echo "❌ Parado"
    echo -n "  Prometheus ($PROMETHEUS_CONTAINER): "
    container list --quiet 2>/dev/null | grep -q "^$PROMETHEUS_CONTAINER$" && echo "✅ Rodando" || echo "❌ Parado"
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
    echo "⚠️  ATENÇÃO: Isso vai remover o container, dashboards e configurações!"
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
    *)
        print_usage
        exit 1
        ;;
esac
