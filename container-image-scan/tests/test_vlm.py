import base64
from unittest.mock import MagicMock, patch

import pytest

from src.vlm import check_concept_vlm

FAKE_B64 = base64.b64encode(b"fake-image-bytes").decode()


def _mock_litellm_response(answer: str):
    msg = MagicMock()
    msg.content = answer
    choice = MagicMock()
    choice.message = msg
    resp = MagicMock()
    resp.choices = [choice]
    return resp


@patch("src.vlm.litellm.completion")
def test_vlm_returns_true_on_yes(mock_completion):
    mock_completion.return_value = _mock_litellm_response("YES")
    result = check_concept_vlm(
        image_b64=FAKE_B64,
        concept="watermark",
        api_base="http://localhost:4000",
        api_key="test",
        model="lmstudio",
    )
    assert result is True


@patch("src.vlm.litellm.completion")
def test_vlm_returns_false_on_no(mock_completion):
    mock_completion.return_value = _mock_litellm_response("NO")
    result = check_concept_vlm(
        image_b64=FAKE_B64,
        concept="watermark",
        api_base="http://localhost:4000",
        api_key="test",
        model="lmstudio",
    )
    assert result is False


@patch("src.vlm.litellm.completion")
def test_vlm_passes_correct_prompt(mock_completion):
    mock_completion.return_value = _mock_litellm_response("YES")
    check_concept_vlm(
        image_b64=FAKE_B64,
        concept="logo",
        api_base="http://localhost:4000",
        api_key="test",
        model="lmstudio",
    )
    call_args = mock_completion.call_args
    messages = call_args.kwargs["messages"]
    content = messages[0]["content"]
    text_block = next(b for b in content if b["type"] == "text")
    assert "logo" in text_block["text"].lower()
    image_block = next(b for b in content if b["type"] == "image_url")
    assert FAKE_B64 in image_block["image_url"]["url"]
