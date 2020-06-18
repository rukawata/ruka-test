##################################################################################################################
# RESOURCES
##################################################################################################################

# RESOURCE GROUP =================================================================================================

# Creates the resource group
resource "azurerm_resource_group" "resource-group" {
  count    = var.infrastructure.resource_group.is_existing ? 0 : 1
  name     = var.infrastructure.resource_group.name
  location = var.infrastructure.region
}

# Imports data of existing resource group
data "azurerm_resource_group" "resource-group" {
  count = var.infrastructure.resource_group.is_existing ? 1 : 0
  name  = split("/", var.infrastructure.resource_group.arm_id)[4]
}

# VNETs ==========================================================================================================

# Creates the management VNET
resource "azurerm_virtual_network" "vnet-management" {
  count               = var.infrastructure.vnets.management.is_existing ? 0 : 1
  name                = var.infrastructure.vnets.management.name
  location            = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  resource_group_name = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  address_space       = [var.infrastructure.vnets.management.address_space]
}

# Creates the SAP VNET
resource "azurerm_virtual_network" "vnet-sap" {
  count               = var.infrastructure.vnets.sap.is_existing ? 0 : 1
  name                = var.infrastructure.vnets.sap.name
  location            = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  resource_group_name = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  address_space       = [var.infrastructure.vnets.sap.address_space]
}

# Imports data of existing management VNET
data "azurerm_virtual_network" "vnet-management" {
  count               = var.infrastructure.vnets.management.is_existing ? 1 : 0
  name                = split("/", var.infrastructure.vnets.management.arm_id)[8]
  resource_group_name = split("/", var.infrastructure.vnets.management.arm_id)[4]
}

# Imports data of existing SAP VNET
data "azurerm_virtual_network" "vnet-sap" {
  count               = var.infrastructure.vnets.sap.is_existing ? 1 : 0
  name                = split("/", var.infrastructure.vnets.sap.arm_id)[8]
  resource_group_name = split("/", var.infrastructure.vnets.sap.arm_id)[4]
}

# SUBNETs ========================================================================================================

# Creates mgmt subnet of management VNET
resource "azurerm_subnet" "subnet-mgmt" {
  count                = var.infrastructure.vnets.management.subnet_mgmt.is_existing ? 0 : 1
  name                 = var.infrastructure.vnets.management.subnet_mgmt.name
  resource_group_name  = var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].resource_group_name : azurerm_virtual_network.vnet-management[0].resource_group_name
  virtual_network_name = var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].name : azurerm_virtual_network.vnet-management[0].name
  address_prefixes     = [var.infrastructure.vnets.management.subnet_mgmt.prefix]
}

# Imports data of existing mgmt subnet
data "azurerm_subnet" "subnet-mgmt" {
  count                = var.infrastructure.vnets.management.subnet_mgmt.is_existing ? 1 : 0
  name                 = split("/", var.infrastructure.vnets.management.subnet_mgmt.arm_id)[10]
  resource_group_name  = split("/", var.infrastructure.vnets.management.subnet_mgmt.arm_id)[4]
  virtual_network_name = split("/", var.infrastructure.vnets.management.subnet_mgmt.arm_id)[8]
}

# Associates mgmt nsg to mgmt subnet
resource "azurerm_subnet_network_security_group_association" "Associate-nsg-mgmt" {
  count                     = signum((var.infrastructure.vnets.management.is_existing ? 0 : 1) + (var.infrastructure.vnets.management.subnet_mgmt.nsg.is_existing ? 0 : 1))
  subnet_id                 = var.infrastructure.vnets.management.subnet_mgmt.is_existing ? data.azurerm_subnet.subnet-mgmt[0].id : azurerm_subnet.subnet-mgmt[0].id
  network_security_group_id = var.infrastructure.vnets.management.subnet_mgmt.nsg.is_existing ? data.azurerm_network_security_group.nsg-mgmt[0].id : azurerm_network_security_group.nsg-mgmt[0].id
}

# VNET PEERINGs ==================================================================================================

# Peers management VNET to SAP VNET
resource "azurerm_virtual_network_peering" "peering-management-sap" {
  count                        = signum((var.infrastructure.vnets.management.is_existing ? 0 : 1) + (var.infrastructure.vnets.sap.is_existing ? 0 : 1))
  name                         = "${var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].resource_group_name : azurerm_virtual_network.vnet-management[0].resource_group_name}_${var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].name : azurerm_virtual_network.vnet-management[0].name}-${var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].resource_group_name : azurerm_virtual_network.vnet-sap[0].resource_group_name}_${var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].name : azurerm_virtual_network.vnet-sap[0].name}"
  resource_group_name          = var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].resource_group_name : azurerm_virtual_network.vnet-management[0].resource_group_name
  virtual_network_name         = var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].name : azurerm_virtual_network.vnet-management[0].name
  remote_virtual_network_id    = var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].id : azurerm_virtual_network.vnet-sap[0].id
  allow_virtual_network_access = true
}

