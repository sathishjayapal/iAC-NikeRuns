#Base names
base_name        = "sathish"
subscription_id  = ""
tenant_id        = ""
timeout_min      = "30m"
timeout_delete   = "2h"
primary_location = "eastus2"

#Resource Group Variables
rg_name = "sathish_config_server_rg"

#Log related properties
log_sku            = "PerGB2018"
log_retention_days = 30
log_name           = "sathishconfigserverlogs"

#Container related properties
dockerimageforconfigserver = "travelhelper0h/sathishconfigserver:latest"
port                       = 8888
cpu_cores                  = 1
memory_in_gb               = 2

restart_policy  = "Always"
ip_address_type = "Public"
os_type         = "Linux"
dns_name_label  = "sathish-config-server"

#AppService properties

dockerimagewithurl = "docker.io/travelhelper0h/sathishconfigserver"
appservice-ostype  = "Linux"
appservice-sku     = "F1"
