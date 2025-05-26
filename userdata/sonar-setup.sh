#!/bin/bash

# Backup and update sysctl.conf
cp /etc/sysctl.conf /root/sysctl.conf_backup
cat <<EOT> /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
EOT
sysctl -p

# Set limits.conf
cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat <<EOT> /etc/security/limits.conf
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOT

# Install Java 17
java -version

# Install PostgreSQL 15
tee /etc/yum.repos.d/pgdg.repo > /dev/null <<EOF
[pgdg15]
name=PostgreSQL 15 for Amazon Linux 2
baseurl=https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64
enabled=1
gpgcheck=1
gpgkey=https://download.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG
EOF

yum -qy module disable postgresql
yum install -y postgresql15 postgresql15-server

/usr/bin/postgresql-setup initdb
systemctl enable postgresql
systemctl start postgresql

# Set password and create user/db
echo "postgres:admin123" | chpasswd
runuser -l postgres -c "createuser sonar"
runuser -l postgres -c "psql -c \"ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';\""
runuser -l postgres -c "psql -c \"CREATE DATABASE sonarqube OWNER sonar;\""
runuser -l postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;\""

# Setup SonarQube
mkdir -p /sonarqube/
cd /sonarqube/
yum install -y unzip wget
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.8.100196.zip
unzip -o sonarqube-9.9.8.100196.zip -d /opt/
mv /opt/sonarqube-9.9.8.100196/ /opt/sonarqube

groupadd sonar
useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
chown sonar:sonar /opt/sonarqube/ -R

# Configure sonar.properties
cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
cat <<EOT > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT

# Create systemd service
cat <<EOT > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube


# Install and configure nginx
yum install -y nginx
rm -f /etc/nginx/conf.d/default.conf
cat <<EOT > /etc/nginx/conf.d/sonarqube.conf
server {
    listen      80;
    server_name sonarqube.groophy.in;

    access_log  /var/log/nginx/sonar.access.log;
    error_log   /var/log/nginx/sonar.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass  http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto http;
    }
}
EOT

systemctl enable nginx
