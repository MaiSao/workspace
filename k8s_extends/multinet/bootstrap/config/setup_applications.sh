#! /bin/bash
VDU_NAME=$1
echo "Setup application for pod with VDU_NAME: $VDU_NAME"

if [[ -z "$VDU_NAME" ]]; then
    echo "Pod has no env VDU_NAME"
    exit 0
fi

case "$VDU_NAME" in    
    kafka)
        # data
		if [[ -d "/opt/kafka/data-0" ]]; then
			/usr/bin/chown -R ocs:ocs /opt/kafka/data-0
		fi
		
		# logs
		if [[ -d "/opt/kafka/logs" ]]; then
			/usr/bin/chown -R ocs:ocs /opt/kafka/logs
		fi
    ;;
    zookeeper)
        # logs
		if [[ -d "/opt/zookeeper/logs" ]]; then
			/usr/bin/chown -R ocs:ocs /opt/zookeeper/logs
		fi
		
		# data
		if [[ -d "/var/zookeeper/data" ]]; then
			/usr/bin/chown -R ocs:ocs /var/zookeeper/data
		fi
		
		if [[ -d "/var/zookeeper/logs" ]]; then
			/usr/bin/chown -R ocs:ocs /var/zookeeper/logs
		fi
    ;;
    cdr-processor|roaming-offline)
		# logs
		if [[ -d "logs" ]]; then
			/usr/bin/chown -R ocs:ocs logs
		fi
		
        # ../logs
		if [[ -d "../logs" ]]; then
			/usr/bin/chown -R ocs:ocs ../logs
		fi

        # /u01/datacdr
		if [[ -d "/u01/datacdr" ]]; then
			/usr/bin/chown -R ocs:ocs /u01/datacdr
		fi
		
		# /u01/app/datacdr
		if [[ -d "/u01/app/datacdr" ]]; then
			/usr/bin/chown -R ocs:ocs /u01/app/datacdr
		fi
    ;;
    *)
        # Do any things default
        # logs
		if [[ -d "logs" ]]; then
			/usr/bin/chown -R ocs:ocs logs
		fi

        # ../logs
		if [[ -d "../logs" ]]; then
			/usr/bin/chown -R ocs:ocs ../logs
		fi
    ;;
esac
