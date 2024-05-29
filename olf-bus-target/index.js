const AWSXRay = require('aws-xray-sdk')
const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb')
const { KMSClient, DecryptCommand } = require('@aws-sdk/client-kms')

// Initialiser le client DynamoDB
const dynamodbClient = AWSXRay.captureAWSv3Client(
  new DynamoDBClient({ region: 'eu-west-3' })
)
const kmsClient = AWSXRay.captureAWSv3Client(
  new KMSClient({ region: 'eu-west-3' })
)

// Fonction pour déchiffrer les données avec KMS
async function decryptData (encryptedData, kmsKeyId) {
  const command = new DecryptCommand({
    KeyId: kmsKeyId,
    CiphertextBlob: Buffer.from(encryptedData, 'base64')
  })
  const response = await kmsClient.send(command)
  return Buffer.from(response.Plaintext).toString('ascii')
}

exports.handler = async (event, context) => {
  //erreur volontaire
  console.log('received event from bus : ', JSON.parse(event.Records[0].body))
  const bdy = JSON.parse(event.Records[0].body)

  const tableName = process.env.TABLE_NAME

  // Données à insérer dans la table
  const params = {
    TableName: tableName,
    Item: {
      eventId: { S: bdy.detail.eventId },
      target: { S: bdy['detail-type'] }
    }
  }

  // Écrire dans la table DynamoDB
  await dynamodbClient.send(new PutItemCommand(params))
  console.log(
    'data to decrypt',
    JSON.parse(event.Records[0].body).detail.eventData.encrypted_data
  )
  console.log(
    'decrypting .... -> ',
    await decryptData(
      JSON.parse(event.Records[0].body).detail.eventData.encrypted_data
    )
  )

  return 1
}
