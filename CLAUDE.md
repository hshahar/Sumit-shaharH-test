# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SHA's Kubernetes Blog Platform - A production-ready, GitOps-based blog platform demonstrating Kubernetes best practices with ArgoCD, Helm, and comprehensive security/observability features. This is a multi-environment (dev/staging/prod) infrastructure showcasing modern cloud-native patterns.

**Technology Stack:**
- Infrastructure: Terraform + Helm + Kubernetes (Rancher Desktop/Docker Desktop/AWS EKS)
- GitOps: ArgoCD for declarative deployment
- Applications: React frontend (Vite) + FastAPI backend + PostgreSQL
- AI/ML: Real-time AI scoring agent with dual model support (Ollama/OpenAI)
- Logging: ELK Stack (Elasticsearch, Logstash, Kibana, Filebeat)
- Progressive Delivery: Argo Rollouts (Canary deployments)
- Autoscaling: KEDA (event-driven) + HPA
- Monitoring: Prometheus + Grafana
- Security: Vault, Calico CNI, NetworkPolicies, Kyverno
- CI/CD: GitHub Actions (golden pipeline with Trivy, Cosign, Syft)

## Common Commands

### Quick Start (10 minutes)
```powershell
# Full setup wrapper
.\run.ps1 help

# Initial infrastructure deployment
cd terraform
terraform init
terraform apply -var-file="environments/dev.tfvars" -auto-approve

# Add hostnames to Windows hosts file (run as Administrator)
.\scripts\add-hosts-sha.ps1

# Check deployment status
.\run.ps1 status dev
kubectl get pods -n sha-dev
```

### Development Workflow

**Deploy to specific environment:**
```powershell
.\run.ps1 deploy dev
.\run.ps1 deploy staging
.\run.ps1 deploy prod
```

**View logs:**
```powershell
.\run.ps1 logs dev
kubectl logs -n sha-dev deployment/sha-k8s-blog-dev-sha-microservices-app-backend -f
kubectl logs -n sha-dev deployment/sha-k8s-blog-dev-sha-microservices-app-frontend -f
```

**Check status:**
```powershell
.\run.ps1 status dev
.\run.ps1 pods dev
.\run.ps1 services dev
kubectl get applications -n argocd  # ArgoCD applications
```

### Testing & Validation

**Lint and validate:**
```powershell
.\run.ps1 test

# Manual validation
helm lint helm/microservices-app
helm lint helm/microservices-app --values helm/microservices-app/values-dev.yaml
cd terraform && terraform validate
```

**Run backend tests:**
```powershell
cd app/backend

# Install test dependencies
pip install pytest pytest-cov

# Run all tests
pytest

# Run all tests with coverage
pytest --cov=. --cov-report=term-missing --cov-report=html

# Run specific test file
pytest test_api.py

# Run specific test
pytest test_api.py::TestBlogPostCRUD::test_create_post

# Run tests with verbose output
pytest -v

# Run tests excluding slow tests
pytest -m "not slow"
```

**Run frontend tests:**
```powershell
cd app/frontend
npm test -- --run
```

### Build & Push Images
```powershell
# Backend
cd app/backend
docker build -t sha-blog-backend:dev .
docker tag sha-blog-backend:dev ghcr.io/yourusername/backend:dev
docker push ghcr.io/yourusername/backend:dev

# Frontend
cd app/frontend
docker build -t sha-blog-frontend:dev .
docker tag sha-blog-frontend:dev ghcr.io/yourusername/frontend:dev
docker push ghcr.io/yourusername/frontend:dev
```

### Terraform Operations

**Environment-specific deployments:**
```powershell
cd terraform

# Dev (minimal resources)
terraform apply -var-file="environments/dev.tfvars"

# Staging (moderate resources)
terraform apply -var-file="environments/staging.tfvars"

# Production (full resources)
terraform apply -var-file="environments/prod.tfvars"

# Plan changes first
terraform plan -var-file="environments/dev.tfvars"

# Destroy environment
terraform destroy -var-file="environments/dev.tfvars"
```

