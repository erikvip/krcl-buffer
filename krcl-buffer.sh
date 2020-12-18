#!/bin/bash -ue

# Since this all happens in Salt Lake, keep everything on Mountain time for consistency.
TZ="America/Denver";

default_sleep_timer=60; 
sleep_timer=$default_sleep_timer; 
max_timer=600; 
startup_date="";
streamripper_date="";
song_index=0;

setup() {
	startup_date=$(TZ="America/Denver" date '+%Y%m%d');
	song_index=0;

	if [[ ! `pgrep --full 'streamripper.*krcl-high'` ]]; then
		# Try to guess the streamripper file...
		streamripper_date=$(TZ="America/Denver" date '+%Y_%m_%d_%H_%M_%S');
#		TZ="America/Denver" streamripper 'http://stream.xmission.com/krcl-high' -A -a 'data/new/%d.mp3' 2>&1 >> data/streamripper.log &
		TZ="America/Denver" streamripper 'http://stream.xmission.com/krcl-high' -A -a "data/new/${streamripper_date}.mp3" 2>&1 >> data/streamripper.log &
	fi
}

main() { 
	last_song_end="";
	echo "Streamripper filename: ${streamripper_date}";
	while [ true ]; do
		./update-krcl-playlist.sh ${song_index} ${streamripper_date};
		song_end=$(TZ="America/Denver" sqlite3 db/krcl-playlist.sqlite3 'select end from playlist order by start desc limit 1' );
		song_end_ts=$(TZ="America/Denver" date -d "${song_end}" "+%s");
		now_ts=$(TZ="America/Denver" date "+%s");
		sleep_timer=$(( $song_end_ts - $now_ts ));

		if [[ "${last_song_end}" == "" ]]; then
			last_song_end="${song_end}"; 
		fi;

		if [[ "${song_end}" != "${last_song_end}" ]]; then
			song_index=$(( $song_index + 1 ));
			last_song_end="${song_end}";
		fi

		./now-playing.sh
#		echo "Interval: ${sleep_timer}";

		if [ $sleep_timer -lt 1 -o $sleep_timer -gt $max_timer ]; then
			sleep_timer=$default_sleep_timer;
		fi

#		echo "Sleeping for ${sleep_timer} seconds...";
#		sleep $sleep_timer;
		sleepdisplay $sleep_timer;

		now=$(TZ="America/Denver" date '+%Y%m%d');
		if [[ "${startup_date}" != "${now}" ]]; then
			# We've crossed into a new day...restart stream ripper and restart loop...
			break;
		fi
	done;

	finish
	startup
	main
}


sleepdisplay() {
	_timeout=$1;
	_remaining=$_timeout;

	while [ $_remaining -gt 0 ]; do
		echo -ne "\rSleeping for $_remaining seconds...";
		_remaining=$(( $_remaining - 1 ));
		sleep 1
		echo -ne "\033[2K\r"
	done
}

finish() {
	kill_streamripper
}

kill_streamripper() {

	while [[ `pgrep --full "streamripper.*krcl-high"` ]]; do
		pkill --full "streamripper.*krcl-high";
		sleep 2
	done;
}


trap finish EXIT

setup
main
	
