# container-postgres

PostgreSQL 17 para desenvolvimento local usando Apple containers.

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Instalação

```bash
# Clone o repositório
git clone https://github.com/morphew-ai/container-infra.git
cd container-infra/container-postgres

# Configure o ambiente
cp .env.example .env
# Edite .env com suas credenciais

# Torne o script executável
chmod +x postgres-dev.sh
```

## Uso

```bash
# Iniciar PostgreSQL
./postgres-dev.sh start

# Verificar status
./postgres-dev.sh status

# Conectar ao banco
./postgres-dev.sh shell
```

### Strings de Conexão

| Contexto | String |
|----------|--------|
| Localhost | `postgresql://postgres:postgres@localhost:5432/postgres` |
| Inter-container | `postgresql://postgres:postgres@192.168.65.1:5432/postgres` |

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container PostgreSQL |
| `stop` | Para o container |
| `status` | Mostra status do container |
| `logs` | Exibe logs do PostgreSQL |
| `shell` | Abre psql no container |
| `reset` | Remove container e volume (apaga todos os dados) |
| `backup <file>` | Exporta dados para arquivo SQL |
| `restore <file>` | Restaura dados de arquivo SQL |
| `add-service <name>` | Cria usuário e banco para um serviço |
| `list-services` | Lista todos os bancos e usuários |

## Gerenciamento de Serviços

### Criar novo serviço

Cria automaticamente usuário, senha e banco de dados para um novo serviço:

```bash
./postgres-dev.sh add-service litellm
```

Output:
```
Criando serviço 'litellm'...

  Usuário: litellm
  Senha:   7Efb6untSBiXHpVn
  Banco:   litellm

✅ Serviço 'litellm' criado com sucesso!

Strings de conexão:
  Localhost:       postgresql://litellm:7Efb6untSBiXHpVn@localhost:5432/litellm
  Inter-container: postgresql://litellm:7Efb6untSBiXHpVn@192.168.65.1:5432/litellm

💡 Adicione ao seu .env:
   LITELLM_DATABASE_URL=postgresql://litellm:7Efb6untSBiXHpVn@192.168.65.1:5432/litellm
```

### Listar serviços

```bash
./postgres-dev.sh list-services
```

## Configuração

Edite o arquivo `.env` para configurar credenciais:

```bash
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
```

## Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                    macOS Host                        │
│                                                      │
│  ┌──────────────────┐    ┌───────────────────────┐  │
│  │ postgres-dev.sh  │    │   Apple Container     │  │
│  │ (script)         │────│   Runtime             │  │
│  └──────────────────┘    └──────────┬────────────┘  │
│                                     │                │
│                          ┌──────────▼──────────┐     │
│                          │  Container          │     │
│                          │  "postgres-dev"     │     │
│                          │                     │     │
│                          │  PostgreSQL 17      │     │
│                          │  Porta: 5432        │     │
│                          └──────────┬──────────┘     │
│                                     │                │
│                          ┌──────────▼──────────┐     │
│                          │  Volume Nomeado     │     │
│                          │  "postgres-data"    │     │
│                          └─────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

### Componentes

| Componente | Descrição |
|------------|-----------|
| Container `postgres-dev` | Imagem `postgres:17-alpine`, porta 5432 |
| Volume `postgres-data` | Persistência de dados em `/var/lib/postgresql` |
| Gateway IP `192.168.65.1` | Comunicação entre containers |

## Fluxo de Trabalho

### Setup Inicial

```bash
cp .env.example .env
./postgres-dev.sh start
./postgres-dev.sh status
```

### Uso Diário

```bash
./postgres-dev.sh start
# trabalhar...
./postgres-dev.sh stop  # opcional
```

### Backup

```bash
./postgres-dev.sh backup backup_$(date +%Y%m%d).sql
```

### Reset

```bash
./postgres-dev.sh reset
```

## Volumes

Dois volumes gerenciados pelo Apple container:

- `postgres-data` — arquivos de dados do PostgreSQL (`/var/lib/postgresql`)
- `postgres-config` — configuração customizada (`postgresql.conf`) em `/etc/postgresql/conf.d`

Para alterar configurações do PostgreSQL, edite `postgresql.conf` antes de iniciar (ou após `reset`).

## Nota Técnica

O Apple container usa virtiofs para volumes. O PostgreSQL não pode inicializar diretamente em `/var/lib/postgresql/data` devido ao diretório `lost+found` presente nos volumes nomeados. A solução é montar em `/var/lib/postgresql` e deixar o PostgreSQL criar o subdiretório `data/`.

Ver [issue #333](https://github.com/apple/container/issues/333) para mais detalhes.

## Referências

- [Apple Container](https://github.com/apple/container)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)