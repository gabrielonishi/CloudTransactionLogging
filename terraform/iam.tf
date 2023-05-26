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
}

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

resource "aws_iam_role_policy_attachment" "basic_role" {
  role       = aws_iam_role.s3_manager_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "kms_s3_permission" {
  role       = aws_iam_role.s3_manager_role.name
  policy_arn = aws_iam_policy.s3_manager_policy.arn
}