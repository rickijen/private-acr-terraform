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
      name = var.resource-groups-workspace
    }
  }
}

data "terraform_remote_state" "aks" {
  backend = "remote"

  config = {
    organization = "greensugarcake"
    workspaces = {
      name = var.aks-cluster-workspace
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

#
# Reference DNS Zone for ACR
#
data "azurerm_private_dns_zone" "dnszone1" {
  count               = 1
  name                = "privatelink.azurecr.io"
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_kube_name
  depends_on = [module.container-registry]
}

# Create PDNSZ VNet link to hub
resource "azurerm_private_dns_zone_virtual_network_link" "pdns-vnet-link" {
  name                  = "vnet-private-zone-link-${data.terraform_remote_state.aks.outputs.hub_vnet_name}"
  resource_group_name   = data.terraform_remote_state.rg.outputs.resource_group_kube_name
  private_dns_zone_name = data.azurerm_private_dns_zone.dnszone1[0].name
  virtual_network_id    = data.terraform_remote_state.aks.outputs.hub_vnet_id
  registration_enabled  = true
}

# Assign the AcrPull role to the kublet obj id
# Equivalent to az aks update ... --attach-acr <acr-name>
resource "azurerm_role_assignment" "role_acrpull_kubelet" {
  scope                = module.container-registry.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = data.terraform_remote_state.aks.outputs.aks_kubelet_identity_id
}
