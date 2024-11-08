#!/bin/bash

# Description: This script retrieves cluster information in JSON format and checks for the existence
# of the "konflux-ci" tag. It then evaluates the creation date of clusters
# to determine if they are older than 4 hours and, if so, deletes the cluster including related subnet tags and load balancers.

TIME_THRESHOLD_SECONDS=${TIME_THRESHOLD_SECONDS:-14400}
MAX_RETRIES=5
LB_TAG_KEY="api.openshift.com/id"

check_env_vars() {
    if [[ -z "$ROSA_TOKEN" ]]; then
        echo "[ERROR] ROSA_TOKEN env is not exported. Exiting."
        exit 1
    fi

    if [[ -z "$AWS_DEFAULT_REGION" || -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SUBNET_IDS" ]]; then
        echo "[ERROR] Required AWS env vars are not exported. Be sure to export \$AWS_DEFAULT_REGION, \$AWS_ACCESS_KEY_ID, \$AWS_SECRET_ACCESS_KEY, \$AWS_SUBNET_IDS"
        exit 1
    fi
}

check_required_tools() {
    if ! command -v rosa &> /dev/null; then
        echo "Error: rosa command not found. Please install the rosa CLI tool."
        exit 1
    fi
    if ! command -v aws &> /dev/null; then
        echo "Error: aws command not found. Please install the aws CLI tool."
        exit 1
    fi
}

delete_cluster() {
    local cluster_id=$1

    for ((i=1; i<=MAX_RETRIES; i++)); do
        if rosa delete cluster --cluster="$cluster_id" -y; then
            echo "[SUCCESS] Cluster with id: ${cluster_id} deleted successfully."
            return 0
        else
            echo "[WARNING] Attempt $i failed to delete cluster with id: ${cluster_id}."
            if [[ $i -eq $MAX_RETRIES ]]; then
                echo "[ERROR] Failed to delete cluster with id: ${cluster_id} after $MAX_RETRIES attempts."
                return 1
            fi
            sleep 2
        fi
    done
}

delete_subnet_tags() {
    local cluster_id=$1
    local subnet_ids="${AWS_SUBNET_IDS//,/ }"

    echo "[INFO] Removing tag from subnets [$AWS_SUBNET_IDS]..."
    aws --region "$AWS_DEFAULT_REGION" ec2 delete-tags --resources $subnet_ids --tags Key="kubernetes.io/cluster/${cluster_id}"
}

delete_load_balancers() {
    local lb_tag_value=$1
    local load_balancers
    local lb_arn

    load_balancers=$(aws --region "$AWS_DEFAULT_REGION" elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerArn" --output text)

    for lb_arn in $load_balancers; do
        local tags
        tags=$(aws --region "$AWS_DEFAULT_REGION" elbv2 describe-tags --resource-arns "$lb_arn" --query "TagDescriptions[*].Tags[?Key=='$LB_TAG_KEY'&&Value=='$lb_tag_value'].Value" --output text)
        
        if [[ "$tags" == "$lb_tag_value" ]]; then

            echo "[INFO] Deleting ELBv2 Load Balancer with ARN: $lb_arn"
            aws --region "$AWS_DEFAULT_REGION" elbv2 delete-load-balancer --load-balancer-arn "$lb_arn"

            echo "[INFO] Deleting Target Groups associated with Load Balancer ARN: $lb_arn"
            delete_target_groups_for_lb "$lb_arn"
        fi
    done
}

delete_target_groups_for_lb() {
    local lb_arn=$1
    local tg_arns

    # Get target groups associated with the specified load balancer
    tg_arns=$(aws elbv2 describe-target-groups --region "$AWS_DEFAULT_REGION" \
        --query "TargetGroups[?LoadBalancerArns[0] == '$lb_arn'].TargetGroupArn" --output text)

    for tg_arn in $tg_arns; do
        echo "[INFO] Deleting Target Group with ARN: $tg_arn (associated with Load Balancer ARN: $lb_arn)"
        aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region "$AWS_DEFAULT_REGION"
    done
}

delete_old_clusters() {
    local cluster_list=$1

    echo "$cluster_list" | jq -c '.[] | select(.aws.tags."konflux-ci" != null)' | while IFS= read -r cluster; do
        local cluster_id
        local creation_date
        local creation_seconds
        local current_seconds

        cluster_id=$(echo "$cluster" | jq -r '.id')
        creation_date=$(echo "$cluster" | jq -r '.creation_timestamp')
        creation_seconds=$(date -d "$creation_date" +"%s")
        current_seconds=$(date -u +"%s")
        local diff_seconds=$((current_seconds - creation_seconds))

        if [[ "$diff_seconds" -ge "${TIME_THRESHOLD_SECONDS}" ]]; then
            echo "[INFO] Cluster with id: ${cluster_id} is older than 4 hours. Attempting to delete..."

            if delete_cluster "$cluster_id"; then
                delete_subnet_tags "$cluster_id"
                delete_load_balancers "$cluster_id"
            else
                echo "[ERROR] Cluster deletion failed for cluster id: ${cluster_id}. Skipping further steps."
            fi
        fi
    done
}

main() {
    check_env_vars
    check_required_tools

    rosa login --token="${ROSA_TOKEN}"

    local cluster_list
    cluster_list=$(rosa list clusters --all -o json)
    if [[ -n "$cluster_list" ]]; then
        delete_old_clusters "$cluster_list"
    else
        echo "[INFO] No clusters for cleanup found."
    fi
}

main