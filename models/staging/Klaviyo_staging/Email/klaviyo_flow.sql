SELECT
    distinct id ID,
    name Name,
    -- date(TIMESTAMP_SUB(CAST (updated as timestamp), INTERVAL 8 hour)) Send_Date,
    date
FROM (
    (SELECT
        a.id AS id,
        list.name AS name,
        -- list.created AS created,
        -- list.updated AS updated,
        -- a._daton_user_id AS _daton_user_id,
        -- a._daton_batch_runtime AS _daton_batch_runtime,
        -- a._daton_batch_id AS _daton_batch_id
    FROM
        murad-data-warehouse.BigQuery.Klaviyo_Integration_US_flows a
    LEFT JOIN
        UNNEST(a.attributes) list
    where list.name is not null
    QUALIFY
        DENSE_RANK() OVER (
            PARTITION BY a.id
            ORDER BY a._daton_batch_runtime DESC
        ) = 1)
    union all
    SELECT *
FROM UNNEST([
    STRUCT('UKAJSC' AS id, '*** Add_to_Cart_Cart_Abandon_15%_Offer ELEVAR' AS name),
    STRUCT('VnabJV' AS id, '*** Add_to_Cart_Cart_Abandon_Kits_New ELEVAR' AS name),
    STRUCT('Wc3zwe' AS id, '*** Browse_Abandonment _Standard ELEVAR' AS name),
    STRUCT('VVXRud' AS id, '*** Add_to_Cart_Cart_Abandon_15%_Offer (Retention)' AS name),
    STRUCT('VwPzKf' AS id, '*** Add_to_Cart_Cart_Abandon_Kits_New (Retention)' AS name),
    STRUCT('TGnG6f' AS id, '*** Browse_Abandonment _Standard (Retention)' AS name),
    STRUCT('RLxfrP' AS id, 'Browse_Abandon_Friends + Family - 25% off Sitewide - March 2025 Retention' AS name),
    STRUCT('VCsMEH' AS id, 'Cart_Abandon_Friends + Family - 25% off Sitewide - March 2025 Elevar' AS name),
    STRUCT('YADw5X' AS id, 'Cart_Abandon_Friends + Family - 25% off Sitewide - March 2025 Retention.com' AS name),
    STRUCT('Yd4emA' AS id, 'Session Abandonment Friends & Family March 2025 Retention' AS name),
    STRUCT('V3tf7z' AS id, 'Session Abandonment Friends & Family March 2025' AS name),
    STRUCT('WHRPVR' AS id, 'Checkout_Abandon_Friends + Family - 25% off Sitewide - March 2025' AS name),
    STRUCT('WvayYp' AS id, 'Browse_Abandon_Friends + Family - 25% off Sitewide - March 2025' AS name),

    -- STRUCT('SjhyCf' AS id, '*** Session Abandonment' AS name),
    STRUCT('Tv7beW' AS id, '*** Started_Checkout_Kits_New Shopify (Retention)' AS name),
    STRUCT('X9LhiY' AS id, 'Browse_Abandon_25% off $100 Sitewide - April 2025 Retention' AS name),
    STRUCT('UcwNWZ' AS id, 'Cart_Abandon_25% off $100 Sitewide - April 2025 Elevar' AS name),
    STRUCT('XMXQ2j' AS id, 'Cart_Abandon_25% off $100 Sitewide - April 2025 Retention.com' AS name),
    STRUCT('VLfrw2' AS id, 'Checkout_Abandon_25% off $100 Sitewide - April 2025' AS name),
    STRUCT('XjnN2F' AS id, 'Session Abandonment 25% off $100 April 2025' AS name),
    STRUCT('X52wVB' AS id, 'Session Abandonment 25% off $100 April 2025 Retention' AS name),
    STRUCT('Wmi3Da' AS id, 'Subscriptions Free Gift Notification' AS name),
    STRUCT('U97NZu' AS id, 'Transactional - CustomerCareOrder Confirmation5' AS name),
    STRUCT('VqLv9J' AS id, 'Skin Analysis/Quiz Results 2025' AS name),

    STRUCT('UcbB4t' AS id, 'Cart_Abandon_25% off $100 Memorial - May 2025 Elevar' AS name),
    STRUCT('UE9Y6D' AS id, 'Browse_Abandon_25% off $100 Memorial - May 2025' AS name),
    STRUCT('T4Lmq2' AS id, 'Session Abandonment 25% off $100 Memorial May 2025' AS name),

    STRUCT('U6xG6Q' AS id, 'Checkout_Abandon_25% off $100 Sitewide_Memorial Day - May 2025' AS name),
    STRUCT('XuZnQA' AS id, 'Price Drop Notification - Standard (Email or SMS)' AS name)
])
)

CROSS JOIN

(SELECT 
date_value AS date
FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates 