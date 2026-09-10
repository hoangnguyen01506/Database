-- 1. Tạo bảng cha (User) trước
CREATE TABLE User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Phone VARCHAR(15) NOT NULL UNIQUE,
    Email VARCHAR(100),
    Password VARCHAR(255) NOT NULL,
    Role VARCHAR(20) NOT NULL,
    Address TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tạo các bảng con tham chiếu đến UserID
CREATE TABLE Restaurant (
    RestaurantID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    BusinessLicense VARCHAR(50),
    CuisineType VARCHAR(100),
    OpeningHours VARCHAR(100),
    CommissionRate DECIMAL(5,2),
    HubID INT,
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Customer (
    CustomerID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    LoyaltyPoints INT DEFAULT 0,
    TotalOrders INT DEFAULT 0,
    PreferredPayment VARCHAR(50),
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Driver (
    DriverID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    DriverLicense VARCHAR(50),
    VehicleType VARCHAR(50),
    PlateNumber VARCHAR(20),
    CurrentLocation VARCHAR(255),
    Status VARCHAR(20),
    HubID INT,
    FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
);