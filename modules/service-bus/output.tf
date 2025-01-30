output "servicebus_name" {
  description = "The name of the service bus"
  value       = azurerm_servicebus_namespace.servicebus_namespace.endpoint
}
output "servicebus_topic" {
  description = "The azurerm_servicebus_queue"
  value       = azurerm_servicebus_queue.servicebus_namespace_queue.name
}
output "servicebus_topic_id" {
  description = "The service bus connection"
  value       = azurerm_servicebus_queue.servicebus_namespace_queue.id
}
