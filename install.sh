#! /bin/bash

if [ -z $1 ];then
    echo "usage:     install.sh path_to_install"
    exit
else
    PREFIX=$1
fi

cp -p vpn.sh vpn.sh.tmp
cp -p vpn.sh.desktop vpn.sh.desktop.tmp
chmod +x vpn.sh
chmod +x vpnind.py

sed -i 's|PREFIX|'$PREFIX'|g' vpn.sh
sed -i 's|PREFIX|'$PREFIX'|g' vpn.sh.desktop
#PREFIX="aa"
allvpn=$(nmcli -t -f TYPE,NAME c | grep vpn | cut -d ":" -f2 | sort )
IFS=$'\n'
actionstring="Actions="
for i in $allvpn; do
    tmp=$(echo $i | tr -cd '[[:alnum:]]._-')
    actionstring="$actionstring$tmp;"
done
echo "$actionstring" >> vpn.sh.desktop
    
for i in $allvpn; do
    tmp=$(echo $i | tr -cd '[[:alnum:]]._-')
    echo "[Desktop Action $tmp]
Name=$i
Exec=vpn.sh -c \"$i\" -s
#OnlyShowIn=Unity;" >> vpn.sh.desktop
#vpn.sh.desktop
done
IFS=' '
    
if [[ $EUID -ne 0 ]]; then
    cp vpn.sh.desktop $HOME/.local/share/applications
else
    cp vpn.sh.desktop /usr/share/applications/
fi

cp vpn.sh $PREFIX
cp vpnind.py $PREFIX 

##revert temp changes

mv vpn.sh.tmp vpn.sh
mv vpn.sh.desktop.tmp vpn.sh.desktop
