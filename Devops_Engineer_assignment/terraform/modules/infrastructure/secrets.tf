# Database credentials secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}-${var.environment}-db-credentials"
  description = "Database credentials for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_instance.postgres.endpoint
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
  })
}

# Redis credentials secret
resource "aws_secretsmanager_secret" "redis_credentials" {
  name        = "${var.project_name}-${var.environment}-redis-credentials"
  description = "Redis credentials for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id
  secret_string = jsonencode({
    host = aws_elasticache_replication_group.redis.primary_endpoint_address
    port = aws_elasticache_replication_group.redis.port
  })
}

# API Keys secret
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "${var.project_name}-${var.environment}-api-keys"
  description = "API keys for ${var.project_name} ${var.environment}"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    jwt_secret_key = random_password.jwt_secret.result
    api_key        = random_password.api_key.result
  })
}

# Random passwords
resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

resource "random_password" "api_key" {
  length  = 32
  special = false
}
# KMS key for secrets encryption
resource "aws_kms_key" "secrets" {
  description             = "KMS key for ${var.project_name} ${var.environment} secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}