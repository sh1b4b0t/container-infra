import base64
import io
import logging

import numpy as np
from PIL import Image

# Import module-level para que @patch("src.scanner.SAM3SemanticPredictor") funcione nos testes.
# try/except permite rodar sem ultralytics instalado (fallback VLM assume o papel).
try:
    from ultralytics.models.sam import SAM3SemanticPredictor
except ImportError:
    SAM3SemanticPredictor = None  # type: ignore

_predictor_cache: dict = {}  # model_path -> SAM3SemanticPredictor instance


def _get_predictor(model_path: str):
    """Instancia e cacheia o SAM3SemanticPredictor por model_path."""
    if SAM3SemanticPredictor is None:
        raise RuntimeError("ultralytics não instalado — pip install ultralytics")
    if model_path not in _predictor_cache:
        overrides = dict(
            conf=0.25,
            task="segment",
            mode="predict",
            model=model_path,
            verbose=False,
        )
        predictor = SAM3SemanticPredictor(overrides=overrides)
        _predictor_cache[model_path] = predictor
        logging.info("SAM-3 predictor carregado de %s", model_path)
    return _predictor_cache[model_path]


def _b64_to_numpy(image_b64: str) -> np.ndarray:
    """Decodifica base64 → numpy array RGB para o SAM-3."""
    image_bytes = base64.b64decode(image_b64)
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    return np.array(img)


def check_concept_sam3(image_b64: str, concept: str, model_path: str) -> bool:
    """
    Retorna True se SAM-3 detectar o conceito na imagem.
    Lança exceção se o modelo não estiver disponível ou SAM-3 falhar.
    """
    predictor = _get_predictor(model_path)
    image_np = _b64_to_numpy(image_b64)
    predictor.set_image(image_np)
    results = predictor(text=[concept])

    if not results:
        return False
    result = results[0]
    return result.masks is not None and len(result.masks) > 0
