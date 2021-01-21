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
    } else {
        // even if the folder is writable the files might not be readable
        // this is a problem of using mounts that overlay the real directory
        // structure - very esoteric. But we might need to actually write
        // and see if its still there.
        $test_file = $cache_folder."/test.txt";
        touch($test_file);
        if (!file_exists($test_file)) {
            $data["cache_folder"] = "Error: we tried to write a file to the cache folder ".$cache_folder." but the file was not readable afterwards.";
        } else {
            unlink($test_file);
        }
    }
    if (!is_writable($exports_folder)) {
        $data["exports_folder"] = "Error: the exports folder ".$exports_folder." is not writable.";
    } else {
        $test_file = $exports_folder."/test.txt";
        touch($test_file);
        if (!file_exists($test_file)) {
            $data["exports_folder"] = "Error: we tried to write a file to the exports folder ".$exports_folder." but the file was not readable afterwards.";
        } else {
            unlink($test_file);
        }
    }

    echo(json_encode($data));
?>