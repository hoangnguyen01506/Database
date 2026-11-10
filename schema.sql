-- Disable check constraints temporarily for script execution
SET @OLD_UNIQUE_CHECKS = @@UNIQUE_CHECKS, UNIQUE_CHECKS = 0;
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS = 0;
SET @OLD_SQL_MODE = @@SQL_MODE, SQL_MODE = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema: food_delivery_db
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS food_delivery_db
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE food_delivery_db;

-- -----------------------------------------------------
-- Table: user
-- -----------------------------------------------------
CREATE TABLE user (
  user_id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) NOT NULL,
  email VARCHAR(100) DEFAULT NULL,
  password VARCHAR(255) NOT NULL,
  role ENUM('CUSTOMER', 'RESTAURANT', 'DRIVER', 'ADMIN') NOT NULL,
  address TEXT DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE INDEX uq_user_phone (phone ASC),
  UNIQUE INDEX uq_user_email (email ASC)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: address
-- -----------------------------------------------------
CREATE TABLE address (
  address_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  label VARCHAR(50) DEFAULT NULL,
  recipient_name VARCHAR(100) NOT NULL,
  recipient_phone VARCHAR(20) NOT NULL,
  address_line TEXT NOT NULL,
  ward VARCHAR(100) DEFAULT NULL,
  district VARCHAR(100) DEFAULT NULL,
  city VARCHAR(100) DEFAULT NULL,
  latitude DECIMAL(10, 7) DEFAULT NULL,
  longitude DECIMAL(10, 7) DEFAULT NULL,
  is_default TINYINT(1) NOT NULL,
  PRIMARY KEY (address_id),
  INDEX idx_address_user_id (user_id ASC),
  CONSTRAINT fk_address_user
    FOREIGN KEY (user_id)
    REFERENCES user (user_id)
    ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: customer
-- -----------------------------------------------------
CREATE TABLE customer (
  customer_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  loyalty_points INT DEFAULT NULL,
  total_orders INT DEFAULT NULL,
  preferred_payment VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (customer_id),
  UNIQUE INDEX uq_customer_user_id (user_id ASC),
  CONSTRAINT fk_customer_user
    FOREIGN KEY (user_id)
    REFERENCES user (user_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: hub
-- -----------------------------------------------------
CREATE TABLE hub (
  hub_id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  location VARCHAR(255) NOT NULL,
  manager_id INT DEFAULT NULL,
  operating_area VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (hub_id),
  INDEX idx_hub_manager_id (manager_id ASC),
  CONSTRAINT fk_hub_manager
    FOREIGN KEY (manager_id)
    REFERENCES user (user_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: restaurant
-- -----------------------------------------------------
CREATE TABLE restaurant (
  restaurant_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  business_license VARCHAR(50) DEFAULT NULL,
  cuisine_type VARCHAR(100) DEFAULT NULL,
  opening_hours VARCHAR(100) DEFAULT NULL,
  commission_rate DECIMAL(5, 2) DEFAULT NULL,
  hub_id INT DEFAULT NULL,
  is_approved TINYINT(1) NOT NULL,
  is_open TINYINT(1) NOT NULL,
  min_order_amount DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (restaurant_id),
  UNIQUE INDEX uq_restaurant_user_id (user_id ASC),
  INDEX idx_restaurant_hub_id (hub_id ASC),
  CONSTRAINT fk_restaurant_user
    FOREIGN KEY (user_id)
    REFERENCES user (user_id),
  CONSTRAINT fk_restaurant_hub
    FOREIGN KEY (hub_id)
    REFERENCES hub (hub_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: driver
-- -----------------------------------------------------
CREATE TABLE driver (
  driver_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  driver_license VARCHAR(50) DEFAULT NULL,
  vehicle_type VARCHAR(50) DEFAULT NULL,
  plate_number VARCHAR(20) DEFAULT NULL,
  current_location VARCHAR(255) DEFAULT NULL,
  status ENUM('ONLINE', 'OFFLINE', 'BUSY') DEFAULT NULL,
  hub_id INT DEFAULT NULL,
  PRIMARY KEY (driver_id),
  UNIQUE INDEX uq_driver_user_id (user_id ASC),
  INDEX idx_driver_hub_id (hub_id ASC),
  CONSTRAINT fk_driver_user
    FOREIGN KEY (user_id)
    REFERENCES user (user_id),
  CONSTRAINT fk_driver_hub
    FOREIGN KEY (hub_id)
    REFERENCES hub (hub_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: menu_item
-- -----------------------------------------------------
CREATE TABLE menu_item (
  menu_item_id INT NOT NULL AUTO_INCREMENT,
  restaurant_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT DEFAULT NULL,
  price DECIMAL(10, 2) NOT NULL,
  category VARCHAR(50) DEFAULT NULL,
  is_available TINYINT(1) DEFAULT NULL,
  PRIMARY KEY (menu_item_id),
  INDEX idx_menu_item_restaurant_id (restaurant_id ASC),
  CONSTRAINT fk_menu_item_restaurant
    FOREIGN KEY (restaurant_id)
    REFERENCES restaurant (restaurant_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: order
-- -----------------------------------------------------
CREATE TABLE `order` (
  order_id INT NOT NULL AUTO_INCREMENT,
  customer_id INT NOT NULL,
  restaurant_id INT NOT NULL,
  driver_id INT DEFAULT NULL,
  order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  total_amount DECIMAL(10, 2) NOT NULL,
  status ENUM('PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'PICKED_UP', 'DELIVERING', 'COMPLETED', 'CANCELLED') DEFAULT NULL,
  delivery_fee DECIMAL(10, 2) DEFAULT NULL,
  payment_method VARCHAR(50) DEFAULT NULL,
  delivery_address_snapshot TEXT DEFAULT NULL,
  PRIMARY KEY (order_id),
  INDEX idx_order_customer_id (customer_id ASC),
  INDEX idx_order_restaurant_id (restaurant_id ASC),
  INDEX idx_order_driver_id (driver_id ASC),
  CONSTRAINT fk_order_customer
    FOREIGN KEY (customer_id)
    REFERENCES customer (customer_id),
  CONSTRAINT fk_order_restaurant
    FOREIGN KEY (restaurant_id)
    REFERENCES restaurant (restaurant_id),
  CONSTRAINT fk_order_driver
    FOREIGN KEY (driver_id)
    REFERENCES driver (driver_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: order_item
-- -----------------------------------------------------
CREATE TABLE order_item (
  order_item_id INT NOT NULL AUTO_INCREMENT,
  order_id INT NOT NULL,
  menu_item_id INT NOT NULL,
  quantity INT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  item_name VARCHAR(100) NOT NULL,
  PRIMARY KEY (order_item_id),
  INDEX idx_order_item_order_id (order_id ASC),
  INDEX idx_order_item_menu_item_id (menu_item_id ASC),
  CONSTRAINT fk_order_item_order
    FOREIGN KEY (order_id)
    REFERENCES `order` (order_id),
  CONSTRAINT fk_order_item_menu_item
    FOREIGN KEY (menu_item_id)
    REFERENCES menu_item (menu_item_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: payment
-- -----------------------------------------------------
CREATE TABLE payment (
  payment_id INT NOT NULL AUTO_INCREMENT,
  order_id INT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  payment_method VARCHAR(50) NOT NULL,
  status ENUM('PENDING', 'SUCCESS', 'FAILED') DEFAULT NULL,
  transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  provider VARCHAR(50) DEFAULT NULL,
  provider_transaction_id VARCHAR(150) DEFAULT NULL,
  paid_at DATETIME DEFAULT NULL,
  failure_reason VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (payment_id),
  UNIQUE INDEX uq_payment_provider_tx_id (provider_transaction_id ASC),
  INDEX idx_payment_order_id (order_id ASC),
  CONSTRAINT fk_payment_order
    FOREIGN KEY (order_id)
    REFERENCES `order` (order_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: audit_log
-- -----------------------------------------------------
CREATE TABLE audit_log (
  log_id INT NOT NULL AUTO_INCREMENT,
  order_id INT NOT NULL,
  old_status VARCHAR(50) DEFAULT NULL,
  new_status VARCHAR(50) NOT NULL,
  changed_by INT NOT NULL,
  changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  INDEX idx_audit_log_order_id (order_id ASC),
  INDEX idx_audit_log_changed_by (changed_by ASC),
  CONSTRAINT fk_audit_log_order
    FOREIGN KEY (order_id)
    REFERENCES `order` (order_id),
  CONSTRAINT fk_audit_log_user
    FOREIGN KEY (changed_by)
    REFERENCES user (user_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: notification
-- -----------------------------------------------------
CREATE TABLE notification (
  notification_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  type ENUM('ORDER', 'PROMOTION', 'SYSTEM') NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  is_read TINYINT(1) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (notification_id),
  INDEX idx_notification_user_read (user_id ASC, is_read ASC, created_at ASC),
  CONSTRAINT fk_notification_user
    FOREIGN KEY (user_id)
    REFERENCES user (user_id)
    ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: review
-- -----------------------------------------------------
CREATE TABLE review (
  review_id INT NOT NULL AUTO_INCREMENT,
  order_id INT NOT NULL,
  reviewer_id INT NOT NULL,
  target_type ENUM('RESTAURANT', 'DRIVER') NOT NULL,
  rating INT DEFAULT NULL,
  comment TEXT DEFAULT NULL,
  review_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (review_id),
  UNIQUE INDEX uq_review_order_reviewer_target (order_id ASC, reviewer_id ASC, target_type ASC),
  INDEX idx_review_reviewer_id (reviewer_id ASC),
  CONSTRAINT fk_review_order
    FOREIGN KEY (order_id)
    REFERENCES `order` (order_id),
  CONSTRAINT fk_review_user
    FOREIGN KEY (reviewer_id)
    REFERENCES user (user_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Table: shift
-- -----------------------------------------------------
CREATE TABLE shift (
  shift_id INT NOT NULL AUTO_INCREMENT,
  driver_id INT NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME DEFAULT NULL,
  completed_orders INT DEFAULT NULL,
  bonus_earned DECIMAL(10, 2) DEFAULT NULL,
  PRIMARY KEY (shift_id),
  INDEX idx_shift_driver_id (driver_id ASC),
  CONSTRAINT fk_shift_driver
    FOREIGN KEY (driver_id)
    REFERENCES driver (driver_id)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- Restore Session Variables
-- -----------------------------------------------------
SET SQL_MODE = @OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS = @OLD_UNIQUE_CHECKS;
