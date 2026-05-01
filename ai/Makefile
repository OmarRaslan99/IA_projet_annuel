.PHONY: download prepare train predict upload docker-build docker-run

# Load .env if present
ifneq (,$(wildcard .env))
	include .env
	export
endif

DATA_BRONZE := data/bronze
DATA_SILVER := data/silver
MODELS_DIR  := models

# ── Data ──────────────────────────────────────────────────────────────────────

download:
	@echo "==> Downloading datasets from Kaggle..."
	python src/data/download.py

prepare:
	@echo "==> Preparing features (bronze → silver)..."
	python src/data/prepare.py

# ── Training ──────────────────────────────────────────────────────────────────

train: train-outcome train-score

train-outcome:
	@echo "==> Training Outcome model (XGBoost)..."
	python src/models/outcome_model.py

train-score:
	@echo "==> Training Score model (Poisson Regressor)..."
	python src/models/score_model.py

# ── Inference (local) ─────────────────────────────────────────────────────────
# Usage: make predict HOME="France" AWAY="Germany" TOURNAMENT="FIFA World Cup"

predict:
	python src/inference/predict.py \
		--home "$(HOME)" \
		--away "$(AWAY)" \
		--tournament "$(TOURNAMENT)"

# ── Upload to S3 ──────────────────────────────────────────────────────────────

upload-data:
	@echo "==> Uploading bronze/silver data to S3..."
	python scripts/upload_data.py

upload-models:
	@echo "==> Uploading trained models to S3..."
	python scripts/upload_models.py

upload: upload-data upload-models

# ── Docker (Lambda local test) ────────────────────────────────────────────────

IMAGE_NAME := ohazard-ai-lambda

docker-build:
	@echo "==> Building Lambda Docker image..."
	docker build -t $(IMAGE_NAME):latest lambda/

docker-run:
	@echo "==> Running Lambda locally on port 9000..."
	docker run --rm -p 9000:8080 \
		-e MODELS_BUCKET=$(S3_MODELS_BUCKET) \
		-e OUTCOME_MODEL_KEY=outcome_model.pkl \
		-e SCORE_HOME_MODEL_KEY=score_home_model.pkl \
		-e SCORE_AWAY_MODEL_KEY=score_away_model.pkl \
		-e AWS_REGION=$(AWS_REGION) \
		-v ~/.aws:/root/.aws:ro \
		$(IMAGE_NAME):latest

docker-test:
	@echo "==> Sending test prediction request..."
	curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
		-H "Content-Type: application/json" \
		-d '{"home": "France", "away": "Germany", "tournament": "FIFA World Cup"}'

# ── ECR Push ──────────────────────────────────────────────────────────────────
# Usage: make ecr-push ECR_URI=123456789.dkr.ecr.eu-west-3.amazonaws.com/ohazard-ai-lambda

ecr-push:
	@echo "==> Pushing image to ECR: $(ECR_URI)..."
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_URI)
	docker tag $(IMAGE_NAME):latest $(ECR_URI):latest
	docker push $(ECR_URI):latest

# ── All ───────────────────────────────────────────────────────────────────────

all: download prepare train upload

clean:
	rm -rf $(DATA_BRONZE)/* $(DATA_SILVER)/* $(MODELS_DIR)/*.pkl
