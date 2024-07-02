const AWSXRayCore = require('aws-xray-sdk-core')

const AWSXRay = require('aws-xray-sdk')
const {
  EventBridgeClient,
  PutEventsCommand
} = require('@aws-sdk/client-eventbridge')
const { KMSClient, EncryptCommand } = require('@aws-sdk/client-kms')

// Initialiser le client DynamoDB
const ebClient = AWSXRay.captureAWSv3Client(
  new EventBridgeClient({ region: 'eu-west-3' })
)
const kmsClient = AWSXRay.captureAWSv3Client(
  new KMSClient({ region: 'eu-west-3' })
)

async function encryptData (data) {
  const command = new EncryptCommand({
    KeyId: '65300fe2-8bbf-4eec-aa8c-109a0ce5990d',
    Plaintext: Buffer.from(data)
  })
  const response = await kmsClient.send(command)
  return Buffer.from(response.CiphertextBlob).toString('base64')
}

exports.handler = async (event, context, callback) => {
  console.log('event: ', event)
  console.log('context: ', context)

  const segment = AWSXRayCore.getSegment()

  const subSegment = segment.addNewSubsegment('producer_meta_data')

  //subSegment.addMetadata('flo_ajoute_des_datas', { key: 'COUCOU' })
  subSegment.addAnnotation('user_ipv4', event.requestContext.identity.sourceIp)

  const ev = {
    Entries: [
      {
        Source: 'overwhelm.go',
        DetailType: 'targetId-A',
        Detail: JSON.stringify({
          dryRun: 'false',
          sourceAccount: 'AWSaccountID',
          sourceRegion: 'eu-west-3',
          eventTimeIso8601: '{$datetime->format(DateTime::ATOM)}',
          eventType: 'UserInformationChange',
          eventVersion: '2',
          source: 'overwhelm.go',
          eventId: '{uuidv4()}',
          trace: {
            traceId: '',
            spanId: ''
          },
          signature: "{$kmsClient->sign(json_encode($event['data']))}",
          signatureAlg: '',
          signKeyId: '<KMS_SIGN_KEY_ID>',
          encryptedField: [
            {
              encryptionKeyId: '<KEYID>',
              encryptedFields: ['encrypted_data']
            }
          ],
          requestId: 'ID API Gateway',
          generateBy: 'le user Id du JWT',
          generateByType: 'application|support_user|end_user|internal_user',
          eventData: {
            ...event,
            encrypted_data: await encryptData('very_ultra_sensitive'),
            clear_data: 'nothing_sensitive'
          }
        }),
        EventBusName: 'olf-event_bus'
      }
    ]
  }

  const command = await ebClient.send(new PutEventsCommand(ev))
  console.log(command)

  subSegment.close()
  var response = {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8'
    },
    body: 'event successfully published to bus'
  }
  callback(null, response)
}
