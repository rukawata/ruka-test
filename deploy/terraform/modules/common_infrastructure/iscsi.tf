/*-----------------------------------------------------------------------------8
|                                                                              |
|                                    iSCSI                                     |
|                                                                              |
+--------------------------------------4--------------------------------------*/

/*-----------------------------------------------------------------------------8
TODO:  Fix Naming convention and document in the Naming Convention Doc
+--------------------------------------4--------------------------------------*/

/*-----------------------------------------------------------------------------8
Only create/import iSCSI subnet and nsg when iSCSI device(s) will be deployed
+--------------------------------------4--------------------------------------*/
# Creates iSCSI subnet of SAP VNET
resource "azurerm_subnet" "iscsi" {
  count                = local.iscsi.iscsi_count == 0 ? 0 : (local.subnet_iscsi.is_existing ? 0 : 1)
  name                 = local.subnet_iscsi.name
  resource_group_name  = var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].resource_group_name : azurerm_virtual_network.vnet-sap[0].resource_group_name
  virtual_network_name = var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].name : azurerm_virtual_network.vnet-sap[0].name
  address_prefixes     = [local.subnet_iscsi.prefix]
}

# Imports data of existing SAP iSCSI subnet
data "azurerm_subnet" "iscsi" {
  count                = local.iscsi_count == 0 ? 0 : (local.subnet_iscsi.is_existing ? 1 : 0)
  name                 = split("/", local.subnet_iscsi.arm_id)[10]
  resource_group_name  = split("/", local.subnet_iscsi.arm_id)[4]
  virtual_network_name = split("/", local.subnet_iscsi.arm_id)[8]
}

# Creates SAP iSCSI subnet nsg
resource "azurerm_network_security_group" "iscsi" {
  count               = local.iscsi.iscsi_count == 0 ? 0 : (local.subnet_iscsi.nsg.is_existing ? 0 : 1)
  name                = local.subnet_iscsi.nsg.name
  location            = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  resource_group_name = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
}

# Imports the SAP iSCSI subnet nsg data
data "azurerm_network_security_group" "iscsi" {
  count               = local.iscsi.iscsi_count == 0 ? 0 : (local.subnet_iscsi.nsg.is_existing ? 1 : 0)
  name                = split("/", var.infrastructure.vnets.sap.subnet_db.nsg.arm_id)[8]
  resource_group_name = split("/", var.infrastructure.vnets.sap.subnet_db.nsg.arm_id)[4]
}

# Creates network security rule to deny external traffic for SAP iSCSI subnet
resource "azurerm_network_security_rule" "iscsi" {
  count                       = local.iscsi_count == 0 ? 0 : (local.subnet_iscsi.is_existing ? 0 : 1)
  name                        = "deny-inbound-traffic"
  resource_group_name         = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  network_security_group_name = azurerm_network_security_group.iscsi[0].name
  priority                    = 102
  direction                   = "Inbound"
  access                      = "deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = var.infrastructure.vnets.sap.subnet_admin.prefix
}

/*-----------------------------------------------------------------------------8
iSCSI device IP address range: .4 - 
+--------------------------------------4--------------------------------------*/
# Creates the NIC and IP address for iSCSI device
resource "azurerm_network_interface" "iscsi" {
  count               = local.iscsi.iscsi_count
  name                = "iscsi-${format("%02d", count.index)}-nic"
  location            = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  resource_group_name = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name

  ip_configuration {
    name                          = "ipconfig-iscsi"
    subnet_id                     = local.subnet_iscsi.is_existing ? data.azurerm_subnet.iscsi[0].id : azurerm_subnet.iscsi[0].id
    private_ip_address            = local.subnet_iscsi.is_existing ? local.iscsi.iscsi_nic_ips[count.index] : lookup(local.iscsi, "iscsi_nic_ips", false) != false ? local.iscsi.iscsi_nic_ips[count.index] : cidrhost(local.subnet_iscsi.prefix, tonumber(count.index) + 4)
    private_ip_address_allocation = "static"
  }
}

# Manages the association between NIC and NSG.
resource "azurerm_network_interface_security_group_association" "iscsi" {
  count                     = local.iscsi.iscsi_count
  network_interface_id      = azurerm_network_interface.iscsi[count.index].id
  network_security_group_id = local.subnet_iscsi.nsg.is_existing ? data.azurerm_network_security_group.iscsi[0].id : azurerm_network_security_group.iscsi[0].id
}

# Manages Linux Virtual Machine for iSCSI
resource "azurerm_linux_virtual_machine" "iscsi" {
  count                           = local.iscsi.iscsi_count
  name                            = "iscsi-${format("%02d", count.index)}"
  location                        = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  resource_group_name             = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  network_interface_ids           = [azurerm_network_interface.iscsi[count.index].id]
  size                            = local.iscsi.size
  computer_name                   = "iscsi-${format("%02d", count.index)}"
  admin_username                  = local.iscsi.authentication.username
  admin_password                  = lookup(local.iscsi.authentication, "password", null)
  disable_password_authentication = local.iscsi.authentication.type != "password" ? true : false

  os_disk {
    name                 = "iscsi-${format("%02d", count.index)}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = local.iscsi.os.publisher
    offer     = local.iscsi.os.offer
    sku       = local.iscsi.os.sku
    version   = "latest"
  }

  admin_ssh_key {
    username   = local.iscsi.authentication.username
    public_key = file(var.sshkey.path_to_public_key)
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage-bootdiag.primary_blob_endpoint
  }

  tags = {
    iscsiName = "iSCSI-${format("%02d", count.index)}"
  }
}
