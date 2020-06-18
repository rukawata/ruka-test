/*-----------------------------------------------------------------------------8
|                                                                              |
|                                 HANA - VMs                                   |
|                                                                              |
+--------------------------------------4--------------------------------------*/

# NICS ============================================================================================================

/*-----------------------------------------------------------------------------8
HANA DB Linux Server private IP range: .10 -
+--------------------------------------4--------------------------------------*/

# Creates the admin traffic NIC and private IP address for database nodes
resource "azurerm_network_interface" "nics-dbnodes-admin" {
  count                         = local.enable_deployment ? length(local.dbnodes) : 0
  name                          = "${local.dbnodes[count.index].name}-admin-nic"
  location                      = var.resource-group[0].location
  resource_group_name           = var.resource-group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "${local.dbnodes[count.index].name}-admin-nic-ip"
    subnet_id                     = var.infrastructure.vnets.sap.subnet_admin.is_existing ? data.azurerm_subnet.subnet-sap-admin[0].id : azurerm_subnet.subnet-sap-admin[0].id
    private_ip_address            = var.infrastructure.vnets.sap.subnet_admin.is_existing ? local.dbnodes[count.index].admin_nic_ip : lookup(local.dbnodes[count.index], "admin_nic_ip", false) != false ? local.dbnodes[count.index].admin_nic_ip : cidrhost(var.infrastructure.vnets.sap.subnet_admin.prefix, tonumber(count.index) + 10)
    private_ip_address_allocation = "static"
  }
}

# Creates the DB traffic NIC and private IP address for database nodes
resource "azurerm_network_interface" "nics-dbnodes-db" {
  count                         = local.enable_deployment ? length(local.dbnodes) : 0
  name                          = "${local.dbnodes[count.index].name}-db-nic"
  location                      = var.resource-group[0].location
  resource_group_name           = var.resource-group[0].name
  enable_accelerated_networking = true

  ip_configuration {
    primary                       = true
    name                          = "${local.dbnodes[count.index].name}-db-nic-ip"
    subnet_id                     = var.infrastructure.vnets.sap.subnet_db.is_existing ? data.azurerm_subnet.subnet-sap-db[0].id : azurerm_subnet.subnet-sap-db[0].id
    private_ip_address            = var.infrastructure.vnets.sap.subnet_db.is_existing ? local.dbnodes[count.index].db_nic_ip : lookup(local.dbnodes[count.index], "db_nic_ip", false) != false ? local.dbnodes[count.index].db_nic_ip : cidrhost(var.infrastructure.vnets.sap.subnet_db.prefix, tonumber(count.index) + 10)
    private_ip_address_allocation = "static"
  }
}

# LOAD BALANCER ===================================================================================================

/*-----------------------------------------------------------------------------8
Load balancer front IP address range: .4 - .9
+--------------------------------------4--------------------------------------*/