### ArgoCD Operations
```powershell
# OPTION 1: Install ArgoCD via automated script (recommended)
cd argocd/install

# Install ArgoCD with custom configuration
.\00-install-argocd.ps1  # or bash 00-install-argocd.sh

# Install application using App-of-Apps pattern
.\02-install-apps.ps1    # or bash 02-install-apps.sh

# OPTION 2: Manual installation
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Apply App-of-Apps pattern
kubectl apply -f argocd/app-of-apps.yaml

# Sync application manually
argocd app sync sha-k8s-blog-dev
argocd app sync sha-k8s-blog-staging
argocd app sync sha-k8s-blog-prod

# Check sync status
argocd app list
argocd app get sha-k8s-blog-dev

# View sync history
argocd app history sha-k8s-blog-dev

# Rollback
argocd app rollback sha-k8s-blog-dev 1
```

### Monitoring & Debugging
```powershell
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access: http://localhost:3000 (admin/admin)

# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Port-forward Vault
kubectl port-forward -n vault svc/vault 8200:8200

# Port-forward Kibana (ELK Stack)
kubectl port-forward -n logging svc/kibana 5601:5601
# Access: http://localhost:5601

# View events
kubectl get events -n sha-dev --sort-by='.lastTimestamp'

# Describe failing pod
kubectl describe pod <pod-name> -n sha-dev

# Shell into pod
kubectl exec -it -n sha-dev <pod-name> -- /bin/sh
```

### AI Agent Operations
```powershell
# Check AI agent status
kubectl get pods -n sha-dev -l app=ai-agent

# View AI agent logs
kubectl logs -n sha-dev -l app=ai-agent -f

# Check current model configuration
kubectl port-forward -n sha-dev svc/ai-agent 8000:8000
curl http://localhost:8000/model

# Manually trigger post scoring
curl -X POST http://localhost:8000/score -H "Content-Type: application/json" -d '{"post_id": 1}'

# View all scores
curl http://localhost:8000/scores

# Rebuild vector database
curl -X POST http://localhost:8000/reindex
```

### ELK Stack Operations
```powershell
# Check ELK stack pods
kubectl get pods -n logging

# View Elasticsearch cluster health
kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health?pretty

# View indices
kubectl exec -n logging elasticsearch-0 -- curl -s http://localhost:9200/_cat/indices?v

# Check Logstash pipeline
kubectl logs -n logging -l app=logstash -f

# View Filebeat logs
kubectl logs -n logging -l app=filebeat --tail=100
```

### AWS EKS Operations (if deployed on AWS)
```powershell
# Update kubeconfig for EKS
aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks

# Shutdown cluster to save costs (~$50-60/month)
cd terraform/eks
.\shutdown-cluster.ps1

# Startup cluster
.\startup-cluster.ps1

# View AWS resources
aws eks describe-cluster --name sha-blog-eks --region us-west-2
```

## Architecture Overview

### Multi-Environment Structure

**Namespaces:**
- `sha-dev` - Development (auto-sync, 1 replica, 1Gi storage)
- `sha-staging` - Staging (auto-sync, 2 replicas, 5Gi storage, canary enabled)
- `sha-production` - Production (manual sync, 3 replicas, 10Gi storage, canary enabled)
- `argocd` - GitOps controller
- `monitoring` - Prometheus + Grafana
- `vault` - Secrets management
- `keda` - Event-driven autoscaling
- `argo-rollouts` - Progressive delivery
- `logging` - ELK Stack (Elasticsearch, Logstash, Kibana, Filebeat)

### Key Infrastructure Components

**Deployed by Terraform ([terraform/main.tf](terraform/main.tf)):**
1. **Calico CNI** - NetworkPolicy enforcement
2. **NGINX Ingress Controller** - Traffic routing
3. **ArgoCD** - GitOps deployment automation
4. **Vault** - Secrets management (dev mode in dev, standalone in staging/prod)
5. **Argo Rollouts** - Canary deployments with auto-rollback
6. **KEDA** - Event-driven autoscaling (80+ scalers)
7. **Prometheus Stack** - Monitoring (Prometheus + Grafana + AlertManager)
8. **External Secrets Operator** - Vault→K8s secrets sync

