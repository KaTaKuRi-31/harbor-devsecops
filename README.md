# Harbor + Terraform + Pipeline CI sécurisée (DevSecOps)

Déploiement de **Harbor** (registre d'images conteneur) sur **k3s** (via **k3d**)
à l'aide de **Terraform** (provider Helm), avec une **pipeline GitHub Actions
bloquante** couvrant l'ensemble de la chaîne DevSecOps, et l'**observabilité**
des métriques Harbor dans **Prometheus / Grafana**.

## Composantes obligatoires du TP

| Domaine        | Outils mis en œuvre |
|----------------|---------------------|
| **Lint**       | hadolint (Dockerfile) · tflint · Checkov (IaC Terraform) |
| **SAST**       | Semgrep |
| **CVE**        | Trivy (bloquant, `exit-code 1`) + scanner Trivy intégré à Harbor |
| **DAST**       | OWASP ZAP baseline |
| **Signing**    | Cosign (keyless, OIDC GitHub) |
| **IaC**        | Terraform — provider Helm (Harbor) sur k3s |
| **Observabilité** | Harbor metrics → Prometheus (ServiceMonitor) → dashboard Grafana |

## Architecture

```
Développeur ──push──> GitHub ──> GitHub Actions (runners hébergés)
                                   │  lint → SAST → build → Trivy(CVE) → ZAP(DAST) → Cosign(sign) → GHCR
                                   │
                                   └─> Runner self-hosted (poste local) ──> Harbor (k3d)
                                          pull GHCR → push Harbor → scan CVE Harbor

   Poste local (Docker Desktop) :
   k3d ── k3s ──┬── Harbor (core, registry, trivy, db, redis, exporter)  ──┐
                └── kube-prometheus-stack (Prometheus + Grafana)  <─────────┘ ServiceMonitor
```

Harbor étant déployé sur un cluster **local non exposé sur Internet**, les
runners hébergés de GitHub ne peuvent pas l'atteindre. La pipeline applique donc
le modèle professionnel standard : les **contrôles sans état** (lint, SAST, CVE,
DAST, signature) s'exécutent sur les **runners hébergés**, et la **publication
vers le registre interne** s'exécute sur un **runner self-hosted** installé sur
le poste, seul capable de joindre Harbor.

## Prérequis

- Docker Desktop (WSL2), ~6 Go de RAM
- `terraform`, `kubectl`, `helm`, `k3d`, `gh`, `cosign` (installés via winget/binaire)
- Les scanners (Trivy, Semgrep, hadolint, Checkov, ZAP) tournent via images Docker

## Déploiement local

```bash
# 1. Cluster k3s local (k3d) avec NodePorts mappés (Harbor 30002, Prom 30090, Grafana 30091)
k3d cluster create harbor --servers 1 \
  --port "30002:30002@server:0" --port "30090:30090@server:0" --port "30091:30091@server:0" \
  --k3s-arg "--disable=traefik@server:0"

# 2. Déploiement IaC : Harbor + kube-prometheus-stack
cd terraform
terraform init
terraform apply -auto-approve
```

Accès :

| Service    | URL                       | Identifiants        |
|------------|---------------------------|---------------------|
| Harbor     | http://localhost:30002    | `admin` / `Harbor12345` |
| Grafana    | http://localhost:30091    | `admin` / `admin`   |
| Prometheus | http://localhost:30090    | —                   |

## Pipeline CI (`.github/workflows/ci.yml`)

| Job | Runner | Étapes | Bloquant |
|-----|--------|--------|----------|
| `lint` | hébergé | hadolint, tflint, Checkov | ✅ |
| `sast` | hébergé | Semgrep (`p/default`, `p/python`, `p/flask`) | ✅ |
| `build-scan-sign` | hébergé | build → **Trivy (`exit-code 1`)** → ZAP baseline → **Cosign sign + verify** → push GHCR | ✅ (Trivy/Cosign) |
| `push-harbor` | **self-hosted** | pull GHCR → push Harbor → déclenche le scan CVE Harbor | ✅ |

Secrets / variables attendus dans le dépôt :

- `secrets.HARBOR_PASSWORD` — mot de passe admin Harbor
- `vars.HARBOR_HOST` — hôte du registre Harbor (ex. `localhost:30002`)

## Observabilité

Harbor expose ses métriques (`harbor_*`) ; le chart crée un **ServiceMonitor**
récupéré par Prometheus. Le dashboard Grafana (« Harbor — Registre & CVE »),
provisionné automatiquement, présente l'état du registre (projets, dépôts,
quotas, trafic HTTP) et les vulnérabilités détectées par le scanner Trivy de
Harbor.

## Arborescence

```
.
├── app/                     # API de démo + Dockerfile (artefact du pipeline)
├── terraform/               # IaC : providers, Harbor + kube-prometheus-stack, dashboard
│   └── values/              # valeurs Helm (templates)
├── grafana/                 # dashboard Harbor (JSON, provisionné via ConfigMap)
├── .github/workflows/ci.yml # pipeline DevSecOps bloquante
├── scripts/                 # cluster, runner self-hosted, démos de blocage
└── docs/                    # rapport, captures, diagramme d'architecture
```
