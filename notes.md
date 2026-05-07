### **# Project Journal — SaaS Churn Analytics**



##### **## Day 1 — Environment Setup**

\- Installed Python 3.10, PostgreSQL 16.13, DBeaver

\- Created project folder structure

\- Set up virtual environment

\- Installed all Python libraries

\- Created GitHub repo



##### \## Day 2 — Database \& Data Generation

\- Created saas\_churn database in PostgreSQL

\- Designed star schema with 6 tables

\- Generated 12,000 customers

\- Generated 3.1 million product events

\- Baked in realistic churn patterns

\- SMB churn rate: 8%, Enterprise: 2%

\- Verified all data in DBeaver

\- Pushed to GitHub

## Day 3 — SQL Analysis

### What I did:
- Wrote churn rate analysis SQL
- Analyzed churn by company size, industry, plan type
- Exported results to CSV

### Key Findings:
- Overall churn rate = 5.7%
- SMB churn = 7.9% (highest)
- Enterprise churn = 2.6% (lowest)
- Industry has minimal impact on churn
- Enterprise annual customers surprisingly churn more

### Business Recommendation:
- Focus CS team on SMB segment
- Improve onboarding for Enterprise annual customers

### MRR Waterfall Key Findings:
- Total ARR = $42.9 Million
- Average MRR per customer = $316
- NRR = 94.5% (below 100% benchmark)
- Enterprise plans = 77% of total MRR
- Starter plans = only 4.69% of MRR
- August 2025 = worst churn month
- SMB drives 48% of MRR but churns at 7.9%
