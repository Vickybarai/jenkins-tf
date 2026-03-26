
provider "aws" {
  region = "ca-central-1"
}

module "jenkins" {

  source = "../modules/ec2"
  instance_name = "instance"
  environment_name = "jenkins"
  ami_value = "ami-0938a60d87953e820"
  instance_type_value = "t3.micro"
  instance_key_name = "TF-key"
  vpc_security_group_ids = ["sg-0c34f567e22c52e77"]
  subnet_id_value = ["subnet-016c5cd1838c909f4"]
  storage_size = 20

 user_data = <<-EOF
    sudo apt update

        sudo apt-get update -y

    sleep 10

    sudo apt install fontconfig openjdk-17-jre -y
    
    sleep 10
    
     sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
      https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
      https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null

    sleep 10

    sudo apt update
    sudo apt install jenkins -y

    sleep 10

    sudo systemctl start jenkins
    sudo systemctl enable jenkins

    sudo cat /var/lib/jenkins/secrets/initialAdminPassword


    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform


 sudo apt install zip -y

 curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

aws configure

EOF
}

output "jenkins_public_ip" {
  value = module.jenkins.public_ip
}
