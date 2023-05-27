# Entendendo o Código em Terraform

Para facilitar a leitura, dividi o projeto em 7 arquivos:
- `providers.tf`
- `variables.tf`
- `kms.tf`
- `s3.tf`
- `lambda.tf`
- `api-gateway.tf`
- `iam.tf`

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


## `lambda.tf`

A função lambda foi criada em python. O seu código está em `lambda/s3_manager.py`, mas o terraform só consegue mandar funções lambda através de arquivos zipados. Além de apontar a função, também é necessário apontar qual a função a ser executada ao se ativar a aplicação (handler). Por fim, ainda pode-se passar variáveis de ambiente ao lambda, como fazemos com o nome do bucket para que ela seja capaz de fazer CRUD nele.

```terraform
resource "aws_lambda_function" "s3_manager_lambda" {
  function_name    = "s3_manager"
  filename         = "s3_manager.zip"
  source_code_hash = filebase64sha256("s3_manager.zip")
  handler          = "s3_manager.lambda_handler"
  role             = aws_iam_role.s3_manager_role.arn
  runtime          = "python3.9"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.client-log-storage.id
    }
  }
}
```

> :warning: **Atenção**: Se o conteúdo da função `s3_manager.py` for alterado, é necessário recompactá-lo e substituir o antigo arquivo `.zip`.

Também configuramos o CloudWatch para verificar os logs dos requests (apenas para debugar)

```terraform
resource "aws_cloudwatch_log_group" "read-file-lambda" {
  name              = "/aws/lambda/${aws_lambda_function.s3_manager_lambda.function_name}"
  retention_in_days = 30
}
```

## `api-gateway.tf`

O api gateway é provavelmente o arquivo mais complexo desse projeto. Vamos por partes, para tentar simplificar. Criando uma API no modelo REST. Aqui também especifico que a API pode receber arquivos binários do tipo `.json`.

```terraform
resource "aws_api_gateway_rest_api" "client_log_management_API" {
  name               = "client_log_management_API"
  binary_media_types = ["application/json"]
}
```

Toda API precisa de Endpoints e métodos, e ao configurar a API Gateway isso não é diferente. Mas lembra que eu falei que a função lambda é a que maneja as requisições? Como isso funciona?

Uma possibilidade dentro da AWS é fazer as funções lambda serem ativadas por outros serviços, como o API Gateway. É o que fazemos aqui: o API Gateway não lida com as requisições, ele apenas as repassa para a função lambda, isto é, ele serve como `proxy`. O que é interessante dessa abordagem é que conseguimos fazer todo o controle de requisições através de uma só função lambda ao passo que só temos que configurar um método no API Gateway.

Essa arquitetura de API Gateway + Lambda Functions em terraform é melhor explicada no [tutorial oficial da Hashicorp](https://registry.terraform.io/providers/hashicorp/aws/2.34.0/docs/guides/serverless-with-aws-lambda-and-api-gateway#configuring-api-gateway), então vou tentar ser mais breve na explicação dos trechos de código.

Criando um resource (path) para a função proxy que recebe qualquer tipo de path com o tipo especial `{proxy+}.

```terraform
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id
  parent_id   = aws_api_gateway_rest_api.client_log_management_API.root_resource_id
  path_part   = "{proxy+}"
}
```

Criando um método para a função proxy que permite qualquer Método HTTP. **Aqui também faço algo diferente do tutorial da Hashicorp**, já que configuro que o método só pode ser executado com as chaves de api (vamos configurá-las mais para frente).

```terraform

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}
```

Aqui fazemos a integração com a função lambda. Atente-se que para qualquer integração com lambda o método de integração é `"POST"` já que enviamos um formulário contendo todo o request para a função.

```terraform
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.s3_manager_lambda.invoke_arn
}
```

Uma inconveniência de usar `proxy` é que não é possível ter um recurso de proxy com um caminho vazio na raiz da API. Por isso temos que fazer essas últimas etapas também para o `root path` da API. 

```terraform
resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id   = aws_api_gateway_rest_api.client_log_management_API.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.s3_manager_lambda.invoke_arn
}
```

Também é necessário dar permissão para o API Gateway ativar a função lambda.
```terraform
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_manager_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.client_log_management_API.execution_arn}/*/*"
}
```

Para fazer o deploy de nossa aplicação, é necessário primeiro criar um estágio de aplicação (criei um estágio `dev`), além de configurar o que acontece quando um novo deploy acontece enquanto a API ainda está de pé.

```terraform
resource "aws_api_gateway_deployment" "deploy-api" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id

  triggers = {
    redeployment = sha1(jsonencode([
      # aws_api_gateway_resource.example.id,
      aws_api_gateway_method.proxy,
      aws_api_gateway_method.proxy_root,
      aws_api_gateway_integration.lambda,
      aws_api_gateway_integration.lambda_root,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev-stage" {
  deployment_id = aws_api_gateway_deployment.deploy-api.id
  rest_api_id   = aws_api_gateway_rest_api.client_log_management_API.id
  stage_name    = "dev"
}
```

Para fazer a ativação das API Keys, é necessário:
 - Criar um `Usage Plan`
 - Criar uma API Access Key
 - Linkar o `Usage Plan` com a chave criada

O Usage Plan é necessário caso se queira dar permissões diferentes para cada método dentro da API Gateway. Pro nosso caso, isso não é tão efetivo, já que só temos um método.

```terraform
resource "aws_api_gateway_usage_plan" "standard_usage_plan" {
  name = "standard_usage_plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.client_log_management_API.id
    stage  = aws_api_gateway_stage.dev-stage.stage_name
  }
}

resource "aws_api_gateway_api_key" "api_access_key" {
  name = "api_access_key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.api_access_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.standard_usage_plan.id
}
```

Por fim, vamos exportar o url da API, assim como as chaves necessárias para acessá-la.

```terraform
output "api-url" {
  value = aws_api_gateway_stage.dev-stage.invoke_url
}

output "api-key" {
  value = aws_api_gateway_usage_plan_key.main.value
}
```

## `iam.tf`

O último arquivo é o que comunica as permissões de cada um de nossos recursos com o IAM.

Criando role da função Lambda:

```terraform
resource "aws_iam_role" "s3_manager_role" {
  name = "lambda-read-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }, {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
```

Criando uma política com as autorizações necessárias para o lambda.

```terraform
resource "aws_iam_policy" "s3_manager_policy" {
  name = "s3_manager_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*",
        "s3:Put*",
        "s3-object-lambda:Get*",
        "s3-object-lambda:List*",
        "s3-object-lambda:Put*"
      ]
      Resource = ["*"]
      }, {
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateAlias",
        "kms:CreateKey",
        "kms:DeleteAlias",
        "kms:Describe*",
        "kms:GenerateRandom",
        "kms:Get*",
        "kms:List*",
        "kms:GenerateDataKey",
        "kms:TagResource",
        "kms:UntagResource",
        "iam:ListGroups",
        "iam:ListRoles",
        "iam:ListUsers"
      ]
      Resource = [aws_kms_key.master_key.arn]
    }]
  })
}
```

Anexando a política customizada que criamos ao IAM role do lambda.

```terraform
resource "aws_iam_role_policy_attachment" "kms_s3_permission" {
  role       = aws_iam_role.s3_manager_role.name
  policy_arn = aws_iam_policy.s3_manager_policy.arn
}
```

Anexando política básica da AWS para funções Lambda

```terraform
resource "aws_iam_role_policy_attachment" "basic_role" {
  role       = aws_iam_role.s3_manager_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```
