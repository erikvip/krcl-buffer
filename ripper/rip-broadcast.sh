#!/bin/bash 
set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

export TZ="America/Denver" 




QUERY=${1:-}; 
RIPDATE=${2:-}; 
BROADCAST_ID=NULL;
SHOW_NAME=NULL;
OUTPUT_DIR="../music/";

setup() {
	# Can use either broadcast id or the show name
	if [[ "$QUERY" =~ ^[0-9]+ ]]; then
		BROADCAST_ID="${QUERY}"
		
	elif [[ "$QUERY" =~ ^[a-z\-] ]]; then
		SHOW_NAME="${QUERY}";
		_res=$(echo "SELECT broadcast_id FROM broadcasts WHERE show_id = ( SELECT show_id FROM shows WHERE name=\"${SHOW_NAME}\" ;" \
			| sqlite3 db/krcl-playlist-data.sqlite3);
		BROADCAST_ID="${_res}";
	else
		echo "Must supply broadcast_id or show short name"
		exit 1
	fi

	main

}

main() {

	#_sql="SELECT b.start, b.end, b.title \
	#	FROM broadcasts b WHERE broadcast_id=${BROADCAST_ID}";

	#_sql="SELECT \
	_sql="SELECT \
t.track_id,
b.title,
t.start,
s.artist, \
s.title, \
strftime('%s', t.start) - strftime('%s', datetime(b.start, '-7 hour')) AS position, \
s.duration,
sh.name,
bs.audiourl
FROM shows sh \
INNER JOIN broadcasts b USING (show_id) \
INNER JOIN broadcast_status bs USING (broadcast_id) \
INNER JOIN tracks t USING (broadcast_id) \
INNER JOIN songs s USING (track_id) \
WHERE b.broadcast_id=${BROADCAST_ID}
ORDER BY t.start
"
	_res=$(echo "${_sql}" | sqlite3 -newline $'\r\n' db/krcl-playlist-data.sqlite3);
	if [[ -z "${_res}" ]]; then
		echo "Could not locate broadcast information..."
		echo $_sql;
		exit 1;
	fi


	OFS=$IFS
	IFS=$'\r\n';
	c=1;
	nextcut=0;
	for i in $_res; do
		_trackid=$(echo "$i" | cut -d '|' -f1);
		_showtitle=$(echo "$i" | cut -d '|' -f2);
		_trackstart=$(echo "$i" | cut -d '|' -f3);
		_artist=$(echo "$i" | cut -d '|' -f4);
		_title=$(echo "$i" | cut -d '|' -f5);
		_position=$(echo "$i" | cut -d '|' -f6);
		_duration=$(echo "$i" | cut -d '|' -f7);
		_showname=$(echo "$i" | cut -d '|' -f8);
		_audiourl=$(echo "$i" | cut -d '|' -f9);

		if [ ! -e `basename "${_audiourl}"` -o -e `basename "${_audiourl}"`.aria2 ]; then
			aria2c -c "${_audiourl}";
			if [[ $? != 0 ]]; then
				echo "Error: aria2 failed to download mp3..."
				echo "Waiting 10 seconds then retrying...";
				sleep 10;
				`${BASH_SOURCE[0]} "${QUERY}"`
				exit 1
			fi
		fi

#echo $_audiourl;
		index=$(printf "%0.4d" "${c}");
		wtf=$(( $_position+$_duration ));

		mkdir -p "${OUTPUT_DIR}${_showtitle}/"

		_ofile="${index}-[KRCL-${_showname}]-${_artist}-${_title}.mp3"
		_ofile=$(echo "${_ofile}" | tr " " "_" | tr -dc "_A-Z-a-z-0-9 #:_\-\.\n\[\]\(\)");
		_ofile="${OUTPUT_DIR}{$_showtile}/${_ofile}"


	
		if [ $nextcut -gt 0 ]; then
			if [[ $(( $_position+$_duration )) != $nextcut ]]; then
		
				echo "Descrepancy in next cut: " $(( $wtf - $nextcut ));
			fi
		fi
		nextcut="${wtf}";


		ffmpeg -stats \
			-ss "${_position}" \
			-t "${_duration}" \
			-i "`basename "${_audiourl}"`" \
			-q:a 2 \
			-metadata artist="KRCL" \
			-metadata album="${_showtitle}" \
			-metadata title="${index}-${_artist}-${_title}" \
			-metadata track="${index}" \
			 "${_ofile}";

		c=$(( c+1 ));
	done


	#for r in $(echo "${_sql}" | sqlite3 db/krcl-playlist-data.sqlite3); do
#		echo $r;
	#done
	#echo $_res;


}


setup