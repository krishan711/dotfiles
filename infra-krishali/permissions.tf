ACLresource "aws_iam_policy" "read_from_storage" {
  name = "read-s3-${aws_s3_bucket.storage.bucket}"
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Action" = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ],
        "Resource" = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "s3:ListBucket"
        ],
        "Resource" = [
          aws_s3_bucket.storage.arn
        ],
        "Condition" = {
          "StringLike" = {
            "s3:prefix" = "*"
          }
        }
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "s3:List*",
          "s3:Get*"
        ],
        "Resource" = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "write_to_storage" {
  name = "write-s3-${aws_s3_bucket.storage.bucket}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        # "s3:DeleteObject",
        # "s3:DeleteObjectTagging",
        # "s3:DeleteObjectVersion",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:PutObjectRetention",
        "s3:PutObjectTagging",
        "s3:PutObjectLegalHold"
      ],
      Resource = [
        aws_s3_bucket.storage.arn,
        "${aws_s3_bucket.storage.arn}/*",
      ]
    }]
  })
}
