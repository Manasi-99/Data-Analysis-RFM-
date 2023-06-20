
----------------------
-- DATA INSPECTION
----------------------
SELECT * FROM [dbo].[sales_data_sample]


-- Checking Distinct values in the relevant columns
SELECT DISTINCT STATUS FROM [dbo].[sales_data_sample] 
SELECT DISTINCT YEAR_ID FROM [dbo].[sales_data_sample]
SELECT DISTINCT PRODUCTLINE FROM [dbo].[sales_data_sample]
SELECT DISTINCT COUNTRY FROM [dbo].[sales_data_sample]
SELECT DISTINCT TERRITORY FROM [dbo].[sales_data_sample]
SELECT DISTINCT DEALSIZE FROM [dbo].[sales_data_sample]


--------------------
-- DATA ANALYSIS
--------------------
-- Sales by Product Line
SELECT PRODUCTLINE, SUM(SALES) AS REVENUE
FROM [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY REVENUE DESC

-- Sales by Year
SELECT YEAR_ID, SUM(SALES) AS REVENUE
FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY REVENUE DESC

-- Checking why year 2005 has significantly less sales.
SELECT DISTINCT MONTH_ID FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2005
-- Because they operated for only 5 months in the year 2005.

-- Sales by Deal size
SELECT DEALSIZE, SUM(SALES) AS REVENUE
FROM [dbo].[sales_data_sample]
GROUP BY DEALSIZE
ORDER BY REVENUE DESC

-- What was the best month for sales in a specific year? How much was earned in that month?
SELECT MONTH_ID, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS [No. of Orders]
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2003
GROUP BY MONTH_ID
ORDER BY REVENUE DESC

-- Most sales are done in the month of November.
-- Checking which product line sells the most in November.
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS [No. of Orders]
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2004 AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY REVENUE DESC



-- Who is the best customer? 
-- RECENCY-FREQUENCY-MONETARY (RFM)
-- Recency: How long ago their last purchase was? -- Last order date
-- Frequency: How often they purchase? -- Count of total order
-- Monetary Value: How much do they spend? -- Total amount spent

DROP TABLE IF EXISTS #RFM; -- Single '#' from local temp and double '##' for global temp
WITH RFM AS
(
	SELECT 
		CUSTOMERNAME
		, SUM(SALES) AS [Monetary Value]
		, AVG(SALES) AS [Avg Monetary Value]
		, COUNT(ORDERNUMBER) AS [No. of Orders]
		, MAX(ORDERDATE) AS [Last Order]
		, (SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample]) AS [Most Recent Order]
		, DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample])) AS RECENCY
	FROM [dbo].[sales_data_sample]
	GROUP BY CUSTOMERNAME
),

RFM_CALC AS
(
	SELECT r.* ,
		NTILE(4) OVER (ORDER BY RECENCY DESC) AS  RFM_Recency,
		NTILE(4) OVER (ORDER BY [No. of Orders] DESC) AS RFM_Frequency,
		NTILE(4) OVER (ORDER BY [Monetary Value] DESC) AS RFM_Monetary
	FROM RFM r
)

SELECT c.*
	, RFM_Recency +  RFM_Frequency + RFM_Monetary AS RFM_Cell
	, CAST(RFM_Recency AS VARCHAR) + CAST(RFM_Frequency AS VARCHAR) + CAST(RFM_Monetary AS VARCHAR) AS RFM_Cell_String
INTO #RFM
FROM RFM_CALC c

-- Creating a RFM Segment
SELECT CUSTOMERNAME, RFM_Recency, RFM_Frequency, RFM_Monetary,
	CASE
		WHEN RFM_Cell_String IN (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) THEN '[Lost Customers]'
		WHEN RFM_Cell_String IN (133, 134, 143, 144, 244, 334, 343, 344, 243, 234) THEN '[Might Lose]'
		WHEN RFM_Cell_String IN (311, 411, 331, 421, 412, 312) THEN '[New Customers]'
		WHEN RFM_Cell_String IN (221, 222, 223, 233, 322, 232) THEN '[Potential Churners]'
		WHEN RFM_Cell_String IN (323, 333, 321, 422, 332, 432) THEN '[Active]'
		WHEN RFM_Cell_String IN (433, 434, 443,444) THEN '[Lost Customers]'
	END AS RFM_Segment
FROM #RFM 


-- What products are most often sold together?
SELECT DISTINCT ORDERNUMBER,
STUFF(

	(SELECT ', ' + PRODUCTCODE
	FROM [dbo].[sales_data_sample] p
	WHERE ORDERNUMBER IN
	(
		SELECT ORDERNUMBER
		FROM (
			SELECT ORDERNUMBER, COUNT(*) AS RN
			FROM [dbo].[sales_data_sample]
			WHERE STATUS = 'Shipped'
			GROUP BY ORDERNUMBER
			) AS Mul
		WHERE RN = 3
	)
	AND
	p.ORDERNUMBER = stf.ORDERNUMBER
	FOR XML PATH (''))
	, 1, 1, '') AS [Product Codes]
FROM [dbo].[sales_data_sample] stf
ORDER BY 2 DESC

/**
SELECT *
FROM [dbo].[sales_data_sample]
WHERE ORDERNUMBER = 10411
**/