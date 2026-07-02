#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Add route
if [[ -f "$SCRIPT_DIR/setup_routes.sh" ]]; then
    sudo /bin/bash $SCRIPT_DIR/setup_routes.sh $VIM_NAME
fi

# Add iptables rules
if [[ -f $SCRIPT_DIR/setup_iptables.sh ]]; then
    sudo /bin/bash $SCRIPT_DIR/setup_iptables.sh $VDU_NAME $VIM_NAME $NETWORK_MODE
fi

# Setup applications
if [[ -f $SCRIPT_DIR/setup_applications.sh ]]; then
    sudo /bin/bash $SCRIPT_DIR/setup_applications.sh $VDU_NAME $VIM_NAME $NETWORK_MODE
fi

# setup env share and private
if [[ -f "$SCRIPT_DIR/setup_env.sh" ]]; then
	source $SCRIPT_DIR/setup_env.sh
fi

# Start application
case "$VDU_NAME" in
    kafka)
        start_kafka.sh $@
    ;;
    zookeeper)
        start_zookeeper.sh $@
    ;;
    em)
        /bin/bash /u01/setup/script.sh
    ;;
    fep)
        /bin/bash /u01/setup/script.sh
    ;;
    bep)
        /bin/bash /u01/setup/script.sh
    ;;
    media)
        /bin/bash /u01/setup/script.sh
    ;;
    app)
        sleep 3000
    ;;
    *)
        /bin/bash start.sh
    ;;
esac
