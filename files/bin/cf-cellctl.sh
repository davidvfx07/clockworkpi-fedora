#!/bin/bash

GPIOCHIP="gpiochip0"
GPIO_POWER=24
GPIO_ENABLE=15

SCRIPT_NAME="$(basename "$0")"
if [[ $EUID -ne 0 ]]; then
   echo "$SCRIPT_NAME must be run as root."
   exit 1
fi

if pgrep "gpioset -c $GPIOCHIP" > /dev/null; then
    echo "$SCRIPT_NAME is still completing a previous task. Please try again in a bit."
fi

function status {
    if [ -e /dev/ttyUSB2 ]; then
        echo "Modem (/dev/ttyUSB2) exists."
    else
        echo "Modem (/dev/ttyUSB2) does not exist."
    fi
}

function enable {
    echo "Powering on 4G module..."
    
    gpioset -c $GPIOCHIP -p 20s -t 0 -z $GPIO_ENABLE=1
    gpioset -c $GPIOCHIP -p 5s -t 0 -z $GPIO_POWER=1
    
    echo "Waiting 15 seconds for modem boot..."
    sleep 15
    
    status
}

function disable {
    echo "Powering off 4G module..."    

    gpioset -c $GPIOCHIP -p 35s -t 0 -z $GPIO_ENABLE=0
    gpioset -c $GPIOCHIP -p 5s -t 0 $GPIO_POWER=1
    
    echo "Waiting 25 seconds for modem poweroff..."
    sleep 25
    
    status
}

case "${1:-}" in
    enable) enable ;;
    disable) disable ;;
    status) status ;;
    *) echo "Usage: $0 {enable|disable|status}"; exit 1 ;;
esac
