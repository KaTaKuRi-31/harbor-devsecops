# Guide de navigation & manipulation

Ce guide te permet de **montrer, expliquer et modifier** le projet quand le jury
demande de manipuler. Chaque section : où c'est, quoi dire, quelle commande taper.

> Avant de commencer : `powershell -ExecutionPolicy Bypass -File scripts\start-demo.ps1`
> (relance le cluster ; ~3 min). À la fin : `scripts\stop-demo.ps1`.

---

## 0. Carte du projet (savoir où est quoi)

| Dossier / fichier | Rôle | « Si le prof demande… » |
|---|---|---|
| `terraform/` | **IaC** : déploie Harbor + Prometheus/Grafana | « montre l'infra as code » |
| `terraform/main.tf` | les 2 releases Helm (Harbor, kube-prometheus-stack) | « où Harbor est-il déclaré ? » |
| `terraform/values/*.tftpl` | réglages Helm (NodePort, Trivy, metrics) | « comment as-tu configuré Harbor ? » |
| `terraform/cve-exporter.tf` | l'exporter CVE (déploiement durci) | « d'où viennent les CVE du dashboard ? » |
| `app/` | l'app de démo + `Dockerfile` | « quel est l'artefact scanné ? » |
| `.github/workflows/ci.yml` | **la pipeline CI bloquante** | « montre la chaîne DevSecOps » |
| `grafana/harbor-dashboard.json` | le dashboard CVE & registre | « le dashboard d'observabilité » |
| `scripts/` | exporter, start/stop démo | — |
| `docs/` | architecture, oral, navigation | — |

---

## 1. Naviguer le CLUSTER (kubectl)

```bash
# Vue d'ensemble : tout ce qui tourne
kubectl get pods -A

# Les composants de Harbor (core, registry, trivy, db, redis, exporter…)
kubectl get pods -n harbor

# La stack d'observabilité (Prometheus, Grafana, operator…)
kubectl get pods -n monitoring

# « Montre que Harbor expose ses métriques » → le ServiceMonitor
kubectl get servicemonitor -n harbor

# Décrire un composant / lire ses logs (utile si on demande un détail)
kubectl describe pod -n harbor -l component=core
kubectl logs -n harbor -l component=core --tail=20
```
**À dire** : « Harbor et l'observabilité tournent sur un cluster k3s léger (k3d).
Le `ServiceMonitor` est l'objet qui dit à Prometheus de venir scraper Harbor. »

---

## 2. Naviguer HARBOR (UI + API)

**UI** : http://localhost:30002 — `admin` / `Harbor12345`
- Projet **library** → dépôts `harbor-demo-app` et `demo-legacy`.
- Cliquer un dépôt → un artefact → onglet **« Vulnerabilities »** : la liste des CVE
  trouvées par le scanner **Trivy intégré** (sévérité, CVE-ID, paquet, version fixée).
- Bouton **« Scan »** : relance un scan à la demande.

