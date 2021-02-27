#!/bin/bash
set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

export TZ="America/Denver" 

DIALOG=${DIALOG=dialog}
_WT_FIFO=`mktemp`

error() {
	echo "$@"
	exit 1
}

finish() {
	rm "${_WT_FIFO}"
}

setup() {
	$DIALOG --version > /dev/null || error "Requires dialog."
	#trap finish EXIT
}


main() {
	_wt_main
}

_wt_main() {
	$DIALOG --backtitle "KRCL Buff/Ripper" \
		--title "Main Menu" \
		--menu "" 15 60 5 \
		"Shows" "List all shows" \
		"All Broadcasts" "List of available broadcasts" \
		"Search Broadcasts" "Search track data for artist/song" \
		"Latest Tracks" "Latest Playlist" 2> "${_WT_FIFO}";
	_s=$?;
	_r=$(cat "${_WT_FIFO}");

	case "$_r" in
		Shows)
			_wt_shows
			;;
		"All Broadcasts")
			_wt_broadcasts
			;;
		"Search Broadcasts")
			_wt_search_broadcasts
			;;
		*)
			error "Unhandled option"
	esac
}

_wt_shows() {
	_sql="SELECT \
sh.name AS tag,
sh.title, 
(SELECT COUNT(*) FROM broadcasts WHERE show_id=sh.show_id) AS total, 
(SELECT MAX(length(title)) from shows) - LENGTH(sh.title) + 5 AS padding

FROM shows sh \
ORDER BY sh.name
";
#sh.title || ' - Total: ' || (SELECT COUNT(*) FROM broadcasts WHERE show_id=sh.show_id) AS item,
	_res=$(echo "${_sql}" | sqlite3 -newline $'\r\n' db/krcl-playlist-data.sqlite3);
	OFS=$IFS
	IFS=$'\r\n';
	_wt_opts=()
	_wt_opts+=( "<<" " Back");
	for i in $_res; do
		_wt_tag=$(echo "$i" | cut -d '|' -f1);
		_wt_item=$(echo "$i" | cut -d '|' -f2);
		_wt_total=$(echo "$i" | cut -d '|' -f3);
		_padding=$(echo "$i" | cut -d '|' -f4);
		_wt_opts+=( ${_wt_tag//\"} "${_wt_item//\"} `printf "%${_padding}s" "${_wt_total}"`");
	done
	$DIALOG --backtitle "KRCL Buff/Ripper" \
		--title "All Shows" \
		--menu "Shows" 22 80 15 \
		${_wt_opts[@]} 2> "${_WT_FIFO}"

	_r=$(cat "${_WT_FIFO}");
	if [[ "${_r}" == "<<" ]]; then
		_wt_main
	else
		_wt_broadcasts "${_r}"
	fi
}

_wt_broadcasts() {
	_show_name=${1:-};
	
	_sql="SELECT \
b.broadcast_id,
b.title,
sh.name,
bs.audiourl, 
b.start
FROM shows sh \
INNER JOIN broadcasts b USING (show_id) \
INNER JOIN broadcast_status bs USING (broadcast_id) 
";
	if [[ "${_show_name}" != "" ]]; then
		_sql="${_sql} WHERE sh.name=\"${_show_name}\" ";
	fi
	_sql="${_sql} ORDER BY b.start DESC ";

	_res=$(echo "${_sql}" | sqlite3 -newline $'\r\n' db/krcl-playlist-data.sqlite3);
	OFS=$IFS
	IFS=$'\r\n';
	_wt_opts=()
	_wt_opts+=( "<<" " Back");
	for i in $_res; do
		_wt_tag=$(echo "$i" | cut -d '|' -f1);
		_wt_item=$(echo "$i" | cut -d '|' -f2);
		_wt_opts+=( ${_wt_tag//\"} "${_wt_item//\"}");
	done
	$DIALOG --backtitle "KRCL Buff/Ripper" \
		--title "Broadcasts" \
		--menu "" 22 80 15 ${_wt_opts[@]} 2> "${_WT_FIFO}"
	_r=$(cat "${_WT_FIFO}");

	if [[ "${_r}" == "<<" ]]; then
		if [[ "${_show_name}" != "" ]]; then
			_wt_shows
		else
			_wt_main
		fi
	else
		_wt_broadcast_info "${_r}" "${_show_name}"
	fi
}

_wt_broadcast_info() {
	_broadcast_id=${1}
	_show_name=${2:-};
	_wt_title="";
	_sql="SELECT \
t.track_id,
b.title,
t.start,
s.artist, \
s.title, \
strftime('%s', t.start) - strftime('%s', datetime(b.start, '-7 hour')) AS position, \
s.duration,
sh.name,
sh.show_id,
bs.audiourl
FROM shows sh \
INNER JOIN broadcasts b USING (show_id) \
INNER JOIN broadcast_status bs USING (broadcast_id) \
INNER JOIN tracks t USING (broadcast_id) \
INNER JOIN songs s USING (track_id) \
WHERE b.broadcast_id=${_broadcast_id}
ORDER BY t.start DESC, b.title
"
	_res=$(echo "${_sql}" | sqlite3 -newline $'\r\n' db/krcl-playlist-data.sqlite3);

	OFS=$IFS
	IFS=$'\r\n';
	c=0;
	_wt_message_header="";
	_wt_message="";
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
		c=$(( $c + 1));

		_wt_message_header="\
Broadcast id: ${_broadcast_id}\n\
Broadcast   : ${_showtitle}\n\
MP3 URL     : ${_audiourl}\n\
";
		_wt_message="${_wt_message}${c}: [${_duration}s] ${_artist} - ${_title}\n";
		_wt_title="${_showtitle}"
	done

	$DIALOG --backtitle "KRCL Buff/Ripper" \
		--title "${_wt_title}" \
		--scrollbar \
		--yes-label "Download" \
		--no-label "<< Back" \
		--yesno "${_wt_message_header}\nTrack List:\n${_wt_message}" 22 80 
	_s=$?;

	if [ $_s -eq 1 ]; then
		 [ "${_show_name}" -eq "" ] && _wt_main || _wt_broadcasts "${_show_name}";
	else
		_wt_rip_broadcast "${_broadcast_id}";
	fi


#	whiptail --scrolltext --title "${_wt_title}" \
#		--scrolltext \
#		--yesno "${_wt_message_header}\nTrack List:\n${_wt_message}" \
#		--yes-button "Download" \
#		--no-button "<< Back"  22 80 \
#		|| _wt_main \
#		&& _wt_rip_broadcast "${_broadcast_id}"
		
		# || ( [ "${_show_id}" -eq "" ] && _wt_main || _wt_broadcasts "${_show_id}" ) \
		#&& _wt_rip_broadcast "${_broadcast_id}"
}

_wt_search_broadcasts() {
	$DIALOG --backtitle "KRCL Buff/Ripper" \
		--title "Search Broadcasts"\
		--inputbox "Search broadcast  data for Artist / Song. \
Wildcards accepted using the Percent Sign (%). \
Note that special characters may be removed or quoted.\n\n\
Search for:" 16 51 2> "${_WT_FIFO}"
	_s=$?

	if [[ $_s != 0 ]]; then
		_wt_main;
	else
		_r=$(cat "${_WT_FIFO}");
		_wt_search_broadcasts_result "${_r}"
	fi
}


_wt_search_broadcasts_result() {
	_query=${1}
	_show_name=${2:-};
	_wt_title="";
	_sql="SELECT \
b.broadcast_id,
t.start,
sh.title AS show_title, 
s.artist, 
s.title, 
( SELECT MAX(LENGTH(title)) FROM shows ),
b.title || ' ( ' || s.artist || ' - ' || s.title || ' ) ',
strftime('%s', t.start) - strftime('%s', datetime(b.start, '-7 hour')) AS position, \
s.duration,
sh.name,
sh.show_id,
bs.audiourl
FROM shows sh \
INNER JOIN broadcasts b USING (show_id) \
INNER JOIN broadcast_status bs USING (broadcast_id) \
INNER JOIN tracks t USING (broadcast_id) \
INNER JOIN songs s USING (track_id) \
WHERE s.artist LIKE '%${_query}%' OR s.title like '%${_query}%'
ORDER BY sh.title, t.start DESC, b.title
"

	_res=$(echo "${_sql}" | sqlite3 -newline $'\r\n' db/krcl-playlist-data.sqlite3);
	OFS=$IFS
	IFS=$'\r\n';
	c=0; 
	_wt_opts=()
	for i in $_res; do
		_wt_tag=$(echo "$i" | cut -d '|' -f1);
		_start=$(echo "$i" | cut -d '|' -f2);
		_showtitle=$(echo "$i" | cut -d '|' -f3);
		_artist=$(echo "$i" | cut -d '|' -f4);
		_title=$(echo "$i" | cut -d '|' -f5);		
		_maxtitle_len=$(echo "$i" | cut -d '|' -f6);
		_padding=$(( $_maxtitle_len + 16 ));

		c=$(( c + 1 ));

		#_start_friendly=$(TZ="America/Denver" date --date="${_start}" "+%a, %b %d");
		_start_friendly=$(TZ="America/Denver" date --date="${_start}" "+%b %d");
		#_showtitle_friendly=$(printf "%s%${_padding}s" "${_showtitle} ${_start_friendly}" "( ${_artist} - ${_title} )")
		#_wt_item=$_showtitle_friendly

		#_wt_item=$(echo "$i" | cut -d '|' -f2);
		_wt_item="${_showtitle} [${_start_friendly}] :: ${_artist} - ${_title}"

		_wt_opts+=( ${_wt_tag//\"} "${_wt_item//\"}");
	done
	$DIALOG --backtitle "KRCL Buff/Ripper" \
		--title "Results for \"${_query}\":" \
		--no-tags \
		--menu "" 22 80 15 ${_wt_opts[@]} 2> "${_WT_FIFO}"
	_s=$?;
	_r=$(cat "${_WT_FIFO}");
	
	if [[ $_s != 0 ]]; then
		_wt_main
	else
		_wt_broadcast_info "${_r}"
	fi

}

_wt_rip_broadcast() {
	_broadcast_id="${1}";
	./rip-broadcast.sh "${_broadcast_id}" && _wt_main || error "rip broadcast ${_broadcast_id} failed";
}

setup $@
main $@