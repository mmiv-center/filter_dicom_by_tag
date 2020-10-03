<?php
  // a simple CART model to learn two class predictions from DICOM tags
  // returns the types for the unknown series
  // the input structure is something like this:
  // data['train'] = [ { class: X, study: Y, series: Z, data: {} } ]
  // data['predict'] = [ { study: Y, series: Z, data: {} } ]


  $data = "";
  if (isset($_POST['data'])) {
     //$erg = file_put_contents("bb.json", $_POST['data']);
     //if (!file_exists("bb.json")) {
     //   syslog(LOG_EMERG, "File could not be created!");
     //}
     $data = json_decode($_POST['data'], TRUE);
  } else {
     echo(json_encode(array("message" => "Error: no data provided")));
     exit(1);
  }
  //echo("ok, start with the R script...");

  // instead of fixed filenames we should use a new name each time we run this, folder even...  
  //$input  = "cal.json";
  //$output = "result.json";

  // TODO: this should code for the user, right now runs are not collectible 
  $input = tempnam("/var/www/html/php/data/", "A01_input");
  $output = tempnam("/var/www/html/php/data/", "A01_prediction");

  file_put_contents($input, json_encode($data)); // write the JSON as file

  // we should check if a call is already running, we can kill that call first before
  // starting a new call
  // this does not work, the exec call will also run the string we are looking for, so we will
  // always detect at least one job
  exec("pgrep -f \"php/classify.R\"", $out, $return);
  // file_put_contents("/tmp/bla.log", json_encode($out));
  if ($return == 0) {
    echo("Ok, process is running\n");
    if (length($out) > 1) {
      foreach($out as $o) {
         if (strlen($o) > 0) {
            echo("Kill ".$o);
            exec("kill -9 ".$o); // would be better to kill only the current users runs
         }
      }
    }
  }

  // now call the external classifier and get the output data back
  $start_time = microtime(true);
  $lastline   = exec("/usr/bin/Rscript --vanilla /var/www/html/php/classify.R ".$input." ".$output);
  $end_time   = microtime(true);
  $data       = json_decode(file_get_contents($output), TRUE);
  $data['processing_time'] = ($end_time - $start_time);
  if (file_exists($output.".svg")) {
     $data['tree_image'] = basename($output.".svg");
  }
  echo(json_encode($data));
?>