**API** (pour montrer qu'on maîtrise au-delà du clic) :
```bash
# Santé de Harbor
curl -s -u admin:Harbor12345 http://localhost:30002/api/v2.0/health

# Les dépôts du projet library
curl -s -u admin:Harbor12345 http://localhost:30002/api/v2.0/projects/library/repositories

# Le résumé CVE d'une image (la « vieille » image, bien vulnérable)
curl -s -u admin:Harbor12345 "http://localhost:30002/api/v2.0/projects/library/repositories/demo-legacy/artifacts/bullseye?with_scan_overview=true"

# Relancer un scan
curl -s -u admin:Harbor12345 -X POST "http://localhost:30002/api/v2.0/projects/library/repositories/demo-legacy/artifacts/bullseye/scan"
```
**À dire** : « Harbor est un registre **+** un scanner de vulnérabilités. Chaque
image poussée est scannée par Trivy ; je peux consulter le résultat dans l'UI ou via l'API. »

---

## 3. Naviguer le TERRAFORM (IaC)

```bash
cd terraform

# Ce qui est géré par l'IaC (état)
terraform state list

# Montrer qu'il n'y a aucune dérive (rien à changer)
terraform plan

# Lire la déclaration de Harbor
#   -> ouvrir main.tf : resource "helm_release" "harbor" { ... }
```
**Manipulation type — « change une valeur et réapplique »** :
1. Ouvrir `terraform/variables.tf`, ex. `harbor_chart_version` ou un NodePort.
2. `terraform plan` (montre le diff), puis `terraform apply`.
**À dire** : « Tout Harbor est déclaré ici ; `terraform apply` reconstruit l'infra
à l'identique sur n'importe quelle machine. tflint et checkov valident ce code dans la CI. »

---

## 4. Naviguer la PIPELINE CI (le cœur)

Ouvre `.github/workflows/ci.yml`. Les **4 jobs**, dans l'ordre :
1. `lint` : hadolint (Dockerfile) + tflint + **checkov** (IaC) — bloquant.
2. `sast` : **Semgrep** — bloquant.
3. `build-scan-sign` : build → **Trivy `--exit-code 1`** → **ZAP** → **Cosign sign+verify** → push GHCR.
4. `push-harbor` : runner **self-hosted** → push dans Harbor + déclenche le scan.

**Voir / déclencher depuis le terminal** (avec `gh`) :
```bash
gh run list --repo KaTaKuRi-31/harbor-devsecops          # historique des exécutions
gh run view --repo KaTaKuRi-31/harbor-devsecops <id>     # détail d'un run
gh workflow run ci.yml --repo KaTaKuRi-31/harbor-devsecops  # relancer la pipeline
```
**Manipulation type — « déclenche la pipeline »** : modifier un fichier, `git commit`,
`git push` → l'onglet **Actions** du dépôt montre les jobs passer au vert.
**À dire** : « Chaque push rejoue toute la chaîne ; si Trivy trouve une CVE
critique corrigeable, le job sort en `exit-code 1` et **bloque** la livraison. »

---

## 5. Démontrer le « BLOQUANT » (question fréquente)

```bash
# L'app de prod (base à jour) : 0 CVE HIGH/CRITICAL corrigeable -> PASSE
docker run --rm -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 localhost:30002/library/harbor-demo-app:dev

# Une image volontairement vieille : 7 Critical, 38 High -> ferait ÉCHOUER la CI
docker run --rm -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --severity HIGH,CRITICAL --exit-code 1 python:3.9-slim-bullseye
```
**À dire** : « Le premier renvoie 0 (pipeline verte), le second renvoie 1
(pipeline rouge). C'est ça, une porte de sécurité **bloquante**. »

---

## 6. Démontrer la SIGNATURE (Cosign keyless)

```bash
cosign verify ghcr.io/katakuri-31/harbor-devsecops/harbor-demo-app:latest \
  --certificate-identity-regexp "https://github.com/KaTaKuRi-31/harbor-devsecops/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```
**À dire** : « La signature n'utilise aucune clé privée : l'identité est le
**workflow GitHub** (OIDC), le certificat vient de Fulcio et la preuve est dans
le journal public Rekor. `verify` confirme que l'image vient bien de mon dépôt. »

---

## 7. Naviguer l'OBSERVABILITÉ

**Prometheus** : http://localhost:30090 → onglet *Graph*, taper une requête :
```promql
harbor_up                                   # Harbor est-il scrappé ?
harbor_statistics_total_repo_amount         # nb de dépôts
harbor_image_vulnerabilities                # CVE par image/sévérité (exporter maison)
```
Onglet **Status → Targets** : montrer les cibles Harbor « UP ».

**Grafana** : http://localhost:30091 → dashboard **« Harbor — Registre & CVE »** :
- ligne du haut = état du registre (projets, dépôts, stockage) ;
- ligne CVE = compteurs Critical/High/… (source : l'exporter qui interroge l'API Harbor) ;
- bas = trafic et latence de l'API.

**À dire** : « Les métriques natives de Harbor donnent l'état du registre ;
j'ai ajouté un petit **exporter** qui interroge l'API Harbor pour exposer le
détail des CVE par sévérité, que Grafana affiche. »

---

## 8. Si on demande « explique CE fichier / CETTE ligne »

- `app/Dockerfile` : image durcie — utilisateur **non-root** (`appuser`), `HEALTHCHECK`,
  serveur **gunicorn**, dépendances épinglées → c'est ce qui fait passer hadolint.
- `terraform/cve-exporter.tf` : déploiement **durci** (securityContext non-root,
  FS en lecture seule, capabilities supprimées, sondes, limites) → fait passer checkov.
- `terraform/values/harbor.yaml.tftpl` : `expose.type=nodePort`, `trivy.enabled=true`,
  `metrics.serviceMonitor.enabled=true` → exposition + scanner + métriques.

---

## 9. Réflexes « anti-blocage » à l'oral
- Tout est local et redémarrable : `scripts\start-demo.ps1`.
- Si un pod n'est pas prêt : `kubectl get pods -n harbor` puis attendre/relancer.
- Si on demande quelque chose que tu ne sais pas faire : ouvre le fichier concerné
  (cf. la carte §0) et raisonne à voix haute — montrer qu'on sait **où chercher**
  vaut mieux que réciter.
