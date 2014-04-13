#!/bin/bash
echo $2 $1
if [ "$1" == "--help" ];then
    echo " "
    echo "usage: vpn.sh [VPN] [start]"
    echo " "
    echo "    VPN      optional: string specifying the name of a vpn connection"
    echo "    start    optional: if VPN is specified, this starts the surveillance immediately"
    echo " "
    
    exit
fi

## make sure only one instance is running
if [ $(pidof -x vpn.sh | wc -w) -gt 2 ]; then 
    notify-send "already running"
    exit
fi

## get all available vpn connections
allvpn=$(nmcli -t -f TYPE,NAME c | grep vpn | cut -d ":" -f2 | sort | sed 's/^/x\n/g' )

## check if a VPN was given as argument
if [ ! -z "$1" ]; then
    VPNNAME="$1"
else
    ## check for already active VPN connection
    active=$(nmcli -t -f NAME,VPN con status | grep yes )
    if [ ! -z "$active" ]; then
	IFS=$'\n'
	VPNNAME=$(echo $active | cut -d ":" -f1)
	IFS=' '
    fi
fi


nice=0
#### here comes the main function
function vpn {
    VPNNAME=$(nmcli -t -f NAME,uuid c| grep $1 |cut -d ":" -f2 | head -1)
    if [ ! -z $VPNNAME ];then
	#$1 #netherlands
	# enter desired time between checks here (in seconds)
	SLEEPTIME=15
	
	while (( 1 == 1)); do
	    upwww=$(nmcli -f STATE con status | grep activated)
	    ## check if network is up
	    if [[ "$upwww" == *activated* ]]; then    
		echo "network is up"
		tested=$(nmcli con status uuid $VPNNAME | grep -c UUID)
		
		#possible results:
		# 0 - no connection - need to start
		# 1 - working connection, continue.

		case $tested in
		    "0")
			echo "Not connected - starting"

			#increase nice counter
			nice=$[nice+1]

			#if "nice start" fails for 3 times
			if [ $nice -ge 3 ];
			then
			    #TRY to knock hard way, resetting the network-manager (sometimes it happens in my kubuntu 12.04).
			    echo "HARD RESTART!"
			    nmcli nm enable false
			    nmcli nm enable true
			    sleep 5
			    nmcli con up uuid $VPNNAME
			    nice=0
			else
			    #not yet 3 falures - try starting normal way
			    echo "trying to enable."
			    nmcli con up uuid $VPNNAME
			fi
			;;

		    "1")
			echo "VPN seems to work"

			;;
		esac
	    else
		echo "network is down"
	    fi
	    sleep $SLEEPTIME
	    
	done
    else 
	notify-send "Error: unknown VPN"
    fi
}


if [[ $2 == "start" ]]; then
    IFS=$'\n'    
    vpn "$VPNNAME" &
    vpn_pid=$!
    IFS=' '
    #notify-send "vpn surveillance started"
fi

## start appindicator
(cat <<EOF
start
stop
change VPN
exit VPN
status
EOF
) | PREFIX/vpnind.py --persist -i gnome-eyes-applet | while read s; do
    case "$s" in 
	start)
	    IFS=$'\n'
	    if [ -z $vpn_pid ];then
		if [ -z "$VPNNAME" ]; then
		    
		    VPNNAME=$(zenity --list --height 400 --radiolist --text "Please select VPN first" --column Select --column VPN $allvpn)
		    
		fi
		if [ -z "$VPNNAME" ]; then
		    notify-send "no VPN selected"
		else
		    vpn $VPNNAME &
		    vpn_pid=$!
		    echo "$vpn_pid"
		    notify-send "vpn surveillance started for $VPNNAME"
		    
		fi
		
	    else
		notify-send "already running $VPNNAME"
	    fi
	    IFS=' '
	    
	    ;;
	stop)
	    if [ ! -z $vpn_pid ];then
		echo $vpn_pid
		kill $vpn_pid
		wait $vpn_pid 2>/dev/null
		vpn_pid=""
		echo "stopped"
		notify-send "vpn surveillance stopped"
		
	    fi
	    ;;
	status)
	    if [ ! -z $vpn_pid ];then
		notify-send "VPN surveillance is active. Current VPN is $VPNNAME"
		nocon=""
	    else
		active=$(nmcli -t -f uuid,VPN con status | grep yes | cut -d ":" -f1)
	    if [ -z $active ]; then
		nocon=". No VPN connection active."
	    fi
	    if [ -z "$VPNNAME" ];then
		nameinfo=" No VPN selected"
	    else
		nameinfo= Current VPN is $VPNNAME
	    fi
		notify-send "VPN surveillance is inactive.$nameinfo $nocon"
	    fi
	    ;;
	
	"change VPN")
	    IFS=$'\n'
	    VPNNAME=$(zenity --list --height 400 --radiolist --text "Select VPN" --column Select --column VPN $allvpn)
	    if [ ! -z "$VPNNAME" ]; then
		if [ ! -z $vpn_pid ];then
		    echo $vpn_pid
		    kill $vpn_pid
		    wait $vpn_pid 2>/dev/null
		    vpn_pid=""
		    echo "stopped"
		    #notify-send "vpn surveillance stopped"
		fi
		
		#VPNNAME=$(zenity --list --radiolist --column "Please select VPN" $allvpn)
		
		active=$(nmcli -t -f uuid,VPN con status | grep yes | cut -d ":" -f1)
		
		if [ ! -z $active ]; then
		    nmcli con down uuid $active	
		fi
		#VPNNAME=$(zenity --entry --text "VPNNAME" --entry-text "Toronto"); 
		vpn $VPNNAME &
		vpn_pid=$!
		echo "$vpn_pid"
		notify-send "trying to start surveillance for VPN $VPNNAME"
		IFS=' '
	    else
		IFS=' '
	    fi
	    ;;
	"exit VPN")
	    if [ ! -z $vpn_pid ];then
		echo $vpn_pid
		kill $vpn_pid
		wait $vpn_pid 2>/dev/null
		vpn_pid=""
	    fi
	    active=$(nmcli -t -f uuid,VPN con status | grep yes | cut -d ":" -f1)
	    if [ ! -z $active ]; then
		nmcli con down uuid $active
	    fi
	    ;;
    esac
done

