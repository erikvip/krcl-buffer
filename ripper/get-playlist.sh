#!/bin/bash
set -o nounset  # Fail when access undefined variable
set -o errexit  # Exit when a command fails

export TZ="America/Denver" 

FETCH_DATE=$1; 
START_TIME=${2:-}; 
END_TIME=${3:-}; 
MAX_PAGES=20;

KRCL_PLAYLIST_BASEURL="https://krcl.org/playlist/?page={1..2}&date=";

if [[ "${FETCH_DATE}" =~ [0-9]{4}\-[0-9]{2}\-[0-9]{2} ]]; then 
	# Valid date
	KRCL_PLAYLIST_URL="${KRCL_PLAYLIST_BASEURL}${FETCH_DATE}"; 
	echo "Fetching playlist for ${FETCH_DATE}"; 
else 
	echo "ERROR: Must specify date as YYYY-MM-DD."
	exit 1
fi;

if [[ "${START_TIME}" == "" ]]; then START_TIME="12:01 AM"; fi
if [[ "${END_TIME}" == "" ]]; then 	END_TIME="11:59 PM"; fi

s_START_TIME=$(date --date="${FETCH_DATE} ${START_TIME}" "+%s"); 
s_END_TIME=$(date --date="${FETCH_DATE} ${END_TIME}" "+%s"); 

if [[ ${s_START_TIME} > ${s_END_TIME} ]]; then
	echo "ERROR: invalid stop time. End time must be before start time";
	exit 1
fi;

START_TIME=$(date --date="@${s_START_TIME}"); 
END_TIME=$(date --date="@${s_END_TIME}"); 


# Year is ommitted in feed, so parse from command line arguments for later
YEAR=$(date --date="@${s_START_TIME}" "+%Y"); 

if [ ! -d "tmp/" ]; then 
	mkdir "tmp";
fi

_TMP_DIR=$(mktemp -d "tmp/krcl-playlist-XXXX"); 

#PL_TMP_DIR=$(mktemp -d "krcl-playlist-XXXX"); 
PL_TMP=$(mktemp); 

## Parse raw HTML data into JSON
## Expects path to HTML file as first argument
## Returns path to temporary JSON file
_krcl_playlist_html_to_json() {

	local JQ_TMP=$(mktemp);
	local _html_data_file=$1; 
	echo "[" > $JQ_TMP
	#cat $_html_data_file |  

	cat ${_TMP_DIR}/playlist.index.*.html |
		tr -d "\r\n\t"  | 
		sed -E -e 's/(<div class="playlist-item (odd|even|none)">)/\
	\0 /g' -e 's/<ul class="pagination">/\
	/g' | 
		grep '<div class="playlistitem-name' | 
		egrep -o '<h3>.*</h3>' | 
		sed -E 's/[[:space:]][[:space:]]+/ /g' | 
		sed -E 's/<h3><b>([^<]*)<\/b> \| ([^<]*)<\/h3> <h3>([^<]*)<\/h3>.*<h3> ([A-Za-z]{3} [0-9][0-9]?)[^>]*>([0-9\:]* [A-Z]{2}).*/{"artist":"\1","track":"\2","album":"\3","date":"\4","time":"\5"}/g'  |
		paste -sd, - >> $JQ_TMP

	echo "]" >> $JQ_TMP
	echo $JQ_TMP

}


	


read_jq_var() {
	declare -n arr=$1;
	local _jq_data=$2; 
    keys=$(jq -c 'keys' <<< "${_jq_data}" | sed -e 's/^\[//' -e 's/\]$//'); 

	OFS=$IFS;
    IFS="," 
    for key in $keys; do
    	k=$(echo "${key}" | sed -e 's/^\"//' -e 's/\"$//');
    	for d in $(jq -c ".${k}" <<< "${_jq_data}"); do
    		d="${d##\"}";
    		d="${d%%\"}";
    		arr["${k}"]="${d}";
    	done
    done
    IFS=$OFS
}


print_r() {
	declare -n arr=$1;
	echo -e "(\n";
	for d in ${!ROW[@]}; do
		echo -e "\t ${d}: ${ROW[$d]}";
	done
	echo -e ")\n";


}


