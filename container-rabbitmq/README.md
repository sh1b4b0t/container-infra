# container-rabbitmq

RabbitMQ 4 para desenvolvimento local usando Apple containers. Inclui Management UI na porta 15672.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Instalação

```bash
cd container-infra/container-rabbitmq

# Configure o ambiente
cp .env.example .env
# Edite .env com suas credenciais (opcional — defaults: rabbitmq/rabbitmq)

# Torne o script executável
chmod +x rabbitmq-dev.sh
```

## Uso

```bash
# Iniciar RabbitMQ
./rabbitmq-dev.sh start

# Verificar status
./rabbitmq-dev.sh status

# Exibir URL e usuário do Management UI
./rabbitmq-dev.sh management
```

### Strings de Conexão

| Contexto | String |
|----------|--------|
| AMQP localhost | `amqp://rabbitmq:rabbitmq@localhost:5672` (credenciais do `.env`) |
| AMQP inter-container | `amqp://rabbitmq:rabbitmq@192.168.65.1:5672` (credenciais do `.env`) |
| Management UI | `http://localhost:15672` |

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container RabbitMQ |
| `stop` | Para o container |
| `status` | Mostra status do container e volumes |
| `logs` | Exibe logs do RabbitMQ |
| `shell` | Abre shell (sh) no container |
| `reset` | Remove container e volumes (apaga todos os dados) |
| `management` | Exibe URL e usuário do Management UI |

## Configuração

Edite `.env` para configurar credenciais:

```bash
RABBITMQ_USER=rabbitmq
RABBITMQ_PASSWORD=rabbitmq
RABBITMQ_VHOST=/
```

Edite `rabbitmq.conf` para ajustar configurações do broker antes de iniciar (ou após `reset`).

## Volumes

Dois volumes gerenciados pelo Apple container:

- `rabbitmq-data` — dados persistentes do RabbitMQ (`/var/lib/rabbitmq`)
- `rabbitmq-config` — `rabbitmq.conf` montado em `/etc/rabbitmq/conf.d` (read-only)

## Arquitetura

```
macOS Host
  └── Apple Container Runtime
      └── rabbitmq-dev (rabbitmq:4-management-alpine)
          ├── :5672  → AMQP
          ├── :15672 → Management UI
          ├── rabbitmq-data    → /var/lib/rabbitmq
          └── rabbitmq-config  → /etc/rabbitmq/conf.d (ro)
```

## Nota Técnica

O Apple container cria volumes com um diretório `lost+found`. O RabbitMQ não consegue
inicializar se tentar criar arquivos nesse diretório. A solução é montar o volume em
`/var/lib/rabbitmq` (não em um subdiretório) — o mesmo padrão usado pelo container-postgres.

Ver [issue #333](https://github.com/apple/container/issues/333) para mais detalhes.

## Referências

- [Apple Container](https://github.com/apple/container)
- [RabbitMQ Docker Image](https://hub.docker.com/_/rabbitmq)
- [RabbitMQ Configuration](https://www.rabbitmq.com/configure.html)
