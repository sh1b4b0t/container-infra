import logging
import os

from fastmcp import FastMCP

from scanner import check_concept_sam3
from vlm import check_concept_vlm

logging.basicConfig(level=logging.INFO)

mcp = FastMCP("Image Scan")

_SAM3_MODEL_PATH = os.environ.get("SAM3_MODEL_PATH", "/models/sam3.pt")
_LITELLM_URL = os.environ.get("LITELLM_URL", "http://192.168.65.1:4000")
_LITELLM_API_KEY = os.environ.get("LITELLM_API_KEY", "local")
_LITELLM_MODEL = os.environ.get("LITELLM_MODEL", "lmstudio")


@mcp.tool
def check_image(image_base64: str, concept: str) -> dict:
    """
    Verifica se uma imagem contém o conceito especificado.

    Exemplos de conceito: "watermark", "logo", "text overlay",
    "copyright notice", "exposed skin", "nudity".

    Usa SAM-3 (Meta) como abordagem primária.
    Se o SAM-3 não estiver disponível, usa LiteLLM VLM como fallback.

    Args:
        image_base64: Imagem codificada em base64 (JPEG, PNG, etc.)
        concept: Conceito visual a detectar (linguagem natural)

    Returns:
        dict com 'found' (bool), 'method' ('sam3'|'vlm'|'error'),
        'concept' (str), e 'error' (str) em caso de falha total.
    """
    try:
        found = check_concept_sam3(image_b64=image_base64, concept=concept, model_path=_SAM3_MODEL_PATH)
        logging.info("sam3: found=%s concept=%r", found, concept)
        return {"found": found, "method": "sam3", "concept": concept}
    except Exception as e:
        logging.warning("SAM-3 falhou: %s — usando VLM como fallback", e)

    try:
        found = check_concept_vlm(
            image_b64=image_base64,
            concept=concept,
            api_base=_LITELLM_URL,
            api_key=_LITELLM_API_KEY,
            model=_LITELLM_MODEL,
        )
        logging.info("vlm: found=%s concept=%r", found, concept)
        return {"found": found, "method": "vlm", "concept": concept}
    except Exception as e:
        logging.error("VLM também falhou: %s", e)
        return {"found": False, "method": "error", "concept": concept, "error": str(e)}


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8081))
    mcp.run(transport="http", host="0.0.0.0", port=port)
