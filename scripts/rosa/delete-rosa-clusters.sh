#!/bin/bash

# Description: This script retrieves cluster information in JSON format and checks for the existence 
# of the "konflux-ci" tag. It then evaluates the creation date of clusters 
# to determine if they are older than 4 hours and, if so, deletes the cluster.

export TIME_THRESHOLD_SECONDS MAX_RETRIES CLUSTER_LIST ROSA_TOKEN
TIME_THRESHOLD_SECONDS=${TIME_THRESHOLD_SECONDS:-14400}
MAX_RETRIES=5

if [[ -z "$ROSA_TOKEN" ]]; then
    echo "[INFO] ROSA_TOKEN env is not defined. Exiting."
    exit 1
else
    rosa login --token="${ROSA_TOKEN}"
fi

if ! command -v rosa &> /dev/null; then
    echo "Error: rosa command not found. Please install the rosa CLI tool."
    exit 1
fi

CLUSTER_LIST=$(rosa list clusters --all -o json)

if [[ -n "$CLUSTER_LIST" ]]; then
    echo "$CLUSTER_LIST" | jq -c '.[] | select(.aws.tags."konflux-ci" != null)' | while IFS= read -r cluster; do

        id=$(echo "$cluster" | jq -r '.id')
        creation_date=$(echo "$cluster" | jq -r '.creation_timestamp')

        creation_seconds=$(date -d "$creation_date" +"%s")
        current_seconds=$(date -u +"%s")

        diff_seconds=$((current_seconds - creation_seconds))

        if [[ "$diff_seconds" -ge "${TIME_THRESHOLD_SECONDS}" ]]; then
            echo -e "[INFO] Cluster with id: ${id} is older than 4 hours. Attempting to delete..."

            for ((i=1; i<=MAX_RETRIES; i++)); do
                if rosa delete cluster --cluster="$id" -y; then
                    echo "[SUCCESS] Cluster with id: ${id} deleted successfully."
                    break
                else
                    echo "[WARNING] Attempt $i failed to delete cluster with id: ${id}."
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "[ERROR] Failed to delete cluster with id: ${id} after $MAX_RETRIES attempts."
                    fi
                    sleep 2
                fi
            done
        fi
    done
fi
