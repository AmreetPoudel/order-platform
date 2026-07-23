output "state_bucket_name" {
  value = aws_s3_bucket.order_platform_tf_state.id
}

output "lock_table_name" {
  value = aws_dynamodb_table.order_platform_tf_lock.name
}