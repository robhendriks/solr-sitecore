#!/bin/bash

solrVersion=$1
solrPassword=$2
dnsNameFQDN=$3
solrCert=$4

{
    if [ -f /var/log/solrInstall.log ]; then
        echo "This install script has already run before, log file found, exiting script" >/var/log/Skippedinstall.log
        exit 0
    fi
}

# Start logging
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/var/log/solrInstall.log 2>&1

echo "127.0.0.1 $dnsNameFQDN" >>/etc/hosts

# Create Disk
if lsblk | grep -q 'sdc'; then
    echo "Use additional disk to store files"
    mkfs.ext4 -F /dev/sdc
    mkdir /opt -p
    diskid=$(blkid | grep -i sdc | cut -d '"' -f2 | cut -d '.' -f1-4)
    mount /dev/sdc /opt
    echo "UUID=$diskid /opt ext4 defaults,nofail 0 0" >>/etc/fstab
    echo "/dev/sdc Disk creation successful"
else
    if lsblk | grep 'sdb1\|/mnt/resource'; then
        echo "Found Temporary Disk"
        echo "Does not Contain additional disk, will create a directory on local drive"
    else
        if lsblk | grep 'sdb'; then
            echo "Use additional disk to store files"
            mkfs.ext4 -F /dev/sdb
            mkdir /opt -p
            diskid=$(blkid | grep -i sdb | cut -d '"' -f2 | cut -d '.' -f1-4)
            mount /dev/sdb /opt
            echo "UUID=$diskid /opt ext4 defaults,nofail 0 0" >>/etc/fstab
            echo "/dev/sdb Disk creation successful"
        else
            echo "Does not Contain additional disk, will create a directory on local drive"
        fi
    fi
fi

apt-get update -y

apt-get install -y wget apt-transport-https software-properties-common
# Download the Microsoft repository GPG keys
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
# Register the Microsoft repository GPG keys
dpkg -i packages-microsoft-prod.deb
# Update the list of products
apt-get update -y
# Enable the "universe" repositories
add-apt-repository universe

packagelist=(
    'wget'
    'unzip'
    'lsof'
    'openjdk-11-jdk'
    'powershell'
)

for i in "${packagelist[@]}"; do
    apt-get install "${i}" -y
done

java -version

useradd solr
echo "solr:$solrPassword" | chpasswd

# Prepare and INSTALL SOLR
if [ -z "$solrVersion" ]; then
    echo "\$solrVersion is empty, setting to version 8.4.0"
    solrVersion=8.4.0
else
    echo "\$solrVersion is set to $solrVersion"
fi

echo "solrVersion is $solrVersion"

echo 'solr soft nofile 65000' >>/etc/security/limits.conf
echo 'solr hard nofile 65000' >>/etc/security/limits.conf
echo 'root soft nofile 65000' >>/etc/security/limits.conf
echo 'root hard nofile 65000' >>/etc/security/limits.conf
echo 'solr soft nproc  65000' >>/etc/security/limits.conf
echo 'solr hard nproc  65000' >>/etc/security/limits.conf
echo 'root soft nproc  65000' >>/etc/security/limits.conf
echo 'root hard nproc  65000' >>/etc/security/limits.conf

echo 'solr soft nproc 65000' >>/etc/security/limits.d/20-nproc.conf

mkdir -p /opt/dist/
mkdir -p /opt/solr/

mkdir ~/tmp
cd ~/tmp

wget http://archive.apache.org/dist/lucene/solr/${solrVersion}/solr-${solrVersion}.tgz -q

tar zxf solr-${solrVersion}.tgz solr-${solrVersion}/bin/install_solr_service.sh --strip-components=2
bash ./install_solr_service.sh solr-${solrVersion}.tgz -i /opt/dist -d /opt/solr -u solr -s solr -p 8983

#Configure SSL
keyStorePass=secret

cd /opt/dist/solr/server/etc/

# First create powershell script to convert Base64 encoded KeyVault cert to PFX

cat <<EOT >ConvertToPFX.ps1

param(
    [Parameter(Mandatory=\$True)][string]\$certString
)

