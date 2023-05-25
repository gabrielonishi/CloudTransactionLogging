resource "aws_iam_role" "lambda-read-role" {
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
}

resource "aws_iam_role" "lambda-write-role" {
  name = "lambda-write-role"
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
}

resource "aws_iam_policy" "lambda-read-policy" {
  name = "lambda-read-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*",
        "s3-object-lambda:Get*",
        "s3-object-lambda:List*"
      ]
      Resource = ["*"]
      }, {
      Effect = "Allow"
      Action = [

        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateAlias",
        "kms:CreateKey",
        "kms:DeleteAlias",
        "kms:Describe*",
        "kms:GenerateRandom",
        "kms:Get*",
        "kms:List*",
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

resource "aws_iam_policy" "lambda-write-policy" {
  name = "lambda-write-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:*",
        "s3-object-lambda:*",
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
        "kms:TagResource",
        "kms:UntagResource",
        "kms:GenerateDataKey",
        "kms:ReEncrypt*",
        "kms:DescribeKey",
        "kms:CreateGrant",
        "iam:ListGroups",
        "iam:ListRoles",
        "iam:ListUsers"
      ]
      Resource = [aws_kms_key.master_key.arn]
      }, {
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject"
      ]
      Resource = [aws_s3_bucket.client-log-storage.arn]
      }, {
      Effect = "Allow"
      Action = [
        "apigateway:*"
      ]
      Resource = ["arn:aws:apigateway:*::/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-read-attach" {
  policy_arn = aws_iam_policy.lambda-read-policy.arn
  role       = aws_iam_role.lambda-read-role.name
}

resource "aws_iam_role_policy_attachment" "read-basic-exec-attach" {
  role       = aws_iam_role.lambda-read-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda-write-attach" {
  policy_arn = aws_iam_policy.lambda-write-policy.arn
  role       = aws_iam_role.lambda-write-role.name
}

resource "aws_iam_role_policy_attachment" "write-basic-exec-attach" {
  role       = aws_iam_role.lambda-write-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}