select distinct * from(SELECT
  PARSE_DATE('%Y/%m/%d', REPLACE(Date, '-', '/')) AS Date,
  round(SAFE_CAST(Subscribes AS NUMERIC),0) AS Subscribes,
  round(SAFE_CAST(Unsubscribes AS NUMERIC),0) AS Unsubscribes,
  round(SAFE_CAST(TotalMarketingSubscribers AS INTEGER),0) AS TotalMarketingSubscribers,row_number() over(partition by date order by  round(SAFE_CAST(Subscribes AS NUMERIC),0),round(SAFE_CAST(Unsubscribes AS NUMERIC),0),round(SAFE_CAST(TotalMarketingSubscribers AS INTEGER),0)) as rnk
FROM murad-data-warehouse.BigQuery.Attentive_Sub) where rnk=1