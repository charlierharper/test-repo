create or replace view ams.vw_mccormick_combined_monthly_report
as
 (with cte_segmentation as

           (Select vwcs.campaignid
                 , max(CASE




                           WHEN vwcs.segmentation_type = 'IO Segment' THEN vwcs.segmentation_value
                           ELSE NULL
                   END) AS io_segmentation
                 , max(CASE
                           WHEN vwcs.segmentation_type = 'Brand' THEN vwcs.segmentation_value
                           ELSE NULL
                   END) AS brand_segmentation

                 , max(CASE
                           WHEN vwcs.segmentation_type = 'Item' THEN vwcs.segmentation_value
                           ELSE NULL
                   END) AS item_segmentation
            from walmart.vw_walmart_campaign_segmentation vwcs
            group by 1)
  select 'Walmart'                                as platform,
         to_char(bd.formatted_date, 'YYYY-MM-DD') as date,
         brand_segmentation                       as brand,
         item_segmentation                        as "UPC|ASIN|ItemID",
         wc.campaign_name                         as "asin|adgroup|campaign_name",
         sum(adspend)                             as spend,
         sum(numadsclicks)                        as clicks,
         sum(numadsshown)                         as impressions,
         (sum(viewrevenue14d)
             + sum(clickrevenue14d)
             + sum(relatedclickrevenue14d)
             + sum(brandclickrevenue14d)
             + sum(brandviewrevenue14d)
             + sum(offlineclickrevenue14d)
             )                                    as sales,
         sum(unitssold14d)                        as units_sold
         --from walmart.vw_campaign_monthly
  from walmart.byday_mtly bd
           join walmart.dim_walmart_campaign wc on wc.id = bd.campaignid
      and wc.is_deleted = 'N'
      and wc.is_active = 'Y'
           join walmart.t_business_unit_advertiser bua on wc.advertiserid_fk = bua.advertiser_id
           join ams.t_business_unit e ON e.id = bua.business_unit_id
      and e.is_deleted = 'N'
           join walmart.base_lookups bl on bd.campaigntypeid = bl.id
           join walmart.base_lookups bl2 on wc.targeting_type_id = bl2.id
           left join cte_segmentation cs on bd.campaignid = cs.campaignid
  where e.name = 'McCormick'
    and bd.formatted_date >= date_trunc('month', getdate()-'1 month'::interval)
    and bd.formatted_date < date_trunc('month', getdate())
  group by bd.formatted_date, brand_segmentation, item_segmentation, wc.campaign_name
     --order by bd.formatted_date DESC
 )

 union all

 -- IC
 -----------------------------------------
 (with cmpsegmentation
           as
           (
               Select cs.adgroupid
                    , cs.adgroup_name
                    , max(CASE
                              WHEN cs.segmentation_type = 'UPC' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS upc_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'Brand' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS brand_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'IO Segment' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS io_segmentation
               From instacart.vw_instacart_adgroup_segmentation cs
               group by cs.adgroupid, cs.adgroup_name
           )
  select 'Instacart'                              as platform,
         to_char(cm.formatted_date, 'YYYY-MM-DD') as date,
         CA.brand_segmentation                    as brand,
         CA.upc_segmentation                      as "UPC|ASIN|ItemID",
         a.adgroup_name                           as "asin|adgroup|campaign_name",
         sum(cm.spend)                            as spend,
         sum(cm.clicks)                           as clicks,
         sum(cm.impressions)                      as impressions,
         sum(cm.sales)                            as sales,
         sum(attributed_quantities)               as units_sold
  from instacart.adgroup_mtly cm
           join instacart.dim_instacart_adgroup a on a.id = cm.adgroupid
           join instacart.dim_instacart_account IA
                on IA.id = cm.accountid_fk
                    and IA.id = 5
           join cmpsegmentation CA on CA.adgroupid = cm.adgroupid
  where
    cm.formatted_date >= date_trunc('month', getdate()-'1 month'::interval)
    and cm.formatted_date < date_trunc('month', getdate())
    and io_segmentation = 'McCormick'
  group by IA.name,
           cm.formatted_date,
           CA.upc_segmentation,
           CA.brand_segmentation, a.adgroup_name)

 union all

 -- AMZ
 ----------------------------------------------
 (with cmpsegmentation
           as
           (
               Select cs.campaignid
                    , cs.campaign_name
                    , max(CASE
                              WHEN cs.segmentation_type = 'ASIN' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS asin_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'Brand' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS brand_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'Category' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS category_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'Custom Segment' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS custom_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'IO Segment' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS io_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'SubBrand' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS subbrand_segmentation
                    , max(CASE
                              WHEN cs.segmentation_type = 'Targeting Type' THEN cs.segmentation_value
                              ELSE NULL
                   END) AS targeting_type
               From ams.vw_campaign_segmentation cs
               group by cs.campaign_name, cs.campaignid
           )
  select 'Amazon'                                as platform
       , to_char(f.formatted_date, 'YYYY-MM-DD') as date
       , ca.brand_segmentation                   as brand
       , ta.asin                                 as "UPC|ASIN|ItemID"
       , ta.asin_title                           as "asn|adgroup|campaign_name"
       , sum(f.spend)                            as spend
       , sum(f.clicks)                           as clicks
       , sum(f.impressions)                      as impressions
       , sum(f.sales)                            as sales
       , sum(f.unitssold14d)                     as units_sold
  FROM ams.amscmp_mtly f
           JOIN ams.t_client C
                ON F.clientid = C.id
                    AND C.is_deleted = 'N'
                    AND C.name = 'McCormick'
           JOIN ams.t_country CT
                ON F.countryid = CT.id
                    AND CT.is_deleted = 'N'
                    AND CT.code = 'US'
           JOIN ams.t_claim CL
                ON F.ClaimId = CL.id
                    AND CL.is_deleted = 'N'
           JOIN ams.base_lookups BL
                ON F.campaigntypeid = BL.id
                    AND BL.lookupcatid = 610012
           JOIN cmpsegmentation CA
                ON F.campaignid = CA.campaignid
           JOIN ams.t_asin ta ON ca.asin_segmentation = ta.asin
      AND ta.is_active = 'Y'
      AND ta.is_deleted = 'N'
  where ca.io_segmentation in
        ('Condiments', 'Kitchen Basics', 'Seasonings', 'Thai Kitchen / SAF / IE', 'Zatarain''s', 'Food Service')
    and f.formatted_date >= date_trunc('month', getdate()-'1 month'::interval)
    and f.formatted_date < date_trunc('month', getdate())
  group by ta.asin, ca.brand_segmentation, f.formatted_date, ta.asin_title
 )
 WITH NO SCHEMA BINDING;