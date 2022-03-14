echo "=========== CREATE USER ============="
user=lsma
password="deploy@1234qwer"
source=$(cat ./source.txt)
tag=$(cat ./tag.txt)
userdel $user
useradd -p $(openssl passwd -crypt $password) -s /bin/bash $user

echo "=========== GENERATE PUBLIC_KEY ============"
su - $user -c "ssh-keygen -b 2048 -t rsa -f /home/$user/.ssh/id_rsa -q -N ''"
cp /home/$user/.ssh/id_rsa.pub ./id_lsma.public
cp /home/$user/.ssh/id_rsa ./id_lsma.pem
su - $user -c "echo $(cat /home/$user/.ssh/id_rsa.pub) > /home/$user/.ssh/authorized_keys"

echo "=========== COPY DEPLOY_FILE ============"
cp ./tag.txt /home/$user/tag.txt && chown $user:$user /home/$user/tag.txt
cp ./source.txt /home/$user/source.txt && chown $user:$user /home/$user/source.txt
cp ./deploy.sh /home/$user/deploy.sh && chown $user:$user /home/$user/deploy.sh
cp ./config /home/$user/.ssh/config && chown $user:$user /home/$user/.ssh/config
su - $user -c "ssh-keyscan -t rsa gitlab.com >> ~/.ssh/known_hosts"

echo "=========== CLONE PROJECT ============="
su - $user -c "git clone -b $tag --single-branch $source project"

echo "=========== UPGRADE SYSTEM ============="
apt-get update

echo "=========== INSTALL GIT ============="
apt-get install git -y

echo "=========== INSTALL NGINX ============"
apt-get install nginx -y
cp ./project.conf /etc/nginx/conf.d/project.conf
service nginx restart

echo "=========== REMOVE DOCKER ============="
apt-get remove docker docker-engine docker.io containerd runc

echo "=========== SETUP DOCKER REPOSITORY =============="
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io -y
groupadd docker
usermod -aG docker $user

echo "============== INSTALL DOCKER-COMPOSE ==================="
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version
