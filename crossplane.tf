resource "aws_iam_role" "crossplane" {
  name               = "${var.app_name}-crossplane"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.eks.outputs.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:crossplane-system:crossplane-aws-sa"]
      variable = "${data.terraform_remote_state.eks.outputs.oidc_provider}:sub"
    }
  }
}

resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "crossplane-aws-sa"
    namespace = kubernetes_namespace.crossplane.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.crossplane.arn
      "meta.helm.sh/release-namespace" = kubernetes_namespace.crossplane.metadata[0].name
    }
  }
}


resource "aws_iam_policy" "policy" {
  name = "${var.app_name}-crossplane"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Deny",
          "Action" : [
            "iam:CreateUser",
            "iam:DeleteUser",
            "iam:UpdateUser",
            "iam:CreateAccessKey",
            "iam:DeleteAccessKey",
            "iam:UpdateAccessKey",
            "iam:AttachUserPolicy",
            "iam:DetachUserPolicy",
            "iam:PutUserPolicy",
            "iam:DeleteUserPolicy",
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:AttachRolePolicy",
            "iam:DetachRolePolicy",
            "iam:PutRolePolicy",
            "iam:DeleteRolePolicy"
          ],
          "Resource" : [
            "arn:aws:iam::*:user/root",
            "arn:aws:iam::*:user/admin",
            "arn:aws:iam::*:role/admin",
            "arn:aws:iam::*:role/root"
          ]
        },
        {
          "Effect" : "Deny",
          "Action" : [
            "ec2:*",
            "rds:*",
            "redshift:*",
            "elasticloadbalancing:*",
            "autoscaling:*",
            "emr:*",
            "eks:CreateCluster",
            "eks:DeleteCluster"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*",
            "cloudfront:*",
            "route53:*",
            "lambda:*",
            "dynamodb:*",
            "logs:*",
            "events:*",
            "sns:*",
            "sqs:*",
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey",
            "kms:DescribeKey",
            "acm:*",
            "iam:PassRole"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Deny",
          "Action" : "iam:PassRole",
          "Resource" : [
            "arn:aws:iam::*:role/admin",
            "arn:aws:iam::*:role/root"
          ],
          "Condition" : {
            "StringEqualsIfExists" : {
              "iam:PassedToService" : [
                "ec2.amazonaws.com",
                "eks.amazonaws.com",
                "rds.amazonaws.com"
              ]
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : "*"
        }
      ]
    }
  )
}
resource "aws_iam_policy_attachment" "crossplane" {
  name       = "crossplane"
  roles      = [aws_iam_role.crossplane.name]
  policy_arn = aws_iam_policy.policy.arn
}