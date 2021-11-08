# Configuring Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  # subscription_id = ""
  # client_id = ""
  # client_secret = ""
  # tenant_id = ""
  features {}
}


# Creating Resource Group
resource "azurerm_resource_group" "sp" {
  name = "SP-RG"
  location = "eastus"
  tags = {
    environment = "sp-test"
  }
}

# Creating Virtual Network
resource "azurerm_virtual_network" "sp" {
  name = "SP-Vnet"
  address_space = ["10.0.0.0/16"]
  location = "eastus"
  resource_group_name = azurerm_resource_group.sp.name
  tags = {
    environment = "sp-test"
  }
}


# Creating Subnet
resource "azurerm_subnet" "sp" {
  name = "SP-Subnet"
  resource_group_name = azurerm_resource_group.sp.name
  virtual_network_name = azurerm_virtual_network.sp.name
  address_prefixes = ["10.1.0.0/24"]
}


# Creating Public IPs
resource "azurerm_public_ip" "sp" {
  name = "SP-PublicIP"
  location = "eastus"
  resource_group_name = azurerm_resource_group.sp.name
  allocation_method = "Dynamic"
  tags = {
    environment = "sp-test"
  }
}


# Creating Network Security Group and rule
resource "azurerm_network_security_group" "sp" {
  name = "SP-NSG"
  location = "eastus"
  resource_group_name = azurerm_resource_group.sp.name

  security_rule {
    name = "SSH"
    priority = 1001
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "10.2.0.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "sp-test"
  }
}


# Creating Network Interface
resource "azurerm_network_interface" "sp" {
  name = "SP-NIC"
  location = "eastus"
  resource_group_name = azurerm_resource_group.sp.name

  ip_configuration {
    name = "SP-NIC-Config"
    subnet_id = azurerm_subnet.sp.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.sp.id
  }

  tags = {
    environment = "sp-test"
  }
}


# Connecting the security group to the network interface
resource "azurerm_network_interface_security_group_association" "sp" {
  network_interface_id = azurerm_network_interface.sp.id
  network_security_group_id = azurerm_network_security_group.sp.id
}


# Generating random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    resource_group = azurerm_resource_group.sp.name
  }
  byte_length = 8
}


# Create storage account for boot diagnostics
resource "azurerm_storage_account" "sp" {
  name = "diag${random_id.randomId.hex}"
  resource_group_name = azurerm_resource_group.sp.name
  location = "eastus"
  account_tier = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "sp-test"
  }
}


# Creating Virtual Machine
resource "azurerm_virtual_machine" "sp" {
  name = "SP-VM"
  location = "eastus"
  resource_group_name = azurerm_resource_group.sp.name
  network_interface_ids = [azurerm_network_interface.sp.id]
  vm_size = "Standard_DS1_v2"

  storage_os_disk {
    name = "SP-Os-Disk"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "20.04-LTS"
    version = "latest"
  }

  os_profile {
    computer_name = "Sourav-VM"
    admin_username = "vmsourav"
    admin_password = "vmsourav12345"
  } 

  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled = "true"
    storage_uri = azurerm_storage_account.sp.primary_blob_endpoint
  }

  tags = {
    environment = "sp-test"
  }
}