# Démarre la démo : relance le cluster k3d et attend que tout soit prêt.
# Usage :  powershell -ExecutionPolicy Bypass -File scripts\start-demo.ps1
$ErrorActionPreference = "Stop"
$env:Path += ";C:\Users\dylan\tools"

Write-Host "==> Démarrage du cluster k3d 'harbor'..." -ForegroundColor Cyan
k3d cluster start harbor

Write-Host "==> Attente des pods Harbor + monitoring (peut prendre 2-3 min)..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod --all -n harbor --timeout=240s
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=240s

Write-Host ""
Write-Host "Tout est prêt :" -ForegroundColor Green
Write-Host "  Harbor     : http://localhost:30002   (admin / Harbor12345)"
Write-Host "  Grafana    : http://localhost:30091   (admin / admin)"
Write-Host "  Prometheus : http://localhost:30090"
Write-Host ""
Write-Host "Pour rejouer la pipeline CI en live, relancer le runner self-hosted :" -ForegroundColor Yellow
Write-Host "  cd C:\actions-runner ; .\run.cmd"
