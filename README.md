vpn.sh
======


a simple bash/python script for conventiently selecting and checking VPN connections on Linux

**Dependencies:**
on Debian/ubuntu you will need the following packages to be installed:
		
	python-appindicator network-manager zenity 


**Install:**

As admin:

	sudo ./install.sh /usr/bin ##or any prefix you like
	
	
As non-root:

	./install.sh /some_path #make sure that some_path is included in your environment's PATH variable
