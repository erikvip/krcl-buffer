#!/bin/bash -x
#set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

export TZ="America/Denver" 

_WT_FIFO=`mktemp`

error() {
	echo "$@"
	exit 1
}

finish() {
	rm "${_WT_FIFO}"
}

setup() {
	whiptail --version > /dev/null || error "Requires whiptail."
	#trap finish EXIT
}


main() {
	_wt_main
}

_wt_main() {
	whiptail --menu "Main Menu" 15 60 5 \
		Shows "List all shows" \
		"All Broadcasts" "List of available broadcasts" \
		"Latest Tracks" "Latest Playlist" 2> "${_WT_FIFO}";
	_r=$(cat "${_WT_FIFO}");

	case "$_r" in
		Shows)
			_wt_shows
			;;
		"All Broadcasts")
			_wt_broadcasts
			;;
		*)
			error "Unhandled option"
	esac
}

_wt_shows() {
	_sql="SELECT \
sh.show_id AS tag,
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
	whiptail --menu "Shows" 22 80 15 ${_wt_opts[@]} 2> "${_WT_FIFO}"
	_r=$(cat "${_WT_FIFO}");
	if [[ "${_r}" == "<<" ]]; then
		_wt_main
	else
		_wt_broadcasts "${_r}"
	fi
}

_wt_broadcasts() {
	_show_id=${1:-};
	
	_sql="SELECT \
b.broadcast_id,
b.title,
sh.name,
bs.audiourl
FROM shows sh \
INNER JOIN broadcasts b USING (show_id) \
INNER JOIN broadcast_status bs USING (broadcast_id) 
";
	if [[ "${_show_id}" =~ ^[0-9]+$ ]]; then
		_sql="${_sql} WHERE sh.show_id=${_show_id} ";
	fi
	_sql="${_sql} ORDER BY b.title ";

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
	whiptail --menu "Broadcasts" 22 80 15 ${_wt_opts[@]} 2> "${_WT_FIFO}"
	_r=$(cat "${_WT_FIFO}");

	if [[ "${_r}" == "<<" ]]; then
		if [[ "${_show_id}" =~ ^[0-9]+$ ]]; then
			_wt_shows
		else
			_wt_main
		fi
	else
		_wt_broadcast_info "${_r}" "${_show_id}"
	fi
}

_wt_broadcast_info() {
	_broadcast_id=${1}
	_show_id=${2:-};
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
	done

	whiptail --scrolltext --title "${_showtitle}" \
		--scrolltext \
		--yesno "${_wt_message_header}\nTrack List:\n${_wt_message}" \
		--yes-button "Download" \
		--no-button "<< Back"  22 80 \
		|| ( "${_show_id}" -eq "" ] && _wt_main || _wt_broadcasts "${_show_id}" ) \
		&& _wt_rip_broadcast "${_r}" 
		

}

setup $@
main $@