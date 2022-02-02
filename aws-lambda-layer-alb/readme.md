# Lambda with NodeJS Layer and ALB

This example demonstrate the Lambda with NodeJS Layer and Application Load Balancer.

### Create Bundle

##### 1. Create function zip

For windows with power shell

```sh
Compress-Archive -Path .\function\ -DestinationPath .\function.zip -Force
```

##### 2. Create layer zip

For windows with power shell

```sh
Compress-Archive -Path .\nodejs\ -DestinationPath .\nodejs.zip -Force
```

### Running Terraform

```sh
terraform init
terraform apply
```
