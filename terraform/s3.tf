resource "aws_s3_bucket" "client-log-storage" {
  # Nome do bucket
  bucket = var.bucket_name

  tags = {
    Name        = "projetoOnishi"
    Environment = "Dev"
  }
}

# Configuração da criptografia
resource "aws_s3_bucket_server_side_encryption_configuration" "config_kms_s3" {
  # Referencia bucket a ser configurado
  bucket = aws_s3_bucket.client-log-storage.id

  # Regras para criptografia
  rule {
    # 
    apply_server_side_encryption_by_default {
      # Master key utilizada
      kms_master_key_id = aws_kms_key.master_key.arn
      # Algoritmo usado
      sse_algorithm = "aws:kms"
    }
  }
}