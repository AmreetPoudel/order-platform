## run this script  manually because this is one time task
aws s3 cp docker-compose.yml \
  s3://order-platform-tf-state-891274465984/deploy/dev/artifacts/docker-compose.yml

aws s3 cp scripts/dev/rollback.sh \
  s3://order-platform-tf-state-891274465984/deploy/dev/artifacts/scripts/dev/rollback.sh

aws s3 cp scripts/dev/update-version.sh \
  s3://order-platform-tf-state-891274465984/deploy/dev/artifacts/scripts/dev/update-version.sh

aws s3 cp scripts/dev/fetch_secrets.sh \
  s3://order-platform-tf-state-891274465984/deploy/dev/artifacts/scripts/dev/fetch_secrets.sh

aws s3 cp scripts/dev/deploy.sh \
  s3://order-platform-tf-state-891274465984/deploy/dev/artifacts/scripts/dev/deploy.sh