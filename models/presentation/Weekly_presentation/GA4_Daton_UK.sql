select start_date,
 sessionDefaultChannelGroup, sessionSource, sessionMedium,
sum(cast(sessions as int64)) as sessions,sum(cast(netRevenue as int64)) as NetRevenue,
sum(keyeventspurchase) purchase from (select  
-- coalesce(cast(transactionId as string),cast(transactionId_in as string)) transactionId, 
sessionDefaultChannelGroup, sessionSource, sessionMedium, start_date,
coalesce(calcMetricnet_revenue, calcMetricnet_revenue_nu) netRevenue, sessions,COALESCE(CAST(keyeventspurchase AS INT64),0) keyeventspurchase
 from murad-data-warehouse.BigQuery.Murad_GA4_UK_332383456_GA4_UK
qualify row_number() over (partition by start_date,sessionDefaultChannelGroup,sessionMedium,sessionsource,transactionid order by _daton_batch_runtime desc) = 1)
group by 1,2,3,4