#!/usr/bin/bash
apt update -y
apt install wget unzip apache2 -y
systemctl start apache2
systemctl enable apache2

cd /tmp
wget -O 2117_infinite_loop.zip https://www.tooplate.com/zip-templates/2117_infinite_loop.zip
unzip -o 2117_infinite_loop.zip

rm -rf /var/www/html/*
cp -r 2117_infinite_loop/* /var/www/html/
systemctl restart apache2