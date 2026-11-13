variable "region" {
  default = "us-east-1"
}

variable "zone1" {
  default = "us-east-1a"
}

variable "webuser" {
  default = "ubuntu"
}

variable "amiID" {
  type = map(any)
  default = {
    us-east-1 = "ami-0d97d7f07b25dd693"
    us-east-2 = "ami-020ba0ae8c230ae28"
  }
}