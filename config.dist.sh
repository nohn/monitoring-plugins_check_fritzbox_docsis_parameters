#!/usr/bin/env bash
HOST="fritz.box"
USER="user"
PASS="password"
# Your Mileage may vary. Fritzbox 6360 has 4 Channels. RRDTools sucks
# with dynamic number of data sources, so use a fixed number of
# channels here.Channels.
MAX_CHANNELS=4
# For the following thresholds, your mileage may vary again. These are
# the values for Unitymedia NRW.
# Thresholds for RX Power Level
CRIT_LOWER[15]=-5
WARN_LOWER[15]=-3
WARN_UPPER[15]=5
CRIT_UPPER[15]=10
# Thresholds for TX Power Level
CRIT_LOWER[32]=43
WARN_LOWER[32]=45
WARN_UPPER[32]=47
CRIT_UPPER[32]=50
# Thresholds for RX SNR MSE
CRIT_LOWER[16]=32
WARN_LOWER[16]=34
# Thresholds for Uncorrectable Errors
CRIT_LOWER[19]=10
WARN_LOWER[19]=5
# Optionally log values to a CSV file
CSVOUT="/path/to/fritzbox.csv"
