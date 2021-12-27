#Install Terraform
echo "Install terraform"
yum install -y yum-utils

yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

yum -y install terraform

echo ${terraform --version}

echo ${terraform -chdir=terraform init}