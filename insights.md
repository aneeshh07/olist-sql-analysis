# 💡 Insights & Recommendations

Every finding below comes from running the SQL in this repo on the full Olist dataset (99,441 orders, Sep 2016 – Oct 2018). Each one has a **number**, a **"so what"**, and the **query** that produced it. The raw query outputs are saved in [`results/`](results/).

All money values are in Brazilian reais (R$).

---

## 1. Growth

**Finding 1.1: Overall growth**
- Result: revenue for Jan–Aug 2018 was **R$8.60M**, up **140.4%** from R$3.58M in Jan–Aug 2017. Orders more than doubled, from 22,562 to 53,531. However, growth flattened in 2018: monthly revenue stayed between about R$0.98M and R$1.16M from January to August.
- So what: Olist grew fast in 2017 but hit a plateau in 2018. The next stage of growth has to come from new customers and categories, or from getting existing customers to buy again.
- Query: [`01_sales_trends.sql`](sql/analysis/01_sales_trends.sql) → Q1.1, Q1.3

**Finding 1.2: Peak day and shopping time**
- Result: **Black Friday (24 Nov 2017)** was the biggest day in the dataset, with **1,166 orders** and R$178.5K in revenue. November 2017 revenue jumped 53.4% over October. Across the week, **Monday and Tuesday** are the busiest days (about 16K orders each) and Saturday is the quietest (10.8K). Most orders are placed in the **afternoon (12:00–18:00)**.
- So what: promotions and ad spend work best early in the week and in the afternoon. Black Friday needs extra logistics capacity planned in advance.
- Query: [`01_sales_trends.sql`](sql/analysis/01_sales_trends.sql) → Q1.4, Q1.5

## 2. Customers

**Finding 2.1: Repeat purchase rate**
- Result: **96.96% of customers bought only once.** Only 2,888 customers (3.0%) ever placed a second order.
- So what: Olist depends almost entirely on new customers. Even a small increase in repeat buying would add a lot of revenue.
- Query: [`02_customer_analysis.sql`](sql/analysis/02_customer_analysis.sql) → Q2.1

**Finding 2.2: RFM segments**
- Result: the **"At Risk (High Value)"** segment is 14.7% of customers but generates **27.5% of revenue**. These customers spent an average of R$308, but their last order was about **443 days ago**. Champions and Loyal / Repeat customers together are only 3.0% of customers.
- So what: thousands of high-spending customers have gone quiet. They are the best target for a win-back campaign.
- Query: [`02_customer_analysis.sql`](sql/analysis/02_customer_analysis.sql) → Q2.2

**Finding 2.3: Cohort retention**
- Result: **fewer than 1% of any monthly cohort** came back to buy in the following month (the highest was 0.71%). Retention stays below 1% at 3, 6, and 12 months too.
- So what: the problem isn't one bad month. No group of customers is being retained, which points to the lack of any loyalty or follow-up programme.
- Query: [`02_customer_analysis.sql`](sql/analysis/02_customer_analysis.sql) → Q2.3

**Finding 2.4: Time to second order**
- Result: among repeat customers, the **median gap between the 1st and 2nd order is 28 days** (the average is 81 days).
- So what: the first month after a purchase is the window for a follow-up offer.
- Query: [`02_customer_analysis.sql`](sql/analysis/02_customer_analysis.sql) → Q2.4

## 3. Delivery

**Finding 3.1: Late delivery vs reviews**
- Result: late orders average **2.27 stars**, versus **4.29 stars** for on-time orders. **62.4% of late orders get a 1–2 star review**, compared with 9.2% of on-time orders. Even 1–3 days late drops the average to 3.29 stars, and at 8+ days late about 80% of reviews are negative.
- So what: delivery reliability is the biggest driver of customer satisfaction in this data. Every day of delay costs ratings.
- Query: [`03_delivery_performance.sql`](sql/analysis/03_delivery_performance.sql) → Q3.3, Q3.4

**Finding 3.2: Worst states for delivery**
- Result: **Alagoas (AL)** has the highest late rate at **21.4%**, with an average of 24.5 days to deliver. It's followed by Maranhão (17.4%) and Sergipe (15.2%), all in the Northeast. São Paulo (SP) is late only 4.5% of the time and delivers in 8.8 days. Cross-state orders take **15.1 days vs 7.9** for same-state orders, are late more often (8.0% vs 4.5%), and pay more freight (18.4% vs 13.1% of item value).
- So what: the delivery problem is mainly about distance. Sellers are concentrated in the South-East (see 4.3), while customers are spread across Brazil.
- Query: [`03_delivery_performance.sql`](sql/analysis/03_delivery_performance.sql) → Q3.2, Q3.5

**Finding 3.3: Estimated delivery dates**
- Result: overall, only **6.8% of orders arrive late**, and orders arrive on average **11.9 days earlier** than the estimated date. The average delivery takes 12.6 days (median 10.2). Late deliveries spiked in **Feb–Mar 2018 (14.1% and 19.0%)** and Nov 2017 (12.4%, the Black Friday month).
- So what: the delivery estimates are very cautious. A long estimate can put customers off at checkout, so Olist could show shorter, more accurate estimates. The spikes show that peak periods need extra logistics capacity.
- Query: [`03_delivery_performance.sql`](sql/analysis/03_delivery_performance.sql) → Q3.1, Q3.6

