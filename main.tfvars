#Base names
base_name        = "sathish"
tenant_id  = "84f1e4ea-8554-43e1-8709-f0b8589ea118"
subscription_id = "28e1e42a-4438-4c30-9a5f-7d7b488fd883"
timeout_min      = "30m"
timeout_delete   = "2h"
primary_location = "South Central US"

#Resource Group Variables
rg_name = "1-3b7cf225-playground-sandbox"
prefix  = "test"
environment = "dev"
#Log related properties
log_sku            = "PerGB2018"
log_retention_days = 30
log_name           = "sathishnikerunserverlogs"

#Container related properties
restart_policy  = "Always"
ip_address_type = "Public"
os_type         = "Linux"
dns_name_label  = "sathishnikerunsuxp"

#AppService properties
dockerimagewithurl = "docker.io/travelhelper0h/nikerunuxp:latest"
appservice-ostype  = "Linux"
appservice-sku     = "F1"
main_group_name = "sathisprj1"

# storage account attributes
account_tier = "Standard"
account_replication_type = "GRS"
account_kind = "StorageV2"
# storage contai                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ner attributes
container_access_type = "blob"

#Container Instances attributes
configServerImageName = "docker.io/travelhelper0h/sathishproject-config-server:latest"
configServercpu = 0.5
configServermemory = 1.5
configServerport = 8888
configServerprotocol = "TCP"
configServerusername = "sathish"
configServerpass = "pass"

#Common docker registry attributes
docker_registry_server_url = "docker.io"
docker_registry_server_username = "travelhelper0h"
docker_registry_server_password = "dckr_pat_OKaYR_PWGTejmPSrPcBwBqIdcZc"

ip_rules= {
  allhosts = "0.0.0.0"
  selfhost = "127.0.0.1"
}
