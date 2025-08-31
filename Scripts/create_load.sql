CREATE TABLE wretail(
	YEAR INT,
    MONTH INT,
    SUPPLIER VARCHAR(255),
    ITEM_CODE VARCHAR(50),
    ITEM_DESCRIPTION VARCHAR(255),
    ITEM_TYPE VARCHAR(50),
    RETAIL_SALES DECIMAL(12,2),
    RETAIL_TRANSFERS DECIMAL(12,2),
    WAREHOUSE_SALES DECIMAL(12,2)
);

-- load file dari csv 
\copy wretail FROM 'C:\Users\USER\Documents\Data Analyst Course\dataset\Excel\Warehouse_and_Retail_Sales.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

SELECT * FROM wretail;

-- ==================================================
-- Create Table Warehouse_and_Retail_Sales
-- Source: Load file dari CSV (Warehouse_and_Retail_Sales.csv)
-- ==================================================

/*
	🔑 Key Dimensions
	Digunakan untuk mendeskripsikan atau sebagai pengelompok data:
		1. YEAR (tahun transaksi)
		2. MONTH (bulan transaksi)
		3. SUPPLIER (nama supplier)
		4. ITEM_CODE (kode item)
		5. ITEM_DESCRIPTION (nama/uraian produk)
		6. ITEM_TYPE (kategori produk: WINE, BEER, dll.)
	📊 Key Metrics
	Digunakan untuk analisis kuantitatif (nilai numerik yang bisa di-aggregate dengan SUM, AVG, dll.):
		1. RETAIL_SALES (penjualan retail)
		2. RETAIL_TRANSFERS (jumlah transfer retail)
		3. WAREHOUSE_SALES (penjualan gudang)
*/	