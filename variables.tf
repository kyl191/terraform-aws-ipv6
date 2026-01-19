variable "db_password" {
  type      = string
  sensitive = true
}

variable "enable_rds" {
  description = "Whether to create the RDS instance and related resources"
  type        = bool
  default     = true
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = null
}

variable "public_key_file" {
  description = "Path to the public key file"
  type        = string
  default     = "sample_id_rsa.pub"
}

variable "user_data_file" {
  description = "Path to the cloud-init user data file"
  type        = string
  default     = "cloud-init-user-data.yaml"
}

variable "ingress_rules" {
  description = "Map of ingress rules. Protocol defaults to TCP if not specified."
  type = map(object({
    port     = number
    protocol = optional(string)
  }))
  default = {
    "SSH" = {
      port = 22
    }
  }
}

variable "instance_config" {
  description = "Map of instance configurations"
  type = map(object({
    ami_base_string = string
    ami_owner       = string
    architecture    = string
    instance_type   = optional(string)
  }))
  default = {}
}
