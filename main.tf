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
  location = var.location

  // Optional Terraform resource manager arguments but required by architecture
  tags = var.tags
}
/*
// Azure SQL database server resource definition
resource "azurerm_mssql_server" "dbserver" {

  // Arguments required by Terraform API
  name = join(local.separator, [var.server_name, random_uuid.poc.result])
  resource_group_name = (azurerm_resource_group.rg != null ? azurerm_resource_group.rg.name : var.resource_group_name)
  //resource_group_name = var.resource_group_name
  location = var.location
  version = var.server_version
  administrator_login = var.administrator_login
  administrator_login_password = var.administrator_login_password
  
  // Optional Terraform resource manager arguments but required by architecture
  connection_policy = local.connection_type
  public_network_access_enabled = local.public_network_access
  tags = var.tags
}

// Azure SQL single database resource definition
resource "azurerm_mssql_database" "singledb" {

  // Arguments required by Terraform API
  name = var.single_database_name
  server_id = azurerm_mssql_server.dbserver.id
  sample_name = local.sample_database

  // Optional Terraform resource manager arguments but required by architecture
  max_size_gb = var.max_size_gb
  sku_name = var.service_tier
  tags = var.tags
}
*/
// Create virtual network to set up a private endpoint later
resource "azurerm_virtual_network" "vnet" {
  
  // Arguments required by Terraform API
  name = join(local.separator, [var.vnet_name, random_uuid.poc.result])
  address_space = [var.vnet_address_space]
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = var.tags
}

// Create associated subnet
resource "azurerm_subnet" "subnet" {
  
  // Arguments required by Terraform API
  name = join(local.separator, [var.subnet_name, random_uuid.poc.result])
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = var.subnet_address_prefixes
  
  // Optional Terraform resource manager arguments but required by architecture
  enforce_private_link_endpoint_network_policies = var.enforce_private_link_endpoint_policies
  service_endpoints = ["Microsoft.Sql"]
}
/*
// Create a private endpoint to connect to the server using private access
resource "azurerm_private_endpoint" "endpoint" {
  
  // Arguments required by Terraform API
  name = join(local.separator, [var.private_endpoint_name, random_uuid.poc.result])
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id = azurerm_subnet.subnet.id

  private_service_connection {
    name = var.service_connection_name
    private_connection_resource_id = azurerm_mssql_server.dbserver.id
    is_manual_connection = var.requires_manual_approval
    subresource_names = ["sqlServer"]
  }

  // Optional Terraform resource manager arguments but required by architecture
  tags = var.tags
}

// Create a Private DNS Zone for SQL Database domain.
resource "azurerm_private_dns_zone" "dnszone" {
  
  // Arguments required by Terraform API
  name = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name

  // Optional Terraform resource manager arguments but required by architecture
  tags = var.tags
}

// Create an association link with the Virtual Network.
resource "azurerm_private_dns_zone_virtual_network_link" "dnslink" {
  
  // Arguments required by Terraform API
  name = var.private_dns_zone_vnet_link
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnszone.name
  virtual_network_id = azurerm_virtual_network.vnet.id

  // Optional Terraform resource manager arguments but required by architecture
  tags = var.tags
}

// Create a DNS Zone Group to associate the private endpoint with the Private DNS Zone.
resource "null_resource" "set_private_dns_zone_config" { 
  provisioner local-exec {
    command = "az network private-endpoint dns-zone-group create --endpoint-name ${azurerm_private_endpoint.endpoint.name} --name MyZoneGroup --private-dns-zone ${azurerm_private_dns_zone.dnszone.id} --resource-group ${azurerm_resource_group.rg.name} --zone-name 'privatelink.database.windows.net'"
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.dnslink
  ]
}

// Set database server TLS version after server creation (unsupported Azure provider argument)
// This setting can only be configured once a private enpoint is in place
resource "null_resource" "set_server_tls_version" { 
  provisioner local-exec {
    command = "az sql server update --name ${azurerm_mssql_server.dbserver.name} --resource-group ${azurerm_resource_group.rg.name} --minimal-tls-version ${local.tls_version}"
  }

  depends_on = [
    azurerm_private_endpoint.endpoint
  ]
}
*/
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
//  virtual machine extension
resource "azurerm_virtual_machine_extension" "vm_extension" {
  name                       = var.vm_extension_name
  virtual_machine_id         = azurerm_virtual_machine.vm.id
  publisher                  = var.vm_extension_publisher
  type                       = var.vm_extension_type
  type_handler_version       = var.vm_extension_type_handler_version
  auto_upgrade_minor_version = var.vm_extension_auto_upgrade_minor_version

  settings = <<SETTINGS
    {
    "commandToExecute": "Powershell -c Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco install azure-data-studio -y"
    }
SETTINGS
}
