variable "avd_subscription_id" {
  type    = string
  default = "90da72fd-4e8b-4566-8304-2c234f193ea5"
}

variable "avdlocation" {
  type    = string
  default = "southcentralus"
}


variable "avd_resource_group_name_suffix" {
  type    = string
  default = "avd-infra"
}

variable "avd_rdsh_count" {
  type    = number
  default = 1
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

variable "avd_host_pool_validate_environment" {
  type    = bool
  default = false
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
  default     = "20224-05-01T00:00:00Z"
  description = "Registration token expiration date in RFC3339 format"
}

variable "avd_host_pool_registration_expiration_date_length" {
  type    = string
  default = "48h"
}

variable "avd_application_group_name_suffix" {
  type    = string
  default = "avd-desktop1"
}

variable "avd_application_group_friendly_name" {
  type    = string
  default = "AVD Desktop Application Group"
}

variable "avd_application_group_description" {
  type    = string
  default = "AVD Desktop Application Group"
}

variable "avd_application_group_type" {
  type    = string
  default = "Desktop"
}


variable "avd_vnet_name_suffix" {
  type    = string
  default = "avd"
}

variable "avd_remote_vnet_peer_name_suffix" {
  type    = string
  default = "adds"
}

variable "avd_remote_peer_vnet_id" {
  type    = string
  default = "/subscriptions/90da72fd-4e8b-4566-8304-2c234f193ea5/resourceGroups/rg-adds/providers/Microsoft.Network/virtualNetworks/vnet-adds"
}

variable "avd_vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}


variable "avd_subnet_name_suffix" {
  type    = string
  default = "internal"
}


variable "avd_subnet_address_prefixes" {
  type    = list(string)
  default = ["172.0.10.0/24"]
}

variable "avd_nic_ip_configuration_name" {
  type    = string
  default = "sessionhosts"
}

variable "avd_nic_private_ip_allocation" {
  type    = string
  default = "Dynamic"
}


variable "avd_host_pool_session_host_vm_name_suffix" {
  type    = string
  default = "vddtsh"
}

variable "domain_name" {
  type    = string
  default = "kapntech.com"
}

variable "ou_path" {
  type    = string
  default = ""
}

variable "domain_user_upn" {
  type    = string
  default = "domainjoineruser"
}

variable "domain_user_password" {
  type      = string
  default   = "ChangeMe123!"
  sensitive = true
}

variable "avd_vm_size" {
  type    = string
  default = "Standard_DS1_v2"
}

variable "avd_vm_priority" {
  type    = string
  default = "Spot"
}

variable "avd_vm_eviction_policy" {
  type    = string
  default = "Deallocate"
}

variable "avd_vm_admin" {
  type    = string
  default = "azadmin"
}

variable "avd_vm_admin_password" {
  type    = string
  default = "Radmin_1q2w_E$R"
}

variable "avd_vm_os_disk_caching" {
  type    = string
  default = "ReadWrite"
}

variable "avd_vm_os_disk_storage_account_type" {
  type    = string
  default = "Standard_LRS"
}

variable "avd_vm_publisher" {
  type    = string
  default = "MicrosoftWindowsDesktop"
}

variable "avd_vm_offer" {
  type    = string
  default = "Windows-11"
}

variable "avd_vm_sku" {
  type    = string
  default = "win11-23h2-pro"
}

variable "avd_vm_version" {
  type    = string
  default = "latest"
}

variable "shutdown_schedule_enabled" {
  type    = bool
  default = true
}

variable "shutdown_schedule_daily_time" {
  type    = string
  default = "1700"
}

variable "shutdown_schedule_timezone" {
  type    = string
  default = "Central Standard Time"
}

variable "shutdown_schedule_notification_enabled" {
  type    = bool
  default = false
}