**Application Stack ([helm/microservices-app/](helm/microservices-app/)):**
- Frontend: React + Vite (Nginx serving static files)
- Backend: FastAPI (Python REST API with Prometheus metrics, rate limiting)
- Database: PostgreSQL 15 (StatefulSet with persistent storage, automated backups)
- AI Agent: Real-time scoring service with RAG (dual model: Ollama/OpenAI)
- Ollama: Local LLM inference (optional, for free AI scoring)

**Logging Stack ([helm/elk-stack/](helm/elk-stack/)):**
- Elasticsearch: Distributed search and analytics (10Gi storage)
- Logstash: Log processing pipeline with JSON parsing
- Kibana: Log visualization and exploration
- Filebeat: DaemonSet log collector on each node

**Cloud Infrastructure (Optional - [terraform/eks/](terraform/eks/)):**
- AWS EKS cluster in us-west-2 (Oregon)
- EC2-based Kubernetes with Spot instances (cost-optimized)
- Auto-scaling node groups (2-10 nodes)
- AWS Load Balancer Controller for ingress
- EBS CSI Driver for persistent storage
- CloudNative PostgreSQL operator for production databases

### GitOps Workflow

**Branch → Environment mapping:**
- `develop` branch → `sha-dev` namespace (auto-sync)
- `staging` branch → `sha-staging` namespace (auto-sync, canary)
- `main` branch → `sha-production` namespace (manual sync, canary)

**CI/CD Pipeline ([.github/workflows/golden-pipeline.yaml](.github/workflows/golden-pipeline.yaml)):**
1. Lint & Test (Python, Node.js, Helm)
2. Security Scan (Trivy filesystem + dependency scanning)
3. Build Images (Docker buildx with SBOM/provenance)
4. Container Scan (Trivy image scanning)
5. Sign Images (Cosign keyless signing)
6. Generate SBOM (Syft in SPDX format)
7. Policy Check (Kyverno validation)
8. Update Manifests (automated Helm values update)
9. Notify ArgoCD (auto-sync in dev, manual promotion for staging/prod)

### Helm Chart Architecture

**Main chart:** `helm/microservices-app/`

**Values files hierarchy:**
- `values.yaml` - Base defaults
- `values-dev.yaml` - Dev overrides (1 replica, 1Gi disk, basic security)
- `values-staging.yaml` - Staging overrides (2 replicas, 5Gi disk, canary, vault)
- `values-prod.yaml` - Production overrides (3 replicas, 10Gi disk, canary, vault, alerts)

**Key templates:**
- `frontend-deployment.yaml` / `rollout-backend.yaml` - Application workloads
- `postgresql-statefulset.yaml` - Database with PVC
- `ingress.yaml` - NGINX routing rules
- `networkpolicy.yaml` - Calico network segmentation
- `servicemonitors.yaml` - Prometheus metrics collection
- `external-secrets.yaml` - Vault integration
- `kyverno-policies.yaml` - Runtime policy enforcement
- `backend-scaledobject.yaml` / `frontend-scaledobject.yaml` - KEDA autoscaling

### Progressive Delivery (Canary)

**Enabled in staging/prod only** via `argoRollouts.enabled: true` in values files.

**Canary strategy ([helm/microservices-app/templates/rollout-backend.yaml](helm/microservices-app/templates/rollout-backend.yaml)):**
1. 10% traffic (pause 2 min, automated analysis)
2. 25% traffic (pause 3 min, automated analysis)
3. 50% traffic (pause 5 min, automated analysis)
4. 100% traffic (promote) OR auto-rollback on failure

**Analysis metrics:**
- Success rate > 95%
- P95 latency < 500ms
- CPU < 80%, Memory < 85%
- Pod uptime > 99%

### Security Architecture

**Network Security:**
- Calico CNI with NetworkPolicies (default-deny in prod)
- Explicit allow rules for frontend→backend→postgres

**Pod Security:**
- PSA enforcement: `baseline` (dev), `restricted` (staging/prod)
- Non-root users (UID 1000)
- Read-only root filesystem
- Seccomp profiles (RuntimeDefault)
- Dropped capabilities
- User namespaces enabled in staging/prod (if cluster supports)

