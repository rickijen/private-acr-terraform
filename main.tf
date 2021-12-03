resource "random_pet" "prefix" {}

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

module "container-registry" {
  source  = "kumarvna/container-registry/azurerm"
  version = "1.0.0"

  # By default, this module will not create a resource group. Location will be same as existing RG.
  # proivde a name to use an existing resource group, specify the existing resource group name, 
  # set the argument to `create_resource_group = true` to create new resrouce group.
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_kube_name
  location            = data.terraform_remote_state.rg.outputs.location

  # Azure Container Registry configuration
  # The `Classic` SKU is Deprecated and will no longer be available for new resources
  container_registry_config = {
    name          = "acr-${random_pet.prefix.id}"
    admin_enabled = true
    sku           = "Premium"
  }

  # The georeplications is only supported on new resources with the Premium SKU.
  # The georeplications list cannot contain the location where the Container Registry exists.
  georeplications = [
    {
      location                = "westus2"
      zone_redundancy_enabled = true
    },
    {
      location                = "southcentralus"
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