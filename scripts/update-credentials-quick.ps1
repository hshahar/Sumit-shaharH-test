# Quick update - Tag the locally built image and restart deployment

Write-Host "Tagging and restarting frontend deployment..." -ForegroundColor Cyan

# Tag the image we just built
docker tag ghcr.io/ilpet/sha-blog-frontend:credentials-fix ghcr.io/ilpet/sha-blog-frontend:latest

# Load it into kind cluster (if using kind)
$clusterInfo = kubectl cluster-info 2>&1
if ($clusterInfo -match "kind") {
    Write-Host "Loading image into kind cluster..." -ForegroundColor Yellow
    kind load docker-image ghcr.io/ilpet/sha-blog-frontend:credentials-fix
}

# Get the deployment name
$deployment = kubectl get deployment -n sha-dev | Select-String "frontend" | ForEach-Object { ($_ -split '\s+')[0] }

if ($deployment) {
    Write-Host "Found deployment: $deployment" -ForegroundColor Green
    Write-Host "Restarting deployment..." -ForegroundColor Yellow

    # Restart the deployment
    kubectl rollout restart deployment/$deployment -n sha-dev

    # Wait for it to complete
    Write-Host "Waiting for rollout to complete..." -ForegroundColor Yellow
    kubectl rollout status deployment/$deployment -n sha-dev --timeout=5m

    Write-Host ""
    Write-Host "Deployment restarted successfully!" -ForegroundColor Green
    Write-Host "The credentials page should now be updated." -ForegroundColor Cyan
    Write-Host "Hard refresh your browser (Ctrl+Shift+R) to see changes." -ForegroundColor Yellow
} else {
    Write-Host "Could not find frontend deployment!" -ForegroundColor Red
}
