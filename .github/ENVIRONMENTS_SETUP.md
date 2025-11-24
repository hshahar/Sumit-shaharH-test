# GitHub Environments Setup Guide

This guide explains how to configure GitHub Environments for deployment approvals and secrets management.

## Overview

The CI/CD pipeline uses GitHub Environments to:
- Require manual approval for production deployments
- Store environment-specific secrets
- Track deployment history

## Environments to Create

### 1. Development Environment

**Name:** `dev`

**Protection Rules:**
- ❌ No required reviewers (auto-deploy)
- ❌ No wait timer
- ✅ Allow administrators to bypass

**Deployment Branches:**
- `develop` branch only

### 2. Staging Environment

**Name:** `staging`

**Protection Rules:**
- ✅ Required reviewers: 1 reviewer
- ❌ No wait timer
- ✅ Allow administrators to bypass

**Deployment Branches:**
- `staging` branch only

### 3. Production Environment

**Name:** `prod`

**Protection Rules:**
- ✅ Required reviewers: 2 reviewers (recommended)
- ⏱️ Wait timer: 5 minutes (optional)
- ❌ Do not allow administrators to bypass

**Deployment Branches:**
- `main` branch only

## Setup Instructions

### Step 1: Navigate to Environments

1. Go to your GitHub repository
2. Click **Settings** → **Environments**
3. Click **New environment**

### Step 2: Create Each Environment

For each environment (dev, staging, prod):

1. Enter the environment name
2. Click **Configure environment**
3. Set up protection rules (see above)
4. Add environment secrets (see below)
5. Click **Save protection rules**

### Step 3: Configure Secrets

Add these secrets to **each environment**:

#### Required Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `ARGOCD_URL` | ArgoCD server URL | `https://argocd.example.com` |
| `ARGOCD_TOKEN` | ArgoCD API token | `eyJhbGc...` |

#### Optional Secrets (for notifications)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `SLACK_WEBHOOK_URL` | Slack incoming webhook | [Create Slack App](https://api.slack.com/messaging/webhooks) |
| `TEAMS_WEBHOOK_URL` | Microsoft Teams webhook | [Create Teams Connector](https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook) |
| `GRAFANA_URL` | Grafana server URL | `https://grafana.example.com` |
| `GRAFANA_API_KEY` | Grafana API key | Create in Grafana → Configuration → API Keys |
| `SONAR_TOKEN` | SonarQube token | Create in SonarQube → My Account → Security |
| `SONAR_HOST_URL` | SonarQube server URL | `https://sonarqube.example.com` |

### Step 4: Get ArgoCD Token

```bash
# Login to ArgoCD
argocd login <ARGOCD_URL> --username admin

# Create a new token
argocd account generate-token --account github-actions

# Add the token to GitHub Environments secrets
```

### Step 5: Test the Setup

1. Push a change to the `develop` branch
2. Verify the pipeline runs automatically
3. For staging/prod, use the "Environment Promotion" workflow
4. Verify approval is required for protected environments

## Deployment Dashboard

GitHub provides a built-in deployment dashboard:

**Access:** Repository → **Environments** tab

**Features:**
- View deployment history per environment
- See who approved deployments
- Track deployment frequency
- Monitor deployment failures

## Workflow Approval Process

### For Staging Deployments

1. Developer merges PR to `staging` branch
2. Pipeline builds and tests automatically
3. **Approval required** - designated reviewer gets notified
4. Reviewer approves in GitHub UI
5. Deployment proceeds to staging environment

### For Production Deployments

#### Option 1: Direct Merge (Not Recommended)
1. Merge PR directly to `main` branch
2. Pipeline requires 2 approvals
3. Deployment proceeds after approvals

#### Option 2: Environment Promotion (Recommended)
1. Go to **Actions** → **Environment Promotion**
2. Click **Run workflow**
3. Select:
   - Source: `staging`
   - Target: `prod`
   - Image tag: e.g., `staging-abc1234`
4. **Approval required** - 2 reviewers get notified
5. Reviewers approve
6. Integration tests run automatically
7. Deployment proceeds to production

## Troubleshooting

### Pipeline Stuck on "Waiting for approval"

**Solution:** Check that:
- Reviewers are configured in Environment settings
- Notified reviewers have repository access
- Check GitHub notifications for approval request

### Secrets Not Working

**Solution:**
- Verify secret names match exactly (case-sensitive)
- Check secrets are added to the correct environment
- Repository secrets are different from environment secrets

### ArgoCD Webhook Not Working

**Solution:**
- Verify `ARGOCD_URL` doesn't have trailing slash
- Check `ARGOCD_TOKEN` is valid and not expired
- Ensure ArgoCD API is accessible from GitHub Actions
- Pipeline will fall back to 3-minute auto-sync

## Best Practices

1. **Use Environment Promotion** for production deployments
2. **Require multiple approvers** for production
3. **Test in staging first** before promoting to prod
4. **Monitor Grafana dashboards** after deployments
5. **Set up Slack notifications** for deployment awareness
6. **Review deployment history** regularly
7. **Rotate tokens** periodically for security

## Security Considerations

- Store all sensitive values as secrets (never in code)
- Use environment-specific secrets (don't share between environments)
- Limit who can approve production deployments
- Enable branch protection rules on `main` and `staging`
- Require signed commits for production branches
- Enable audit logging for deployment approvals
