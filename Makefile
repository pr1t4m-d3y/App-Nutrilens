.PHONY: backend-install backend-lint backend-test backend-run flutter-get flutter-analyze flutter-test eval-local eval-cloud eval-safety eval-report export-additives size

backend-install:
	cd backend && python -m pip install -r requirements-dev.txt

backend-lint:
	cd backend && ruff check . && cd ../evals && ruff check --config ../backend/ruff.toml .

backend-test:
	cd backend && python -m pytest
	python -m pytest evals/tests

backend-run:
	cd backend && gunicorn --bind 127.0.0.1:8080 --threads 8 'nutrilens_api.app:create_app()'

flutter-get:
	flutter pub get

flutter-analyze:
	flutter analyze

flutter-test:
	flutter test

# Evals (need labels in evals/labels; see evals/README.md).
eval-local:
	flutter test test/eval

eval-cloud:
	python evals/run_cloud.py

eval-safety:
	python evals/run_safety.py

eval-report:
	python evals/report.py

# Export data/additives.csv to the app asset (needs data/regulations/manifest.json).
export-additives:
	cd backend && python -m nutrilens_api.rag.export_additives --csv ../data/additives.csv --manifest ../data/regulations/manifest.json --out ../assets/additives/additives.json

# Usage: make size LABEL=baseline
size:
	bash scripts/app_size.sh --label "$(LABEL)"
