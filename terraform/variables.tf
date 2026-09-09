variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "CampfireDBPass2026!"
}

variable "alert_email" {
  type    = string
  default = "admin@campfire.local"
}