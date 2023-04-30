# iAC-Runs

* TF to provision Azure and AWS infrastructure to run the application.
* Currently, the Container apps will provision the configserver needed for the RUNS application microservices.
## Commands to run confiserverwebappservice
* * terraform apply -var-file="secrets.tfvars.tfvars"
* terraform plan -var-file="secrets.tfvars.tfvars"
* terraform destroy -var-file="secrets.tfvars"

## Commands to run Nikewebappservice
* terraform apply -var-file="nikerun-secrets.tfvars"
* terraform plan -var-file="nikerun-secrets.tfvars" 

