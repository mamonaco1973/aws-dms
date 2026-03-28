# CLAUDE.md — aws-dms

## Project Overview

This project demonstrates **AWS Database Migration Service (DMS)** by migrating
the **Sakila** sample database from a MySQL RDS instance (source) to a
PostgreSQL RDS instance (target).

Sakila is MySQL's official sample database — a DVD rental store schema with
actors, films, customers, rentals, payments, and inventory. It exercises a
broad range of data types and relationships, making it a realistic migration
source. The goal is to show DMS performing a heterogeneous full-load migration
(MySQL → PostgreSQL) with automatic schema and data type conversion.

The infrastructure is deployed in two phases:

1. **RDS** — MySQL and PostgreSQL RDS instances, web admin UIs (phpMyAdmin for
   MySQL source, pgweb for PostgreSQL target), VPC, secrets, and IAM.
2. **DMS** — *(planned)* Replication instance, source/target endpoints, and a
   full-load migration task from MySQL `sakila` to PostgreSQL.

## Project Structure

```
aws-dms/
├── 01-rds/                    # Phase 1: RDS instances and admin UIs
│   ├── data/                  # SQL query examples (reference only)
│   ├── scripts/
│   │   ├── install_pgweb.sh   # Installs pgweb on port 80; PostgreSQL target
│   │   │                      #   starts empty — DMS populates it
│   │   └── install-phpmyadmin.sh  # Installs phpMyAdmin on port 80; downloads
│   │                              #   and loads Sakila into MySQL source
│   ├── main.tf                # AWS provider (us-east-2)
│   ├── networking.tf          # VPC 10.0.0.0/24, two public subnets
│   │                          #   (us-east-2a/2b), IGW, route table
│   ├── postgres.tf            # PostgreSQL RDS instance + DB subnet group
│   ├── mysql.tf               # MySQL 8.4 RDS instance + parameter group
│   ├── pgweb.tf               # pgweb EC2 (Ubuntu 24.04, t3.medium)
│   ├── phypmyadmin.tf         # phpMyAdmin EC2 (Ubuntu 24.04, t3.medium)
│   ├── secret.tf              # Random passwords; Secrets Manager entries for
│   │                          #   postgres-credentials and mysql-credentials
│   ├── security.tf            # rds_sg (TCP/5432), http_sg (TCP/80)
│   └── role.tf                # IAM role EC2SSMRole-PGWeb-Admin with SSM
│                              #   access for pgweb and phpMyAdmin instances
├── apply.sh                   # Provisions 01-rds then calls validate.sh
├── check_env.sh               # Validates aws, terraform, jq in PATH and
│                              #   AWS CLI authentication
├── destroy.sh                 # Tears down all infrastructure
└── validate.sh                # Prints pgweb and RDS endpoint URLs
```

## Deployment Workflow

### Prerequisites

- `terraform` >= 1.5.0
- `aws` CLI configured with credentials for us-east-2
- `jq`

### Deploy

```bash
./check_env.sh   # Validate tools and AWS credentials
./apply.sh       # Provision 01-rds then print endpoints
```

### Destroy

```bash
./destroy.sh     # Full cleanup
```

## Phase Details

### Phase 1 — RDS (`01-rds/`) — us-east-2

- VPC `rds-vpc` (`10.0.0.0/24`)
- Public subnet `rds-subnet-1` (`10.0.0.0/26`, `us-east-2a`)
- Public subnet `rds-subnet-2` (`10.0.0.64/26`, `us-east-2b`)
- Internet Gateway and route table for public access

**MySQL RDS** (`mysql-rds-instance`) — DMS source:
- Engine: MySQL 8.4, `db.t4g.micro`, `gp3`
- Multi-AZ standby enabled; publicly accessible
- Master user: `admin`; initial database: `mydb`
- Custom parameter group: `log_bin_trust_function_creators = 1`
- Credentials in Secrets Manager: `mysql-credentials`
  (`user`, `password`, `endpoint`)

**PostgreSQL RDS** (`postgres-rds-instance`) — DMS target:
- Engine: PostgreSQL (default latest version), `db.t4g.micro`, `gp3`
- Multi-AZ standby enabled; publicly accessible
- Master user: `postgres`; database: `postgres`
- Starts empty — DMS creates the Sakila schema and loads all data
- Credentials in Secrets Manager: `postgres-credentials`
  (`user`, `password`, `endpoint`)

**phpMyAdmin EC2** (`phpmyadmin-rds`) — source admin UI:
- Ubuntu 24.04, `t3.medium`, `rds-subnet-1`, public IP
- `install-phpmyadmin.sh` at boot:
  - Installs phpMyAdmin on TCP/80, connecting to the MySQL RDS endpoint
  - Downloads `sakila-db.zip` from `downloads.mysql.com`
  - Loads `sakila-schema.sql` then `sakila-data.sql` into MySQL `sakila`
    database — this is the DMS migration source

