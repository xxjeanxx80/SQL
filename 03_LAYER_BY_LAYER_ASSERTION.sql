/* ==============================================================================
   FILE 3: LAYER-BY-LAYER ASSERTION SUITE - TASK EDAPCP-35281
   Mục đích: Đối soát tự động kết quả trên Target đối chiếu với Ma trận Test Case (#TEST_CASE_MATRIX)
   từ File 1, kiểm tra độ chính xác từ Tầng 1 -> Tầng 5:
             - Assertion 1 (Tầng 1): Bad Ending Check (Kỳ vọng 0 bản ghi lọt vào Target)
             - Assertion 2 (Tầng 2): VIP Type & VIP Group & Quy tắc bất biến Special
             - Assertion 3 (Tầng 3): Fallback Chi nhánh ưu tiên (UT1 -> UT2 -> UT3 -> UT4)
             - Assertion 4 (Tầng 4): Chuỗi ưu tiên gán DAO/RM (TD > BOND > CCQ > CA > EKASH > MJ > Round Robin)
             - Assertion 5 (Tầng 5): Chuẩn hóa CN_CHUYENGIAO & Các trường cấm rác
             - Tổng kết Scorecard: Dashboard tự động tính PASSED / FAILED theo từng Case ID
============================================================================== */

DECLARE @BUSINESS_DATE DATE = '2026-09-16';

-- ==============================================================================
-- ASSERTION 1 (TẦNG 1): TẤT CẢ CÁC CA BAD ENDING TUYỆT ĐỐI KHÔNG ĐƯỢC CÓ MẶT Ở TARGET
-- Kỳ vọng: 0 bản ghi (Nếu có bản ghi xuất hiện -> Lọt Blacklist / Lỗi Tầng 1)
-- ==============================================================================
PRINT '====================================================================';
PRINT '>>> ASSERTION 1 (TẦNG 1): KIỂM TRA CHẶN BAD ENDING & DATA CLEANING...';
PRINT '====================================================================';

SELECT 
    tgt.RECID,
    tgt.CUS_NAME,
    m.CASE_GROUP,
    m.DESCRIPTION AS REASON_SHOULD_BE_EXCLUDED,
    'BUG: Khách hàng vi phạm nhưng vẫn lọt vào Target!' AS BUG_ALERT
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
JOIN #TEST_CASE_MATRIX m ON tgt.RECID = m.CASE_ID
WHERE 1=1
  AND tgt.BUSINESS_DATE = @BUSINESS_DATE
  AND m.EXPECTED_OUTCOME = 'REJECTED';


-- ==============================================================================
-- ASSERTION 2 (TẦNG 2): KIỂM TRA PHÂN HẠNG VIP & PHÂN KHÚC SPECIAL
-- ==============================================================================
PRINT '====================================================================';
PRINT '>>> ASSERTION 2 (TẦNG 2): KIỂM TRA PHÂN HẠNG VIP & VIP_GROUP...';
PRINT '====================================================================';

-- 2.1 So khớp VIP_TYPE & VIP_GROUP thực tế vs Kỳ vọng
SELECT 
    m.CASE_ID,
    m.DESCRIPTION        AS TEST_SCENARIO,
    tgt.VIP_TYPE         AS ACTUAL_VIP_TYPE,
    m.EXPECTED_VIP_TYPE  AS EXPECTED_VIP_TYPE,
    tgt.VIP_GROUP        AS ACTUAL_VIP_GROUP,
    m.EXPECTED_GROUP     AS EXPECTED_VIP_GROUP,
    CASE 
        WHEN tgt.VIP_TYPE = m.EXPECTED_VIP_TYPE 
         AND ISNULL(tgt.VIP_GROUP, '') = ISNULL(m.EXPECTED_GROUP, '') 
        THEN 'PASSED'
        ELSE 'FAILED - WRONG VIP TYPE/GROUP'
    END AS TEST_STATUS
