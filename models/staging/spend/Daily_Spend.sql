select base.*,
newc.New_cust new_cust,
coalesce(google_ads_spending,0) Google,
coalesce(meta_ads_spending,0) Meta,
coalesce(yt_ads_spending,0) YouTube,
coalesce(Affiliate_ads_spending,0) Affiliate,
coalesce(tiktok_ads_spending,0) TikTok,
coalesce(Bing_ads_spending,0) Bing,
coalesce(TTD_ads_spending,0) TTD, 
coalesce(google_ads_spending,0)+coalesce(meta_ads_spending,0)+coalesce(yt_ads_spending,0)+coalesce(Affiliate_ads_spending,0)+coalesce(Bing_ads_spending,0)+coalesce(tiktok_ads_spending,0)+coalesce(TTD_ads_spending,0) as Total_spend
from 
(select DATE(date) date,coalesce(sum(revenue),0) Overall_revenue_achieved from {{ ref('weekly_report_overall') }} where  platform='Non_Tiktok' group by 1) base 
left join  (select date(date) date,coalesce(sum(spend),0) meta_ads_spending from {{ ref('weekly_report_ads') }} where platform='Facebook Ads' group by 1 )fb on base.date=fb.date 
left join (select date(date) date,coalesce(sum(spend),0) google_ads_spending from {{ ref('weekly_report_ads') }} where platform='Google Ads' and strategy!='YouTube' group by 1 ) Gad on base.date=Gad.date
left join (select date(date) date,coalesce(sum(spend),0) yt_ads_spending from {{ ref('weekly_report_ads') }} where platform='Google Ads' and strategy='YouTube' group by 1 ) Yt on base.date=Yt.date
left join (
    SELECT date(eventdate) date ,sum(spend) Affiliate_ads_spending FROM {{ ref('Affiliate_spend') }} group by 1
    ) Af on base.date=af.date 
left join (select date(date) date,coalesce(sum(spend),0) Tiktok_ads_spending from {{ ref('Tiktok_spend') }}  group by 1 ) Tk on base.date=tk.date
left join (select date(date) date,coalesce(sum(spend),0) Bing_ads_spending from {{ ref('Bing') }} group by 1 ) bing on base.date=bing.date
left join (
  SELECT Date,sum(included_spend) TTD_ads_spending FROM `murad-data-warehouse.BigQuery.AffiliateTTDSpendFinl` where tier_1='Paid Display' group by 1
 ) TTD on base.date=TTD.date
left join (select date(order_created_at) date,count(distinct email) New_cust from {{ ref('BCAndShopifyData') }} where type='New' AND platform!='Tiktok' group by 1) newc on base.date=newc.date