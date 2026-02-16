import os
import json
import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/catalog"
)


def get_db():
    return psycopg2.connect(DATABASE_URL)


def init_db():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                price DECIMAL(10, 2) NOT NULL,
                category VARCHAR(100),
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        app.logger.warning(f"Could not initialize database: {e}")


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "catalog"})


@app.route("/products", methods=["GET"])
def list_products():
    try:
        conn = get_db()
        cur = conn.cursor()
        category = request.args.get("category")
        if category:
            cur.execute(
                "SELECT id, name, description, price, category FROM products WHERE category = %s",
                (category,),
            )
        else:
            cur.execute("SELECT id, name, description, price, category FROM products")
        rows = cur.fetchall()
        products = [
            {"id": r[0], "name": r[1], "description": r[2], "price": float(r[3]), "category": r[4]}
            for r in rows
        ]
        cur.close()
        conn.close()
        return jsonify(products)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/products", methods=["POST"])
def create_product():
    data = request.get_json()
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO products (name, description, price, category) VALUES (%s, %s, %s, %s) RETURNING id",
            (data["name"], data.get("description", ""), data["price"], data.get("category", "")),
        )
        product_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"id": product_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "3002")))
