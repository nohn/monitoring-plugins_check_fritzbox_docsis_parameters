#!/usr/bin/env bash

. ./config.sh

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

fetch_data()
{
    curl -sk "https://$HOST/internet/docsis_overview.lua?sid=$SID&update=&xhr=1&t1540371669938=nocache" > /tmp/icinga-fritzbox-$HOST-general.json
    curl -sk "https://$HOST/internet/docsis_info.lua?update=uiInfo&sid=$SID&xhr=1&t1537694807848=nocache" | html2text | sed "s@\xA0@@g" | sed "s@\xC2@@g"  > /tmp/icinga-fritzbox-$HOST-channels.html
}

if [ ! -s /tmp/icinga-fritzbox-$HOST-sid.txt ] || [ ! -s /tmp/icinga-fritzbox-$HOST-channels.html ] || [ ! -s /tmp/icinga-fritzbox-$HOST-general.json ]; then
    login
else
    SID=$(cat /tmp/icinga-fritzbox-$HOST-sid.txt)
fi

fetch_data

if [ ! -s /tmp/icinga-fritzbox-$HOST-channels.html ] || [ ! -s /tmp/icinga-fritzbox-$HOST-general.json ]; then
    login
    fetch_data
fi

NUMDSCHANNELS=$(cat /tmp/icinga-fritzbox-$HOST-general.json | jq -r '.ds_count')
NUMUSCHANNELS=$(cat /tmp/icinga-fritzbox-$HOST-general.json | jq -r '.us_count')
DOCSISVERSION=$(cat /tmp/icinga-fritzbox-$HOST-general.json | jq -rc '.stateTxt[] | select(contains("DOCSIS"))')

# Thresholds for RX SNR MSE
CRIT_LOWER[16]=30.1
WARN_LOWER[16]=32.1
if echo $DOCSISVERSION | grep -q "DOCSIS 3.0"; then
    # Thresholds for RX Power Level
    # In fact, these values depend on the QAM, using 256QAM
    # thresholds here. 64QAM is more tolerant...
    CRIT_LOWER[15]=-7.9
    WARN_LOWER[15]=-5.9
    WARN_UPPER[15]=18
    CRIT_UPPER[15]=20
    # Thresholds for TX Power Level
    CRIT_LOWER[32]=35.1
    WARN_LOWER[32]=37.1
    WARN_UPPER[32]=51
    CRIT_UPPER[32]=53
elif echo $DOCSISVERSION | grep -q "DOCSIS 3.1"; then
    # Thresholds for RX Power Level
    # In fact, these values depend on the QAM, using 4096QAM
    # thresholds here. 2048QAM and 1024 QAM are more tolerant...
    CRIT_LOWER[15]=-1.9
    WARN_LOWER[15]=0.1
    WARN_UPPER[15]=24
    CRIT_UPPER[15]=26
    # Thresholds for TX Power Level
    CRIT_LOWER[32]=38.1
    WARN_LOWER[32]=40.1
    WARN_UPPER[32]=48
    CRIT_UPPER[32]=50
else
    status_unknown "$DOCSISVERSION is unknown to me."
fi

if [ ! -z "$CSVOUT" ]; then
    FPING=$(fping -c 10 -o -q 8.8.8.8 2>&1)
    PACKETLOSS=$(echo "$FPING" | cut -d "/" -f 5 | cut -d "," -f 1)
else
    PACKETLOSS="undefined"
fi

METRICS[12]="RX Channel"
METRICS[13]="RX Frequency"
METRICS[14]="RX Modulation QAM"
METRICS[15]="RX Power Level"
METRICS[16]="RX SNR MSE"
METRICS[17]="RX Latency"
METRICS[18]="RX Correctable Errors"
METRICS[19]="RX Uncorrectable Errors"
METRICS[28]="TX Channel"
METRICS[29]="TX Frequency"
METRICS[30]="TX Modulation QAM"
METRICS[32]="TX Power Level"

UNITS[18]=c
UNITS[19]=c

LINENUMBER=0;
OUTPUT=""
PERFDATA=""
CSV=$(date -u +"%Y-%m-%dT%H:%M:%SZ")";$PACKETLOSS"
CRITICAL=0
WARNING=0
while read -r LINE; do
    LINENUMBER=$((LINENUMBER+1))
    METRIC=${METRICS[$LINENUMBER]}
    if [ ! -z "$METRIC" ]; then
        OUTPUT="$OUTPUT $METRIC:"
        IFS=" " read -r -a LINEARRAY <<< "$LINE"
        for CHANNEL in $(seq 1 "$MAX_CHANNELS"); do
            CHANNELINDEX=$((CHANNEL-1))
            if [ "${LINEARRAY[$CHANNELINDEX]+isset}" ]; then
                VALUE=$(echo "${LINEARRAY[$CHANNELINDEX]}" | grep -Eo "[0-9]*\.?[0-9]*" )
                if [ "${CRIT_LOWER[$LINENUMBER]+isset}" ]   && lower   "${CRIT_LOWER[$LINENUMBER]}" "$VALUE"; then
                    OUTPUT="$OUTPUT CRITICAL: Lower Limit ${CRIT_LOWER[$LINENUMBER]} is >> than"
                    CRITICAL=1
                elif [ "${CRIT_UPPER[$LINENUMBER]+isset}" ] && greater "${CRIT_UPPER[$LINENUMBER]}" "$VALUE"; then
                    OUTPUT="$OUTPUT CRITICAL: Upper Limit ${CRIT_UPPER[$LINENUMBER]} is << than"
                    CRITICAL=1
                elif [ "${WARN_LOWER[$LINENUMBER]+isset}" ] && lower   "${WARN_LOWER[$LINENUMBER]}" "$VALUE"; then
                    OUTPUT="$OUTPUT WARNING: Lower Limit ${WARN_LOWER[$LINENUMBER]} is > than"
                    WARNING=1
                elif [ "${WARN_UPPER[$LINENUMBER]+isset}" ] && greater "${WARN_UPPER[$LINENUMBER]}" "$VALUE"; then
                    OUTPUT="$OUTPUT WARNING: Upper Limit ${WARN_UPPER[$LINENUMBER]} is < than"
                    WARNING=1
                fi
            else
                VALUE=0
            fi
            OUTPUT="$OUTPUT $VALUE"
            PERFDATA="$PERFDATA '${METRIC} ${CHANNEL}'=$VALUE${UNITS[$LINENUMBER]}"
            CSV="$CSV;$VALUE"
        done
    fi
done < /tmp/icinga-fritzbox-$HOST-channels.html

echo "$OUTPUT |$PERFDATA"
if [ ! -z "$CSVOUT" ]; then
    echo "$CSV" >> "$CSVOUT"
fi

if [ $CRITICAL -eq 1 ]; then
    exit 2
elif [ $WARNING -eq 1 ]; then
    exit 1
else
    exit 0
fi
