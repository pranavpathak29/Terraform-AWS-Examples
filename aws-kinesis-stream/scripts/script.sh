#Sample commands for Kinesis Stream
#To Put Records
aws kinesis put-record --stream-name ${stream-name} --data ${data} --partition-key ${key} --cli-binary-format raw-in-base64-out
aws kinesis put-record --stream-name aws-stream --data "This is Pranav" --partition-key "user1" --cli-binary-format raw-in-base64-out

#To Get Shards
aws kinesis describe-stream --stream-name ${stream-name}
aws kinesis describe-stream --stream-name aws-stream

#To Get Iterator
aws kinesis get-shard-iterator --stream-name ${stream-name} -shard-id ${shard-id} --shard-iterator-type "TRIM_HORIZON"
aws kinesis get-shard-iterator --stream-name aws-stream --shard-id shardId-000000000000 --shard-iterator-type TRIM_HORIZON

#To Get Recrods
aws kinesis get-records --shard-iterator ${iterator}
aws kinesis get-records --shard-iterator "AAAAAAAAAAEgGedoxrWF6tkBI/Jl6im+b2UV8N8/I6qPQVNpJiu4kW0POx4evCzky8WpOmsIQFoMNef1MtvCcshF3QK6orq3nrm57stJLmFjEZS21v1OtWFRfJkPmDNkO4LXkek2EaP0YGhh4kgmDuGuXYNLbm18ueQTidP0bS8dMcpEdg72NpFwoSaDbaNdVaCrCXLu+it6xrsnYkJ1ii7eQOq1KkaGQ9oYL7U/e8c3hq/5sKD2iA=="