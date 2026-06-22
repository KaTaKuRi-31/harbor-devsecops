"""Exporter Prometheus des vulnérabilités (CVE) détectées par Harbor.

Les métriques natives de Harbor couvrent le registre (projets, dépôts, quotas)
mais pas le détail des CVE par sévérité. Cet exporter interroge l'API Harbor
(scan_overview de chaque artefact) et expose, au format Prometheus :

  harbor_image_vulnerabilities{project,repository,tag,severity}  (gauge)
  harbor_image_fixable_vulnerabilities{project,repository,tag}   (gauge)
  harbor_artifacts_scanned_total                                 (gauge)
  harbor_cve_exporter_up                                         (gauge)

Configuration par variables d'environnement :
  HARBOR_URL       (def. http://harbor:80)
  HARBOR_USER      (def. admin)
  HARBOR_PASSWORD  (def. Harbor12345)
  SCRAPE_INTERVAL  (def. 30 secondes)
  EXPORTER_PORT    (def. 9099)
"""
import os
import time
import logging

import requests
from prometheus_client import start_http_server, Gauge, REGISTRY

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

HARBOR_URL = os.environ.get("HARBOR_URL", "http://harbor:80").rstrip("/")
HARBOR_USER = os.environ.get("HARBOR_USER", "admin")
HARBOR_PASSWORD = os.environ.get("HARBOR_PASSWORD", "Harbor12345")
SCRAPE_INTERVAL = int(os.environ.get("SCRAPE_INTERVAL", "30"))
EXPORTER_PORT = int(os.environ.get("EXPORTER_PORT", "9099"))

SEVERITIES = ["Critical", "High", "Medium", "Low", "None", "Unknown"]

VULN = Gauge(
    "harbor_image_vulnerabilities",
    "Nombre de vulnérabilités par sévérité pour l'artefact scanné le plus récent.",
    ["project", "repository", "tag", "severity"],
)
FIXABLE = Gauge(
    "harbor_image_fixable_vulnerabilities",
    "Nombre de vulnérabilités corrigeables (fixable) pour l'artefact.",
    ["project", "repository", "tag"],
)
SCANNED = Gauge(
    "harbor_artifacts_scanned_total",
    "Nombre total d'artefacts pour lesquels un rapport de scan est disponible.",
)
UP = Gauge("harbor_cve_exporter_up", "1 si la dernière collecte a réussi, 0 sinon.")

SESSION = requests.Session()
SESSION.auth = (HARBOR_USER, HARBOR_PASSWORD)


def api(path, params=None):
    resp = SESSION.get(f"{HARBOR_URL}/api/v2.0{path}", params=params, timeout=15)
    resp.raise_for_status()
    return resp.json()


def collect():
    VULN.clear()
    FIXABLE.clear()
    scanned = 0
    for project in api("/projects", {"page_size": 100}):
        pname = project["name"]
        repos = api(f"/projects/{pname}/repositories", {"page_size": 100})
        for repo in repos:
            # Nom court du dépôt (sans le préfixe "projet/").
            full = repo["name"]
            short = full.split("/", 1)[1] if "/" in full else full
            artifacts = api(
                f"/projects/{pname}/repositories/{short}/artifacts",
                {"with_scan_overview": "true", "page_size": 50},
            )
            for art in artifacts:
                overview = art.get("scan_overview") or {}
                if not overview:
                    continue
                report = next(iter(overview.values()), {})
                summary = (report.get("summary") or {}).get("summary") or {}
                tags = art.get("tags") or []
                tag = tags[0]["name"] if tags else art.get("digest", "")[:12]
                for sev in SEVERITIES:
                    VULN.labels(pname, short, tag, sev).set(summary.get(sev, 0))
                fixable = (report.get("summary") or {}).get("fixable", 0)
                FIXABLE.labels(pname, short, tag).set(fixable)
                scanned += 1
    SCANNED.set(scanned)


def main():
    start_http_server(EXPORTER_PORT)
    logging.info("Harbor CVE exporter en écoute sur :%s (cible %s)", EXPORTER_PORT, HARBOR_URL)
    while True:
        try:
            collect()
            UP.set(1)
            logging.info("Collecte OK")
        except Exception as exc:  # noqa: BLE001 - on veut rester vivant quoi qu'il arrive
            UP.set(0)
            logging.warning("Échec de collecte : %s", exc)
        time.sleep(SCRAPE_INTERVAL)


if __name__ == "__main__":
    main()
