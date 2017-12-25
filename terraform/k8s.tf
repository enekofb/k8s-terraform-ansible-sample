resource "aws_s3_bucket" "k8s-backup" {
  bucket = "7771-7135-9344-k8s-backup"
  acl    = "private"


  versioning {
    enabled = true
  }

  tags {
    Owner = "${var.owner}"
    Name   = "Kubernetes backups bucket"
    ansibleFilter = "${var.ansibleFilter}"
  }

  lifecycle_rule {
    prefix  = "backups/"
    enabled = true

    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      days          = 60
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      days = 90
    }
  }
}
