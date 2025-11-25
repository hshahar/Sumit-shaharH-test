# Redeploy Frontend with Updated Credentials Page
# This script rebuilds and redeploys the frontend with the new credentials.html

Write-Host "Redeploying Frontend with Updated Credentials Page..." -ForegroundColor Cyan

# Step 1: Build new frontend image
Write-Host ""
Write-Host "Building new frontend Docker image..." -ForegroundColor Yellow
Set-Location "$PSScriptRoot\..\app\frontend"

docker build -t ghcr.io/ilpet/sha-blog-frontend:credentials-fix .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Frontend image built successfully" -ForegroundColor Green

# Step 2: Push to registry
Write-Host ""
Write-Host "Pushing image to registry..." -ForegroundColor Yellow
docker push ghcr.io/ilpet/sha-blog-frontend:credentials-fix

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker push failed! Make sure you're logged in: docker login ghcr.io" -ForegroundColor Red
    exit 1
}

Write-Host "Image pushed successfully" -ForegroundColor Green

# Step 3: Update Kubernetes deployment
Write-Host ""
Write-Host "Updating Kubernetes deployment..." -ForegroundColor Yellow
kubectl set image deployment/frontend frontend=ghcr.io/ilpet/sha-blog-frontend:credentials-fix -n sha-production

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to update sha-production, trying default namespace..." -ForegroundColor Yellow
    kubectl set image deployment/frontend frontend=ghcr.io/ilpet/sha-blog-frontend:credentials-fix
}

# Step 4: Wait for rollout
Write-Host ""
Write-Host "Waiting for deployment to complete..." -ForegroundColor Yellow
kubectl rollout status deployment/frontend -n sha-production --timeout=5m

if ($LASTEXITCODE -ne 0) {
    kubectl rollout status deployment/frontend --timeout=5m
}

Write-Host ""
Write-Host "Frontend redeployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "The credentials page is now updated at:" -ForegroundColor Cyan
Write-Host "http://k8s-envoygat-envoysha-97f4db56ea-d47e5074cc1d878a.elb.us-west-2.amazonaws.com/credentials.html" -ForegroundColor White
Write-Host ""
Write-Host "If you still see old content, hard refresh your browser (Ctrl+Shift+R or Ctrl+F5)" -ForegroundColor Yellow
