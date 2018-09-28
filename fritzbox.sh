#!/usr/bin/env bash

. ./config.sh

# Below be dragons
SID=$(cat /tmp/fritzbox-sid.txt)

greater()
{
    if [ $(echo "$1>$2"| bc) -eq 0 ]; then
	return 0
    else
	return 1
    fi
}

lower()
{
    if [ $(echo "$1<$2"| bc) -eq 0 ]; then
	return 0
    else
	return 1
    fi
}

curl -sk "https://$HOST/internet/docsis_info.lua?update=uiInfo&sid=$SID&xhr=1&t1537694807848=nocache" | html2text | sed "s@\xA0@@g" | sed "s@\xC2@@g"  > /tmp/fritzbox.txt

if [ ! -s /tmp/fritzbox.txt ]; then
    FRITZLOGINCHALLENGE=$(curl -sk "https://$HOST/login_sid.lua" |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d ">" -f 2)
    FRITZLOGINHASH=$(echo -n "$FRITZLOGINCHALLENGE-$PASS" | sed -e "s@.@&\n@g" | tr "\n" "\0" | md5sum | grep -o "[0-9a-z]\{32\}")
    SID=$(curl -sk "https://$HOST/login_sid.lua" -d "response=$FRITZLOGINCHALLENGE-$FRITZLOGINHASH" -d "username=$USER" | grep -o "<SID>[a-z0-9]\{16\}" |  cut -d ">" -f 2)
    echo "$SID" > /tmp/fritzbox-sid.txt
    curl -sk "https://$HOST/internet/docsis_info.lua?update=uiInfo&sid=$SID&xhr=1&t1537694807848=nocache" | html2text | sed "s@\xA0@@g" | sed "s@\xC2@@g"  > /tmp/fritzbox.txt
fi

if [ ! -s /tmp/fritzbox.txt ]; then
    echo "CRITICAL! No Data found"
    exit 1
else
    FPING=$(fping -c 10 -o -q 8.8.8.8 2>&1)
    PACKETLOSS=$(echo "$FPING" | cut -d "/" -f 5 | cut -d "," -f 1)
    
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
			OUTPUT="$OUTPUT CRITICAL: Upper Limit ${CRIT_LOWER[$LINENUMBER]} is >> than"
			CRITICAL=1
		    elif [ "${CRIT_UPPER[$LINENUMBER]+isset}" ] && greater "${CRIT_UPPER[$LINENUMBER]}" "$VALUE"; then
			OUTPUT="$OUTPUT CRITICAL: Lower Limit ${CRIT_UPPER[$LINENUMBER]} is << than"
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
    done < /tmp/fritzbox.txt
    
    echo "$OUTPUT |$PERFDATA"
    if [ ! -z "$CSVOUT" ]; then
	echo "$CSV" >> "$CSVOUT"
    fi
fi

if [ $CRITICAL -eq 1 ]; then
    exit 2
elif [ $WARNING -eq 1 ]; then
    exit 1
else
    exit 0
fi
