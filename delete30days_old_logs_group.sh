#!/usr/bin/env bash
# delete log groups with dev word
list=$(aws logs describe-log-groups | jq -r ".logGroups[].logGroupName" | grep dev)
#echo ${list[@]}
for i in $list
do
  #echo $i
  timestmp=$(aws logs describe-log-streams --query "logStreams[*].lastEventTimestamp" --log-group $i | jq "max/1000|floor")
  item=@$timestmp
  itemdate=$(date -d $item)
  #echo -e "LogGroupName: $i \t\t-->\tDate: $itemdate"
  timeago='30 days ago'
  check=$(date --date "$timeago" +'%s')
  if [ $timestmp -lt $check ]
  then
    echo -e "Deleteing:\t $i \t\t\t --> $itemdate"
    aws logs delete-log-group --log-group-name $i
  fi
done
