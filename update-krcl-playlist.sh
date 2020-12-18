#!/bin/bash
wget --user-agent Firefox -q -O - 'https://krcl.org/endpoints/now-playing/' | \
	gunzip | \
	jq -r '.now_playing | "REPLACE INTO playlist (id, start, end, artist, release, song, duration) VALUES( \(.id|@sh), \(.start|@sh), \(.end|@sh), \(.artist|@sh), \(.release|@sh), \(.song|@sh), \(.duration|@sh) ); "  ' | sqlite3 db/krcl-playlist.sqlite3


