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
* [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [terraform](https://www.terraform.io/) - 0.12

In Azure, you also need:
* A user account or service policy with Contributor level access to the target subscription

## Variables

These are the variables used along with their defaults. For any without a value in default, the value must be filled in unless otherwise sateted otherwise the deployment will encounter failures.

**Global Variables**

|Variable|Description|Default Value|
|-|-|-|
|tenant_id|The tenant id of this deployment|`null`|
|subscription_id|The subscription id of this deployment|`null`|
|client_id|The client id used to authenticate to Azure|`null`|
|client_secret|The client secret used to authenticate to Azure|`null`|
|location|The location of this deployment|`"UK South"`|
|resource_group_name|The name of an existing resource group - this will override the creation of a new resource group|`""`|
|resource_prefix|A prefix for the name of the resource, used to generate the resource names|`"locust"`|
|tags|Tags given to the resources created by this template|`{}`|

**Resource-Specific Variables**

|Variable|Description|Default Value|
|-|-|-|
|vm_size|VM Size for the VMs|`"Standard_B1s"`|
|vm_count|Number of client VMs to deploy per-region|`1`|
|additional_locations|List of additional locations to deploy to|`null`|
|locustfile|The location of a Locustfile used for load testing|`"files/Locustfile.py"`|

## Outputs

This template will output the following information:

|Output|Description|
|-|-|
|server_vm_info|Information for the Locust Server|
|server_vm_web_access|Information to log into the Locust Server|

## Deployment

Below describes the steps to deploy this template.

1. Set variables for the deployment
    * Terraform has a number of ways to set variables. See [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for more information.
2. Log into Azure with `az login` and set your subscription with `az account set --subscription='<REPLACE_WITH_SUBSCRIPTION_ID_OR_NAME>'`
    * Terraform has a number of ways to authenticate. See [here](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) for more information.
3. Initialise Terraform with `terraform init`
    * By default, state is stored locally. State can be stored in different backends. See [here](https://www.terraform.io/docs/backends/types/index.html) for more information.
4. Set the workspace with `terraform workspace select <REPLACE_WITH_ENVIRONMENT>`
    * If the workspace does not exist, use `terraform workspace new <REPLACE_WITH_ENVIRONMENT>`
5. Generate a plan with `terraform plan -out tf.plan`
6. If the plan passes, apply it with `terraform apply tf.plan`

In the event the deployment needs to be destroyed, you can run `terraform destroy` in place of steps 5 and 6.

## Post-Deployment

To get access to the VM, you can use the `terraform output admin_private_key` command to retrieve the private key and using that SSH into the VM.
