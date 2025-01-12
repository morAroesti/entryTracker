#!/bin/bash


INSTANCE_TYPE="t3a.small"
AMI_ID="ami-053b12d3152c0cc71"  
KEY_NAME="morrost_ec2_keypair"
SECURITY_GROUP="sg-00257ff378acccd78"
SUBNET_ID="subnet-02fe3384564948adb"
INSTANCE_NAME="GithubActionInstance"
USER_DATA_FILE=""
REGION="ap-south-1"
VOLUME_SIZE="8"
VOLUME_TYPE="gp3"

# Help function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Launch an EC2 instance with specified parameters"
    echo
    echo "Options:"
    echo "  -t, --instance-type    EC2 instance type (default: t2.micro)"
    echo "  -a, --ami-id           AMI ID to use"
    echo "  -k, --key-name         SSH key pair name"
    echo "  -s, --security-group   Security group ID"
    echo "  -n, --subnet-id        Subnet ID"
    echo "  -N, --name             Instance name tag"
    echo "  -u, --user-data        Path to user data script"
    echo "  -r, --region           AWS region (default: us-east-1)"
    echo "  -v, --volume-size      Root volume size in GB (default: 8)"
    echo "  -T, --volume-type      Root volume type (default: gp3)"
    echo "  -h, --help             Display this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        -a|--ami-id)
            AMI_ID="$2"
            shift 2
            ;;
        -k|--key-name)
            KEY_NAME="$2"
            shift 2
            ;;
        -s|--security-group)
            SECURITY_GROUP="$2"
            shift 2
            ;;
        -n|--subnet-id)
            SUBNET_ID="$2"
            shift 2
            ;;
        -N|--name)
            INSTANCE_NAME="$2"
            shift 2
            ;;
        -u|--user-data)
            USER_DATA_FILE="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -v|--volume-size)
            VOLUME_SIZE="$2"
            shift 2
            ;;
        -T|--volume-type)
            VOLUME_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$KEY_NAME" ]; then
    echo "Error: Key pair name is required"
    usage
fi

if [ -z "$SECURITY_GROUP" ]; then
    echo "Error: Security group ID is required"
    usage
fi

if [ -z "$SUBNET_ID" ]; then
    echo "Error: Subnet ID is required"
    usage
fi

# Prepare user data argument if file is provided
USER_DATA_ARG=""
if [ -n "$USER_DATA_FILE" ]; then
    if [ -f "$USER_DATA_FILE" ]; then
        USER_DATA_ARG="--user-data file://$USER_DATA_FILE"
    else
        echo "Error: User data file not found: $USER_DATA_FILE"
        exit 1
    fi
fi

# Set AWS region
export AWS_DEFAULT_REGION="$REGION"

# Check for existing instance with the same name
echo "Checking for existing instances with name: $INSTANCE_NAME"
EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[*].Instances[*].[InstanceId]' \
    --output text)

if [ ! -z "$EXISTING_INSTANCE" ]; then
    echo "Found existing instance with ID: $EXISTING_INSTANCE"
    echo "Terminating existing instance..."
    
    aws ec2 terminate-instances --instance-ids "$EXISTING_INSTANCE"
    
    echo "Existing instance terminated successfully"
fi

# Launch EC2 instance
echo "Launching EC2 instance in region $REGION..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"$VOLUME_TYPE\",\"DeleteOnTermination\":true}}]" \
    $USER_DATA_ARG \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --output text \
    --query 'Instances[0].InstanceId')

if [ $? -eq 0 ]; then
    echo "Successfully launched instance: $INSTANCE_ID"
	echo "Waiting for instance to be running..."
	aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
	

	
	# Get instance public IP
	PUBLIC_IP=$(aws ec2 describe-instances \
		--instance-ids "$INSTANCE_ID" \
		--query 'Reservations[0].Instances[0].PublicIpAddress' \
		--output text)
		
	echo "Instance Public IP: $PUBLIC_IP"
	echo "PUBLIC_IP=$PUBLIC_IP" >> $GITHUB_ENV	
	
	# Verify the status checks
	INSTANCE_STATUS=$(aws ec2 describe-instance-status \
		--instance-ids "$INSTANCE_ID" \
		--query 'InstanceStatuses[0].{SystemStatus:SystemStatus.Status,InstanceStatus:InstanceStatus.Status}' \
		--output text)
	
	echo "Instance fully provisioned!"
	echo "Instance ID: $INSTANCE_ID"
	echo "Public IP: $PUBLIC_IP"
	echo "Instance Status: $INSTANCE_STATUS"
	echo "Instance Name: $INSTANCE_NAME"
	echo "Waiting for instance status checks..."
	aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
else
    echo "Failed to launch instance"
    exit 1
fi
