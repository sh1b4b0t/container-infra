# container-grafana

Grafana para desenvolvimento local usando Apple containers. Pré-configurado com Tempo como datasource para visualização de traces distribuídos.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado
- Grafana Tempo (container-tempo) rodando para visualizar traces

## Instalação

```bash
chmod +x grafana-dev.sh
```

## Uso

```bash
# Iniciar Grafana
./grafana-dev.sh start

# Verificar status
./grafana-dev.sh status

# Ver logs
./grafana-dev.sh logs
```

## Acesso

```
URL: http://localhost:3000
```

Acesso anônimo habilitado com papel de Admin — não é necessário login para desenvolvimento.

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Cria volumes e inicia o container |
| `stop` | Para o container |
| `status` | Mostra status, volumes e dependências |
| `logs` | Exibe logs do Grafana |
| `shell` | Abre shell no container |
| `reset` | Remove container e volumes (apaga dashboards e configurações) |

## Datasources

O Tempo é provisionado automaticamente como datasource padrão via `datasources.yaml`.

| Datasource | URL | Tipo |
|------------|-----|------|
| Tempo | `http://192.168.65.1:3200` | Distributed Tracing |

Para atualizar a URL do Tempo, edite `datasources.yaml` e execute `reset` + `start`.

## Visualizando Traces

1. Acesse **http://localhost:3000**
2. Vá em **Explore** → selecione datasource **Tempo**
3. Use **TraceQL** para consultar traces:
   ```
   { .service.name = "meu-servico" }
   ```
4. Ou busque por **Trace ID** diretamente

## Volumes

| Volume | Conteúdo | Mount |
|--------|----------|-------|
| `grafana-data` | SQLite DB, plugins, dashboards salvos | `/var/lib/grafana` |
| `grafana-config` | `datasources.yaml` (Tempo) | `/etc/grafana/provisioning/datasources:ro` |

## Referências

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Tempo Datasource](https://grafana.com/docs/grafana/latest/datasources/tempo/)
- [TraceQL](https://grafana.com/docs/tempo/latest/traceql/)
- [Apple Container](https://github.com/apple/container)
