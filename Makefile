.PHONY: install lint format test eval db-up db-down

install:
	uv sync

lint:
	uv run ruff check .
	uv run ruff format --check .

format:
	uv run ruff format .
	uv run ruff check --fix .

test:
	uv run pytest

# Placeholder until the eval harness lands; will run the golden set in evals/golden/.
eval:
	@echo "No eval harness yet — golden set lives in evals/golden/."

db-up:
	docker compose up -d --wait

db-down:
	docker compose down
