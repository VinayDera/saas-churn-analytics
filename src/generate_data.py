# ============================================
# SaaS Churn Analytics — Data Generation Script
# Author: Vinay
# Purpose: Generate realistic synthetic data
#          and load into PostgreSQL
# ============================================

import pandas as pd
import numpy as np
import psycopg2
from faker import Faker
import uuid
import random
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

# ============================================
# DATABASE CONNECTION
# ============================================
print("Connecting to database...")
conn = psycopg2.connect(
    host="127.0.0.1",
    port=5432,
    database="saas_churn",
    user="postgres",
    password="postgres123"
)
cursor = conn.cursor()
print("Connected successfully!")

# ============================================
# CONFIGURATION
# ============================================
fake = Faker()
random.seed(42)
np.random.seed(42)

NUM_CUSTOMERS    = 12000
START_DATE       = datetime(2022, 1, 1)
END_DATE         = datetime(2026, 4, 30)

# ============================================
# STEP 1 — POPULATE dim_dates
# ============================================
print("\nGenerating dim_dates...")

current = START_DATE
dates = []
while current <= END_DATE:
    dates.append((
        current.date(),
        current.year,
        (current.month - 1) // 3 + 1,
        current.month,
        current.strftime('%B'),
        current.isocalendar()[1],
        current.weekday(),
        current.strftime('%A'),
        current.weekday() >= 5
    ))
    current += timedelta(days=1)

cursor.executemany("""
    INSERT INTO dim_dates (
        full_date, year, quarter, month,
        month_name, week_of_year,
        day_of_week, day_name, is_weekend)
    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
""", dates)
conn.commit()
print(f"dim_dates: {len(dates)} rows inserted")

# ============================================
# STEP 2 — POPULATE dim_channels
# ============================================
print("\nGenerating dim_channels...")

channels = [
    ('Organic Search', 'Inbound',  'SEO Campaign 2022'),
    ('Paid Google',    'Outbound', 'Google Ads Q1'),
    ('Partner',        'Partner',  'AWS Marketplace'),
    ('Referral',       'Inbound',  'Customer Referral Program'),
    ('Paid LinkedIn',  'Outbound', 'LinkedIn B2B Campaign'),
    ('Direct',         'Inbound',  'Direct Traffic'),
    ('Webinar',        'Inbound',  'Product Webinar Series'),
    ('Cold Outbound',  'Outbound', 'SDR Outreach Campaign'),
]

cursor.executemany("""
    INSERT INTO dim_channels (
        channel_name, channel_type, campaign_name)
    VALUES (%s,%s,%s)
""", channels)
conn.commit()
print(f"dim_channels: {len(channels)} rows inserted")

# ============================================
# STEP 3 — POPULATE dim_plans
# ============================================
print("\nGenerating dim_plans...")

plans = [
    ('Starter',    49.00,  5,  False, 'monthly'),
    ('Starter',    39.00,  5,  False, 'annual'),
    ('Growth',     199.00, 20, True,  'monthly'),
    ('Growth',     159.00, 20, True,  'annual'),
    ('Enterprise', 799.00, 999,True,  'monthly'),
    ('Enterprise', 639.00, 999,True,  'annual'),
]

cursor.executemany("""
    INSERT INTO dim_plans (
        plan_name, price_monthly, max_seats,
        has_api_access, billing_cycle)
    VALUES (%s,%s,%s,%s,%s)
""", plans)
conn.commit()
print(f"dim_plans: {len(plans)} rows inserted")

# ============================================
# STEP 4 — POPULATE dim_customers
# ============================================
print("\nGenerating dim_customers...")

industries   = ['Technology','Finance','Healthcare',
                'Retail','Education','Logistics',
                'Marketing','Legal','Real Estate']
company_sizes= ['SMB','SMB','SMB',
                'Mid-Market','Mid-Market',
                'Enterprise']
countries    = ['India','India','India','India',
                'USA','USA','UK','Singapore',
                'Australia','Canada']
csm_owners   = ['Priya Sharma','Rahul Verma',
                'Ankit Patel','Sneha Reddy',
                'John Smith','Sarah Johnson']

customers = []
customer_ids = []

for _ in range(NUM_CUSTOMERS):
    cid = str(uuid.uuid4())
    customer_ids.append(cid)
    signup = START_DATE + timedelta(
        days=random.randint(0, 1200))
    customers.append((
        cid,
        fake.company(),
        random.choice(industries),
        random.choice(company_sizes),
        random.choice(countries),
        signup.date(),
        random.choice(csm_owners)
    ))

cursor.executemany("""
    INSERT INTO dim_customers (
        customer_id, company_name, industry,
        company_size, country,
        signup_date, csm_owner)
    VALUES (%s,%s,%s,%s,%s,%s,%s)
""", customers)
conn.commit()
print(f"dim_customers: {len(customers)} rows inserted")

# ============================================
# STEP 5 — POPULATE fact_subscriptions
# ============================================
print("\nGenerating fact_subscriptions...")

