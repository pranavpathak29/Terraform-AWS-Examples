# Eventbridge with Lambda (Every 5 minutes)

This example demonstrate the eventbridge to trigger lambda on every 5 minutes.

### Create Bundle

For windows with power shell

```sh
Compress-Archive -Path .\function\ -DestinationPath .\function.zip -Force
```

### Running Terraform

```sh
terraform init
terraform apply
```
