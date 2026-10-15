variable "subscription_id" {
  type    = string
  default = "d712536d-a62a-4083-b2a7-d6f1b1acc79b"
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}

variable "node_count" {
  type    = number
  default = 2
}
