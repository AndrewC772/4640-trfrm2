terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# data blocks contained here

#declare the ssh key
data "digitalocean_ssh_key" "lab_ssh_key" {
  name = "River"
  #name = "4640_Lab"
}

#declares the project name
data "digitalocean_project" "lab_project" {
  name = "4640_labs"
  #name = "BCIT_4640"
}

# resource blocks contained here

#Create a tag
resource "digitalocean_tag" "do_tag" {
  name = "Web"
}

#Create a new VPC
resource "digitalocean_vpc" "web_vpc" {
  name   = "web"
  region = var.region
}

#Create a new VM
resource "digitalocean_droplet" "web" {
  image    = "rockylinux-9-x64"
  name     = "web-${count.index + 1}"
  count    = var.droplet_count
  tags     = [digitalocean_tag.do_tag.id]
  region   = "sfo3"
  size     = "s-1vcpu-512mb-10gb"
  vpc_uuid = digitalocean_vpc.web_vpc.id
  ssh_keys = [data.digitalocean_ssh_key.lab_ssh_key.id]

  lifecycle {
    create_before_destroy = true
  }
}

# adds the droplets to an existing project
# the flatten will allow you to make a 2d list of the droplets so it isn't an array of arrays
resource "digitalocean_project_resources" "project_attach" {
    project = data.digitalocean_project.lab_project.id
    resources = flatten([ digitalocean_droplet.web.*.urn ])
}


#creates a loadbalancer
resource "digitalocean_loadbalancer" "public" {
  name   = "loadbalancer-1"
  region = var.region

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port     = 22
    protocol = "tcp"
  }

  droplet_tag = "Web"
  vpc_uuid = digitalocean_vpc.web_vpc.id
}


# reads out the IP of the servers
output "server_ip" {
    value = digitalocean_droplet.web.*.ipv4_address
}