# Terraform AWS IPv6 Module

This Terraform module deploys EC2 instances with IPv6 support and an optional RDS MySQL instance on AWS. It supports creating multiple instances with different AMIs and architectures (x86_64, arm64).

## Prerequisites

- Terraform >= 1.0
- AWS Authentication configured

## Usage

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd terraform-aws-ipv6
    ```

2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

3.  **Configure Variables:**
    Create a `terraform.tfvars` file to specify your configuration. You can copy the example:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

    **Example `terraform.tfvars`:**
    ```hcl
    db_password = "your-secure-password"
    enable_rds  = true
    aws_profile = "default"

    instance_config = {
      "web-server-1" = {
        ami_base_string = "Fedora-Cloud-Base-AmazonEC2.x86_64-42-*"
        ami_owner       = "125523088429" # Fedora Project
        architecture    = "x86_64"
        instance_type   = "t3a.small"
      }
    }
    ingress_rules = {
      "SSH" = {
          port = 22
      }
      "HTTP" = {
          port = 80
      }
      "HTTPS" = {
          port = 443
      }
    }
    ```

4.  **Apply Configuration:**
    ```bash
    terraform apply
    ```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `db_password` | Password for the RDS MySQL instance. | `string` | - | yes |
| `enable_rds` | Whether to create the RDS instance and related resources. | `bool` | `true` | no |
| `aws_profile` | AWS CLI profile to use for authentication. | `string` | `null` | no |
| `public_key_file` | Path to the public key file. | `string` | `"sample_id_rsa.pub"` | no |
| `user_data_file` | Path to the cloud-init user data file. | `string` | `"cloud-init-user-data.yaml"` | no |
| `ingress_rules` | Map of ingress rules (port, optional protocol). | `map(object)` | `{SSH=22}` | no |
| `instance_config` | Map of instance configurations. See below for object structure. | `map(object)` | `{}` | no |

### `instance_config` Object Structure

| Attribute | Description | Type |
|-----------|-------------|------|
| `ami_base_string` | AMI name pattern to filter (e.g., `Fedora-Cloud-Base-*`). | `string` |
| `ami_owner` | AWS Account ID of the AMI owner. | `string` |
| `architecture` | CPU architecture (`x86_64` or `arm64`). | `string` |
| `instance_type` | (Optional) EC2 instance type. Defaults to `t3a.small` (x86) / `t4g.small` (arm64). | `string` |

## Resources Created

- **VPC**: A new VPC with IPv6 support.
- **Subnets**: Public subnets in available availability zones.
- **EC2 Instances**: Defined by `instance_config`, with encrypted root volumes and IPv6 addresses.
- **RDS Instance**: Optional MySQL database (t2.micro), accessible from the EC2 instances.
- **Security Groups**:
    - `default_ports`: Controlled by `ingress_rules` map, allows ICMP (v4/v6).
    - `allow_mysql`: Allows MySQL traffic from the EC2 instances (if RDS is enabled).
