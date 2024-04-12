variable "subscription_id" {
  type    = string
  default = "90da72fd-4e8b-4566-8304-2c234f193ea5"
}

variable "avd_resource_group_name_suffix" {
  type    = string
  default = "avd"
}

variable "location" {
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
  default = ["10.0.1.0/24"]
}

variable "avd_nic_ip_configuration_name" {
  type    = string
  default = "internal"
}

variable "avd_nic_private_ip_allocation" {
  type    = string
  default = "Dynamic"
}

variable "avd_host_pool_session_host_vm_name_suffix" {
  type    = string
  default = "vddtsh"
}

variable "vm_size" {
  type    = string
  default = "Standard_DS1_v2"
}

variable "vm_priority" {
  type    = string
  default = "Spot"
}

variable "vm_eviction_policy" {
  type    = string
  default = "Deallocate"
}

variable "vm_admin_username" {
  type    = string
  default = "azadmin"
}

variable "vm_admin_password" {
  type    = string
  default = "Radmin@1q2w#E$R"
}

variable "vm_os_disk_caching" {
  type    = string
  default = "ReadWrite"
}

variable "vm_os_disk_storage_account_type" {
  type    = string
  default = "Standard_LRS"
}

variable "vm_publisher" {
  type    = string
  default = "MicrosoftWindowsDesktop"
}

variable "vm_offer" {
  type    = string
  default = "Windows-11"
}

variable "vm_sku" {
  type    = string
  default = "win11-23h2-pro"
}

variable "vm_version" {
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