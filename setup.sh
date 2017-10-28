#!/bin/bash

profile=$1
key_name=$2

if [[ $profile == '' ]]; then
  echo "You must supply both an AWS CLI profile name and an SSH key name."
  return 1
fi

if [[ $key_name == '' ]]; then
  echo "You must supply both an AWS CLI profile name and an SSH key name."
  return 1
fi

current_relative_path="$(dirname $BASH_SOURCE)"

account_id=$(aws --profile $profile sts get-caller-identity --output text --query 'Account')
exit_code=$?
if [ $exit_code -ne 0 ]; then
  return $exit_code
fi
region=$(aws --profile $profile configure list | grep region | awk '{print $2}')
exit_code=$?
if [ $exit_code -ne 0 ]; then
  return $exit_code
fi

# Set terraform variables.
export TF_VAR_aws_region=$region
export TF_VAR_key_name=$key_name

terraform_bucket="${account_id}-${region}-aws-study-terraform"

if [ $(aws s3 ls s3://${terraform_bucket}/ &> /dev/null; echo $?) -eq 255 ]; then
  aws --region $region s3 mb s3://${terraform_bucket}
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    return $exit_code
  fi
fi

cat << EOF > ${current_relative_path}/terraform/.backend_config
# This file is dynamically created by the setup script in the project root. Don't edit it manually.
bucket = "${terraform_bucket}"
region = "${region}"
EOF
