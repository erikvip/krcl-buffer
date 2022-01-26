#!/bin/bash -x
set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

# Cache folder for API requests
_KRCL_BROADCAST_CACHE_DIR="/tmp/krcl_broadcast_cache";
mkdir -p "${_KRCL_BROADCAST_CACHE_DIR}";

export TZ="America/Denver" 
_tmpdata=$(mktemp);



# Shows
_update_shows() {
	echo "Updating show data"
	urls=$(seq -s " " -f  "https://krcl-studio.creek.org/api/shows?page=%0.0f" 1 5)
	#wget -q -O - 'https://krcl-studio.creek.org/api/shows?page=2' \
	wget -q -O - $urls \
 	| jq -r '.data[] | "REPLACE INTO shows (show_id, title, name, updated_at) VALUES ( \(.id), \"\(.title)\", \"\(.name)\", \"\(.updated_at)\"); "' \
 	| sqlite3 db/krcl-playlist-data.sqlite3
}
#_update_shows

log() {
	echo "$@"
}

error() {
	echo "$@"
	exit 1
}

cleanup() {
	rm -f ${_tmpdata}.sql ${_tmpdata}.json;
}

trap cleanup EXIT

######
## Fetch broadcasts from api at https://krcl-studio.creek.org/api/broadcasts?page=...
## $1 date maximum age to fetch. Defaults to 2 weeks
######
#_oldest=$(echo "SELECT IFNULL( max(start), DATETIME('now', '-30 day') ) from broadcasts WHERE start < datetime('now', '-12 hour');" | sqlite3 "db/krcl-playlist-data.sqlite3" );
#t_oldest=$(TZ="America/Denver" date --date="${_oldest}" "+%s");
update_broadcasts() {
	#_arg_maxdate=${1:-"2 weeks ago"};
	_arg_maxdate=${1:-"5 days ago"};
	_ts_maxdate=$(TZ="America/Denver" date --date="${_arg_maxdate}" "+%s");
	_ts_last=$(TZ="America/Denver" date --date="Now" "+%s");
	_pg=0;
	_baseurl="https://krcl-studio.creek.org/api/broadcasts?page=";

	# JQ Query string to format data for sqlite
#	_jq=$(cat <<- END_QUERY
#		.data[] | {
#			"title": ( .show.title + " - " + 
#					(.start|strptime("%Y-%m-%dT%H:%M:%S.000000Z") | strftime("%Y, %b %d"))
#			),
#			"id":.id, "show_id":.show.id, "start":.start,"end":.end
#		} | ( "REPLACE INTO broadcasts (broadcast_id, show_id, start, end, tracks_processed, title, audiourl) "+
#			"VALUES (\(.id), \(.show_id), \(.start|tojson), \(.end|tojson), 0, \(.title|tojson), \(.audio.url|tojson));"
#		)
#END_QUERY
#	);
		
	# Grab each page and process
	while [ "${_ts_last}" -gt "${_ts_maxdate}" ]; do
		_pg=$(( ${_pg}+1 ));
		_url="${_baseurl}${_pg}";

		log "Fetching broadcast page at $_url";
		log "Time to fetch (seconds):" $(( ${_ts_last} - ${_ts_maxdate} ));
	
		wget --user-agent="Firefox" -q -O "${_tmpdata}.json" "${_url}" || error "wget failed";
		
		_ts_last=$(cat "${_tmpdata}.json" | jq '[.data[].start | strptime("%Y-%m-%dT%H:%M:%S.000000Z") | mktime] | min');
		log "Oldest timestamp on page #${_pg}: ${_ts_last}";
		#jq -r "${_jq}" "${_tmpdata}.json" >> "${_tmpdata}.sql"; 
		jq -r -f "update_broadcasts.jq" "${_tmpdata}.json" >> "${_tmpdata}.sql"; 
	done
	log "Updating broadcast data from ${_tmpdata}.sql"; 
	sqlite3 db/krcl-playlist-data.sqlite3 < "${_tmpdata}.sql";
}
#update_broadcasts; 

#exit;


#t_oldest=$(( t_current - 1209600 ))
#while [ $t_current -gt $t_oldest ]; do
#	break;
#	echo "Fetching broadcast page $_LAST_BROADCAST_PG. Current: ${t_current}. Oldest accepted: ${t_oldest}"
#	_START_BROADCAST_PG=$(( ${_LAST_BROADCAST_PG} - 5 ));
#	_START_BROADCAST_PG=1;
#	_LAST_BROADCAST_PG=2;	
	#$(( ${_LAST_BROADCAST_PG} - 5 ));

	#"https://krcl-studio.creek.org/api/broadcasts?page="$_START_BROADCAST_PG.._LAST_BROADCAST_PG}
