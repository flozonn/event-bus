<?php
use Aws\Exception\AwsException;
use Aws\S3\S3Client;

use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\API\Signals;
use OpenTelemetry\API\LoggerHolder;

use OpenTelemetry\Contrib\Otlp\OtlpUtil;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\Contrib\Grpc\GrpcTransportFactory;

use OpenTelemetry\Aws\Xray\IdGenerator;
use OpenTelemetry\Aws\Xray\Propagator;
use OpenTelemetry\Aws\AwsSdkInstrumentation;

use OpenTelemetry\SDK\Common\Configuration\Configuration;
use OpenTelemetry\SDK\Common\Configuration\Variables;
use OpenTelemetry\SDK\Trace\TracerProvider;
use OpenTelemetry\SDK\Trace\SpanProcessor\SimpleSpanProcessor;



class Xray
{
    private function convertOtelTraceIdToXrayFormat(String $otelTraceId) : String
    {
        $xrayTraceID = sprintf(
            "1-%s-%s",
            substr($otelTraceId, 0, 8),
            substr($otelTraceId, 8)
        );

        return $xrayTraceID;
    }


    public function outgoingHttpCall()
    {
        /*
        otel:4317 endpoint corresponds to the collector endpoint in docker-compose 
        If running this sample app locally, set the endpoint to correspond to the endpoint 
        of your collector instance. 
        */
        $endpoint = $this->getEndpoint();
        $transport = (new GrpcTransportFactory())->create($endpoint . OtlpUtil::method(Signals::TRACE));
        $exporter = new SpanExporter($transport);

        // Initialize Span Processor, X-Ray ID generator, Tracer Provider, and Propagator
        $spanProcessor = new SimpleSpanProcessor($exporter);
        $idGenerator = new IdGenerator();
        $tracerProvider = new TracerProvider($spanProcessor, null, null, null, $idGenerator);
        $propagator = new Propagator();
        $tracer = $tracerProvider->getTracer('io.opentelemetry.contrib.php');
        $carrier = [];
        $traceId = "";


        try {
            // Create and activate root span
            $root = $tracer
                    ->spanBuilder('Trace PHP custom ✅')
                    ->setSpanKind(SpanKind::KIND_CLIENT)
                    ->startSpan();
            $rootScope = $root->activate();


           
            $propagator->inject($carrier);

            $root->setAttributes([
                "http.method" => 'ET BIIM  🔥',
                "http.url" => 'ET BOOM ✨ ',
                "http.status_code" => '666' 
            ]);


            $traceId = $this->convertOtelTraceIdToXrayFormat(
                $root->getContext()->getTraceId()
            );
        } finally {

            $root->end();
            $rootScope->detach();

            $tracerProvider->shutdown();
        }
        
    }


    public function awsSdkCall()
    {
        /*
            otel:4317 endpoint corresponds to the collector endpoint in docker-compose 
            If running this sample app locally, set the endpoint to correspond to the endpoint 
            of your collector instance. 
        */
        $endpoint = $this->getEndpoint();
        $transport = (new GrpcTransportFactory())->create($endpoint . OtlpUtil::method(Signals::TRACE));
        $exporter = new SpanExporter($transport);

        // Initialize Span Processor, X-Ray ID generator, Tracer Provider, and Propagator
        $spanProcessor = new SimpleSpanProcessor($exporter);
        $idGenerator = new IdGenerator();
        $tracerProvider = new TracerProvider($spanProcessor, null, null, null, $idGenerator);
        $propagator = new Propagator();

        // Create new instance of AWS SDK Instrumentation class
        $awssdkinstrumentation = new  AwsSdkInstrumentation();

        // Configure AWS SDK Instrumentation with Propagator and set Tracer Provider (created above)
        $awssdkinstrumentation->setPropagator($propagator);
        $awssdkinstrumentation->setTracerProvider($tracerProvider);
        $traceId = "";

        // Create and activate root span
        $root = $awssdkinstrumentation
                ->getTracer()
                ->spanBuilder('AwsSDKInstrumentation')
                ->setSpanKind(SpanKind::KIND_SERVER)
                ->startSpan();
        $rootScope = $root->activate();

        $root->setAttributes([
            "http.method" => 'ET BIM',
            "http.url" => 'ET BAM !!',
        ]);

        // Initialize all AWS Client instances
        $s3Client = new S3Client([
            'region' => 'eu-west-3',
            'version' => '2006-03-01'
        ]);

        // Pass client instances to AWS SDK
        $awssdkinstrumentation->instrumentClients([$s3Client]);

        // Activate Instrumentation -- all AWS Client calls will be instrumented
        $awssdkinstrumentation->activate();

        // Make S3 client call
        try{
            $result = $s3Client->listBuckets();

            echo $result['Body'] . "\n";

            $root->setAttributes([
                'http.status_code' => $result['@metadata']['statusCode'],
            ]);

            $traceId = $this->convertOtelTraceIdToXrayFormat(
                $root->getContext()->getTraceId()
            );

        } catch (AwsException $e){
            $root->recordException($e);
        } finally {
            // End the root span after all the calls to the AWS SDK have been made
            $root->end();
            $rootScope->detach();

            $tracerProvider->shutdown();
        }
    }

    private function getEndpoint(): string
    {
        return 'http://0.0.0.0:4317';
    }
}