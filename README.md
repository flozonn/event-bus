# event-bus

Préambule
Considérations Techniques
“ La résilience globale d'un système est dictée par la résilience de son maillon le plus faible. ”  

Aujourd’hui nous utilisons massivement des services managés par AWS qui offrent une résilience accrue avec des SLA de disponibilité élevés:

S3, SLA de disponibilité à 99.9%

Route53, SLA de disponibilité à 100%

On pourrait croire que d’utiliser ces services hautement résiliants augmente la résilience globale de notre système.
En fait pas du tout, la résilience de notre système dépend uniquement de la présence de services faiblement résiliants. Les services faiblement résiliants nivèlent par le bas notre résilience globale.

Prenons comme exemple RabbitMQ et MemCache qui sont deux services non managés par AWS.

MEMCACHE est un service de cache qui repose sur une instance EC2 présente dans une seule AZ. L’API legacy constituée d’API gateway + lambda (hautement résilient) dépend de MEMCACHE qui lui est faiblement résilient car non répliqué sur plusieurs AZ.  Cela fait de l’API legacy toute entière, une api peu résiliante.

RABBITMQ est utilisé chez l'entreprise pour emmagasiner des webhooks envoyés par Thredd (les settlement card) et reçu d’abord par une stack API gateway + lambda (stack hautement disponible avec capacité d’ingestion très élevée). RabbitMQ est quant à elle hébergée sur une instance EC2 mono-AZ. La encore, toute l’infra de reception des settlement Thredd a un niveau de résilience correspondant au maillon le plus faible, ici RabbitMQ. Ce qui fait que lorsque RabbitMQ est KO, ou ralenti, tout le système est impacté.

Nous pourrions faire en sorte que MEMCACHE et RABBITMQ soit au niveau de résilience souhaité, cela engagerait des couts d’infrastructure élevés (tout répliquer sur 3 AZ) et poserait de gros problèmes d’opérabilité (charge SRE).

 

“ La résilience globale de votre système n’est pas uniquement liée à la résilience des composants de celui-ci, mais également à celle des applications “externes” dont vous dépendez. ”  

Prenons l’exemple d’un end user qui modifie son numéro de téléphone. 
C’est une information que nous devons prendre en compte car lors du prochain paiement par carte, l’utilisateur s’attendra a recevoir le SMS d’authentification sur son nouveau numéro.
Dans les faits voici ce qu’il se passe:
- Le service UserManager va contacter le service Card2 pour l’informer du changement de numéro.
- Le service Card2 va contacter le prestataire externe THRED pour l’informer du changement de numéro.
On a donc un chaine de dépendance UserManager → Card2 → THRED qui implique que si THRED n’est pas disponible alors toute la chaine en pâti.

Nous avons ce type de dépendances partout dans notre système.

L’idée n’est pas de supprimer ces dépendances définitivement mais plutôt de rechercher un compromis entre:
- haute disponibilité
- dégradation de l’expérience utilisateur 
- risque opérationnel

 

Pour illustrer l’intérêt de ce compromis, reprenons l’exemple de la modification du numéro de téléphone d’un utilisateur.
Il est très peu probable qu’un utilisateur change son numéro de téléphone et qu’il fasse un paiement dans la foulée :check_mark: 
Supposons que THRED est en difficulté et que son système n’est pas en mesure de nous répondre.
Comme un numéro de téléphone, ou une donnée personnelle, constitue un élément de KYC très important pour l'entreprise, il vaut mieux que nous soyons capables de “mettre en attente” ou de conserver l’information du changement du numéro de téléphone dans un état “latent”/”pending” plutôt que de connaître un échec lors d’une tentative de traitement synchrone.
En d’autres termes il faut que l'entreprise ait pris en compte ce changement d’information personnelle, et soit capable de traiter l’information pour l’envoyer à THRED lorsque THRED sera prêt à la traiter.
On introduit donc de l’asynchronisme, couplé à une conservation de l'évènement tant qu’il n’est pas traité correctement avec la capacité de le rejouer.

 

Considérations organisationnelles
Nous connaissons aussi des dépendances organisationnelles susceptibles de ralentir le déploiement de nouvelles fonctionnalités.
Dans l’exemple du changement de numéro de téléphone, tant que Card2 n’a pas fourni un endpoint permettant de recevoir l’information et de répondre, UserManagement ne peut pas être déployé.
Ce phénomène d’interdépendance va s’accroitre au fur et à mesure que nous allons décomposer le monolithe en services métier récupérés par les squads dédiées.