resource "azurerm_lb" "hana-lb" {
  count               = local.enable_deployment ? length(local.sid-infra) : 0
  name                = "hana-${local.sid-infra[count.index].sid}-lb"
  resource_group_name = var.resource-group[0].name
  location            = var.resource-group[0].location

  frontend_ip_configuration {
    name                          = "hana-${local.sid-infra[count.index].sid}-lb-feip"
    subnet_id                     = var.infrastructure.vnets.sap.subnet_db.is_existing ? data.azurerm_subnet.subnet-sap-db[0].id : azurerm_subnet.subnet-sap-db[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.infrastructure.vnets.sap.subnet_db.is_existing ? local.sid-infra[count.index].frontend_ip : lookup(local.sid-infra[count.index], "frontend_ip", false) != false ? local.sid-infra[count.index].frontend_ip : cidrhost(var.infrastructure.vnets.sap.subnet_db.prefix, tonumber(count.index) + 4)
  }
}

resource "azurerm_lb_backend_address_pool" "hana-lb-back-pool" {
  count               = local.enable_deployment ? length(local.sid-infra) : 0
  resource_group_name = var.resource-group[0].name
  loadbalancer_id     = azurerm_lb.hana-lb[count.index].id
  name                = "hana-${local.sid-infra[count.index].sid}-lb-bep"
}

resource "azurerm_lb_probe" "hana-lb-health-probe" {
  count               = local.enable_deployment ? length(local.sid-infra) : 0
  resource_group_name = var.resource-group[0].name
  loadbalancer_id     = azurerm_lb.hana-lb[count.index].id
  name                = "hana-${local.sid-infra[count.index].sid}-lb-hp"
  port                = "625${local.sid-infra[count.index].instance_number}"
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# TODO:
# Current behavior, it will try to add all VMs in the cluster into the backend pool, which would not work since we do not have availability sets created yet.
# In a scale-out scenario, we need to rewrite this code according to the scale-out + HA reference architecture.
resource "azurerm_network_interface_backend_address_pool_association" "hana-lb-nic-bep" {
  count                   = local.enable_deployment ? length(azurerm_network_interface.nics-dbnodes-db) : 0
  network_interface_id    = azurerm_network_interface.nics-dbnodes-db[count.index].id
  ip_configuration_name   = azurerm_network_interface.nics-dbnodes-db[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.hana-lb-back-pool[index(local.hdb-sids, local.dbnodes[count.index].sid)].id
}

resource "azurerm_lb_rule" "hana-lb-rules" {
  count                          = local.enable_deployment ? length(local.loadbalancer_ports) : 0
  resource_group_name            = var.resource-group[0].name
  loadbalancer_id                = azurerm_lb.hana-lb[index(local.hdb-sids, local.loadbalancer_ports[count.index].sid)].id
  name                           = "HANA_${local.loadbalancer_ports[count.index].sid}_${local.loadbalancer_ports[count.index].port}"
  protocol                       = "Tcp"
  frontend_port                  = local.loadbalancer_ports[count.index].port
  backend_port                   = local.loadbalancer_ports[count.index].port
  frontend_ip_configuration_name = "hana-${local.loadbalancer_ports[count.index].sid}-lb-feip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.hana-lb-back-pool[index(local.hdb-sids, local.loadbalancer_ports[count.index].sid)].id
  probe_id                       = azurerm_lb_probe.hana-lb-health-probe[index(local.hdb-sids, local.loadbalancer_ports[count.index].sid)].id
  enable_floating_ip             = true
}

# AVAILABILITY SET ================================================================================================

resource "azurerm_availability_set" "hana-as" {
  count                        = local.enable_deployment ? length(local.sid-infra) : 0
  name                         = "${local.sid-infra[count.index].sid}-as"
  location                     = var.resource-group[0].location
  resource_group_name          = var.resource-group[0].name
  platform_update_domain_count = 20
  platform_fault_domain_count  = 2
  proximity_placement_group_id = lookup(var.infrastructure, "ppg", false) != false ? (var.ppg[0].id) : null
  managed                      = true
}

# VIRTUAL MACHINES ================================================================================================

# Creates managed data disk
resource "azurerm_managed_disk" "data-disk" {
  count                = local.enable_deployment ? length(local.data-disk-list) : 0
  name                 = local.data-disk-list[count.index].name
  location             = var.resource-group[0].location
  resource_group_name  = var.resource-group[0].name
  create_option        = "Empty"
  storage_account_type = local.data-disk-list[count.index].storage_account_type
  disk_size_gb         = local.data-disk-list[count.index].disk_size_gb
}

# Manages Linux Virtual Machine for HANA DB servers
resource "azurerm_linux_virtual_machine" "vm-dbnode" {
  count                           = local.enable_deployment ? length(local.dbnodes) : 0
  name                            = local.dbnodes[count.index].name
  computer_name                   = local.dbnodes[count.index].name
  location                        = var.resource-group[0].location
  resource_group_name             = var.resource-group[0].name
  availability_set_id             = azurerm_availability_set.hana-as[index(local.hdb-sids, local.dbnodes[count.index].sid)].id
  proximity_placement_group_id    =  lookup(var.infrastructure, "ppg", false) != false ? (var.ppg[0].id) : null
  network_interface_ids           = [
    azurerm_network_interface.nics-dbnodes-admin[count.index].id,
    azurerm_network_interface.nics-dbnodes-db[count.index].id
  ]
  size                            = lookup(local.sizes, local.dbnodes[count.index].size).compute.vm_size
  admin_username                  = local.dbnodes[count.index].authentication.username
  admin_password                  = lookup(local.dbnodes[count.index].authentication, "password", null)
  disable_password_authentication = local.dbnodes[count.index].authentication.type != "password" ? true : false

  dynamic "os_disk" {
    iterator = disk
    for_each = flatten([for storage_type in lookup(local.sizes, local.dbnodes[count.index].size).storage : [for disk_count in range(storage_type.count) : { name = storage_type.name, id = disk_count, disk_type = storage_type.disk_type, size_gb = storage_type.size_gb, caching = storage_type.caching }] if storage_type.name == "os"])
    content {
      name                 = "${local.dbnodes[count.index].name}-osdisk"
      caching              = disk.value.caching
      storage_account_type = disk.value.disk_type
      disk_size_gb         = disk.value.size_gb
    }
  }

  source_image_reference {
    publisher = local.dbnodes[count.index].os.publisher
    offer     = local.dbnodes[count.index].os.offer
    sku       = local.dbnodes[count.index].os.sku
    version   = "latest"
  }

  admin_ssh_key {
    username   = local.dbnodes[count.index].authentication.username
    public_key = file(var.sshkey.path_to_public_key)
  }

  boot_diagnostics {
    storage_account_uri = var.storage-bootdiag.primary_blob_endpoint
  }
}

# Manages attaching a Disk to a Virtual Machine
resource "azurerm_virtual_machine_data_disk_attachment" "vm-dbnode-data-disk" {
  count                     = local.enable_deployment ? length(local.data-disk-list) : 0
  managed_disk_id           = azurerm_managed_disk.data-disk[count.index].id
  virtual_machine_id        = azurerm_linux_virtual_machine.vm-dbnode[floor(count.index / length(local.data-disk-per-dbnode))].id
  caching                   = local.data-disk-list[count.index].caching
  write_accelerator_enabled = local.data-disk-list[count.index].write_accelerator_enabled
  lun                       = count.index
}
