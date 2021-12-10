resource "aws_iam_group" "cyberduck_users" {
  name = "${local.project}-cyberduck-users"
}

resource "aws_iam_user" "krishan_macbook_cyberduck" {
  name = "${local.project}-krishan-macbook-cyberduck"
  tags = {
    app = local.project
  }
}

resource "aws_iam_access_key" "krishan_macbook_cyberduck" {
  user = aws_iam_user.krishan_macbook_cyberduck.name
}

output "krishan_macbook_cyberduck_iam_key" {
  value     = aws_iam_access_key.krishan_macbook_cyberduck.id
  sensitive = true
}

output "krishan_macbook_cyberduck_iam_secret" {
  value     = aws_iam_access_key.krishan_macbook_cyberduck.secret
  sensitive = true
}

resource "aws_iam_user_group_membership" "krishan_macbook_cyberduck" {
  user = aws_iam_user.krishan_macbook_cyberduck.name
  groups = [
    aws_iam_group.cyberduck_users.name,
  ]
}

resource "aws_iam_group_policy_attachment" "cyberduck_users_read_from_storage" {
  group = aws_iam_group.cyberduck_users.name
  policy_arn = aws_iam_policy.read_from_storage.arn
}

resource "aws_iam_group_policy_attachment" "cyberduck_users_write_to_storage" {
  group = aws_iam_group.cyberduck_users.name
  policy_arn = aws_iam_policy.write_to_storage.arn
}
