-- =====================================================================
-- Skyfortress HUNT PACK · raw CloudTrail via Athena (Track B)
-- Table: skyfortress.org_trail  (see athena-cloudtrail-table.sql)
-- Always constrain the partition columns (account, region, timestamp) — it's
-- the difference between scanning 5 MB and 5 TB.
-- =====================================================================

-- H0 · Sanity: what happened today, by service?
SELECT eventsource, count(*) AS n
FROM skyfortress.org_trail
WHERE "timestamp" = date_format(current_date, '%Y/%m/%d')
GROUP BY 1 ORDER BY n DESC LIMIT 25;

-- H1 · AccessDenied storms (ATT&CK T1580 / T1087 — discovery by trial and error)
-- Hypothesis: a principal probing for permissions it doesn't have racks up denials.
SELECT useridentity.arn                         AS principal,
       count(*)                                 AS denied,
       count(DISTINCT eventname)                AS distinct_apis,
       array_agg(DISTINCT eventname)            AS apis
FROM skyfortress.org_trail
WHERE "timestamp" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
  AND errorcode IN ('AccessDenied', 'Client.UnauthorizedOperation', 'AccessDeniedException')
GROUP BY 1
ORDER BY denied DESC LIMIT 20;

-- H2 · Who read which secret? (ATT&CK T1555.006)
SELECT useridentity.arn                                       AS principal,
       json_extract_scalar(requestparameters, '$.secretId')   AS secret,
       count(*)                                               AS reads,
       min(eventtime) AS first_seen, max(eventtime) AS last_seen
FROM skyfortress.org_trail
WHERE "timestamp" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
  AND eventsource = 'secretsmanager.amazonaws.com'
  AND eventname = 'GetSecretValue'
GROUP BY 1, 2
ORDER BY reads ASC;

-- H3 · Rare user agents — "least frequency of occurrence" stacking
SELECT useragent, count(*) AS n, count(DISTINCT useridentity.arn) AS principals
FROM skyfortress.org_trail
WHERE "timestamp" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
  AND useridentity.type = 'AssumedRole'
GROUP BY 1
ORDER BY n ASC LIMIT 15;

-- H4 · Region hopping — one session, many regions, in minutes (ATT&CK T1535 / T1580)
SELECT useridentity.arn            AS principal,
       count(DISTINCT awsregion)   AS regions,
       array_agg(DISTINCT awsregion) AS which
FROM skyfortress.org_trail
WHERE "timestamp" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
GROUP BY 1
HAVING count(DISTINCT awsregion) >= 3
ORDER BY regions DESC;

-- H5 · Reconstruct one session's full story (swap in the ARN you found)
SELECT eventtime, awsregion, eventsource, eventname, errorcode, sourceipaddress, useragent
FROM skyfortress.org_trail
WHERE "timestamp" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
  AND useridentity.arn LIKE '%/nimbus-ops-hunt-role/%SESSION_NAME_HERE%'
ORDER BY eventtime;
