provider "google" {
  credentials = "${file("secrets/terraform_project1.json")}"
  project     = "zippy-chain-243507"
  region      = "us-west1"
}
