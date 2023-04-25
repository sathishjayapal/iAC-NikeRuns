# iAC-Runs

* TF to provision Azure and AWS infrastructure to run the application.
* Currently, the Container apps will provision the configserver needed for the RUNS application microservices.
## Commands
* terraform destroy -var-file="secrets.tfvars"
* terraform apply -var-file="nikerun-secrets.tfvars"
* terraform plan -var-file="nikerun-secrets.tfvars" 

