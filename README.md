# HorizontalPodAutoscaledApp
This repository autoscales guestbook app using nginx ingress controller on GKE

## Pre-requisites for running
1) Install [terraform](https://www.terraform.io/downloads.html).
2) Install [gcloud](https://cloud.google.com/sdk/install) SDK.
3) Install [jq](https://stedolan.github.io/jq/download/) which is a command line JSON processor.
4) Enable the [GKE api](https://console.developers.google.com/apis/api/container.googleapis.com/overview)

## Usage
1) Make a separate service account from your gcloud console for terraform with admin privileges and download the credentials as a json file.
2) Rename the credentials json as secrets.json and place in a new secrets directory outside the projects with name as secrets.json.
3) Initialize gcloud using ```gcloud init``` and make a new project.
4) Add the name(project-id) of your project in [connections.tf](terraform/connections.tf) file in terraform directory.
5) Add the details for your cluster in [terraform.tfvars](terraform/terraform.tfvars)
6) Run [setup.sh](setup.sh) and setup cluster and view autoscaling in action.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
