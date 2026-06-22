import sys


def test_python_version():
    assert sys.version_info >= (3, 12)


def test_package_imports():
    import src.agent  # noqa: F401
    import src.drift  # noqa: F401
    import src.evals  # noqa: F401
    import src.ingest  # noqa: F401
    import src.retrieval  # noqa: F401
    import src.serve  # noqa: F401