\$kvSecretBytes = [System.Convert]::FromBase64String(\$certString)
\$certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
\$certCollection.Import(\$kvSecretBytes,\$null,[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
\$password = 'secret'
\$protectedCertificateBytes = \$certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, \$password)
\$pfxPath = "/opt/dist/solr/server/etc/solr-ssl.keystore.p12"
[System.IO.File]::WriteAllBytes(\$pfxPath, \$protectedCertificateBytes)

EOT
#Convert
echo "Convert the Base64 Encoded value of the solrCert variable to a PFX"
pwsh ConvertToPFX.ps1 -certString $solrCert

sed -i "s/#SOLR_SSL_ENABLED=true/SOLR_SSL_ENABLED=true/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_KEY_STORE=etc\/solr-ssl.keystore.jks/SOLR_SSL_KEY_STORE=etc\/solr-ssl.keystore.p12/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_KEY_STORE_PASSWORD=${keyStorePass}/SOLR_SSL_KEY_STORE_PASSWORD=${keyStorePass}/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_TRUST_STORE=etc\/solr-ssl.keystore.jks/SOLR_SSL_TRUST_STORE=etc\/solr-ssl.keystore.p12/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_TRUST_STORE_PASSWORD=${keyStorePass}/SOLR_SSL_TRUST_STORE_PASSWORD=${keyStorePass}/" /etc/default/solr.in.sh
#sed -i "s/#SOLR_SSL_NEED_CLIENT_AUTH=false/SOLR_SSL_NEED_CLIENT_AUTH=false/" /etc/default/solr.in.sh
#sed -i "s/#SOLR_SSL_WANT_CLIENT_AUTH=false/SOLR_SSL_WANT_CLIENT_AUTH=false/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_CHECK_PEER_NAME=true/SOLR_SSL_CHECK_PEER_NAME=false/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_KEY_STORE_TYPE=JKS/SOLR_SSL_KEY_STORE_TYPE=PKCS12/" /etc/default/solr.in.sh
sed -i "s/#SOLR_SSL_TRUST_STORE_TYPE=JKS/SOLR_SSL_TRUST_STORE_TYPE=PKCS12/" /etc/default/solr.in.sh

# Configure SOLR memory and leave 2 GB free
cat <<EOT >>/etc/default/set_solr_memory.sh
#!/bin/bash

totalmemory=\$(free -g | gawk  '/Mem:/{print \$2}')
memory=\$((totalmemory-2))g

stringToReplace="SOLR_JAVA_MEM="
stringToReplaceWith="SOLR_JAVA_MEM=\"-Xms512m -Xmx\$memory\""
sed -i "s/.*\$stringToReplace.*/\$stringToReplaceWith/" /etc/default/solr.in.sh 
EOT

#make sure to remove empty lines
sed -i '/^$/d' /etc/default/set_solr_memory.sh

# Set SOLR HOME
sed -i "s/#SOLR_HOME=/SOLR_HOME=\/opt\/solr\/data/" /etc/default/solr.in.sh
sed -i "s/#SOLR_PID_DIR=/SOLR_PID_DIR=\/opt\/solr/" /etc/default/solr.in.sh
echo 'SOLR_OPTS="$SOLR_OPTS -Dlog4j2.formatMsgNoLookups=true"' >>/etc/default/solr.in.sh

chmod +x /etc/default/set_solr_memory.sh

# Set Solr Server Service
rm -rf /etc/init.d/solr

cat <<EOT >>/etc/systemd/system/solr.service
[Unit]
Description=Apache SOLR
After=network.target

[Service]
PermissionsStartOnly=true
ExecStartPre=/etc/default/set_solr_memory.sh
Type=forking
User=solr
Group=solr
Environment=SOLR_INCLUDE=/etc/default/solr.in.sh
ExecStart=/opt/dist/solr/bin/solr start
ExecStop=/opt/dist/solr/bin/solr stop
Restart=on-failure
LimitNOFILE=65000
LimitNPROC=65000
TimeoutSec=180s

[Install]
WantedBy=multi-user.target
EOT

chown -R solr:solr /opt/solr/
chown -R solr:solr /opt/dist/
chown -R solr:solr /etc/default/solr.in.sh

systemctl enable solr

# Doesn't work on 20.04 LTS
# firewall-cmd --permanent --add-port=8983/tcp
