DIR=/u01/app/etc
sharedEnv=$DIR/envshare/env-share.env
privatedEnv=$DIR/config/env.conf
## export env shared 
if [ -f "$sharedEnv" ]; then
        echo "exits file $sharedEnv"
        export $(cat "$sharedEnv")
else
        echo "$sharedEnv not exits"
fi

## export snv private

if [ -f "$privatedEnv" ]; then
        echo "exits file $privatedEnv"
        export $(cat "$privatedEnv")
else
        echo "$privatedEnv not exits"
fi
