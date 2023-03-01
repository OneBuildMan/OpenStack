#!/bin/bash

#Set the output file
output_file="loadbalancer_inventory_$(date +'%d_%m_%H')"
output_path="$(pwd)/$output_file"

#Get the loadbalancers
lb_ids=($(openstack loadbalancer list -c id -f value))

#Get info from each loadbalancer
for lb_id in "${lb_ids[@]}"
do
    lb=$(openstack loadbalancer show $lb_id)
    lb_name=$(echo "$lb" | grep "name" | awk '{print $4}')
    lb_state=$(echo "$lb" | grep "operating_status" | awk '{print $4}')
    lb_provision_state=$(echo "$lb" | grep "provisioning_status" | awk '{print $4}')
    lb_ip=$(echo "$lb" | grep "vip_address" | awk '{print $4}')
    lb_members_pools=$(echo "$lb" | grep "pools" | awk '{print $4}')
    lb_project=$(echo "$lb" | grep "project_id" | awk '{print $4}')

    #Get amphora details
    amphora_id=$(openstack loadbalancer amphora list | grep $lb_id | awk '{print $2}')
    amphora=$(openstack loadbalancer amphora show $amphora_id)
    compute_id=$(echo "$amphora" | grep "compute_id" | awk '{print $4}')
    image_id=$(echo "$amphora" | grep "image_id" | awk '{print $4}')
    image=$(openstack image show $image_id)
    image_version=$(echo "image" | grep "version")

    #Write the load balancer details to the output file
    echo "Load Balancer Name: $lb_name" >> $output_path
    echo "Load Balancer ID: $lb_id" >> $output_path
    echo "Load Balancer State: $lb_state" >> $output_path
    echo "Load Balancer Provision State: $lb_provision_state" >> $output_path
    echo "Load Balancer IP: $lb_ip" >> $output_path
    echo "Load Balancer Members/Pools: $lb_members_pools" >> $output_path
    echo "Amphora Image Used: $amphora_image" >> $output_path
    echo "Amphora Image Version: $amphora_image_version" >> $output_path
    echo "Node Running the Load Balancer: $compute_id" >> $output_path
    echo "Project Name: $lb_project" >> $output_path
    echo "" >> $output_path
done

echo "LB inventory created, it can be found at: $output_path"