**Secrets Management:**
- Vault (HashiCorp) for centralized storage
- External Secrets Operator for automatic sync
- K8s Secrets for backward compatibility

**Runtime Security:**
- Kyverno policies (audit or enforce mode)
- Image signature verification (Cosign)
- Trusted registry enforcement
- SBOM attestation

### Monitoring & Observability

**Grafana Dashboards ([helm/microservices-app/templates/grafana-dashboard.yaml](helm/microservices-app/templates/grafana-dashboard.yaml)):**
- Request rate (req/sec by service)
- Error rate (5xx errors %)
- P95 latency (ms)
- CPU/Memory usage per pod
- Pod uptime/ready ratio
- Active rollouts progress
- Database connections
- Network I/O

**Prometheus ServiceMonitors:**
- Backend `/metrics` endpoint
- Frontend Nginx metrics
- PostgreSQL exporter
- Argo Rollouts metrics
- KEDA scaler metrics

**Alerts (production only):**
- Error rate > 1%
- P95 latency > 300ms
- CPU > 80%, Memory > 85%
- Pod not ready > 5 minutes

## Important Development Notes

### Personalization: SHA Naming Convention

This codebase uses "SHA" as a personalization prefix throughout. When modifying or extending:
- Helm release names: `sha-k8s-blog-{env}`
- Namespaces: `sha-{env}`
- Ingress hosts: `sha-{component}-{env}.local`
- Deployment names: `sha-k8s-blog-{env}-sha-microservices-app-{component}`

### Environment-Specific Considerations

**Dev:**
- Auto-sync enabled (changes deploy within 3 minutes)
- No canary deployments (direct rollout)
- Single replicas for all services
- Vault in dev mode (ephemeral, no TLS)
- Minimal resources (suitable for local laptop)
- No AlertManager

**Staging:**
- Auto-sync enabled
- Canary deployments with automated analysis
- Vault in standalone mode with persistent storage
- 2 replicas, moderate resources
- No AlertManager (alerts logged only)

**Production:**
- Manual sync required (via ArgoCD UI or CLI)
- Canary deployments with automated rollback
- Vault HA mode with persistent storage
- 3 replicas, full resources
- AlertManager enabled with notification channels
- Auto-healing disabled (manual intervention required)

### Terraform State Management

**Local state (default):**
- State stored in `terraform/terraform.tfstate`
- ⚠️ Not suitable for teams or production

**S3 backend (recommended):**
```powershell
# Setup script
.\terraform\scripts\setup-s3-backend.ps1 -BucketName "sha-k8s-terraform-state" -Region "us-east-1"

# Enable backend
Copy-Item terraform\backend-s3.tf.example terraform\backend-s3.tf

# Migrate state
terraform init -migrate-state
```

### Troubleshooting Common Issues

**Pods stuck in Pending:**
- Check PVC binding: `kubectl get pvc -n sha-dev`
- Check resources: `kubectl describe nodes`
- Check events: `kubectl get events -n sha-dev`

**Ingress not working:**
- Verify hosts file: `Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "sha-"`
- Check Ingress Controller: `kubectl get pods -n ingress-nginx`
- Check Ingress: `kubectl describe ingress -n sha-dev`

**ArgoCD not syncing:**
- Check application health: `argocd app get sha-k8s-blog-dev`
- Force refresh: `argocd app sync sha-k8s-blog-dev --force`
- Check repo access: ArgoCD UI → Settings → Repositories

**KEDA not scaling:**
- Check ScaledObject status: `kubectl get scaledobject -n sha-dev`
- View metrics: `kubectl get hpa -n sha-dev` (KEDA creates HPA)
- Check KEDA operator logs: `kubectl logs -n keda deployment/keda-operator`

### Scripts Directory

