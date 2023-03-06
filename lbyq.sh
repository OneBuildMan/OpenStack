#!/bin/bash

# Checking yq is present
if ! which yq &>/dev/null; then
    echo "yq is not present, the script will not run correctly without it. Exiting script..."
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
    lb=$(openstack loadbalancer show "$lb_id" -f yaml | yq -r '.name, .operating_status, .provisioning_status, .vip_address, .pools, .project_id')

    # Get amphora details
    amphora_id=$(openstack loadbalancer amphora list --loadbalancer $lb_id | awk 'NR>3 && $2 != "" {print $2}') #takes the first id it finds
    if [ -z "$amphora_id" ]
    then
        echo "Warning: Could not find an amphora associated with this LB"
    else
        amphora=$(openstack loadbalancer amphora show "$amphora_id" -f yaml | yq -r '.compute_id, .image_id')
        image=$(openstack image show "${amphora[1]}" -f yaml | yq -r '.properties.source_product_name, .properties.source_version_name')
    fi

    # Write to output file
    touch "$output_path"
    {
        printf "LB\nid: %s\nname: %s\noperating_status: %s\nprovisioning_status: %s\nvip_address: %s\npools: %s\nproject_id: %s\n\n" \
            $lb_id ${lb[0]} ${lb[1]} ${lb[2]} ${lb[3]} ${lb[4]} ${lb[5]}
        printf "Amphora\ncompute_id: %s\nimage_id: %s\nimage version: %s\nimage name: %s\n\n" \
            ${amphora[0]} ${amphora[1]} ${image[1]} ${image[0]}
    } >> "$output_path"
done

echo "Load balancer inventory created, it can be found at: $output_path"
