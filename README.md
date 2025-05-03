# Multi-Site CI/CD Pipeline – Vercel & Oracle VM Deployment

This repository orchestrates automated CI/CD for multiple static sites (Next.js), providing:

- **Feature branches** (`feat/**`, `fix/**`) → Preview deploys on **Vercel**  
- **Main branch** (`main`) → Production deploys on **Vercel** AND sync to **Oracle VM** (via SCP + Nginx)  
- **Optional Terraform** jobs via `deploy_to: terraform` in `.cicd-config.yml` for AWS infrastructure  

---

## 🔑 1. Prerequisites & GitHub Secrets

### 1.1 Vercel

- **VERCEL_TOKEN**  
- For each site, two per-repo secrets:  
  - `MYPROJECT_VERCEL_ORG_ID`  
  - `MYPROJECT_VERCEL_PROJECT_ID`  

### 1.2 Oracle VM

- **ORACLE_VM_IP** → public IP of your VM  
- **ORACLE_VM_USER** → SSH username (e.g. `ubuntu`)  
- **ORACLE_VM_SSH_KEY** → base64-encoded private key  

### 1.3 (Optional) AWS / Terraform

- **AWS_ACCESS_KEY_ID**  
- **AWS_SECRET_ACCESS_KEY**  

> In GitHub: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

---

## ⚡ 2. Triggering the CI/CD Pipeline

In *each* site repo, add `.github/workflows/trigger-deploy.yml`:

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
          curl -X POST \
            -H "Authorization: token ${{ secrets.PERSONAL_ACCESS_TOKEN }}" \
            -H "Accept: application/vnd.github.everest-preview+json" \
            --data '{
              "event_type": "deploy",
              "client_payload": {
                "repository": "${{ github.repository }}",
                "repository_name": "${{ github.event.repository.name }}",
                "branch": "${{ github.ref_name }}"
              }}' \
            https://api.github.com/repos/awc-create/multi-site-oracle-cicd/dispatches

## 3. Central CI/CD Workflow

Located at .github/workflows/build.yml in this repo:

