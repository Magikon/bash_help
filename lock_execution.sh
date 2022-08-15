#!/usr/bin/env bash
cleenup(){
        rm -f "$lockfile"
}

trap cleenup SIGHUP SIGTRAP SIGKILL SIGABRT ERR EXIT

lockfile="$(pwd)/$(echo $0 | cut -d'/' -f2).lock"
while :
do
        sleep 1
        if [ -f "$lockfile" ];then
                echo "Script execution delayed"
        else
                touch "$lockfile"
                echo "The script starts to run"
                sleep 30
                echo "Script completed"
                break
        fi
done

