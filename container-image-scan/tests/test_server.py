import base64
from unittest.mock import patch

FAKE_B64 = base64.b64encode(b"fake-image").decode()


@patch("src.server.check_concept_vlm")
@patch("src.server.check_concept_sam3")
def test_check_image_uses_sam3_first(mock_sam3, mock_vlm):
    mock_sam3.return_value = True
    from src.server import check_image
    result = check_image(image_base64=FAKE_B64, concept="watermark")
    assert result["found"] is True
    assert result["method"] == "sam3"
    mock_vlm.assert_not_called()


@patch("src.server.check_concept_vlm")
@patch("src.server.check_concept_sam3")
def test_check_image_falls_back_to_vlm_on_sam3_error(mock_sam3, mock_vlm):
    mock_sam3.side_effect = RuntimeError("model not found")
    mock_vlm.return_value = True
    from src.server import check_image
    result = check_image(image_base64=FAKE_B64, concept="watermark")
    assert result["found"] is True
    assert result["method"] == "vlm"
    mock_vlm.assert_called_once()


@patch("src.server.check_concept_vlm")
@patch("src.server.check_concept_sam3")
def test_check_image_returns_error_when_both_fail(mock_sam3, mock_vlm):
    mock_sam3.side_effect = RuntimeError("sam3 error")
    mock_vlm.side_effect = RuntimeError("vlm error")
    from src.server import check_image
    result = check_image(image_base64=FAKE_B64, concept="logo")
    assert result["found"] is False
    assert result["method"] == "error"
    assert "error" in result


@patch("src.server.check_concept_vlm")
@patch("src.server.check_concept_sam3")
def test_check_image_returns_concept_in_response(mock_sam3, mock_vlm):
    mock_sam3.return_value = False
    from src.server import check_image
    result = check_image(image_base64=FAKE_B64, concept="logo")
    assert result["concept"] == "logo"
