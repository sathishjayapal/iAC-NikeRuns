terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.47.0"
    }
  }
}
provider "azurerm" {
  subscription_id = "b43c969f-b5f5-42ce-a1f3-57886e9935b2"
  tenant_id       = "3c44a19d-2993-4b1d-868e-3c7bcf63bc60"
  client_id       = ""
  features {}
}
