#!/bin/bash

# Exit on any error
set -e

export AWS_DEFAULT_REGION="ap-south-1"

   
# Check if there's an existing EC2 instance
if [[ ! -z "${INSTANCE_ID}" ]]; then
    echo "Found existing EC2 instance: ${INSTANCE_ID}"
    
    # Check if instance exists before attempting to terminate
    if aws ec2 describe-instances --instance-ids ${INSTANCE_ID} >/dev/null 2>&1; then
        echo "Terminating existing EC2 instance..."
        aws ec2 terminate-instances --instance-ids ${INSTANCE_ID}
        
        # Wait for the instance to be terminated
        echo "Waiting for instance to be terminated..."
        aws ec2 wait instance-terminated --instance-ids ${INSTANCE_ID}
        echo "Previous instance terminated successfully"
    else
        echo "Previous instance ID not found, it may have been already terminated"
    fi
fi

read -r -d '' USER_DATA << 'EOF'
#!/bin/bash

apt-get update

# Install prerequisites
apt-get install -y ca-certificates curl gnupg git

# Create directory for keyrings
install -m 0755 -d /etc/apt/keyrings

# Download and install Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group to run docker without sudo
usermod -aG docker ubuntu

systemctl enable docker
systemctl start docker

mkdir -p /home/ubuntu/workspace

cd /home/ubuntu/workspace

git clone -b Continuous_Deployment_Usage https://github.com/morAroesti/entryTracker.git

chown -R ubuntu:ubuntu /home/ubuntu/workspace
EOF


# Launch EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ami-053b12d3152c0cc71 \
    --count 1 \
    --instance-type t3a.small \
    --region ap-south-1 \
    --associate-public-ip-address \
    --subnet-id ${AWS_SUBNET_ID}
    --key-name ${AWS_EC2_KEY_NAME} \
    --block-device-mappings '[
        {
            "DeviceName": "/dev/xvda",
            "Ebs": {
                "VolumeSize": 8,
                "VolumeType": "gp3",
                "DeleteOnTermination": true,
                "Iops": 3000
            }
        }]' \
    --security-group-ids ${AWS_SECURITY_GROUP_ID} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=GITHUB-ACTIONS-entry-tracker-${GITHUB_RUN_NUMBER}}]" \
    --user-data "$(echo "$USER_DATA" | base64)" \
    --output text \
    --query 'Instances[0].InstanceId')

# Export instance ID for GitHub Actions
echo "INSTANCE_ID=$INSTANCE_ID" >> $GITHUB_ENV

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "EC2 instance $INSTANCE_ID is now running"

# Get and export public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
echo "Instance Public IP: $PUBLIC_IP"
echo "PUBLIC_IP=$PUBLIC_IP" >> $GITHUB_ENV
