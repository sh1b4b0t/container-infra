# container-image-scan

MCP server que verifica se uma imagem contém um conceito visual especificado em linguagem natural.

**Tool exposta:** `check_image(image_base64, concept) → {found, method, concept}`

Usa **SAM-3** (Meta, via ultralytics) como abordagem primária. Se SAM-3 falhar (modelo ausente, erro de inferência), cai automaticamente para **LiteLLM VLM** (qualquer modelo multimodal no gateway LiteLLM).

## Requisitos

- Apple Container instalado
- Model weights SAM-3 (`src/sam3.pt`, ~3.4 GB) — ver seção "Model weights" abaixo
- LiteLLM rodando em `../container-litellm` (opcional — fallback VLM)

## Setup

```bash
# 1. Configurar variáveis de ambiente
cp .env.example .env
# editar LITELLM_API_KEY se necessário

# 2. Build da imagem Docker
./image-scan-dev.sh build

# 3. Instalar model weights no volume (uma vez, ~3.4 GB)
./image-scan-dev.sh install-model

# 4. Iniciar
./image-scan-dev.sh start
```

## Comandos

```bash
./image-scan-dev.sh <comando>
```

| Comando | Descrição |
|---------|-----------|
| `start` | Inicia o container (verifica imagem e volume) |
| `stop` | Para o container |
| `status` | Mostra status do container, volume e imagem |
| `logs` | Segue os logs em tempo real |
| `shell` | Shell interativo dentro do container |
| `build` | Build da imagem Docker local |
| `install-model` | Copia `src/sam3.pt` para o volume de modelos |
| `reset` | Remove container e volume de modelos ⚠️ |

## MCP Endpoint

```
http://localhost:8081/mcp
```

## Volume

| Volume | Conteúdo | Como popular |
|--------|----------|--------------|
| `image-scan-models` | `sam3.pt` (~3.4 GB) | `./image-scan-dev.sh install-model` |

## Model weights

O SAM-3 não é distribuído automaticamente. Para obter `src/sam3.pt`:

```bash
# Via ultralytics (recomendado — faz download do modelo correto):
uv run python -c "from ultralytics import SAM; SAM('sam2.1_l.pt')"
# O arquivo baixado fica em ~/.cache/ultralytics/ — copiar para src/sam3.pt

# Ou baixar manualmente em: https://docs.ultralytics.com/pt/models/sam-3/
```

Após ter o arquivo em `src/sam3.pt`, execute `install-model` para copiá-lo ao volume.

## Conceitos suportados

Qualquer texto em linguagem natural funciona. O `config.yaml` documenta categorias pré-configuradas para uso pelos callers:

- `watermark` — marcas d'água, overlays de texto, copyright
- `logo` — logos e ícones de marca
- `body_parts` — nudez e pele exposta

## Desenvolvimento local

```bash
# Instalar dependências
uv sync --dev

# Rodar testes
uv run pytest -v

# Rodar servidor sem container (requer sam3.pt em src/)
SAM3_MODEL_PATH=src/sam3.pt uv run python src/server.py
```