FROM #TEST_CASE_MATRIX m
LEFT JOIN VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt 
    ON m.CASE_ID = tgt.RECID AND tgt.BUSINESS_DATE = @BUSINESS_DATE
WHERE m.EXPECTED_OUTCOME = 'IN_TARGET';

-- 2.2 Kiểm tra luật bất biến của nhóm Special:
-- Special thì bắt buộc CN_CHUYENGIAO IS NULL và VIP_GROUP = 'AF_TOI'
SELECT 
    tgt.RECID,
    tgt.VIP_TYPE,
    tgt.VIP_GROUP,
    tgt.CN_CHUYENGIAO,
    'VI PHẠM QUY TẮC NHÓM SPECIAL: CN_CHUYENGIAO phải NULL và VIP_GROUP phải là AF_TOI' AS BUG_DESCRIPTION
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
WHERE 1=1
  AND tgt.BUSINESS_DATE = @BUSINESS_DATE
  AND tgt.VIP_TYPE = 'AF-Special'
  AND (tgt.CN_CHUYENGIAO IS NOT NULL OR tgt.VIP_GROUP <> 'AF_TOI');


-- ==============================================================================
-- ASSERTION 3 (TẦNG 3): KIỂM TRA FALLBACK CHI NHÁNH (UT1 -> UT2 -> UT3 -> UT4)
-- ==============================================================================
PRINT '====================================================================';
PRINT '>>> ASSERTION 3 (TẦNG 3): KIỂM TRA FALLBACK CHI NHÁNH ƯU TIÊN (CNUT)...';
PRINT '====================================================================';

SELECT 
    m.CASE_ID,
    m.DESCRIPTION        AS TEST_SCENARIO,
    tgt.CNUT             AS ACTUAL_CNUT,
    m.EXPECTED_CNUT      AS EXPECTED_CNUT,
    CASE 
        WHEN tgt.CNUT = m.EXPECTED_CNUT THEN 'PASSED'
        ELSE 'FAILED - WRONG BRANCH FALLBACK'
    END AS TEST_STATUS
FROM #TEST_CASE_MATRIX m
LEFT JOIN VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt 
    ON m.CASE_ID = tgt.RECID AND tgt.BUSINESS_DATE = @BUSINESS_DATE
WHERE m.EXPECTED_CNUT IS NOT NULL;


-- ==============================================================================
-- ASSERTION 4 (TẦNG 4): KIỂM TRA THỨ TỰ ƯU TIÊN GÁN DAO/RM
-- ==============================================================================
PRINT '====================================================================';
PRINT '>>> ASSERTION 4 (TẦNG 4): KIỂM TRA CHUỖI ƯU TIÊN GÁN DAO/RM QUẢN LÝ...';
PRINT '====================================================================';

SELECT 
    m.CASE_ID,
    m.DESCRIPTION        AS TEST_SCENARIO,
    tgt.DAO_RM           AS ACTUAL_DAO_RM,
    m.EXPECTED_DAO       AS EXPECTED_DAO,
    CASE 
        WHEN tgt.DAO_RM = m.EXPECTED_DAO THEN 'PASSED'
        ELSE 'FAILED - WRONG DAO PRIORITY'
    END AS TEST_STATUS
FROM #TEST_CASE_MATRIX m
LEFT JOIN VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt 
    ON m.CASE_ID = tgt.RECID AND tgt.BUSINESS_DATE = @BUSINESS_DATE
WHERE m.EXPECTED_DAO IS NOT NULL;


-- ==============================================================================
-- ASSERTION 5 (TẦNG 5): KIỂM TRA CHUẨN HÓA TRƯỜNG TARGET & DATA INTEGRITY
-- ==============================================================================
PRINT '====================================================================';
PRINT '>>> ASSERTION 5 (TẦNG 5): KIỂM TRA CHUẨN HÓA CỘT TARGET (CN_CHUYENGIAO, CỘT RÁC)...';
PRINT '====================================================================';

