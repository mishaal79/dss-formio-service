output "instance_name" {
  description = "Name of the PostgreSQL instance"
  value       = google_sql_database_instance.postgresql.name
}

output "instance_connection_name" {
  description = "Connection name of the PostgreSQL instance"
  value       = google_sql_database_instance.postgresql.connection_name
}

output "instance_private_ip" {
  description = "Private IP address of the PostgreSQL instance"
  value       = google_sql_database_instance.postgresql.private_ip_address
}

output "instance_public_ip" {
  description = "Public IP address of the PostgreSQL instance"
  value       = google_sql_database_instance.postgresql.public_ip_address
}

output "connection_string" {
  description = "PostgreSQL connection string for the main database"
  value       = local.connection_string
  sensitive   = true
}

output "connection_strings" {
  description = "All PostgreSQL connection strings"
  value       = local.connection_strings
  sensitive   = true
}

output "connection_string_secret_id" {
  description = "Secret Manager secret ID for connection strings"
  value       = google_secret_manager_secret.postgresql_connection_string.secret_id
}

output "admin_password_secret_id" {
  description = "Secret Manager secret ID for admin password"
  value       = google_secret_manager_secret.postgres_password.secret_id
}

output "formio_user_password_secret_id" {
  description = "Secret Manager secret ID for Form.io user password"
  value       = google_secret_manager_secret.formio_user_password.secret_id
}

output "database_names" {
  description = "Names of created databases"
  value = {
    main         = google_sql_database.formio_db.name
    submissions  = google_sql_database.form_submissions_db.name
    analytics    = google_sql_database.form_analytics_db.name
    templates    = google_sql_database.form_templates_db.name
  }
}

output "usernames" {
  description = "Database usernames"
  value = {
    admin  = google_sql_user.postgres_user.name
    formio = google_sql_user.formio_user.name
  }
}