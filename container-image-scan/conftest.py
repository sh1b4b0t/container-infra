# conftest.py
import sys
import os

# Adiciona src/ ao sys.path para que imports bare (from scanner import ...)
# funcionem quando tests importam src.server, src.scanner, src.vlm
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))

import pytest

# Pre-import src.server so that @patch("src.server.*") decorators can resolve
# the module at decoration time (before test body runs).
import src.server  # noqa: F401


@pytest.fixture(autouse=True)
def clear_sam3_cache():
    """Limpa o cache global do predictor SAM-3 entre testes."""
    import src.scanner as scanner_mod
    scanner_mod._predictor_cache.clear()
    yield
    scanner_mod._predictor_cache.clear()
