select tier_1,tier_2,tier_3,tier_4,cast(tier_5 as string) tier_5,date(day) as eventdate,coalesce(cast(spend_1 as int64),0) spend from murad-data-warehouse.BigQuery.Murad_US_Spend_DailySpend_Affiliate
union all
(
  WITH
  RankedRecords AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY commissionid ORDER BY _daton_batch_runtime DESC) AS rn
  FROM
    `murad-data-warehouse.BigQuery.Murad_US_COMMISSIONJUNCTION_Commission_Detail` ),
  base AS(
  SELECT
    _daton_user_id,
    _daton_batch_runtime,
    _daton_batch_id,
    actionstatus,
    actiontype,
    aid,
    commissionid,
    country,
    eventdate eventdate_string,
    FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S UTC', TIMESTAMP(eventdate), 'UTC') AS eventdate_utc,
    DATE(LEFT(eventdate,10)) eventdate,
    lockingdate,
    orderid,
    original,
    originalactionid,
    postingdate,
    websiteid,
    actiontrackerid,
    actiontrackername,
    cid,
    publishername,
    commissionamount,
    orderdiscount,
    saleamount,
    iscrossdevice
  FROM
    RankedRecords
  WHERE
    rn = 1)
SELECT
  'Affiliate' as tier_1,
  publishername as tier_2,
  'cj' as tier_3,
  CONCAT(cid, '-', websiteid) as tier_4,
  'null' as tier_5,
  eventdate,
  SUM(COALESCE(CAST(commissionamount AS numeric),0)) * (-1) Spend
FROM
  base
GROUP BY
  1,2,3,4,5,6
)

union all
(
  SELECT tier_1,tier_2,tier_3,tier_4,tier_5,Date,sum(included_spend) FROM `murad-data-warehouse.BigQuery.AffiliateTTDSpendFinl` where tier_1='Affiliate' and date>'2025-04-03' and date not between '2025-06-01' and '2025-08-31' group by 1,2,3,4,5,6
)