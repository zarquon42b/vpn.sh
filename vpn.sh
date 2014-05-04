#!/bin/bash
start=0
SLEEPTIME=15
function usage {
    echo " "
    echo "usage: vpn.sh [-c VPN ][ -s][-t TIME]"
    echo " "
    echo "    -c VPN      optional: string specifying the name of a vpn connection"
    echo "    -s          optional: if VPN is specified, this starts the surveillance immediately"
    echo "    -t TIME     optional: set inteval time (in seconds) to check if VPN is up. Default is 15 seconds."
    echo "    -h -?       print this help"
    echo " "
    
    exit
}

while getopts "c:s?ht:" opt; do
    case "$opt" in
        c)
            VPNNAME=$OPTARG
	    VPNNAME=$(nmcli -t -f NAME,uuid c| grep "$VPNNAME" |cut -d ":" -f1 | head -1)

            ;;
        s)  start=1
            ;;
	?)
	    usage
	    ;;
	h)
	    usage
	    ;;
	t)
	    SLEEPTIME=$OPTARG
	    
    esac
done


## make sure only one instance is running
if [ $(pidof -x vpn.sh | wc -w) -gt 2 ]; then 
    notify-send "already running"
    exit
fi

## get all available vpn connections
allvpn=$(nmcli -t -f TYPE,NAME c | grep vpn | cut -d ":" -f2 | sort | sed 's/^/x\n/g' )

## check if a VPN was given as argument
if [ -z "$VPNNAME" ]; then
    ## check for already active VPN connection
    active=$(nmcli -t -f NAME,VPN con status | grep yes )
    if [ ! -z "$active" ]; then
	IFS=$'\n'
	VPNNAME=$(echo $active | cut -d ":" -f1)
	IFS=' '
	echo $VPNNAME
    fi
fi
function killvpn {
    active=$(nmcli -t -f uuid,VPN con status | grep yes | cut -d ":" -f1)
    if [ ! -z $active ]; then
	nmcli con down uuid $active
    fi
}

function killpid {
    if [ ! -z $vpn_pid ];then
	echo $vpn_pid
	kill $vpn_pid
	wait $vpn_pid 2>/dev/null
	vpn_pid=""
	echo "stopped"
	notify-send "vpn surveillance stopped"
    fi
}
function startvpn {
    IFS=$'\n'
    if [ -z $vpn_pid ];then
	if [ -z "$VPNNAME" ]; then
	    ## check for already active VPN connection
	    active=$(nmcli -t -f NAME,VPN con status | grep yes )
	    if [ ! -z "$active" ]; then
		IFS=$'\n'
		VPNNAME=$(echo $active | cut -d ":" -f1)
		IFS=' '
		echo $VPNNAME
	    fi
	fi
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
}
function showstatus {
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
}
function pingfun {
    ping -q -w 1 -c 1 8.8.8.8 > /dev/null && return 0 || return 1
}
nice=0
#### here comes the main function
function vpn {
    VPNNAME=$(nmcli -t -f NAME,uuid c| grep $1 |cut -d ":" -f2 | head -1)
    if [ ! -z $VPNNAME ];then
	#$1 #netherlands
	# enter desired time between checks here (in seconds)
	
	
	while :
	do
	    upwww=$(pingfun)
	    ## check if network is up
	    if ( $upwww ); then    
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


if [[ $start == 1 ]]; then
    startvpn
    #vpn surveillance started"
fi

## start appindicator
(cat <<EOF
Start
Stop
Change VPN
Exit VPN
Status
EOF
) | PREFIX/vpnind.py --persist -i vpn.sh | while read s; do
    case "$s" in 
	Start)
	    startvpn
	    ;;
	Stop)
	    killpid
	    ;;
	Status)
	    showstatus
	    ;;
	
	"Change VPN")
	    IFS=$'\n'
	    VPNNAME=$(zenity --list --height 400 --radiolist --text "Select VPN" --column Select --column VPN $allvpn)
	    if [ ! -z "$VPNNAME" ]; then
		killpid
		echo "stopped"
		killvpn
		vpn $VPNNAME &
		vpn_pid=$!
		notify-send "trying to start surveillance for VPN $VPNNAME"
		#notify-send "vpn surveillance stopped"

	    else
		notify-send "Nothing selected."
	    fi
	    
	    
	    #VPNNAME=$(zenity --entry --text "VPNNAME" --entry-text "Toronto"); 
	    
	    #echo "$vpn_pid"
	    
	    IFS=' '
	    #IFS=' '
	    #fi
	    ;;
	"Exit VPN")
	    killpid
	    killvpn
	    ;;
    esac
done

