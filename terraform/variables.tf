variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-azure-etl-project"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vm_admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_password" {
  description = "Admin password for the VM (will be stored in Key Vault)"
  type        = string
  sensitive   = true
  default     = null # Will be auto-generated if not provided
}

variable "vm_size" {
  description = "Size of the VM for SHIR"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "source_data_path" {
  description = "Path to on-premise data source"
  type        = string
  default     = "C:\\OnPremiseData"
}

variable "alert_email_address" {
  description = "Email address for monitoring alerts"
  type        = string
  default     = "admin@example.com" # Change this to your email
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Azure-ETL-OnPrem-to-Cloud"
    ManagedBy   = "Terraform"
    Environment = "Development"
    Purpose     = "ETL-Demo"
  }
}

variable "allowed_ip_addresses" {
  description = "List of allowed IP addresses for Key Vault and VM access"
  type        = list(string)
  default     = [] # Add your public IP here
}

variable "databricks_cluster_id" {
  description = "Existing Databricks cluster ID (optional, will create new if not provided)"
  type        = string
  default     = ""
}

variable "fabric_sku" {
  description = "Microsoft Fabric capacity SKU (F2, F4, F8, F16, F32, F64)"
  type        = string
  default     = "F2" # Minimum for production, ~$262/month
}

variable "fabric_admin_emails" {
  description = "List of admin emails for Fabric capacity"
  type        = list(string)
  default     = ["admin@example.com"]
}

variable "search_sku" {
  description = "Azure AI Search SKU (basic, standard, standard2, standard3)"
  type        = string
  default     = "basic"
}

variable "search_replica_count" {
  description = "Azure AI Search replica count"
  type        = number
  default     = 1
}

variable "search_partition_count" {
  description = "Azure AI Search partition count"
  type        = number
  default     = 1
}

variable "openai_sku" {
  description = "Azure OpenAI SKU"
  type        = string
  default     = "S0"
}
