# syntax=docker/dockerfile:1
# Image de l'API de démonstration — durcie pour passer hadolint et Trivy.
FROM python:3.13-slim

# Bonnes pratiques d'exécution Python en conteneur.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dépendances d'abord (cache de couche), versions épinglées (cf. requirements.txt).
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Code applicatif.
COPY app.py ./

# Utilisateur non-root dédié.
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8080

# Sonde de santé intégrée à l'image.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:8080/healthz').status==200 else sys.exit(1)"

# Serveur WSGI de production.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
