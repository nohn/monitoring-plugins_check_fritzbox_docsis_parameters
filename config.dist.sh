#!/usr/bin/env bash
HOST="fritz.box"
USER="user"
PASS="password"
# Debug Mode
DEBUG=false
# Your Mileage may vary. Fritzbox 6360 has 4 Channels. RRDTools sucks
# with dynamic number of data sources, so use a fixed number of
# channels here.
MAX_CHANNELS=4
# Thresholds for Uncorrectable Errors
CRIT_LOWER[19]=10
WARN_LOWER[19]=5
# Optionally log values to a CSV file
# CSVOUT="/path/to/fritzbox.csv"
