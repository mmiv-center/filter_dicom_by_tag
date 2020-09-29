<?php
  // Where do we store the output?
  $to_export = array();
  if (isset($_POST['to_export'])) {
      $to_export = json_decode($_POST['to_export'], TRUE);
  } else {
      echo(json_encode(array("message" => "Error: no to_export variable found.")));
      return;
  }

  $key = uniqid("export_");
  $path = "/var/www/html/php/exports/".$key;
  mkdir($path, 0777, TRUE);
  file_put_contents($path."job.json", json_encode($to_export));
  shell_exec("/usr/bin/nohup /var/www/html/php/run_export.sh ".$path." &");
  echo(json_encode(array("message" => "Create export structure with key ".$key. ". Running in the background...")));

?>
