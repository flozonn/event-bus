<?php
 
require __DIR__ . '/vendor/autoload.php';



return function ($event) {

    sleep(15);
    return 'Hello ' . ($event['name'] ?? 'world');
};