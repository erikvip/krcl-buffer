#!/bin/bash -x
# Extract a single song from a streamripper grab, 
# using the krcl-buffer sqlite3 database

_songindex="NULL";
_streamfile="NULL";


errusage() {
	echo "Usage: extract-song <songindex> <streamfile>"
	exit 1

}

setup() {
	if [[ "$1" =~ ^[0-9]+ ]]; then
		_songindex="${1}";
		if [[ "$2" =~ [0-9\_]+ ]]; then
			#_streamfile="'${2}'";
			_streamfile="${2}";
		else
			errusage
		fi
	else
		errusage
	fi
}
debug() {
	echo $*
}
main() {
	setup $@
	#_sql="SELECT start, end, artist, release, song, duration, showtitle FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};"
	_sql="SELECT start FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};"	
	echo $_sql;
	_res=$(echo $_sql | sqlite3 db/krcl-playlist.sqlite3);
	if [ $? != 0 ]; then
		echo "Error: failed to extract song info."
		exit 1
	fi
	debug "SQL: $_sql. Res: ${_res}"


	_file=$(find ./data/new -iname "${_streamfile}-*.mp3");
	debug "Real stream file: $_file"
	_actualstart=$(basename "${_file}" | cut -d '-' -f2 | cut -d '.' -f1 | awk -F '_' '{ print $1"-"$2"-"$3" "$4":"$5":"$6 }')
	debug "Actual start: $_actualstart"
	_actualstartsec=$(TZ="America/Denver" date -d "${_actualstart}" "+%s");
	debug "Actual start epoch: ${_actualstartsec}"

	_cutsecondstartepoch=$(TZ="America/Denver" date -d "${_res}" "+%s");
	debug "Cut song start epoch: ${_cutsecondstartepoch}"

	_cutsecondstart=$(( $_cutsecondstartepoch - $_actualstartsec ));
	debug "Song cut start seconds: ${_cutsecondstart}"
	
	_duration=$(echo "SELECT duration FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
	debug "Song duration: ${_duration}"

	# Determine file name...shows to be 'recorded' include index number and date of show, 
	# Where 'normal' live song/ripping only contains track artist, album, title
	_showtitle=$(echo "SELECT showtitle FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
	_saveshow=$(echo "SELECT save from shows where showtitle=(SELECT showtitle FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
	

	if [ "$_saveshow" -eq 1 ]; then
		_showdate=$(TZ="America/Denver" date -d "${_actualstart}" "+%Y%m%d");
		_outputdir="music/${_showtitle}-${_showdate}";
		_filename=$(echo "SELECT substr('0000' || songindex, -4) || '-' || artist || ' - ' || release || ' - ' || song || ' (' || songindex || ' - ' || showtitle || ' ' || start || ').mp3' FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
		_tagtrack=$(printf '%0.4d' ${_songindex});
	else
		_showdate=$(TZ="America/Denver" date -d "${_actualstart}" "+%Y%m%d");
		_outputdir="music/recent";
		_filename=$(echo "SELECT artist || ' - ' || release || ' - ' || song || ' (' || songindex || ' - ' || showtitle || ' ' || start || ').mp3' FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
		_tagtrack=$(printf '%0.4d' ${_songindex});
	fi
	debug "Output dir: ${_outputdir}"
	mkdir -p "${_outputdir}"
	debug "Filename: ${_filename}"

	_tagartist=$(echo "SELECT artist FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
	_tagrelease=$(echo "SELECT release FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	
	_tagsong=$(echo "SELECT song FROM playlist WHERE streamfile=${_streamfile} AND songindex=${_songindex};" | sqlite3 db/krcl-playlist.sqlite3);	

	# Fix breaking characters in filename
	_filenamesafe=$(echo "${_filename}" | sed -e 's/[^A-Za-z0-9._-()\[\]]/_/g');

	# Now run FF mpeg
	ffmpeg -stats -ss ${_cutsecondstart} -t ${_duration} -i "$_file" \
		-metadata artist="${_tagartist}" \
		-metadata album="${_tagrelease}" \
		-metadata title="${_tagsong}" \
		-metadata track="${_tagtrack}" \
		 "${_outputdir}/${_filenamesafe}"
}

main $@