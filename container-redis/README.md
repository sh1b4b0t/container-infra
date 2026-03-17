# container-redis

Redis 7 para desenvolvimento local usando Apple containers.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Instalação

```bash
# Torne o script executável
chmod +x redis-dev.sh
```

## Uso

```bash
# Iniciar Redis
./redis-dev.sh start

# Verificar status
./redis-dev.sh status

# Conectar ao Redis
./redis-dev.sh shell
```

### String de Conexão

```
redis://localhost:6379
```

Para comunicação entre containers, use o IP do gateway:
```
redis://192.168.65.1:6379
```

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container Redis |
| `stop` | Para o container |
| `status` | Mostra status do container |
| `logs` | Exibe logs do Redis |
| `shell` | Abre redis-cli no container |
| `reset` | Remove container e volume (apaga todos os dados) |
| `backup <file>` | Exporta dados para arquivo RDB |
| `restore <file>` | Restaura dados de arquivo RDB |
| `info` | Mostra informações do Redis |

## Configuração

Edite as variáveis no topo do script `redis-dev.sh`:

```bash
CONTAINER_NAME="redis-dev"
VOLUME_DATA="redis-data"    # Volume para dados RDB
VOLUME_CONFIG="redis-config"  # Volume para redis.conf
PORT=6379
IMAGE="redis:7-alpine"
```

Para alterar a configuração do Redis, edite `redis.conf` antes de iniciar (ou após `reset`).

## Persistência

Os dados são persistidos em dois volumes gerenciados pelo Apple container. Os volumes sobrevivem a reinicializações do container.

- `redis-data` — arquivos RDB (snapshots dos dados)
- `redis-config` — configuração do Redis (`redis.conf`)

Redis usa RDB (snapshots) com as seguintes regras:
- Após 900s (15 min) se houver pelo menos 1 mudança
- Após 300s (5 min) se houver pelo menos 10 mudanças
- Após 60s se houver pelo menos 10000 mudanças

## Referências

- [Apple Container](https://github.com/apple/container)
- [Redis Docker Image](https://hub.docker.com/_/redis)