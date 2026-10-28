import os, oracledb
from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, session, flash

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "change-this-secret")
CFG = dict(user=os.getenv("DB_USER", "bookstore"),
           password=os.getenv("DB_PASS", "bookstore123"),
           dsn=os.getenv("DB_DSN", "localhost:1521/XEPDB1"))

def call(name, *args, ret=None):
    """Call bookstore_pkg.<name>. ret=oracledb.CURSOR -> list of dict rows."""
    with oracledb.connect(**CFG) as con:
        cur, fn = con.cursor(), "bookstore_pkg." + name
        if ret is oracledb.CURSOR:
            rc = cur.callfunc(fn, ret, list(args))
            cols = [c[0].lower() for c in rc.description]
            return [dict(zip(cols, r)) for r in rc.fetchall()]
        out = cur.callfunc(fn, ret, list(args)) if ret else cur.callproc(fn, list(args))
        con.commit()
        return out

ROWS = oracledb.CURSOR

def login_required(admin=False):
    def deco(f):
        @wraps(f)
        def w(*a, **k):
            if "uid" not in session:
                flash("Please sign in to continue.", "warning"); return redirect(url_for("login"))
            if admin and session.get("role") != "ADMIN":
                flash("Admin access only.", "danger"); return redirect(url_for("index"))
            return f(*a, **k)
        return w
    return deco

@app.errorhandler(oracledb.DatabaseError)
def db_error(e):
    full = str(e.args[0])
    print(full)
    if request.method == "GET":
        return f"<h3>Database error</h3><pre>{full}</pre>", 500
    flash(full.split("\n")[0].split(": ", 1)[-1], "danger")
    return redirect(request.referrer or url_for("index"))

@app.route("/")
def index():
    q = request.args.get("q", "")
    return render_template("index.html", books=call("search_books", q, ret=ROWS), q=q)

@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        f = request.form
        call("register_user", f["name"], f["email"], f["address"], f["password"])
        flash("Account created. You can sign in now.", "success"); return redirect(url_for("login"))
    return render_template("auth.html", mode="register")

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        rows = call("login_user", request.form["email"], request.form["password"], ret=ROWS)
        if rows:
            session.update(uid=rows[0]["user_id"], name=rows[0]["name"], role=rows[0]["role"])
            return redirect(url_for("admin" if rows[0]["role"] == "ADMIN" else "index"))
        flash("Email or password is incorrect.", "danger")
    return render_template("auth.html", mode="login")

@app.route("/logout")
def logout():
    session.clear(); return redirect(url_for("index"))

@app.route("/profile", methods=["GET", "POST"])
@login_required()
def profile():
    if request.method == "POST":
        call("update_profile", session["uid"], request.form["name"], request.form["address"])
        session["name"] = request.form["name"]; flash("Profile saved.", "success")
    with oracledb.connect(**CFG) as con:
        r = con.cursor().execute("SELECT name,email,address FROM users WHERE user_id=:1", [session["uid"]]).fetchone()
    return render_template("profile.html", u=r)

@app.route("/cart")
@login_required()
def cart():
    items = call("get_cart", session["uid"], ret=ROWS)
    return render_template("cart.html", items=items, total=sum(i["subtotal"] for i in items))

@app.post("/cart/add/<int:bid>")
@login_required()
def cart_add(bid):
    call("add_to_cart", session["uid"], bid, 1); flash("Added to your cart.", "success")
    return redirect(request.referrer or url_for("index"))

@app.post("/cart/update/<int:bid>")
@login_required()
def cart_update(bid):
    call("update_cart", session["uid"], bid, int(request.form["qty"])); return redirect(url_for("cart"))

@app.post("/checkout")
@login_required()
def checkout():
    oid = call("checkout", session["uid"], ret=int)
    flash(f"Order #{oid} placed. Thank you!", "success"); return redirect(url_for("orders"))

@app.route("/orders")
@login_required()
def orders():
    return render_template("orders.html", orders=call("order_history", session["uid"], ret=ROWS))

@app.route("/admin")
@login_required(admin=True)
def admin():
    o = call("all_orders", ret=ROWS)
    return render_template("admin.html", books=call("search_books", "", ret=ROWS), orders=o,
        best=call("best_sellers", ret=ROWS), trend=call("sales_trend", ret=ROWS),
        revenue=sum(x["total_amount"] for x in o if x["status"] != "CANCELLED"))

@app.post("/admin/book")
@login_required(admin=True)
def admin_add():
    f = request.form
    call("add_book", f["title"], f["author"], f["category"], float(f["price"]), int(f["qty"]))
    flash("Book added.", "success"); return redirect(url_for("admin"))

@app.post("/admin/book/<int:bid>")
@login_required(admin=True)
def admin_update(bid):
    f = request.form
    if "delete" in f: call("remove_book", bid); flash("Book removed.", "success")
    else: call("update_book", bid, float(f["price"]), int(f["qty"])); flash("Book updated.", "success")
    return redirect(url_for("admin"))

@app.post("/admin/order/<int:oid>")
@login_required(admin=True)
def admin_status(oid):
    call("set_status", oid, request.form["status"]); return redirect(url_for("admin"))

if __name__ == "__main__":
    app.run(debug=True, use_reloader=False)