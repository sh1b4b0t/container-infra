# container-playwright

Playwright microservice para desenvolvimento local usando Apple containers. Expõe um endpoint HTTP `/scrape` compatível com o Firecrawl (`PLAYWRIGHT_MICROSERVICE_URL`).

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Instalação

```bash
cd container-infra/container-playwright

# Torne o script executável
chmod +x playwright-dev.sh
```

## Uso

```bash
# Iniciar serviço Playwright
./playwright-dev.sh start

# Verificar status
./playwright-dev.sh status

# Parar
./playwright-dev.sh stop
```

### Endpoint

```bash
# Fazer scrape de uma URL
curl -X POST http://localhost:3000/scrape \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

### Strings de Conexão

| Contexto | URL |
|----------|-----|
| Localhost | `http://localhost:3000/scrape` |
| Inter-container | `http://192.168.65.1:3000/scrape` |

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container Playwright |
| `stop` | Para o container |
| `status` | Mostra status do container e volumes |
| `logs` | Exibe logs do serviço |
| `shell` | Abre shell (sh) no container |
| `reset` | Remove container e volumes (apaga todos os dados) |

## Configuração

Edite `playwright.conf` para ajustar as configurações do serviço:

```ini
# Bloquear downloads de media para reduzir banda (true/false)
BLOCK_MEDIA=true
```

## Volumes

Dois volumes gerenciados pelo Apple container:

- `playwright-data` — artefatos temporários (`/app/data`)
- `playwright-config` — `playwright.conf` montado em `/app/config` (read-only)

## Arquitetura

```
macOS Host
  └── Apple Container Runtime
      └── playwright-dev (ghcr.io/mendableai/playwright-service)
          ├── :3000  → HTTP /scrape
          ├── playwright-data   → /app/data
          └── playwright-config → /app/config (ro)
```

Serviço HTTP de scraping baseado em Playwright, projetado para integração com o Firecrawl via `PLAYWRIGHT_MICROSERVICE_URL=http://192.168.65.1:3000/scrape`.

## Referências

- [Apple Container](https://github.com/apple/container)
- [Firecrawl Playwright Service](https://github.com/mendableai/firecrawl/tree/main/apps/playwright-service-ts)
