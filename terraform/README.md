# Entendendo o Código em Terraform

Para facilitar a leitura, dividi o projeto em 7 arquivos:
- `api-gateway.tf`
- `iam.tf`
- `kms.tf`
- `lambda.tf`
- `providers.tf`
- `s3.tf`
- `variables.tf`

Vamos destrinchá-los um por um:

## `providers.tf`
Esse arquivo foi criado para isolar um trecho de código comum em todas os códigos terraform: definição de provedores. Não há nada que vá além dos tutoriais iniciais de terraform aqui. A região `us-east-2` ao acaso e pode ser trocada por qualquer outra.

```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}
```

## `variables.tf`
Definitivamente o arquivo mais simples do projeto, o `variables.tf` é o responsável por definir todas as variáveis de entrada do nosso programa. Como só temos uma variável, na prática esse arquivo apenas coleta o nome do bucket a ser criado:

```terraform
variable "bucket_name" {
  description = "Nome desejado pro S3 Bucket"
  type        = string
  nullable = false
}
```

## `kms.tf`

O AWS Key Management Service faz o controle de chaves com várias possibilidades de aplicação. Para o nosso caso, a chave administrada pelo KMS criptografa e descriptografa os objetos do bucket s3.

O trecho de código abaixo cria uma chave KMS com o uso desejado ("ENCRYPT DECRYPT") e utiliza o método de criptografia simétrica.  Além disso, ainda determinei um prazo de 30 dias para deleção da chave (uma chave KMS tem um prazo de duração forçado entre 7 e 30 dias)

```terraform

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
```

Além disso, ainda forneci um alias para a chave criada para facilitar a visualização dela no Dashboard da AWS.

```terraform
resource "aws_kms_alias" "alias_master_key" {
  name          = "alias/master-key-s3"
  target_key_id = aws_kms_key.master_key.id
}
```

> **Nota:**  Como as chaves da AWS foram compartilhadas, utilizo tags na maior parte dos recursos criados apenas para facilitar a diferenciação dos meus recursos dos meus outros colegas

## `s3.tf`

O Amazon S3 (Simple Storage Service) é o serviço de armazenamento em nuvem da AWS. No nosso caso, a única coisa que ele armazenará são arquivos json, mas ele permite que você armazene imagens, vídeos e outros tipos de conteúdo. 

A aplicação do s3 através de terraform também é simples. Note que utilizei a variável bucket_name, que configurei no arquivo `variables.tf`.

```terraform
resource "aws_s3_bucket" "client-log-storage" {
  # Nome do bucket
  bucket = var.bucket_name

  tags = {
    Name        = "projetoOnishi"
    Environment = "Dev"
  }

  force_destroy = true
}
```

Outro parâmetro importante desse trecho de código é o `force_destroy`. Por padrão, buckets com objetos dentro não podem ser apagados através do `terraform destroy`, o que se torna frustrante em etapa de produção (um dos problemas relacionados com esse comportamento padrão é que a chave kms associada ao bucket é apagada, mas não o bucket. Demorou uma quantidade de tempo a qual eu não me orgulho para finalmente entender o porque eu não conseguia mais utilizar o meu s3). Contudo, em etapa de aplicação pode ser uma boa ideia trocar esse parâmetro como forma de segurança. Fica a seu cargo decidir.

Lembra que os dados do bucket são criptografados pelo KMS? Fazemos essa configuração no trecho de código abaixo:

```terraform
resource "aws_s3_bucket_server_side_encryption_configuration" "config_kms_s3" {
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
```



