<?php
  // Where do we store the output?
  $to_export = array();
  if (isset($_POST['to_export'])) {
      $to_export = $_POST['to_export'];
  } else {
      echo(json_encode(array("message" => "Error: no to_export variable found.")));
      return;
  }

  echo(json_encode(array("message" => "Start doing some work.")));


?>
