{{ config(enabled = False) }}

select StartDate,DATE_ADD(StartDate, INTERVAL 52 WEEK) DateThisYear,Murad_Marketing_Channel,sessions
 from murad-data-warehouse.GA3_Backup_queries.Murad_GA3_Backup_Acquisition where Marketplace='US'
-- select DATE_ADD(StartDate, INTERVAL 52 WEEK) DateThisYear,Murad_Marketing_Channel,sum(sessions
--  from murad-data-warehouse.GA3_Backup_queries.Murad_GA3_Backup_Acquisition where Marketplace='US' group by 1,2
