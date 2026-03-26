terraform {
  required_providers {
    fivetran = {
      source  = "fivetran/fivetran"
      version = "~> 1.9"
    }
  }
}

provider "fivetran" {
  api_key    = var.fivetran_api_key
  api_secret = var.fivetran_api_secret
}

# ─────────────────────────────────────────────
# Destination
# Supports: postgres_rds_warehouse | snowflake | bigquery
# ─────────────────────────────────────────────
resource "fivetran_destination" "demo_dest" {
  group_id         = var.group_id
  service          = var.destination_service
  region           = var.region
  time_zone_offset = var.time_zone_offset
  run_setup_tests  = var.run_setup_tests

  # Single config block — attributes are conditionally set based on destination_service.
  # Unused attributes default to null and are ignored by the provider.
  config {
    # PostgreSQL / RDS (AWS)
    # Snowflake — host is derived from account identifier
    # Azure SQL / Synapse — host is the Azure SQL server FQDN
    host = contains(["postgres_rds_warehouse"], var.destination_service) ? var.db_host : (
      var.destination_service == "snowflake" ? "${var.snowflake_account}.snowflakecomputing.com" : (
        contains(["azure_sql_warehouse", "azure_sql_managed_instance"], var.destination_service) ? var.azure_sql_server : null
      )
    )
    port = contains(["postgres_rds_warehouse"], var.destination_service) ? var.db_port : (
      var.destination_service == "snowflake" ? 443 : (
        contains(["azure_sql_warehouse", "azure_sql_managed_instance"], var.destination_service) ? var.azure_sql_port : null
      )
    )
    database = contains(["postgres_rds_warehouse"], var.destination_service) ? var.db_name : (
      var.destination_service == "snowflake" ? var.snowflake_database : (
        contains(["azure_sql_warehouse", "azure_sql_managed_instance"], var.destination_service) ? var.azure_sql_database : null
      )
    )
    user = contains(["postgres_rds_warehouse"], var.destination_service) ? var.db_user : (
      var.destination_service == "snowflake" ? var.snowflake_user : (
        contains(["azure_sql_warehouse", "azure_sql_managed_instance"], var.destination_service) ? var.azure_sql_user : null
      )
    )
    password = contains(["postgres_rds_warehouse"], var.destination_service) ? var.db_password : (
      var.destination_service == "snowflake" ? var.snowflake_password : (
        contains(["azure_sql_warehouse", "azure_sql_managed_instance"], var.destination_service) ? var.azure_sql_password : null
      )
    )
    connection_type = contains(["postgres_rds_warehouse"], var.destination_service) ? var.connection_type : null

    # SSH tunnel — only when connection_type = SshTunnel
    tunnel_host = var.connection_type == "SshTunnel" ? var.tunnel_host : null
    tunnel_port = var.connection_type == "SshTunnel" ? var.tunnel_port : null
    tunnel_user = var.connection_type == "SshTunnel" ? var.tunnel_user : null

    # Azure SQL / Synapse — host/port/database/user/password reuse the same config fields
    # project_id and data_set_location are left null for non-BigQuery destinations
    project_id        = null
    data_set_location = null
  }
}

# ─────────────────────────────────────────────
# Connectors (one per entry in var.connectors)
# ─────────────────────────────────────────────
resource "fivetran_connector" "connectors" {
  for_each = { for c in var.connectors : c.name => c }

  group_id = fivetran_destination.demo_dest.group_id
  service  = each.value.service

  destination_schema {
    name = each.value.schema_name
  }

  depends_on = [fivetran_destination.demo_dest]
}

# ─────────────────────────────────────────────
# Connector Schedules
# ─────────────────────────────────────────────
resource "fivetran_connector_schedule" "schedules" {
  for_each = { for c in var.connectors : c.name => c }

  connector_id   = fivetran_connector.connectors[each.key].id
  sync_frequency = tostring(each.value.sync_frequency)
  paused         = each.value.paused
}
