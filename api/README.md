# Local Food Delivery API

This small Python API serves the local test page at `http://127.0.0.1:8000`
and reads/writes the existing MySQL schema. The code is split by responsibility;
database queries are explicit SQL statements with parameters, without an ORM.
Each request connects using a dedicated MySQL account for its application role
and explicitly activates the matching MySQL role.

| File | Responsibility |
| --- | --- |
| `main.py` | Starts the local server and opens the browser |
| `server.py` | HTTP routing and static page serving |
| `base_handler.py` | JSON requests, sessions, shared database reads, and errors |
| `profile_routes.py` | Current role profile and driver availability |
| `database.py` | MySQL connection and query helpers |
| `auth_routes.py` | Login |
| `catalog_routes.py` | Restaurants, menu, and cart |
| `order_routes.py` | Order creation, ownership, assignment, and delivery |
| `admin_routes.py` | Admin statistics |
| `sessions.py` | In-memory login sessions |
| `config.py` | Local `.env` settings and server configuration |
| `errors.py` | Consistent API error type |
| `index.html` | FoodieGo role-aware local browser UI |
| `static/app.css` | Responsive FoodieGo styles |
| `static/app.js` | UI startup and role-based view selection |
| `static/shared.js`, `static/orders.js` | Shared API/state/UI helpers and order rendering/actions |
| `static/customer.js`, `static/restaurant.js` | Customer and restaurant screens |
| `static/driver.js`, `static/admin.js` | Driver and admin screens |

## Setup

1. Install MySQL 8 and create the schema with `mysql/schemasql.sql`.
2. Load one data set:
   - Full coursework data: `mysql/food_delivery_complete_5000_mysql.sql`
   - Or the small fixture: indexes, triggers, views, then `mysql/seed/sample_data.sql`
3. If loading the full dataset, run it directly after the schema and before
   `mysql/indexes/indexes.sql`, `mysql/triggers/triggers.sql`, and
   `mysql/views/views.sql`. The full seed imports historical audit records.
4. Run `mysql/security/roles.sql` after the schema, data, indexes, triggers, and
   views have been installed.
5. Create one MySQL account per API role and grant each account only its matching
   role. Use the same host as `MYSQL_HOST` (the example uses `127.0.0.1`):

   ```sql
   CREATE USER 'food_delivery_customer'@'127.0.0.1' IDENTIFIED BY 'replace-customer-password';
   GRANT 'role_customer' TO 'food_delivery_customer'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_customer'@'127.0.0.1';

   CREATE USER 'food_delivery_restaurant'@'127.0.0.1' IDENTIFIED BY 'replace-restaurant-password';
   GRANT 'role_restaurant' TO 'food_delivery_restaurant'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_restaurant'@'127.0.0.1';

   CREATE USER 'food_delivery_driver'@'127.0.0.1' IDENTIFIED BY 'replace-driver-password';
   GRANT 'role_driver' TO 'food_delivery_driver'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_driver'@'127.0.0.1';

   CREATE USER 'food_delivery_admin'@'127.0.0.1' IDENTIFIED BY 'replace-admin-password';
   GRANT 'role_admin' TO 'food_delivery_admin'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_admin'@'127.0.0.1';
   ```

6. Copy `.env.example` to `api/.env` and set the matching credentials. Do not
   configure the API with MySQL `root`; direct root privileges bypass the
   restrictions provided by these roles.
7. From the repository root, install the connector once:

   ```powershell
   python -m pip install -r api\requirements.txt
   ```

8. Run `api\main.py` (double-click it or run `python api\main.py`). It starts
   the API and automatically opens `http://127.0.0.1:8000` in your browser.
   Keep the terminal window open while testing; press Ctrl+C there to stop it.

The full sample file stores unique random six-character plaintext passwords
because this is a database coursework fixture. It is not suitable for real user
accounts. Find credentials for each role in a local MySQL client with this
explicit query (do not publish the returned passwords):

```sql
SELECT user_id, name, email, password, role
FROM food_delivery_db.`user`
WHERE role = 'Customer'
ORDER BY user_id
LIMIT 5;
```

Repeat with `Restaurant`, `Driver`, and `Admin` to get accounts for the complete
workflow. Choose an ONLINE driver; use a restaurant with `is_open = 1` and an
available menu item. Unapproved and closed restaurants remain visible in the
restaurant list with their status, but cannot be ordered from. The list excludes
unapproved restaurants; query them directly in MySQL if you need to inspect
approval cases.

Use these explicit SQL queries to find accounts that fit the workflow:

