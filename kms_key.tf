resource "aws_kms_key" "encrypt_decrypt" {
  description = "KMS used to publish and consume encrypted events in the bus"
  key_usage   = "ENCRYPT_DECRYPT"
}

resource "aws_kms_key_policy" "allow_key_usage" {
  key_id = aws_kms_key.encrypt_decrypt.id
  policy = jsonencode({
    Id = "allow_key_usage"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }

        Resource = "*"
        Sid      = "allow_key_usage"
      },
    ]
    Version = "2012-10-17"
  })
}