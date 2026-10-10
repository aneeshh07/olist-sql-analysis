# Data

Download the **Brazilian E-Commerce Public Dataset by Olist** from Kaggle:
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Unzip it and place these 9 files in this `data/` folder:

| File | Rows (approx.) | Description |
|---|---|---|
| `olist_customers_dataset.csv` | 99k | Customer location; `customer_unique_id` identifies a person |
| `olist_geolocation_dataset.csv` | 1M | Zip prefix to lat/lng |
| `olist_orders_dataset.csv` | 99k | Order status and timestamps |
| `olist_order_items_dataset.csv` | 113k | Items in each order, price, freight |
| `olist_order_payments_dataset.csv` | 104k | Payment method, instalments, value |
| `olist_order_reviews_dataset.csv` | 99k | Review score and comments |
| `olist_products_dataset.csv` | 33k | Product category and dimensions |
| `olist_sellers_dataset.csv` | 3k | Seller location |
| `product_category_name_translation.csv` | 71 | Portuguese to English category names |

The CSVs are excluded from Git via `.gitignore`.
