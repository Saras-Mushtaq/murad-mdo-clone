{{ config(enabled = False) }}

select `Session Murad Marketing Channels`,PARSE_DATE('%Y%m%d', date) as Date,Sessions,Transactions,`Net revenue`
 from murad-data-warehouse.BigQuery.GA4_Historical_Data_Jan24ToOct24
