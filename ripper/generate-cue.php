<?php



#echo $date->format('Y-m-d H:i:sP') . "\n";
#echo $date->format('U') . "\n";

#date_default_timezone_set("America/Denver");

$broadcast_file=$_SERVER['argv'][1];

$data=json_decode(file_get_contents($broadcast_file), false);

$tracks=[];
$date = new DateTime($data->data->start, new DateTimeZone('UTC'));
$date->setTimeZone(new DateTimeZone('America/Denver'));

$enddate = new DateTime($data->data->end, new DateTimeZone('UTC'));
$enddate->setTimeZone(new DateTimeZone('America/Denver'));


#print_r($data);

foreach($data->data->playlist as $i=>$p) {
	$start=strtotime($p->start);
#	echo $p->start . "\n";
	if (isset($data->data->playlist[($i+1)]->start)) {
		$end=strtotime($data->data->playlist[($i+1)]->start);
#		echo "ok";
	} else {
		$end=$enddate->format("U");
#		echo "end";
	}
	#$o=$p;
	$p->duration = $end - $start;

	$tracks[]=$p;
}
#ksort($tracks);
#print_r($tracks);exit;

#$first=array_shift($tracks);

$show_start=$date->format('U');


$intro_date = new DateTime($first->start, new DateTimeZone('America/Denver'));
$intro_date->setTimeZone(new DateTimeZone('UTC'));



$intro_end = $intro_date->format("U");


#print_r($tracks);exit;
#echo date("r", $show_start) . "\n" . $intro_end. "\n";

#echo ($show_start - $intro_end) . "\n";
#exit;


$intro=Array(
	'start'=>$date->format('r'), 
	'end'=>$first->start, 
	'duration'=>strtotime($first->start) - $date->format('U'),
	'song'=>Array(
		'artist'=>'NA', 
		'title'=> 'Intro', 
		'album'=> 'NA'
	)
);

#array_unshift($tracks, $first);


echo "FILE \"vagabon-radio_2021-06-15_20-00-00.mp3\"\n";
echo "TRACK 1 AUDIO\n";
echo "\tTITLE \"Intro\"\n";
echo "\tINDEX 01 0:0:00\n";

$offset=0;
$index=1;
foreach($tracks as $t) {
	$index++;
	$offset=$offset+$t->duration;
	

	$ms=0;
	$s=$offset%60;
	$m=floor($offset/60);
	


	echo "TRACK {$index} AUDIO\n";
	echo "\tTITLE \"{$t->song->title}\"\n";
	echo "\tINDEX 01 {$m}:{$s}:{$ms}\n";
}


#TRACK 2 AUDIO


foreach($t as $tracks) {

}
