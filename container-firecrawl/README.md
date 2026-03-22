# container-firecrawl

Firecrawl para desenvolvimento local usando Apple containers. Serviço de scraping e crawling web que expõe uma API REST compatível com os SDKs oficiais.

Depende dos containers compartilhados: **redis-dev**, **rabbitmq-dev**, **playwright-dev**.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado
- Containers rodando: `redis-dev`, `rabbitmq-dev`, `playwright-dev`

## Setup (primeira vez)

```bash
cd container-infra/container-firecrawl

# 1. Torne o script executável
chmod +x firecrawl-dev.sh

# 2. Configure o ambiente
cp .env.example .env
# Edite .env com suas chaves

# 3. Inicie as dependências (se não estiverem rodando)
cd ../container-redis     && ./redis-dev.sh start
cd ../container-rabbitmq  && ./rabbitmq-dev.sh start
cd ../container-playwright && ./playwright-dev.sh start
cd ../container-firecrawl

# 4. Provisione o usuário firecrawl no RabbitMQ
./firecrawl-dev.sh provision

# 5. Inicie o Firecrawl
./firecrawl-dev.sh start
```

## Uso

```bash
# Verificar status
./firecrawl-dev.sh status

# Testar a API
./firecrawl-dev.sh test

# Ver logs
./firecrawl-dev.sh logs
```

### Endpoints

| Recurso | URL |
|---------|-----|
| API | `http://localhost:3002/v1` |
| Bull UI | `http://localhost:3002/admin/<BULL_AUTH_KEY>/queues` |

### Scrape via SDK

**Python:**
```python
from firecrawl import Firecrawl

app = Firecrawl(api_url="http://localhost:3002")
result = app.scrape_url("https://example.com")
```

**Node.js:**
```javascript
import FirecrawlApp from '@mendable/firecrawl-js';

const app = new FirecrawlApp({ apiUrl: 'http://localhost:3002' });
const result = await app.scrapeUrl('https://example.com');
```

**curl:**
```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H "Authorization: Bearer test-firecrawl-key" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container (requer dependências rodando) |
| `stop` | Para o container |
| `status` | Mostra status do container e dependências |
| `logs` | Exibe logs do Firecrawl |
| `shell` | Abre shell (sh) no container |
| `reset` | Remove container e volumes |
| `provision` | Cria usuário/vhost firecrawl no RabbitMQ |
| `test` | Health check + teste de scrape |

## Configuração

### .env

```bash
# API Authentication
TEST_API_KEY=test-firecrawl-key
BULL_AUTH_KEY=firecrawl-bull-key

# RabbitMQ (criado via provision)
FIRECRAWL_RABBITMQ_USER=firecrawl
FIRECRAWL_RABBITMQ_PASS=firecrawl
FIRECRAWL_RABBITMQ_VHOST=firecrawl
```

### firecrawl.conf

```ini
# Workers BullMQ por fila
NUM_WORKERS_PER_QUEUE=2

# Jobs simultâneos máximos
MAX_CONCURRENT_JOBS=5
```

## Provisionamento de Infraestrutura

O comando `provision` cria as credenciais necessárias nos containers compartilhados:

### RabbitMQ
- Vhost: `firecrawl`
- Usuário: `firecrawl` (configurado em `.env`)
- Permissões: leitura/escrita/configuração no vhost `firecrawl`
- URL: `amqp://firecrawl:****@192.168.65.1:5672/firecrawl`

### Redis
- Sem usuário separado (Redis sem autenticação neste stack)
- Database index 1 reservado para Firecrawl
- URL: `redis://192.168.65.1:6379/1`

### Playwright
- Sem usuário (serviço HTTP stateless)
- URL: `http://192.168.65.1:3000/scrape`

## Volumes

Dois volumes gerenciados pelo Apple container:

- `firecrawl-data` — dados temporários (`/app/data`)
- `firecrawl-config` — `firecrawl.conf` montado em `/app/config` (read-only)

## Arquitetura

```
macOS Host
  └── Apple Container Runtime
      ├── firecrawl-dev (ghcr.io/mendableai/firecrawl)
      │   ├── :3002  → API REST / Bull UI
      │   ├── firecrawl-data   → /app/data
      │   └── firecrawl-config → /app/config (ro)
      │
      ├── redis-dev :6379      ← BullMQ queues (DB 1)
      ├── rabbitmq-dev :5672   ← Message broker (vhost: firecrawl)
      └── playwright-dev :3000 ← Browser scraping (/scrape)
```

## Fluxo de uso

```bash
# Setup inicial
./firecrawl-dev.sh provision
./firecrawl-dev.sh start

# Uso diário
./firecrawl-dev.sh start
# ... trabalhar ...
./firecrawl-dev.sh stop

# Reset completo
./firecrawl-dev.sh reset
```

## Referências

- [Apple Container](https://github.com/apple/container)
- [Firecrawl GitHub](https://github.com/mendableai/firecrawl)
- [Firecrawl Self-Hosting](https://docs.firecrawl.dev/self-host)
