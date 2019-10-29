#!/usr/bin/env bash

. ./check_fritzbox.config.sh

if [ "$DEBUG" == "true" ]; then
    set -x
fi

# Below be dragons

greater()
{
    if [ $(echo "$1>=$2"| bc) -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

lower()
{
    if [ $(echo "$1<=$2"| bc) -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

status_unknown()
{
    echo $1
    exit 3
}

login()
{
    FRITZLOGINCHALLENGE=$(curl -sk "https://$HOST/login_sid.lua" |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d ">" -f 2)
    FRITZLOGINHASH=$(echo -n "$FRITZLOGINCHALLENGE-$PASS" | sed -e "s@.@&\n@g" | tr "\n" "\0" | md5sum | grep -o "[0-9a-z]\{32\}")
    SID=$(curl -sk "https://$HOST/login_sid.lua" -d "response=$FRITZLOGINCHALLENGE-$FRITZLOGINHASH" -d "username=$USER" | grep -o "<SID>[a-z0-9]\{16\}" |  cut -d ">" -f 2)
    echo "$SID" > /tmp/icinga-fritzbox-$HOST-sid.txt
}
