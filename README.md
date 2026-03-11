# Container Infra

Infraestrutura de containers Apple Container para desenvolvimento local.

## O que é este projeto?

Repositório centralizado para gerenciar containers de desenvolvimento usando [Apple Container](https://github.com/apple/container) no macOS.

## Estrutura

```
container-infra/
├── .claude/
│   └── skills/
│       └── apple-container-infra/
│           └── SKILL.md          # Skill para Claude Code
├── container-postgres/           # PostgreSQL 17
├── container-redis/              # Redis 7
├── container-litellm/            # LiteLLM Proxy
└── container-{service}/          # Futuros containers
```

## Containers Disponíveis

| Container | Serviço | Porta | Status |
|-----------|---------|-------|--------|
| container-postgres | PostgreSQL 17 | 5432 | A migrar |
| container-redis | Redis 7 | 6379 | A migrar |
| container-litellm | LiteLLM Proxy | 4000 | A migrar |

## Requisitos

- macOS 26 (Tahoe) com Apple Silicon
- [Apple Container](https://github.com/apple/container) instalado

## Criando Novos Containers

Use a skill `apple-container-infra` no Claude Code:

```
Crie container-qdrant seguindo a skill apple-container-infra
```

## Padrões do Projeto

Todos os containers seguem:

- **Secrets externos** via `.env` (nunca no script)
- **Config montado como volume** (read-only)
- **Volumes separados** para data e config
- **Imagens com versão específica** (não `:latest`)
- **Gateway IP** `192.168.64.1` para comunicação entre containers

## Auditoria

Para verificar se um container segue os padrões:

```
Audite o container-postgres seguindo a skill apple-container-infra
```

## Referências

- [Apple Container](https://github.com/apple/container)
- [Apple Container Issue #333](https://github.com/apple/container/issues/333) - Volume mounting issue