**pgweb EC2** (`pgweb-deployment`) — target admin UI:
- Ubuntu 24.04, `t3.medium`, `rds-subnet-1`, public IP
- `install_pgweb.sh` at boot: installs pgweb as a systemd service on
  TCP/80; connects to PostgreSQL RDS; no data pre-loaded (DMS populates it)

### Phase 2 — DMS (`02-dms/`) — us-east-2 *(planned)*

Planned resources:
- **DMS replication subnet group** — spans both RDS subnets
- **DMS replication instance** — placed in the VPC
- **Source endpoint** — MySQL: `mysql-rds-instance`, port 3306,
  database `sakila`, user `admin`
- **Target endpoint** — PostgreSQL: `postgres-rds-instance`, port 5432,
  database `postgres`, user `postgres`
- **Replication task** — full-load migration, `TargetTablePrepMode =
  DROP_AND_CREATE`, migration type `full-load`

## Sakila Database

Sakila is MySQL's official sample database representing a DVD rental store.
Key tables migrated by DMS:

| Table | Rows (approx) | Description |
|---|---|---|
| `actor` | 200 | Actor names |
| `film` | 1000 | Film titles, descriptions, ratings |
| `film_actor` | 5462 | Actor-film join |
| `category` | 16 | Film categories |
| `inventory` | 4581 | Physical copies |
| `customer` | 599 | Customer records |
| `rental` | 16044 | Rental transactions |
| `payment` | 14596 | Payment records |
| `address` / `city` / `country` | ~600/600/109 | Location data |

DMS handles MySQL → PostgreSQL type mapping automatically: `TINYINT(1)` →
`boolean`, `DATETIME` → `timestamp`, inline `ENUM` → `character varying`,
`AUTO_INCREMENT` → integer (sequences not created by default). Stored
procedures and triggers are not migrated — full-load moves table data only.

## Important Notes

- **MySQL security group gap**: `rds_sg` currently only opens TCP/5432
  (PostgreSQL). MySQL RDS uses `rds_sg` but listens on TCP/3306. Port 3306
  must be added to `rds_sg` ingress before phpMyAdmin or DMS can reach MySQL.

- **DMS replication instance networking**: The DMS replication instance must
  be in the same VPC (`rds-vpc`) as both RDS instances. The replication
  instance's security group must be allowed to reach port 3306 (MySQL source)
  and port 5432 (PostgreSQL target) in `rds_sg`.

- **DMS creates the target schema**: With `TargetTablePrepMode = DROP_AND_CREATE`
  DMS introspects the MySQL source and creates corresponding tables on
  PostgreSQL automatically. No pre-created schema is needed on the target.

- **`log_bin_trust_function_creators`**: Set to `1` on the MySQL parameter
  group. Required for DMS to create helper routines on the MySQL source
  during migration setup.

- **validate.sh references Aurora**: The current `validate.sh` attempts to
  resolve an `aurora-postgres-cluster` endpoint that does not exist in this
  project. This should be cleaned up when the script is updated for Phase 2.

- **Region**: This project uses `us-east-2` (Ohio), not `us-east-1`.
  All `AWS_DEFAULT_REGION` exports and Terraform provider configs must
  target `us-east-2`.

- **Local Terraform state only** — no backend configured. Never commit
  `*.tfstate` or `*.tfstate.backup`.

- **Secret deletion**: Both Secrets Manager secrets use
  `recovery_window_in_days = 0` — deletion is immediate on `terraform
  destroy`. No recovery window.

## Key IAM Resources

| Resource | Purpose |
|---|---|
| `EC2SSMRole-PGWeb-Admin` | EC2 instance role for pgweb and phpMyAdmin |
| `AmazonSSMManagedInstanceCore` | SSM Session Manager access |
| `AmazonSSMFullAccess` | Full SSM access (should be scoped down for prod) |

## Code Commenting Standards

Claude should apply consistent, professional commenting when modifying code.

### General Rules

- Keep comment lines **≤ 80 characters**
- Do **not change code behavior**
- Preserve existing variable names and structure
- Comments should explain **intent**, not restate obvious code
- Prefer concise, structured comments

### Terraform Files

```hcl
# ================================================================================
# Section Name
# Description of resources created in this block
# ================================================================================
```

Comments should explain **why infrastructure exists**, not repeat the resource
definition.

### Shell Scripts

```bash
# ================================================================================
# Section Name
# Purpose of this block
# ================================================================================

# ------------------------------------------------------------------------------
# Subsection Name
# Brief operational note
# ------------------------------------------------------------------------------
```

- Preserve strict bash style: `set -euo pipefail`
- Keep scripts idempotent where possible
- Explain why a command block exists, not what obvious flags do