```sql
SELECT u.user_id, u.email, u.password, r.restaurant_id, r.is_open
FROM food_delivery_db.restaurant AS r
JOIN food_delivery_db.`user` AS u ON u.user_id = r.user_id
WHERE r.is_approved = 1 AND r.is_open = 1
ORDER BY r.restaurant_id
LIMIT 10;

SELECT u.user_id, u.email, u.password, d.driver_id, d.status
FROM food_delivery_db.driver AS d
JOIN food_delivery_db.`user` AS u ON u.user_id = d.user_id
WHERE d.status = 'ONLINE'
  AND NOT EXISTS (
      SELECT 1
      FROM food_delivery_db.`order` AS o
      WHERE o.driver_id = d.driver_id
        AND o.status NOT IN ('COMPLETED', 'CANCELLED')
  )
ORDER BY d.driver_id
LIMIT 10;

SELECT u.user_id, u.email, u.password
FROM food_delivery_db.`user` AS u
WHERE u.role = 'Admin'
ORDER BY u.user_id
LIMIT 5;
```

If there is no available ONLINE driver in the full seed, choose an unused
OFFLINE driver and set it online for the local demo with a direct
`UPDATE driver` statement. The API requires the driver to be ONLINE and to have
no other active order before accepting one. A driver's `GET /api/orders` also
lists currently available unassigned orders.

## API routes and SQL behavior

| Route | Required role | Behavior |
| --- | --- | --- |
| `GET /api/health` | Public | Checks MySQL connectivity |
| `POST /api/login` | Public | Matches email/password with a parameterized `SELECT` |
| `GET /api/profile` | Any signed-in role | Loads the current user's role-specific profile |
| `GET /api/restaurants` | Public | Reads approved restaurants, including closed ones |
| `GET /api/restaurants/{id}/menu` | Public | Reads all menu items with availability flags |
| `POST /api/cart/items` | Customer | Validates restaurant/item availability and adds to session cart |
| `POST /api/orders` | Customer | Inserts order and order items in one transaction |
| `POST /api/orders/{id}/confirm` | Restaurant owner | `PENDING` to `CONFIRMED` |
| `POST /api/orders/{id}/prepare` | Restaurant owner | `CONFIRMED` to `PREPARING` |
| `POST /api/orders/{id}/ready` | Restaurant owner | `PREPARING` to `READY` |
| `POST /api/orders/{id}/accept` | Driver | Assigns the driver's ID to an eligible order |
| `POST /api/orders/{id}/complete` | Assigned driver | Writes `READY` → `PICKED_UP` → `DELIVERING` → `COMPLETED` |
| `POST /api/driver/status` | Driver | Switches availability between `ONLINE` and `OFFLINE`; an active delivery must be completed first |
| `GET /api/admin/stats` | Admin | Explicit aggregate SQL for order counts, GMV, and food revenue |

The API sets MySQL session variable `@app_user_id` inside the same transaction
as writes that activate database triggers. The database triggers remain
responsible for order totals, audit rows, driver availability, and valid state
transitions. API sessions and shopping carts are in memory and reset when the
server restarts. `database.py` uses the customer MySQL account for login and
public catalog reads; after login it selects the dedicated Customer,
Restaurant, Driver, or Admin account and runs `SET ROLE` for the corresponding
MySQL role on every connection. Missing accounts or role grants are reported
explicitly. This is a local coursework demonstrator, not a production
authentication or deployment setup.

## Nine requested test scenarios

1. Log in using a `Customer` account.
2. Load restaurants and verify the response comes from MySQL.
3. Choose an available item and add it to the cart.
4. Place the order; inspect `order` and `order_item` in MySQL.
5. Log in as the order's restaurant owner and confirm it.
6. Start preparing, then mark the order ready.
7. Log in as an `ONLINE` driver and accept the order.
8. Complete the delivery; verify the final status is `COMPLETED`.
9. Log in as `Admin` and load statistics.

Useful verification SQL:

```sql
SELECT order_id, status, total_amount, delivery_fee, driver_id
FROM food_delivery_db.`order`
ORDER BY order_id DESC
LIMIT 10;

SELECT order_id, old_status, new_status, changed_by, changed_at
FROM food_delivery_db.audit_log
ORDER BY log_id DESC
LIMIT 20;

SELECT COUNT(*) AS total_orders,
       SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
       COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN total_amount ELSE 0 END), 0) AS completed_gmv,
       COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN total_amount - delivery_fee ELSE 0 END), 0) AS food_revenue
FROM food_delivery_db.`order`;
```
