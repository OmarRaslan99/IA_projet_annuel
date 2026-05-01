# OHazard — Plateforme de prédiction Coupe du Monde

Jeu de prédiction des scores de matchs où les utilisateurs s'affrontent contre un modèle IA.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS (eu-west-3)                        │
│                                                                 │
│  CloudFront → S3 (frontend Vue.js)                              │
│  API Gateway HTTP                                               │
│    ├── ANY /{proxy+}  → Lambda backend (Node.js)               │
│    └── POST /ai/predict → Lambda AI (Python, Docker/ECR)       │
│                                                                 │
│  DynamoDB : users | groups | predictions                        │
│  Aurora Serverless v2 PostgreSQL                                │
│  S3 : bronze | silver | models                                  │
│  ECR : ohazard-ai-lambda                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Partie IA — `ai/`

### Structure

```
ai/
├── src/
│   ├── data/
│   │   ├── download.py       # Téléchargement Kaggle (bronze)
│   │   └── prepare.py        # Feature engineering (bronze → silver)
│   ├── models/
│   │   ├── outcome_model.py  # Modèle 1 : XGBoost probas home/draw/away
│   │   └── score_model.py    # Modèle 2 : Poisson buts home/away
│   └── inference/
│       └── predict.py        # Inférence locale (CLI)
├── lambda/
│   ├── handler.py            # Entrypoint Lambda AWS
│   ├── requirements.txt      # Deps Lambda uniquement
│   └── Dockerfile            # Image Python 3.11 pour ECR
├── scripts/
│   ├── upload_data.py        # Upload bronze/silver → S3
│   └── upload_models.py      # Upload .pkl → S3 models
├── notebooks/                # EDA et validation features
├── Makefile                  # Toutes les commandes locales
├── requirements.txt          # Deps complètes (training)
└── .env.example              # Variables d'environnement requises
```

### Modèles

| Modèle | Algorithme | Output | Métrique |
|--------|-----------|--------|----------|
| Outcome | XGBoost multi-classe + calibration isotonique | `{home: 67%, draw: 12%, away: 21%}` | Log-loss |
| Score | Poisson Regressor × 2 (fallback XGBoost) | `{home: 2, away: 1}` | MAE |

**Features utilisées :** ranking FIFA (home/away/diff), stats glissantes 10 derniers matchs (win rate, draw rate, buts marqués/encaissés), historique face-à-face (5 derniers), poids du tournoi.

**Split temporel :** entraînement < 2022, test = matchs 2022–2026.

### Setup local

```bash
cd ai

# 1. Copier et remplir les variables d'environnement
cp .env.example .env
# Remplir KAGGLE_USERNAME, KAGGLE_KEY, S3_*_BUCKET, AWS_REGION

# 2. Installer les dépendances Python
pip install -r requirements.txt

# 3. Pipeline complet
make download    # Télécharge les 2 datasets Kaggle → data/bronze/
make prepare     # Feature engineering → data/silver/matches_features.parquet
make train       # Entraîne les 2 modèles → models/*.pkl

# 4. Tester l'inférence en local
make predict HOME="France" AWAY="Germany" TOURNAMENT="FIFA World Cup"

# 5. Test Lambda local (Docker requis)
make docker-build
make docker-run
make docker-test   # dans un autre terminal
```

### Déploiement AWS

```bash
# 1. Déployer l'infrastructure (sans Lambda AI d'abord)
cd terraform
terraform init
terraform apply

# 2. Récupérer l'URL ECR depuis les outputs
terraform output ecr_repository_url

# 3. Builder et pousser l'image Docker
cd ../ai
make ecr-push ECR_URI=<ecr_repository_url>

# 4. Uploader les modèles entraînés
make upload-models

# 5. Redéployer Terraform avec l'URI de l'image
# Dans terraform/terraform.tfvars, ajouter :
# ai_lambda_image_uri = "<ecr_repository_url>:latest"
cd ../terraform
terraform apply

# 6. Tester l'endpoint AI
curl -X POST $(terraform output -raw ai_predict_url) \
  -H "Content-Type: application/json" \
  -d '{"home": "France", "away": "Germany", "tournament": "FIFA World Cup"}'
```

## Partie Web — `terraform/`

### Ressources déployées

| Fichier | Ressources |
|---------|-----------|
| `s3_cloudfront.tf` | Bucket frontend + CloudFront CDN |
| `lambda_api.tf` | Lambda backend Node.js + API Gateway HTTP |
| `rds.tf` | Aurora Serverless v2 PostgreSQL |
| `dynamodb.tf` | Tables `users` et `groups` |
| `iam.tf` | Groupe OHazard + rôles Lambda |
| `s3_ai.tf` | Buckets bronze / silver / models |
| `ecr.tf` | Repo ECR pour Lambda AI |
| `lambda_ai.tf` | Lambda AI (Docker) + route `/ai/predict` |
| `dynamodb_ai.tf` | Table `predictions` |
| `sagemaker.tf` | Rôle IAM SageMaker (Training Jobs) |

### Variables requises

```hcl
# terraform/terraform.tfvars
aws_region   = "eu-west-3"
project_name = "ohazard"
environment  = "dev"
db_name      = "ohazarddb"
db_username  = "ohazardadmin"
db_password  = "..."
lambda_zip_path    = "build/lambda_placeholder.zip"
ai_lambda_image_uri = ""  # remplir après docker push
```

### Commandes Terraform

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
terraform output   # voir toutes les URLs et ARNs
```
