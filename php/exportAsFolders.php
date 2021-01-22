<?php
  // Where do we store the output?
  $key = uniqid("export_");
  $path = "/var/www/html/php/exports/".$key;

  $to_export = array( "key" => $key, "output" => $path, "data" => array(), "name" => "", "id" => "", "project" => "" );
  if (isset($_POST['to_export'])) {
      $to_export["data"] = json_decode($_POST['to_export'], TRUE);
      echo(json_encode(array("message" => "OK: found variable." . $_POST['to_export'])));
  } else {
      echo(json_encode(array("message" => "Error: no to_export variable found.")));
      return;
  }
  if (isset($_POST['name'])) {
      $to_export['name'] = $_POST['name'];
  }
  if (isset($_POST['id'])) {
    $to_export['id'] = $_POST['id'];
  }
  if (isset($_POST['project'])) {
    $to_export['project'] = $_POST['project'];
  }

  mkdir($path, 0777, TRUE);
  $content = $path."/job.json";
  file_put_contents($content, json_encode($to_export));
  shell_exec("/usr/bin/nohup /var/www/html/php/run_export.sh ".$content." > /tmp/export.log 2>&1 &");
  echo(json_encode(array("message" => "Create export structure with key ".$key. ". Running in the background...", "key" => $key)));

?>
