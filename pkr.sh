#!/usr/bin/env bash
set -e
set -u
set -o pipefail

# load IaaS env vars required by BBL
eval $(~/GDrive/Work/IaaS/AWS/bootstrap-env.sh)

function pkr_validate {
  pushd packer
  packer validate \
    -var 'playbook_dir=/home/siobrien/Workspace/Work/pcf-ops-playbook' \
    jumpbox-image.json
  popd
}

function pkr_destroy {
  pushd packer

  AMI_ID=$(cat manifest.json | jq --raw-output '.builds[0].artifact_id | split(":") | .[1]')
  SNAPSHOT_ID=$(aws ec2 describe-images --image-id ${AMI_ID} --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' --output text)

  echo "De-registering AMI: ${AMI_ID}"
  aws ec2 deregister-image --image-id ${AMI_ID}
  
  echo "Deleting EBS Snapshot: ${SNAPSHOT_ID}"
  aws ec2 delete-snapshot --snapshot-id ${SNAPSHOT_ID}

  rm -f manifest.json

  popd
}

function pkr_build {
  pushd packer
  packer build \
    -var 'playbook_dir=/home/siobrien/Workspace/Work/pcf-ops-playbook' \
    jumpbox-image.json
  popd
}

while getopts 'vbd' OPTION; do
  case "$OPTION" in
    v)
      pkr_validate
      ;;
    b)
      pkr_build
      ;;
    d)
      pkr_destroy
      ;;
  esac
done
shift "$(($OPTIND -1))"

