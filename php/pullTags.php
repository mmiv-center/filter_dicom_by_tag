<?php

$project = "";
if (isset($_GET['project'])) {
   $project = $_GET['project'];
} else {
   echo("{ \"message\": \"no project name\" }");
   exit();
}
$allowCache = "1";
if (isset($_GET['allowCache'])) {
   $allowCache = $_GET['allowCache'];
}	   

$uid = uniqid();
$path = 'data';
mkdir($path . "/" . $uid);
$data = array( 'ID' => $uid, 'project' => $project );

if ($allowCache == "1") {
   $project_cache = dirname(__FILE__)."/project_cache/".$project;
   if (is_dir($project_cache)) {
      // copy all cache data over (takes too long, better to just link to the path)
       //shell_exec("cp -R ".$project_cache."/* ".$path."/".$uid."/");
      shell_exec("cp -R ".$project_cache."/imageIndex.txt ".$project_cache."/imageMontage.jpg ".$path."/".$uid."/");
      $data['startdate'] = "now";
      $data['enddate'] = "now";
      $data['cache_path'] = $project_cache;
      file_put_contents($path . "/". $uid . "/info.json", json_encode($data));
      echo("{ \"ID\": \"". $uid . "\", \"cache\": \"ok\" }");
      // done
      exit(0);
   }
}

// start the real work in the background
shell_exec(dirname(__FILE__).'/getAllTags.sh "'.$uid.'" "'.$project.'" >> /tmp/getAllTags.log 2>&1 &');

file_put_contents($path . "/". $uid . "/info.json", json_encode($data));
echo("{ \"ID\": \"". $uid . "\" }");

?>
