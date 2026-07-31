# deploy via ssm error
aws ssm get-command-invocation \
  --command-id 25624008-743d-4398-bbb9-dbca8e2fccd8 \
  --instance-id i-08a3068352dc88536 \
  --query "{Status:Status, StepStatuses:StatusDetails, StdOut:StandardOutputContent, StdErr:StandardErrorContent}" \
  --output json