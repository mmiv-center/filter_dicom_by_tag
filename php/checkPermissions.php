<?php
    // test the linked directories, see if we can write
    // but that does not test if they are accessible from 
    // the outside...
    $data = array();
    $data_folder = "/data/";
    $cache_folder= "/var/www/html/php/project_cache";
    $exports_folder = "/var/www/html/php/exports";

    // check if the data folder exists
    if (!is_dir($data_folder)) {
        $data["data_folder"] = "Error: the data folder ".$data_folder." could not be found.";
    }

    // check if the cache and export folders are writable
    if (!is_writable($cache_folder)) {
        $data["cache_folder"] = "Error: the cache folder ".$cache_folder." is not writable.";
    }
    if (!is_writable($exports_folder)) {
        $data["exports_folder"] = "Error: the exports folder ".$exports_folder." is not writable.";
    }

    echo(json_encode($data));
?>