#!/bin/bash
while read line
do
echo $line | awk -v q="\"" '{split($0,a,":"); print "useradd -c \""a[5]"\" -u "a[3]" -g "a[4]" -d "a[6]" -s "a[7]" "a[1]}'
done < userlist

