# ─────────────────────────────────────────────
# Fivetran Auth
# ─────────────────────────────────────────────
variable "fivetran_api_key" {
  type        = string
  description = "Fivetran API key for authenticating with the Fivetran provider."
  sensitive   = true
}

variable "fivetran_api_secret" {
  type        = string
  description = "Fivetran API secret for authenticating with the Fivetran provider."
  sensitive   = true
}

variable "group_id" {
  type        = string
  description = "Fivetran group ID that contains the destination and connectors."
}

# ─────────────────────────────────────────────
# Destination — General
# ─────────────────────────────────────────────
variable "destination_service" {
  type        = string
  description = "Fivetran destination service type. One of: postgres_rds_warehouse, snowflake, azure_sql_warehouse, azure_sql_managed_instance."
  default     = "postgres_rds_warehouse"

  validation {
    condition     = contains(["postgres_rds_warehouse", "snowflake", "azure_sql_warehouse", "azure_sql_managed_instance"], var.destination_service)
    error_message = "destination_service must be one of: postgres_rds_warehouse, snowflake, azure_sql_warehouse, azure_sql_managed_instance."
  }
}

variable "region" {
  type        = string
  description = "Fivetran destination region. AWS examples: US_EAST_1, US_WEST_2. Azure examples: AZURE_EAST_US, AZURE_WEST_EUROPE."
  default     = "US_EAST_1"
}

variable "time_zone_offset" {
  type        = string
  description = "UTC time zone offset for the destination (e.g. '0', '-5')."
  default     = "0"
}

variable "run_setup_tests" {
  type        = bool
  description = "Whether Fivetran should run connection setup tests on destination creation."
  default     = true
}

# ─────────────────────────────────────────────
# Destination — PostgreSQL
# ─────────────────────────────────────────────
variable "db_host" {
  type        = string
  description = "Hostname of the PostgreSQL destination database."
  default     = ""
}

variable "db_port" {
  type        = number
  description = "Port number of the PostgreSQL destination database."
  default     = 5432
}

variable "db_name" {
  type        = string
  description = "Name of the PostgreSQL destination database."
  default     = ""
}

variable "db_user" {
  type        = string
  description = "Username for the PostgreSQL destination database."
  default     = ""
}

variable "db_password" {
  type        = string
  description = "Password for the PostgreSQL destination database."
  sensitive   = true
  default     = ""
}

variable "connection_type" {
  type        = string
  description = "PostgreSQL connection method. One of: Directly, SshTunnel, PrivateLink."
  default     = "Directly"

  validation {
    condition     = contains(["Directly", "SshTunnel", "PrivateLink"], var.connection_type)
    error_message = "connection_type must be one of: Directly, SshTunnel, PrivateLink."
  }
}

# ─────────────────────────────────────────────
# Destination — SSH Tunnel (optional)
# ─────────────────────────────────────────────
variable "tunnel_host" {
  type        = string
  description = "SSH tunnel host. Required when connection_type = SshTunnel."
  default     = ""
}

variable "tunnel_port" {
  type        = number
  description = "SSH tunnel port. Required when connection_type = SshTunnel."
  default     = 22
}

variable "tunnel_user" {
  type        = string
  description = "SSH tunnel username. Required when connection_type = SshTunnel."
  default     = ""
}

# ─────────────────────────────────────────────
# Destination — Snowflake (optional)
# ─────────────────────────────────────────────
variable "snowflake_account" {
  type        = string
  description = "Snowflake account identifier. Required when destination_service = snowflake."
  default     = ""
}

variable "snowflake_database" {
  type        = string
  description = "Snowflake database name. Required when destination_service = snowflake."
  default     = ""
}

variable "snowflake_warehouse" {
  type        = string
  description = "Snowflake virtual warehouse name. Required when destination_service = snowflake."
  default     = ""
}

variable "snowflake_role" {
  type        = string
  description = "Snowflake role to use for the connection."
  default     = ""
}

variable "snowflake_user" {
  type        = string
  description = "Snowflake username. Required when destination_service = snowflake."
  default     = ""
}

variable "snowflake_password" {
  type        = string
  description = "Snowflake password. Required when destination_service = snowflake."
  sensitive   = true
  default     = ""
}

# ─────────────────────────────────────────────
# Destination — Azure SQL / Synapse (optional)
# ─────────────────────────────────────────────
variable "azure_sql_server" {
  type        = string
  description = "Azure SQL server hostname (e.g. myserver.database.windows.net). Required when destination_service = azure_sql_warehouse or azure_sql_managed_instance."
  default     = ""
}

variable "azure_sql_database" {
  type        = string
  description = "Azure SQL database name. Required when destination_service = azure_sql_warehouse or azure_sql_managed_instance."
  default     = ""
}

variable "azure_sql_user" {
  type        = string
  description = "Azure SQL username. Required when destination_service = azure_sql_warehouse or azure_sql_managed_instance."
  default     = ""
}

variable "azure_sql_password" {
  type        = string
  description = "Azure SQL password. Required when destination_service = azure_sql_warehouse or azure_sql_managed_instance."
  sensitive   = true
  default     = ""
}

variable "azure_sql_port" {
  type        = number
  description = "Azure SQL port. Default is 1433."
  default     = 1433
}

# ─────────────────────────────────────────────
# Connectors
# ─────────────────────────────────────────────
variable "connectors" {
  description = "List of Fivetran connector definitions to create."
  type = list(object({
    name           = string                # logical name used in resource naming
    service        = string                # Fivetran service type (e.g. webhooks)
    schema_name    = string                # destination schema name
    sync_frequency = optional(number, 60)  # sync interval in minutes
    paused         = optional(bool, false) # whether the connector starts paused
  }))
  default = [
    {
      name           = "jsonplaceholder"
      service        = "webhooks"
      schema_name    = "jsonplaceholder_users"
      sync_frequency = 60
      paused         = false
    }
  ]
}