**PowerShell automation scripts in [scripts/](scripts/):**
- `setup.ps1` - Initial full setup
- `deploy.ps1` - Deploy/update specific environment
- `status.ps1` - Check deployment status
- `view-logs.ps1` - View component logs
- `cleanup.ps1` - Remove environment resources
- `add-hosts-sha.ps1` - Configure Windows hosts file (requires admin)
- `deploy-argocd.ps1` - Deploy ArgoCD standalone
- `setup-vault.ps1` - Initialize and unseal Vault
- `verify-calico.ps1` - Verify Calico NetworkPolicy support
- `verify-stack.ps1` - Verify entire monitoring stack

**Wrapper script:** `run.ps1` provides convenient commands (see Common Commands above)

### File Organization

**Critical paths:**
- `terraform/main.tf` - Infrastructure definitions (local Kubernetes)
- `terraform/eks/` - AWS EKS infrastructure (cloud deployment)
- `terraform/environments/*.tfvars` - Environment configurations
- `helm/microservices-app/values*.yaml` - Application configurations
- `helm/microservices-app/templates/` - Kubernetes manifests (Deployment, Service, etc.)
- `helm/ai-agent/` - AI scoring agent Helm chart
- `helm/ollama/` - Local LLM inference Helm chart
- `helm/elk-stack/` - ELK logging stack Helm chart
- `helm/cloudnative-pg/` - CloudNative PostgreSQL operator chart
- `argocd/app-of-apps.yaml` - ArgoCD master application
- `argocd/applications/*.yaml` - Environment-specific ArgoCD apps
- `argocd/install/` - ArgoCD installation automation scripts
- `.github/workflows/golden-pipeline.yaml` - Complete CI/CD pipeline
- `.github/PULL_REQUEST_TEMPLATE.md` - PR template with Kubernetes-specific checklist
- `.github/ISSUE_TEMPLATE/` - Bug report and feature request templates
- `app/backend/main.py` - FastAPI backend with Prometheus metrics, AI integration
- `app/backend/test_api.py` - Comprehensive backend tests
- `app/backend/conftest.py` - Test fixtures and configuration
- `app/frontend/src/App.tsx` - React frontend with AI score display
- `app/ai-agent/main_dual_model.py` - AI agent with Ollama/OpenAI support
- `app/ai-agent/db_migration.sql` - Database schema for AI scoring

### Progressive Enhancement Path

When adding new features, follow this progression:
1. **Dev first:** Test in `sha-dev` with auto-sync
2. **Update Helm values:** Modify `values-dev.yaml`
3. **Commit to `develop`:** Triggers CI/CD pipeline
4. **Verify metrics:** Check Grafana dashboards
5. **Promote to staging:** Merge to `staging` branch
6. **Monitor canary:** Watch rollout progress in ArgoCD
7. **Promote to prod:** Merge to `main` branch (requires manual sync)

### KEDA Autoscaling Configuration

**Enabled via:** `autoscaling.enabled: true` and `autoscaling.type: keda` in values files.

**Available scalers:**
- CPU-based (default, 70% target)
- Memory-based (optional, 80% target)
- Prometheus metrics (custom queries)
- Cron (scheduled scaling)
- HTTP request rate
- Queue depth (future: RabbitMQ/SQS)

**Scaling behavior is highly tuned:**
- Scale up: fast (30s window, +100% or +4 pods/period)
- Scale down: gradual (300s window, -50% or -2 pods/period)

### AI Agent & Real-Time Scoring

**Architecture Overview:**

The platform includes an intelligent AI agent that automatically scores blog posts in real-time using RAG (Retrieval Augmented Generation) and supports dual models:

**Key Features:**
- **Real-time scoring**: Posts scored automatically on create/update (non-blocking background tasks)
- **Dual model support**: Choose between free local models (Ollama) or premium cloud models (OpenAI)
- **6 quality metrics**: Technical accuracy (25), clarity (20), completeness (20), code quality (15), SEO (10), engagement (10)
- **Visual display**: Color-coded score badges in frontend (⭐ 90+, ✨ 80+, 👍 70+, 📝 60+, 💡 <60)
- **RAG integration**: Uses vector database (ChromaDB) to find similar posts for context

**Model Comparison:**

| Model | Cost | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| Ollama (Llama3) | $0 | 10-15s | 85-90% | High volume, privacy, dev/test |
| OpenAI GPT-4 | ~$0.01-0.02/post | 5-8s | 95%+ | Production, best quality |

