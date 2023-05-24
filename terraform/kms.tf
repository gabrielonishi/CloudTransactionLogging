resource "aws_kms_key" "master_key" {
  description              = "Chave criada para encriptografar dados do S3"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  # Por padrão, manti a data de expiração da chave para 30 dias
  deletion_window_in_days = 30
  tags = {
    Name = "projetoOnishi"
  }
}

resource "aws_kms_alias" "alias_master_key" {
  name          = "alias/master-key-s3"
  target_key_id = aws_kms_key.master_key.id
}