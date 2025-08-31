SELECT * FROM wretail_staging LIMIT 10;

-- pertanyaan 3
-- 1. change over time analysis
SELECT
	MONTH AS sales_month,
	YEAR AS sales_year,
	round(sum(retail_sales + warehouse_sales),0) AS overall_sales,
	round(sum(retail_transfers),0) AS total_retail_transfer,
	concat(ROUND(
        SUM(retail_transfers) / NULLIF(SUM(retail_sales) + SUM(warehouse_sales), 0) * 100,
        2
    ),'%') AS pct_retail_sales
FROM wretail_staging
GROUP BY MONTH,YEAR
ORDER BY sales_month , sales_year;

-- 2. Cumulative analysis
SELECT 
	sales_month,
	sales_year,
	overall_sales,
	sum(overall_sales) over(ORDER BY sales_month,sales_year) AS running_total_sales,
	round(avg(avg_overall_sales) over(ORDER BY sales_month,sales_year),2) AS moving_avg_sales
FROM (
SELECT
	MONTH AS sales_month,
	YEAR AS sales_year,
	round(sum(retail_sales + warehouse_sales),0) AS overall_sales,
	round(avg(retail_sales + warehouse_sales),3) AS avg_overall_sales
FROM wretail_staging
GROUP BY MONTH,year
)t
ORDER BY sales_month;

-- pertanyaan 4
-- 3. performance overall sales analysis
WITH yearly_product_sales AS (
SELECT 
	year AS yearly_sales,
	item_type AS jenis_produk,
	round(sum(retail_sales + warehouse_sales),2) AS overall_sales
FROM wretail_staging
GROUP BY yearly_sales, item_type
HAVING sum(retail_sales + warehouse_sales) > 0
), sales_w_flag AS (
SELECT 
	yearly_sales,
	jenis_produk,
	round(avg(overall_sales) OVER(ORDER BY yearly_sales),0) AS avg_ovl_sales,
	round((overall_sales - avg(overall_sales) over(ORDER BY yearly_sales)),0) diff_avg,
	CASE
		when(overall_sales - avg(overall_sales) over(ORDER BY yearly_sales)) > 0 THEN 'above average'
		when(overall_sales - avg(overall_sales) over(ORDER BY yearly_sales)) < 0 THEN 'below average'
		ELSE 'average'
	END AS avg_flag,
	round(lag(overall_sales) over(PARTITION BY jenis_produk ORDER BY yearly_sales),0) AS pv_year_sales,
	CASE
		WHEN overall_sales - lag(overall_sales) over(PARTITION BY jenis_produk ORDER BY yearly_sales) > 0 THEN 'Increase'
		WHEN overall_sales - lag(overall_sales) over(PARTITION BY jenis_produk ORDER BY yearly_sales) < 0 THEN 'Decrease'
		ELSE 'No Change'
	END AS diff_py_sales
FROM yearly_product_sales
ORDER BY yearly_sales, jenis_produk
) 
SELECT * FROM sales_w_flag 
WHERE pv_year_sales IS NOT NULL
ORDER BY jenis_produk, yearly_sales;

-- 4. Part to whole analysis
-- kategori produk yg paling banyak terjual mulai dari retail dan gudang, serta overall sales
WITH item_sales AS (
SELECT
	item_type,
	round(sum(retail_sales + warehouse_sales),0) AS total_sales
FROM wretail_staging
GROUP BY item_type
)
SELECT 
	item_type,
	total_sales,
	sum(total_sales::numeric) over() AS overall_sales,
	concat(round((total_sales::NUMERIC / sum(total_sales) OVER())*100,2),'%') AS pct_of_total
FROM item_sales
ORDER BY pct_of_total DESC;

-- 5. Produk segmentation (pertanyaan 5)
-- segmenting produk atau suplier menggunakan overall sales
-- dan hitung berapa banyak produk dipisah berdasarkan segment
WITH produk_segment AS (
SELECT
	item_code,
	item_description,
	round(sum(retail_sales + warehouse_sales),0) AS overall_sales,
	CASE
		WHEN sum(retail_sales + warehouse_sales) > 1000 THEN 'High Sales'
		WHEN sum(retail_sales + warehouse_sales) BETWEEN 100 AND 999 THEN 'Medium sales'
		WHEN sum(retail_sales + warehouse_sales) between 1 AND 99 THEN 'Low Sales'
		else 'No sales'
	END AS sales_range
FROM wretail_staging
group BY item_code, item_description
)
SELECT 
	sales_range,
	count(DISTINCT item_code) AS total_produk,
	concat(round(count(item_code) *100 / sum(count(item_code)) over(),2),'%') AS pct_produk
FROM produk_segment 
GROUP BY sales_range
ORDER BY total_produk DESC;

--> suplier segmentation (pertanyaan 6)
WITH base_query AS (
SELECT
	item_code,
	supplier,
	retail_sales,
	warehouse_sales,
	to_date(YEAR::text || '-' || MONTH::text || '-01', 'YYYY-MM-DD') AS invoice_date
FROM wretail_staging
), supplier_sales AS (
SELECT 	
	item_code,
	supplier,
	sum(retail_sales + warehouse_sales) AS overall_sales,
	min(invoice_date) AS first_sales,
	max(invoice_date) AS last_sales,
	round(
	(max(invoice_date) - min(invoice_date)) / 30.0, 0) AS lifespan_in_months
FROM base_query
GROUP BY item_code,supplier
HAVING sum(retail_sales + warehouse_sales)  > 0
) 
SELECT
	supplier_segment,
	count(item_code) AS total_produk,
	concat(round(count(item_code) *100 / sum(count(item_code)) over(),2),'%') AS pct_supplier
FROM (
SELECT 
	item_code,
	CASE
		WHEN lifespan_in_months >= 12 AND overall_sales > 200 THEN 'Established & High Performer'
    	WHEN lifespan_in_months >= 12 AND overall_sales BETWEEN 1 AND 200 THEN 'Established but Low Performer'
    	WHEN lifespan_in_months < 12 AND overall_sales > 200 THEN 'Rising Star'
    	ELSE 'New or Low Performer'
	END AS supplier_segment
FROM supplier_sales
)t
GROUP BY supplier_segment
ORDER BY total_produk DESC;