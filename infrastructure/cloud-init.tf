data "aws_region" "current" {
  current = true
}

data "template_file" "ssh_config" {
  template = "${file("${path.module}/template/ssh_config.tmpl.sh")}"

  vars {
    users_ca_publickey = "${var.users_ca_publickey}"
    region             = "${data.aws_region.current.name}"
  }
}

data "template_cloudinit_config" "ssh_config" {
  gzip          = true
  base64_encode = true

  # Setup hello world script to be called by the cloud-config
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.ssh_config.rendered}"
  }
}

output "cloud_init_config" {
  value = "${data.template_cloudinit_config.ssh_config.rendered}"
}
