
```hcl
resource "azurerm_container_registry" "acr" {
  for_each = { for registry in var.registries : registry.name => registry }

  name                          = each.value.name
  resource_group_name           = each.value.rg_name
  location                      = each.value.location
  admin_enabled                 = each.value.admin_enabled
  sku                           = title(each.value.sku)
  public_network_access_enabled = try(each.value.public_network_access_enabled, null)
  quarantine_policy_enabled     = try(each.value.quarantine_policy_enabled, null)
  zone_redundancy_enabled       = try(each.value.zone_redundancy_enabled, null)
  export_policy_enabled         = try(each.value.export_policy_enabled, null)
  data_endpoint_enabled         = try(each.value.data_endpoint_enabled, null)
  anonymous_pull_enabled        = try(each.value.anonymous_pull_enabled, null)
  network_rule_bypass_option    = try(each.value.network_rule_bypass_option, null)
  tags                          = each.value.tags

  dynamic "georeplications" {
    for_each = title(each.value.sku) == "Premium" && each.value.georeplications != null ? [each.value.georeplications] : []
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = georeplications.value.tags
    }
  }

  dynamic "network_rule_set" {
    for_each = each.value.sku == "Premium" && each.value.network_rule_set != null ? [each.value.network_rule_set] : []
    content {
      default_action = network_rule_set.value.default_action

      dynamic "ip_rule" {
        for_each = network_rule_set.value.ip_rule != null ? [network_rule_set.value.ip_rule] : []
        content {
          action   = ip_rule.value.action
          ip_range = ip_rule.value.ip_range
        }
      }

      dynamic "virtual_network" {
        for_each = network_rule_set.value.virtual_network != null ? [network_rule_set.value.virtual_network] : []
        content {
          action    = virtual_network.value.action
          subnet_id = virtual_network.value.subnet_id
        }
      }
    }
  }

  dynamic "retention_policy" {
    for_each = each.value.retention_policy != null ? [each.value.retention_policy] : []
    content {
      days    = retention_policy.value.days
      enabled = retention_policy.value.enabled
    }
  }

  dynamic "trust_policy" {
    for_each = each.value.trust_policy != null ? [each.value.trust_policy] : []
    content {
      enabled = trust_policy.value.enabled
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned" ? [each.value.identity_type] : []
    content {
      type = each.value.identity_type
    }
  }

  dynamic "identity" {
    for_each = try(length(each.value.identity_ids), 0) > 0 || each.value.identity_type == "UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = try(each.value.identity_ids, [])
    }
  }


  dynamic "identity" {
    for_each = try(length(each.value.identity_ids), 0) > 0 || each.value.identity_type == "SystemAssigned, UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = length(try(each.value.identity_ids, [])) > 0 ? each.value.identity_ids : []
    }
  }

  dynamic "encryption" {
    for_each = each.value.encryption != null ? [each.value.encryption] : []
    content {
      enabled            = encryption.value.enabled
      key_vault_key_id   = encryption.value.key_vault_key_id
      identity_client_id = encryption.value.identity_client_id
    }
  }
}

locals {
  flattened_pools = flatten([
    for registry in var.registries :
    registry.agent_pool != null ? [
      for pool in registry.agent_pool : {
        registry_name = registry.name
        pool          = pool
      }
    ] : []
  ])
}


resource "azurerm_container_registry_agent_pool" "agent_pool" {
  for_each = { for item in local.flattened_pools : "${item.registry_name}-${item.pool.name}" => item }

  name                    = each.value.pool.name
  resource_group_name     = azurerm_container_registry.acr[each.value.registry_name].resource_group_name
  location                = azurerm_container_registry.acr[each.value.registry_name].location
  container_registry_name = azurerm_container_registry.acr[each.value.registry_name].name

  instance_count            = try(each.value.pool.instance_count, 1)
  tier                      = try(each.value.pool.tier, "S1")
  virtual_network_subnet_id = try(each.value.pool.virtual_network_subnet_id, null)
  tags                      = try(each.value.pool.tags, null)
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_container_registry.acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_container_registry_agent_pool.agent_pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_agent_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_clusters"></a> [clusters](#input\_clusters) | A list of clusters to create | <pre>list(object({<br>    name                                = string<br>    kubernetes_version                  = string<br>    location                            = string<br>    rg_name                             = string<br>    dns_prefix                          = string<br>    sku_tier                            = string<br>    private_cluster_enabled             = bool<br>    tags                                = map(string)<br>    http_application_routing_enabled    = optional(bool)<br>    azure_policy_enabled                = optional(bool)<br>    role_based_access_control_enabled   = optional(bool)<br>    open_service_mesh_enabled           = optional(bool)<br>    private_dns_zone_id                 = optional(string)<br>    private_cluster_public_fqdn_enabled = optional(bool)<br>    custom_ca_trust_certificates_base64 = optional(list(string), [])<br>    disk_encryption_set_id              = optional(string)<br>    edge_zone                           = optional(string)<br>    image_cleaner_enabled               = optional(bool)<br>    image_cleaner_interval_hours        = optional(number)<br>    automatic_channel_upgrade           = optional(string, null)<br>    local_account_disabled              = optional(bool)<br>    node_os_channel_upgrade             = optional(string)<br>    node_resource_group                 = optional(string)<br>    oidc_issuer_enabled                 = optional(bool)<br>    dns_prefix_private_cluster          = optional(string)<br>    workload_identity_enabled           = optional(bool)<br>    identity_type                       = optional(string)<br>    identity_ids                        = optional(list(string))<br>    linux_profile = optional(object({<br>      admin_username = string<br>      ssh_key = list(object({<br>        key_data = string<br>      }))<br>    }))<br>    default_node_pool = optional(object({<br>      enable_auto_scaling                 = optional(bool)<br>      agents_max_count                    = optional(number)<br>      agents_min_count                    = optional(number)<br>      agents_type                         = optional(string)<br>      capacity_reservation_group_id       = optional(string)<br>      orchestrator_version                = optional(string)<br>      custom_ca_trust_enabled             = optional(bool)<br>      custom_ca_trust_certificates_base64 = optional(list(string))<br>      enable_host_encryption              = optional(bool)<br>      host_group_id                       = optional(string)<br>      pool_name                           = optional(string)<br>      vm_size                             = optional(string)<br>      os_disk_size_gb                     = optional(number)<br>      subnet_id                           = optional(string)<br>      enable_node_public_ip               = optional(bool)<br>      availability_zones                  = optional(list(string))<br>      count                               = optional(number)<br>      fips_enabled                        = optional(bool)<br>      kubelet_disk_type                   = optional(string)<br>      max_pods                            = optional(number)<br>      message_of_the_day                  = optional(string)<br>      node_public_ip_prefix_id            = optional(string)<br>      node_labels                         = optional(map(string))<br>      node_taints                         = optional(list(string))<br>      only_critical_addons_enabled        = optional(bool)<br>      os_sku                              = optional(string)<br>      pod_subnet_id                       = optional(string)<br>      proximity_placement_group_id        = optional(string)<br>      scale_down_mode                     = optional(string)<br>      snapshot_id                         = optional(string)<br>      temporary_name_for_rotation         = optional(string)<br>      tags                                = optional(map(string))<br>      ultra_ssd_enabled                   = optional(bool)<br>      linux_os_config = optional(object({<br>        swap_file_size_mb             = optional(number)<br>        transparent_huge_page_defrag  = optional(string)<br>        transparent_huge_page_enabled = optional(string)<br>        sysctl_config = optional(object({<br>          fs_aio_max_nr                      = optional(number)<br>          fs_file_max                        = optional(number)<br>          fs_inotify_max_user_watches        = optional(number)<br>          fs_nr_open                         = optional(number)<br>          kernel_threads_max                 = optional(number)<br>          net_core_netdev_max_backlog        = optional(number)<br>          net_core_optmem_max                = optional(number)<br>          net_core_rmem_default              = optional(number)<br>          net_core_rmem_max                  = optional(number)<br>          net_core_somaxconn                 = optional(number)<br>          net_core_wmem_default              = optional(number)<br>          net_core_wmem_max                  = optional(number)<br>          net_ipv4_ip_local_port_range_max   = optional(number)<br>          net_ipv4_ip_local_port_range_min   = optional(number)<br>          net_ipv4_neigh_default_gc_thresh1  = optional(number)<br>          net_ipv4_neigh_default_gc_thresh2  = optional(number)<br>          net_ipv4_neigh_default_gc_thresh3  = optional(number)<br>          net_ipv4_tcp_fin_timeout           = optional(number)<br>          net_ipv4_tcp_keepalive_intvl       = optional(number)<br>          net_ipv4_tcp_keepalive_probes      = optional(number)<br>          net_ipv4_tcp_keepalive_time        = optional(number)<br>          net_ipv4_tcp_max_syn_backlog       = optional(number)<br>          net_ipv4_tcp_max_tw_buckets        = optional(number)<br>          net_ipv4_tcp_tw_reuse              = optional(number)<br>          net_netfilter_nf_conntrack_buckets = optional(number)<br>          net_netfilter_nf_conntrack_max     = optional(number)<br>          vm_max_map_count                   = optional(number)<br>          vm_swappiness                      = optional(number)<br>          vm_vfs_cache_pressure              = optional(number)<br>        }))<br>      }))<br>      kubelet_config = optional(object({<br>        allowed_unsafe_sysctls    = optional(list(string))<br>        container_log_max_line    = optional(number)<br>        container_log_max_size_mb = optional(number)<br>        cpu_cfs_quota_enabled     = optional(bool)<br>        cpu_cfs_quota_period      = optional(string)<br>        cpu_manager_policy        = optional(string)<br>        image_gc_high_threshold   = optional(number)<br>        image_gc_low_threshold    = optional(number)<br>        pod_max_pid               = optional(number)<br>        topology_manager_policy   = optional(string)<br>      }))<br>    }))<br>    azure_active_directory_role_based_access_control = optional(object({<br>      managed                = optional(bool)<br>      tenant_id              = optional(string)<br>      admin_group_object_ids = optional(list(string))<br>      client_app_id          = optional(string)<br>      server_app_id          = optional(string)<br>      server_app_secret      = optional(string)<br>      azure_rbac_enabled     = optional(bool)<br>    }))<br>    service_principal = optional(object({<br>      client_id     = string<br>      client_secret = string<br>    }))<br>    identity = optional(object({<br>      type         = string<br>      identity_ids = optional(list(string))<br>    }))<br>    oms_agent = optional(object({<br>      log_analytics_workspace_id = string<br>    }))<br>    network_profile = optional(object({<br>      network_plugin = string<br>      network_policy = string<br>      dns_service_ip = string<br>      outbound_type  = string<br>      pod_cidr       = string<br>      service_cidr   = string<br>    }))<br>    aci_connector_linux = optional(object({<br>      subnet_name = string<br>    }))<br>    api_server_access_profile = optional(object({<br>      authorized_ip_ranges     = list(string)<br>      subnet_id                = string<br>      vnet_integration_enabled = bool<br>    }))<br>    auto_scaler_profile = optional(object({<br>      balance_similar_node_groups      = optional(bool)<br>      expander                         = optional(string)<br>      max_graceful_termination_sec     = optional(number)<br>      max_node_provisioning_time       = optional(string)<br>      max_unready_nodes                = optional(number)<br>      max_unready_percentage           = optional(number)<br>      new_pod_scale_up_delay           = optional(string)<br>      scale_down_delay_after_add       = optional(string)<br>      scale_down_delay_after_delete    = optional(string)<br>      scale_down_delay_after_failure   = optional(string)<br>      scan_interval                    = optional(string)<br>      scale_down_unneeded              = optional(string)<br>      scale_down_unready               = optional(string)<br>      scale_down_utilization_threshold = optional(number)<br>      empty_bulk_delete_max            = optional(number)<br>      skip_nodes_with_local_storage    = optional(bool)<br>      skip_nodes_with_system_pods      = optional(bool)<br>    }))<br>    confidential_computing = optional(object({<br>      sgx_quote_helper_enabled = optional(bool)<br>    }))<br>    maintenance_window = optional(object({<br>      allowed = optional(list(object({<br>        day   = string<br>        hours = list(number)<br>      })))<br>      not_allowed = optional(list(object({<br>        start = string<br>        end   = string<br>      })))<br>    }))<br>    maintenance_window_auto_upgrade = optional(object({<br>      frequency   = string<br>      interval    = number<br>      duration    = number<br>      day_of_week = optional(string)<br>      week_index  = optional(string)<br>      start_time  = optional(string)<br>      utc_offset  = optional(string)<br>      start_date  = optional(string)<br>      not_allowed = optional(list(object({<br>        start = string<br>        end   = string<br>      })))<br>    }))<br><br>    maintenance_window_node_os = optional(object({<br>      frequency   = string<br>      interval    = number<br>      duration    = number<br>      day_of_week = optional(string)<br>      week_index  = optional(string)<br>      start_time  = optional(string)<br>      utc_offset  = optional(string)<br>      start_date  = optional(string)<br>      not_allowed = optional(list(object({<br>        start = string<br>        end   = string<br>      })))<br>    }))<br>    http_proxy_config = optional(object({<br>      http_proxy  = string<br>      https_proxy = string<br>      trusted_ca  = string<br>    }))<br>    ingress_application_gateway = optional(object({<br>      gateway_id   = optional(string)<br>      gateway_name = optional(string)<br>      subnet_cidr  = optional(string)<br>      subnet_id    = optional(string)<br>    }))<br>    storage_profile = optional(object({<br>      blob_driver_enabled         = optional(bool)<br>      disk_driver_enabled         = optional(bool)<br>      disk_driver_version         = optional(string)<br>      file_driver_enabled         = optional(bool)<br>      snapshot_controller_enabled = optional(bool)<br>    }))<br>    service_mesh_profile = optional(object({<br>      mode                             = string<br>      internal_ingress_gateway_enabled = optional(bool)<br>      external_ingress_gateway_enabled = optional(bool)<br>    }))<br>    key_management_service = optional(object({<br>      key_vault_key_id        = optional(string)<br>      keyvault_network_access = optional(string)<br>    }))<br>    key_vault_secrets_provider = optional(object({<br>      secret_rotation_enabled  = optional(bool)<br>      secret_rotation_interval = optional(string)<br>    }))<br>    kubelet_config = optional(object({<br>      allowed_unsafe_sysctls    = optional(list(string))<br>      container_log_max_line    = optional(number)<br>      container_log_max_size_mb = optional(number)<br>      cpu_cfs_quota_enabled     = optional(bool)<br>      cpu_cfs_quota_period      = optional(string)<br>      cpu_manager_policy        = optional(string)<br>      image_gc_high_threshold   = optional(number)<br>      image_gc_low_threshold    = optional(number)<br>      pod_max_pid               = optional(number)<br>      topology_manager_policy   = optional(string)<br>    }))<br>    kubelet_identity = optional(object({<br>      user_assigned_identity_id = string<br>    }))<br>    microsoft_defender = optional(object({<br>      log_analytics_workspace_id = optional(string)<br>    }))<br>    monitor_metrics = optional(object({<br>      annotations_allowed = optional(list(string))<br>      labels_allowed      = optional(list(string))<br>    }))<br>    windows_profile = optional(object({<br>      admin_username = string<br>      admin_password = optional(string)<br>      license        = optional(string)<br>      gmsa = optional(object({<br>        dns_server  = string<br>        root_domain = string<br>      }))<br>    }))<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_pool_ids"></a> [agent\_pool\_ids](#output\_agent\_pool\_ids) | The IDs of the Azure Container Registry Agent Pools. |
| <a name="output_agent_pool_locations"></a> [agent\_pool\_locations](#output\_agent\_pool\_locations) | The locations of the Azure Container Registry Agent Pools. |
| <a name="output_agent_pool_names"></a> [agent\_pool\_names](#output\_agent\_pool\_names) | The names of the Azure Container Registry Agent Pools. |
| <a name="output_registry_admin_passwords"></a> [registry\_admin\_passwords](#output\_registry\_admin\_passwords) | The admin passwords of the created Azure Container Registries, if admin is enabled. |
| <a name="output_registry_admin_usernames"></a> [registry\_admin\_usernames](#output\_registry\_admin\_usernames) | The admin usernames of the created Azure Container Registries, if admin is enabled. |
| <a name="output_registry_identities"></a> [registry\_identities](#output\_registry\_identities) | The identities of the Azure Container Registries. |
| <a name="output_registry_ids"></a> [registry\_ids](#output\_registry\_ids) | The IDs of the created Azure Container Registries. |
| <a name="output_registry_locations"></a> [registry\_locations](#output\_registry\_locations) | The locations of the created Azure Container Registries. |
| <a name="output_registry_login_servers"></a> [registry\_login\_servers](#output\_registry\_login\_servers) | The login servers of the created Azure Container Registries. |
| <a name="output_registry_skus"></a> [registry\_skus](#output\_registry\_skus) | The SKUs of the created Azure Container Registries. |
| <a name="output_registry_tags"></a> [registry\_tags](#output\_registry\_tags) | The tags associated with the created Azure Container Registries. |
