# Workload 4: Microblog VPC Deployment

# Purpose:
In this workload, we deployed our microblog application with a more robust and secure infrastructure where we separated the deployment environment (in the default VPC) from the production environment (in the custom VPC). We also explore the use of SSH tunneling to deploy the microblog application.

# Steps:
## Cloned application code to personal repository:
Cloned the [Workload 4 repository](https://github.com/kura-labs-org/C5-Deployment-Workload-4/tree/main) to my GitHub account to have a personal copy of the application code. Named the cloned repository "microblog_VPC_deployment".

## Created custom VPC and internal resources:
- Created custom VPC called "Workload 4 VPC"
   - Availability zone: us-east-1a
   - IPv4 CIDR: 10.0.0.0/16
   - Enabled DNS hostnames and DNS resolution
   - Ensured no VPC endpoints because I won't need private network access to additional AWS services for this deployment.

**VPC:**
![image](https://github.com/user-attachments/assets/8fe813ef-e9e4-43ac-ab6a-438a4680ac0b)
https://github.com/acurwen/microblog_VPC_deployment/blob/main/Screenshots/370403963-8fe813ef-e9e4-43ac-ab6a-438a4680ac0b.png
![image](https://github.com/user-attachments/assets/7f138118-c17f-4bc7-bea5-bdfaab81f4ec)

**Network ACL:**
Left the custom VPC's NACL to its default settings: to allow all inbound traffic and allow all outbound traffic from all sources.

Created **Internet Gateway** called "W4 Internet Gateway" and attached it to the "Workload 4 VPC".
![image](https://github.com/user-attachments/assets/44dcc486-fe46-40e7-8c87-40357a731a7a)

Created **NAT Gateway** called "W4 NAT Gateway" in the public subnet and assigned an Elastic IP (static/non-changing IP).
![image](https://github.com/user-attachments/assets/e8d844ec-34cc-4d72-90b4-45fe89ca869c)

**Created Public and Private Route Tables:**
- Public Route Table:
    - named "public RT"
    - local connection
    - "W4 Internet Gateway" added

![image](https://github.com/user-attachments/assets/ce1bee0c-6b49-4396-9130-7c274e65d607)

- Private Route Table:
    - named "privateRT"
    - local connection
    - "W4 NAT Gateway" added

![image](https://github.com/user-attachments/assets/aa222788-5a39-40df-8d04-5b9aa1703d83)

**Created my Public and Private Subnets:**
- Public Subnet:
    - named "Public Subnet"
    - IPv4 CIDR: 10.0.64.0/18
    - Associated with "public RT" route table 
- Private Subnet:
    - named "Private Subnet"
    - IPv4 CIDR: 10.0.0.0/18
    - turned on auto-assign IPv4 addresses
    - Associated with "privateRT" route table 

Subnets:
![image](https://github.com/user-attachments/assets/d57706de-a0db-430f-bdf1-a457e0f9187b)

## Jenkins EC2 in Default VPC:
In my default VPC, I created a t3.medium EC2 called "Jenkins."
Availability zone is us-east-1a. Security group rules: Inbound (Ports 8080: Jenkins, 80: HTTP, 22: SSH & 443: HTTPS)

To install Jenkins, I wrote a script with all the Jenkins installation commands to automate the installation.
I added in some echo statements that introduced each line of code and sleep statements throughout, so I could see during the installation process where the script was.

![image](https://github.com/user-attachments/assets/6df2df7a-d39b-4f4e-ad03-7be078c1d71c)

Jenkins installation was successful:
![image](https://github.com/user-attachments/assets/03224745-aa55-4778-8931-7fd93d54a53c)


## EC2 Instances in Custom VPC:
Within my "Workload 4 VPC", I created two instances: one acting as the web tier and the other as the application tier. 

**"Web_Server" EC2**
  - In the "Public Subnet"
  - t3.micro
  - Security group: ports 22 (ssh) and 80 (HTTP) open.

**"Application_Server" EC2**
  - In the "Private Subnet"
  - t3.micro
  - Security group: ports 22 (ssh), 5000 (gunicorn) and set the sources for both to be the security group of the Web_Server EC2 for extra security. Also added Port 9100 later for Node Exporter. 
  - Created and saved the appserver.pem key pair to my local machine.

## Creating and Testing Authorized Keys
Ran the `ssh-keygen` command in the the "Jenkins" server. Copied the public key that was created and appended it to the "authorized_keys" file in the Web Server. 
(Later on, I re-did this step as the actual Jenkins user so that Jenkins could have ownership of the keypair used in the SSH command in the Deploy section of my Jenkinsfile.)

To test the connection, I ran `ssh -i id_ed25519 ubuntu@100.26.52.94` to SSH into the 'Web_Server' EC2 from the 'Jenkins' EC2. (The IP after 'ubuntu' is the public IP of the Web Server.) 

After successfullly SSH-ing into the 'Web_Server' EC2, I got confirmation that the 'Web_Server' EC2 was permanently added to the list of known hosts. 
![image](https://github.com/user-attachments/assets/b120e464-70bf-4ef1-acc1-0f789f1dbc01)

However, the public IP address was added and I wondered if that would create issues later since the public IP changes. I tried to SSH with the private key of my Web_Server EC2, but that didn't work. Later on, I used VPC peering to connect the default VPC (that holds Jenkins) and my custom VPC (that holds the Web_Server) so that I could run the same command above with the private IP of my Web_Server.

**What does it mean to be a known host?** A known host represents a server that has successfully SSH'd into the current server in the past. A SSH attempt in the future by a known host has to match the details the current server has of that known host (obtained from the first SSH attempt). This cross reference done by the current server ensures security and avoids access to any "bad actors" or instances that are not known and shouldn't have SSH access capabilities into the current server.

# Installing NginX:

In the Web_Server EC2, I installed NginX by running `sudo apt-get install nginx`.

Installation Successful:

![image](https://github.com/user-attachments/assets/4601d09a-40e2-457d-bfed-3412e874b379)

Then from the root directory, I ran `cd ./etc/nginx/sites-enabled` and sudo nano'd into the "default" file. There I modified the "location" section to read as below. The IP shown is the private IP address of the application server and port 5000 is where Gunicorn listens for incoming requests. 

![image](https://github.com/user-attachments/assets/9c4a6321-42b9-4978-931c-53b68e8352d3)

Running `sudo nginx -t` verfied that the config file had correct syntax and had a successful test. 

![image](https://github.com/user-attachments/assets/4f901bfe-5c7b-444c-9626-b6dbca6befc0)

Then to restart NginX, I ran `sudo systemctl restart nginx`.

## Copying key pair
In the "Web_Server" EC2, I nano'd a new file (called "appserver.pem") and copied the contents of my appserver.pem file into it (created when I made the Application_Server EC2). 

Ran `chmod 400 appserver.pem` to grant me, as the owner, read access.

To test the connection, I ran `ssh -i appserver.pem ubuntu@10.0.92.22` to SSH into the "Application_Server" from the "Web_Server" EC2. The IP aFter 'ubuntu' is the private IP of the Application_Server.

Successfullly SSH'd into the "Application_Server" EC2:

![image](https://github.com/user-attachments/assets/5eebfcd3-7e9c-4aff-bef8-5bb0ed2798e7)

# Scripts:

## "start_app.sh"
For my "start_app.sh" script, I started off with psuedo code for what should be included and then filled in the related commands, based on past workloads.

Example:
```
# creating and activating virtual environment 
echo "Creating and activating venv..."
python3.9 -m venv venv
source venv/bin/activate

# install the application dependencies from the requirements.txt file as well as [gunicorn, pymysql, cryptography] 
pip install pip --upgrade #upgrading the virtual env's pip
pip install -r requirements.txt
pip install gunicorn pymysql cryptography
```

I started with `sudo apt-get update` to get the latest info on what packages are available for install. Then to set up the server with all the dependencies that the application needs, I included the first line from Workload 1 in our install Jenkins step and changed the python version to 3.9.
```
sudo apt install fontconfig openjdk-17-jre software-properties-common -y && sudo add-apt-repository ppa:deadsnakes/ppa -y && sudo apt install python3.9 python3.9-venv -y
```
I also added `python3-pip` so the script can run the subsequent pip commands. I also included a "-y" on all my install commands to bypass the yes/no prompts to continue on with each installation - super helpful in a script. 

Then for my clone the repository section, I wrote an if statement that if the microblog_VPC_deployment directory doesn't already exists, then to git clone the repository and cd into the directory. In the else statement, if the microblog_VPC_deployment directory does already exist, I wrote `git pull main origin` so that the latest version of the repository is pulled and the cd command again to ensure the current directory is microblog_VPC_deployment.

```
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
```
Then I added in the remaining commands from the previous workloads needed to create and activate the venv, install all app dependencies, set environmental variables, establish the application database and translation files and lastly the gunicorn command to start the app. To allow the app to run in the background I added 'daemon' to the command: 
`gunicorn -b :5000 -w 4 microblog:app --daemon`

I also used "export" before FLASK_APP=microblog.py to make the flask_app variable "global" in a sense so that its value remains the same.

To test the script, from my Web_Server I ssh'd into my Application_Server to create and save start_app.sh. Then I ran in and all installation processes went through successfully. 

Next, I put the Web_Server IP address into my browser to confirm the microblog application was up and running and it was!

Then I ran `pgrep gunicorn` to see the processes running related to gunicorn and as expected, saw the gunicorn process as well as 4 other processes representing the 4 workers. Then I ran `pkill gunicorn` to kill all processes related.
![image](https://github.com/user-attachments/assets/8ede11da-a30b-4ac4-953b-934903f87a2e)

## "setup.sh" script
For the setup.sh script, I wrote the command to SSH into the "Application_Server" using its private IP. Next, I use the curl command with the -O flag to download my start_app.sh script that I had added to my GH repository. This step ensures that once I've SSH'd into the "Application_Server", I'll ensure that the start_app.sh script is available to be ran. Then I used `source` to run the start_app.sh script. To ensure all commands are run once the SSH into the "Application_Server" is done, I wrapped the rest of my commands with "<< EOF" "EOF" to make sure that they were run while still in the "Application_Server" -- more on this below.

```
#!/bin/bash

# will run in the "Web_Server" 

# SSH into the "Application_Server" 
ssh -i appserver.pem ubuntu@10.0.92.22 << EOF

echo "Downloading start_app.sh from GH..."
curl -O https://raw.githubusercontent.com/acurwen/microblog_VPC_deployment/refs/heads/main/scripts/start_app.sh

echo "Running the start_app.sh..."
source start_app.sh
EOF
```
Because I'm using source to execute my start_app.sh script, I didn't have to worry about figuring out how to change permissions on the script beforehand. I tested this out with a test.sh script that ran with `source` without me changing permissions for it to have executable rights. Addtionally, using source ensures your script runs in the current shell session vs. using bash or './' makes your scipt run in a new shell session. It's beneficial for my scripts to run in the current shell session so that any changes made by the scripts are reflected in my current shell.

**Testing Scripts:**

First, I wanted to test SSHing into another server and running a script there. I SSH'd into my Application_Server EC2 from my Web_Server EC2 and created a test script called setup.sh. I put an `echo "Hello World"` command in it, updated permissions and ran the script - It worked.

Then I logged out of the Application_Server, went back into my Web_Server EC2 and created another test script. In this test script, I wrote a command to SSH into the Application_Server EC2 and then run that setup.sh script I created before. 

When testing, I noticed that when I ran the second test script, the SSH portion worked but then the script stopped altogether –while I was "in" my Application_Server EC2.

Then I typed in exit to go back to my Web_Server and then the rest of the script ran. 
I used Chat GPT to understand why the rest of the commands seem to halt after the SSH and only continue once I log out and I found the "<< EOF" fix. Writing << EOF after the SSH command opens up a window where you can write additional commands to be executed while SShing into another server. To end the window, write another EOF. 

Updated my test-setup.sh script, tested it and it worked!

Lastly, I tested my real setup.sh script with my start_app.sh script and testing worked. I confirmed the microblog was running with my web server's public IP and then killed the gunicorn processes again. 

I also added my scripts to my repository in a directory called "Scripts". 


## Jenkins Build:

Before starting a build in Jenkins, I set up VPC Peering to connect the default VPC that Jenkins is in to the custom VPC I made where the Web_Server and Application_Server live. 

I set up VPC Peering so that in my Deploy stage, I could SSH into the Web Server from the Jenkins server with the private IP of the Web_Server. I updated the route tables of each VPC to have the Peering Connection I created and set the destination IP to be the CIDR block of the opposite VPC. 

![image](https://github.com/user-attachments/assets/fe202885-fc1a-4606-acf1-edd16fd1ed7c)

Public Route Table (Custom VPC):
![image](https://github.com/user-attachments/assets/15163a63-667e-415a-8d43-beeb61304d49)

Was successfully able to SSH from the Jenkins EC2 into the Web_Server with the private IP of the Web_Server.

Next, in the Jenkins EC2, I manually installed the dependencies for the microblog application so I didn't have to worry about including those commands in the Build stage of the Jenkinsfile. (I already ran the middle command with the script I made to install Jenkins when I first created the Jenkins EC2.)
```
sudo apt-get update -y
sudo apt install fontconfig openjdk-17-jre software-properties-common -y && sudo add-apt-repository ppa:deadsnakes/ppa -y && sudo apt install python3.9 python3.9-venv -y
sudo apt install python3-pip -y
```

Then in the *Build* Stage, I included all the commands for installing all the dependencies and requirements within the virtual environment created:
```
python3.9 -m venv venv
source venv/bin/activate
pip install pip --upgrade
pip install -r requirements.txt
pip install gunicorn pymysql cryptography
export FLASK_APP=microblog.py
flask translate compile
flask db upgrade
```

The *Test* stage I left the same as Workload 3's and made sure to put my pytest called test_app.sh in the same path (./tests/unit). I also added in my pytest.ini into my repository to ensure the path for my pytest is known as well as the rest of the application files. I made sure to update requirements.txt to include pytest, which was removed...


For the *OWASP* stage, I made sure to install the "OWASP Dependency-Check" plug-in and installed it as a Dependency-Check tool called "DP-Check".
The OWASP stage scans the project to detect if there any parts of the app that are categorized as vulnerable or “CVE” (Common Vulnerability and Exposure) and reports them back.

Lastly, for my *Deploy* stage I included a command to ssh into the Web_Server EC2 and run the setup.sh script with `source`. As mentioned before, I set up VPC Peering to establish a connection between the Jenkins server and Web_Server, enabling me to use the private IP of the Web_Server EC2 for the SSH command. To ensure the source setup.sh script ran I put it in single quotes in the same line as the SSH command. I tried to use the << EOF method here but Jenkins threw a syntax error.
```
ssh -i "/var/lib/jenkins/.ssh/id_ed25519" ubuntu@10.0.46.12 'source /home/ubuntu/setup.sh'
```

Build was a success:

![image](https://github.com/user-attachments/assets/037fc7cb-81d3-4333-8027-d9dfa7d4e725)


After a successful build, I tested the public IP of the Web_Server and the application showed up:
![image](https://github.com/user-attachments/assets/955e298c-c169-4716-801e-0502c31b9a4f)

**How do you get the scripts onto their respective servers if they are saved in the GitHub Repo? Do you SECURE COPY the file from one server to the next in the pipeline? Do you C-opy URL the file first as a setup? How much of this process is manual vs. automated?** I used the curl command to download the scripts onto their respective servers from GH. I used a manual command to get the setup.sh script onto the Web_Server, but the curl command to get the start_app.sh script onto the Application_Server was ran in the setup.sh script, automating that process. 

**In WL3, a method of "keeping the process alive" after a Jenkins stage completed was necessary. Is it in this Workload? Why or why not?** The keep the process alive method is not present in this workload nor was it necessary here because there's no Clean stage in the Jenkinsfile that stopped the gunicorn process. We are also serving up the appliction in the background in the Deploy stage with --daemon.  

# Monitoring:

Created "Monitoring" EC2 Instance::
- AMI (Amazon Machine Image): Ubuntu
- Instance type: t3.micro
- Key pair used was my default one
- Used the default VPC (Virtual Private Cloud)
- Picked a subnet that was in Availability Zone 1-east a (the same as the Application_Server and Web_Server)
- Security group rules included SSH (Port: 22), Grafana (Port: 3000), Prometheus (Port: 9090) and Node Exporter (Port: 9100) 
- Storage was set to 1x8 GiB and gp3 (General Purpose SSD) Root Volume

Instance:
![image](https://github.com/user-attachments/assets/c4c34c7d-75f0-4dbd-a878-c7fc3fdfbcd1)

Security groups:
![image](https://github.com/user-attachments/assets/257b7202-893a-4092-bcfc-bc5dc8991d8a)


To install Prometheus, Grafana and Node Exporter, I followed the steps in Mike's [repository](https://github.com/mmajor124/monitorpractice_promgraf/tree/main):

- Created and ran [promgraf.sh](https://github.com/mmajor124/monitorpractice_promgraf/blob/main/promgraf.sh) within my Monitoring instance

![image](https://github.com/user-attachments/assets/6e1b45ee-c2f6-4167-98f2-d6ce31f446b7)

Confirmed that Grafana and Prometheus were up and running:
![image](https://github.com/user-attachments/assets/039c0587-4fd7-4922-a32e-8d44e4f56bcf)

![image](https://github.com/user-attachments/assets/6ae7979b-b146-42e5-82a9-4cbe31ec7058)


- Created and ran [nodex.sh](https://github.com/mmajor124/monitorpractice_promgraf/blob/main/nodex.sh) within my Application_Server instance (by SSHing into it from the Web_Server)

Node Exporter lives on the Application_Server EC2 because it will export the metrics of the microblog application.


Before running nodex.sh, I commented out this part of nodex.sh since Prometheus and Grafana are instead installed on my Monitoring EC2. 
```
# Add Node Exporter job to Prometheus config
cat << EOF | sudo tee -a /opt/prometheus/prometheus.yml

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Restart Prometheus to apply the new configuration
sudo systemctl restart prometheus
```
![image](https://github.com/user-attachments/assets/9bc8039c-cb21-4e8c-9f0e-5f41623e57b0)


Then back in my Monitoring EC2, I ran those code sections:

I ran the below directly in the instance terminal.
```
cat << EOF | sudo tee -a /opt/prometheus/prometheus.yml

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
```
Then I ran `sudo nano /opt/prometheus/prometheus.yml` to doublecheck that the lines were added to my prometheus.yml file.

Later on I changed 'localhost' to the private IP of my Application_Server instance so that it could remain static. Then I ran `sudo systemctl restart prometheus` to update Prometheus with my updated endpoints. 

Lastly, I checked the targets in Prometheus to ensure my endpoints were "UP":
![image](https://github.com/user-attachments/assets/4fc91b9e-c419-42ac-875d-fae6ef8dc1e7)


We need all three of these systems because Grafana needs to understand where to find the data to make the graphs. Prometheus is the one grabbing all the data and lastly Node Exporter is the one storing all the metrics and handing Prometheus all the metrics. Grafana speaks to Prometheus within the Monitoring instance which speaks to Node Exporter that's scraping metrics from the Application_Server instance.

**Creating a Dashboard In Grafana** 

I logged into Grafana on port 3000 with 'admin, admin' credentials.

Created a new dashboard, added a data source (Prometeheus and URL http://172.31.18.164:9090 - using the private IP of my Monitoring server)

This time around, I imported a Node Exporter dashboard from Grafana's [templates](https://grafana.com/grafana/dashboards/). The dashboard view below is for the past 3 hours from which the screenshot was taken.

**Grafana Dashboard:**

![image](https://github.com/user-attachments/assets/aaecc145-5cc9-4f76-ac82-03f4570ae8d4)
![image](https://github.com/user-attachments/assets/15f2904e-c942-42a1-9032-47503fef6399)


# System Design Diagram:
![image](https://github.com/user-attachments/assets/b0c7b4b8-a254-42c3-974b-e4af4f4d726f)


# Troubleshooting:
**Installing Jenkins onto EC2:**

When creating my Jenkins installation script, I didn't include the commands to install python 3.9 or python venv 3.9 at first thinking I wasn't gonna use this instance to create the virtual environment. However, I do since creating and activating the Python environment is a part of the Jenkins pipeline build. I also received these error messages when first running my Jenkins script:

"Package python is not available, but is referred to by another package."
"Package ‘python’ has no installation candidate."

![image](https://github.com/user-attachments/assets/75049762-209a-42a1-bc5d-72049898ed00)

In the command beore we are installing the python dead snakes repository which allows you to install multiple python versions. So the script ran that command which triggered the system t check for whatever pythinv ersin was supposed to be created. I can tell this because I added an echo message that says "First line complete." after that first code chunk is ran.

I ran `sudo apt install python3.9 python3.9-venv` to make sure I had python and the correct version installed. 

**Testing Connection from Web_Server to Application_Server:**

After copying the contents of my appserver.pem file in to anew file in the "Web_Server" EC2, I ran `ssh -i appserver.pem ubuntu@10.0.92.22` to test the connection.

However, I wasn't able to connect as the "Permissions 0664 for 'appserver.pem' are too open."
![image](https://github.com/user-attachments/assets/c4984866-de5b-4ae4-9ec0-7cc73727a895)

I forgot I needed to first change permissions of the file so that only I as the owner could have read access. 
Ran `chmod 400 appserver.pem` and then the ssh command again and I was able to connect. 

**Jenkins Build**
First, I couldn't get past the Build stage because of a syntax error where I forgot the three ticks (''') that open and close a bash script and a '}'.

![image](https://github.com/user-attachments/assets/861672e6-1e34-40f7-a986-b74df6ce1ca1)

Then, I couldn't get past the Build stage because the build couldn't find my public key. Then I adjusted the path to where it was (/home/ubuntu/.ssh/id_ed25519) and received a Permission denied error. By default, anyone other than me cannot access. 
To rectify, I realize I needed jenkins to be the owner of the keypair so while in the Jenkins EC2, I switched users to jenkins with `sudo su - jenkins` and ran ssh-keygen to get another keypair -- added that to the authorized key file in the Web_Server. I also changed the permissions to read permissions for the key. At first, ssh-ing still didn't work until I rebooted my instance. 


I also realized that I had initially copied the key fingerprint into the authorized key file instead of the actual public key. I got a message in my terminal that the key fingerprint for my key pair is "SHA256" so I thought momentarily that I needed to use that instead for future ssh-ing. 

Lastly, in my Deploy Stage I included EOF after the SSH command to ensure that my source setup.sh line would run while still in the Application_server. However, I got an error where Jenkins didn't recognize that syntax. 
![image](https://github.com/user-attachments/assets/d56d9956-bf29-41e4-b988-ef8c809cc304)


So I ended up taking that out and instead wrote the source setup.sh on the same line as the SSH command with single quotes around it. 

```
ssh -i "/var/lib/jenkins/.ssh/id_ed25519" ubuntu@10.0.46.12 << EOF
source /home/ubuntu/setup.sh
EOF
```

```
ssh -i "/var/lib/jenkins/.ssh/id_ed25519" ubuntu@10.0.46.12 'source /home/ubuntu/setup.sh'
```
Build History:
![image](https://github.com/user-attachments/assets/35418e9f-0dc2-46dd-8b74-64a03ccf5f62)

**Monitoring:**

In the Prometheus web GUI, in Status > Targets I saw my Node Exporter endpoint was down. I realized that during my VPC Peering setup, I didn't update my private route table (of my custom VPC) to add the VPC Peering connection and the destination of the default VPC's CIDR. Once I added the VPC connection, my Monitoring EC2 and Application_Server EC2 were able to connect and my metrics were pulled. 
![image](https://github.com/user-attachments/assets/a1321ae8-97c6-4c8a-b969-8849f74f4aa1)

# Optimization:
What are the advantages of separating the deployment environment from the production environment? Separating deployment environment from the production environment ensures more security around the application code in the production environment separate from the web server its hosted on so that in the case of an attack, there's multiple defense posts so to speak in front of the application code.

Does the infrastructure in this workload address these concerns? Yes, we had our application tier in a different EC2 than our web server tier, which was in a separate VPC than our Jenkins EC2 and monitoring EC2.

Could the infrastructure created in this workload be considered that of a "good system"? Why or why not? Yes, but copying the key pairs over manually felt prone to human error. In fact, I did make an error where I copied over the key fingerprint instead of the public key to the authorized keys file. 

# Conclusion:
Splitting up our infrastructure made this project feel quite realistic, specifically understanding how many moving parts are involved in deploying and hosting an applciation and why it's important to ensure that those parts are able to communicate with one another. 
