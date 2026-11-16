import os
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import database


class DatabaseRoleTests(unittest.TestCase):
    @patch.dict(os.environ, {
        "MYSQL_CUSTOMER_USER": "food_delivery_customer",
        "MYSQL_CUSTOMER_PASSWORD": "customer-password",
    }, clear=True)
    @patch("database.mysql.connector.connect")
    def test_customer_connection_activates_customer_role(self, mysql_connect):
        cursor = Mock()
        connection = Mock()
        connection.cursor.return_value = cursor
        mysql_connect.return_value = connection

        result = database.connect("Customer")

        self.assertIs(result, connection)
        cursor.execute.assert_called_once_with("SET ROLE 'role_customer'")
        cursor.close.assert_called_once_with()
        mysql_connect.assert_called_once_with(
            host="127.0.0.1",
            port=3306,
            user="food_delivery_customer",
            password="customer-password",
            database="food_delivery_db",
            charset="utf8mb4",
            collation="utf8mb4_unicode_ci",
            autocommit=False,
            connection_timeout=5,
        )

    def test_every_application_role_activates_its_matching_mysql_role(self):
        for app_role, (username_key, password_key, mysql_role) in database.ROLE_CONFIG.items():
            username = "account_" + app_role.lower()
            environment = {username_key: username, password_key: "test-password"}
            with self.subTest(app_role=app_role):
                with patch.dict(os.environ, environment, clear=True):
                    with patch("database.mysql.connector.connect") as mysql_connect:
                        connection = Mock()
                        cursor = Mock()
                        connection.cursor.return_value = cursor
                        mysql_connect.return_value = connection

                        database.connect(app_role)

                        cursor.execute.assert_called_once_with("SET ROLE '%s'" % mysql_role)

    @patch.dict(os.environ, {}, clear=True)
    @patch("database.mysql.connector.connect")
    def test_missing_role_account_fails_before_connecting(self, mysql_connect):
        with self.assertRaisesRegex(
            database.DatabaseRoleConfigurationError,
            "MYSQL_CUSTOMER_USER is not set",
        ):
            database.connect("Customer")
        mysql_connect.assert_not_called()

    @patch.dict(os.environ, {"MYSQL_CUSTOMER_USER": "food_delivery_customer"}, clear=True)
    @patch("database.mysql.connector.connect")
    def test_ungranted_role_closes_connection_and_reports_setup_error(self, mysql_connect):
        cursor = Mock()
        cursor.execute.side_effect = database.mysql.connector.Error("role not granted")
        connection = Mock()
        connection.cursor.return_value = cursor
        mysql_connect.return_value = connection

        with self.assertRaisesRegex(
            database.DatabaseRoleConfigurationError,
            "role_customer.*granted",
        ):
            database.connect("Customer")

        cursor.close.assert_called_once_with()
        connection.close.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
