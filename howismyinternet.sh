#!/bin/bash

#title           :howismyconnection.sh
#description     :Network connectivity monitoring.
#author		 	 :Alexandre Gomes (alegomes at gmail), for personal purposes.
#date            :2020-05-26
#version         :0.1 
#usage		 	 :bash howismyconnection.sh
#notes           :Requires sudo privileges
#                :You can install it as a daemon using install_as_a_daemon.sh
#tested on       :macOS Catalina v10.15.4 - Darwin Kernel Version 19.4.0
#depedencies     :https://github.com/sivel/speedtest-cli
#==============================================================================

# General params

HEADER_IN=60
INTERVAL=600 #secs

INTERNAL="192.168.0.1"
EXTERNAL="8.8.8.8"

GOOGLE="8.8.8.8"
FACEBOOK="2804:14d:1:0:181:213:132:2"


# Colors (not really used, yet)
# https://misc.flogisoft.com/bash/tip_colors_and_formatting

NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

# Format

BOLD='\e[1m'
NOBOLD='\e[21m'
DIM='\e[2m'
NODIM='\e[22m'
UNDERLINE='\e[4m'
NOUNDERLINE='\e[24m'
BLINK='\e[5m'
NOBLINK='\e[25m'
INVERT='\e[7m'
NOINVERT='\e[27m'
HIDDEN='\e[8m'
NOHIDDEN='\e[28m'


LOGS=("/tmp/ping_internal_v4" \
		 "/tmp/ping_external_v4" \
		 "/tmp/ping_internal_v6" \
		 "/tmp/ping_external_v6" )

CMDS=("ping"
	  "ping"
	  "ping6"
	  "ping6")

trap exit SIGINT

function exit {
	echo "Exiting...."
	# set -e 
	# exit 1
	kill -s TERM $$
}

function write_on_console {
	HEADER=$1
	RESULT=$2
	LINE_NUMBER=$3

	FORMAT="%-16s %-16s %-15s %-15s %-15s %-29.29s %-29.29s %-29.29s %9s %9s %9s %9s %7s %8s %6s %4s %5s %11s %9s %3s %7s\n"

	IFS=";"
	read -ra HEADERS <<< "$HEADER"
	read -ra VALUES <<< "$RESULT"

	let NO_HEADER=$LINE_NUMBER%$HEADER_IN # NO_HEADER = 0 if LINE_NUMBER = 0 or any multiple of HEADER_IN
	if (( ! $NO_HEADER )); # 0 = false; != 0 is true
	then
		printf "$FORMAT" ${HEADERS[@]}
	fi

	printf "$FORMAT" ${VALUES[@]}

	unset IFS
}

function write_on_logfile {
	HEADER=$1
	RESULT=$2

	if [ ! -f $LOG_FILE ]; then
		echo $HEADER > $LOG_FILE
	fi

	echo $RESULT >> $LOG_FILE

}

