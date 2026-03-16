---
name: apple-container-infra
description: Use when creating new container infrastructure (container-{service}), auditing existing container directories, or when user mentions "Apple Container", "container-infra", "criar container", "new container project". Also triggers when containers need .env files, config volumes, or follow standard patterns.
---

# Apple Container Infrastructure

## Overview

Standard patterns for creating development containers using Apple Container on macOS. All containers follow a consistent structure with externalized configuration, secrets in .env files, and volume-mounted configs.

**Core principle:** Configuration and secrets are ALWAYS external - mounted at runtime, never baked into images.

## When to Use

```dot
digraph when_trigger {
    "User request?" [shape=diamond];
    "Create new container?" [shape=diamond];
    "Audit existing?" [shape=diamond];
    "Apply creation pattern" [shape=box];
    "Apply audit checklist" [shape=box];
    "Explore existing patterns first" [shape=box];

    "User request?" -> "Create new container?";
    "Create new container?" -> "Explore existing patterns first" [label="yes"];
    "Explore existing patterns first" -> "Apply creation pattern";
    "Create new container?" -> "Audit existing?" [label="no"];
    "Audit existing?" -> "Apply audit checklist" [label="yes"];
}
```

- **Creating:** User asks to create container-mongodb, container-mysql, etc.
- **Auditing:** User asks to verify container structure follows guidelines
- **Reference:** User asks about Apple Container patterns, volume mounting, .env setup

## Directory Structure

```
container-{service}/
├── {service}-dev.sh          # Management script (executable)
├── {service}.conf            # Service config file - copied to VOLUME_CONFIG at start
├── .env                      # Secrets (NOT in git)
├── .env.example              # Template (only if service needs credentials)
└── README.md                 # Documentation
```

**Notes:**
- `.gitignore` is handled by the **repo root** (`**/.env`, `*.sql`, `*.rdb`, `.DS_Store`). No per-container `.gitignore` needed.
- No `.claude/settings.local.json` per-container.

## Required Files Checklist

### 1. Management Script ({service}-dev.sh)

**Full template:**

```bash
#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="{service}-dev"
VOLUME_DATA="{service}-data"      # Persistent data volume
VOLUME_CONFIG="{service}-config"  # Config files volume
PORT={default_port}
IMAGE="{service}:{version}-alpine"  # Use specific version, NOT :latest
CONFIG_FILE="{service}.conf"

# Only if service has credentials:
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Only if service depends on other containers:
POSTGRES_CONTAINER="postgres-dev"
REDIS_CONTAINER="redis-dev"

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|backup|restore}"
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

# Read a variable from .env (use instead of inline grep):
get_env_var() {
    grep "^$1=" "$SCRIPT_DIR/$ENV_FILE" | cut -d= -f2-
}

# Only if service has credentials:
check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   cp .env.example .env"
        return 1
    fi
    return 0
}

# Only if service has a config file:
check_config_file() {
    if [ ! -f "$SCRIPT_DIR/$CONFIG_FILE" ]; then
        echo "❌ Arquivo '$CONFIG_FILE' não encontrado."
        return 1
    fi
    return 0
}

# Only if service depends on other containers:
check_dependencies() {
    if ! container list --quiet 2>/dev/null | grep -q "^$POSTGRES_CONTAINER$"; then
        echo "❌ PostgreSQL '$POSTGRES_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-postgres && ./postgres-dev.sh start"
        return 1
    fi
    if ! container list --quiet 2>/dev/null | grep -q "^$REDIS_CONTAINER$"; then
        echo "❌ Redis '$REDIS_CONTAINER' não está rodando."
        echo "   Execute: cd ../container-redis && ./redis-dev.sh start"
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
cmd_start() {
    echo "Iniciando {Service}..."

    # Optional: check_dependencies || return 1
    # Optional: check_env_file || return 1
    # Optional: check_config_file || return 1

    # Read credentials (if service has .env):
    SERVICE_USER=$(get_env_var "SERVICE_USER")
    SERVICE_PASSWORD=$(get_env_var "SERVICE_PASSWORD")

    # Check if already running
    if check_container_running; then
        echo "Container '$CONTAINER_NAME' já está rodando."
        return 0
    fi

    # Restart stopped container without recreating
    if container list -a --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"; then
        echo "Container '$CONTAINER_NAME' existe mas está parado. Iniciando..."
        container start "$CONTAINER_NAME"
        echo "Container iniciado!"
        return 0
    fi

    # Create data volume
    if ! check_volume_data_exists; then
        echo "Criando volume '$VOLUME_DATA'..."
        container volume create "$VOLUME_DATA"
    fi

    # Create config volume and copy config
    create_volume_and_copy_config

    echo "Criando container '$CONTAINER_NAME'..."
    container run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT":{internal_port} \
        -v "$VOLUME_DATA":/data/path \
        -v "$VOLUME_CONFIG":/etc/service/conf.d:ro \
        -e SERVICE_USER="$SERVICE_USER" \
        -e SERVICE_PASSWORD="$SERVICE_PASSWORD" \
        -m {memory_limit} \
        "$IMAGE"

    echo ""
    echo "{Service} iniciado com sucesso!"
    echo "String de conexão: {protocol}://localhost:$PORT"
    echo ""
    echo "Aguarde alguns segundos para o serviço inicializar completamente."
}

cmd_stop() {
    echo "Parando {Service}..."
    if ! check_container_running; then
        echo "Container '$CONTAINER_NAME' não está rodando."
        return 0
    fi
    container stop "$CONTAINER_NAME"
    echo "Container parado."
}

cmd_status() {
    echo "Status do {Service}:"
    echo ""
    if check_container_running; then
        echo "Container: $CONTAINER_NAME"
        echo "Status: RODANDO"
        echo ""
        container list
        echo ""
        echo "String de conexão: {protocol}://localhost:$PORT"
    else
        echo "Container: $CONTAINER_NAME"
        echo "Status: PARADO ou NÃO EXISTE"
    fi
    echo ""
    echo "Volume de dados '$VOLUME_DATA':"
    check_volume_data_exists && container volume list || echo "  Não existe"
    echo ""
    echo "Volume de config '$VOLUME_CONFIG':"
    check_volume_config_exists && echo "  Existe" || echo "  Não existe"
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
    echo "⚠️  ATENÇÃO: Isso vai remover o container e todos os volumes!"
    read -p "Tem certeza? (y/N): " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Operação cancelada."; return 0; }

    container stop "$CONTAINER_NAME" 2>/dev/null || true
    container delete "$CONTAINER_NAME" 2>/dev/null || true
    container volume delete "$VOLUME_DATA" 2>/dev/null || true
    container volume delete "$VOLUME_CONFIG" 2>/dev/null || true

    echo "Reset completo. Use '$0 start' para criar um novo container."
}

# backup/restore: service-specific

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
    backup)  cmd_backup "$2" ;;
    restore) cmd_restore "$2" ;;
    *)       print_usage; exit 1 ;;
esac
```

