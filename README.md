
# Multi-Site CI/CD Pipeline – Vercel & Terraform Deployment

This repository manages automated CI/CD deployments for multiple Next.js projects, enabling preview and production deployments via GitHub Actions, Vercel (for preview), and AWS (for production using Terraform).

---

## ✅ 1. Setting Up GitHub Actions & CI/CD Integration (Vercel Dev Deployments)

### Step 1: Create a Vercel Access Token

1. Go to [Vercel Tokens](https://vercel.com/account/tokens).
2. Click "Create", name it `cicd-vercel-token`.
3. Copy the token and add it to your CI/CD repo:

```
Name: VERCEL_TOKEN
Value: (Paste your Vercel token here)
```

> GitHub → Settings → Secrets and Variables → Actions → Add Secret

---

### Step 2: Set Up Project Repo Trigger (trigger-deploy.yml)

Inside your project repo:

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/trigger-deploy.yml`:

```yaml
name: Trigger CI/CD Deployment

on:
  push:
    branches:
      - main
      - 'feat/**'
      - 'fix/**'

jobs:
  notify-cicd-repo:
    runs-on: ubuntu-latest
    steps:
      - name: Send Deployment Trigger
        run: |
          curl -X POST -H "Authorization: token ${{ secrets.PERSONAL_ACCESS_TOKEN }}" \
          -H "Accept: application/vnd.github.everest-preview+json" \
          --data '{
            "event_type": "deploy",
            "client_payload": {
              "repository": "${{ github.repository }}",
              "repository_name": "${{ github.event.repository.name }}",
              "branch": "${{ github.ref_name }}"
            }}' \
          https://api.github.com/repos/YOUR_CICD_REPO_OWNER/awc-multi-site-cicd/dispatches
```

Commit & push the workflow:
```bash
git add .github/workflows/trigger-deploy.yml
git commit -m "Setup CI/CD workflow"
git push origin main
```

---

## 🧪 2. Vercel Deployment Setup (Local Project)

Install and set up Vercel:

```bash
sudo npm install -g vercel
vercel login
vercel link
```

Extract your `.vercel/project.json`:
```json
{
  "projectId": "YOUR_PROJECT_ID",
  "orgId": "YOUR_ORG_ID"
}
```

Go to `awc-multi-site-cicd` → GitHub Secrets and add:

```ini
PROJECTNAME_PROJECT_ID = your projectId
PROJECTNAME_ORG_ID = your orgId
```

---

## ⚙️ 3. How the CI/CD Pipeline Works

| Git Action              | Result                         |
|-------------------------|--------------------------------|
| Push to feat/**, fix/** | Deploys preview to Vercel      |
| Merge to main           | Deploys production to Vercel   |
| (If `deploy_to: vercel`)|                                |

Each Vercel deployment uses:
- `VERCEL_TOKEN` (global)
- `PROJECT_ID`, `ORG_ID` (per project)

---

## 🏗 4. Adding a New Project to CI/CD (Vercel)

### Step 1: Add `.cicd-config.yml` to your project:

```yaml
project_type: static
tests:
  - unit
deploy_to: vercel
```

### Step 2: Commit & Push

```bash
git add .cicd-config.yml
git commit -m "CI/CD config"
git push origin main
```

### Step 3: Test with a Feature Branch

```bash
git checkout -b feat/test-deploy
echo "console.log('Hello CI');" >> hello.js
git add hello.js
git commit -m "Test CI deploy"
git push origin feat/test-deploy
```

---

## 🏔 5. AWS Production Deployment via Terraform

When a project defines:

```yaml
deploy_to: terraform
```

…in `.cicd-config.yml`, production deployments will be handled by Terraform and deploy to AWS infrastructure.

### What Happens:

1. GitHub Actions detects `deploy_to: terraform` on `main` branch.
2. Executes `build.terraform.yml` to run Terraform scripts in `/infra`.

### Terraform Deployments Include:

| AWS Service        | Purpose                                  |
|--------------------|------------------------------------------|
| **S3**             | Static site hosting                      |
| **CloudFront**     | Global CDN with HTTPS                    |
| **ACM**            | SSL Certificate                          |
| **Route 53**       | Optional DNS configuration               |
| **DynamoDB**       | Remote state locking                     |

---

## 🛠 AWS Setup Summary

1. IAM User: `terraform-github-actions` (created via Terraform)
2. GitHub Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. S3 Bucket: `my-terraform-state-prod`
4. DynamoDB Table: `terraform-locks`

---

## 🧾 Infra Code Structure

The `infra/` folder contains:

- `provider.tf`: AWS region setup
- `backend.tf`: S3 + DynamoDB remote state
- `s3.tf`: Hosting bucket config
- `cloudfront.tf`: CDN distribution
- `acm.tf`: SSL certificate
- `route53.tf`: (optional) DNS alias record
- `variables.tf`: Configurable inputs
- `outputs.tf`: CloudFront domain name

---

## ✅ Conclusion

You now have a complete, extensible CI/CD pipeline that:

- Supports **preview and production deployments**
- Runs on **GitHub Actions**
- Deploys to **Vercel (Dev)** and **AWS (Prod)** automatically
