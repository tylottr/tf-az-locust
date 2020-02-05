Terraform: VM Lab Environment
====================================

This template will create a hub-spoke environment for lab purposes.

The environment deployed contains the following resources:
* TODO: Populate

Prerequisites
-------------

Prior to deployment you need the following:
* [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [terraform](https://www.terraform.io/) - 0.12

In Azure, you also need:
* A user account or service policy with Contributor level access to the target subscription

Variables
---------

These are the variables used along with their defaults. For any without a value in default, the value must be filled in unless otherwise sateted otherwise the deployment will encounter failures.

|Variable|Description|Default|
|-|-|-|
|tenant_id|The tenant id of this deployment|null|
|subscription_id|The subscription id of this deployment|null|
|client_id|The client id used to authenticate to Azure|null|
|client_secret|The client secret used to authenticate to Azure|null|
|location|The primary location of this deployment|UK South|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names|locust|
|tags|Tags given to the resources created by this template|{}|
|vm_username|Username for the VMs|vmadmin|
|vm_size|VM Size for the VMs|Standard_B1s|
|vm_disk_type|VM disk type for the VMs|StandardSSD_LRS|
|vm_disk_size|VM disk size for the VMs in GB (Minimum 30)|32|
|vm_count|Number of client VMs to deploy per-region|1|
|additional_location|An additional location to deploy to|West Europe|
|locustfile|The location of a Locustfile used for load testing|files/locust/Locustfile.py|

> additional_location should be changed to set(string) and be given an empty set in future when more locations are supported.

Outputs
-------

This template will output the following information:

|Output|Description|
|-|-|
|client_vm_public_ips|The public IPs of Locust agent VMs|
|server_vm_fqdn|The FQDN of the Locust server|

Deployment
----------

Below describes the steps to deploy this template.

1. Set variables for the deployment
    * Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables)
2. Log into Azure with `az login` and set your subscription with `az account set --subscription <replace with subscription id>`
    * Terraform has a number of ways to authenticate. See [here](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html)
3. Initialise Terraform with `terraform init`
    * By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html) for more information.
4. Set the workspace with `terraform workspace select <replace with environment>`
    * If the workspace does not exist, use `terraform workspace new <replace with environment>`
5. Generate a plan with `terraform plan -out tf.plan`
6. If the plan passes, apply it with `terraform apply tf.plan`

In the event the deployment needs to be destroyed, you can run `terraform destroy` in place of steps 5 and 6.