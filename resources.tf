resource "digitalocean_ssh_key" "my_ssh_key" {
  name       = var.email_tag
  public_key = file(var.public_ssh_key_file_path)
}

resource "random_password" "password" {
  count = var.droplet_count
  length = 16
  special = true
}

resource "digitalocean_droplet" "web" {
  count = var.droplet_count
  image  = "ubuntu-22-04-x64"
  name   = "web-${count.index + 1}"
  region = element(data.digitalocean_regions.available.regions, 0).slug
  size   = element(data.digitalocean_sizes.main.sizes, 0).slug
  ssh_keys = [data.digitalocean_ssh_key.existing_ssh_key.id, digitalocean_ssh_key.my_ssh_key.id]
  tags = ["devops", var.email_tag]

  provisioner "remote-exec" {
      connection {
      type     = "ssh"
      user     = "root"
      private_key = file(var.private_ssh_key_file_path)
      host     = self.ipv4_address
      agent    = false
    }

    inline = [
      "echo 'root:${random_password.password[count.index].result}' | chpasswd"
    ]
  }
}

# locals {
#   droplet_ips = [for droplet in digitalocean_droplet.web : droplet.ipv4_address]
# }

resource "aws_route53_record" "my_dns_record" {
  count = var.droplet_count
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${var.personal_domain_prefix}-${count.index + 1}"
  type    = "A"
  ttl     = "300"
  # records = local.droplet_ips
  records = [digitalocean_droplet.web[count.index].ipv4_address]
}
