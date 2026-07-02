#! /bin/bash
VIM_NAME=$1
echo "Setup route for pod in VIM: $VIM_NAME"

if [[ -z "$VIM_NAME" ]]; then
	echo "Pod has no env VIM_NAME"
	exit 0
fi

case "$VIM_NAME" in
	VIM_K8S_SITE_1)
		
		#Add route by interface
		if ls /sys/class/net/app-net 1> /dev/null 2>&1; then
			#add app-net to site02
			ip route add 68.240.37.0/28 via 68.240.39.78
		fi
		if  ls /sys/class/net/db-net 1> /dev/null 2>&1; then
			#add route to db linksite site02
			ip route add 68.240.37.80/28 via 68.240.39.94
		fi
	;;
	VIM_K8S_SITE_2)
		#Add route by interface
		if ls /sys/class/net/app-net 1> /dev/null 2>&1; then
			#add app-net to site01
			ip route add 68.240.39.64/28 via 68.240.37.14
		fi
		if  ls /sys/class/net/db-net 1> /dev/null 2>&1; then
			#add route to db linksite site01
			ip route add 68.240.39.80/28 via 68.240.37.94
		fi
	;;
esac
