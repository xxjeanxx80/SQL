/* ==============================================================================
   FILE 4: SOURCE-TO-TARGET DATA RECONCILIATION SUITE
   Mục đích: Đối soát toàn diện Nguồn - Đích bằng kỹ thuật:
   - Mẹo 3: So sánh Count & Distinct Count trên 1 dòng đơn giản (Không cần UNION)
   - Mẹo 2: Kỹ thuật đối chiếu Nguồn - Đích từng cột bằng cách bôi đen
            (FULL JOIN + Dấu phẩy đặt trước "-- ," giúp mở cột nào cũng không bao giờ bị lỗi cú pháp)
   - Mẹo 1: Ad-hoc Sanity Check trên Target (WHERE 1=1 + Toggle)
============================================================================== */

DECLARE @BUSINESS_DATE DATE = '2026-09-16';

-- ==============================================================================
-- BƯỚC CHUẨN BỊ: BẢNG NGUỒN EXPECTED (#map_final) ĐƯỢC TÍNH TOÁN ĐỘC LẬP TỪ BRD
-- ==============================================================================
DROP TABLE IF EXISTS #map_final;
SELECT 
    c.RECID,
    c.CUS_NAME,
    'AF' AS SEGMENT,
    'T24 AUTO' AS AF_CHANNEL,
    c.VIP_CODE AS OLD_VIP_TYPE,
    CAST(NULL AS VARCHAR(20)) AS VIP_INFOR,
    CAST(NULL AS VARCHAR(20)) AS RE_ASSET,
    CAST(NULL AS VARCHAR(20)) AS ID_FLAG,
    CASE 
        WHEN fin.aum_af_group >= 5000000000 OR fin.casa_af_group >= 500000000 THEN 'AF-Private'
        WHEN fin.aum_af_group >= 1000000000 OR fin.casa_af_group >= 150000000 THEN 'AF-Preferred'
        WHEN toi.AVG_TOI >= 1800000 THEN 'AF-Special'
    END AS VIP_TYPE,
    CASE 
        WHEN fin.aum_af_group >= 5000000000 OR fin.casa_af_group >= 500000000 
            THEN 'AF-' + CASE WHEN fin.aum_af_group >= 5000000000 THEN 'AUM' ELSE 'CASA' END
        WHEN fin.aum_af_group >= 1000000000 OR fin.casa_af_group >= 150000000 
            THEN 'AF-' + CASE WHEN fin.aum_af_group >= 1000000000 THEN 'AUM' ELSE 'CASA' END
        WHEN toi.AVG_TOI >= 1800000 THEN 'AF_TOI'
    END AS VIP_GROUP,
    CASE 
        WHEN fin.aum_af_group >= 5000000000 THEN 'AUM'
        WHEN fin.casa_af_group >= 500000000 THEN 'CASA'
        WHEN fin.aum_af_group >= 1000000000 THEN 'AUM'
        WHEN fin.casa_af_group >= 150000000 THEN 'CASA'
        ELSE NULL 
    END AS CN_CHUYENGIAO,
    COALESCE(fin.VALID_DEPT, c.COMPANY_BOOK, c.PROVINCE_CITY) AS CNUT,
    COALESCE(td.DAO, bond.DAO, 'ROUND_ROBIN') AS DAO_RM
INTO #map_final
FROM DEV_DEST_DF.dbo.VPB_CUSTOMER c
LEFT JOIN (
    SELECT a1.customer, a1.aum_af_group, a1.casa_af_group, af.department_code AS VALID_DEPT
    FROM DEV_DEST_DF.dbo.vpb_aum_casa_T30 a1
    JOIN DEV_DEST_DF.dbo.vpb_aum_casa_co_code_T30 c1 ON a1.customer = c1.customer AND a1.business_date = c1.business_date
    LEFT JOIN DEV_DEST_DF.dbo.AF_BOOK af ON c1.co_code = af.department_code
    WHERE a1.business_date = @BUSINESS_DATE
) fin ON c.RECID = fin.customer
LEFT JOIN (
    SELECT t.CUSTOMER_ID, SUM(t.TOI) / 3.0 AS AVG_TOI
    FROM DEV_DEST_DF.dbo.TBL_TOI_AF_ADB_3M t
    JOIN DEV_DEST_DF.dbo.efz_vpb_customer sub ON t.CUSTOMER_ID = sub.ID
    WHERE sub.SUB_SEGMENT <> 'HBS'
      AND CAST(t.BUSINESS_DATE AS DATE) BETWEEN EOMONTH(DATEADD(MONTH, -3, @BUSINESS_DATE)) 
                                            AND EOMONTH(DATEADD(MONTH, -1, @BUSINESS_DATE))
    GROUP BY t.CUSTOMER_ID
    HAVING SUM(t.TOI) / 3.0 > 1800000
) toi ON c.RECID = toi.CUSTOMER_ID
LEFT JOIN (
    SELECT cif, DAO, ROW_NUMBER() OVER(PARTITION BY cif ORDER BY CREATE_DATE DESC) AS rn
    FROM DEV_DEST_DF.dbo.VPB_RPT_ACCT_BAL WHERE CLOSING_BAL > 0 AND DAO IS NOT NULL
) td ON c.RECID = td.cif AND td.rn = 1
LEFT JOIN (
    SELECT customer, DAO, ROW_NUMBER() OVER(PARTITION BY customer ORDER BY VALUE_DATE DESC) AS rn
    FROM DEV_DEST_DF.dbo.TBL_EFZ_CCQ_TP WHERE K_TYPE = 'TP' AND PRINCIPAL_AMOUNT > 0 AND DAO IS NOT NULL
) bond ON c.RECID = bond.customer AND bond.rn = 1
WHERE 1=1
  AND c.SEGMENT = 'KHCN'
  AND c.business_date = @BUSINESS_DATE
  AND ISNULL(c.RE_ASSET_AF, '') NOT LIKE '%DENY%'
  AND c.CUS_NAME NOT LIKE '%KHONG SU DUNG%'
  AND c.CUS_NAME NOT LIKE '%KHONGSUDUNG%'
  AND c.CUS_NAME NOT LIKE '%NO NAME%'
  AND c.CUS_NAME NOT LIKE '%NONAME%'
  AND c.CUS_NAME NOT LIKE '%KHONG SD%'
  AND c.CUS_NAME NOT LIKE '%KHONG GIAO DICH%'
  AND c.LEGAL_ID NOT LIKE '%KHONG-SU-DUNG%'
  AND c.LEGAL_ID NOT LIKE '%KHONGSUDUNG%'
  AND (fin.aum_af_group >= 1000000000 OR fin.casa_af_group >= 150000000 OR toi.AVG_TOI >= 1800000);


-- ==============================================================================
-- MẸO 3: SO SÁNH COUNT & DISTINCT COUNT TRÊN 1 DÒNG ĐƠN GIẢN (BÔI ĐEN CHẠY)
-- ==============================================================================
SELECT 
    (SELECT COUNT(*) FROM #map_final) AS count_src,
    (SELECT COUNT(*) FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION WHERE BUSINESS_DATE = @BUSINESS_DATE) AS count_tgt,
    (SELECT COUNT(DISTINCT RECID) FROM #map_final) AS dist_src,
    (SELECT COUNT(DISTINCT RECID) FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION WHERE BUSINESS_DATE = @BUSINESS_DATE) AS dist_tgt
;


-- ==============================================================================
-- MẸO 2: KỸ THUẬT ĐỐI CHIẾU NGUỒN - ĐÍCH TỪNG CỘT BẰNG CÁCH BÔI ĐEN
-- (Dấu phẩy đặt trước "-- ," giúp mở cột nào cũng không bao giờ bị lỗi cú pháp)
-- ==============================================================================
SELECT 
    COALESCE(src.RECID, tgt.RECID) AS RECID,
    
    -- 1. Check tệp bản ghi (Missing / Extra)
    CASE 
        WHEN tgt.RECID IS NULL THEN 'MISSING (Co nguon, mat dich)'
        WHEN src.RECID IS NULL THEN 'EXTRA (Khong co nguon, thua o dich)'
        ELSE 'MATCHED_KEY'
    END AS CHECK_KEY
    
    -- 2. Check VIP_TYPE (Bôi đen 2 dòng dưới để chạy)
    -- , src.VIP_TYPE AS SRC_VIP, tgt.VIP_TYPE AS TGT_VIP
    -- , CASE WHEN ISNULL(src.VIP_TYPE,'') = ISNULL(tgt.VIP_TYPE,'') THEN 1 ELSE 0 END AS MATCH_VIP
    
    -- 3. Check VIP_GROUP (Bôi đen 2 dòng dưới để chạy)
    -- , src.VIP_GROUP AS SRC_GROUP, tgt.VIP_GROUP AS TGT_GROUP
    -- , CASE WHEN ISNULL(src.VIP_GROUP,'') = ISNULL(tgt.VIP_GROUP,'') THEN 1 ELSE 0 END AS MATCH_GROUP

    -- 4. Check CN_CHUYENGIAO (Bôi đen 2 dòng dưới để chạy)
    -- , src.CN_CHUYENGIAO AS SRC_CN_CHUYENGIAO, tgt.CN_CHUYENGIAO AS TGT_CN_CHUYENGIAO
    -- , CASE WHEN ISNULL(src.CN_CHUYENGIAO,'') = ISNULL(tgt.CN_CHUYENGIAO,'') THEN 1 ELSE 0 END AS MATCH_CN_CHUYENGIAO

    -- 5. Check CNUT (Bôi đen 2 dòng dưới để chạy)
    -- , src.CNUT AS SRC_CNUT, tgt.CNUT AS TGT_CNUT
    -- , CASE WHEN ISNULL(src.CNUT,'') = ISNULL(tgt.CNUT,'') THEN 1 ELSE 0 END AS MATCH_CNUT

    -- 6. Check DAO_RM (Bôi đen 2 dòng dưới để chạy)
    -- , src.DAO_RM AS SRC_DAO, tgt.DAO_RM AS TGT_DAO
    -- , CASE WHEN ISNULL(src.DAO_RM,'') = ISNULL(tgt.DAO_RM,'') THEN 1 ELSE 0 END AS MATCH_DAO

    -- 7. Check SEGMENT (Bôi đen 2 dòng dưới để chạy)
    -- , src.SEGMENT AS SRC_SEGMENT, tgt.SEGMENT AS TGT_SEGMENT
    -- , CASE WHEN ISNULL(src.SEGMENT,'') = ISNULL(tgt.SEGMENT,'') THEN 1 ELSE 0 END AS MATCH_SEGMENT

    -- 8. Check AF_CHANNEL (Bôi đen 2 dòng dưới để chạy)
    -- , src.AF_CHANNEL AS SRC_CHANNEL, tgt.AF_CHANNEL AS TGT_CHANNEL
    -- , CASE WHEN ISNULL(src.AF_CHANNEL,'') = ISNULL(tgt.AF_CHANNEL,'') THEN 1 ELSE 0 END AS MATCH_CHANNEL

FROM #map_final src
FULL JOIN VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
       ON src.RECID = tgt.RECID
      AND tgt.BUSINESS_DATE = @BUSINESS_DATE
WHERE 1=1
  -- === BỘ LỌC TÌM LỖI (Bật/tắt bằng cách bỏ dấu --) ===
  -- AND (src.RECID IS NULL OR tgt.RECID IS NULL)                     -- Chi loc ra tap lech ban ghi
  -- AND ISNULL(src.VIP_TYPE, '') <> ISNULL(tgt.VIP_TYPE, '')        -- Chi loc nhung dong sai VIP_TYPE
  -- AND ISNULL(src.VIP_GROUP, '') <> ISNULL(tgt.VIP_GROUP, '')      -- Chi loc nhung dong sai VIP_GROUP
  -- AND ISNULL(src.CN_CHUYENGIAO, '') <> ISNULL(tgt.CN_CHUYENGIAO, '') -- Chi loc sai Kênh chuyển giao
  -- AND ISNULL(src.CNUT, '') <> ISNULL(tgt.CNUT, '')                -- Chi loc sai Chi nhánh CNUT
  -- AND ISNULL(src.DAO_RM, '') <> ISNULL(tgt.DAO_RM, '')            -- Chi loc sai DAO_RM
;