Appeler un fonctionnalité servie par une autre squad impose de faire un appel HTTP via une API REST qui soit documentée et déployée. Sachant que chaque squad dispose de sa propre organisation interne (durée de sprint, outils, contrats d’interface etc..)

Il faut donc penser un système permettant à chaque squad d'être indépendant dans le déploiement de leurs service meme si ils ont besoin d’information provenant d’autre services.
C’est là la valeur ajoutée d’un BUS d'évènement.

Le bus
Le BUS d'évènement sera la colonne vertébrale de tout service; il permettra de servir des évènement à différent services et permettra à différents services de publier des évènements.
Un autre atout de ce BUS d'évènement est qu’il permet de centraliser tous les évènements et donc de monitorer l’activité plus finement. A la manière d’un CloudTrail nous serons en mesure d'établir les traces d’exécution de chaque évènement.

Description du BUS
EventBridge permet de mettre en place le type de BUS dont nous avons besoin.
En termes de limitations et de quotas, il sont tous ajustables, c’est un outil au service de la scalabilité des organisations.
Il est possible de publier ou de lire des évènement depuis différent comptes AWS sans restrictions.
Toute Squad amenée à publier le bus doit se poser la question suivante:

De quels évènements aurais-je besoin si je devais utiliser mon service ?


Dans le doute nous appliquerons le principe de “qui peut le plus peut le moins” 
<=> 
Mieux vaut publier des évènements qui ne serviront pas, plutôt que d’oublier d’émettre des évènements dont une squad peut dépendre.

Événements
Les évènements ajoutés au bus par les squads seront documentés via cet outil https://www.asyncapi.com/ 
Chaque évènement contient un ensemble de données obligatoires permettant la génération de trace et la lecture par les consommateurs de cet évènement.
Pour garantir l’intégrité et la sécurité des données qui transitent dans le bus, il sera nécéssaire de publier un évènement signé (chiffré si nécéssaire).
Voici les champs obligatoires:



{
    "metadata": {
        "dryRun":false,
        "sourceAccount":"AWSaccountID",
        "sourceRegion":"eu-west-3",
        "eventTimeIso8601": "{$datetime->format(DateTime::ATOM)}",
        "eventType": "UserInformationChange",
        "eventVersion": "2",
        "source": "cloud.l'entreprise.{dev|preprod|prod}.{main|shine|swile}.api",
        "eventId": "{uuidv4()}",
        "trace": {
            "traceId": "",
            "spanId": ""
        },
        "signature": "{$kmsClient->sign(json_encode($event['data']))}",
        "signatureAlg": "",
        "signKeyId": "<KMS_SIGN_KEY_ID>",
        "encryptedField": [
              {
                  "encryptionKeyId": "<KEYID>"
                  "encryptedFields": ["user.firstname" , ...] ,
              }
        ],
        "requestId": "ID API Gateway",
        "generateBy": "le user Id du JWT",
        "generateByType": "application|support_user|end_user|internal_user"
    },
    "eventData": {ici ton évènement}
}
Ecouter

Chaque squad est responsable de l’infrastructure qui permettra la lecture des évènements.
Par conséquent chaque squad pourra mettre en oeuvre:

N rules (filtres et scheduler)

M targets (destinations à privilégier API gateway et LAMBDA)

Un sdk dans chaque langage utilisé par l'entreprise peut uniformiser la lecture sur le BUS en authentifiant et déchiffrant la donnée.


Un module TF sera mis a disposition pour brancher une lambda qui écoute le bus.

Afin de garantir qu’un message est traité une et une seule fois, il faut stocker l’information traitée (avec succès) dans une table DDB.

Cette table contient en clé de hachage l’eventId et en clé de tri la targetId.
Ainsi pour chaque message reçu, avant de traiter l’information, la lambda réalise une vérification via un getItem dans DDB. Si l’eventId est présent alors la lambda ne traite pas l’event, dans le cas contraire elle traite l'évènement et en cas de traitement réussi elle stocke l'évènement dans la table DDB.