# Peers SAP VNET to management VNET
resource "azurerm_virtual_network_peering" "peering-sap-management" {
  count                        = signum((var.infrastructure.vnets.management.is_existing ? 0 : 1) + (var.infrastructure.vnets.sap.is_existing ? 0 : 1))
  name                         = "${var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].resource_group_name : azurerm_virtual_network.vnet-sap[0].resource_group_name}_${var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].name : azurerm_virtual_network.vnet-sap[0].name}-${var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].resource_group_name : azurerm_virtual_network.vnet-management[0].resource_group_name}_${var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].name : azurerm_virtual_network.vnet-management[0].name}"
  resource_group_name          = var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].resource_group_name : azurerm_virtual_network.vnet-sap[0].resource_group_name
  virtual_network_name         = var.infrastructure.vnets.sap.is_existing ? data.azurerm_virtual_network.vnet-sap[0].name : azurerm_virtual_network.vnet-sap[0].name
  remote_virtual_network_id    = var.infrastructure.vnets.management.is_existing ? data.azurerm_virtual_network.vnet-management[0].id : azurerm_virtual_network.vnet-management[0].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# STORAGE ACCOUNTS ===============================================================================================

# Generates random text for boot diagnostics storage account name
resource "random_id" "random-id" {
  keepers = {
    # Generate a new id only when a new resource group is defined
    resource_group = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  }
  byte_length = 4
}

# Creates storage account for storing SAP Bits
resource "azurerm_storage_account" "storage-sapbits" {
  count                     = var.software.storage_account_sapbits.is_existing ? 0 : 1
  name                      = lookup(var.software.storage_account_sapbits, "name", false) ? var.software.storage_account_sapbits.name : "sapbits${random_id.random-id.hex}"
  resource_group_name       = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  location                  = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  account_replication_type  = "LRS"
  account_tier              = var.software.storage_account_sapbits.account_tier
  account_kind              = var.software.storage_account_sapbits.account_kind
  enable_https_traffic_only = var.options.enable_secure_transfer == "" ? true : var.options.enable_secure_transfer
}

# Creates the storage container inside the storage account for SAP bits
resource "azurerm_storage_container" "storagecontainer-sapbits" {
  count                 = lookup(var.software.storage_account_sapbits, "blob_container_name", false) == false ? 0 : var.software.storage_account_sapbits.is_existing ? 0 : 1
  name                  = var.software.storage_account_sapbits.blob_container_name
  storage_account_name  = azurerm_storage_account.storage-sapbits[0].name
  container_access_type = var.software.storage_account_sapbits.container_access_type
}

# Creates file share inside the storage account for SAP bits
resource "azurerm_storage_share" "fileshare-sapbits" {
  count                = lookup(var.software.storage_account_sapbits, "file_share_name", false) == false ? 0 : var.software.storage_account_sapbits.is_existing ? 0 : 1
  name                 = var.software.storage_account_sapbits.file_share_name
  storage_account_name = azurerm_storage_account.storage-sapbits[0].name
}

# Imports existing storage account to use for SAP bits
data "azurerm_storage_account" "storage-sapbits" {
  count               = var.software.storage_account_sapbits.is_existing ? 1 : 0
  name                = split("/", var.software.storage_account_sapbits.arm_id)[8]
  resource_group_name = split("/", var.software.storage_account_sapbits.arm_id)[4]
}

# Creates boot diagnostics storage account
resource "azurerm_storage_account" "storage-bootdiag" {
  name                      = lookup(var.infrastructure, "boot_diagnostics_account_name", false) == false ? "sabootdiag${random_id.random-id.hex}" : var.infrastructure.boot_diagnostics_account_name
  resource_group_name       = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  location                  = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  account_replication_type  = "LRS"
  account_tier              = "Standard"
  enable_https_traffic_only = var.options.enable_secure_transfer == "" ? true : var.options.enable_secure_transfer
}


# PROXIMITY PLACEMENT GROUP ===============================================================================================

resource "azurerm_proximity_placement_group" "ppg" {
  count               = lookup(var.infrastructure, "ppg", false) != false ? (var.infrastructure.ppg.is_existing ? 0 : 1) : 0
  name                = var.infrastructure.ppg.name
  resource_group_name = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  location            = var.infrastructure.resource_group.is_existing ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
}


data "azurerm_proximity_placement_group" "ppg" {
  count               = lookup(var.infrastructure, "ppg", false) != false ? (var.infrastructure.ppg.is_existing ? 1 : 0) : 0
  name                = split("/", var.infrastructure.ppg.arm_id)[8]
  resource_group_name = split("/", var.infrastructure.ppg.arm_id)[4]
}
