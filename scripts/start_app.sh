#!/bin/bash
# will run in the "Application_Server" 

# Setting up the server with all of the dependencies that the application needs
echo "Initial setup starting..."
sudo apt-get update -y
sudo apt install fontconfig openjdk-17-jre software-properties-common -y && sudo add-apt-repository ppa:deadsnakes/ppa -y && sudo apt install python3.9 python3.9-venv -y
sudo apt install python3-pip -y


# clone the GH repository
sudo apt-get install git -y
echo "Cloning repo..."

# If GH repo doesn't already exist, git clone it 
if [[ ! -d /home/ubuntu/microblog_VPC_deployment ]]
then
    echo "Repository cloned."
    git clone https://github.com/acurwen/microblog_VPC_deployment.git
    cd /home/ubuntu/microblog_VPC_deployment
else
    echo "Repository already exists. Newest changes pulled."
    cd /home/ubuntu/microblog_VPC_deployment
    git pull origin main #pulling the remote repo origin into the directory to get the "latest" version of it
fi

# creating and activating virtual environment 
echo "Creating and activating venv..."
python3.9 -m venv venv
source venv/bin/activate

# install the application dependencies from the requirements.txt file as well as [gunicorn, pymysql, cryptography] 
pip install pip --upgrade #upgrading the virtual env's pip
pip install -r requirements.txt
pip install gunicorn pymysql cryptography

# set ENVIRONMENTAL Variables, flask commands
export FLASK_APP=microblog.py
flask translate compile
flask db upgrade

# and finally the gunicorn command that will serve the application IN THE BACKGROUND
gunicorn -b :5000 -w 4 microblog:app --daemon

echo "Microblog up and running."
