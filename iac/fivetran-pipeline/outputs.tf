output "destination_id" {
  description = "The Fivetran destination resource ID."
  value       = fivetran_destination.demo_dest.id
}

output "destination_service" {
  description = "The Fivetran destination service type that was provisioned."
  value       = fivetran_destination.demo_dest.service
}

output "connector_ids" {
  description = "Map of connector name to Fivetran connector ID."
  value       = { for k, v in fivetran_connector.connectors : k => v.id }
}

output "connector_schemas" {
  description = "Map of connector name to destination schema name."
  value       = { for k, v in fivetran_connector.connectors : k => v.destination_schema.name }
}

output "destination_schema" {
  description = "Destination schema name of the first connector (for backwards compatibility)."
  value       = length(var.connectors) > 0 ? var.connectors[0].schema_name : ""
}
