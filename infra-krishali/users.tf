resource "aws_iam_group" "backup_users" {
  name = "${local.project}-backup-users"
}

resource "aws_iam_user" "krishan_macbook" {
  name = "${local.project}-krishan-macbook"
  tags = {
    app = local.project
  }
}

resource "aws_iam_access_key" "krishan_macbook" {
  user = aws_iam_user.krishan_macbook.name
}

output "krishan_macbook_iam_key" {
  value = aws_iam_access_key.krishan_macbook.id
  sensitive = true
}

output "krishan_macbook_iam_secret" {
  value = aws_iam_access_key.krishan_macbook.secret
  sensitive = true
}

output "krishan_macbook_iam_arn" {
  value = aws_iam_user.krishan_macbook.arn
  sensitive = true
}

resource "aws_iam_user_group_membership" "krishan_macbook" {
  user = aws_iam_user.krishan_macbook.name
  groups = [
    aws_iam_group.backup_users.name,
  ]
}

resource "aws_iam_user" "krupali_macbook" {
  name = "${local.project}-krupali-macbook"
  tags = {
    app = local.project
  }
}

resource "aws_iam_access_key" "krupali_macbook" {
  user = aws_iam_user.krupali_macbook.name
}

output "krupali_macbook_iam_key" {
  value = aws_iam_access_key.krupali_macbook.id
  sensitive = true
}

output "krupali_macbook_iam_secret" {
  value = aws_iam_access_key.krupali_macbook.secret
  sensitive = true
}

output "krupali_macbook_iam_arn" {
  value = aws_iam_user.krupali_macbook.id
  sensitive = true
}

resource "aws_iam_user_group_membership" "krupali_macbook" {
  user = aws_iam_user.krupali_macbook.name
  groups = [
    aws_iam_group.backup_users.name,
  ]
}

resource "aws_iam_group_policy_attachment" "backup_users_read_from_storage" {
  group = aws_iam_group.backup_users.name
  policy_arn = aws_iam_policy.read_from_storage.arn
}

resource "aws_iam_group_policy_attachment" "backup_users_write_to_storage" {
  group = aws_iam_group.backup_users.name
  policy_arn = aws_iam_policy.write_to_storage.arn
}
