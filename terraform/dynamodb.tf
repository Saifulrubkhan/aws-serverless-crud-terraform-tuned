# Single-table CRUD store, keyed on "id". No secondary indexes because the
# API only ever looks items up by their primary key (see README.md >
# Architecture > "Why these services" for why DynamoDB over RDS).
resource "aws_dynamodb_table" "items" {
  name         = "${var.project_name}-items"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-items"
  }
}