**Deployment:**

```bash
# Option 1: Free local model (Ollama)
helm install ollama ./helm/ollama --namespace sha-dev
helm upgrade sha-blog ./helm/microservices-app \
  --set aiAgent.enabled=true \
  --set aiAgent.modelProvider=ollama

# Option 2: OpenAI (premium)
helm upgrade sha-blog ./helm/microservices-app \
  --set aiAgent.enabled=true \
  --set aiAgent.modelProvider=openai \
  --set aiAgent.openai.apiKey=sk-your-key
```

**How it Works:**
1. User creates/updates post → Backend saves to DB
2. Backend triggers AI agent via background task (non-blocking)
3. AI agent retrieves post, finds similar posts (RAG)
4. AI agent analyzes with LLM and calculates scores
5. Scores stored in database
6. Frontend displays score badge within 5-15 seconds

**Files:**
- [app/ai-agent/main_dual_model.py](app/ai-agent/main_dual_model.py) - Dual model AI agent
- [helm/ai-agent/](helm/ai-agent/) - AI agent Helm chart
- [helm/ollama/](helm/ollama/) - Ollama local LLM chart
- [docs/REALTIME_AI_SCORING.md](docs/REALTIME_AI_SCORING.md) - Full deployment guide
- [docs/DUAL_MODEL_AI_AGENT.md](docs/DUAL_MODEL_AI_AGENT.md) - Dual model configuration

### ELK Stack Integration

**Centralized Logging Architecture:**

Complete ELK (Elasticsearch, Logstash, Kibana) stack for log aggregation, processing, and visualization:

**Components:**
- **Elasticsearch**: Distributed search engine for log storage (10Gi persistent storage)
- **Logstash**: Log processing pipeline with JSON parsing, Kubernetes metadata enrichment
- **Kibana**: Web UI for log visualization and analysis
- **Filebeat**: DaemonSet collector running on each node, auto-discovers containers

**Log Flow:**
```
Container Logs → Filebeat (collect) → Logstash (parse/enrich) → Elasticsearch (store) → Kibana (visualize)
```

**Features:**
- Structured JSON logging from backend
- Kubernetes metadata enrichment (namespace, pod, container)
- FastAPI request/response logging with duration tracking
- Nginx access logs parsing
- Error tracking and alerting
- Full-text search across all logs

**Deployment:**

```bash
# Install ELK stack
helm install elk-stack ./helm/elk-stack --namespace logging --create-namespace

# Or via ArgoCD
kubectl apply -f argocd/applications/elk-stack.yaml

# Access Kibana
kubectl port-forward -n logging svc/kibana 5601:5601
# http://localhost:5601
```

**Common Queries in Kibana:**
- Backend errors: `k8s_container: "backend" AND level: "ERROR"`
- HTTP 500 errors: `status_code: 500`
- Slow requests: `duration > 500`
- Specific endpoint: `path: "/api/posts" AND http_method: "POST"`

**Files:**
- [helm/elk-stack/](helm/elk-stack/) - Complete ELK Helm chart
- [docs/ELK_STACK_GUIDE.md](docs/ELK_STACK_GUIDE.md) - Comprehensive ELK guide
- [elk/dashboards/](elk/dashboards/) - Kibana dashboard templates

### AWS EKS Deployment (Cloud Infrastructure)

**Production-Ready Cloud Deployment:**

The platform can be deployed on AWS EKS for production workloads with cost-optimized configurations:

**Features:**
- **Region**: us-west-2 (Oregon) for lower costs
- **Compute**: Spot instances (70% cheaper than On-Demand)
- **Auto-scaling**: 2-10 nodes based on load
- **Storage**: EBS gp3 volumes (20% cheaper than gp2)
- **Load Balancing**: AWS ALB for ingress traffic
- **Cost Management**: Shutdown scripts to save ~$50-60/month when not in use

**Cost Breakdown:**
- Running 24/7: ~$150-160/month
- With shutdown nights/weekends: ~$105/month (EKS control plane + NAT gateway only)

**Deployment:**