```yaml
name: Build, Test, and Deploy to Vercel & Oracle VM

on:
  push:
    branches:
      - dev
      - main
      - 'feat/**'
      - 'fix/**'
  repository_dispatch:

env:
  # Vercel
  VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
  VERCEL_ORG_ID:  ${{ secrets[format('{0}_VERCEL_ORG_ID', github.repository)] }}
  VERCEL_PROJECT_ID: ${{ secrets[format('{0}_VERCEL_PROJECT_ID', github.repository)] }}

  # Oracle VM
  ORACLE_VM_IP:    ${{ secrets.ORACLE_VM_IP }}
  ORACLE_VM_USER:  ${{ secrets.ORACLE_VM_USER }}
  ORACLE_VM_SSH_KEY: ${{ secrets.ORACLE_VM_SSH_KEY }}

permissions:
  contents: read
  actions: write

jobs:
  detect-project-type:
    runs-on: ubuntu-latest
    outputs:
      repository:      ${{ github.event.client_payload.repository }}
      repository_name: ${{ github.event.client_payload.repository_name }}
      branch:          ${{ github.event.client_payload.branch }}
      project_type:    ${{ steps.detect.outputs.PROJECT_TYPE }}

    steps:
      - name: Checkout Target Repo
        uses: actions/checkout@v4
        with:
          repository: ${{ github.event.client_payload.repository }}
          ref:        ${{ github.event.client_payload.branch }}
          path:       target/

      - name: Detect Project Type
        id: detect
        run: |
          cd target
          PROJECT_TYPE=static
          if grep -q 'deploy_to: terraform' .cicd-config.yml 2>/dev/null; then
            PROJECT_TYPE=terraform
          fi
          echo "::set-output name=PROJECT_TYPE::$PROJECT_TYPE"

  static_pipeline:
    needs: detect-project-type
    if: needs.detect-project-type.outputs.project_type == 'static'
    runs-on: ubuntu-latest
    outputs:
      repo:   ${{ needs.detect-project-type.outputs.repository }}
      branch: ${{ needs.detect-project-type.outputs.branch }}

    steps:
      - name: Checkout & Install
        uses: actions/checkout@v4
        with:
          repository: ${{ needs.static_pipeline.outputs.repo }}
          ref:        ${{ needs.static_pipeline.outputs.branch }}
          path:       app/

      - name: Use Node.js
        uses: actions/setup-node@v3
        with: node-version: '22'

      - name: Install Dependencies
        run: yarn --cwd app install --immutable

      - name: Build Static Export
        run: yarn --cwd app build && yarn --cwd app export

      - name: Upload Static Site
        uses: actions/upload-artifact@v4
        with:
          name: static-export
          path: app/out

  preview-to-vercel:
    needs: static_pipeline
    if: startsWith(needs.static_pipeline.outputs.branch, 'feat/') ||
        startsWith(needs.static_pipeline.outputs.branch, 'fix/')
    runs-on: ubuntu-latest

    steps:
      - name: Download & Deploy to Vercel (Preview)
        uses: actions/download-artifact@v4
        with:
          name: static-export
          path: out/

      - name: Install Vercel CLI
        run: npm install -g vercel

      - name: Deploy Preview
        run: vercel deploy --prebuilt --token=$VERCEL_TOKEN --env=preview

  production-to-vercel:
    needs: static_pipeline
    if: needs.static_pipeline.outputs.branch == 'dev'
    runs-on: ubuntu-latest

    steps:
      - name: Download & Deploy to Vercel (Prod)
        uses: actions/download-artifact@v4
        with:
          name: static-export
          path: out/

      - name: Install Vercel CLI
        run: npm install -g vercel

      - name: Deploy Production
        run: vercel deploy --prebuilt --prod --token=$VERCEL_TOKEN

  deploy-to-oracle:
    needs: static_pipeline
    if: needs.static_pipeline.outputs.branch == 'main'
    runs-on: ubuntu-latest
    env:
      ORACLE_VM_IP:    ${{ secrets.ORACLE_VM_IP }}
      ORACLE_VM_USER:  ${{ secrets.ORACLE_VM_USER }}
      ORACLE_VM_SSH_KEY: ${{ secrets.ORACLE_VM_SSH_KEY }}

    steps:
      - name: Download Static Export
        uses: actions/download-artifact@v4
        with:
          name: static-export
          path: out/

      - name: Provision SSH Key
        run: |
          echo "$ORACLE_VM_SSH_KEY" | base64 -d > oracle_vm_key
          chmod 600 oracle_vm_key

      - name: Add Known Host
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -H $ORACLE_VM_IP >> ~/.ssh/known_hosts

      - name: Ensure Remote Directory
        run: |
          ssh -i oracle_vm_key $ORACLE_VM_USER@$ORACLE_VM_IP \
            "sudo mkdir -p /var/www/\${GITHUB_REPOSITORY##*/}.co.uk && \
             sudo chown $ORACLE_VM_USER:$ORACLE_VM_USER /var/www/\${GITHUB_REPOSITORY##*/}.co.uk"

      - name: Sync to Oracle VM
        run: |
          scp -r -i oracle_vm_key out/* \
            $ORACLE_VM_USER@$ORACLE_VM_IP:/var/www/\${GITHUB_REPOSITORY##*/}.co.uk/

      - name: Reload Nginx
        run: |
          ssh -i oracle_vm_key $ORACLE_VM_USER@$ORACLE_VM_IP \
            "sudo systemctl reload nginx"

  terraform_pipeline:
    needs: detect-project-type
    if: needs.detect-project-type.outputs.project_type == 'terraform'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout & Setup Terraform
        uses: actions/checkout@v4
        with:
          path: infra/
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      - name: Terraform Init & Apply
        run: |
          cd infra
          terraform init
          terraform apply -auto-approve
```

## README Highlights

Preview on every feature/fix branch via Vercel.

Production on dev → Vercel & on main → Vercel + Oracle VM.

Optional AWS/Terraform for more complex infra.