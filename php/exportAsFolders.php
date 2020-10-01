<?php
  // Where do we store the output?
  $key = uniqid("export_");
  $path = "/var/www/html/php/exports/".$key;

  $to_export = array( "key" => $key, "output" => $path, "data" => array() );
  if (isset($_POST['to_export'])) {
      $to_export["data"] = json_decode($_POST['to_export'], TRUE);
      echo(json_encode(array("message" => "OK: found variable." . $_POST['to_export'])));
  } else {
      echo(json_encode(array("message" => "Error: no to_export variable found.")));
      return;
  }

  mkdir($path, 0777, TRUE);
  $content = $path."/job.json";
  file_put_contents($content, json_encode($to_export));
  shell_exec("/usr/bin/nohup /var/www/html/php/run_export.sh ".$content." > /tmp/export.log 2>&1 &");
  echo(json_encode(array("message" => "Create export structure with key ".$key. ". Running in the background...", "key" => $key)));

?>
