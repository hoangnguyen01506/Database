import os

import mysql.connector


ROLE_CONFIG = {
    "Customer": ("MYSQL_CUSTOMER_USER", "MYSQL_CUSTOMER_PASSWORD", "role_customer"),
    "Restaurant": ("MYSQL_RESTAURANT_USER", "MYSQL_RESTAURANT_PASSWORD", "role_restaurant"),
    "Driver": ("MYSQL_DRIVER_USER", "MYSQL_DRIVER_PASSWORD", "role_driver"),
    "Admin": ("MYSQL_ADMIN_USER", "MYSQL_ADMIN_PASSWORD", "role_admin"),
}


class DatabaseRoleConfigurationError(RuntimeError):
    pass


def connect(app_role="Customer"):
    if app_role not in ROLE_CONFIG:
        raise ValueError("Unsupported application role for database access")

    username_key, password_key, mysql_role = ROLE_CONFIG[app_role]
    username = os.getenv(username_key)
    if not username:
        raise DatabaseRoleConfigurationError(
            "%s is not set; configure a dedicated MySQL account for the %s role."
            % (username_key, app_role)
        )

    connection = mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=username,
        password=os.getenv(password_key, ""),
        database=os.getenv("MYSQL_DATABASE", "food_delivery_db"),
        charset="utf8mb4",
        collation="utf8mb4_unicode_ci",
        autocommit=False,
        connection_timeout=5,
    )
    cursor = connection.cursor()
    try:
        cursor.execute("SET ROLE '%s'" % mysql_role)
    except mysql.connector.Error as exc:
        try:
            cursor.close()
        finally:
            connection.close()
        raise DatabaseRoleConfigurationError(
            "Could not activate MySQL role '%s' for account '%s'. Check that the role "
            "exists and is granted to that account."
            % (mysql_role, username)
        ) from exc
    cursor.close()
    return connection


def query_all(sql, parameters=(), app_role="Customer"):
    connection = connect(app_role)
    try:
        cursor = connection.cursor(dictionary=True)
        try:
            cursor.execute(sql, parameters)
            return cursor.fetchall()
        finally:
            cursor.close()
    finally:
        connection.close()


def query_one(sql, parameters=(), app_role="Customer"):
    rows = query_all(sql, parameters, app_role)
    return rows[0] if rows else None
