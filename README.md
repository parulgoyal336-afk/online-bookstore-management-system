# Folio Books – Online Bookstore Management System (Oracle PL/SQL + Flask)

Folio Books is a web-based Online Bookstore Management System. The core business logic is implemented in **Oracle PL/SQL** (via the `bookstore_pkg` package, audit triggers, and transactional checkout), paired with a **Python Flask + Bootstrap 5** front end connected through `python-oracledb`.

---

<<<<<<< HEAD
## 🚀 Features & Architecture

* **User Management:** Registration, login, and profile management (secured with SHA-256 hashed passwords).
* **Book Catalogue:** Interactive browsing and search filtered by title, author, or category.
* **Shopping Cart & Checkout:** Real-time stock validation, transactional checkout, and database rollback support.
* **Order Tracking:** Detailed order history and real-time status updates for customers.
* **Admin Dashboard:** Manage inventory, update order statuses, and view analytical reports (best sellers, sales trends).
* **Security & Auditing:** Automated price/stock change logging via `trg_books_audit`, bind variables to prevent SQL injection, input validation, and role-based access control.

---

## 🛠️ Tech Stack

* **Database:** Oracle Database Free / XE (PL/SQL, Packages, Triggers)
* **Backend:** Python 3, Flask, `python-oracledb`
* **Frontend:** HTML5, CSS3, Bootstrap 5

---

## ⚙️ Setup Instructions

### 1. Database Setup (Oracle XE 21c / Free recommended)

1. Open SQL Developer (or SQL*Plus), connect as **SYSTEM**, and create the schema user:

   ```sql
   CREATE USER bookstore IDENTIFIED BY bookstore123 QUOTA UNLIMITED ON USERS;
   GRANT CONNECT, RESOURCE TO bookstore;
