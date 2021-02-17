#!/bin/bash 
set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

export TZ="America/Denver" 


# Shows
echo "Updating show data"
wget -q -O - 'https://krcl-studio.creek.org/api/shows' \
 | jq -r '.data[] | "REPLACE INTO shows (show_id, title, name, updated_at) VALUES ( \(.id), \"\(.title)\", \"\(.name)\", \"\(.updated_at)\"); "' \
 | sqlite3 db/krcl-playlist-data.sqlite3


# Broadcasts...only for last week
echo "Updating broadcast data"
# First figure out the last page and start there...
_LAST_BROADCAST_PG=$(wget -q -O - 'https://krcl-studio.creek.org/api/broadcasts' | jq -r '.meta .last_page');

_tmpdata=$(mktemp);
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