function main {

	local LINE_NUMBER=0
	
	HEADER="Timestamp;WiFi;RouterV4;LocalIPv4;ExternalIPv4;RouterV6;LocalIpv6;ExteralIPv6;IntLossV4;ExtLossV4;IntLossV6;ExtLossV6;Ping;Download;Upload;RSSI;Noise;WifiMaxRate;MyMaxRate;MCS;Channel"

	while (true); do

		LOG_FILE="/var/log/${0##*/}-$(date +%Y%m%d).log"

		TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
		WIFI=$(networksetup -getairportnetwork en0 | pcregrep -o1 'Current Wi-Fi Network: (.*)')
		
		LAN4=$(ipconfig getifaddr en0)
		LAN6=$(ifconfig en0 inet6 | grep inet6 | grep en0 | awk '{print $2}' | cut -d% -f1)

		if [ -z $LAN4 ]; then LAN4='Unk'; fi
		if [ -z $LAN6 ]; then LAN6='Unk'; fi	

		WAN4=$(curl -s ifconfig.me)
		WAN6=$(curl -s http://ip6only.me/api/ | cut -d "," -f 2)

		if [ -z $WAN4 ]; then WAN4='Unk'; fi
		if [ -z $WAN6 ]; then WAN6='Unk'; fi	

		ROUTER4=$(ipconfig getoption en0 router)
		ROUTER6=$(ipconfig getv6packet en0 | pcregrep -o1 'IAADDR (.{0,4}:.{0,4}:.{0,4}:.{0,4}:.{0,4}:.{0,4})')

		if [ -z $ROUTER4 ]; then ROUTER4='Unk'; fi
		if [ -z $ROUTER6 ]; then ROUTER6='Unk'; fi	

		RESULT="$TIMESTAMP;$WIFI;$ROUTER4;$LAN4;$WAN4;$ROUTER6;$LAN6;$WAN6"

		SERVERS=($ROUTER4 $GOOGLE $ROUTER6 $FACEBOOK)

		for i in "${!SERVERS[@]}"; 
		do 
			${CMDS[i]} -c 10 ${SERVERS[i]} &> ${LOGS[i]}

			LOSS=$(cat ${LOGS[i]} | grep "packet loss" | pcregrep -o1 '(\d+\.\d+%) packet loss')

			# if [ $LOSS != '0.0%' ]; 
			# then
			# 	LOSS=$(echo -e "$RED${LOSS}$NOCOLOR")
			# fi

			if [ -z $LOSS ]; then
				x=$(wc -l ${LOGS[i]} | xargs -n 1 | head -1)
				y=$(grep "No route to host" ${LOGS[i]})

				if [ $x -eq 1 ] && [ ! -z "$y" ]; 
				then
					LOSS='NoRoute'
				else
					LOSS='Unk'
				fi
			fi

			RESULT="${RESULT};$LOSS"

		done

		if [ -z '$(which speedtest)' ]; 
		then
			echo "[ERROR] speedtest-cli not installed."
			echo "Available at https://github.com/sivel/speedtest-cli"
			exit 255
		fi

		# Speedtest

		PING='--'
		DWN='--'
		UP='--'

		if [ "$WAN4" != 'Unk' ];
		then
			speedtest --simple &> /tmp/speedtest 
			if [ -z "$(grep 'timed out' /tmp/speedtest)" ];
			then
				PING=$(cat /tmp/speedtest | grep -i ping | cut -d ' ' -f 2)
				PING=$(echo $PING | xargs printf "%1.3f") #29.3 -> 29.300
				DWN=$(cat /tmp/speedtest | grep -i download | cut -d ' ' -f 2)
				UP=$(cat /tmp/speedtest | grep -i upload | cut -d ' ' -f 2)
			fi
		fi

		RESULT="${RESULT};${PING%ms};${DWN%Mbit/s};${UP%Mbit/s}"

		# Wi-Fi Stats

		/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport en0 -I > /tmp/airport
		RSSI=$(cat /tmp/airport | grep agrCtlRSSI | awk '{print $2}')
		NOISE=$(cat /tmp/airport | grep agrCtlNoise | awk '{print $2}')
		LAST_RATE=$(cat /tmp/airport | grep lastTxRate | awk '{print $2}')
		MAX_RATE=$(cat /tmp/airport | grep maxRate | awk '{print $2}')
		MCS=$(cat /tmp/airport | grep MCS | awk '{print $2}')
		CHANNEL=$(cat /tmp/airport | grep channel | awk '{print $2}')

		RESULT="${RESULT};${RSSI};${NOISE};${LAST_RATE};${MAX_RATE};${MCS};${CHANNEL}"

		# Output results

		write_on_console "$HEADER" "$RESULT" $LINE_NUMBER
		write_on_logfile "$HEADER" "$RESULT" 


		(( LINE_NUMBER++ ))

		sleep $INTERVAL
	done
}

main 

# Refs de comandos
# sysctl net.inte6 | grep temp
# ndp -a
# dig AAAA www.facebook.com 
# scutil --dns | grep nameserver | grep "::"
# traceroute6 www.facebook.com
# ping6 ::1
# netstat -s -f inet6
# netstat -r -f inet6
# ifconfig -L en0 inet6
# ifconfig -a
# arp -a
# nslookup -> server
#
# cd ~/Library/LaunchAgents
# launchctl stop my.shim.catalina.captivenetworkassistant
# launchctl unload my.shim.catalina.captivenetworkassistant.plist
# rm my.shim.catalina.captivenetworkassistant.plist

# /private/var/db/dhcpclient/leases/en0-1,f0:18:98:18:cf:cd
# https://unix.stackexchange.com/questions/396223/bash-shell-script-output-alignment/396224
# https://medium.com/@fahimhossain_16989/adding-startup-scripts-to-launch-daemon-on-mac-os-x-sierra-10-12-6-7e0318c74de1
