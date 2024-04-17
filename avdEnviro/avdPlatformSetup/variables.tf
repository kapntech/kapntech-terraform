variable "avd_subscription_id" {
  type    = string
  default = "90da72fd-4e8b-4566-8304-2c234f193ea5"
}

variable "avd_resource_group_name_suffix" {
  type    = string
  default = "avd"
}

variable "avdlocation" {
  type    = string
  default = "southcentralus"
}

variable "avd_workspace_name_suffix" {
  type    = string
  default = "avd-desktop"
}

variable "avd_workspace_friendly_name" {
  type    = string
  default = "AVD Desktop Workspace"
}

variable "avd_workspace_description" {
  type    = string
  default = "AVD Desktop Workspace"
}

variable "avd_host_pool_name_suffix" {
  type    = string
  default = "avd-desktop"
}

variable "avd_host_pool_friendly_name" {
  type    = string
  default = "AVD Desktop Hostpool"
}

variable "avd_host_pool_description" {
  type    = string
  default = "AVD Desktop Hostpool"
}

variable "avd_host_pool_validate_environment" {
  type    = bool
  default = false
}

variable "avd_host_pool_custom_rdp_properties" {
  type    = string
  default = "audiocapturemode:i:1;audiomode:i:0;"
}

variable "avd_host_pool_type" {
  type    = string
  default = "Pooled"
}

variable "avd_host_pool_maximum_sessions_allowed" {
  type    = number
  default = 3
}

variable "avd_host_pool_load_balancer_type" {
  type    = string
  default = "DepthFirst"
}

variable "rfc3339" {
  type        = string
  default     = "2024-05-01T00:00:00Z"
  description = "Registration token expiration date in RFC3339 format"
}

variable "avd_application_group_name_suffix" {
  type    = string
  default = "avd-desktop1"
}

variable "avd_application_group_type" {
  type    = string
  default = "Desktop"
}

variable "avd_application_group_friendly_name" {
  type    = string
  default = "AVD Desktop Application Group"
}

variable "avd_application_group_description" {
  type    = string
  default = "AVD Desktop Application Group"
}