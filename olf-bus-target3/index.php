<?php
 
require __DIR__ . '/vendor/autoload.php';
require "./Xray.php";



return function ($event) {
    $Xray = new Xray();
    $Xray->outgoingHttpCall() ;
    sleep(15);
    return 'Hello ' . ($event['name'] ?? 'world');
};

