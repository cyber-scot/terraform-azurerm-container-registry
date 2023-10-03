module "rg" {
  source = "cyber-scot/rg/azurerm"

  name     = "rg-${var.short}-${var.loc}-${var.env}-01"
  location = local.location
  tags     = local.tags
}

module "network" {
  source = "cyber-scot/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = "vnet-${var.short}-${var.loc}-${var.env}-01"
  vnet_location      = module.rg.rg_location
  vnet_address_space = ["10.0.0.0/16"]

  subnets = {
    "sn1-${module.network.vnet_name}" = {
      prefix            = "10.0.0.0/24",
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

module "container_registry" {
  source = "../../"

  registries = [
    {
      name                  = "acr${var.short}${var.loc}${var.env}01"
      rg_name               = module.rg.rg_name
      location              = module.rg.rg_location
      tags                  = module.rg.rg_tags
      admin_enabled         = true
      sku                   = "Basic"
      export_policy_enabled = true
    },
    {
      name                  = "acr${var.short}${var.loc}${var.env}02"
      rg_name               = module.rg.rg_name
      location              = module.rg.rg_location
      tags                  = module.rg.rg_tags
      admin_enabled         = true
      export_policy_enabled = true
      sku                   = "Premium"
      agent_pool = [ # As of 03/10/2023 - only eastus,westeurope,westus2,southcentralus,canadacentral,centralus,eastasia,eastus2,northeurope are supported
        {
          name                      = "pool1"
          instance_count            = 1
          tier                      = "S1"
          virtual_network_subnet_id = module.network.subnets_ids["sn1-${module.network.vnet_name}"]
          tags                      = module.rg.rg_tags
        }
      ]
    }
  ]
}
