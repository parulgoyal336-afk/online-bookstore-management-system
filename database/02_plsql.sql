CREATE OR REPLACE PACKAGE bookstore_pkg AS
 PROCEDURE register_user(p_name VARCHAR2, p_email VARCHAR2, p_address VARCHAR2, p_pass VARCHAR2);
 FUNCTION  login_user(p_email VARCHAR2, p_pass VARCHAR2) RETURN SYS_REFCURSOR;
 PROCEDURE update_profile(p_uid NUMBER, p_name VARCHAR2, p_address VARCHAR2);
 PROCEDURE add_book(p_title VARCHAR2, p_author VARCHAR2, p_cat VARCHAR2, p_price NUMBER, p_qty NUMBER);
 PROCEDURE update_book(p_id NUMBER, p_price NUMBER, p_qty NUMBER);
 PROCEDURE remove_book(p_id NUMBER);
 FUNCTION  search_books(p_term VARCHAR2) RETURN SYS_REFCURSOR;
 PROCEDURE add_to_cart(p_uid NUMBER, p_bid NUMBER, p_qty NUMBER);
 PROCEDURE update_cart(p_uid NUMBER, p_bid NUMBER, p_qty NUMBER);
 FUNCTION  get_cart(p_uid NUMBER) RETURN SYS_REFCURSOR;
 FUNCTION  checkout(p_uid NUMBER) RETURN NUMBER;
 FUNCTION  order_history(p_uid NUMBER) RETURN SYS_REFCURSOR;
 FUNCTION  all_orders RETURN SYS_REFCURSOR;
 PROCEDURE set_status(p_oid NUMBER, p_status VARCHAR2);
 FUNCTION  best_sellers RETURN SYS_REFCURSOR;
 FUNCTION  sales_trend RETURN SYS_REFCURSOR;
