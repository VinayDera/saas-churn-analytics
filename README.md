# \# SaaS Churn Analytics — Revenue Intelligence \& Behavioral Early-Warning System

# 

# <div align="center">

# 

# !\[PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.13-336791?style=flat-square\&logo=postgresql\&logoColor=white)

# !\[Python](https://img.shields.io/badge/Python-3.10-3776AB?style=flat-square\&logo=python\&logoColor=white)

# !\[Pandas](https://img.shields.io/badge/pandas-2.3-150458?style=flat-square\&logo=pandas\&logoColor=white)

# !\[Jupyter](https://img.shields.io/badge/Jupyter-Notebook-F37626?style=flat-square\&logo=jupyter\&logoColor=white)

# !\[Status](https://img.shields.io/badge/Status-Active-2ECC71?style=flat-square)

# 

# \*\*End-to-end analytics project simulating real analyst work inside a B2B SaaS company.\*\*  

# From schema design and synthetic data generation to behavioral health scoring, statistical validation, and board-level revenue reporting.

# 

# \[View SQL Scripts](#sql-analysis) · \[View Notebooks](#python-analysis) · \[Key Findings](#key-findings) · \[Reproduce Locally](#reproduce-locally)

# 

# </div>

# 

# \---

# 

# \## The Problem This Project Solves

# 

# Most churn analyses start with a cancellation event.

# 

# By then, the intervention window is already shrinking.

# 

# This project investigates a different question:

# 

# > \*\*How early can behavioral disengagement be detected — and can it be quantified in revenue terms before it appears in financial reports?\*\*

# 

# Working with a simulated B2B SaaS environment (\*\*SubscribeIQ\*\* — fictional), this project builds a full analytical stack: from raw event-level behavioral data to a prioritised, dollar-quantified account intervention list that a Customer Success team can act on the same day.

# 

# \---

# 

# \## Business Context

# 

# | Parameter | Value |

# |---|---|

# | Company | SubscribeIQ (simulated B2B SaaS) |

# | Total Customers | 12,000 |

# | Total ARR | $42.8 Million |

# | Monthly Churn Rate | 5.7% (industry benchmark: 2–4%) |

# | Net Revenue Retention | 94.5% (benchmark: >100%) |

# | Data Volume | 3,113,813 product usage events |

# | Analysis Period | Jan 2022 – Apr 2026 |

# 

# The Head of Revenue has escalated churn as a P0 priority. The ask to the analytics team:

# 

# 1\. Identify \*\*which customers\*\* are most at risk — before cancellation

# 2\. Quantify \*\*exactly how much revenue\*\* is at risk by segment

# 3\. Determine \*\*what behavioral signals\*\* predict churn earliest

# 4\. Deliver \*\*actionable recommendations\*\* with financial impact estimates

# 

# \---

# 

# \## Project Architecture

# 

# ```

# saas-churn-analytics/

# │

# ├── src/

# │   └── generate\_data.py          # Synthetic data generation engine

# │                                 # Faker + psycopg2 + controlled distributions

# │

# ├── sql/

# │   ├── 01\_churn\_rate\_analysis.sql    # Churn by segment, plan, industry

# │   ├── 02\_mrr\_waterfall.sql          # MRR movements, NRR, ARR breakdown

# │   ├── 03\_customer\_health\_score.sql  # Behavioral health scoring model

# │   ├── 04\_revenue\_at\_risk.sql        # Dollar-quantified risk classification

# │   └── 05\_channel\_performance.sql   # Acquisition channel quality analysis

# │

# ├── notebooks/

# │   ├── 01\_eda.ipynb                  # EDA, behavioral analysis, stat tests

# │   ├── 02\_cohort\_analysis.ipynb      # 12-month cohort retention heatmap

# │   └── 03\_segmentation.ipynb         # RFM scoring + K-Means segmentation

# │

# ├── outputs/

# │   ├── 01\_churn\_overview.png

# │   ├── 02\_mrr\_analysis.png

# │   ├── 03\_channel\_performance.png

# │   ├── 04\_annual\_vs\_monthly\_churn.png

# │   └── 05\_behavioral\_analysis.png

# │

# ├── notes.md                          # Project journal + learning log

# └── README.md

# ```

# 

# \---

# 

# \## Database Design

# 

# Star schema built in PostgreSQL 16 — modeled on a real SaaS data warehouse pattern.

# 

# ```

# &#x20;                       ┌─────────────────┐

# &#x20;                       │   dim\_dates     │

# &#x20;                       │  1,581 rows     │

# &#x20;                       └────────┬────────┘

# &#x20;                                │

