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
