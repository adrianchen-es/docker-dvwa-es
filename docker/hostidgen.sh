#!/bin/sh
set -e
set -u

if [ ! -f "/etc/machine-id" ]; 
then 
        dbus-uuidgen > /etc/machine-id
else
        apt-get purge dbus-tests -y
fi
