#!/bin/bash

# will run in the "Web_Server" 

# SSH into the "Application_Server" 
ssh -i appserver.pem ubuntu@10.0.92.22 << EOF

echo "Downloading start_app.sh from GH..."
curl -O https://raw.githubusercontent.com/acurwen/microblog_VPC_deployment/refs/heads/main/scripts/start_app.sh

echo "Running the start_app.sh..."
source start_app.sh
EOF
