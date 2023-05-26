resource "aws_s3_bucket" "client-log-storage" {
  # Nome do bucket
  bucket = var.bucket_name

  tags = {
    Name        = "projetoOnishi"
    Environment = "Dev"
  }

  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_kms_s3" {
  bucket = aws_s3_bucket.client-log-storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.master_key.arn
      sse_algorithm = "aws:kms"
    }
  }
}