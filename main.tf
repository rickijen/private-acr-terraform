resource "random_string" "number" {
  length  = 16
  upper   = false
  lower   = false
  number  = true
  special = false
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "rg" {
  backend = "remote"

  config = {
    organization = "greensugarcake"
    workspaces = {
      name = "create-resource-groups"
    }
  }
}

data "terraform_remote_state" "aks" {
  backend = "remote"

  config = {
    organization = "greensugarcake"
    workspaces = {
      name = "private-aks-cluster"
    }
  }
}

# Private DNS Zone for ACR
#resource "azurerm_private_dns_zone" "dns-acr" {
#  name                = "privatelink.azurecr.io"
#  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_kube_name
#}

module "container-registry" {
  source  = "kumarvna/container-registry/azurerm"
  version = "1.0.0"

  # By default, this module will not create a resource group. Location will be same as existing RG.
  # proivde a name to use an existing resource group, specify the existing resource group name, 
  # set the argument to `create_resource_group = true` to create new resrouce group.
  resource_group_name       = data.terraform_remote_state.rg.outputs.resource_group_kube_name
  location                  = data.terraform_remote_state.rg.outputs.location
  
  # Private ACR
  enable_private_endpoint   = true
  virtual_network_name      = data.terraform_remote_state.aks.outputs.kube_vnet_name
  #private_subnet_address_prefix = ["${data.terraform_remote_state.aks.outputs.aks_subnet_prefix}"]
  private_subnet_address_prefix = ["10.10.6.0/24"]
  #existing_private_dns_zone = azurerm_private_dns_zone.dns-acr.name

  # Azure Container Registry configuration
  # The `Classic` SKU is Deprecated and will no longer be available for new resources
  container_registry_config = {
    name          = "acr${random_string.number.result}"
    admin_enabled = true
    sku           = "Premium"
  }

  # The georeplications is only supported on new resources with the Premium SKU.
  # The georeplications list cannot contain the location where the Container Registry exists.
  georeplications = [
    {
      location                = "southcentralus" # Must have AZ support
      zone_redundancy_enabled = true
    }
  ]

  # (Optional) To enable Azure Monitoring for Azure MySQL database
  # (Optional) Specify `storage_account_name` to save monitoring logs to storage. 
  log_analytics_workspace_name = data.terraform_remote_state.aks.outputs.azurerm_log_analytics_workspace_name

  # Adding TAG's to your Azure resources
  tags = {
    env          = "production"
  }
}

# Create PDNSZ VNet link to hub
resource "azurerm_private_dns_zone_virtual_network_link" "pdns-vnet-link" {
  name                  = "vnet-private-zone-link-2-hub"
  resource_group_name   = data.terraform_remote_state.rg.outputs.resource_group_vnet_name
  private_dns_zone_name = "privatelink.azurecr.io"
  virtual_network_id    = data.terraform_remote_state.aks.outputs.hub_vnet_id
}
