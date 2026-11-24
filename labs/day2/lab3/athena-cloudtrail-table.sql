-- Lab 2.3 · Track B — Athena table over the ORG TRAIL bucket (from Lab 2.1)
-- Run in Athena (management account, us-east-1). Replace the three placeholders:
--   __BUCKET__   your org-trail bucket name
--   __ORG_ID__   o-xxxxxxxxxx   (aws organizations describe-organization)
--   __ACCOUNTS__ comma-separated account IDs to include, e.g. 111111111111,222222222222
-- Partition projection = no MSCK REPAIR, no crawler, partitions computed from the path.

CREATE DATABASE IF NOT EXISTS skyfortress;

CREATE EXTERNAL TABLE IF NOT EXISTS skyfortress.org_trail (
  eventversion STRING,
  useridentity STRUCT<
    type: STRING, principalid: STRING, arn: STRING, accountid: STRING, invokedby: STRING,
    accesskeyid: STRING, username: STRING,
    sessioncontext: STRUCT<
      attributes: STRUCT<mfaauthenticated: STRING, creationdate: STRING>,
      sessionissuer: STRUCT<type: STRING, principalid: STRING, arn: STRING, accountid: STRING, username: STRING>,
      sourceidentity: STRING>>,
  eventtime STRING,
  eventsource STRING,
  eventname STRING,
  awsregion STRING,
  sourceipaddress STRING,
  useragent STRING,
  errorcode STRING,
  errormessage STRING,
  requestparameters STRING,
  responseelements STRING,
  additionaleventdata STRING,
  requestid STRING,
  eventid STRING,
  readonly STRING,
  resources ARRAY<STRUCT<arn: STRING, accountid: STRING, type: STRING>>,
  eventtype STRING,
  apiversion STRING,
  recipientaccountid STRING,
  sharedeventid STRING,
  vpcendpointid STRING,
  eventcategory STRING,
  tlsdetails STRUCT<tlsversion: STRING, ciphersuite: STRING, clientprovidedhostheader: STRING>
)
PARTITIONED BY (account STRING, region STRING, `timestamp` STRING)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://__BUCKET__/AWSLogs/__ORG_ID__/'
TBLPROPERTIES (
  'projection.enabled' = 'true',
  'projection.account.type' = 'enum',
  'projection.account.values' = '__ACCOUNTS__',
  'projection.region.type' = 'enum',
  'projection.region.values' = 'us-east-1,us-west-2,eu-west-1,ap-southeast-1,sa-east-1',
  'projection.timestamp.type' = 'date',
  'projection.timestamp.format' = 'yyyy/MM/dd',
  'projection.timestamp.range' = '2026/01/01,NOW',
  'projection.timestamp.interval' = '1',
  'projection.timestamp.interval.unit' = 'DAYS',
  'storage.location.template' = 's3://__BUCKET__/AWSLogs/__ORG_ID__/${account}/CloudTrail/${region}/${timestamp}'
);
