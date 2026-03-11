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
├── config.yaml               # Service config (if needed) - mounted as volume
├── .env                      # Secrets (NOT in git)
├── .env.example              # Template showing required variables
├── .gitignore                # Exclude .env, backups, .DS_Store
├── README.md                 # Documentation
└── .claude/
    └── settings.local.json   # Claude Code permissions
```

## Required Files Checklist

### 1. Management Script ({service}-dev.sh)

**Template structure:**

```bash
#!/bin/bash
set -e

# ============================================
# Configuração
# ============================================
CONTAINER_NAME="{service}-dev"
VOLUME_DATA="{service}-data"      # Data persistence volume
VOLUME_CONFIG="{service}-config"  # Config files volume (if needed)
PORT={default_port}
IMAGE="{service}:{version}-alpine"  # Use specific version, NOT :latest

# Arquivos externos
ENV_FILE=".env"
CONFIG_FILE="config.yaml"  # Se aplicável
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_volume_data_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_DATA$"
}

check_volume_config_exists() {
    container volume list --quiet 2>/dev/null | grep -q "^$VOLUME_CONFIG$"
}

# ============================================
# Funções Auxiliares
# ============================================
print_usage() {
    echo "Uso: $0 {start|stop|status|logs|shell|reset|backup|restore}"
}

check_container_running() {
    container list --quiet 2>/dev/null | grep -q "^$CONTAINER_NAME$"
}

check_env_file() {
    if [ ! -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        echo "❌ Arquivo '$ENV_FILE' não encontrado."
        echo "   cp .env.example .env"
        return 1
    fi
    return 0
}

# ============================================
# Comandos (case statement)
# ============================================
```

**Standard commands:**

| Command | Description |
|---------|-------------|
| `start` | Create volume, start container |
| `stop` | Stop container gracefully |
| `status` | Show container and volume status |
| `logs` | Follow container logs |
| `shell` | Open interactive shell |
| `reset` | Remove container and volume (with confirmation) |
| `backup` | Export data |
| `restore` | Import data |

### 2. Environment Files

**.env.example (committed to git):**
```bash
# Service credentials
{SERVICE}_USER=your-username
{SERVICE}_PASSWORD=your-password

# API keys (if needed)
API_KEY=your-api-key

# Inter-container URLs use gateway IP
DATABASE_URL=postgresql://postgres:postgres@192.168.64.1:5432/dbname
```

**.env (NOT in git):**
```bash
{SERVICE}_USER=actual-username
{SERVICE}_PASSWORD=actual-password
API_KEY=actual-key
```

### 3. .gitignore

```gitignore
# Secrets
.env

# Backups
*.sql
*.rdb
*.bson
*.json

# macOS
.DS_Store

# Editor
*.swp
*.swo
*~
```

### 4. Claude Permissions (.claude/settings.local.json)

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:github.com)",
      "Bash(container --help)",
      "Bash(container run:*)",
      "Bash(container volume:*)",
      "Bash(container list:*)",
      "Bash(container logs:*)",
      "Bash(container start:*)",
      "Bash(container stop:*)",
      "Bash(container delete:*)",
      "Bash(container exec:*)"
    ]
  }
}
```

## Apple Container Specifics

### Gateway IP for Inter-Container Communication

All containers communicate via the gateway IP: `192.168.64.1`

```
macOS Host (192.168.64.1)
  └── Apple Container Runtime
      ├── postgres-dev :5432
      ├── redis-dev :6379
      └── {service}-dev :{port}
```

**In config files, use gateway IP:**
```yaml
# Example: connecting to Redis from another container
cache_params:
  host: 192.168.64.1  # NOT localhost
  port: 6379
```

### Volume Mounting Patterns

**Two separate volumes:**
- `VOLUME_DATA` - Persistent data storage (database files, logs)
- `VOLUME_CONFIG` - Configuration files (mounted read-only)

```bash
# Standard volume mount for data
container run -d \
    -v $VOLUME_DATA:/data/path \
    image:tag

# With separate config volume
container run -d \
    -v $VOLUME_DATA:/data/db \
    -v $VOLUME_CONFIG:/etc/config:ro \
    image:tag
```

**Config file as volume (copy to volume first):**
```bash
container volume create $VOLUME_CONFIG
cat config.yaml | container run --rm -i \
    -v $VOLUME_CONFIG:/config \
    alpine:latest \
    sh -c "cat > /config/config.yaml"

# Then mount in main container
container run -d \
    -v $VOLUME_CONFIG:/app/config:ro \
    -e CONFIG_PATH=/app/config/config.yaml \
    image:tag
```

### Database Volume Mounting (lost+found Issue)

Apple Container creates volumes with a `lost+found` directory. Databases that need to initialize data directories cannot chmod/chown this, causing init failure.

**Affected services:** PostgreSQL, MySQL, MongoDB, and any database that initializes its data directory.

**Solution:** Mount to parent directory, let the database create its own subdirectory:

| Service | ❌ WRONG | ✅ CORRECT |
|---------|----------|------------|
| PostgreSQL | `/var/lib/postgresql/data` | `/var/lib/postgresql` |
| MongoDB | `/data/db` | `/data` (if init fails) |
| Qdrant | `/qdrant/storage` | `/qdrant-data` (use custom path) |

**PostgreSQL example:**
```bash
# PostgreSQL creates data/ subdirectory itself
-v postgres-data:/var/lib/postgresql
```

**MongoDB example:**
```bash
# Standard works, but if init fails, mount to /data instead
-v mongodb-data:/data/db
```

See [issue #333](https://github.com/apple/container/issues/333) for details.

## Image Selection

| Service | Recommended Image |
|---------|-------------------|
| PostgreSQL | `postgres:17-alpine` |
| Redis | `redis:7-alpine` |
| MongoDB | `mongo:7` |
| Qdrant | `qdrant/qdrant:v1.8` |
| LiteLLM | `ghcr.io/berriai/litellm:main-latest` |

**Rules:**
- Use specific versions, NOT `:latest`
- Prefer `-alpine` variants for smaller size
- Use official images from Docker Hub or ghcr.io

## Audit Checklist

When auditing an existing container-{service}/ directory:

| Check | Pass Criteria |
|-------|---------------|
| Directory naming | `container-{service}` pattern |
| Script naming | `{service}-dev.sh` |
| .env.example exists | Shows required variables |
| .env in .gitignore | Secrets not committed |
| Config externalized | Config file mounted as volume OR in .env |
| No hardcoded secrets | All credentials from .env file |
| Specific image version | NOT `:latest` |
| Separate volumes | VOLUME_DATA and VOLUME_CONFIG defined |
| Claude permissions | Full container command permissions |
| README complete | Includes requirements, usage, connection string |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding credentials in script | Move to .env, read with `grep VAR .env \| cut -d= -f2` |
| Using `:latest` tag | Pin to specific version like `postgres:17-alpine` |
| Database mounting to data subdirectory | Mount to parent dir (PostgreSQL: `/var/lib/postgresql`, not `/data`) |
| Using `localhost` in inter-container config | Use `192.168.64.1` (gateway IP) |
| Forgetting .env.example | Always create template showing required vars |
| Skipping .gitignore for .env | Add `.env` to .gitignore immediately |
| Single volume for data and config | Use separate VOLUME_DATA and VOLUME_CONFIG |

## References

- **REQUIRED:** Use Context7 MCP to fetch latest Apple Container documentation before creating new containers
- [Apple Container GitHub](https://github.com/apple/container)
- [Apple Container Issue #333](https://github.com/apple/container/issues/333) - PostgreSQL volume issue