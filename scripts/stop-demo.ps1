# Arrête la démo pour libérer la RAM (l'état est conservé : start-demo le restaure).
# Usage :  powershell -ExecutionPolicy Bypass -File scripts\stop-demo.ps1
$env:Path += ";C:\Users\dylan\tools"

Write-Host "==> Arrêt du runner self-hosted (si lancé)..." -ForegroundColor Cyan
Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "==> Arrêt du cluster k3d 'harbor' (état conservé)..." -ForegroundColor Cyan
k3d cluster stop harbor

Write-Host "Cluster arrêté. RAM libérée. Relancer avec scripts\start-demo.ps1" -ForegroundColor Green
