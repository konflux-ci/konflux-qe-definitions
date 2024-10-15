#!/bin/bash

# Description: This script retrieves cluster information in JSON format and checks for the existence
# of the "konflux-ci" tag. It then evaluates the creation date of clusters
# to determine if they are older than 4 hours and, if so, deletes the cluster including related subnet tags.

export TIME_THRESHOLD_SECONDS MAX_RETRIES CLUSTER_LIST ROSA_TOKEN AWS_DEFAULT_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SUBNET_IDS
TIME_THRESHOLD_SECONDS=${TIME_THRESHOLD_SECONDS:-14400}
MAX_RETRIES=5

if [[ -z "$ROSA_TOKEN" ]]; then
    echo "[ERROR] ROSA_TOKEN env is not exported. Exiting."
    exit 1
fi

if [[ -z "$AWS_DEFAULT_REGION" || -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SUBNET_IDS" ]]; then
    echo "[ERROR] Required AWS env vars are not exported. Be sure to export \$AWS_DEFAULT_REGION, \$AWS_ACCESS_KEY_ID, \$AWS_SECRET_ACCESS_KEY, \$AWS_SUBNET_IDS"
    exit 1
fi

if ! command -v rosa &> /dev/null; then
    echo "Error: rosa command not found. Please install the rosa CLI tool."
    exit 1
fi

rosa login --token="${ROSA_TOKEN}"

CLUSTER_LIST=$(rosa list clusters --all -o json)

if [[ -n "$CLUSTER_LIST" ]]; then
    echo "$CLUSTER_LIST" | jq -c '.[] | select(.aws.tags."konflux-ci" != null)' | while IFS= read -r cluster; do

        cluster_id=$(echo "$cluster" | jq -r '.id')
        creation_date=$(echo "$cluster" | jq -r '.creation_timestamp')

        creation_seconds=$(date -d "$creation_date" +"%s")
        current_seconds=$(date -u +"%s")

        diff_seconds=$((current_seconds - creation_seconds))

        if [[ "$diff_seconds" -ge "${TIME_THRESHOLD_SECONDS}" ]]; then
            echo -e "[INFO] Cluster with id: ${cluster_id} is older than 4 hours. Attempting to delete..."

            for ((i=1; i<=MAX_RETRIES; i++)); do
                if rosa delete cluster --cluster="$cluster_id" -y; then
                    echo "[SUCCESS] Cluster with id: ${cluster_id} deleted successfully."
                    break
                else
                    echo "[WARNING] Attempt $i failed to delete cluster with id: ${cluster_id}."
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "[ERROR] Failed to delete cluster with id: ${cluster_id} after $MAX_RETRIES attempts."
                    fi
                    sleep 2
                fi
            done

            for ((i=1; i<=MAX_RETRIES; i++)); do
                echo "INFO: Removing tag from subnets [$AWS_SUBNET_IDS]..."
                new_subnet_ids="${AWS_SUBNET_IDS//,/ }"
                if aws --region "$AWS_DEFAULT_REGION" ec2 delete-tags --resources $new_subnet_ids --tags Key="kubernetes.io/cluster/${cluster_id}"; then
                    echo "[SUCCESS] Subnet tag with cluster id: ${cluster_id} deleted successfully."
                    break
                else
                    echo "[WARNING] Attempt $i failed to delete subnet tag with cluster id: ${cluster_id}."
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "[ERROR] Failed to delete subnet tag with cluster id: ${cluster_id} after $MAX_RETRIES attempts."
                    fi
                    sleep 2
                fi
            done
        fi
    done
fi