# Folio Books – Online Bookstore Management System (Oracle PL/SQL + Flask)

## 1. Database (Oracle XE 21c recommended)
1. In SQL Developer connect as SYSTEM and create the schema user:
   `CREATE USER bookstore IDENTIFIED BY bookstore123 QUOTA UNLIMITED ON USERS; GRANT CONNECT, RESOURCE TO bookstore;`
2. Connect as `bookstore` and run, in order: `database/01_schema.sql`, `02_plsql.sql`, `03_seed.sql`.

## 2. Web app (VS Code terminal)
```
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python app.py
```
Open http://127.0.0.1:5000. If your DB differs, set env vars `DB_USER`, `DB_PASS`, `DB_DSN` (default `localhost:1521/XEPDB1`; use `localhost:1521/XE` on 11g).

Admin login: admin@bookstore.com / admin123 (change it). Register any other account as a customer.

## Where each requirement lives
- User/Book/Cart/Order/Reports: `bookstore_pkg` in `database/02_plsql.sql`
- Trigger: `trg_books_audit` (price/stock audit log)
- Security: bind variables (no SQL injection), SHA-256 password hashing, input validation, role checks