# ┌──────────────┐    ┌────────────▼──────────────┐    ┌──────────────────┐

# │  dim\_plans   │    │    fact\_subscriptions      │    │  dim\_channels    │

# │  6 rows      ├────►      12,000 rows           ◄────┤  8 rows          │

# └──────────────┘    │  (core business fact table)│    └──────────────────┘

# &#x20;                   └────────────┬──────────────┘

# &#x20;                                │

# &#x20;                   ┌────────────▼──────────────┐

# &#x20;                   │     dim\_customers          │

# &#x20;                   │      12,000 rows           │

# &#x20;                   └────────────┬──────────────┘

# &#x20;                                │

# &#x20;                   ┌────────────▼──────────────┐

# &#x20;                   │      fact\_events           │

# &#x20;                   │    3,113,813 rows          │

# &#x20;                   │  (behavioral event log)    │

# &#x20;                   └───────────────────────────┘

# ```

# 

# \*\*Design decisions:\*\*

# \- `fact\_events` intentionally kept denormalized for fast behavioral aggregation

# \- Churn patterns baked into generation logic (SMB 8%, Mid-Market 4%, Enterprise 2%) to simulate real-world signal distribution

# \- Controlled random seed ensures reproducibility across runs

# 

# \---

# 

# \## SQL Analysis

# 

# Five production-grade SQL scripts — each answering a specific business question using real analytical patterns.

# 

# \### Query 1 — Churn Rate Analysis

# \*\*Business question:\*\* Which segments churn the most and why does it matter financially?

# 

# Techniques: `GROUP BY`, `CASE WHEN`, multi-table `JOIN`, window functions (`OVER()`), percentage calculations

# 

# ```sql

# \-- Churn rate by company size with window function for % share

# SELECT

# &#x20;   c.company\_size,

# &#x20;   COUNT(\*)                                          AS total\_customers,

# &#x20;   SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END) AS churned,

# &#x20;   ROUND(SUM(CASE WHEN s.status = 'churned' THEN 1 ELSE 0 END)

# &#x20;         \* 100.0 / COUNT(\*), 2)                     AS churn\_rate\_pct

# FROM fact\_subscriptions s

# JOIN dim\_customers c ON s.customer\_id = c.customer\_id

# GROUP BY c.company\_size

# ORDER BY churn\_rate\_pct DESC;

# ```

# 

# \### Query 2 — MRR Waterfall

# \*\*Business question:\*\* How is revenue moving — and is growth masking underlying decay?

# 

# Techniques: `DATE\_TRUNC`, `LAG()`, `SUM CASE WHEN`, NRR calculation

# 

# \### Query 3 — Customer Health Scoring

# \*\*Business question:\*\* Which specific accounts are most likely to churn in the next 30 days?

# 

# Techniques: Multi-CTE chain, behavioral signal weighting, `EXTRACT`, risk classification via `CASE WHEN`

# 

# ```sql

# \-- Health score formula

# LEAST(100, ROUND(

# &#x20;   (active\_days \* 2)          -- recency signal

# &#x20;   + (feature\_variety \* 5)    -- breadth of usage

# &#x20;   + (total\_sessions \* 0.5)   -- engagement frequency

# &#x20;   + (api\_usage \* 3)          -- depth signal (strongest predictor)

# &#x20;   - (days\_since\_active \* 1.5)-- inactivity penalty

# , 0)) AS health\_score

# ```

# 

# \### Query 4 — Revenue at Risk

# \*\*Business question:\*\* Exactly how much ARR is exposed — and who owns those accounts?

# 

# Techniques: Nested CTEs, `LEAST()`, dollar quantification, CSM-level attribution

# 

# \### Query 5 — Channel Performance

# \*\*Business question:\*\* Which acquisition channel produces the most valuable, longest-retained customers?

# 

# Techniques: LTV calculation, quality scoring formula, cross-segment analysis, tenure analysis

# 

# \---

# 

# \## Python Analysis

# 

# \### Notebook 01 — Exploratory Data Analysis

# 

# \*\*Data quality audit results:\*\*

# 

# | Table | Rows | Duplicates | Nulls |

# |---|---|---|---|

# | dim\_customers | 12,000 | 0 | None |

# | fact\_subscriptions | 12,000 | 0 | end\_date (expected), churn\_reason (expected) |

# | fact\_events | 500,000 | 0 | None |

# 

# > Both null columns are \*\*business logic nulls\*\* — not data quality issues. `end\_date` is null for active customers; `churn\_reason` is null for customers who didn't complete an exit survey.

# 

# \*\*Behavioral feature engineering:\*\*

# 

# ```python

