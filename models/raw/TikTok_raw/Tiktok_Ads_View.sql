SELECT 
campaign_id, 
campaign_name, 
adgroup_id, 
adgroup_name, 
ad_id,
ad_name,
stat_time_day,
coalesce(video_views_p25,video_views_p25_in) video_views_p25, 
coalesce(video_views_p50,video_views_p50_in) video_views_p50,
coalesce(video_views_p75,video_views_p75_in) video_views_p75, 
coalesce(video_views_p100,video_views_p100_in) video_views_p100  
FROM (
select * from `murad-data-warehouse.BigQuery.Murad_US_TiktokAds_Ad_Report_Daily` 
qualify row_number() over(partition by stat_time_day,campaign_id,ad_id order by _daton_batch_runtime desc)=1
)
order by 3 desc