import base64
from unittest.mock import MagicMock, patch

import pytest

from src.scanner import check_concept_sam3

FAKE_B64 = base64.b64encode(b"fake-image-bytes").decode()


def _mock_predictor_with_detections(n_detections: int):
    result = MagicMock()
    if n_detections > 0:
        masks = MagicMock()
        masks.__len__ = lambda s: n_detections
        result.masks = masks
    else:
        result.masks = None
    return [result]


@patch("src.scanner.SAM3SemanticPredictor")
@patch("src.scanner.Image")
def test_sam3_found_when_masks_present(mock_image, mock_predictor_class):
    predictor_instance = MagicMock()
    mock_predictor_class.return_value = predictor_instance
    predictor_instance.return_value = _mock_predictor_with_detections(2)

    result = check_concept_sam3(
        image_b64=FAKE_B64,
        concept="watermark",
        model_path="/fake/sam3.pt",
    )

    assert result is True
    predictor_instance.assert_called_once_with(text=["watermark"])


@patch("src.scanner.SAM3SemanticPredictor")
@patch("src.scanner.Image")
def test_sam3_not_found_when_no_masks(mock_image, mock_predictor_class):
    predictor_instance = MagicMock()
    mock_predictor_class.return_value = predictor_instance
    predictor_instance.return_value = _mock_predictor_with_detections(0)

    result = check_concept_sam3(
        image_b64=FAKE_B64,
        concept="logo",
        model_path="/fake/sam3.pt",
    )

    assert result is False


@patch("src.scanner.SAM3SemanticPredictor")
@patch("src.scanner.Image")
def test_sam3_reuses_predictor_for_same_model(mock_image, mock_predictor_class):
    predictor_instance = MagicMock()
    mock_predictor_class.return_value = predictor_instance
    predictor_instance.return_value = _mock_predictor_with_detections(1)

    check_concept_sam3(FAKE_B64, "watermark", "/fake/sam3.pt")
    check_concept_sam3(FAKE_B64, "logo", "/fake/sam3.pt")

    # SAM3SemanticPredictor só deve ser instanciado uma vez (cache)
    assert mock_predictor_class.call_count == 1
