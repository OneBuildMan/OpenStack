#!/bin/bash

#Set the output file
output_file="loadbalancer_inventory_$(date +'%d_%m_%H')"
output_path="$(pwd)/$output_file"

#Deleting the file in case the script was run before
touch $output_path
rm $output_path

#Get the loadbalancers
lb_ids=($(openstack loadbalancer list -c id -f value))
if [ $? -ne 0 ]; then
    echo -e "Script failed with exit code $?\nCould not get the loadbalancer list"
    rm output_path
    exit 1
fi

#Get info from each loadbalancer
for lb_id in "${lb_ids[@]}"
do
    lb=$(openstack loadbalancer show $lb_id -f yaml)
    lb_name=$(echo "$lb" | grep "name")
    lb_state=$(echo "$lb" | grep "operating_status")
    lb_provision_state=$(echo "$lb" | grep "provisioning_status")
    lb_ip=$(echo "$lb" | grep "vip_address")
    lb_members_pools=$(echo "$lb" | grep "pools")
    lb_project=$(echo "$lb" | grep "project_id")

    #Get amphora details
    amphora_id=$(openstack loadbalancer amphora list | grep $lb_id | awk '{print $2}')
    if [ -z "$amphora_id" ]
    then
        echo "Warning: Could not find an amphora associated with this LB"
    else
        amphora=$(openstack loadbalancer amphora show $amphora_id -f yaml)
        compute_id=$(echo "$amphora" | grep "compute_id")
        image_id=$(echo "$amphora" | grep "image_id" | awk '{print $2}')
        image=$(openstack image show $image_id)
        image_name=$(echo "image" | grep "product")
        image_version=$(echo "image" | grep "version")
    fi
    touch $output_path
    {
        echo -e "id: $lb_id\n$lb_name\n$lb_state\n$lb_provision_state\n$lb_ip\n$lb_members_pools\n$lb_project\n"
        echo -e "Amphora\n$compute_id\nimage:$image_id\n$image_version\n$image_name"
    }>>"$output_path"
done

echo "LB inventory created, it can be found at: $output_path"