```bash
cd terraform/eks

# Deploy EKS cluster (takes 15-20 minutes)
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks

# Deploy application
helm install sha-blog ../../helm/microservices-app \
  --namespace sha-dev \
  --values ../../helm/microservices-app/values-eks.yaml

# Shutdown when not needed (saves ~$50-60/month)
.\shutdown-cluster.ps1

# Startup again
.\startup-cluster.ps1
```

**Files:**
- [terraform/eks/](terraform/eks/) - Complete EKS infrastructure
- [terraform/eks/README.md](terraform/eks/README.md) - Detailed EKS deployment guide
- [terraform/eks/shutdown-cluster.ps1](terraform/eks/shutdown-cluster.ps1) - Cost-saving script
- [helm/cloudnative-pg/](helm/cloudnative-pg/) - Production PostgreSQL operator

### Recent Improvements (Latest Updates)

**1. Enhanced Backend Application ([app/backend/main.py](app/backend/main.py)):**
- ✅ **Prometheus Metrics Integration:** Full metrics export at `/metrics` endpoint
  - `http_requests_total` - Request counter with labels (method, endpoint, status)
  - `http_request_duration_seconds` - Request duration histogram
  - `db_connections_active` - Active database connection gauge
  - `blog_posts_total` - Total blog posts gauge
- ✅ **Rate Limiting:** Protection against API abuse with slowapi
  - GET /api/posts: 100 requests/minute
  - POST /api/posts: 10 requests/minute
  - PUT /api/posts: 20 requests/minute
  - DELETE /api/posts: 10 requests/minute
- ✅ **Improved Health Checks:**
  - `/health` - Health probe with database connectivity check
  - `/ready` - Readiness probe (returns 503 if not ready)
  - `/metrics` - Prometheus metrics endpoint
- ✅ **Database Connection Pooling:** Enhanced SQLAlchemy engine with pool management
- ✅ **Better Error Handling:** Proper HTTP exception handling throughout API

**2. Comprehensive Test Suite ([app/backend/test_api.py](app/backend/test_api.py)):**
- ✅ **70+ Test Cases:** Full coverage of all API endpoints
  - Health and readiness endpoint tests
  - Complete CRUD operations testing
  - Pagination and filtering tests
  - Input validation tests
  - Rate limiting tests
- ✅ **Test Infrastructure:**
  - SQLite in-memory database for fast tests
  - Pytest fixtures for reusable test data
  - Coverage reporting with pytest-cov
  - Organized test classes by functionality
- ✅ **Run tests:** `cd app/backend && pytest --cov=. --cov-report=term-missing`

**3. PostgreSQL Automated Backup ([helm/microservices-app/templates/postgresql-backup-cronjob.yaml](helm/microservices-app/templates/postgresql-backup-cronjob.yaml)):**
- ✅ **Daily Automated Backups:** CronJob runs at 2 AM daily
- ✅ **Retention Policy:** Keeps last 7 backups automatically
- ✅ **Compressed Backups:** Using gzip for space efficiency
- ✅ **Dedicated Storage:** Separate 5Gi PVC for backups
- ✅ **Resource Limits:** Controlled CPU/memory usage during backups
- ✅ **Enable in values:** `postgresql.backup.enabled: true`

**4. Vault Secrets Management Enabled:**
- ✅ **Enabled by Default:** Vault integration now active in all environments
- ✅ **External Secrets Operator:** Automatic sync from Vault to Kubernetes Secrets
- ✅ **Configuration:** `vault.enabled: true` in [values.yaml](helm/microservices-app/values.yaml)
- ✅ **Vault Address:** `http://vault.vault:8200`
- ✅ **Refresh Interval:** 1 hour automatic secret refresh

**5. Resource Quotas and Limit Ranges ([helm/microservices-app/templates/](helm/microservices-app/templates/)):**
- ✅ **ResourceQuota ([resourcequota.yaml](helm/microservices-app/templates/resourcequota.yaml)):**
  - CPU limits: 4 requests / 8 limits
  - Memory limits: 8Gi requests / 16Gi limits
  - Storage limits: 50Gi requests, 10 PVCs max
  - Object counts: 20 pods, 10 services, 20 secrets/configmaps