#	urls=$(seq -s " " -f  "https://krcl-studio.creek.org/api/broadcasts?page=%0.0f" ${_START_BROADCAST_PG} ${_LAST_BROADCAST_PG})
	
	#wget -q -O "${_tmpdata}" $urls
	#_old_broadcast=$(cat "${_tmpdata}" | jq -r '[ .data[] | .start] | min');

	#echo "Oldest broadcast on page ${_LAST_BROADCAST_PG}: ${_old_broadcast}"

	#for u in $urls; do 
		#cat "${_tmpdata}" |
		#wget -q -O - ${u} \
		#	| jq -r '.data[] | "REPLACE INTO broadcasts (broadcast_id, show_id, start, end, title) VALUES(\(.id), \(.show.id), \"\(.start)\", \"\(.end)\", \"\(.show.title) - \(.title)\");"' \
		#	| sqlite3 db/krcl-playlist-data.sqlite3
	#done

#	t_current=$(TZ="America/Denver" date --date="${_old_broadcast}" "+%s");
#	_LAST_BROADCAST_PG=$(( $_LAST_BROADCAST_PG - 1 ));
#done;

######
# Fetch and update songs for a broadcast
# $1 int broadcast_id (Required)
####
fetch_broadcast_songs() {
	[[ $1 == ?(-)+([0-9]) ]] || error "fetch_broadcast_songs: broadcast_id must be numeric"
	_bid="$1";
	log "Fetch song data for broadcast ${_bid}";
	_json="${_KRCL_BROADCAST_CACHE_DIR}/broadcast-${_bid}.json";
	_url="https://krcl.studio.creek.org/api/broadcasts/${_bid}";

	
	if [ -e "${_json}" ]; then
		# Cache file already exists, use it	
		log "Cache hit: broadcast ${_bid} already saved at ${_json}";
	else 
		# Fetch the broadcast data
		log "Cache miss: fetching broadcast data from ${_url}"
		wget --user-agent "Firefox" -q -O "${_json}" "${_url}";
	fi

	jq -r -f update_playlists.jq "$_json" \
		| sed 's/\\"/""/g' \
		| sqlite3 db/krcl-playlist-data.sqlite3

	log "Updated ${_bid}";

	echo "UPDATE broadcasts SET tracks_processed=1 WHERE broadcast_id=${_bid}" \
		| sqlite3 db/krcl-playlist-data.sqlite3
}


########
## Grab track / song data for each broadcast with tracks_processed!=1
###
update_broadcast_songs() {
	_sql=$(cat << END_QUERY
		SELECT broadcast_id FROM broadcasts 
		WHERE 
			DATE(start) < DATE('now', '-12 hour') 
			AND tracks_processed != 1 ORDER BY start DESC
END_QUERY
);
	for _bid in $(echo "${_sql}" | sqlite3 db/krcl-playlist-data.sqlite3); do
		log "Update broadcast songs for broadcast #${_bid}";
		fetch_broadcast_songs "${_bid}";
	done
	#for bid in $(echo "select broadcast_id from broadcasts where DATE(start) < DATE('now') AND broadcast_id not in (select broadcast_id from broadcast_status where processed=1) ORDER BY start DESC;" | sqlite3 db/krcl-playlist-data.sqlite3); do	
}
update_broadcast_songs

exit





# Now fetch track data for broadcasts older than today, which have not yet been processed
echo "Gatering missing track data for updated broadcasts...";
for bid in $(echo "select broadcast_id from broadcasts where DATE(start) < DATE('now') AND broadcast_id not in (select broadcast_id from broadcast_status where processed=1) ORDER BY start DESC;" | sqlite3 db/krcl-playlist-data.sqlite3); do
	echo -n "Fetching track data for broadcast ${bid}..."
	wget -q -O "${_tmpdata}" "https://krcl-studio.creek.org/api/broadcasts/${bid}"
	_showtitle=$(cat "${_tmpdata}" | jq -r '.data.show.title');
	_showname=$(cat "${_tmpdata}" | jq -r '.data.show.name');
	_showid=$(cat "${_tmpdata}" | jq -r '.data.show.id');
	_audiourl=$(cat "${_tmpdata}" | jq -r '.data.audio.url');
	_start=$(cat "${_tmpdata}" | jq -r '.data.start');
	#_audiourl_guess=$(TZ="America/Denver" date --date="${_start}" "+https://krcl-media.s3.us-west-000.backblazeb2.com/audio/${_showname)/${_showname}_%Y-%m-%d_%H-%M-%S.mp3" );
	_audiourl_guess=$(date --date="${_start}" "+https://krcl-media.s3.us-west-000.backblazeb2.com/audio/${_showname}/${_showname}_%Y-%m-%d_%H-%M-%S.mp3" );

	echo "${_showtitle}. MP3 URL: ${_audiourl}";
	if [[ ! $_audiourl =~ ^http ]]; then
		echo "No audiourl found...skipping".
		echo "audiourl GUESS: ${_audiourl_guess}"
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