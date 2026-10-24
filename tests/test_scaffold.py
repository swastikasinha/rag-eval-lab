import importlib

import pytest


@pytest.mark.parametrize("package", ["ingest", "retrieve", "generate", "api"])
def test_stage_packages_import(package: str) -> None:
    assert importlib.import_module(package) is not None
