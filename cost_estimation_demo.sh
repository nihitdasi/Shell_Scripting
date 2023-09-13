#!/bin/bash

# Set your desired AWS region
AWS_REGION="us-east-1"  # Change this to your desired region

# Function to calculate cost per month
calculate_cost() {
  local cost_per_hour="$1"
  local hours_per_month=730 # Assuming 30 days with 24 hours each
  local cost_per_month=$(bc -l <<< "$cost_per_hour * $hours_per_month")
  echo "$cost_per_month"
}

# Retrieve EC2 instances information
ec2_instances=$(aws ec2 describe-instances --region "$AWS_REGION" --query "Reservations[*].Instances[*]" --output json)

# Retrieve EBS volumes information
ebs_volumes=$(aws ec2 describe-volumes --region "$AWS_REGION" --query "Volumes[*]" --output json)

# Initialize arrays to store instance and volume data
declare -a instances
declare -a volumes

# Process EC2 instances data
for instance in $(echo "$ec2_instances" | jq -c '.[][]'); do
  instance_name=$(echo "$instance" | jq -r '.Tags[] | select(.Key=="Name") | .Value')
  public_ip=$(echo "$instance" | jq -r '.PublicIpAddress // empty')
  private_ip=$(echo "$instance" | jq -r '.PrivateIpAddress')
  size=$(echo "$instance" | jq -r '.InstanceType')
  cpus=$(echo "$instance" | jq -r '.CpuOptions.Cores')
  ram=$(echo "$instance" | jq -r '.Memory')
  volume_size=$(echo "$instance" | jq -r '.BlockDeviceMappings[] | .Ebs.VolumeSize')
  
  # Calculate cost per hour based on instance type
  cost_per_hour=0  # Set this to the actual cost per hour for each instance type
  
  cost_per_month=$(calculate_cost "$cost_per_hour")

  instances+=("$instance_name,$public_ip,$private_ip,$size,$cpus,$ram,$volume_size,$cost_per_hour,$cost_per_month")
done

# Process EBS volumes data
for volume in $(echo "$ebs_volumes" | jq -c '.[]'); do
  volume_name=$(echo "$volume" | jq -r '.Tags[] | select(.Key=="Name") | .Value')
  volume_size=$(echo "$volume" | jq -r '.Size')
  volume_cost=0  # Set this to the actual cost per month for each volume size
  
  volumes+=("$volume_name,$volume_size,$volume_cost")
done

# Export instance and volume data to CSV files
echo "Instance Name,Public IP,Private IP,Size,CPUs,RAM,Volume Size (GB),Instance Cost per Hour (USD),Cost per Month (USD)" > instances.csv
for instance in "${instances[@]}"; do
  echo "$instance" >> instances.csv
done

echo "Volume Name,Volume Size (GB),Volume Cost per Month (USD)" > volumes.csv
for volume in "${volumes[@]}"; do
  echo "$volume" >> volumes.csv
done

# Create a Python script to convert CSV to XLSX
python_script=$(cat <<EOF
import csv
from openpyxl import Workbook

# Convert instances.csv to instances.xlsx
wb = Workbook()
ws = wb.active
with open('instances.csv', 'r') as f:
    for row in csv.reader(f):
        ws.append(row)
wb.save('instances.xlsx')

# Convert volumes.csv to volumes.xlsx
wb = Workbook()
ws = wb.active
with open('volumes.csv', 'r') as f:
    for row in csv.reader(f):
        ws.append(row)
wb.save('volumes.xlsx')
EOF
)

# Run the Python script to generate XLSX files
echo "$python_script" > convert_to_xlsx.py
python convert_to_xlsx.py

# Clean up temporary CSV and Python files
rm instances.csv volumes.csv convert_to_xlsx.py

echo "Cost Estimation data saved to instances.xlsx and volumes.xlsx"
