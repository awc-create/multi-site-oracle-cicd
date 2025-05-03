# 🌐 Static Site Infrastructure Setup (S3 + CloudFront + Route 53)

This guide walks you through setting up AWS infrastructure to host static websites using S3, CloudFront, and Route 53. It also covers CI/CD integration for automatic deployment via GitHub Actions.

---

## 🥇 Step 1: Create S3 Bucket for Static Website Hosting

### ✅ S3 Bucket Naming
Use a consistent format:
- `portfolio-static-site`
- `projectname-static-site`

### ⚙️ Configuration
1. Go to **S3 → Create bucket**
2. Set the **bucket name** (must be globally unique)
3. **Uncheck** “Block all public access”
4. Enable **Static Website Hosting**:
   - **Index document:** `index.html`
   - **Error document (optional):** `404.html`

### 🔐 Bucket Policy (Optional - Only if NOT using CloudFront OAC)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-bucket-name/*"
    }
  ]
}

> **Important:** Replace `your-bucket-name` with your actual S3 bucket name.

## 🥈 Step 2: Create CloudFront Distribution

### 🔧 Setup
- **Origin Domain:** Your S3 bucket
- **Access:** Use Origin Access Control (OAC)
- **Viewer Protocol Policy:** Redirect HTTP to HTTPS
- **Root Object:** `index.html`
- **Cache Policy:** Use a managed cache policy unless custom logic is needed
- **Alternate Domain (CNAME):** Optional (if using a custom domain)
- **SSL Certificate:** Attach from AWS Certificate Manager (if using a custom domain)

> **Note:** Save the CloudFront Distribution ID; it will be used later in the CI/CD secrets.

## 🥉 Step 3: Set Up Route 53 DNS (Optional)

### 🌐 Steps
1. Go to **Route 53 → Hosted Zones**
2. Create a Hosted Zone (e.g., `yourdomain.com`)
3. Add a new record with the following settings:
   - **Type:** A – IPv4 address
   - **Alias:** Yes
   - **Alias Target:** CloudFront Distribution

## 🛠️ Step 4: Add GitHub Secrets

### 🔒 Required Secrets

| Secret Name                              | Description                       |
| ---------------------------------------- | --------------------------------- |
| `AWS_ACCESS_KEY_ID`                      | IAM user key                      |
| `AWS_SECRET_ACCESS_KEY`                  | IAM user secret                   |
| `PROJECTNAME_S3_BUCKET_NAME`             | e.g., `portfolio-static-site`     |
| `PROJECTNAME_CLOUDFRONT_DISTRIBUTION_ID`  | CloudFront Distribution ID        |

> **Tip:** Use naming such as `PORTFOLIO_S3_BUCKET_NAME` so you can reference it dynamically.

## 🧪 Step 5: CI/CD Deployment Workflow

### 🔁 GitHub Actions Sample Workflow

```yaml
name: Deploy Static Site

on:
  push:
    branches: 
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-2

      - name: Sync Static Files to S3
        run: |
          echo "📦 Syncing static site to S3..."
          aws s3 sync out/ s3://$S3_BUCKET_NAME --delete
        env:
          S3_BUCKET_NAME: ${{ secrets.PORTFOLIO_S3_BUCKET_NAME }}

      - name: Invalidate CloudFront Cache
        if: env.CLOUDFRONT_DISTRIBUTION_ID != ''
        run: |
          echo "🚀 Invalidating CloudFront cache..."
          aws cloudfront create-invalidation \
            --distribution-id $CLOUDFRONT_DISTRIBUTION_ID \
            --paths "/*"
        env:
          CLOUDFRONT_DISTRIBUTION_ID: ${{ secrets.PORTFOLIO_CLOUDFRONT_DISTRIBUTION_ID }}

### 📌 Notes
- `out/` is the default export directory for static sites in Next.js (using `output: export`).
- The `aws s3 sync` command uploads your site files.
- CloudFront invalidation ensures users see the latest version of your site as CloudFront caches files aggressively.

---

### ❓ FAQs

**Q: Why do we invalidate CloudFront?**  
A: Because CloudFront caches files aggressively. Invalidating ensures your users get the latest deployment.

**Q: Can I skip CloudFront and use S3 alone?**  
A: Yes, but using CloudFront offers better performance, security, and custom domain support.

**Q: Can I manage this setup with Terraform?**  
A: Yes — you can manage S3 buckets, CloudFront, Route 53, and even IAM configurations via Terraform to automate the process.


