resource "aws_iam_group" "backup_users" {
  name = "${local.project}-backup-users"
}

resource "aws_iam_user" "krishan_macbook_backup" {
  name = "${local.project}-krishan-macbook-backup"
  tags = {
    app = local.project
  }
}

resource "aws_iam_access_key" "krishan_macbook_backup" {
  user = aws_iam_user.krishan_macbook_backup.name
}

output "krishan_macbook_backup_iam_key" {
  value     = aws_iam_access_key.krishan_macbook_backup.id
  sensitive = true
}

output "krishan_macbook_backup_iam_secret" {
  value     = aws_iam_access_key.krishan_macbook_backup.secret
  sensitive = true
}

resource "aws_iam_user_group_membership" "krishan_macbook_backup" {
  user = aws_iam_user.krishan_macbook_backup.name
  groups = [
    aws_iam_group.backup_users.name,
  ]
}

resource "aws_iam_user" "krupali_macbook_backup" {
  name = "${local.project}-krupali-macbook-backup"
  tags = {
    app = local.project
  }
}

resource "aws_iam_access_key" "krupali_macbook_backup" {
  user = aws_iam_user.krupali_macbook_backup.name
}

output "krupali_macbook_backup_iam_key" {
  value     = aws_iam_access_key.krupali_macbook_backup.id
  sensitive = true
}

output "krupali_macbook_backup_iam_secret" {
  value     = aws_iam_access_key.krupali_macbook_backup.secret
  sensitive = true
}

resource "aws_iam_user_group_membership" "krupali_macbook_backup" {
  user = aws_iam_user.krupali_macbook_backup.name
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
