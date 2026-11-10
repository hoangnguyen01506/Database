# 🛵 Food Delivery Aggregator (Mini-DoorDash) - Group G4

> **Course:** INT1313 - Database Systems  
> **Semester:** Semester 1 (2026 - 2027)  
> **University:** Posts and Telecommunications Institute of Technology - Campus 2 (PTIT HCM)

---

## 👥 Team Members

| No. | Full Name | Student ID / Email |
| :-: | :--- | :--- |
| 1 | **Trần Thanh Nhuận** | `n24dece085@student.ptithcm.edu.vn` |
| 2 | **Trần Hoàng Nguyên** | `n24dece084@student.ptithcm.edu.vn` |
| 3 | **Thái Tuấn Vũ** | `n24dece104@student.ptithcm.edu.vn` |

---

## 📐 Database Design (DDD)

**Database Documentation:** [View Database Schema on dbdocs.io](https://dbdocs.io/17-thanh-nhuan/test)

---

## 📌 Project Overview

### 1. Project Objectives

This project aims to design and develop a **relational database system** for an online **Food Delivery Aggregator** application, similar to a mini-DoorDash. The system addresses the need to connect three main participants on a single platform: **Customers**, **Restaurant Partners**, and **Driver Partners**.

### 2. Key Database Components

- **Extended EER Model:** Apply **specialization/generalization relationships (IS-A Hierarchy)** with the central `User` entity and its subclasses: `Customer`, `Restaurant`, and `Driver`.

- **Order Lifecycle Management:** Track and maintain **data integrity throughout the entire order lifecycle**, from order creation and food preparation to pickup and successful delivery.

- **Operational Management (Hub & Shift):** Manage drivers and restaurants based on specific **operational hubs/areas (`Hub`)**, while tracking **work shifts (`Shift`)**, driver earnings, and driver bonuses.

- **Supporting Features:** Integrate supporting modules including **Shopping Cart (`Cart`)**, **Promotions (`Coupon`)**, **Order Change History (`AuditLog`)**, **Reviews (`Review`)**, **Payments (`Payment`)**, and **Notifications (`Notification`)**.

### 3. Technologies & Tools

- **Database Management System (DBMS):** MySQL
- **Design Methodology:** Extended Entity-Relationship (EER) Modeling & Database Normalization

---

## 📚 References & Documentation

The following resources were used for database design, implementation, and documentation:

1. **Database Schema Documentation:** [Mini-DoorDash Database Design - dbdocs.io](https://dbdocs.io/17-thanh-nhuan/test)
2. **MySQL Official Documentation:** [https://dev.mysql.com/doc/](https://dev.mysql.com/doc/)
3. **Database Normalization:** [Database Normalization Explained - Microsoft Learn](https://learn.microsoft.com/en-us/office/troubleshoot/access/database-normalization-description)
4. **Entity-Relationship Model:** [Entity Relationship Diagrams - Lucidchart](https://www.lucidchart.com/pages/er-diagrams)
5. **DoorDash Platform:** [https://www.doordash.com/](https://www.doordash.com/)

---

*Developed by Group G4 - INT1313 Database Systems, PTIT HCM.*
