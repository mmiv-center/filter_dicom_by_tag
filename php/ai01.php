<?php
   // a simple CART model to learn two class predictions from DICOM tags
   // returns the types for the unknown series
   // the input structure is something like this:
   // data['train'] = [ { class: X, study: Y, series: Z, data: {} } ]
   // data['predict'] = [ { study: Y, series: Z, data: {} } ]

   $project = "";
   if (isset($_POST['project'])) {
      $project = $_POST['project'];
   }
   $queryID = "";
   if (isset($_POST['queryID'])) {
      $queryID = $_POST['queryID'];
   }

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

   // We check if a call is already running, we can kill that call first before
   // starting a new call. This allows a single classification BY system. So if we
   // have multiple users this would break.
   exec("pgrep -f \"/var/www/html/php/classify.R\" | /usr/bin/xargs -I'{}' /usr/bin/kill -9 {}");

   // now call the external classifier and get the output data back
   $start_time = microtime(true);
   $lastline   = exec("/usr/bin/Rscript --vanilla /var/www/html/php/classify.R ".$input." ".$output." \"".$project."\" \"".$queryID."\"" );
   $end_time   = microtime(true);
   $data = array();
   $count = 0;
   while(TRUE) {
      $o = sprintf("%s_%04d", $output, $count);
      // do we still have such a file?
      if (!file_exists($o)) {
        break;  
      }
      $data[$count] = json_decode(file_get_contents($o), TRUE);
      $data[$count]['processing_time'] = ($end_time - $start_time);
       if (file_exists(sprintf("%s_%04d.svg", $output, $count))) {
          $data[$count]['tree_image'] = basename(sprintf("%s_%04d.svg", $output, $count));
       }
       if (file_exists(sprintf("%s_model_%04d.RDS", $output, $count))) {
          $data[$count]['model_binary'] = basename(sprintf("%s_model_%04d.RDS", $output, $count));
       }
       $count = $count + 1;
   }
   echo(json_encode($data));
?> 
