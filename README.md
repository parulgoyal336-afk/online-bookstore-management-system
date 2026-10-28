Folio Books is a web-based Online Bookstore Management System. The business logic lives in Oracle PL/SQL (package bookstore_pkg, audit trigger, transactional checkout) and a Python Flask + Bootstrap front end calls it through python-oracledb.

Features
- User registration, login and profile management (SHA-256 hashed passwords)
- Book catalogue with search by title, author or category
- Shopping cart and safe checkout with stock validation and rollback
- Order history and order status tracking
- Admin dashboard: manage books, update order status, best sellers and sales trend

Tech stack: Oracle Database Free, PL/SQL, Python 3, Flask, python-oracledb, HTML, CSS, Bootstrap 5

Setup: run database/01_schema.sql, 02_plsql.sql and 03_seed.sql in Oracle, then pip install -r requirements.txt and python app.py
