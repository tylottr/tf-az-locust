# Terraform: Locust Load Test

This template will create a multi-region compatible load testing setup using Locust. By default it will use a Locustfile under `files/Locustfile.py`, but you can either edit this file or change the `locustfile` variable to point to a new file.

> To ensure that the deployment and load test will be successful, it may be worth running Locust locally against the Locustfile you want to save time in the case that there might be a syntax error.

The environment deployed contains the following resources:

- A Resource Group
- A storage account
    - A file share for storing Locust test results
- A VNet for the Locust Server with an NSG allowing traffic from the current public IP of the user deploying the template to ports 22 and 8089
- A Locust Server VM with an admin called "vmadmin" and a mount to the created file share and Locust set up as a SystemD Unit
- A VNet for the Locust Clients per location used for the load test peered to the Locust Server VNet with NSGs allowing only VNet-to-VNet traffic
- *n* Locust Client VMs with an admin called "vmadmin" in each location used for the load test

## Prerequisites

Prior to deployment you need the following:

- [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [terraform](https://www.terraform.io/) - 0.13

In Azure, you also need:

- A user account or service policy with Contributor level access to the target subscription

## Variables

|Variable Name|Description|Type|Default|
|-|-|-|-|
|tenant_id|The tenant id of this deployment|string|`null`|
|subscription_id|The subscription id of this deployment|string|`null`|
|client_id|The client id of this deployment|string|`null`|
|client_secret|The client secret of this deployment|string|`null`|
|location|The location of this deployment|string|`"Central US"`|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names|string|`"locust-lt"`|
|tags|Tags given to the resources created by this template|map(string)|`{}`|
|additional_locations|List of additional locations to deploy to|list(string)|`null`|
|locustfile|The location of a Locustfile used for load testing|string|`null`|
|vm_count|Number of client VMs to deploy per-region|number|`1`|

## Outputs

|Output Name|Description|
|-|-|
|resource_group_name|Resource group of the VMs|
|server_vm_ip|IP of the server VM|
|admin_username|Username of the VM Admin|
|admin_private_key|Private key data for the vm admin|
|server_vm_web_access|Information to log into the Locust Server|

## Deployment

1. Set variables for the deployment
    - Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for more information.
2. Log into Azure with `az login` and set your subscription with `az account set --subscription='REPLACE_WITH_SUBSCRIPTION_ID_OR_NAME'`
    - Terraform has a number of ways to authenticate. See [here](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) for more information.
3. Initialise Terraform with `terraform init`
    - By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html) for more information.
4. Set the workspace with `terraform workspace select REPLACE_WITH_WORKSPACE_NAME`
    - If the workspace does not exist, use `terraform workspace new REPLACE_WITH_WORKSPACE_NAME`
5. Generate a plan with `terraform plan -out tf.plan`
6. If the plan passes, apply it with `terraform apply tf.plan`

In the event the deployment needs to be destroyed, you can run `terraform destroy` in place of steps 5 and 6.

## Post-Deployment

To get access to the VM, you can use the `terraform output admin_private_key` command to retrieve the private key and using that SSH into the VM or use the created private key file in the folder `.terraform/.ssh/`
