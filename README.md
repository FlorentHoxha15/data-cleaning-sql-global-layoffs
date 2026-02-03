# SQL Data Cleaning & Exploratory Analysis – Global Layoffs

## 📌 Project Overview
This project focuses on **data cleaning and exploratory data analysis (EDA)** using a global layoffs dataset.  
The main objective is to transform raw, inconsistent data into a clean and analysis-ready format, and to extract meaningful insights using SQL.

The project simulates a **real-world data analyst workflow**, starting from raw CSV data and ending with structured analytical insights.

---

## 🧹 Data Cleaning Process
The dataset required extensive cleaning before analysis. Key steps included:

- Importing raw CSV data into MySQL
- Handling missing and invalid values
- Removing duplicate records using window functions
- Standardizing company names, industries, and countries
- Converting date fields to proper DATE formats
- Filtering out logically incorrect records (e.g. zero layoffs with no percentage)

This step ensured that all subsequent analysis was based on **reliable and consistent data**.

---

## 📊 Exploratory Data Analysis
After cleaning, exploratory analysis was performed to answer key questions such as:

- Which companies had the highest number of layoffs?
- Which industries were most affected?
- Which countries experienced the most layoffs?
- How did layoffs evolve over time (yearly and monthly)?
- Which companies ranked highest in layoffs per year?

Advanced SQL techniques such as **CTEs, window functions, aggregations, and ranking** were used throughout the analysis.

---

## 🛠 Tools & Technologies
- SQL (MySQL)
- MySQL Workbench
- CSV data import

---

## 📁 Repository Structure
- `global-layoffs-sql-data-cleaning-eda.sql`  
  Contains the full SQL workflow:
  - Data import
  - Data cleaning
  - Exploratory analysis queries

---

## 📈 Key Takeaway
Clean data is the foundation of meaningful insights.  
This project highlights the importance of **structured data cleaning** before drawing conclusions from analysis.

---

## 🚀 Author
Created by **Florent Hoxha**  
Aspiring Data Analyst | SQL • Data Cleaning • Analytics

