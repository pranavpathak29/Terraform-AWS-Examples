#Sample commands for Kinesis Stream
#To Put Records
aws kinesis put-record --stream-name ${stream-name} --data ${data} --partition-key ${key} --cli-binary-format raw-in-base64-out
aws kinesis put-record --stream-name aws-stream --data "This is Pranav" --partition-key "user1" --cli-binary-format raw-in-base64-out