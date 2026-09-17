# 🛵 Food Delivery Aggregator (Mini-DoorDash) - Group G4

> **Môn học:** INT1313 - Cơ sở dữ liệu (Database Systems)  
> **Học kỳ:** Học kỳ 1 (2026 - 2027)  
> **Trường:** Học viện Công nghệ Bưu chính Viễn thông CS2 (PTIT HCM)

---

## 👥 Thành viên nhóm (Team Members)

| STT | Họ và tên | Mã sinh viên / Email |
| :---: | :--- | :--- |
| 1 | **Trần Thanh Nhuận** | `n24dece085@student.ptithcm.edu.vn` |
| 2 | **Trần Hoàng Nguyên** | `n24dece084@student.ptithcm.edu.vn` |
| 3 | **Thái Tuấn Vũ** | `n24dece104@student.ptithcm.edu.vn` |

---

## 📌 Sơ lược về đồ án (Project Overview)

### 1. Mục tiêu bài toán
Đồ án xây dựng và thiết kế hệ thống **Cơ sở dữ liệu quan hệ** cho mô hình ứng dụng đặt và giao đồ ăn trực tuyến (**Food Delivery Aggregator**). Hệ thống giải quyết bài toán kết nối ba đối tượng chính: **Khách hàng (Customer)**, **Đối tác nhà hàng (Restaurant)** và **Đối tác tài xế (Driver)** trên cùng một nền tảng.

### 2. Các điểm trọng tâm của cơ sở dữ liệu
* **Mô hình EER Mở rộng:** Áp dụng mối quan hệ chuyên biệt hóa/tổng quát hóa (IS-A Hierarchy) với bảng trung tâm `User` và các bảng con `Customer`, `Restaurant`, `Driver`.
* **Quản lý vòng đời đơn hàng:** Lưu vết và duy trì tính toàn vẹn dữ liệu xuyên suốt các trạng thái đơn hàng (từ khi tạo đơn, chuẩn bị món, lấy hàng đến khi hoàn tất giao hàng).
* **Phân vùng vận hành (Hub & Shift):** Quản lý tài xế và nhà hàng theo từng trạm/khu vực vận hành (`Hub`), đồng thời theo dõi ca làm việc (`Shift`) và doanh thu/tiền thưởng của tài xế.
* **Tính năng phụ trợ:** Tích hợp các phân hệ Giỏ hàng (`Cart`), Khuyến mãi (`Coupon`), Lịch sử thay đổi đơn hàng (`AuditLog`), Đánh giá (`Review`), Thanh toán (`Payment`) và Thông báo (`Notification`).

### 3. Công nghệ & Công cụ
* **Hệ quản trị CSDL:** MySQL
* **Phương pháp thiết kế:** Extended Entity-Relationship (EER) Modeling & Normalization