- ✅ **LimitRange ([limitrange.yaml](helm/microservices-app/templates/limitrange.yaml)):**
  - Container limits: 50m-2 CPU, 64Mi-4Gi memory
  - Default container requests: 100m CPU, 128Mi memory
  - Default container limits: 200m CPU, 256Mi memory
  - Pod limits: 4 CPU, 8Gi memory max
  - PVC limits: 1Gi-20Gi storage range
- ✅ **Prevents resource exhaustion and ensures fair resource allocation**

**6. GitHub Templates ([.github/](github/)):**
- ✅ **Pull Request Template:** Kubernetes-specific checklist including:
  - Helm lint verification
  - Resource limits checks
  - SecurityContext validation
  - NetworkPolicy updates
  - ArgoCD compatibility
  - RBAC considerations
- ✅ **Bug Report Template:** Component-specific issue reporting
- ✅ **Feature Request Template:** Structured feature proposals with priority

### Testing the Improvements

**Test backend with metrics:**
```powershell
cd app/backend
python main.py

# In another terminal
curl http://localhost:8000/metrics
curl http://localhost:8000/health
curl http://localhost:8000/ready
```

**Run comprehensive tests:**
```powershell
cd app/backend
pytest -v --cov=. --cov-report=html
# Open htmlcov/index.html to see coverage report
```

**Test backup CronJob:**
```powershell
# Deploy with backups enabled
helm upgrade --install sha-blog ./helm/microservices-app \
  --namespace sha-dev \
  --set postgresql.backup.enabled=true

# Trigger manual backup (for testing)
kubectl create job -n sha-dev test-backup \
  --from=cronjob/sha-blog-sha-microservices-app-postgres-backup

# Check backup job
kubectl get jobs -n sha-dev
kubectl logs -n sha-dev job/test-backup
```

**Verify resource quotas:**
```powershell
kubectl get resourcequota -n sha-dev
kubectl get limitrange -n sha-dev
kubectl describe resourcequota -n sha-dev
```

## Additional Resources

**Essential Documentation:**
- [README.md](README.md) - Project overview
- [GETTING_STARTED.md](GETTING_STARTED.md) - 10-minute quick start guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture diagrams
- [terraform/README.md](terraform/README.md) - Terraform usage
- [helm/microservices-app/README.md](helm/microservices-app/README.md) - Helm chart documentation
- [argocd/README.md](argocd/README.md) - ArgoCD setup and GitOps workflow

**AI & ML Features:**
- [docs/REALTIME_AI_SCORING.md](docs/REALTIME_AI_SCORING.md) - Real-time AI scoring deployment guide
- [docs/DUAL_MODEL_AI_AGENT.md](docs/DUAL_MODEL_AI_AGENT.md) - Dual model (Ollama/OpenAI) setup
- [docs/DUAL_MODEL_QUICK_START.md](docs/DUAL_MODEL_QUICK_START.md) - Quick AI agent reference
- [docs/AI_RAG_AGENT_PLAN.md](docs/AI_RAG_AGENT_PLAN.md) - Original RAG architecture plan
- [REALTIME_AI_IMPLEMENTATION_SUMMARY.md](REALTIME_AI_IMPLEMENTATION_SUMMARY.md) - Complete implementation summary

**Logging & Observability:**
- [docs/ELK_STACK_GUIDE.md](docs/ELK_STACK_GUIDE.md) - Complete ELK stack guide
- [elk/dashboards/README.md](elk/dashboards/README.md) - Kibana dashboard creation guide

**Cloud Deployment:**
- [terraform/eks/README.md](terraform/eks/README.md) - AWS EKS deployment guide with cost optimization

**Reference Files:**
- [CHEATSHEET.md](CHEATSHEET.md) - Command quick reference
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [ENVIRONMENTS.md](ENVIRONMENTS.md) - Environment comparison matrix
- [docs/GRACEFUL_SHUTDOWN_ANALYSIS.md](docs/GRACEFUL_SHUTDOWN_ANALYSIS.md) - Graceful shutdown implementation
