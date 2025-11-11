# TestProject AWS Static Hosting Platform

## 1. Project Overview

This project provides a scalable, automated, and cost-effective infrastructure for hosting multiple static websites on AWS. It is designed for managing a large number of unique domains with a centralized and version-controlled configuration.

The key features are:
- **Multi-Domain Hosting**: Serves unique content for hundreds of domains from a single infrastructure stack.
- **Fully Automated Deployment**: A GitLab CI/CD pipeline handles infrastructure provisioning, DNS configuration guidance, and content synchronization.
- **Serverless Architecture**: Built on AWS S3, CloudFront, and ACM for high availability, performance, and low operational overhead.
- **DNS Agnostic**: Integrates with external DNS management systems like OctoDNS by providing clear, machine-readable DNS record configurations.
- **Dynamic Domain Discovery**: Automatically discovers and configures new domains by simply adding a directory.

---

## 2. Architecture

The platform uses a serverless architecture composed of the following AWS services:

- **Amazon S3**: A single S3 bucket stores the content for all websites. Each website's content is organized into a directory named after the domain (e.g., `www.example.com/`).
- **Amazon CloudFront**: A single CloudFront distribution acts as the global Content Delivery Network (CDN). It uses an Origin Access Control (OAC) to securely fetch content from the S3 bucket.
- **CloudFront Function**: A lightweight JavaScript function (`url-rewrite.js`) associated with the CloudFront distribution inspects the incoming request's `Host` header and rewrites the path to point to the corresponding directory in the S3 bucket.
- **AWS Certificate Manager (ACM)**: A single multi-domain SSL/TLS certificate is automatically provisioned to cover all discovered domains, enabling HTTPS for all sites.
- **AWS IAM**: An IAM role is used by the GitLab CI/CD pipeline to grant Terraform the necessary permissions to manage the AWS resources.
- **Amazon DynamoDB**: Used by Terraform for state locking to prevent concurrent modifications to the infrastructure.

### Workflow Diagram

```
User Request (https://domain.com)
       |
       v
[ CloudFront Distribution ] -- (SSL/TLS via ACM Certificate)
       |
       |--> [ CloudFront Function: url-rewrite.js ]
       |      (Reads Host header "domain.com", rewrites path to "/domain.com/index.html")
       |
       v
[ S3 Bucket (testproject-static-content) ] -- (OAC for secure access)
       |
       |--> /domain.com/index.html
       |--> /another-domain.net/index.html
       |--> ...
```

---

## 3. Terraform Structure

The infrastructure is managed using Terraform, organized into modules for reusability and clarity.

- **`main.tf`**: The main entrypoint. It defines the providers, S3 backend, and orchestrates the modules. It contains the core logic for the automated 2-step deployment, conditionally attaching domains to CloudFront only after the ACM certificate is validated.
- **`variables.tf`**: Defines all input variables for customizing the deployment (e.g., project name, AWS region, feature flags).
- **`locals.tf`**: Contains local variables, including the logic for discovering domain names from the `config` directory and the crucial `certificate_is_validated` flag.
- **`outputs.tf`**: Defines the stack's outputs. These are highly conditional, providing DNS instructions during the initial deployment and a "Live" confirmation message after completion.
- **`modules/`**:
    - **`acm/`**: Manages the creation and validation of the multi-domain ACM certificate.
    - **`s3/`**: Manages the S3 bucket for static content.
    - **`cloudfront/`**: Manages the CloudFront distribution, CloudFront Function, and OAC.

---

## 4. Deployment Workflow (CI/CD)

The entire deployment process is automated via the `.gitlab-ci.yml` pipeline.

**Step 1: Initial `terraform apply`**
- The `deploy:infrastructure` job runs `terraform apply`.
- Terraform creates the S3 bucket, the ACM certificate (with status `PENDING_VALIDATION`), and the CloudFront distribution **without** any custom domain aliases attached yet.
- The pipeline outputs the CNAME records required for both ACM validation and for pointing the domains to the CloudFront distribution. These are formatted for easy addition to your OctoDNS configuration.

**Step 2: DNS Configuration (Manual Action)**
- You must add the CNAME records provided in the pipeline output to your DNS provider (via your OctoDNS YAML files).
- Once these records propagate, AWS can validate the ACM certificate.

**Step 3: Automated Polling and Final `terraform apply`**
- The GitLab CI pipeline automatically enters a polling loop.
- It checks the status of the ACM certificate every 30 seconds for up to 30 minutes.
- Once the script detects the certificate status has changed to `ISSUED`, it automatically triggers a **second `terraform apply`**.
- On this second run, the `local.certificate_is_validated` variable in Terraform becomes `true`.
- This conditionally adds the custom domain aliases and the validated certificate to the CloudFront distribution.
- The pipeline then outputs a "Live" confirmation message with links to the deployed sites.

**Step 4: Content Synchronization**
- A `null_resource` in Terraform with a `local-exec` provisioner runs `aws s3 sync` during the `apply` process.
- This ensures that the content from the `/config` directory is always synchronized with the S3 bucket whenever infrastructure changes are applied.

---

## 5. Domain Management

**To add a new domain:**

1.  Create a new directory inside the `/config` directory. The directory name must match the domain name (e.g., `www.new-landing-page.com`).
2.  Place your website's static files (e.g., `index.html`, `styles.css`) inside this new directory.
3.  Commit and push the changes to your GitLab repository.

The CI/CD pipeline will automatically:
- Detect the new domain.
- Add it to the ACM certificate.
- Output the new DNS records you need to add to OctoDNS.
- Deploy the content to S3.
- Attach the domain to CloudFront once its certificate is validated.

---

## 6. Content Management

**To update the content of an existing website:**

1.  Modify the files within the corresponding domain directory in `/config`.
2.  Commit and push the changes to the `main` or `master` branch.

The CI/CD pipeline is configured to automatically handle content-only updates. When you push changes to any file within the `/config` directory, a dedicated `sync:content` job is triggered. This job will:

1.  Synchronize the updated files to the S3 bucket using `aws s3 sync`.
2.  Create a CloudFront cache invalidation (`/*`) to ensure the changes are made live quickly across the globe.
