# Guide d'oral — Harbor + Terraform + CI sécurisée (DevSecOps)

## 1. Pitch d'ouverture (30 s)
« J'ai déployé **Harbor**, un registre d'images d'entreprise, entièrement par
**Infrastructure as Code** (Terraform + provider Helm) sur un cluster **k3s**.
Autour, j'ai construit une **pipeline CI/CD sécurisée et bloquante** sur GitHub
Actions qui couvre toute la chaîne DevSecOps — lint, SAST, scan de
vulnérabilités, DAST, et signature d'image — puis publie l'image signée. Enfin,
Harbor est **observé** : ses métriques et les CVE détectées remontent dans
Prometheus et sont visualisées dans Grafana. »

## 2. Les 3 composantes obligatoires (ce que le prof coche)

### a. IaC — Terraform
- `terraform/` déploie **deux releases Helm** : Harbor et kube-prometheus-stack.
- Providers `helm` + `kubernetes` ciblant le cluster k3d.
- Valeurs Helm externalisées en templates (`values/*.tftpl`).
- **À montrer** : `terraform/main.tf`, puis `kubectl get pods -n harbor` (tout Running).
- Point fort : `terraform apply` reproductible, **tflint + checkov passent** (gate IaC).

### b. CI/CD sécurisée bloquante — GitHub Actions
Ordre de la pipeline (`.github/workflows/ci.yml`) :
1. **Lint** : hadolint (Dockerfile), tflint, **checkov** (IaC) — bloquant.
2. **SAST** : **Semgrep** (`p/default`, `p/python`, `p/flask`) — bloquant.
3. **Build** de l'image.
4. **CVE** : **Trivy** `--severity HIGH,CRITICAL --exit-code 1` — **bloquant**.
5. **DAST** : **OWASP ZAP baseline** contre l'app qui tourne (rapport en artefact).
6. **Signature** : **Cosign keyless** (OIDC GitHub, sans clé privée) + vérification.
7. **Publication** : push GHCR puis **push Harbor** (runner self-hosted).
- **À montrer** : l'onglet Actions tout vert, et le détail d'un job.

### c. Observabilité — Prometheus + Grafana
- Harbor expose `harbor_*` (registre) ; le chart crée un **ServiceMonitor**.
- Un **exporter CVE** maison interroge l'API Harbor et expose les vulnérabilités
  par sévérité (`harbor_image_vulnerabilities{severity=...}`).
- Dashboard Grafana **« Harbor — Registre & CVE »** provisionné automatiquement.
- **À montrer** : le dashboard avec les compteurs Critical/High réels.

## 3. La question qui tue : « Pourquoi un runner self-hosted ? »
Harbor tourne sur un cluster **local, non exposé sur Internet**. Les runners
**hébergés** de GitHub ne peuvent donc pas le joindre. En entreprise, on sépare :
- les **contrôles sans état** (lint, SAST, CVE, DAST, signature) → runners hébergés ;
- le **déploiement/publication vers l'infra interne** → **runner self-hosted**
  installé dans le réseau privé (ici mon poste), seul à pouvoir joindre Harbor.
C'est un vrai patron d'architecture DevSecOps, pas un contournement.

## 4. Démonstration du caractère « bloquant »
- Trivy est configuré `--exit-code 1` sur HIGH/CRITICAL **corrigeables**
  (`--ignore-unfixed`) : on ne bloque que sur l'**actionnable**.
- Preuve : l'image `demo-legacy` (base Debian 11 ancienne) a **7 CVE Critical,
  38 High** → un tel artefact **ferait échouer** la pipeline. L'app de prod
  (base `python:3.13-slim` à jour) passe car 0 CVE HIGH/CRITICAL corrigeable.
- Nuance fine : Harbor affiche aussi les CVE **non corrigeables** (d'où des
  compteurs > 0 dans le dashboard même pour l'app de prod) — Trivy en CI les
  ignore car non actionnables. Cohérent et défendable.

## 5. Signature Cosign — pourquoi « keyless » ?
- Pas de clé privée à stocker/faire fuiter : l'identité du signataire est le
  **workflow GitHub** (OIDC), le certificat est émis par **Fulcio** et la
  signature enregistrée dans le journal de transparence **Rekor**.
- `cosign verify` contrôle que l'image vient bien **de ce dépôt** et **de ce
  workflow** → garantit la chaîne d'approvisionnement (supply chain).

## 6. Schéma d'architecture
Voir `docs/architecture.png` (runners hébergés → GHCR → runner self-hosted →
Harbor ; ServiceMonitor → Prometheus → Grafana).

## 7. Commandes utiles pour la démo live
```bash
# Cluster & déploiement
kubectl get pods -n harbor
kubectl get pods -n monitoring
terraform -chdir=terraform output

# Sécurité (gates locaux, mêmes que la CI)
docker run --rm -i hadolint/hadolint hadolint - < app/Dockerfile
docker run --rm -v "$PWD/terraform:/tf" bridgecrew/checkov -d /tf --framework terraform
docker run --rm -v "$PWD/app:/src" semgrep/semgrep semgrep --config p/default /src

# Vulnérabilités vues par Harbor
curl -s -u admin:Harbor12345 \
 "http://localhost:30002/api/v2.0/projects/library/repositories/demo-legacy/artifacts/bullseye?with_scan_overview=true"

# Signature
cosign verify ghcr.io/katakuri-31/harbor-devsecops/harbor-demo-app:<tag> \
  --certificate-identity-regexp "https://github.com/KaTaKuRi-31/harbor-devsecops/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

## 8. Accès (démo)
| Service | URL | Identifiants |
|---|---|---|
| Harbor | http://localhost:30002 | admin / Harbor12345 |
| Grafana | http://localhost:30091 | admin / admin |
| Prometheus | http://localhost:30090 | — |
| Dépôt + Actions | https://github.com/KaTaKuRi-31/harbor-devsecops | — |
