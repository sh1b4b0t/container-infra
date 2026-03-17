# container-prometheus

Prometheus para desenvolvimento local usando Apple containers. Coleta métricas do OTEL Collector exposto no gateway da rede de containers.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado
- `container-otel-collector` em execução (expondo métricas em `192.168.65.1:8889`)

## Instalação

```bash
chmod +x prometheus-dev.sh
```

## Uso

```bash
# Iniciar Prometheus
./prometheus-dev.sh start

# Verificar status
./prometheus-dev.sh status

# Testar conectividade
./prometheus-dev.sh test

# Ver logs
./prometheus-dev.sh logs

# Parar
./prometheus-dev.sh stop

# Abrir shell no container
./prometheus-dev.sh shell

# Remover container e volumes
./prometheus-dev.sh reset
```

## Endpoints

| Endpoint | URL | Descrição |
|----------|-----|-----------|
| HTTP API / UI | `http://localhost:9090` | Interface web e API REST do Prometheus |

## Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Cria volumes, copia configuração e inicia o container |
| `stop` | Para o container |
| `status` | Mostra status e volumes |
| `logs` | Exibe logs do Prometheus |
| `shell` | Abre shell no container |
| `reset` | Remove container e volumes (apaga todos os dados) |
| `test` | Testa conectividade via `/-/ready` |

## Scrape Targets

| Job | Target | Descrição |
|-----|--------|-----------|
| `otel-collector` | `192.168.65.1:8889` | Métricas expostas pelo OTEL Collector |
| `prometheus` | `localhost:9090` | Auto-monitoramento do Prometheus |

O endereço `192.168.65.1` é o gateway IP da rede de containers Apple, permitindo que o Prometheus (rodando dentro de um container) alcance serviços no host.

## Volumes

| Volume | Conteúdo | Mount |
|--------|----------|-------|
| `prometheus-data` | Dados TSDB | `/prometheus` |
| `prometheus-config` | `prometheus.yml` | `/etc/prometheus:ro` |

## Configuração

Edite `prometheus.yml` para ajustar:
- `global.scrape_interval` — intervalo de coleta (padrão: 15s)
- `scrape_configs` — adicionar ou remover targets

Para aplicar mudanças na configuração, execute `reset` e `start` novamente.

## Integração com Grafana

Para usar o Prometheus como datasource no Grafana, adicione a URL:

```
http://192.168.65.1:9090
```

## Referências

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Apple Container](https://github.com/apple/container)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
