# Creates admin subnet of SAP VNET
resource "azurerm_subnet" "subnet-sap-admin" {
  count                = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_admin.is_existing ? 0 : 1) : 0
  name                 = var.infrastructure.vnets.sap.subnet_admin.name
  resource_group_name  = var.vnet-sap[0].resource_group_name
  virtual_network_name = var.vnet-sap[0].name
  address_prefixes     = [var.infrastructure.vnets.sap.subnet_admin.prefix]
}

# Creates db subnet of SAP VNET
resource "azurerm_subnet" "subnet-sap-db" {
  count                = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_db.is_existing ? 0 : 1) : 0
  name                 = var.infrastructure.vnets.sap.subnet_db.name
  resource_group_name  = var.vnet-sap[0].resource_group_name
  virtual_network_name = var.vnet-sap[0].name
  address_prefixes     = [var.infrastructure.vnets.sap.subnet_db.prefix]
}

# Imports data of existing SAP admin subnet
data "azurerm_subnet" "subnet-sap-admin" {
  count                = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_admin.is_existing ? 1 : 0) : 0
  name                 = split("/", var.infrastructure.vnets.sap.subnet_admin.arm_id)[10]
  resource_group_name  = split("/", var.infrastructure.vnets.sap.subnet_admin.arm_id)[4]
  virtual_network_name = split("/", var.infrastructure.vnets.sap.subnet_admin.arm_id)[8]
}

# Imports data of existing SAP db subnet
data "azurerm_subnet" "subnet-sap-db" {
  count                = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_db.is_existing ? 1 : 0) : 0
  name                 = split("/", var.infrastructure.vnets.sap.subnet_db.arm_id)[10]
  resource_group_name  = split("/", var.infrastructure.vnets.sap.subnet_db.arm_id)[4]
  virtual_network_name = split("/", var.infrastructure.vnets.sap.subnet_db.arm_id)[8]
}

# Creates SAP admin subnet nsg
resource "azurerm_network_security_group" "nsg-admin" {
  count               = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_admin.nsg.is_existing ? 0 : 1) : 0
  name                = var.infrastructure.vnets.sap.subnet_admin.nsg.name
  location            = var.resource-group[0].location
  resource_group_name = var.resource-group[0].name
}

# Creates SAP db subnet nsg
resource "azurerm_network_security_group" "nsg-db" {
  count               = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_db.nsg.is_existing ? 0 : 1) : 0
  name                = var.infrastructure.vnets.sap.subnet_db.nsg.name
  location            = var.resource-group[0].location
  resource_group_name = var.resource-group[0].name
}

# Imports the SAP admin subnet nsg data
data "azurerm_network_security_group" "nsg-admin" {
  count               = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_admin.nsg.is_existing ? 1 : 0) : 0
  name                = split("/", var.infrastructure.vnets.sap.subnet_admin.nsg.arm_id)[8]
  resource_group_name = split("/", var.infrastructure.vnets.sap.subnet_admin.nsg.arm_id)[4]
}

# Imports the SAP db subnet nsg data
data "azurerm_network_security_group" "nsg-db" {
  count               = local.enable_deployment ? (var.infrastructure.vnets.sap.subnet_db.nsg.is_existing ? 1 : 0) : 0
  name                = split("/", var.infrastructure.vnets.sap.subnet_db.nsg.arm_id)[8]
  resource_group_name = split("/", var.infrastructure.vnets.sap.subnet_db.nsg.arm_id)[4]
}

# Associates SAP admin nsg to SAP admin subnet
resource "azurerm_subnet_network_security_group_association" "Associate-nsg-admin" {
  count                     = local.enable_deployment ? (signum((var.infrastructure.vnets.sap.subnet_admin.is_existing ? 0 : 1) + (var.infrastructure.vnets.sap.subnet_admin.nsg.is_existing ? 0 : 1))) : 0
  subnet_id                 = var.infrastructure.vnets.sap.subnet_admin.is_existing ? data.azurerm_subnet.subnet-sap-admin[0].id : azurerm_subnet.subnet-sap-admin[0].id
  network_security_group_id = var.infrastructure.vnets.sap.subnet_admin.nsg.is_existing ? data.azurerm_network_security_group.nsg-admin[0].id : azurerm_network_security_group.nsg-admin[0].id
}

# Associates SAP db nsg to SAP db subnet
resource "azurerm_subnet_network_security_group_association" "Associate-nsg-db" {
  count                     = local.enable_deployment ? (signum((var.infrastructure.vnets.sap.subnet_db.is_existing ? 0 : 1) + (var.infrastructure.vnets.sap.subnet_db.nsg.is_existing ? 0 : 1))) : 0
  subnet_id                 = var.infrastructure.vnets.sap.subnet_db.is_existing ? data.azurerm_subnet.subnet-sap-db[0].id : azurerm_subnet.subnet-sap-db[0].id
  network_security_group_id = var.infrastructure.vnets.sap.subnet_db.nsg.is_existing ? data.azurerm_network_security_group.nsg-db[0].id : azurerm_network_security_group.nsg-db[0].id
}
