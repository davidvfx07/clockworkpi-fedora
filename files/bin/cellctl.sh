#!/bin/bash

CHIP="gpiochip0"
POWER=24
RESET=15

SET="gpioset -c $CHIP -t 0 -z -p"

if [[ $EUID -ne 0 ]]; then
   SCRIPT_NAME="$(basename "$0")"
   echo "$SCRIPT_NAME must be run as root."
   exit 1
fi


function get_state {
    STATE=0
    if [ -e /dev/ttyUSB2 ]; then
        STATE=1
    fi

    return $STATE
}

function status {
    get_state
    if [ $? -eq 1 ]; then
        echo "Modem (/dev/ttyUSB2) is connected."
    else
        echo "Modem (/dev/ttyUSB2) is disconnected."
    fi
}

function toggle {
    get_state
    OLD_STATE=$?

    echo "Toggling power to modem..."

    $SET 3s $POWER=0
    sleep 3
    $SET 10s $POWER=1

    while true; do
        get_state
        if [ $? -ne $OLD_STATE ]; then
            echo
            status
            echo "Please wait for ModemManager to pick up changes."
            exit
        fi

        sleep 1
    done
}

function on {
    get_state
    if [ $? -eq 1 ]; then
        echo "Modem already powered on."
    else
        toggle
    fi
}

function off {
    get_state
    if [ $? -eq 0 ]; then
        echo "Modem already powered off."
    else
        toggle
    fi
}


case "${1:-}" in
    on) on ;;
    off) off ;;
    toggle) toggle ;;
    status) status ;;
    *) echo "Usage: $0 {status|on|off|toggle}"; exit 1 ;;
esac