# customer\_behavior = events.groupby('customer\_id').agg(

# &#x20;   total\_events    = ('event\_id',     'count'),

# &#x20;   unique\_features = ('feature\_used', 'nunique'),

# &#x20;   unique\_sessions = ('session\_id',   'nunique'),

# &#x20;   active\_days     = ('event\_ts',     lambda x: x.dt.date.nunique()),

# &#x20;   api\_calls       = ('feature\_used', lambda x: (x == 'api').sum()),

# &#x20;   login\_count     = ('event\_type',   lambda x: (x == 'login').sum()),

# )

# ```

# 

# \---

# 

# \## Key Findings

# 

# \### Finding 1 — Churn is a segmentation problem, not a product problem

# 

# | Segment | Churn Rate | Customers | ARR Impact |

# |---|---|---|---|

# | SMB | \*\*7.9%\*\* | 5,926 | $561K at risk |

# | Mid-Market | 4.04% | 4,035 | — |

# | Enterprise | \*\*2.6%\*\* | 2,039 | — |

# 

# SMB customers represent \*\*68% of all churn\*\* while generating 48.6% of MRR. The leverage point is clear: a 2% reduction in SMB churn recovers approximately $170K ARR annually.

# 

# \---

# 

# \### Finding 2 — Nearly half of ARR is behaviorally at risk

# 

# ```

# Total ARR              $42.8M   (100%)

# ARR showing disengagement signals  $21.1M   (49%)

# Critical ARR (health score < 40)   $11.2M   (26%)

# ```

# 

# This revenue is not yet churned. It is still appearing in MRR reports as healthy. Behavioral signals are the only early-warning system.

# 

# \---

# 

# \### Finding 3 — Annual billing masks product failure for up to 11 months

# 

# Across every plan tier, annual customers churn at a higher rate than monthly:

# 

# | Plan | Annual Churn | Monthly Churn | Delta |

# |---|---|---|---|

# | Enterprise | 6.45% | 4.58% | +1.87% |

# | Growth | 6.23% | 5.59% | +0.64% |

# | Starter | 6.31% | 5.08% | +1.23% |

# | \*\*Overall\*\* | \*\*6.33%\*\* | \*\*5.08%\*\* | \*\*+1.25%\*\* |

# 

# \*\*Hypothesis:\*\* Annual customers commit during a sales cycle before experiencing the product's value. Monthly customers face a renewal decision every 30 days — forcing earlier CS attention and faster product iteration feedback.

# 

# \---

# 

# \### Finding 4 — API adoption is the strongest single predictor of retention

# 

# | Behavioral Signal | Active (median) | Churned (median) | Ratio | p-value |

# |---|---|---|---|---|

# | Login count | 34.0 | 4.0 | 8.5x | <0.001 |

# | API calls | 33.0 | 4.0 | 8.2x | <0.001 |

# | Active days | 232.0 | 34.0 | 6.8x | <0.001 |

# | Total events | 279.0 | 39.0 | 7.2x | <0.001 |

# | Unique features | 8.0 | 8.0 | 1.0x | <0.001 |

# 

# \*\*Notable:\*\* Feature variety shows no difference between active and churned customers. Customers who churn explored the same breadth of features — they simply never used any of them deeply enough to form usage habits.

# 

# \*\*Implication for product:\*\* The onboarding problem is not feature discovery. It is value realization depth. Get customers to use two or three features repeatedly rather than showing them everything once.

# 

# \---

# 

# \### Finding 5 — Technical issues drive more churn than price

# 

# | Churn Reason | Customers | Share |

# |---|---|---|

# | Technical issues | 85 | \*\*12.4%\*\* |

# | Missing features | 76 | 11.1% |

# | Switched to competitor | 75 | 11.0% |

# | Too expensive | 70 | 10.2% |

# | No longer needed | 70 | 10.2% |

# | Poor support | 65 | 9.5% |

# 

# Most SaaS companies optimize for pricing flexibility to reduce churn. This data suggests product stability is the higher-leverage intervention.

# 

# \---

# 

# \### Finding 6 — Channel quality creates a three-way tradeoff

# 

# | Channel | Churn Rate | Avg MRR | LTV | Quality Score |

# |---|---|---|---|---|

# | Partner | \*\*4.32%\*\* ✅ | $310 | $2,433 | 556 |

# | Paid Google | 5.31% | $311 | $2,561 | \*\*577\*\* ✅ |

# | Paid LinkedIn | 5.77% | \*\*$331\*\* ✅ | \*\*$3,237\*\* ✅ | 560 |

# | Cold Outbound | 6.15% | $320 | $3,282 | 556 |