-- 5.1 So khớp trường CN_CHUYENGIAO ('AUM' / 'CASA' / NULL)
SELECT 
    m.CASE_ID,
    m.DESCRIPTION,
    tgt.CN_CHUYENGIAO    AS ACTUAL_CHUYENGIAO,
    m.EXPECTED_CHUYEN    AS EXPECTED_CHUYENGIAO,
    CASE 
        WHEN ISNULL(tgt.CN_CHUYENGIAO, '') = ISNULL(m.EXPECTED_CHUYEN, '') THEN 'PASSED'
        ELSE 'FAILED - WRONG CN_CHUYENGIAO'
    END AS TEST_STATUS
FROM #TEST_CASE_MATRIX m
LEFT JOIN VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt 
    ON m.CASE_ID = tgt.RECID AND tgt.BUSINESS_DATE = @BUSINESS_DATE
WHERE m.EXPECTED_OUTCOME = 'IN_TARGET';

-- 5.2 Kiểm tra các trường cấm rác (Bắt buộc phải NULL trên toàn bộ Target)
SELECT 
    tgt.RECID,
    tgt.VIP_INFOR,
    tgt.RE_ASSET,
    tgt.ID_FLAG,
    'BUG: Các trường VIP_INFOR / RE_ASSET / ID_FLAG bắt buộc phải là NULL' AS BUG_DESCRIPTION
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
WHERE 1=1
  AND tgt.BUSINESS_DATE = @BUSINESS_DATE
  AND (tgt.VIP_INFOR IS NOT NULL OR tgt.RE_ASSET IS NOT NULL OR tgt.ID_FLAG IS NOT NULL);


-- ==============================================================================
-- BẢNG TỔNG KẾT DASHBOARD: TEST SCORECARD CHO TOÀN BỘ 36 TEST CASES
-- ==============================================================================
PRINT '====================================================================';
PRINT '>>> BẢNG TỔNG HỢP KẾT QUẢ KIỂM THỬ (QA TEST SCORECARD)...';
PRINT '====================================================================';

SELECT 
    m.CASE_ID,
    m.CASE_GROUP,
    m.DESCRIPTION,
    m.EXPECTED_OUTCOME,
    CASE 
        -- Nhóm Bad Ending / Rejected: Nếu có ở Target -> FAIL
        WHEN m.EXPECTED_OUTCOME = 'REJECTED' AND tgt.RECID IS NOT NULL 
            THEN 'FAILED (Unexpectedly Found in Target)'
        WHEN m.EXPECTED_OUTCOME = 'REJECTED' AND tgt.RECID IS NULL 
            THEN 'PASSED (Properly Excluded)'
        -- Nhóm Happy / Target: Phải có ở Target và đúng toàn bộ thuộc tính
        WHEN m.EXPECTED_OUTCOME = 'IN_TARGET' AND tgt.RECID IS NULL 
            THEN 'FAILED (Missing in Target)'
        WHEN m.EXPECTED_OUTCOME = 'IN_TARGET' 
         AND (tgt.VIP_TYPE <> m.EXPECTED_VIP_TYPE 
              OR ISNULL(tgt.VIP_GROUP, '') <> ISNULL(m.EXPECTED_GROUP, '')
              OR (m.EXPECTED_CNUT IS NOT NULL AND tgt.CNUT <> m.EXPECTED_CNUT)
              OR (m.EXPECTED_DAO IS NOT NULL AND tgt.DAO_RM <> m.EXPECTED_DAO)
              OR (ISNULL(tgt.CN_CHUYENGIAO, '') <> ISNULL(m.EXPECTED_CHUYEN, '')))
            THEN 'FAILED (Attribute Mismatch)'
        ELSE 'PASSED'
    END AS FINAL_RESULT
FROM #TEST_CASE_MATRIX m
LEFT JOIN VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt 
    ON m.CASE_ID = tgt.RECID AND tgt.BUSINESS_DATE = @BUSINESS_DATE
ORDER BY 
    CASE WHEN FINAL_RESULT LIKE 'FAILED%' THEN 1 ELSE 2 END,
    m.CASE_GROUP, 
    m.CASE_ID;
