#!/usr/bin/env bash
set -e

echo "⚠️ WARNING: You are about to destroy all Campfire AWS Cloud resources."
read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Running Terraform Destroy..."
    terraform destroy -auto-approve
    echo "✅ All AWS resources successfully terminated. Zero cloud charges active."
fi