get_filedate() {
	#declare -n ROW=$1; 
	local secs=$1; 
	
	#hour=$(TZ="Europe/London" date --date="@${secs}" "+%H");
	#min=$(TZ="Europe/London" date --date="@${secs}" "+%M");
	#filedate=$(TZ="Europe/London" date --date="@${secs}" "+%Y%m%d-%H");

	#####filedate=$(date --date="TZ=\"Europe/London\" @${secs}" "+%Y%m%d-%H");

	hour=$(TZ="America/Denver" date --date="@${secs}" "+%H");
	min=$(TZ="America/Denver" date --date="@${secs}" "+%M");
	filedate=$(TZ="America/Denver" date --date="@${secs}" "+%Y%m%d-%H");

	

	# Files are split into 15 min increments...so figure out which file
	if [[ $min > 0 && $min < 16 ]]; then filedate="${filedate}0000";  fi;
	if [[ $min > 15 && $min < 31 ]]; then filedate="${filedate}1500";  fi;
	if [[ $min > 30 && $min < 46 ]]; then filedate="${filedate}3000";  fi;
	if [[ $min > 45 ]]; then filedate="${filedate}4500";  fi;

	echo $filedate;


}

#echo `get_filedate 1573617600`;
#exit

# 
#fetch_http() {

#}

main() {
	echo "Start time : ${START_TIME} ( ${s_START_TIME} );"
	echo "End time   : ${END_TIME} ( ${s_END_TIME} );"

#	wget \
#		--show-progress \
#		--connect-timeout 60 \
#		--read-timeout 60 \
#		--retry-connrefused \
#		--no-check-certificate \
#		-O - https://krcl.org/playlist/?page={1..20}\&date=${FETCH_DATE} >> "${PL_TMP}"	
	
	for i in $(seq 1 ${MAX_PAGES}); do 
		echo -e "https://krcl.org/playlist/?page=${i}&date=${FETCH_DATE}\n out=${_TMP_DIR}/playlist.index.${i}.html" >> ${_TMP_DIR}/fetch_list.urls
	done
#		echo https://krcl.org/playlist/?page={1..20}\&date=${FETCH_DATE} \


#		--show-progress \
#		--connect-timeout 60 \
#		--read-timeout 60 \
#		--retry-connrefused \
#		--no-check-certificate \
#		-O - https://krcl.org/playlist/?page={1..20}\&date=${FETCH_DATE} >> "${PL_TMP}"	

	aria2c -i "${_TMP_DIR}/fetch_list.urls"  # >> "${PL_TMP}""
#	cat ${_TMP_DIR}/playlist.index.*.html >> "${PL_TMP}"
	#cat tmp/krcl-playlist-oKB6/playlist.index.*.html >> "${PL_TMP}"
	#rm -r "${_TMP_DIR}"

	echo "Playlist html data saved to " $PL_TMP;

	JQ_TMP=$(_krcl_playlist_html_to_json "${PL_TMP}");

	echo "Playlist JSON saved to ${JQ_TMP}"

	OUTPUT_TMP=$(mktemp)

	# Now parse json into bash arrays
	OFS=$IFS;
	IFS=$'\n'; 
	for i in $(cat $JQ_TMP | jq -c '.[]'); do 
		declare -A ROW
		read_jq_var ROW $i

		secs=$(date --date="${ROW[date]} ${YEAR} ${ROW[time]}" "+%s");
		if [[ $secs > $s_START_TIME && $secs < $s_END_TIME ]]; then
			filedate=$(get_filedate $secs); 
			# Found a match within specified times
			#print_r ROW
			sp=$(( 30-${#ROW[artist]} ));
			_tracksp=$(printf "%${sp}s"); 
			echo -e "$filedate ${ROW[date]} ${ROW[time]} :: ${ROW[artist]:0:29} $_tracksp ${ROW[track]} " >> ${OUTPUT_TMP}
		fi
	done
	IFS=$OFS;

	cat ${OUTPUT_TMP} | sort | uniq
}
cleanup () {
	rm "${OUTPUT_TMP}"
	rm "${PL_TMP}"
	rm -rf "${_TMP_DIR}"
}



trap cleanup EXIT
main

#rm "${PL_TMP}"
#rm "${JQ_TMP}";