**Standard commands:**

| Command | Description |
|---------|-------------|
| `start` | Create volumes, copy config, start container |
| `stop` | Stop container gracefully |
| `status` | Show container and both volume statuses |
| `logs` | Follow container logs |
| `shell` | Open interactive shell |
| `reset` | Remove container and both volumes (with confirmation) |
| `backup` | Export data |
| `restore` | Import data |

**Service-specific extra commands** (add as needed):

| Service | Extra commands |
|---------|----------------|
| Redis | `info` — Redis server info and stats |
| PostgreSQL | `add-service`, `remove-service`, `list-services` — manage per-service DBs/users |
| LiteLLM | `models` — list models via API; `test` — connectivity test |

**Recommended memory limits:**

| Service | `-m` flag |
|---------|-----------|
| Redis | `-m 256M` |
| PostgreSQL | `-m 512M` |
| LiteLLM | `-m 2G` |

### 2. Config File ({service}.conf)

Each service has a config file committed to git and copied into `VOLUME_CONFIG` at start:

| Service | Config file | Mount path | Start command |
|---------|-------------|------------|---------------|
| Redis | `redis.conf` | `/usr/local/etc/redis:ro` | `redis-server /usr/local/etc/redis/redis.conf` |
| PostgreSQL | `postgresql.conf` | `/etc/postgresql/conf.d:ro` | `postgres -c "config_file=/etc/postgresql/conf.d/postgresql.conf"` |
| LiteLLM | `config.yaml` | `/app/config` | `--config /app/config/config.yaml` |

**Redis example (`redis.conf`):**
```
maxmemory 128mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

**PostgreSQL example (`postgresql.conf`) — minimal complete config (used as primary via `config_file`):**
```
# Connection Settings
listen_addresses = '*'
max_connections = 100

# Memory Settings
shared_buffers = 128MB

# Locale / Timezone
datestyle = 'iso, mdy'
timezone = 'Etc/UTC'
log_timezone = 'Etc/UTC'
```

> **Note:** `include_dir` is NOT a GUC parameter — it cannot be passed via `-c`. Use `config_file` pointing to a complete (minimal) config file instead.

**LiteLLM config.yaml — reference env vars via `os.environ/VAR`:**
```yaml
litellm_settings:
  cache: True
  cache_params:
    host: os.environ/REDIS_HOST
    port: os.environ/REDIS_PORT
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
```

### 3. Environment Files

**.env.example (committed to git) — only for services with credentials:**
```bash
# Service credentials
{SERVICE}_USER=your-username
{SERVICE}_PASSWORD=your-password

# API keys (if needed)
API_KEY=your-api-key