# | Referral | 6.11% | $314 | $2,472 | 537 |

# 

# No single channel dominates all three dimensions simultaneously. The optimal channel mix depends on whether the business is optimizing for churn reduction, revenue per account, or customer lifetime value.

# 

# \---

# 

# \## Business Recommendations

# 

# | Priority | Finding | Recommendation | Est. ARR Impact |

# |---|---|---|---|

# | P0 | 49% MRR behaviorally at risk | Weekly Revenue at Risk report; CS team works from prioritised health score list | $21M protected |

# | P1 | SMB churn 7.9% | Build automated low-touch re-engagement for SMB (email sequences, in-app nudges, health score triggers) | \~$170K saved |

# | P1 | Annual churn > monthly | Mandatory 90-day value realization program for all annual customers | \~$196K saved |

# | P2 | Technical issues = #1 reason | Shift product roadmap priority toward stability before new feature development | Reduce churn 1–2% |

# | P2 | API adoption predicts retention | Redesign onboarding to drive API activation in first 14 days | Improve health scores |

# | P3 | Partner channel lowest churn | Expand partner ecosystem (marketplace listings, integration partnerships) | Improve cohort NRR |

# 

# \---

# 

# \## Visualizations

# 

# | Chart | Key Insight |

# |---|---|

# | !\[Churn Overview](outputs/01\_churn\_overview.png) | SMB churn (7.9%) is 3x Enterprise (2.6%) |

# | !\[MRR Analysis](outputs/02\_mrr\_analysis.png) | Enterprise plans = 77% of MRR despite 17% of customers |

# | !\[Channel Performance](outputs/03\_channel\_performance.png) | Partner has lowest churn; Paid LinkedIn has highest LTV |

# | !\[Annual vs Monthly](outputs/04\_annual\_vs\_monthly\_churn.png) | Annual billing churn exceeds monthly across all tiers |

# | !\[Behavioral Signals](outputs/05\_behavioral\_analysis.png) | Active customers show 7–8x higher engagement across all signals |

# 

# \---

# 

# \## Reproduce Locally

# 

# \### Prerequisites

# \- PostgreSQL 16+

# \- Python 3.10+

# \- Git

# 

# \### Setup

# 

# ```bash

# \# Clone

# git clone https://github.com/VinayDera/saas-churn-analytics.git

# cd saas-churn-analytics

# 

# \# Environment

# python -m venv venv

# venv\\Scripts\\activate        # Windows

# source venv/bin/activate     # Mac/Linux

# 

# \# Dependencies

# pip install pandas numpy matplotlib seaborn scikit-learn \\

# &#x20;           sqlalchemy psycopg2-binary faker jupyter scipy

# 

# \# Database

# psql -U postgres -c "CREATE DATABASE saas\_churn;"

# 

# \# Generate data (\~5 minutes)

# python src/generate\_data.py

# 

# \# Launch notebooks

# jupyter notebook notebooks/

# ```

# 

# \### Expected output after data generation

# ```

# dim\_dates         :    1,581 rows

# dim\_channels      :        8 rows

# dim\_plans         :        6 rows

# dim\_customers     :   12,000 rows

# fact\_subscriptions:   12,000 rows

# fact\_events       :3,113,813 rows

# ```

# 

# \---

# 

# \## Tech Stack

# 

# | Layer | Technology | Purpose |

# |---|---|---|

# | Database | PostgreSQL 16.13 | Star schema, SQL analysis |

# | Language | Python 3.10 | Data generation, EDA, modeling |

# | Data manipulation | pandas 2.3 | Transformation, feature engineering |

# | Visualization | matplotlib, seaborn | Charts and dashboards |

# | Statistical testing | scipy.stats | Significance validation |

# | Notebooks | Jupyter | Interactive analysis |

# | Version control | Git + GitHub | Code management |

# 

# \---

# 

# \## Project Status

# 

# \- \[x] Database schema design

# \- \[x] Synthetic data generation (3.1M rows)

# \- \[x] SQL analysis — 5 scripts

# \- \[x] Python EDA — behavioral analysis + statistical tests

# \- \[x] Visualizations — 5 charts

# \- \[ ] Cohort retention analysis (in progress)

# \- \[ ] RFM customer segmentation (in progress)

# \- \[ ] A/B test simulation (upcoming)

# \- \[ ] Churn prediction model (upcoming)

# 

# \---

# 

# \## Author

# 

# \*\*Vinay Dera\*\* — Junior Data Analyst  

# \[LinkedIn](https://linkedin.com/in/dera-venkata-sai-vinay) · \[GitHub](https://github.com/VinayDera) · vinaydera555@gmail.com

