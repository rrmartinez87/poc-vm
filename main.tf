// Azure provider configuration
terraform {
  required_version = ">= 0.12"
  backend "azurerm" {}
}

provider "azurerm" {
    version = "~>2.0"
    features {}
	subscription_id = "a7b78be8-6f3c-4faf-a43d-285ac7e92a05"
	tenant_id       = "c160a942-c869-429f-8a96-f8c8296d57db"
 }
// Resource required to generate random guids
resource "random_uuid" "poc" { }

// Azure resource group definition
resource "azurerm_resource_group" "rg" {

  // Arguments required by Terraform API
  name = var.resource_group_name
  location = "${location}"

  // Optional Terraform resource manager arguments but required by architecture
  tags = var.tags
}
// Create virtual network to set up a private endpoint later
resource "azurerm_virtual_network" "vnet" {
  
  // Arguments required by Terraform API
  name = var.vnet_name
  address_space = [var.vnet_address_space]
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = var.tags
}

// Create associated subnet
resource "azurerm_subnet" "subnet" {
  
  // Arguments required by Terraform API
  name = var.subnet_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = var.subnet_address_prefixes
  
  // Optional Terraform resource manager arguments but required by architecture
  enforce_private_link_endpoint_network_policies = var.enforce_private_link_endpoint_policies
  service_endpoints = ["Microsoft.Sql"]
}
//ip
resource "azurerm_public_ip" "ip" {
  name                    = var.azurerm_public_ip_name
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  allocation_method       = var.azurerm_public_ip_allocation_method
  idle_timeout_in_minutes = var.azurerm_public_ip_idle_timeout_in_minutes
  tags = {
    environment = var.azurerm_public_ip_enviroment
  }
}
// Network Interface
resource "azurerm_network_interface" "ni" {
  name                = var.azurerm_network_interface_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = var.ip_configuration_name
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = var.private_ip_address_allocation
    private_ip_address            = var.private_ip_address
    public_ip_address_id          = azurerm_public_ip.ip.id

  }
}
// virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = var.azurerm_virtual_machine_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.ni.id]
  vm_size               = var.azurerm_virtual_machine_vm_size

  storage_image_reference {
    publisher = var.storage_image_reference_publisher
    offer     = var.storage_image_reference_offer
    sku       = var.storage_image_reference_sku
    version   = var.storage_image_reference_version
  }

  storage_os_disk {
    name              = var.storage_os_disk_name
    caching           = var.storage_os_disk_caching
    create_option     = var.storage_os_disk_create_option
    managed_disk_type = var.storage_os_disk_managed_disk_type
  }

    os_profile {
    computer_name      = var.azurerm_virtual_machine_name
    admin_username     = var.os_profile_admin_username 
    admin_password     = var.os_profile_admin_password 
  
  }

  os_profile_windows_config {
    provision_vm_agent = var.os_profile_windows_config_provision_vm_agent
  winrm  {  //Here defined WinRM connectivity config
      protocol = var.os_profile_windows_config_protocol  
    }
  }
}
