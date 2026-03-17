# container-tempo

Grafana Tempo para desenvolvimento local usando Apple containers. Backend de rastreamento distribuído (distributed tracing) compatível com OpenTelemetry.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Instalação

```bash
chmod +x tempo-dev.sh
```

## Uso

```bash
# Iniciar Tempo
./tempo-dev.sh start

# Verificar status
./tempo-dev.sh status

# Testar conectividade (aguarde ~15s após o start para o ring estabilizar)
./tempo-dev.sh test

# Ver logs
./tempo-dev.sh logs
```

## Endpoints

| Endpoint | URL | Descrição |
|----------|-----|-----------|
| HTTP API | `http://localhost:3200` | API REST do Tempo |
| OTLP gRPC | `localhost:4317` | Ingestão de traces via gRPC |
| OTLP HTTP | `http://localhost:4318` | Ingestão de traces via HTTP |

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Cria volumes e inicia o container |
| `stop` | Para o container |
| `status` | Mostra status e volumes |
| `logs` | Exibe logs do Tempo |
| `shell` | Abre shell no container |
| `reset` | Remove container e volumes (apaga todos os traces) |
| `test` | Testa conectividade via `/ready` e `/api/echo` |

## Enviando Traces

### OpenTelemetry SDK (Python)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider = TracerProvider()
exporter = OTLPSpanExporter(endpoint="localhost:4317", insecure=True)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)
```

### OpenTelemetry SDK (Node.js)

```javascript
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const exporter = new OTLPTraceExporter({
  url: 'localhost:4317',
});
```

### curl (OTLP HTTP)

```bash
# Verificar se está pronto
curl http://localhost:3200/ready

# Buscar trace por ID
curl http://localhost:3200/api/traces/{traceId}
```

## Configuração

Edite `tempo.yaml` para ajustar:
- `ingester.trace_idle_period` — tempo para fechar um trace inativo
- `compactor.compaction.block_retention` — retenção dos traces (padrão: 1h)
- `storage.trace.backend` — backend de armazenamento (`local` para dev)

Para aplicar mudanças na configuração, execute `reset` e `start` novamente.

## Volumes

| Volume | Conteúdo | Mount |
|--------|----------|-------|
| `tempo-data` | Traces e WAL | `/var/tempo` |
| `tempo-config` | `tempo.yaml` | `/etc/tempo:ro` |

## Integração com Grafana

Para visualizar traces no Grafana, adicione o Tempo como datasource:

```
URL: http://192.168.65.1:3200
```

## Referências

- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Apple Container](https://github.com/apple/container)
- [OpenTelemetry](https://opentelemetry.io/)
