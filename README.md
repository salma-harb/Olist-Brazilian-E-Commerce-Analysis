Olist Brazilian E-Commerce Analysis

An e-commerce analytics dashboard enables executives and operations managers to monitor sales KPIs, track logistics efficiency, and understand customer satisfaction in one central place, helping teams optimize delivery performance and drive sustainable revenue growth.

The Project:

Raw e-commerce transactional data often hides critical bottlenecks behind overall sales figures. In this project, I built an end-to-end data pipeline using SQL Server (data cleaning, ETL schemas, and star-schema dimensional modeling) connected to an interactive two-page Power BI dashboard. This solution gives business decision-makers the analytical power to spot delivery delays, evaluate payment behaviors, and identify high-volume product categories at risk of poor customer ratings.

Metrics Visualised:

• Total revenue and total order volume across the platform
• Monthly order trends and commercial seasonality
• Top-performing sellers and top revenue-generating product categories
• Customer segmentation distribution (VIP, Loyal, Occasional, and Churn Risk)
• Global distribution of customer satisfaction review scores (1 to 5 stars)
• Global delivery delay rate and average delivery time in days
• Average delivery time distribution by state on a geographical map
• Direct impact of delivery delays on average customer satisfaction scores
• Payment method performance comparing total transaction value and average order value
• Product category performance balancing sales volume, revenue, and customer satisfaction

The dashboard can be further filtered by:

• Customer Segment
• Brazilian State
• Order Year

Sneek Peek:
<img width="1387" height="748" alt="d1" src="https://github.com/user-attachments/assets/7eaf342b-10db-470c-b42f-cc32c39a82c4" />

<img width="1385" height="746" alt="d2" src="https://github.com/user-attachments/assets/cf7b2891-0aae-44d3-98fc-2c6ef7ef9e74" />


The Dataset:

Olist E-Commerce Data:

The data used in this project comes from the Brazilian Olist marketplace dataset, containing nearly 100,000 real commercial orders made between 2016 and 2018. Before visualization, the raw tables were cleaned, standardized, and structured in SQL Server into a star schema consisting of fact and dimension tables (orders, customers, products, sellers, payments, and reviews) along with analytical views to ensure fast and accurate reporting.
