SELECT * FROM wretail_staging;
WITH base_query AS (
SELECT 
	item_type,
	retail_sales,
	warehouse_sales,
	to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD') AS sales_date
FROM wretail_staging
), median_v AS (
SELECT
 	item_type,
 	PERCENTILE_CONT(0.5) WITHIN GROUP (
 		ORDER BY (retail_sales + warehouse_sales)
 	) AS median
FROM base_query
WHERE sales_date BETWEEN '2020-01-01' AND '2020-12-31'
GROUP BY item_type
)
SELECT
	bq.item_type,
	round(avg(mv.median::numeric),2) AS median,
	 ROUND(COALESCE(SUM(
        CASE 
            WHEN (retail_sales + warehouse_sales) < mv.median
                 AND sales_date BETWEEN '2020-01-01' AND '2020-12-31'
            THEN (retail_sales + warehouse_sales)
        END
    ), 0), 0) AS low_sales_2020,
    ROUND(SUM(
        CASE 
            WHEN (retail_sales + warehouse_sales) >= mv.median
                 AND sales_date BETWEEN '2020-01-01' AND '2020-12-31'
            THEN (retail_sales + warehouse_sales)
        END
    ), 0) AS high_sales_2020
FROM base_query AS bq
INNER JOIN median_v AS mv ON bq.item_type = mv.item_type
GROUP BY bq.item_type
ORDER BY bq.item_type;

--> 2. IQR percentile untuk q3-q1
WITH q3_q1 AS (
SELECT 
	retail_sales,
	warehouse_sales,
	to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD') AS sales_date
FROM wretail_staging
)
SELECT 
	PERCENTILE_CONT(0.25) WITHIN GROUP
	(
		ORDER BY (retail_sales + warehouse_sales)
	) AS q1_2017_2020,
	PERCENTILE_CONT(0.75) WITHIN GROUP
	(
		ORDER BY (retail_sales + warehouse_sales)
	) AS q3_2017_2020
FROM q3_q1 
WHERE sales_date BETWEEN '2017-01-01' AND '2020-12-31';

--> 3. segmenting quartile sales untuk di analisis
-- low, medium dan high untuk overall sales dari tahun 2017-2020
WITH q3_q1 AS (
SELECT
	item_type,
	retail_sales,
	warehouse_sales,
	to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD') AS sales_date
FROM wretail_staging
), q_segmenting AS (
SELECT
	PERCENTILE_CONT(0.25) WITHIN GROUP
	(
		ORDER BY (retail_sales + warehouse_sales)
	) AS q1_2017_2020,
	PERCENTILE_CONT(0.75) WITHIN GROUP
	(
		ORDER BY (retail_sales + warehouse_sales)
	) AS q3_2017_2020
FROM q3_q1
WHERE sales_date BETWEEN '2017-01-01' AND '2020-12-31'
)
SELECT 
	q.item_type AS jenis_produk,
	CASE
		WHEN (q.retail_sales + q.warehouse_sales) <= qs.q1_2017_2020 THEN '3-Low sales'
		WHEN (q.retail_sales + q.warehouse_sales) >= qs.q1_2017_2020 THEN '1-High sales'
		ELSE '2-Medium sales'
	END AS sales_tier,
	round(sum(q.retail_sales + q.warehouse_sales), 0) AS overall_sales
FROM q3_q1 AS q
CROSS JOIN q_segmenting AS qs
GROUP BY q.item_type, sales_tier
ORDER BY jenis_produk, sales_tier;

--> 4. Cohort analysis
--> Cohort : A group of people/supplier or items sharing a common characteristic.
WITH yearly_cohort AS (
SELECT
	DISTINCT item_code,
	to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD') AS sales_date
FROM wretail_staging
), cohort2 AS (
SELECT
	item_code,
	min(sales_date),
	extract(YEAR FROM min(sales_date) over(PARTITION BY item_code)) AS cohort_year
FROM yearly_cohort
GROUP BY item_code, sales_date
) 
SELECT 
	c.cohort_year,
	extract(YEAR FROM to_date(ws.YEAR::text || '-' || ws.MONTH::text || '-01', 'YYYY-MM-DD')) AS purchase_year,
	round(sum(ws.retail_sales + ws.warehouse_sales),0) AS net_sales
FROM wretail_staging AS ws
LEFT JOIN cohort2 AS c ON ws.item_code = c.item_code
GROUP BY
	c.cohort_year,
	purchase_year
ORDER BY c.cohort_year, purchase_year;

--> 4. retention analysis (to find churned supplier and produk)
WITH base_query AS (
-- karena ngga ada kolom spesifik, jadi buat dulu di base query untuk langkah berikutnya
SELECT
	item_code,
	item_description,
	item_type,
	to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD') AS sales_date
FROM wretail_staging
), churn_produk AS (
SELECT
	item_code,
	item_description,
	item_type,
	sales_date,
	row_number() over(PARTITION BY item_code ORDER BY sales_date desc) AS rn,
	min(sales_date)over(PARTITION BY item_code) AS first_sales_date,
	extract(YEAR FROM min (sales_date)) AS cohort_year
FROM base_query
GROUP BY item_code, item_type, sales_date, item_description
), final_query AS (
SELECT 
	item_code,
	item_description,
	sales_date AS last_sales_date,
	CASE
		WHEN sales_date < (SELECT max(to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD')) 
                               FROM wretail_staging) - INTERVAL '6 months' 
                 THEN 'churned'
		ELSE 'Active'
	END AS produk_status,
	cohort_year
FROM churn_produk 
WHERE  rn = 1
AND first_sales_date < (SELECT max(to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD')) 
                              FROM wretail_staging) - INTERVAL '6 months'
)
SELECT
	cohort_year,
	produk_status,
	count(item_code) AS num_produk,
	sum(count(item_code)) over(PARTITION BY cohort_year) AS total_produk,
	concat(round(count(item_code)*100 / sum(count(item_code)) over(PARTITION BY cohort_year),2),'%') AS status_percentage
FROM final_query
GROUP BY cohort_year, produk_status;