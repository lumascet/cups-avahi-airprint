#!/bin/sh
set -e

# Is CUPSADMIN set? If not, set to default
if [ -z "$CUPSADMIN" ]; then
    CUPSADMIN="cupsadmin"
fi

# Is CUPSPASSWORD set? If not, set to $CUPSADMIN
if [ -z "$CUPSPASSWORD" ]; then
    CUPSPASSWORD=$CUPSADMIN
fi

if [ $(grep -ci $CUPSADMIN /etc/shadow) -eq 0 ]; then
    adduser -S -G lpadmin --no-create-home $CUPSADMIN 
fi
echo $CUPSADMIN:$CUPSPASSWORD | chpasswd

mkdir -p /config/ppd
mkdir -p /services
rm -rf /etc/avahi/services/*
rm -rf /etc/cups/ppd
ln -s /config/ppd /etc/cups
if [ `ls -l /services/*.service 2>/dev/null | wc -l` -gt 0 ]; then
    cp -f /services/*.service /etc/avahi/services/
fi
if [ `ls -l /config/printers.conf 2>/dev/null | wc -l` -eq 0 ]; then
    touch /config/printers.conf
fi
cp /config/printers.conf /etc/cups/printers.conf

if [ `ls -l /config/cupsd.conf 2>/dev/null | wc -l` -ne 0 ]; then
    cp /config/cupsd.conf /etc/cups/cupsd.conf
fi

/usr/sbin/avahi-daemon --daemonize
/root/printer-update.sh &
exec /usr/sbin/cupsd -f &

# Check if the USB device ID is set
if [ -z "$USB_DEVICE_ID" ]; then
    echo "USB_DEVICE_ID environment variable is not set. Exiting script."
    exit 1
fi

# Check if the USB device is already connected
if lsusb | grep -q "$USB_DEVICE_ID"; then
    DEVICE_CONNECTED_BEFORE=1
else
    DEVICE_CONNECTED_BEFORE=0
fi

while true; do
    if [ $DEVICE_CONNECTED_BEFORE -eq 0 ] && lsusb | grep -q "$USB_DEVICE_ID"; then
        DEVICE_CONNECTED_BEFORE=1
        echo "USB device $USB_DEVICE_ID reconnected. Exiting script."
        exit 0
    elif [ $DEVICE_CONNECTED_BEFORE -eq 1 ] && ! lsusb | grep -q "$USB_DEVICE_ID"; then
        DEVICE_CONNECTED_BEFORE=0
        echo "USB device $USB_DEVICE_ID disconnected. Waiting to reconnect."
    fi
    sleep 5
done