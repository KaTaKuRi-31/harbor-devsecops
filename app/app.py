"""Petite API de démonstration poussée dans le pipeline DevSecOps.

Sert de charge utile aux étapes SAST (Semgrep), CVE (Trivy), DAST (ZAP)
et signature (Cosign) avant publication dans le registre Harbor.
"""
from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/")
def index():
    """Point d'entrée : identité du service."""
    return jsonify(service="harbor-demo-app", status="ok")


@app.get("/healthz")
def healthz():
    """Sonde de vivacité utilisée par le HEALTHCHECK et Kubernetes."""
    return jsonify(status="healthy")


@app.get("/api/echo")
def echo():
    """Renvoie le message fourni (validé) — surface de test pour le DAST."""
    message = request.args.get("msg", default="", type=str)
    return jsonify(echo=message[:256])


if __name__ == "__main__":
    # Exécution locale uniquement ; en conteneur, gunicorn prend le relais.
    app.run(host="127.0.0.1", port=8080)