# Churn rates by segment (realistic)
churn_rates = {
    'SMB':        0.08,
    'Mid-Market': 0.04,
    'Enterprise': 0.02,
}

churn_reasons = [
    'Too expensive',
    'Missing features',
    'Switched to competitor',
    'No longer needed',
    'Poor support',
    'Technical issues',
    None, None, None  # Most dont give reason
]

subscriptions = []

for i, cid in enumerate(customer_ids):
    size      = customers[i][3]
    signup_dt = datetime.combine(
        customers[i][5], datetime.min.time())
    plan_id   = random.choice([1,2,3,4,5,6])
    channel_id= random.randint(1, 8)

    # MRR based on plan
    mrr_map = {1:49,2:39,3:199,
               4:159,5:799,6:639}
    mrr = mrr_map[plan_id]

    # Determine if churned
    churn_prob = churn_rates[size]
    churned    = random.random() < churn_prob

    if churned:
        tenure = random.randint(30, 540)
        end_dt = signup_dt + timedelta(days=tenure)
        if end_dt > END_DATE:
            end_dt   = END_DATE
            churned  = False
        status       = 'churned' if churned else 'active'
        end_date_val = end_dt.date() if churned else None
        reason       = random.choice(churn_reasons) \
                       if churned else None
    else:
        status       = 'active'
        end_date_val = None
        reason       = None

    subscriptions.append((
        str(uuid.uuid4()),
        cid,
        plan_id,
        channel_id,
        signup_dt.date(),
        end_date_val,
        mrr,
        status,
        reason
    ))

cursor.executemany("""
    INSERT INTO fact_subscriptions (
        subscription_id, customer_id,
        plan_id, channel_id,
        start_date, end_date,
        mrr_amount, status, churn_reason)
    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
""", subscriptions)
conn.commit()
print(f"fact_subscriptions: {len(subscriptions)} rows inserted")

# ============================================
# STEP 6 — POPULATE fact_events
# ============================================
print("\nGenerating fact_events...")
print("This will take 2-3 minutes...")

event_types  = ['login','report_created',
                'api_call','export',
                'dashboard_view','settings_update',
                'user_invited','support_ticket']

features     = ['analytics','reporting',
                'api','export',
                'dashboard','admin',
                'collaboration','billing']

batch        = []
batch_size   = 10000
total_events = 0

for i, cid in enumerate(customer_ids):
    signup_dt  = datetime.combine(
        customers[i][5], datetime.min.time())
    sub        = subscriptions[i]
    status     = sub[7]
    end_dt     = datetime.combine(
        sub[5], datetime.min.time()) \
        if sub[5] else END_DATE

    # Churned customers have LESS activity
    # (realistic behavioral signal)
    if status == 'churned':
        num_events = random.randint(5, 80)
    else:
        num_events = random.randint(50, 500)

    for _ in range(num_events):
        event_dt = signup_dt + timedelta(
            seconds=random.randint(
                0,
                int((end_dt-signup_dt)
                    .total_seconds())))

        batch.append((
            cid,
            random.choice(event_types),
            event_dt,
            str(uuid.uuid4()),
            random.choice(features)
        ))

        if len(batch) >= batch_size:
            cursor.executemany("""
                INSERT INTO fact_events (
                    customer_id, event_type,
                    event_ts, session_id,
                    feature_used)
                VALUES (%s,%s,%s,%s,%s)
            """, batch)
            conn.commit()
            total_events += len(batch)
            print(f"  Events inserted: {total_events:,}")
            batch = []

# Insert remaining batch
if batch:
    cursor.executemany("""
        INSERT INTO fact_events (
            customer_id, event_type,
            event_ts, session_id,
            feature_used)
        VALUES (%s,%s,%s,%s,%s)
    """, batch)
    conn.commit()
    total_events += len(batch)

print(f"fact_events: {total_events:,} rows inserted")

# ============================================
# FINAL SUMMARY
# ============================================
print("\n" + "="*45)
print("DATA GENERATION COMPLETE!")
print("="*45)

cursor.execute("SELECT COUNT(*) FROM dim_dates")
print(f"dim_dates        : {cursor.fetchone()[0]:>8,} rows")

cursor.execute("SELECT COUNT(*) FROM dim_channels")
print(f"dim_channels     : {cursor.fetchone()[0]:>8,} rows")

cursor.execute("SELECT COUNT(*) FROM dim_plans")
print(f"dim_plans        : {cursor.fetchone()[0]:>8,} rows")

cursor.execute("SELECT COUNT(*) FROM dim_customers")
print(f"dim_customers    : {cursor.fetchone()[0]:>8,} rows")

cursor.execute("SELECT COUNT(*) FROM fact_subscriptions")
print(f"fact_subscriptions: {cursor.fetchone()[0]:>8,} rows")

cursor.execute("SELECT COUNT(*) FROM fact_events")
print(f"fact_events      : {cursor.fetchone()[0]:>8,} rows")

print("="*45)

cursor.close()
conn.close()
print("\nDatabase connection closed.")
print("Your database is ready for analysis!")