# Lambda Destination with SQS

This example demonstrate the lambda destination with SQS.

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

### Invoke Lambda 

##### Success 
Execute following using AWS-CLI
```sh
aws lambda invoke --function-name Lambda-Event-Source-Mapping-SQS  --invocation-type Event --cli-binary-format raw-in-base64-out --payload '{ "type": "success" }' response.json
```

##### Failure 
Execute following using AWS-CLI
```sh
aws lambda invoke --function-name Lambda-Event-Source-Mapping-SQS  --invocation-type Event --cli-binary-format raw-in-base64-out --payload '{ "type": "error" }' response.json
```