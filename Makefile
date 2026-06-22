.PHONY: setup test lint fmt eval ingest
setup:
	uv sync

test:
	uv run pytest -q

lint:
	uv run ruff check .
	uv run ruff format --check .

fmt:
	uv run ruff format .

eval:
	@echo "TODO(M3): wire src/evals/run.py to write results/<run-id>/"
	uv run python -m src.evals.run

ingest:
	@echo "TODO(M1): wire src/ingest/run.py"
	uv run python -m src.ingest.run
