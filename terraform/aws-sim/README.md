# aws-sim (Terraform draft)

Draft for the AWS phase: one VPC, one S3 bucket and an output.
Tested against the Vyomi local AWS simulator (no real AWS account).

- terraform validate: passes.
- On the simulator, apply created the VPC but failed on read-back (DescribeVpcAttribute not implemented)
  and on a second S3 bucket (the simulator holds one bucket at a time).

Run against the simulator:

    terraform init
    terraform apply -var "endpoint=http://localhost:<port>"

For real AWS: remove the endpoints block and the skip_* lines, set real credentials, then plan and apply.
