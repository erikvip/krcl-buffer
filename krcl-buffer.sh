#!/bin/bash -ue

default_sleep_timer=60; 
sleep_timer=$default_sleep_timer; 
max_timer=600; 

if [[ ! `pgrep streamripper` ]]; then
	streamripper 'http://stream.xmission.com/krcl-high' -A -a 'data/%d.mp3' 2>&1 >> data/streamripper.log &
fi

while [ true ]; do
	./update-krcl-playlist.sh;
	song_end=$(sqlite3 db/krcl-playlist.sqlite3 'select end from playlist order by start desc limit 1' );
	song_end_ts=$(date -d "${song_end}" "+%s");
#	./now-playing.sh
	now_ts=$(date "+%s");
#	echo "$song_end_ts - $now_ts";
	sleep_timer=$(( $song_end_ts - $now_ts ));

	./now-playing.sh
	echo "Interval: ${sleep_timer}";

	if [ $sleep_timer -lt 1 -o $sleep_timer -gt $max_timer ]; then
		sleep_timer=$default_sleep_timer;
	fi

	echo "Sleeping for ${sleep_timer} seconds...";

	sleep $sleep_timer;
done;
	

