# MySQL scripts

Run the scripts against a fresh MySQL 8.0.16+ database in this order.
The performance benchmarks require MySQL 8.0.18+:

1. `schemasql.sql`
2. `indexes/indexes.sql`
3. `triggers/triggers.sql`
4. `views/views.sql`
5. `seed/sample_data.sql` (optional; demo data, run once)
6. Run any individual script in `queries/` or `performance/benchmarks.sql`
7. `tests/00_helpers.sql`, then each `tests/0*.sql` file in numeric order
   (requires the demo data; each test file rolls back its own test data)
8. `security/roles.sql` (requires the views and an account allowed to manage roles)

For the API, create four dedicated MySQL accounts after installing these roles.
Grant each account only its matching `role_customer`, `role_restaurant`,
`role_driver`, or `role_admin` role, then configure the matching credentials in
`api/.env`. The API activates the role for every connection. Do not use MySQL
`root` for the API because its direct privileges bypass role restrictions.
Re-run `security/roles.sql` after updating it so the added API permissions are
applied to existing roles.

For the full 5,000-user dataset, use `food_delivery_complete_5000_mysql.sql`
instead of `seed/sample_data.sql`. Run it immediately after `schemasql.sql`,
before installing triggers, because it imports historical orders and audit
records directly. Then continue with the indexes, triggers, views, and security
scripts above. Do not load both seed files into the same database.
If MySQL reports error 1644, `trg_order_before_insert` was installed before the
full seed: its rule correctly rejects historical orders that are not new,
unassigned `PENDING` orders. Do not disable or weaken the trigger to load the
fixture. Roll back the failed import transaction and load the full dataset into
a fresh, empty database in the order above. Do not rerun the seed on top of
partially imported or existing sample data.

If the failed import is still open in the same MySQL connection, run:

```sql
ROLLBACK;
```

This undoes the inserts made by that seed transaction; it does not remove
pre-existing rows or triggers.
The numbered integrity tests are written for the small `seed/sample_data.sql`
fixture and should not be run against the full dataset.
The full dataset has 5,086 users with random six-character plaintext demo
passwords, a designated group of 20 customers without orders, 10 idle drivers,
5 restaurants awaiting approval, 20 approved but closed restaurants, and
unavailable menu items. These passwords are only for coursework/demo data.

`schemasql.sql` creates and selects `food_delivery_db`. Index scripts are intended
to run once after the schema. The `idx_order_item_order` index is declared with
the `order_item` foreign key in the schema so MySQL does not create a duplicate
index automatically. Demo accounts use a deliberately invalid password hash
placeholder; replace it with an application-generated bcrypt hash before
testing authentication.

Before creating an order, set `@app_user_id` to the authenticated customer's
`user_id`; the trigger verifies that the customer owns the new order. Set the
same session variable to the authenticated staff member before status changes
or driver assignments so audit rows record the actor. The seed demonstrates
customer, restaurant, and driver actors through a completed order lifecycle.

The files in `queries/` are standalone query groups. The integrity-test helper
procedure must be installed once per database before running the numbered test
files; each test file is intended to run in its own MySQL session.

The report's cart and coupon modules remain out of scope, as described in its
future-enhancements section. Role grants include the report's customer order,
item, and payment inserts, restaurant order-status/driver-assignment updates,
and driver availability/order-status/assignment updates.
Database grants are table-level; the application must still enforce row
ownership for customer, restaurant, and driver reads and updates. The reporting
order-summary view includes customer names and should be granted only to
authorized reporting users.
