select start_date,
 sessionDefaultChannelGroup, sessionSource, sessionMedium,
-- count(distinct transactionId) orders,
sum(keyeventspurchase ) Purchase,
sum(cast(sessions as int64)) as sessions,sum(cast(netRevenue as int64)) as NetRevenue from (select  coalesce(cast(transactionId as string),cast(transactionId_st as string),cast(transactionId_nu as string)) transactionId, sessionDefaultChannelGroup, sessionSource, sessionMedium, start_date,
coalesce(calcMetricnet_revenue, calcMetricnet_revenue_in) netRevenue, sessions,keyeventspurchase
 from murad-data-warehouse.BigQuery.Murad_GA4_Daton_AU_334821383_GA4_AU
qualify row_number() over (partition by start_date,sessionDefaultChannelGroup,sessionMedium,sessionsource,transactionid order by _daton_batch_runtime desc) = 1)
group by 1,2,3,4