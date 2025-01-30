output "eventgrid_name" {
  description = "The name of the Event Grid System Topic"
  value       = azurerm_eventgrid_system_topic.eventgridevtgrid.name
}
output "eventgrid_storage_account" {
  description = "The storage account name for event grid"
  value       = azurerm_storage_account.eventgridsa.name
}
output "eventgrid_storage_account_id" {
  description = "The storage account id for event grid"
  value       = azurerm_storage_account.eventgridsa.id
}
