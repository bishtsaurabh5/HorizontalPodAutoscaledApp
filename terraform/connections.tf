provider "google" {
#Place your secrets.json file outside the clone repo or in any other path , These credentials are generated when you create a service account from IAM in GCP
  credentials = "${file("../../secrets/secrets.json")}"
#Enter the project name
  project     = "zippy-chain-243507"
#Enter the region name
  region      = "us-west1"
}
