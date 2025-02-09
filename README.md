# iAC-Runs

* TF to provision Azure and AWS infrastructure to run the application.
* We have only a sandbox environment for Azure.
  * Delete the .terrafrom folder 
  * Delete the .terraform.lock.hcl file
* Currently, the Container apps will provision the configserver needed for the RUNS application microservices.
* The code base is based of modules.
  * The four modules are:
    * configserver - runs a configserver microservice
    * logs - runs the log service
    * storage - runs the blob storage container
    * Database Postrgres - Admin and password is hadcoded in the code.
    * resroucegroup - runs the resource group
## Simple general commands
  * To run the terraform code for Azure sandbox
    * terraform init
    * terraform apply -var-file="main.tfvars"
## Verify the resources all this in main.tfvars
    * tenant_id  = ""
    * subscription_id = ""
    * resource group name = ""        

## Commands to run confiserverwebappservice
* terraform init
* terraform apply -var-file="main.tfvars" -auto-approve
* terraform plan -var-file="main.tfvars"
* terraform destroy -var-file="main.tfvars"
## Things to remember
* Create a module folder and the two files under the module. 
* main.tf and variables.tf. 
* main.tf will have the code to create the resources and variables.tf will have the variables that are used in the main.tf file.
* Come to the root.tf file and add the module block to call the module. Make sure all the variables are passed to the module. Match up with what you have defined in the module's variables.tf file.
* Define the variables in the module and redefine them in the root-variables.tf file.
* If there are no default values, make sure main.tfvars file has the information to pass the values to the variables.
## AWS server provisoning
<!-- Create a keypair for the AWS instance, store it in local folder -->
* aws ec2 create-key-pair --key-name formypc1 --query 'KeyMaterial' --output text > formypc.pem
* chmod 700 formypc.pem


## Terraform changes
* When introducing an envrionment variable, make sure to add it to the variables.tf file and pass it to the module.
* For example, in the configserver module, we have added the environment variable for the jar file name
* Check the Dockerfile for the configserver module to see how the environment variable is used.
* Now let us start from the top here. We have root-varaibles.tf file that has the variables that are passed to the modules. Add the entry for the Jar file
* Next add the value entry in main.tfvars file.
* Goto the modules folder and add the variable in the variables.tf file.
* Change the main.tf file to use the variable.