END bookstore_pkg;
/
CREATE OR REPLACE PACKAGE BODY bookstore_pkg AS
 FUNCTION hash_pw(p VARCHAR2) RETURN VARCHAR2 IS
    v_hash VARCHAR2(64);
  BEGIN 
    SELECT STANDARD_HASH(p, 'SHA256') INTO v_hash FROM DUAL;
    RETURN v_hash; 
  END;

 PROCEDURE register_user(p_name VARCHAR2, p_email VARCHAR2, p_address VARCHAR2, p_pass VARCHAR2) IS
    v_hash VARCHAR2(64);
  BEGIN
    IF p_name IS NULL OR p_email NOT LIKE '%_@_%._%' THEN raise_application_error(-20001,'Enter a valid name and email'); END IF;
    IF LENGTH(p_pass) < 6 THEN raise_application_error(-20002,'Password must be at least 6 characters'); END IF;
    v_hash := hash_pw(p_pass);
    INSERT INTO users(name,email,address,password_hash) VALUES(p_name,LOWER(p_email),p_address,v_hash);
  EXCEPTION WHEN DUP_VAL_ON_INDEX THEN raise_application_error(-20003,'This email is already registered');
  END;

  FUNCTION login_user(p_email VARCHAR2, p_pass VARCHAR2) RETURN SYS_REFCURSOR IS 
    rc SYS_REFCURSOR;
    v_hash VARCHAR2(64);
  BEGIN 
    v_hash := hash_pw(p_pass);
    OPEN rc FOR SELECT user_id,name,role FROM users WHERE email=LOWER(p_email) AND password_hash=v_hash; 
    RETURN rc; 
  END;

 PROCEDURE update_profile(p_uid NUMBER, p_name VARCHAR2, p_address VARCHAR2) IS
 BEGIN UPDATE users SET name=p_name, address=p_address WHERE user_id=p_uid; END;

 PROCEDURE add_book(p_title VARCHAR2, p_author VARCHAR2, p_cat VARCHAR2, p_price NUMBER, p_qty NUMBER) IS
 BEGIN INSERT INTO books(title,author,category,price,quantity) VALUES(p_title,p_author,p_cat,p_price,p_qty); END;

 PROCEDURE update_book(p_id NUMBER, p_price NUMBER, p_qty NUMBER) IS
 BEGIN UPDATE books SET price=p_price, quantity=p_qty WHERE book_id=p_id; END;

 PROCEDURE remove_book(p_id NUMBER) IS
 BEGIN DELETE FROM books WHERE book_id=p_id;
 EXCEPTION WHEN OTHERS THEN
  IF SQLCODE=-2292 THEN raise_application_error(-20004,'Book has past orders and cannot be removed; set stock to 0 instead');
  ELSE RAISE; END IF;
 END;

 FUNCTION search_books(p_term VARCHAR2) RETURN SYS_REFCURSOR IS rc SYS_REFCURSOR;
 BEGIN OPEN rc FOR SELECT book_id,title,author,category,price,quantity FROM books
  WHERE LOWER(title) LIKE '%'||LOWER(p_term)||'%' OR LOWER(author) LIKE '%'||LOWER(p_term)||'%'
     OR LOWER(category) LIKE '%'||LOWER(p_term)||'%' ORDER BY title; RETURN rc; END;

 PROCEDURE add_to_cart(p_uid NUMBER, p_bid NUMBER, p_qty NUMBER) IS v NUMBER;
 BEGIN
  SELECT quantity INTO v FROM books WHERE book_id=p_bid;
  IF v < 1 THEN raise_application_error(-20005,'This book is out of stock'); END IF;
  MERGE INTO cart c USING (SELECT p_uid u, p_bid b FROM dual) s ON (c.user_id=s.u AND c.book_id=s.b)
  WHEN MATCHED THEN UPDATE SET c.quantity=LEAST(c.quantity+p_qty, v)
  WHEN NOT MATCHED THEN INSERT(user_id,book_id,quantity) VALUES(p_uid,p_bid,LEAST(p_qty,v));
 EXCEPTION WHEN NO_DATA_FOUND THEN raise_application_error(-20006,'Book not found');
 END;

 PROCEDURE update_cart(p_uid NUMBER, p_bid NUMBER, p_qty NUMBER) IS
 BEGIN
  IF p_qty <= 0 THEN DELETE FROM cart WHERE user_id=p_uid AND book_id=p_bid;
  ELSE UPDATE cart SET quantity=p_qty WHERE user_id=p_uid AND book_id=p_bid; END IF;
 END;

 FUNCTION get_cart(p_uid NUMBER) RETURN SYS_REFCURSOR IS rc SYS_REFCURSOR;
 BEGIN OPEN rc FOR SELECT b.book_id,b.title,b.author,b.price,c.quantity,b.price*c.quantity subtotal
  FROM cart c JOIN books b ON b.book_id=c.book_id WHERE c.user_id=p_uid ORDER BY b.title; RETURN rc; END;

 FUNCTION checkout(p_uid NUMBER) RETURN NUMBER IS v_oid NUMBER; v_total NUMBER:=0; v_n NUMBER:=0;
 BEGIN
  INSERT INTO orders(user_id) VALUES(p_uid) RETURNING order_id INTO v_oid;
  FOR r IN (SELECT c.book_id, c.quantity qty, b.price, b.quantity stock, b.title
            FROM cart c JOIN books b ON b.book_id=c.book_id WHERE c.user_id=p_uid FOR UPDATE OF b.quantity) LOOP
   IF r.qty > r.stock THEN raise_application_error(-20010,'Not enough stock for '||r.title); END IF;
   INSERT INTO order_items(order_id,book_id,quantity,price) VALUES(v_oid,r.book_id,r.qty,r.price);
   UPDATE books SET quantity=quantity-r.qty WHERE book_id=r.book_id;
   v_total:=v_total+r.qty*r.price; v_n:=v_n+1;
  END LOOP;
  IF v_n=0 THEN raise_application_error(-20011,'Your cart is empty'); END IF;
  UPDATE orders SET total_amount=v_total WHERE order_id=v_oid;
  DELETE FROM cart WHERE user_id=p_uid;
  COMMIT; RETURN v_oid;
 EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
 END;

 FUNCTION order_history(p_uid NUMBER) RETURN SYS_REFCURSOR IS rc SYS_REFCURSOR;
 BEGIN OPEN rc FOR SELECT o.order_id,o.order_date,o.status,o.total_amount,
   (SELECT LISTAGG(b.title||' x'||i.quantity, ', ') WITHIN GROUP (ORDER BY b.title)
    FROM order_items i JOIN books b ON b.book_id=i.book_id WHERE i.order_id=o.order_id) items
  FROM orders o WHERE o.user_id=p_uid ORDER BY o.order_id DESC; RETURN rc; END;

 FUNCTION all_orders RETURN SYS_REFCURSOR IS rc SYS_REFCURSOR;
 BEGIN OPEN rc FOR SELECT o.order_id,u.name customer,o.order_date,o.status,o.total_amount
  FROM orders o JOIN users u ON u.user_id=o.user_id ORDER BY o.order_id DESC; RETURN rc; END;

 PROCEDURE set_status(p_oid NUMBER, p_status VARCHAR2) IS
 BEGIN UPDATE orders SET status=p_status WHERE order_id=p_oid; END;

 FUNCTION best_sellers RETURN SYS_REFCURSOR IS rc SYS_REFCURSOR;
 BEGIN OPEN rc FOR SELECT b.title,b.author,SUM(i.quantity) sold,SUM(i.quantity*i.price) revenue
  FROM order_items i JOIN books b ON b.book_id=i.book_id JOIN orders o ON o.order_id=i.order_id
  WHERE o.status<>'CANCELLED' GROUP BY b.title,b.author ORDER BY sold DESC FETCH FIRST 5 ROWS ONLY; RETURN rc; END;

 FUNCTION sales_trend RETURN SYS_REFCURSOR IS rc SYS_REFCURSOR;
 BEGIN OPEN rc FOR SELECT TRUNC(order_date) day, COUNT(*) orders, SUM(total_amount) revenue
  FROM orders WHERE status<>'CANCELLED' GROUP BY TRUNC(order_date) ORDER BY 1 DESC FETCH FIRST 7 ROWS ONLY; RETURN rc; END;
END bookstore_pkg;
/
CREATE OR REPLACE TRIGGER trg_books_audit AFTER UPDATE OF price, quantity ON books FOR EACH ROW
BEGIN
 INSERT INTO audit_log(action,details) VALUES('BOOK_UPDATE','Book '||:OLD.book_id||' price '||:OLD.price||'->'||:NEW.price||', stock '||:OLD.quantity||'->'||:NEW.quantity);
END;
/
