# Fivetran Terraform Pipeline — Enterprise Production Demo

A fully reusable, production-grade Terraform configuration that provisions a Fivetran data
pipeline from a public REST API into a destination warehouse on **AWS** or **Azure**.
All infrastructure is declared as code, version-controlled, and parameterised via variables —
no manual Fivetran dashboard interaction required.

Supported destinations:

| Cloud | Service | `destination_service` value |
|---|---|---|
| AWS | PostgreSQL / RDS | `postgres_rds_warehouse` |
| AWS | Snowflake | `snowflake` |
| Azure | Azure SQL Database / Synapse | `azure_sql_warehouse` |
| Azure | Azure SQL Managed Instance | `azure_sql_managed_instance` |

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Project Structure](#3-project-structure)
4. [Step 1 — Get Fivetran API Credentials](#4-step-1--get-fivetran-api-credentials)
5. [Step 2 — Get Your Fivetran Group ID](#5-step-2--get-your-fivetran-group-id)
6. [Step 3 — Prepare Your Destination](#6-step-3--prepare-your-destination)
   - [Option A — AWS PostgreSQL / RDS](#option-a--aws-postgresql--rds)
   - [Option B — AWS Snowflake](#option-b--aws-snowflake)
   - [Option C — Azure SQL / Synapse](#option-c--azure-sql--synapse)
7. [Step 4 — Configure Variables](#7-step-4--configure-variables)
8. [Step 5 — Initialise Terraform](#8-step-5--initialise-terraform)
9. [Step 6 — Plan](#9-step-6--plan)
10. [Step 7 — Apply](#10-step-7--apply)
11. [Step 8 — Verify the Pipeline](#11-step-8--verify-the-pipeline)
12. [Step 9 — Add More Connectors](#12-step-9--add-more-connectors)
13. [Step 10 — Tear Down](#13-step-10--tear-down)
14. [Networking Options](#14-networking-options)
    - [Direct Connection](#direct-connection)
    - [SSH Tunnel (AWS)](#ssh-tunnel-aws)
    - [PrivateLink (AWS)](#privatelink-aws)
    - [Private Endpoint (Azure)](#private-endpoint-azure)
15. [Environment Separation (dev / staging / prod)](#15-environment-separation-dev--staging--prod)
16. [Remote State (Production Recommended)](#16-remote-state-production-recommended)
    - [AWS S3 + DynamoDB](#aws-s3--dynamodb)
    - [Azure Blob Storage](#azure-blob-storage)
17. [Security Best Practices](#17-security-best-practices)
18. [Troubleshooting](#18-troubleshooting)

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Terraform (IaC)                       │
│  variables.tf ──► main.tf ──► outputs.tf                 │
│                      │                                   │
│            fivetran/fivetran provider v1.9               │
└──────────────────────────────┬───────────────────────────┘
                               │ terraform apply
                               ▼
                      Fivetran Platform
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
  fivetran_destination  fivetran_connector  fivetran_connector_schedule
  (RDS / Snowflake /    (webhooks /         (sync every N minutes)
   Azure SQL / Synapse)  REST API source)
          │
          │  sync
          ▼
  Destination Warehouse
  └── schema: jsonplaceholder_users
      └── table: users  (id, name, email, phone, …)
```

**Data flow:**
1. `terraform apply` creates the destination, connector, and schedule in Fivetran.
2. Fivetran executes the first sync, pulling data from `https://jsonplaceholder.typicode.com/users`.
3. Rows land in the destination warehouse under the configured schema.

---

## 2. Prerequisites

Complete every item in this section before running any Terraform commands.

---

### 2.1 Required Tools

| Tool | Minimum Version | Purpose | Install |
|---|---|---|---|
| Terraform | 1.3+ | Provision all infrastructure | https://developer.hashicorp.com/terraform/install |
| Git | 2.x | Clone the repo | https://git-scm.com/downloads |
| AWS CLI | 2.x | Manage AWS resources (RDS, S3, IAM) | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Azure CLI | 2.x | Manage Azure resources (SQL, Storage) | https://learn.microsoft.com/en-us/cli/azure/install-azure-cli |
| psql | 14+ | Connect to PostgreSQL / RDS to run setup SQL | https://www.postgresql.org/download |
| jq | 1.6+ | Parse Terraform JSON outputs in shell scripts | https://stedolan.github.io/jq/download |

> You only need AWS CLI **or** Azure CLI depending on your chosen destination.

---

### 2.2 Install Terraform

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Ubuntu / Debian:**
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform
```

**Windows (Chocolatey):**
```powershell
choco install terraform
```

Verify:
```bash
terraform version
# Terraform v1.x.x
```

---

### 2.3 Install AWS CLI (AWS destinations only)

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

**Windows:**
Download and run: https://awscli.amazonaws.com/AWSCLIV2.msi

Configure with your credentials:
```bash
aws configure
# AWS Access Key ID:     <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name:   us-east-1
# Default output format: json
```

Verify:
```bash
aws sts get-caller-identity
```

---

### 2.4 Install Azure CLI (Azure destinations only)

**macOS:**
```bash
brew install azure-cli
```

**Linux (Ubuntu/Debian):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Windows:**
Download and run: https://aka.ms/installazurecliwindows

Log in and set your subscription:
```bash
az login
az account set --subscription "<your-subscription-id>"
az account show   # confirm correct subscription is active
```

---

### 2.5 Fivetran Account

- Sign up or log in at https://fivetran.com
- You need a **paid plan or active trial** — the free tier does not support API-based provisioning
- Ensure your account has permission to create **Destinations** and **Connectors**
- You will need your **API Key** and **API Secret** (generated in Step 1)

---

### 2.6 Destination Database Access

Depending on your chosen destination, you need one of the following already provisioned
and reachable before running `terraform apply`:

| Destination | What you need ready |
|---|---|
| AWS PostgreSQL / RDS | Running RDS instance, master credentials, security group ID |
| AWS Snowflake | Snowflake account on AWS, admin login to run setup SQL |
| Azure SQL / Synapse | Azure SQL server created, admin login, resource group name |

> Terraform provisions the **Fivetran resources** (destination config, connector, schedule).
> It does not create the underlying database server itself — that must exist first.

---

### 2.7 Network Access

Fivetran's servers must be able to reach your destination database.
Before applying, ensure:

- Fivetran's IP ranges are allowlisted in your firewall / security group / NSG
- Full IP list: https://fivetran.com/docs/using-fivetran/ips
- For private databases, set up an SSH tunnel or PrivateLink first (see [Networking Options](#14-networking-options))

---

### 2.8 Clone the Repository

```bash
git clone https://github.com/sonbarse17/fivetran-terraform-pipeline.git
cd fivetran-terraform-pipeline/iac/fivetran-pipeline
```

---

### 2.9 Quick Prerequisites Checklist

Before moving to Step 1, confirm all of the following:

- [ ] Terraform 1.3+ installed and `terraform version` returns successfully
- [ ] Git installed
- [ ] AWS CLI configured (`aws sts get-caller-identity` works) — if using AWS
- [ ] Azure CLI logged in (`az account show` works) — if using Azure
- [ ] Fivetran account active with API access
- [ ] Destination database server is running and reachable
- [ ] Fivetran IP ranges allowlisted in your firewall / security group
- [ ] Repository cloned locally

---

## 3. Project Structure

```
fivetran-terraform-pipeline/         <- repo root
├── README.md                        # This guide (rendered on GitHub)
├── .gitignore
├── connector/                       # Fivetran Connector SDK - data sync script
│   ├── connector.py                 # Fetches users from REST API, upserts to destination
│   └── requirements.txt             # Python dependencies (requests)
└── iac/
    └── fivetran-pipeline/
        ├── main.tf                  # Provider, destination, connectors, schedules
        ├── variables.tf             # All input variables with types, descriptions, defaults
        ├── outputs.tf               # destination_id, connector_ids, schemas
        ├── terraform.tfvars.example # Template - copy to terraform.tfvars and fill in values
        └── .terraform.lock.hcl     # Pinned provider version (committed for reproducibility)
```

### What each file does

| File | Purpose |
|---|---|
| `connector/connector.py` | Python script Fivetran runs on every sync. Calls the JSONPlaceholder API, flattens nested address and company fields, upserts rows into the destination. |
| `connector/requirements.txt` | Python dependencies installed by Fivetran before running the script. |
| `iac/fivetran-pipeline/main.tf` | Declares the Fivetran provider, destination, connector, and schedule resources. |
| `iac/fivetran-pipeline/variables.tf` | All input variables - credentials, destination type, region, connector list. |
| `iac/fivetran-pipeline/outputs.tf` | Outputs destination_id, connector_ids, connector_schemas after apply. |
| `iac/fivetran-pipeline/terraform.tfvars.example` | Copy this to terraform.tfvars and fill in your values. Never commit terraform.tfvars. |

---

## 4. Step 1 — Get Fivetran API Credentials

1. Log in to the Fivetran dashboard at https://fivetran.com/dashboard
2. Click your avatar (top-right) → **Account Settings**
3. Go to the **API Keys** tab
4. Click **Generate API Key**
5. Copy both the **API Key** and **API Secret** — the secret is shown only once

You will use these as `fivetran_api_key` and `fivetran_api_secret`.

---

## 5. Step 2 — Get Your Fivetran Group ID

A Fivetran **Group** is the organisational container (workspace) that holds your
destinations and connectors. Every Fivetran account has at least one group created
automatically — you do **not** need to add a destination first to get the group ID.

---

### The easiest way — read it from the URL

When you click **Destinations** → **Add destination** in the Fivetran dashboard, look at
the browser URL bar:

```
https://fivetran.com/dashboard/add-destination?groupId=narrowest_settler
                                                         ^^^^^^^^^^^^^^^^
                                                         this is your group_id
```

The value after `groupId=` in the URL is your group ID. Copy it directly into
`terraform.tfvars`:

```hcl
group_id = "narrowest_settler"   # replace with your actual value from the URL
```

> Your group ID will be a short hyphenated word pair like `narrowest_settler`,
> `bright_compass`, etc. — Fivetran auto-generates these names.

---

### Option B — Find it via the Fivetran API

```bash
curl -s https://api.fivetran.com/v1/groups \
  -H "Authorization: Basic $(echo -n '<API_KEY>:<API_SECRET>' | base64)" \
  | jq '.data.items[] | {id, name}'
```

This lists all groups in your account with their IDs and names.

---

### Option C — Create a brand new group

If you want a fresh isolated group for this pipeline:

```bash
curl -X POST https://api.fivetran.com/v1/groups \
  -H "Authorization: Basic $(echo -n '<API_KEY>:<API_SECRET>' | base64)" \
  -H "Content-Type: application/json" \
  -d '{"name": "fivetran-demo-pipeline"}'
```

The `"id"` field in the response is your new `group_id`. Terraform will then create
the destination and connectors inside this group when you run `terraform apply`.

---

## 6. Step 3 — Prepare Your Destination

Choose one destination and follow the relevant section.

---

### Option A — AWS PostgreSQL / RDS

You need a running PostgreSQL instance (RDS, Aurora PostgreSQL, or self-hosted on EC2) with:

- A database created for Fivetran to write into
- A user with `CREATE SCHEMA`, `CREATE TABLE`, `INSERT`, `UPDATE`, `DELETE` privileges
- Port 5432 open to Fivetran's IP ranges in your RDS security group

**Create the Fivetran user (run as superuser):**

```sql
CREATE USER fivetran_user WITH PASSWORD 'your_strong_password';
CREATE DATABASE fivetran_demo;
GRANT ALL PRIVILEGES ON DATABASE fivetran_demo TO fivetran_user;
```

**Allow Fivetran IPs in your RDS Security Group (AWS Console or CLI):**

```bash
# Example: allow Fivetran US_EAST_1 CIDR (check current list at fivetran.com/docs)
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 5432 \
  --cidr 52.0.2.4/32
```

Full Fivetran IP list: https://fivetran.com/docs/using-fivetran/ips

Variables you will need:
```hcl
destination_service = "postgres_rds_warehouse"
region              = "US_EAST_1"
db_host             = "mydb.abc123.us-east-1.rds.amazonaws.com"
db_port             = 5432
db_name             = "fivetran_demo"
db_user             = "fivetran_user"
db_password         = "your_strong_password"
connection_type     = "Directly"
```

---

### Option B — AWS Snowflake

You need a Snowflake account hosted on AWS with a database and warehouse created.

**Run in a Snowflake worksheet:**

```sql
CREATE DATABASE FIVETRAN_DEMO;
CREATE WAREHOUSE FIVETRAN_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE ROLE FIVETRAN_ROLE;
CREATE USER FIVETRAN_USER
  PASSWORD = 'your_strong_password'
  DEFAULT_ROLE = FIVETRAN_ROLE
  DEFAULT_WAREHOUSE = FIVETRAN_WH;

GRANT ROLE FIVETRAN_ROLE TO USER FIVETRAN_USER;
GRANT USAGE ON WAREHOUSE FIVETRAN_WH TO ROLE FIVETRAN_ROLE;
GRANT ALL ON DATABASE FIVETRAN_DEMO TO ROLE FIVETRAN_ROLE;
```

Variables you will need:
```hcl
destination_service = "snowflake"
region              = "US_EAST_1"
snowflake_account   = "xy12345.us-east-1"   # from your Snowflake account URL
snowflake_database  = "FIVETRAN_DEMO"
snowflake_warehouse = "FIVETRAN_WH"
snowflake_role      = "FIVETRAN_ROLE"
snowflake_user      = "FIVETRAN_USER"
snowflake_password  = "your_strong_password"
```

---

### Option C — Azure SQL / Synapse

You need an Azure SQL Database or Synapse Analytics workspace with:

- A SQL login with `db_owner` or equivalent permissions on the target database
- Port 1433 open to Fivetran's IP ranges in your Azure SQL firewall rules

**Create the database and Fivetran login (run as admin in Azure SQL):**

```sql
-- Run on master
CREATE LOGIN fivetran_user WITH PASSWORD = 'your_strong_password!1';

-- Run on your target database
CREATE USER fivetran_user FOR LOGIN fivetran_user;
ALTER ROLE db_owner ADD MEMBER fivetran_user;
```

**Allow Fivetran IPs in Azure SQL Firewall (Azure CLI):**

```bash
# Example: allow a Fivetran IP range (check current list at fivetran.com/docs)
az sql server firewall-rule create \
  --resource-group myResourceGroup \
  --server myserver \
  --name fivetran-allow \
  --start-ip-address 52.0.2.4 \
  --end-ip-address 52.0.2.4
```

Full Fivetran IP list: https://fivetran.com/docs/using-fivetran/ips

Variables you will need:
```hcl
destination_service = "azure_sql_warehouse"   # or azure_sql_managed_instance
region              = "AZURE_EAST_US"
azure_sql_server    = "myserver.database.windows.net"
azure_sql_database  = "fivetran_demo"
azure_sql_user      = "fivetran_user"
azure_sql_password  = "your_strong_password!1"
azure_sql_port      = 1433
```

---

## 7. Step 4 — Configure Variables

Copy the example file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and fill in the values for your chosen destination.
**Never commit `terraform.tfvars` to version control** — it contains secrets.

Add it to `.gitignore`:

```bash
echo "terraform.tfvars" >> .gitignore
echo ".terraform/" >> .gitignore
echo "*.tfstate" >> .gitignore
echo "*.tfstate.backup" >> .gitignore
```

---

## 8. Step 5 — Initialise Terraform

From the `iac/fivetran-pipeline/` directory:

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding fivetran/fivetran versions matching "~> 1.9"...
- Installing fivetran/fivetran v1.9.26...
Terraform has been successfully initialized!
```

---

## 9. Step 6 — Plan

Review what Terraform will create before applying:

```bash
terraform plan
```

You should see **3 resources to add**:
- `fivetran_destination.demo_dest`
- `fivetran_connector.connectors["jsonplaceholder"]`
- `fivetran_connector_schedule.schedules["jsonplaceholder"]`

And **5 outputs**:
- `destination_id`
- `destination_service`
- `connector_ids`
- `connector_schemas`
- `destination_schema`

If the plan looks correct, proceed to apply.

---

## 10. Step 7 — Apply

```bash
terraform apply
```

Type `yes` when prompted. Terraform will:

1. Create the `fivetran_destination` resource and run setup tests against your DB
   (if `run_setup_tests = true`). This validates the connection before proceeding.
2. Create the `fivetran_connector` resource pointing at the webhooks source.
3. Create the `fivetran_connector_schedule` to activate syncing every 60 minutes.

Expected output on success:
```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

connector_ids = {
  "jsonplaceholder" = "connector_abc123"
}
connector_schemas = {
  "jsonplaceholder" = "jsonplaceholder_users"
}
destination_id      = "dest_xyz789"
destination_schema  = "jsonplaceholder_users"
destination_service = "postgres_rds_warehouse"
```

> If `run_setup_tests = true` and the destination connection fails, Terraform will error
> here with the Fivetran connection test failure message. Fix the DB credentials or
> network access and re-run `terraform apply`.

---

## 11. Step 8 — Verify the Pipeline

### Check Fivetran Dashboard

1. Go to https://fivetran.com/dashboard/connectors
2. You should see the `jsonplaceholder_users` connector listed
3. Click it — the status should show **Syncing** or **Synced**
4. The first sync runs automatically within a few minutes of creation

### Trigger a Manual Sync (optional)

```bash
CONNECTOR_ID=$(terraform output -json connector_ids | jq -r '.jsonplaceholder')

curl -X POST \
  "https://api.fivetran.com/v1/connectors/${CONNECTOR_ID}/sync" \
  -H "Authorization: Basic $(echo -n '<API_KEY>:<API_SECRET>' | base64)"
```

### Query the Destination — AWS PostgreSQL / RDS

```sql
-- Check the schema was created
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'jsonplaceholder_users';

-- Row count
SELECT COUNT(*) FROM jsonplaceholder_users.users;

-- Preview
SELECT id, name, email, username
FROM jsonplaceholder_users.users
LIMIT 10;
```

Expected: 10 rows matching https://jsonplaceholder.typicode.com/users

### Query the Destination — AWS Snowflake

```sql
USE DATABASE FIVETRAN_DEMO;
SELECT COUNT(*) FROM JSONPLACEHOLDER_USERS.USERS;
SELECT ID, NAME, EMAIL FROM JSONPLACEHOLDER_USERS.USERS LIMIT 10;
```

### Query the Destination — Azure SQL / Synapse

```sql
-- Row count
SELECT COUNT(*) FROM jsonplaceholder_users.users;

-- Preview
SELECT TOP 10 id, name, email, username
FROM jsonplaceholder_users.users;
```

Or via Azure CLI:

```bash
az sql db query \
  --resource-group myResourceGroup \
  --server myserver \
  --name fivetran_demo \
  --query "SELECT TOP 10 id, name, email FROM jsonplaceholder_users.users"
```

---

## 12. Step 9 — Add More Connectors

To add a second connector, edit `terraform.tfvars` and add an object to the `connectors` list:

```hcl
connectors = [
  {
    name           = "jsonplaceholder"
    service        = "webhooks"
    schema_name    = "jsonplaceholder_users"
    sync_frequency = 60
    paused         = false
  },
  {
    name           = "salesforce"
    service        = "salesforce"
    schema_name    = "salesforce_crm"
    sync_frequency = 360
    paused         = false
  }
]
```

Then run:

```bash
terraform plan   # review — should show 2 new resources for the salesforce connector
terraform apply
```

Terraform adds only the new connector resources without touching existing ones.

---

## 13. Step 10 — Tear Down

To destroy all provisioned resources:

```bash
terraform destroy
```

Type `yes` when prompted. This deletes the connector schedule, connector, and destination.

> Data already synced into your warehouse is NOT deleted by Terraform destroy.
> Drop the schema manually if needed:
>
> PostgreSQL / RDS:
> ```sql
> DROP SCHEMA jsonplaceholder_users CASCADE;
> ```
>
> Snowflake:
> ```sql
> DROP SCHEMA FIVETRAN_DEMO.JSONPLACEHOLDER_USERS;
> ```
>
> Azure SQL:
> ```sql
> DROP SCHEMA jsonplaceholder_users;
> ```

---

## 14. Networking Options

### Direct Connection

The default. Fivetran connects directly to your database host over the public internet.
Ensure Fivetran's IP ranges are allowlisted in your firewall/security group.

```hcl
connection_type = "Directly"
```

---

### SSH Tunnel (AWS)

Use when your RDS instance is in a private subnet behind a bastion host.

```hcl
connection_type = "SshTunnel"
tunnel_host     = "bastion.example.com"   # public IP or DNS of your EC2 bastion
tunnel_port     = 22
tunnel_user     = "ec2-user"
```

Add Fivetran's public SSH key to the bastion's `~/.ssh/authorized_keys`.
Get the key from the Fivetran dashboard under the destination's **Setup** tab.

Your bastion security group needs:
- Inbound: port 22 from Fivetran IP ranges
- Outbound: port 5432 to the RDS security group

---

### PrivateLink (AWS)

Use AWS PrivateLink to keep traffic entirely within the AWS network.

```hcl
connection_type = "PrivateLink"
db_host         = "vpce-xxxxxxxx.rds.us-east-1.vpce.amazonaws.com"
```

Steps:
1. Create a VPC endpoint for your RDS instance
2. Share the endpoint DNS with Fivetran
3. Contact Fivetran support to enable PrivateLink for your account
4. Set `connection_type = "PrivateLink"` and use the private endpoint as `db_host`

---

### Private Endpoint (Azure)

Use Azure Private Endpoint to keep traffic within the Azure network.

1. Create a Private Endpoint for your Azure SQL server in the Azure Portal
2. Note the private IP address assigned to the endpoint
3. Set `azure_sql_server` to the private IP or private DNS name
4. Ensure Fivetran's Azure-hosted infrastructure can reach the private endpoint
   (requires Fivetran's Azure Private Link feature — contact Fivetran support)

---

## 15. Environment Separation (dev / staging / prod)

Use separate `.tfvars` files per environment:

```
iac/fivetran-pipeline/
├── envs/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
```

Deploy to a specific environment:

```bash
terraform plan  -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"

terraform plan  -var-file="envs/prod.tfvars"
terraform apply -var-file="envs/prod.tfvars"
```

Example `envs/prod.tfvars` (Azure Synapse):

```hcl
fivetran_api_key    = "prod_key"
fivetran_api_secret = "prod_secret"
group_id            = "prod_group_id"

destination_service = "azure_sql_warehouse"
region              = "AZURE_EAST_US"
run_setup_tests     = true

azure_sql_server   = "prod-server.database.windows.net"
azure_sql_database = "prod_dw"
azure_sql_user     = "fivetran_prod"
azure_sql_password = "prod_password!1"
azure_sql_port     = 1433

connectors = [
  {
    name           = "jsonplaceholder"
    service        = "webhooks"
    schema_name    = "jsonplaceholder_users"
    sync_frequency = 60
    paused         = false
  }
]
```

---

## 16. Remote State (Production Recommended)

### AWS S3 + DynamoDB

Add a `backend` block to `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "fivetran-pipeline/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
  ...
}
```

Create the resources:

```bash
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Then re-initialise:

```bash
terraform init -migrate-state
```

---

### Azure Blob Storage

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "fivetran-pipeline/terraform.tfstate"
  }
  ...
}
```

Create the resources:

```bash
az group create --name terraform-state-rg --location eastus

az storage account create \
  --name tfstateaccount \
  --resource-group terraform-state-rg \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name tfstate \
  --account-name tfstateaccount
```

Then re-initialise:

```bash
terraform init -migrate-state
```

---

## 17. Security Best Practices

| Practice | How |
|---|---|
| Never commit secrets | Add `terraform.tfvars` to `.gitignore` |
| Mark secrets as sensitive | All secret variables have `sensitive = true` in `variables.tf` |
| Use environment variables in CI/CD | Set `TF_VAR_fivetran_api_key=...` instead of writing to a file |
| Rotate API keys regularly | Regenerate in Fivetran dashboard, update tfvars, re-apply |
| Encrypt remote state | `encrypt = true` on S3 backend; Azure Blob encrypts at rest by default |
| Least-privilege DB user | Grant only the permissions Fivetran needs (see Step 3) |
| Use PrivateLink / Private Endpoint in prod | Avoid public internet exposure for production databases |
| Use Azure Key Vault / AWS Secrets Manager | Store secrets centrally and reference via data sources |

**Using environment variables instead of tfvars (CI/CD friendly):**

```bash
export TF_VAR_fivetran_api_key="your_key"
export TF_VAR_fivetran_api_secret="your_secret"
export TF_VAR_db_password="your_password"

terraform apply -var-file="envs/prod.tfvars"
```

---

## 18. Troubleshooting

**`Error: 401 Unauthorized` during plan/apply**
- Double-check `fivetran_api_key` and `fivetran_api_secret`
- Ensure the API key has not been revoked in the Fivetran dashboard

**`Error: connection test failed` during apply**
- Fivetran cannot reach your database — check firewall rules and allowlist Fivetran IPs
- Verify host, port, user, and password are correct
- Set `run_setup_tests = false` temporarily to skip the test and debug manually

**`Error: group not found`**
- The `group_id` does not exist in your Fivetran account
- Re-check the group ID from the dashboard URL or API (see Step 2)

**`Error: destination_service validation failed`**
- Only `postgres_rds_warehouse`, `snowflake`, `azure_sql_warehouse`, and
  `azure_sql_managed_instance` are supported
- Check for typos in your `terraform.tfvars`

**Connector shows status `failed` in dashboard**
- The webhooks connector requires an external push — this is expected for the demo
- For a live REST API pull, replace `service = "webhooks"` with a supported connector
  type (e.g. a Fivetran Function connector or Connector SDK deployment)

**Azure SQL: `Login failed for user`**
- Ensure the login was created on `master` and the user was created on the target database
- Azure SQL requires SQL Authentication to be enabled on the server
  (Azure Portal → SQL Server → Settings → Azure Active Directory → check SQL auth is on)

**`terraform destroy` hangs**
- Fivetran may be mid-sync — pause the connector first then destroy:
  ```bash
  terraform apply -var='connectors=[{name="jsonplaceholder",service="webhooks",schema_name="jsonplaceholder_users",sync_frequency=60,paused=true}]'
  terraform destroy
  ```

**State drift after manual dashboard changes**
- Run `terraform refresh` to reconcile state with actual Fivetran resources
- Then run `terraform plan` to see the diff
