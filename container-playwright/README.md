# container-playwright

Playwright v1.51 para desenvolvimento local usando Apple containers. Expõe um servidor WebSocket ao qual outros serviços ou testes locais podem conectar para executar automação de browser remotamente.

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
# Iniciar servidor Playwright
./playwright-dev.sh start

# Verificar status
./playwright-dev.sh status

# Parar
./playwright-dev.sh stop
```

### Conectar ao servidor

**JavaScript/TypeScript:**
```js
const browser = await playwright['chromium'].connect('ws://localhost:3000/');
```

**Python:**
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect("ws://localhost:3000/")
```

### Strings de Conexão

| Contexto | URL |
|----------|-----|
| Localhost | `ws://localhost:3000/` |
| Inter-container | `ws://192.168.65.1:3000/` |

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container Playwright (servidor WebSocket) |
| `stop` | Para o container |
| `status` | Mostra status do container e volumes |
| `logs` | Exibe logs do servidor |
| `shell` | Abre shell (sh) no container |
| `reset` | Remove container e volumes (apaga todos os dados) |

## Configuração

Edite `playwright.conf` para ajustar as configurações do servidor:

```ini
# Porta do servidor WebSocket (externa)
PLAYWRIGHT_SERVER_PORT=3000

# Browser a expor: chromium, firefox, webkit
PLAYWRIGHT_BROWSER=chromium
```

Alterações em `playwright.conf` só têm efeito após `reset` + `start` (o config é copiado para o volume no primeiro start).

## Volumes

Dois volumes gerenciados pelo Apple container:

- `playwright-data` — artefatos do Playwright (`/home/pwuser/playwright-data`): screenshots, traces, downloads
- `playwright-config` — `playwright.conf` montado em `/home/pwuser/config` (read-only)

## Arquitetura

```
macOS Host
  └── Apple Container Runtime
      └── playwright-dev (mcr.microsoft.com/playwright:v1.51.0-noble)
          ├── :3000  → WebSocket (run-server)
          ├── playwright-data   → /home/pwuser/playwright-data
          └── playwright-config → /home/pwuser/config (ro)
```

O servidor é iniciado com `npx playwright run-server --port 3000 --host 0.0.0.0`, aceitando conexões de qualquer origem. O container roda como `pwuser` (não-root), conforme recomendado pela documentação oficial.

## Referências

- [Apple Container](https://github.com/apple/container)
- [Playwright Docker docs](https://playwright.dev/docs/docker)
- [Playwright run-server](https://playwright.dev/docs/api/class-browsertype#browser-type-launch-server)
