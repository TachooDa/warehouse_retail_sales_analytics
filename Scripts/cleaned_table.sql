SELECT * FROM wretail_staging;

--> membuat table staging agar tidak menggunakan raw date
CREATE TABLE wretail_staging
(LIKE wretail INCLUDING  ALL);
--> masukan data ke table staging
INSERT INTO wretail_staging 
SELECT * FROM wretail;

-- CLEANING DATA
-- > 1. Cek duplicate data
WITH dupl AS (
SELECT *,
	row_number() over(PARTITION BY supplier,item_description,item_code,item_type ORDER BY year) AS rn
FROM wretail_staging
) SELECT * FROM dupl
WHERE rn > 1
ORDER BY year;

--> 2. Standarisasi data yg dimiliki
SELECT
	supplier, item_description
FROM wretail_staging
WHERE supplier = 'UNKNOWN';
-- update untuk supplier&item_description (hanya trim spasi)
UPDATE wretail_staging
SET supplier = upper(trim(supplier)),
 item_description = upper(trim(item_description));
-- update blank values to unknown (to make your analysis easier)
UPDATE wretail_staging 
SET supplier = 'UNKNOWN'
WHERE supplier IS NULL OR TRIM(supplier) = '';

--> cek untuk retail_sales karena terdapat null/blank values (set menjadi 0)
SELECT 
	count(retail_transfers)
FROM wretail_staging 
WHERE retail_transfers = '0';
-- update null/blank values to 0 value
UPDATE wretail_staging 
SET retail_sales = '0'
WHERE retail_sales IS NULL;

--> added item type WINE untuk produk fonatafreda barollo s label 750 ml
SELECT 
	item_description,
	item_type
FROM wretail_staging 
WHERE item_description = 'FONTANAFREDDA BAROLO SILVER LABEL 750 ML';
UPDATE wretail_staging
SET item_type = 'WINE'
WHERE item_type IS NULL OR TRIM(item_type) = '';

--> cleane simbol di item_description
SELECT distinct
	item_description
FROM wretail_staging
WHERE item_description  LIKE 'EA%';
--> bersihkan produk ! EA ! - 750ML
UPDATE wretail_staging 
SET item_description = trim(REPLACE(REPLACE(item_description, '!',''),' ',' '))
WHERE item_description LIKE '%! EA !%';


