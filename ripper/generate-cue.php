<?php

# @ TODO
# The timezones are screwed up...the broadcast data reports it's in UTC timezone and it is
# But the Playlist data reports UTC but *IT'S NOT UTC*. It's America/Denver, but claims Greenwich...
# This screws w/ all the date handling code...
# Need to normalize / fix the timezone data...



#echo $date->format('Y-m-d H:i:sP') . "\n";
#echo $date->format('U') . "\n";

#date_default_timezone_set("America/Denver");

$broadcast_file=$_SERVER['argv'][1];
#$data=json_decode(file_get_contents($broadcast_file), false);
$sql = new SQLite3('db/krcl-playlist-data.sqlite3');
$sql->enableExceptions(true);

function query($query) {
	global $sql;
	$result = $sql->query($query); 
	$output=[];
	while ($r = $result->fetchArray(SQLITE3_ASSOC)) {
		$output[]=$r;
	}
	return $output;
}


#$bid=95088;
$broadcast=query("SELECT * FROM broadcasts WHERE audiourl LIKE '%$broadcast_file'");
$bid=$broadcast[0]['broadcast_id'];
#$q = "select (select strftime('%s', start) - strftime('%s',datetime(b.start,'-7 hour')) from playlists where broadcast_id=94191 order by start limit 1) as duration,datetime(start, '-7 hour') AS start,datetime(b.end, '-7 hour') as end,'Intro' as title,'NA' as artist, 'NA' as album from broadcasts b where broadcast_id=94191 UNION select strftime('%s', end) - strftime('%s', start) AS duration, start, end, title, artist, album from playlists p join songs using (song_id) where broadcast_id=94191 order by start ;";
$q="SELECT * from playlists p join songs s using (song_id) where p.broadcast_id=$bid order by start";
$playlist=query($q);

$bdate = new DateTime($broadcast[0]['start'], new DateTimeZone('UTC'));
$bdate->setTimeZone(new DateTimeZone('America/Denver'));


#print_r($broadcast);
#print_r($playlist);
#exit;

/*
#print_r($broadcast);
#exit;
#print_r($playlist);

#exit;
#echo $broadcast->start;
#exit;

$tracks=[];
$date = new DateTime($broadcast[0]['start'], new DateTimeZone('UTC'));
$date->setTimeZone(new DateTimeZone('America/Denver'));

#print_r($date->format('r'));
#exit;
$enddate = new DateTime($broadcast[0]['end'], new DateTimeZone('UTC'));
$enddate->setTimeZone(new DateTimeZone('America/Denver'));


#print_r($data);

foreach($playlist as $i=>$p) {
	$start=strtotime($p['start']);
#	echo $p->start . "\n";
	if (isset($playlist[($i+1)]['start'])) {
		$end=strtotime($playlist[($i+1)]['start']);
#		echo "ok";
	} else {
		$end=$enddate->format("U");
#		echo "end";
	}
	#$o=$p;
	$p['duration'] = $end - $start;

	$tracks[]=$p;
}
#ksort($tracks);
#print_r($tracks);exit;

#$first=array_shift($tracks);
$first=$playlist[0];

$show_start=$date->format('U');



$intro_date = new DateTime($first['start'], new DateTimeZone('America/Denver'));
#$intro_date->setTimeZone(new DateTimeZone('America/Denver'));



#$intro_end = $intro_date->format("U");


#print_r($tracks);exit;
#echo date("r", $show_start) . "\n" . $intro_end. "\n";

#echo ($show_start - $intro_end) . "\n";
#exit;
//echo time();
#echo $show_start;exit;

$intro=Array(
	'start'=>$intro_date->format('r'), 
	'end'=>$first['start'], 
	'duration'=>$first['start'] - $intro_date->format("U"),
	'artist'=>'NA', 
	'title'=> 'Intro', 
	'album'=> 'NA'
);
#print_r($intro);exit;

array_unshift($playlist, $intro);
*/

$b = explode("/", $broadcast[0]['audiourl']);
echo "PERFORMER \"KRCL\"\n";
echo "TITLE \"{$broadcast[0]['title']}\"\n";
echo "FILE \"$b[5]\" MP3\n";
echo "TRACK 01 AUDIO\n";
echo "\tPERFORMER \"KRCL\"\n";
echo "\tTITLE \"Intro\"\n";
echo "\tINDEX 01 0:0:00\n";

$offset=0;
$index=1;
#array_shift($playlist);
$secs = $bdate->format("U");
#print_r($bdate);
#echo $bdate->format("U") . "\n";
foreach($playlist as $i=>$t) {
	#print_r($t);
	#echo substr($t['start'],0,19);
	$d = new DateTime( substr($t['start'],0,19), new DateTimeZone('America/Denver'));
	#$d->setTimeZone(new DateTimeZone('America/Denver'));

	$duration = $d->format("U") - $secs;
	$offset += $duration;

	#echo $duration;

	#print_r($t);exit;
	$index++;
	#$duration=strtotime($t['end']) - strtotime($t['start']);
	#echo $t['start']; echo $t['end'];
	#echo $duration;exit;
	if (!isset($playlist[($i+1)]))
		break;
	#$offset=$offset+$playlist[($i+1)]['duration'];
	$offset=$duration;
	

	$ms=0;
	$s=$offset%60;
	$m=floor($offset/60);
	

	$tr = sprintf("%02d", $index);
	echo "TRACK $tr AUDIO\n";
	echo "\tPERFORMER \"{$t['artist']}\"\n";
	echo "\tTITLE \"{$t['title']}\"\n";
	echo "\tINDEX 01 {$m}:{$s}:{$ms}\n";
}


#TRACK 2 AUDIO


foreach($t as $tracks) {

}
