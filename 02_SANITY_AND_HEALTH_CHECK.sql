/* ==============================================================================
   FILE 2: SANITY & HEALTH CHECK SUITE
   Mục đích: Kiểm tra độ "sạch" kỹ thuật của bảng Target ngay sau khi Job DEV chạy xong.
   Không cần so với Nguồn vẫn có thể bắt được các lỗi:
   - Duplicate Primary Key (Cháy lực lượng dữ liệu)
   - Vi phạm ràng buộc NOT NULL
   - Vi phạm chuẩn hóa giá trị cố định (Tầng 5)
   - Lọt dữ liệu rác / Tên kỹ thuật
============================================================================== */

DECLARE @BUSINESS_DATE DATE = '2026-09-16';

-- ------------------------------------------------------------------------------
-- CHECK 1: KIỂM TRA TỔNG SỐ LƯỢNG & DUPLICATE KEY TRÊN 1 DÒNG (MẸO 3)
-- Kỳ vọng: DUP_COUNT = 0
-- ------------------------------------------------------------------------------
SELECT 
    COUNT(*)                                       AS TOTAL_ROWS,
    COUNT(DISTINCT RECID)                          AS DISTINCT_CIF,
    COUNT(*) - COUNT(DISTINCT RECID)               AS DUP_COUNT,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT RECID) THEN 'PASSED - NO DUPLICATE'
        ELSE 'FAILED - CRITICAL DUPLICATE DETECTED'
    END                                            AS DUP_STATUS
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION 
WHERE BUSINESS_DATE = @BUSINESS_DATE;


-- ------------------------------------------------------------------------------
-- CHECK 2: TRUY VẾT CÁC BẢN GHI BỊ TRÙNG LẶP KEY (NẾU CÓ DUP)
-- ------------------------------------------------------------------------------
SELECT 
    RECID, 
    COUNT(*) AS OCCURRENCE_COUNT
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION 
WHERE BUSINESS_DATE = @BUSINESS_DATE
GROUP BY RECID 
HAVING COUNT(*) > 1;


-- ------------------------------------------------------------------------------
-- CHECK 3: BẮT VI PHẠM RÀNG BUỘC NOT NULL (CÁC TRƯỜNG BẮT BUỘC CÓ DỮ LIỆU)
-- Kỳ vọng: Không có dòng nào vi phạm (0 bản ghi)
-- ------------------------------------------------------------------------------
SELECT 
    tgt.RECID,
    tgt.CUS_NAME,
    CASE 
        WHEN tgt.VIP_TYPE IS NULL  THEN 'RỚT VIP_TYPE'
        WHEN tgt.VIP_GROUP IS NULL THEN 'RỚT VIP_GROUP'
        WHEN tgt.CNUT IS NULL      THEN 'RỚT CHI NHÁNH CNUT'
        WHEN tgt.DAO_RM IS NULL    THEN 'RỚT GÁN RM (DAO_RM)'
        WHEN tgt.SEGMENT IS NULL   THEN 'RỚT SEGMENT'
    END AS NULL_ERROR_TYPE
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
WHERE 1=1
  AND tgt.BUSINESS_DATE = @BUSINESS_DATE
  AND (
      tgt.VIP_TYPE IS NULL 
      OR tgt.VIP_GROUP IS NULL 
      OR tgt.CNUT IS NULL 
      OR tgt.DAO_RM IS NULL 
      OR tgt.SEGMENT IS NULL
  );


-- ------------------------------------------------------------------------------
-- CHECK 4: KIỂM THỬ CHUẨN HÓA CỐ ĐỊNH THEO TẦNG 5 CỦA BRD
-- Kỳ vọng: 0 bản ghi vi phạm
-- ------------------------------------------------------------------------------
SELECT 
    tgt.RECID,
    tgt.SEGMENT,
    tgt.AF_CHANNEL,
    tgt.VIP_INFOR,
    tgt.RE_ASSET,
    tgt.ID_FLAG
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
WHERE 1=1
  AND tgt.BUSINESS_DATE = @BUSINESS_DATE
  AND (
      tgt.SEGMENT <> 'AF'                       -- BRD quy định cứng SEGMENT = 'AF'
      OR tgt.AF_CHANNEL <> 'T24 AUTO'           -- BRD quy định cứng AF_CHANNEL = 'T24 AUTO'
      OR tgt.VIP_INFOR IS NOT NULL              -- BRD quy định phải NULL
      OR tgt.RE_ASSET IS NOT NULL                -- BRD quy định phải NULL
      OR tgt.ID_FLAG IS NOT NULL                 -- BRD quy định phải NULL
  );


-- ------------------------------------------------------------------------------
-- CHECK 5: QUÉT LỌT TÊN RÁC & GIẤY TỜ RÁC VÀO BẢNG TARGET
-- Kỳ vọng: 0 bản ghi
-- ------------------------------------------------------------------------------
SELECT 
    tgt.RECID,
    tgt.CUS_NAME,
    tgt.LEGAL_ID
FROM VPB_SERVICE_DF.dbo.AF_IDENTIFICATION tgt
WHERE 1=1
  AND tgt.BUSINESS_DATE = @BUSINESS_DATE
  AND (
      tgt.CUS_NAME LIKE '%KHONG SU DUNG%'
      OR tgt.CUS_NAME LIKE '%KHONGSUDUNG%'
      OR tgt.CUS_NAME LIKE '%NO NAME%'
      OR tgt.CUS_NAME LIKE '%NONAME%'
      OR tgt.CUS_NAME LIKE '%KHONG SD%'
      OR tgt.CUS_NAME LIKE '%KHONG GIAO DICH%'
      OR tgt.LEGAL_ID LIKE '%KHONG-SU-DUNG%'
      OR tgt.LEGAL_ID LIKE '%KHONGSUDUNG%'
  );

