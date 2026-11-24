-- =====================================================================
-- Skyfortress HUNT PACK · Amazon Security Lake (OCSF) via Athena (Track A)
-- Default names for Security Lake source version 2 (OCSF 1.1) in us-east-1:
--   database: amazon_security_lake_glue_db_us_east_1
--   table:    amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0
-- Field names follow OCSF. Run this first and adjust if your schema differs:
--   DESCRIBE amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0;
-- Source version 2 tables are Apache Iceberg: filter on time_dt and Athena prunes the
-- date partitions for you (eventday/accountid/region were the version 1 partition columns).
-- Always put a time_dt bound in every hunt, or you scan the whole lake.
-- =====================================================================

-- H0 · Sanity: today's API activity by service
SELECT api.service.name AS service, count(*) AS n
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0"
WHERE time_dt >= current_timestamp - INTERVAL '1' DAY
GROUP BY 1 ORDER BY n DESC LIMIT 25;

-- H1 · AccessDenied storms
SELECT actor.user.uid                    AS principal_id,
       actor.session.issuer              AS role_arn,
       count(*)                          AS denied,
       array_agg(DISTINCT api.operation) AS apis
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0"
WHERE time_dt >= current_timestamp - INTERVAL '1' DAY
  AND status = 'Failure'
  AND api.response.error IN ('AccessDenied', 'Client.UnauthorizedOperation', 'AccessDeniedException')
GROUP BY 1, 2
ORDER BY denied DESC LIMIT 20;

-- H2 · Secret readers
SELECT actor.user.uid AS principal_id, api.operation, count(*) AS n,
       min(time_dt) AS first_seen, max(time_dt) AS last_seen
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0"
WHERE time_dt >= current_timestamp - INTERVAL '1' DAY
  AND api.service.name = 'secretsmanager.amazonaws.com'
  AND api.operation = 'GetSecretValue'
GROUP BY 1, 2 ORDER BY n ASC;

-- H3 · Rare user agents
SELECT http_request.user_agent AS ua, count(*) AS n, count(DISTINCT actor.user.uid) AS principals
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0"
WHERE time_dt >= current_timestamp - INTERVAL '1' DAY
GROUP BY 1 ORDER BY n ASC LIMIT 15;

-- H4 · Region hopping
SELECT actor.user.uid AS principal_id, count(DISTINCT cloud.region) AS regions,
       array_agg(DISTINCT cloud.region) AS which
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0"
WHERE time_dt >= current_timestamp - INTERVAL '1' DAY
GROUP BY 1 HAVING count(DISTINCT cloud.region) >= 3
ORDER BY regions DESC;

-- H5 · One session's timeline (principal_id for a role session is "AROA…:<session-name>")
SELECT time_dt, cloud.region, api.service.name, api.operation, api.response.error,
       src_endpoint.ip, http_request.user_agent
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0"
WHERE time_dt >= current_timestamp - INTERVAL '1' DAY
  AND actor.user.uid LIKE '%:SESSION_NAME_HERE'
ORDER BY time_dt;
