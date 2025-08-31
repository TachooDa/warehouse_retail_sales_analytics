-- exploratory data analysis
SELECT
	round(sum(retail_sales + warehouse_sales),0) AS total_sales
FROM wretail_staging;
-- total produk 
SELECT count(DISTINCT item_code) AS total_produk
FROM wretail_staging;

--> jumlah transaksi dan avg_sales, total sales pada retail
SELECT
	count(DISTINCT retail_sales) AS total_retail_sales,
	round(avg(retail_sales),2) AS avg_total_sales,
	round(sum(retail_sales),0)AS num_of_retail_sales
FROM wretail_staging;

--> total warehouse sales
SELECT
	count(DISTINCT warehouse_sales) AS total_warehouse_sales,
	round(avg(warehouse_sales),2) AS avg_warehouse_sales,
	round(sum(warehouse_sales),0) AS num_of_wsales
FROM wretail_staging;

-- total transfer pada retail transfer
SELECT
	round(sum(retail_transfers),0) AS jumlah_transfer
FROM wretail_staging;

--> total retail sales untuk jenis produk
SELECT
	item_description,
	item_code,
	round(sum(retail_sales),0) AS total_sales
FROM wretail_staging
WHERE retail_sales > 0
GROUP BY item_description,item_code
ORDER BY total_sales DESC LIMIT 10;

--> jumlah suplier
SELECT 
	count(DISTINCT supplier) AS jumlah_supplier
FROM wretail_staging;


--> produk performance
--> top 5 produk
    -- 1. Ambil top 10 item berdasarkan retail_sales
WITH top_produk AS (
    SELECT
        item_code,
        supplier,
        item_description AS produk,
        ROUND(SUM(retail_sales), 0) AS total_sales
    FROM wretail_staging
    GROUP BY item_code, supplier, item_description
  )
  SELECT
  	row_number() over(ORDER BY total_sales desc) AS RANK,
  	item_code,
  	supplier,
  	produk,
  	total_sales 
  FROM top_produk
	ORDER BY RANK LIMIT 10; 	

 -- worst produk
WITH worst_items AS (
    SELECT
        item_code,
        supplier,
        item_description AS produk,
        ROUND(SUM(retail_sales), 0) AS total_sales
    FROM wretail_staging
    GROUP BY item_code, supplier, item_description
)
SELECT
    ROW_NUMBER() OVER (ORDER BY total_sales ASC) AS rank,
    item_code,
    supplier,
    produk,
    total_sales
FROM worst_items
ORDER BY rank
LIMIT 10;

-- pertanyaan 2
-- bandingkan retail sales dengan warehous sales (supply and deman)
WITH contribution AS (
SELECT
	item_description,
	item_type,
	round(sum(retail_sales),0) AS total_retail_sales,
	round(avg(retail_sales),0) AS avg_retail_sales,
	round(sum(warehouse_sales),0) AS total_wr_sales,
	round(avg(warehouse_sales),0) AS avg_wr_sales
FROM wretail_staging
GROUP BY item_description, item_type
)
SELECT
	item_description,
	item_type,
	total_retail_sales,
	avg_retail_sales,
	concat(round((total_retail_sales::NUMERIC / NULLIF(total_retail_sales + total_wr_sales, 0))*100 ,2),'%') AS pct_retail_vs_total,
	total_wr_sales,
	avg_wr_sales,
	concat(round((total_wr_sales::NUMERIC / NULLIF(total_retail_sales + total_wr_sales, 0))*100 ,2),'%') AS pct_wr_vs_total
FROM contribution
ORDER BY total_retail_sales DESC LIMIT 10;


--> sales trend analysis (timeseries)
-- trend penjualan per tahun
SELECT
	year,
	round(sum(retail_sales),0) AS total_retail_sales,
	round(sum(warehouse_sales),0) AS total_wr_sales
FROM wretail_staging 
GROUP BY year
ORDER BY total_retail_sales desc;
-- trend penjualan per bulan
SELECT
	month,
	round(sum(retail_sales),0) AS total_retail_sales,
	round(sum(warehouse_sales),0) AS total_wr_sales
FROM wretail_staging
GROUP BY month
ORDER BY total_retail_sales desc;

-- kontribusi supplier
SELECT 
	supplier,
	item_type,
	round(sum(retail_sales),0) AS total_sales,
	round(sum(warehouse_sales),0) AS total_wr_sales
FROM wretail_staging
GROUP BY supplier, item_type
ORDER BY total_sales DESC, total_wr_sales desc 
limit 10;



-- kontribusi terbesar supplier berdasarkan total dari retail sales dan warehous sales top (10)
-- pertanyaan 1
WITH top_supplier AS (
SELECT 
	supplier,
	round(sum(retail_sales),0) AS total_retail_sales,
	round(sum(retail_transfers),0) AS total_retail_transfers,
	round(sum(warehouse_sales),0) AS total_wr_sales,
	round(sum(retail_sales + warehouse_sales),0) AS overall_sales,
		concat(ROUND(
        SUM(retail_sales) / NULLIF(SUM(retail_sales) + SUM(warehouse_sales), 0) * 100,
        2
    ),'%') AS pct_retail_sales
FROM wretail_staging
GROUP BY supplier
)
SELECT
	supplier,
	total_retail_transfers,
	total_retail_sales,
	total_wr_sales,
	overall_sales,
	pct_retail_sales
FROM top_supplier
ORDER BY overall_sales DESC LIMIT 10;


