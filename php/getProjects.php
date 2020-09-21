<?php
  // assume that each folder in /data contains the raw data for one project
  // we will store caches in the same folder - to be outside of Docker
  $user_name = "local";

  $allowed = true;
  $allowed_projects = array();
  //  check for the role matching ProjectsXXXXX where XXXXXX is a project name

  $projects = array();
  $folders = scandir('/data/');
  foreach($folders as $folder) {
    if ($folder === '.' or $folder === '..')
      continue;
    if (is_dir('/data/'.$folder)) {
       $projects[] = array( "record_id" => $folder );
    }
  }		

echo json_encode($projects);


?>

