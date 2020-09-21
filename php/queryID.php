<?php

// We want to cache the data for a project. We can leave it up to the
// user if he wants to update the cache or use the existing cache.

$num_allowed = 5;
$dirs_tmp = glob('data/*', GLOB_ONLYDIR);
$dirs = [];
foreach ($dirs_tmp as $d) {
   if(!preg_match("#^\.#", $d)) {
     $dirs[] = $d;
   }
}
usort($dirs, function($a, $b) {
    return filemtime($a) > filemtime($b);
});

function delTree($dir) {
   $files = array_diff(scandir($dir), array('.','..'));
   foreach ($files as $file) {
     (is_dir("$dir/$file")) ? delTree("$dir/$file") : unlink("$dir/$file");
   }
   return rmdir($dir);
}

if (count($dirs) > $num_allowed) {
   // remove the oldest
   $deleteThisMany = count($dirs) - $num_allowed;
   $counter = 0;
   foreach ($dirs as $v) {
      //echo("delete directory (".$v.")");
      delTree($v);
      if ($counter > $deleteThisMany) {
         break;// stop deleting more
      }
      $counter = $counter + 1;
   }
}

$uid = "";
if (isset($_GET['ID'])) {
  $uid = $_GET['ID'];
} else {
  echo("{ \"message\": \"no id specified\" }");
  exit();
}

// does this id directory exist?
$infofn = 'data/'.$uid.'/info.json';
if (!file_exists($infofn)) {
  echo("{ \"message\": \"no query for this uid\" }");
  exit();
}

// collect all the dcmdump info and return them
$data = array();
// parse the directory for all .cache files
$files = glob('data/'.$uid.'/*/*.cache');
foreach($files as $file) {
  $tmp = explode("/", $file);
  $StudyInstanceUID=$tmp[2];
  $SeriesInstanceUID=$tmp[3];
  if (!isset($data[$StudyInstanceUID])) {
     $data[$StudyInstanceUID] = array();
  }
  $output = explode("\n", shell_exec('cat "'.$file.'" | sort | uniq | tr -cd \'[:print:]\n\' | tr -d \'<\' | sed "s/[\\"\']/~/g" '));
  //syslog(LOG_EMERG, "output is: \"".json_encode($output)."\"");
  foreach($output as &$out) {
    $out = htmlentities($out);
  }
  $data[$StudyInstanceUID][$SeriesInstanceUID] = $output;
}

//$output = explode("\n", shell_exec('cat data/'.$uid.'/*.cache | sort | uniq'));
// now parse the result into key, value pairs
//$counter = 1;
//foreach($output as $line) {
//   if (strlen($line) > 0) {
//     $data[] = array( "key" => $counter, "value" => $line);
//     $counter = $counter + 1;
//   }
//}

//syslog(LOG_EMERG, "\"".json_encode($data)."\"");
echo(json_encode($data));

?>