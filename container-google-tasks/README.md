# container-google-tasks

Servidor MCP para interação com Google Tasks API, executado via Apple Container.

Construído com [FastMCP 3.0](https://github.com/jlowin/fastmcp) e [Google Tasks API v1](https://developers.google.com/tasks).

## Pré-requisitos

- Apple Container instalado
- Projeto no Google Cloud com a **Tasks API** habilitada
- Credenciais OAuth2 do tipo **"App para computador"**

## Configuração inicial

### 1. Credenciais Google

1. Acesse [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Crie credenciais OAuth2 → "App para computador"
3. Copie o **Client ID** e **Client Secret**

### 2. Arquivo .env

```bash
cp .env.example .env
# Edite .env com suas credenciais
```

### 3. Construir a imagem

```bash
./google-tasks-dev.sh build
```

### 4. Autenticar com Google

```bash
./google-tasks-dev.sh auth
# Copie a URL exibida, abra no navegador e autorize o acesso
```

### 5. Iniciar o servidor

```bash
./google-tasks-dev.sh start
```

## Uso

```bash
./google-tasks-dev.sh start    # Inicia o servidor
./google-tasks-dev.sh stop     # Para o servidor
./google-tasks-dev.sh status   # Status e volumes
./google-tasks-dev.sh logs     # Logs em tempo real
./google-tasks-dev.sh test     # Testa o endpoint MCP
./google-tasks-dev.sh auth     # Re-autentica com o Google
./google-tasks-dev.sh build    # Reconstrói a imagem
./google-tasks-dev.sh reset    # Remove tudo (incluindo token)
```

## Endpoint MCP

```
http://localhost:8080/mcp
```

### Configuração no Claude Desktop

```json
{
  "mcpServers": {
    "google-tasks": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

## Ferramentas disponíveis

| Ferramenta | Descrição |
|-----------|-----------|
| `list_task_lists` | Lista todas as listas de tarefas |
| `create_task_list` | Cria uma nova lista |
| `delete_task_list` | Remove uma lista |
| `list_tasks` | Lista tarefas de uma lista |
| `get_task` | Obtém detalhes de uma tarefa |
| `create_task` | Cria uma nova tarefa |
| `update_task` | Atualiza título, notas, data ou status |
| `delete_task` | Remove uma tarefa |
| `complete_task` | Marca uma tarefa como concluída |
| `clear_completed_tasks` | Remove todas as tarefas concluídas |
| `move_task` | Move uma tarefa (posição ou hierarquia) |

## Volumes

| Volume | Conteúdo |
|--------|----------|
| `google-tasks-data` | Token OAuth2 (`token.json`) |
| `google-tasks-config` | Arquivo de configuração (`config.yaml`) |

## Porta

| Porta | Uso |
|-------|-----|
| `8080` | Servidor MCP HTTP |
| `8090` | Callback OAuth2 (apenas durante `auth`) |