SI le traitement échoue, alors on peut permettre un stratégie de retry (jusqu'à 3 fois).
Si le traitement échoue 3 fois alors l'évènement n’est plus proposé à la lambda, et il se dirige alors vers la DeadLetterQueue.

La DeadLetterQueue déclenche une alarme lorsqu’elle contient X évènements.

Open image-20240415-170616.png
image-20240415-170616.png
 

l’intégration entre la queue SQS et la lambda consommatrice doit se faire avec un batch size, un concurrency limit, un visibility timeout et une redrive_policy bien réglés en fonction de vos besoins.
Voici un résumé des impacts de chacun des paramètres:

Le visibility timeout des messages de la queue implique que si un message n’est pas traité par la lambda dans le délai imparti alors le même message sera présenté à nouveau à la lambda ou une lambda concurrente. Donc afin de s’assurer qu’un message soit servi à une seule lambda en même temps, définissez un visibility timeout égal à 6 fois le temps de traitement de votre lambda.

concurrency limit, c’est un paramètre de l’intégration entre la lambda et la queue qui permet de dire que les évènements de cette queue ne peuvent déclencher que X instance de la lambda. C’est mieux de définir ce paramètre à ce niveau, plut^t qu’au niveau de la lambda globalement.

Batch size c’est le nombre d'évènements de la queue SQS que va traiter une lambda en une seule invocation.

La redrive_policy quant à elle détermine vers quelle dead letter queue renvoyer le message lorsqu’il a été présenté X fois à la lambda consommatrice.

Diffuser
La publication d’un évènement sur le BUS se fait via l’API AWS: putEvent.
Un sdk dans chaque langage utilisé par l'entreprise peut uniformiser l'écriture sur le BUS en signant et chiffrant la donnée, ainsi qu’en ajoutant les champs obligatoires.
Paramètres:
- KMS key de signature
- KMS key de chiffrement
- Payload en clair
- Champs à chiffrer

 

Traçage Xray
Définition d’une trace
Open image (2).png
image (2).png
La trace d'exécution sur la droite montre le cheminement d’un évènement envoyé par un utilisateur (bloc “client”) sur l’API gateway.

La lambda producer branchée à l’API reçoit l'évènement, elle utilise KMS pour chiffrer la donnée, puis envoie l'évènement sur le BUS eventbridge.

On voit ensuite qu’il y a 3 lambdas consommatrices de l'évènement en question: Target (Nodejs), Target2(python), Target3(php).

Les lambdas consommatrices utilisent à leur tour KMS pour déchiffrer l’information contenue dans l’event puis écrivent l'évènement dans dynamoDB.

 

:warning:  Comme le montre le cartographie, certains éléments du système n’apparaissent pas ( cf les liens en pointillés ). 
A la place des pointillés, devraient figurer une Queue SQS. 
Etant donné que la queue SQS est définie comme étant une target du BUS, AWS ne le modélise pas, c’est une limitation.

Vocabulaire
Une trace (rectangles sur le graphique) se compose de segments qui peuvent contenir des sous-segments.
Un segment peut se voir affecter des annotations et des méta-données.

Configurer le traçage
La plupart des services AWS disposent d’une capacité d’intégration avec XRAY.
Afin de s’assurer de générer une trace, il faut “capturer” les appels au SDK AWS pour que Xray intègre l’appel aux autres services cette trace.

Par exemple, au sein d’une lambda si je veux que les appels vers dynamoDB soient tracés, je dois capturer tous les appels au sdk de cette façon:



const dynamodbClient = AWSXRay.captureAWSv3Client( new DynamoDBClient({ region: 'eu-west-3' }))
Dès lors que je passe le client dynamoDb à Xray, tous les appels vers DDB au sein de cette lambda seront tracés.

Pareil avec S3:



const kmsClient = AWSXRay.captureAWSv3Client( new KMSClient({ region: 'eu-west-3' }))

Ce niveau de traçage est le niveau minimal → les traces ainsi générée ne contiennent que les informations déduites par AWS.

Pour ajouter de l’information aux traces il est possible et recommandé, d’utiliser le sdk XRAY pour:

créer des sous-segments

annoter des segments

ajouter des méta données aux segments

EXEMPLE:



const segment = AWSXRayCore.getSegment()
const subSegment = segment.addNewSubsegment('producer_meta_data')
subSegment.addAnnotation('user_ipv4', event.requestContext.identity.sourceIp)
Cas particulier les lambdas en PHP
Le runtime custom PHP ne permet pas le traçage de la même façon que les runtimes proposés à AWS.
En revanche il est possible d’utiliser OpenTelemetry, un standard de la télémétrie pour effectuer le traçage des requêtes.
Pour cela nous utilisons le framework GRPC pour communiquer avec le daemon opentelemetry collector.
Les informations de la trace sont générées en PHP, transmises au collecteur opentelemetry via grpc.

Exemple de tracage php → https://gitlab.app.l'entreprise.com/arc/poc/event-bus-load-test/-/blob/main/trz-bus-target3/Xray.php?ref_type=heads 

layer open telemetry collector → arn:aws:lambda:eu-west-3:901920570463:layer:aws-otel-collector-amd64-ver-0-68-0:1

layer grpc → arn:aws:lambda:eu-west-3:403367587399:layer:grpc-php-81:16

Overcost Xray
L’enregistrement de traces comporte un cout qui se calcule comme suit:

Comme l’indique le graphique précédent, un évènement publié génère un nombre de traces égale à  1 + 1*N (consommateurs)

Chaque trace coute 0,000005 USD.

Si on publie 10 millions d'évènements consommés en moyenne par 10 consommateurs

Alors nous générons un nombre de traces égal à : 10 millions + 10 millions * 10 soit 110 millions de traces

110 millions *  0,000005 USD = 550 USD

Récap:
Si nous publions 10 millions d'évènements consommés par 10 services, le cout d’enregistrement des traces est de 550 USD.
Ce calcul part de l’hypothèse que nous avons un taux d'échantillonnage de 100% (c’est à dire que tous les évènements sont tracés) - il est possible de réduire ce taux d'échantillonnage et donc de réduire proportionnellement le cout associé.

FAQ
Pourquoi EventBridge et pas SNS ?
Pour la bande passant importante nécéssaire au flux d'évènements l'entreprise

Pour la capacité de rejeu des évènements, et pour la capacité d’archivage.

Pour la diversité des targets disponibles.

Pour la capacité de rediriger les évènements cross accounts.

Quel est le process pour ajouter un évènement ?
Documenter l'évènement sur AsyncAPI - MR sur le repo

Une fois que l'évènement des documenté, le publier sur le bus en passant pas la lib du langage utilisé.

Quels évènements publier ?
tous les webhooks 

tout évènement que vous jugez utile

tout évènement permettant la traçabilité 

Uniquement des évènements ayant un impact idem potent

Qui est owner des règles et targets eventbridge ?
Chaque SQUAD consommateur d'évènement est en charge de développer ses règles et targets.
Chaque règle doit être documentée pour pouvoir être mise en commun ( par exemple 2 squad consomment le même évènement, alors elles utilisent la meme règle avec des targets différentes)

Qui est owner de la documentation asyncApi ?
Que faire des évènements
les traiter

les stocker un fois qu’ils sont traités avec succès

Peut-on rejouer les évènements ?
oui il est possible de renvoyer les évènements correspondant à une règle - c’est à dire ceux qui matchent un certain pattern.

Comment protéger la donnée ?
Il est important de limiter l’accès aux données sensibles aux resources légitimes.
Pour cela nous mettons en place un mécanisme de chiffrement via clé KMS.
Chaque évènement contient un champs encryptionKeyId et encryptedField.
La clé définie dans encryptionKeyId permet de déchiffre les champs listés dans encryptedField.
Cela implique de la ressources (target) qui va consommer l'évènement doit inclure dans son role, une policy lui permettant d’utiliser la clé encryptionKeyId.

Comment garantir qu’un évènement a été traité/pris en compte ?
Avec le système décrit dans la partie  écouter les events tout évènement ayant transité dans le bus ET correspondant à la règle définie se retrouvera soit dans la table dynamoDB soit dans la DLQ en fonction du résultat du traitement de l'évènement.

Je veux que N champs soient lisibles par X ressources et M autres champs lisibles par Y autres ressources.
Chaque évènement utilise une seule clé KMS de chiffrement pour les champs protégés.
Afin de diffuser un évènement contenant des champs lisibles par des ressources et d’autres champs lisibles par d’autres ressources il faut générer autant d'évènements qu’il y a de clé KMS nécessaires (ou de consommateur).

