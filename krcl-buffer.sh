#!/bin/bash -uex

# Since this all happens in Salt Lake, keep everything on Mountain time for consistency.
TZ="America/Denver";


default_sleep_timer=60; 
sleep_timer=$default_sleep_timer; 
max_timer=600; 


setup() {
	if [[ ! `pgrep streamripper` ]]; then
		#TZ="America/Denver" streamripper 'http://stream.xmission.com/krcl-high' -A -a 'data/%d.mp3' 2>&1 >> data/streamripper.log &
		streamripper 'http://stream.xmission.com/krcl-high' -A -a 'data/%d.mp3' 2>&1 >> data/streamripper.log &
	fi
}

main() { 
	while [ true ]; do
		./update-krcl-playlist.sh;
		song_end=$(TZ="America/Denver" sqlite3 db/krcl-playlist.sqlite3 'select end from playlist order by start desc limit 1' );
		song_end_ts=$(TZ="America/Denver" date -d "${song_end}" "+%s");
		now_ts=$(TZ="America/Denver" date "+%s");
		sleep_timer=$(( $song_end_ts - $now_ts ));

		./now-playing.sh
#		echo "Interval: ${sleep_timer}";

		if [ $sleep_timer -lt 1 -o $sleep_timer -gt $max_timer ]; then
			sleep_timer=$default_sleep_timer;
		fi

#		echo "Sleeping for ${sleep_timer} seconds...";
#		sleep $sleep_timer;
		sleepdisplay $sleep_timer;

	done;
}


sleepdisplay() {
	_timeout=$1;
	_remaining=$_timeout;

	while [ $_remaining -gt 0 ]; do
		echo -ne "\rSleeping for $_remaining seconds...";
		_remaining=$(( $_remaining - 1 ));
		sleep 1
		echo -ne "\033[2K"
	done
	
	

}


setup
main
	