# Inter-container URLs — gateway IP used as template, overridden dynamically at runtime
DATABASE_URL=postgresql://postgres:postgres@192.168.64.1:5432/dbname
REDIS_HOST=192.168.64.1
REDIS_PORT=6379
```

**No `.env` needed** for services without credentials (e.g., Redis — pass config via `redis.conf`).

## Apple Container Specifics

### Inter-Container Communication

**Option 1: Gateway IP (use in static `.env.example` templates)**
```
macOS Host (192.168.64.1)
  └── Apple Container Runtime
      ├── postgres-dev :5432
      ├── redis-dev :6379
      └── {service}-dev :{port}
```

**Option 2: Dynamic IP detection (required when gateway IP unreliable)**

Detect actual container IPs at runtime using `container inspect`:

```bash
POSTGRES_IP=$(container inspect "$POSTGRES_CONTAINER" 2>/dev/null \
    | grep -o '"ipv4Address":"[^"]*"' | head -1 \
    | cut -d'"' -f4 | cut -d'/' -f1 | tr -d '\\')

REDIS_IP=$(container inspect "$REDIS_CONTAINER" 2>/dev/null \
    | grep -o '"ipv4Address":"[^"]*"' | head -1 \
    | cut -d'"' -f4 | cut -d'/' -f1 | tr -d '\\')

if [ -z "$POSTGRES_IP" ] || [ -z "$REDIS_IP" ]; then
    echo "❌ Não foi possível detectar os IPs das dependências."
    return 1
fi

# Override host in DATABASE_URL from .env
DATABASE_URL_TEMPLATE=$(get_env_var "DATABASE_URL")
DATABASE_URL=$(echo "$DATABASE_URL_TEMPLATE" | sed "s|@[^:]*:\([0-9]*\)/|@${POSTGRES_IP}:\1/|")
REDIS_HOST="$REDIS_IP"
```

Pass resolved values as `-e` flags to `container run`.

### Database Volume Mounting (lost+found Issue)

Apple Container creates volumes with a `lost+found` directory. Databases that initialize data directories cannot chmod/chown this, causing init failure.

**Solution:** Mount to parent directory, let the database create its own subdirectory:

| Service | ❌ WRONG | ✅ CORRECT |
|---------|----------|------------|
| PostgreSQL | `/var/lib/postgresql/data` | `/var/lib/postgresql` |
| MongoDB | `/data/db` | `/data` (if init fails) |
| Qdrant | `/qdrant/storage` | `/qdrant-data` (custom path) |

See [issue #333](https://github.com/apple/container/issues/333) for details.

## Image Selection

| Service | Recommended Image |
|---------|-------------------|
| PostgreSQL | `postgres:17-alpine` |
| Redis | `redis:7-alpine` |
| MongoDB | `mongo:7` |
| Qdrant | `qdrant/qdrant:v1.8` |
| LiteLLM | `ghcr.io/berriai/litellm:main-stable` |

**Rules:**
- Use specific versions, NOT `:latest`
- Prefer `-alpine` variants for smaller size

## Audit Checklist

| Check | Pass Criteria |
|-------|---------------|
| Directory naming | `container-{service}` pattern |
| Script naming | `{service}-dev.sh` (executable) |
| Both volumes defined | `VOLUME_DATA` and `VOLUME_CONFIG` at top of script |
| Config file exists | `{service}.conf` or `config.yaml` committed to git |
| .env.example exists | Present if service needs credentials |
| .env excluded from git | Root `.gitignore` has `**/.env` |
| No hardcoded secrets | All credentials via `get_env_var` helper |
| Specific image version | NOT `:latest` |
| Stopped container restart | `container list -a` check in `cmd_start` |
| Both volumes deleted on reset | `cmd_reset` removes `VOLUME_DATA` and `VOLUME_CONFIG` |
| README complete | Includes requirements, usage, connection string, volume descriptions |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding credentials in script | Move to .env, read with `get_env_var VAR` (not inline grep) |
| Using `:latest` tag | Pin to specific version like `postgres:17-alpine` |
| Database mounting to data subdirectory | Mount to parent dir (PostgreSQL: `/var/lib/postgresql`) |
| Using `localhost` in inter-container config | Use gateway IP `192.168.64.1` or dynamic `container inspect` |
| Hardcoding `192.168.64.1` when it fails | Use `container inspect` to detect IP dynamically |
| Missing stopped-container restart path | Add `container list -a` check before `container run` in `cmd_start` |
| Single volume for everything | Always define separate `VOLUME_DATA` and `VOLUME_CONFIG` |
| Config options as CLI args | Move to a config file, copy to `VOLUME_CONFIG` at start |
| Creating per-container .gitignore | Root repo `.gitignore` with `**/.env` covers all containers |

## References

- **REQUIRED:** Use Context7 MCP to fetch latest Apple Container documentation before creating new containers
- [Apple Container GitHub](https://github.com/apple/container)
- [Apple Container Issue #333](https://github.com/apple/container/issues/333) - PostgreSQL volume issue
