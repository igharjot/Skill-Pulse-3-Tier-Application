terraform {
  backend "local" {
    path = "production.tfstate"
  }
}