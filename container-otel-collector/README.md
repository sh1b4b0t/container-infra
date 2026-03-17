# container-otel-collector

OpenTelemetry Collector — central ingress for Claude Code telemetry. Receives traces, metrics, and logs via OTLP and routes them to the appropriate backends.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado
- `container-tempo` rodando (obrigatório para traces)
- `container-prometheus` rodando (opcional para métricas)

## Instalação

```bash
chmod +x otel-collector-dev.sh
```

## Uso

```bash
# Iniciar OTEL Collector
./otel-collector-dev.sh start

# Verificar status
./otel-collector-dev.sh status

# Testar conectividade
./otel-collector-dev.sh test

# Ver logs
./otel-collector-dev.sh logs

# Parar
./otel-collector-dev.sh stop

# Remover container e volumes
./otel-collector-dev.sh reset
```

## Endpoints

| Endpoint | URL | Descrição |
|----------|-----|-----------|
| OTLP gRPC | `localhost:4315` | Recebe telemetria via gRPC |
| OTLP HTTP | `http://localhost:4316` | Recebe telemetria via HTTP |
| Self-metrics | `http://localhost:8888/metrics` | Métricas internas do collector |
| Prometheus scrape | `http://localhost:8889/metrics` | Métricas de aplicação para Prometheus |

Portas 4315/4316 são usadas (em vez de 4317/4318) para evitar conflito com o Tempo, que já ocupa as portas padrão OTLP.

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Cria volumes, copia config e inicia o container |
| `stop` | Para o container |
| `status` | Mostra status e volumes |
| `logs` | Exibe logs do OTEL Collector |
| `shell` | Abre shell no container |
| `reset` | Remove container e volumes |
| `test` | Testa conectividade via self-metrics |

## Roteamento de Telemetria

| Sinal | Destino | Endereço |
|-------|---------|----------|
| Traces | Tempo (via OTLP gRPC) | `192.168.65.1:4317` |
| Metrics | Prometheus exporter | `:8889` (Prometheus scrapes) |
| Logs | Debug exporter (stdout) | — |

O IP `192.168.65.1` é o gateway padrão do Apple Container, que permite comunicação entre containers e o host.

## Configuração do Claude Code

Defina a variável de ambiente para que o Claude Code envie telemetria ao collector:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4316
```

Ou via gRPC:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4315
```

## Volumes

| Volume | Conteúdo | Mount |
|--------|----------|-------|
| `otel-collector-config` | `otel-collector.yaml` | `/etc/otel:ro` |
| `otel-collector-data` | (reservado para uso futuro) | — |

O collector é stateless; o volume de dados é criado por consistência com o padrão mas não é montado.

## Configuração

Edite `otel-collector.yaml` para ajustar:
- `processors.batch.timeout` — intervalo de envio em batch
- `exporters.prometheus.namespace` — prefixo das métricas exportadas
- `exporters.debug.verbosity` — nível de detalhe dos logs (`basic`, `normal`, `detailed`)

Para aplicar mudanças na configuração, execute `reset` e `start` novamente.

## Referências

- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [OTEL Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib)
- [Apple Container](https://github.com/apple/container)
