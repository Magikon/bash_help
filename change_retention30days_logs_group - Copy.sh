#!/usr/bin/env bash

list=$(aws logs describe-log-groups | jq -r ".logGroups[].logGroupName")
for i in $list
do
  aws logs put-retention-policy --log-group-name $i --retention-in-days 30
  echo -e "Cange retention to 30days: $i"
done

