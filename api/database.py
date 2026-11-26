"""Kết nối MySQL theo role ứng dụng và cung cấp helper truy vấn chỉ đọc."""

import os

import mysql.connector


ROLE_CONFIG = {
    "Customer": ("MYSQL_CUSTOMER_USER", "MYSQL_CUSTOMER_PASSWORD", "role_customer"),
    "Restaurant": ("MYSQL_RESTAURANT_USER", "MYSQL_RESTAURANT_PASSWORD", "role_restaurant"),
    "Driver": ("MYSQL_DRIVER_USER", "MYSQL_DRIVER_PASSWORD", "role_driver"),
    "Admin": ("MYSQL_ADMIN_USER", "MYSQL_ADMIN_PASSWORD", "role_admin"),
}


class DatabaseRoleConfigurationError(RuntimeError):
    """Lỗi cấu hình tài khoản hoặc quyền role MySQL của API."""

    pass


def connect(app_role="Customer"):
    """Kết nối bằng tài khoản riêng, bật role tương ứng và chọn database."""
    if app_role not in ROLE_CONFIG:
        raise ValueError("Unsupported application role for database access")

    username_key, password_key, mysql_role = ROLE_CONFIG[app_role]
    username = os.getenv(username_key)
    if not username:
        raise DatabaseRoleConfigurationError(
            "%s is not set; configure a dedicated MySQL account for the %s role."
            % (username_key, app_role)
        )

    database_name = os.getenv("MYSQL_DATABASE", "food_delivery_db")
    connection = mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=username,
        password=os.getenv(password_key, ""),
        charset="utf8mb4",
        collation="utf8mb4_unicode_ci",
        autocommit=False,
        connection_timeout=5,
    )
    cursor = connection.cursor()
    try:
        cursor.execute("SET ROLE '%s'" % mysql_role)
        connection.database = database_name
    except mysql.connector.Error as exc:
        try:
            cursor.close()
        finally:
            connection.close()
        raise DatabaseRoleConfigurationError(
            "Could not activate MySQL role '%s' or select database '%s' for account '%s'. "
            "Check that the role exists, is granted to the account, and has database access."
            % (mysql_role, database_name, username)
        ) from exc
    cursor.close()
    return connection


def query_all(sql, parameters=(), app_role="Customer"):
    """Chạy SELECT có tham số và trả về danh sách dòng dạng dictionary."""
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
    """Chạy SELECT có tham số và trả dòng đầu tiên nếu có."""
    rows = query_all(sql, parameters, app_role)
    return rows[0] if rows else None
