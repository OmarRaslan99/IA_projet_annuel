# Image de base AWS Lambda Python 3.11 (compatible Lambda Runtime Interface)
FROM public.ecr.aws/lambda/python:3.11

# Copier les dépendances et les installer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le handler
COPY handler.py ${LAMBDA_TASK_ROOT}/

# Entrypoint Lambda
CMD ["handler.handler"]
