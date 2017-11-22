# Retrieve AWS credentials from env variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
terraform {
  backend "s3" {
    bucket = "7771-7135-9344-terraform-state"
    key    = "k8s"
    region = "eu-west-1"
  }
}

provider "aws" {
  access_key = ""
  secret_key = ""
  region = "${var.region}"
}
