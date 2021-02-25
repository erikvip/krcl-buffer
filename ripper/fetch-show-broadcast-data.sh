#!/bin/bash
set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

export TZ="America/Denver" 
_tmpdata=$(mktemp);

cleanup() {
	rm -r "${_tmpdata}"
}

trap cleanup EXIT


# Shows
echo "Updating show data"
wget -q -O - 'https://krcl-studio.creek.org/api/shows' \
 | jq -r '.data[] | "REPLACE INTO shows (show_id, title, name, updated_at) VALUES ( \(.id), \"\(.title)\", \"\(.name)\", \"\(.updated_at)\"); "' \
 | sqlite3 db/krcl-playlist-data.sqlite3


# Broadcasts...only for last week
echo "Updating broadcast data"
# First figure out the last page and start there...
_LAST_BROADCAST_PG=$(wget -q -O - 'https://krcl-studio.creek.org/api/broadcasts' | jq -r '.meta .last_page');

_oldest=$(echo "SELECT IFNULL( max(start), DATETIME('now', '-8 day') ) from broadcasts WHERE start < datetime('now', '-1 day');" | sqlite3 "db/krcl-playlist-data.sqlite3" );
t_current=$(TZ="America/Denver" date --date="now" "+%s");

_oldest=$(echo "SELECT IFNULL( max(start), DATETIME('now', '-8 day') ) from broadcasts WHERE start < datetime('now', '-1 day');" | sqlite3 "db/krcl-playlist-data.sqlite3" );

t_oldest=$(TZ="America/Denver" date --date="${_oldest}" "+%s");
while [ $t_current -gt $t_oldest ]; do
	echo "Fetching broadcast page $_LAST_BROADCAST_PG. Current: ${t_current}. Oldest accepted: ${t_oldest}"

	wget -q -O "${_tmpdata}" "https://krcl-studio.creek.org/api/broadcasts?page=${_LAST_BROADCAST_PG}"
	_old_broadcast=$(cat "${_tmpdata}" | jq -r '[ .data[] | .start] | min');

	echo "Oldest broadcast on page ${_LAST_BROADCAST_PG}: ${_old_broadcast}"


	cat "${_tmpdata}" | jq -r '.data[] | "REPLACE INTO broadcasts (broadcast_id, show_id, start, end, title) VALUES(\(.id), \(.show.id), \"\(.start)\", \"\(.end)\", \"\(.show.title) - \(.title)\");"' \
		| sqlite3 db/krcl-playlist-data.sqlite3

	t_current=$(TZ="America/Denver" date --date="${_old_broadcast}" "+%s");
	

	_LAST_BROADCAST_PG=$(( $_LAST_BROADCAST_PG - 1 ));
done;


# Now fetch track data for broadcasts older than today, which have not yet been processed
echo "Gatering missing track data for updated broadcasts...";
for bid in $(echo "select broadcast_id from broadcasts where DATE(start) < DATE('now') AND broadcast_id not in (select broadcast_id from broadcast_status where processed=1);" | sqlite3 db/krcl-playlist-data.sqlite3); do
	echo -n "Fetching track data for broadcast ${bid}...";
	wget -q -O "${_tmpdata}" "https://krcl-studio.creek.org/api/broadcasts/${bid}"
	_showtitle=$(cat "${_tmpdata}" | jq -r '.data.show.title');
	_showid=$(cat "${_tmpdata}" | jq -r '.data.show.id');
	_audiourl=$(cat "${_tmpdata}" | jq -r '.data.audio.url');

	echo "${_showtitle}. MP3 URL: ${_audiourl}";
	if [[ ! $_audiourl =~ ^http ]]; then
		echo "No audiourl found...skipping".
		continue;
	fi

	cat "${_tmpdata}" | jq -r '.data.tracks[] | "REPLACE INTO tracks (track_id, broadcast_id, show_id, start, end) VALUES(\(.id), '${bid}', '${_showid}', \"\(.start)\", \"\(.end)\");"' \
		| sqlite3 db/krcl-playlist-data.sqlite3

	echo 'REPLACE INTO broadcast_status (broadcast_id, processed, audiourl) VALUES('${bid}', 1, "'${_audiourl}'");' \
		| sqlite3 db/krcl-playlist-data.sqlite3		
done	


echo "Gathering song data from playlist parser";
for d in $(echo "select DISTINCT date(start) from tracks where track_id not in (select track_id from songs) AND DATE(start) != DATE('now');" | sqlite3 db/krcl-playlist-data.sqlite3); do
	echo "Fetching playlist for ${d}";
	./get-playlist.sh "$d"
done