<?php

use Bref\Context\Context;
use Bref\Event\Sqs\SqsEvent;
use Bref\Event\Sqs\SqsHandler;
use OpenTelemetry\Aws\AwsSdkInstrumentation;
use OpenTelemetry\API\Common\Instrumentation\InstrumentationTrait;

class MyHandler extends SqsHandler
{
    public function handleSqs(SqsEvent $event, Context $context): void
    {
        $awssdkinstrumentation = new AwsSdkInstrumentation();      
        $span2 = $awssdkinstrumentation->getTracer()->spanBuilder('subsegmentFLOOO')->setSpanKind(SpanKind::KIND_CLIENT)->startSpan();

        $span = $awssdkinstrumentation->getTracer()->spanBuilder('subsegmentFLOOO2')->startSpan();
        
        $spanScope = $span->activate();
                
        $span->setAttributes(["FLOOOO" => "DATTTTAAAA CUSTOM"]);
                
        $span->end();
        $spanScope->detach();
        
        $span2->end();
    }
}