data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "Full permissions for root"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = { for statement in var.kms_key_policy_statements : statement.sid => statement }
    content {
      sid       = statement.value.sid
      effect    = try(statement.value.effect, "Allow")
      actions   = try(statement.value.actions, [])
      resources = ["*"]
      dynamic "principals" {
        for_each = { for principal in try(statement.value.principals, []) : jsonencode(principal) => principal }
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
    }
  }

  dynamic "statement" {
    for_each = { for principal in var.service_principals : principal => principal }
    content {
      sid       = "Allow KMS Use by ${var.purpose} by ${statement.key}"
      effect    = "Allow"
      actions   = var.kms_actions
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = [statement.key]
      }
    }
  }
  dynamic "statement" {
    for_each = { for principal in var.iam_principals : principal => principal }
    content {
      sid       = "Allow KMS Use by ${var.purpose} by ${statement.key}"
      effect    = "Allow"
      actions   = var.kms_actions
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = [statement.key]
      }
    }
  }
}

resource "aws_kms_key" "kms" {
  count = var.encrypt_with_aws_managed_keys ? 0 : 1

  description             = "KMS Key for ${var.purpose}"
  deletion_window_in_days = 10
  policy                  = data.aws_iam_policy_document.kms.json
  enable_key_rotation     = true
}

resource "aws_kms_alias" "alias" {
  count = var.encrypt_with_aws_managed_keys ? 0 : 1

  name_prefix   = "alias/${var.bucket_prefix}"
  target_key_id = aws_kms_key.kms[0].key_id
}
