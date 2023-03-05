#!/bin/bash

# Checking jq is present
if ! which jq &>/dev/null; then
    echo "jq is not present, the script will not run correctly without it. Exiting program..."
    exit 1
fi

# Set the output file
output_file="loadbalancer_inventory_$(date +'%d_%m_%H')"
output_path="$(pwd)/$output_file"

# Delete the file in case the script was run before
rm "$output_path" &>/dev/null

# Get the load balancers
lb_ids=($(openstack loadbalancer list -c id -f value))
if [ $? -ne 0 ]; then
    echo -e "Script failed with exit code $?\nCould not get the load balancer list"
    exit 1
fi

# Get info from each load balancer
for lb_id in "${lb_ids[@]}"
do
    lb=$(openstack loadbalancer show "$lb_id" -f json)
    lb_name=$(jq -r '.name' <<< "$lb")
    lb_state=$(jq -r '.operating_status' <<< "$lb")
    lb_provision_state=$(jq -r '.provisioning_status' <<< "$lb")
    lb_ip=$(jq -r '.vip_address' <<< "$lb")
    lb_members_pools=$(jq -r '.pools' <<< "$lb")
    lb_project=$(jq -r '.project_id' <<< "$lb")

    # Get amphora details
    amphora_id=$(openstack loadbalancer amphora list | grep "$lb_id" | awk '{print $2}')
    if [ -z "$amphora_id" ]
    then
        echo "Warning: Could not find an amphora associated with this LB"
    else
        amphora=$(openstack loadbalancer amphora show "$amphora_id" -f json)
        compute_id=$(jq -r '.compute_id' <<< "$amphora")
        image_id=$(jq -r '.image_id' <<< "$amphora")
        image=$(openstack image show "$image_id" -f json)
        image_name=$(jq -r '.name' <<< "$image")
        image_version=$(jq -r '.metadata.version' <<< "$image")
    fi

    # Write to output file
    touch "$output_path"
    {
        printf "id: %s\nname: %s\noperating_status: %s\nprovisioning_status: %s\nvip_address: %s\npools: %s\nproject_id: %s\n\n" \
            "$lb_id" "$lb_name" "$lb_state" "$lb_provision_state" "$lb_ip" "$lb_members_pools" "$lb_project"
        printf "Amphora\ncompute_id: %s\nimage_id: %s\nversion: %s\nname: %s\n\n" \
            "$compute_id" "$image_id" "$image_version" "$image_name"
    } >> "$output_path"
done

echo "Load balancer inventory created, it can be found at: $output_path"
