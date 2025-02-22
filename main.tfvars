#Base names
base_name        = "sathish"
tenant_id  = "84f1e4ea-8554-43e1-8709-f0b8589ea118"
subscription_id = "2213e8b1-dbc7-4d54-8aff-b5e315df5e5b"
timeout_min      = "30m"
timeout_delete   = "2h"
primary_location = "East US"

#Resource Group Variables
rg_name = "1-730b43e6-playground-sandbox"
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
# storage container                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ner attributes
container_access_type = "blob"

#Container Instances attributes
configServerImageName = "docker.io/travelhelper0h/sathishproject-config-server:latest"
configServercpu = 0.5
configServermemory = 1.5
configServerport = 8888
configServerprotocol = "TCP"
configServerusername = "sathish"
configServerpass = "pass"
appserviceport = 8888
git_uri = "https://github.com/sathishjayapal/jubilant-memory.git"
encrypt_key = "MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBAK8GMsEw44Vw71MsofkIaS5PWKVP1A2yNCxoXNP31VEi4gCUt2ViRkan/c4/WXW7eAOP07Qh7Z287TfZFbgH2oNpVBakuTo5VdmpknZ3z89I4ah36l3+DwaY7JuSSVl0KzDs/xXesmJxBU8gxtNh9AzTvYxuR4bTGPZDMVJuBQ9nAgMBAAECgYAoxQbZnavCD7aP51uriNwHX5BEob3BmvswRPcqoRZdmgSPIhU+VpAMMWGbw4HxPMQOAFjOIwEYt0OCuNyoS5wIkJwYpu5skP5dZ02+TnzZ4LQpEIyLWZtK2BVK/PXTGmMh0zYBE4Ruvx4pwfb0A0nltzY5H5yCR72QMnZloR/T0QJBAPb5MDkobGB19rUezSxUAuCQeLEmdmH5BHD71jtS/EaPCKGkp4ifZ/SO5N8JibyN5MLZ/dDZ51GOWOY4LTn9hbsCQQC1a9DfBVvtJlgtg+aITZwV+rHLKlVP141RbOmoYWJwrubja4fmkQuqXJNfeei3LQ6XclvXHujq9LLCpvlo7cxFAkEAxusDlTXivHqmn1DUrhxoSNjz7LLu7JA1rI6aCSQYvvfbWt4Udez2PLqOyrmS74RVuT78uKeZMU32ek7K1odEmwJBALR8SXTGURjSD+FgGoW5qDHZkO2M9QiUafv6vU4NbDCsX/kaLj58SD25EchncNRjF+QlGicekhvFSt4J3ZC9Gn0CQQDVLHandZGEYx6M1jWzZU8VN/DVUuxrAy3a8kpjxWzCpHCPl2uPr4v4Up3bw8oZwrUG6A06mgV2+bZ4uxkSV7oZ"
jar_file ="sathishconfigserver.jar"

#Common docker registry attributes
docker_registry_server_url = "docker.io"
docker_registry_server_username = "travelhelper0h"
docker_registry_server_password = "dckr_pat_OKaYR_PWGTejmPSrPcBwBqIdcZc"

ip_rules= {
  allhosts = "0.0.0.0"
  selfhost = "127.0.0.1"
}
