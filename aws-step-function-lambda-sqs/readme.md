# Step function with Lambda, SNS, SQS

This example demonstrate the Step function with Lambda, SNS and SQS. Where lambda is used to create and activate user account and SNS is used to send email on creation and send failure notification to SQS for further evaluation.

> Note: Database is not integrated so no DB operation will perform.

### Create Bundle

##### Create Account Function
For windows with power shell
```sh
Compress-Archive -Path .\function\create-account -DestinationPath .\function\create-account.zip -Force
```
##### Activate Account Function
For windows with power shell
```sh
Compress-Archive -Path .\function\activate-account -DestinationPath .\function\activate-account.zip -Force
```

### Running Terraform

```sh
terraform init
terraform apply
terraform destroy
```