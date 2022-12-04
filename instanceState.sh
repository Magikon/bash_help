#!/usr/bin/env bash
#--------------------------------------------#
#-------   Developer Mikayel Galyan   -------#
#---   Email: mikayel.galyan@gmail.com   ----#
#--------------------------------------------#
#region=<region>
#profile=<profilename>
state=start # or stop
#name=somename*
######################################################################################################################################################################################
start=`date +%s`
while getopts p:r:n:s:h flag
do
    case "${flag}" in
        p) profile=${OPTARG};;
        r) region=${OPTARG};;
        n) name=${OPTARG};;
        s) state=${OPTARG};;
        h) echo "example: ./`basename "$0"` -r <region> -p <profilename> -s start -n somename*"
           echo "If you write default values in the stript file, you can omit some options."
           echo "example: ./`basename "$0"` -s start -n somename*"
           echo "example: ./`basename "$0"` -s start"
           exit;;
    esac
done

echo "-----------------";
echo "profile: $profile";
echo "region: $region";
echo "name: $name";
echo "state: $state";
echo "-----------------";

echo "Please enter the code from your mfa device"
aws-mfa --profile $profile # If you are using aws-mfa otherwise comment this line
declare -a IDs
for i in $(aws ec2 describe-instances --filters "Name=tag:Name,Values=$name" --region $region --profile $profile --output text --query 'Reservations[*].Instances[*].InstanceId')
do
    IDs+=($i);
    echo $i;
done

echo "Changing your instance state...."
for c in ${!IDs[@]}; do
    case $state in
      stop)
        aws ec2 stop-instances --instance-ids ${IDs[$c]} --region $region --profile $profile;;
      start)
        aws ec2 start-instances --instance-ids ${IDs[$c]} --region $region --profile $profile;;
    esac
done
for c in ${!IDs[@]}; do
   instancename=$(aws ec2 describe-instances --instance-ids ${IDs[$c]} --region $region --profile $profile --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' --output text)
        while :; do
            if [[ $state == "start" ]];then
                temp=$(aws ec2 describe-instance-status --instance-ids ${IDs[$c]} --region $region --profile $profile --query 'InstanceStatuses[*].InstanceStatus[].Status' --output text)
                if [[ $temp == "ok" ]];then echo "instanceId = ${IDs[$c]}, $instancename in working order";break;fi
            elif [[ $state == "stop" ]];then
                temp=$(aws ec2 describe-instances --instance-ids ${IDs[$c]} --region $region --profile $profile --output text --query 'Reservations[*].Instances[*].State[].Name');
                if [[ $temp == "stopped" ]];then echo "instanceId = ${IDs[$c]}, $instancename is shutted down";break;fi
            fi
            echo $instancename $temp;
            sleep 10;
        done
done

echo "Task ended in " $((`date +%s`-start)) "seconds"
