#!/bin/bash
eval `qmmp --status | egrep '(playing|TITLE =)' | sed '/playing/ s/^[^0-9]*/SEEK = /g' | sed -e 's/ = /="/g' -e 's/$/"/g'`; 
SEC_ELAPSED=$(echo $SEEK | cut -d '/' -f1 | awk -F ':' '{ print $1*60+$2 }'); 
playdate=$(echo $TITLE | awk -F'_' '{print $1"-"$2"-"$3" "$4":"$5":"$6 }'); 
currentplay=$(echo "${SEC_ELAPSED} +" `date -d "${playdate}" "+%s"` | bc -l | sed 's/^/@/g' | TZ='America/Denver' xargs date -Iseconds -d ); 


echo "SELECT artist || ' - ' || release || ' - ' || song FROM playlist WHERE start<'${currentplay}' and end > '${currentplay}'" | sqlite3 krcl-playlist.sqlite3