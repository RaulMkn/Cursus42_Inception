#!/bin/bash

FTP_USER="${FTP_USER:-ftpuser}"
FTP_PASSWORD="${FTP_PASSWORD:-ftp_password}"
FTP_HOME="/var/www/html"

mkdir -p "$FTP_HOME"
mkdir -p /var/run/vsftpd/empty

if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd -m -d "/home/$FTP_USER" -s /bin/bash "$FTP_USER"
fi

echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
usermod -aG www-data "$FTP_USER"

chown "$FTP_USER":www-data "/home/$FTP_USER"
find "$FTP_HOME" -type d -exec chmod 775 {} \;
find "$FTP_HOME" -type f -exec chmod 664 {} \;

cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=002
chroot_local_user=YES
allow_writeable_chroot=YES
check_shell=NO
pam_service_name=vsftpd
secure_chroot_dir=/var/run/vsftpd/empty
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30009
pasv_address=${FTP_PASV_ADDRESS}
local_root=${FTP_HOME}
EOF

exec /usr/sbin/vsftpd /etc/vsftpd.conf