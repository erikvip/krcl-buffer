#!/bin/bash
_songindex="NULL";
_streamfile="NULL";

if [[ "$1" =~ ^[0-9]+ ]]; then
	_songindex="${1}";
	if [[ "$2" =~ [0-9\_]+ ]]; then
		_streamfile="'${2}'";
	fi
fi


wget --user-agent Firefox -q -O - 'https://krcl.org/endpoints/now-playing/' | \
	gunzip | \
	jq -r "\"REPLACE INTO playlist (id, start, end, artist, release, song, duration, showtitle, songindex, streamfile) VALUES( \(.now_playing.id|@sh), \(.now_playing.start|@sh), \(.now_playing.end|@sh), \(.now_playing.artist|@sh), \(.now_playing.release|@sh), \(.now_playing.song|@sh), \(.now_playing.duration|@sh), \(.on_air_now.title|@sh), ${_songindex}, ${_streamfile} ); \" " | \
	sed "s#'\\\''#''#g" | \
	sqlite3 db/krcl-playlist.sqlite3


_showtitle=$(echo "SELECT showtitle FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex} LIMIT 1;" | sqlite3 db/krcl-playlist.sqlite3);
_res=$(echo "REPLACE INTO shows (showtitle) VALUES('${_showtitle}');" | sqlite3 db/krcl-playlist.sqlite3);

# The second to last sed line there converts shell escaping to Sqlite escaping...



