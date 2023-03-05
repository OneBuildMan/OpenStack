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
    printf "Script failed with exit code %s\nCould not get the loadbalancer list\n" $? >> $output_path
    exit 1
fi

#Get info from each loadbalancer
for lb_id in "${lb_ids[@]}"
do
    lb=$(openstack loadbalancer show $lb_id -f yaml)
    lb_name=$(grep "name" <<< "$lb")
    lb_state=$(grep "operating_status" <<< "$lb")
    lb_provision_state=$(grep "provisioning_status" <<< "$lb")
    lb_ip=$(grep "vip_address" <<< "$lb")
    lb_members_pools=$(grep "pools" <<< "$lb")
    lb_project=$(grep "project_id" <<< "$lb")

    #Get amphora details
    amphora_id=$(openstack loadbalancer amphora list | grep $lb_id | awk '{print $2}')
    if [ -z "$amphora_id" ]
    then
        printf "Warning: Could not find an amphora associated with this LB\n" >> $output_path
    else
        amphora=$(openstack loadbalancer amphora show $amphora_id -f yaml)
        compute_id=$(grep "compute_id" <<< "$amphora")
        image_id=$(grep "image_id" <<< "$amphora" | awk '{print $2}')
        image=$(openstack image show $image_id)
        image_name=$(grep "product" <<< "$image")
        image_version=$(grep "version" <<< "$image")
    fi
    {
        printf "id: %s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$lb_id" "$lb_name" "$lb_state" "$lb_provision_state" "$lb_ip" "$lb_members_pools" "$lb_project"
        printf "Amphora\n%s\nimage:%s\n%s\n%s" "$compute_id" "$image_id" "$image_version" "$image_name"
    } >> $output_path
done

printf "LB inventory created, it can be found at: %s\n" "$output_path"