## 4. Sellers

**Finding 4.1: Revenue concentration (Pareto)**
- Result: **533 sellers (17.9% of all 2,970) generate 80% of revenue.** The top 10% of sellers alone bring in 67.1%, while the bottom 50% bring in less than 4%.
- So what: this is a classic 80/20 pattern. Losing a few top sellers would hurt a lot, so they deserve dedicated account management.
- Query: [`04_seller_analysis.sql`](sql/analysis/04_seller_analysis.sql) → Q4.2, Q4.3

**Finding 4.2: Risky sellers**
- Result: **15 sellers** with 50+ orders have an average rating **below 3.5 stars**. The worst averages 2.39 stars, with 59.8% negative reviews. One of them is the **#5 seller by revenue** (973 orders, 3.50 stars).
- So what: a small group of sellers is pulling down customer experience, including one of Olist's most important sellers.
- Query: [`04_seller_analysis.sql`](sql/analysis/04_seller_analysis.sql) → Q4.4, Q4.1

**Finding 4.3: Seller vs customer location**
- Result: **59.7% of sellers are in São Paulo**, but only 41.9% of customers are. The Northeast is underserved: Bahia has 3.4% of customers but 0.6% of sellers, and four states (AL, TO, AP, RR) have no sellers at all.
- So what: this explains the long cross-state deliveries in Finding 3.2. Recruiting sellers in the North and Northeast would cut delivery times where they're worst.
- Query: [`04_seller_analysis.sql`](sql/analysis/04_seller_analysis.sql) → Q4.5

## 5. Payments & Products

**Finding 5.1: Payment methods and instalments**
- Result: **credit card** is used for **76.9% of orders** (78.3% of value), followed by boleto (bank slip) at 19.9%. Two-thirds of card payments are split into instalments. Payments split into **7–10 instalments average R$334**, about **3.5×** the R$96 average of payments made in full.
- So what: instalments let customers buy more expensive items. Interest-free instalment offers are a good lever for high-value categories.
- Query: [`05_payments.sql`](sql/analysis/05_payments.sql) → Q5.1, Q5.2

**Finding 5.2: Category winners and losers**
- Result: **health & beauty** is the top category (R$1.23M, 9.3% of item revenue), followed by watches & gifts (8.8%) and bed, bath & table (7.7%). The fastest-growing categories (Jan–Aug 2018 vs 2017) were **baby (+269%)**, stationery (+260%), electronics (+244%), and watches & gifts (+242%). Watches & gifts is both a top-2 category and one of the fastest growing. On the other side, **office furniture** has the lowest rating (3.51 stars), and **bed, bath & table**, the #3 category by revenue, rates only 3.92.
- So what: watches & gifts and baby are the best categories to invest in. Bed, bath & table brings a lot of revenue but disappoints customers, so its seller and product quality needs attention.
- Query: [`06_product_analysis.sql`](sql/analysis/06_product_analysis.sql) → Q6.1, Q6.2, Q6.3

**Finding 5.3: Freight on small items**
- Result: for products **under 0.5 kg**, freight costs **20.2% of the item price**, the highest share of any weight group (12.7%–16.7% for heavier items).
- So what: shipping makes cheap, light items feel expensive. Free-shipping thresholds or bundling ("buy 2, ship free") could raise basket size.
- Query: [`06_product_analysis.sql`](sql/analysis/06_product_analysis.sql) → Q6.4

---

## ✅ Recommendations

1. **Fix delivery in the Northeast:** recruit sellers in the North and Northeast and partner with regional carriers, starting with AL, MA, and SE, where late rates are 15–21% (Findings 3.2, 4.3). Late orders drive 1–2 star reviews (Finding 3.1).
2. **Launch a second-purchase programme:** send a discount within 28 days of the first order, the typical gap before a second purchase (Finding 2.4), to lift the 3% repeat rate (Finding 2.1).
3. **Win back high-value customers:** target the "At Risk (High Value)" segment, which holds 27.5% of revenue but hasn't ordered in over a year (Finding 2.2).
4. **Manage seller quality:** put the 15 high-volume, low-rated sellers on an improvement plan, starting with the #5 revenue seller, and assign account managers to the 533 sellers who drive 80% of revenue (Findings 4.1, 4.2).
5. **Invest in growth categories:** focus marketing on watches & gifts and baby, and offer instalments on high-value items (Findings 5.1, 5.2).

## ⚠️ Limitations

- Data covers 2016–2018 only and comes from one Brazilian marketplace.
- 2016 and Sep–Oct 2018 have very few orders, so trend comparisons use Jan–Aug of each year.
- Reviews are submitted voluntarily, so they may over-represent strong opinions.
- Revenue excludes vouchers and refunds that aren't visible in the data.
- The analysis shows relationships, not proof of cause and effect.
