# API giao món FoodieGo

API Python này phục vụ giao diện demo tại `http://127.0.0.1:8000` và đọc/ghi
cơ sở dữ liệu MySQL. Mỗi module phụ trách một phần chức năng; câu truy vấn SQL
được viết tường minh, có tham số và không dùng ORM. API kết nối MySQL bằng tài
khoản riêng theo vai trò, sau đó kích hoạt role tương ứng.

## Vai trò các tệp

| Tệp | Nhiệm vụ |
| --- | --- |
| `main.py` | Khởi động máy chủ và tự mở trang demo trong trình duyệt |
| `server.py` | Định tuyến HTTP và phục vụ trang tĩnh |
| `base_handler.py` | Xử lý JSON, phiên đăng nhập, truy vấn chung và lỗi |
| `auth_routes.py` | Đăng nhập, mở ca làm cho tài xế |
| `profile_routes.py` | Đọc hồ sơ, cập nhật trạng thái và ca tài xế |
| `catalog_routes.py` | Nhà hàng, thực đơn và giỏ hàng theo phiên |
| `order_routes.py` | Tạo đơn, thống kê nhà hàng, kiểm tra quyền xem, xử lý giao hàng |
| `notification_routes.py` | Đọc hộp thư notification và đánh dấu đã đọc |
| `admin_routes.py` | Truy vấn thống kê chỉ đọc cho Admin |
| `database.py` | Kết nối MySQL theo role và helper truy vấn |
| `sessions.py` | Lưu phiên trong bộ nhớ; phiên mất khi API khởi động lại |
| `config.py` | Đọc cấu hình API và `api/.env` |
| `errors.py` | Kiểu lỗi API có mã trạng thái HTTP |
| `index.html` | Khung giao diện cho Khách hàng, Nhà hàng, Tài xế và Admin |
| `static/app.js` | Điều phối đăng nhập và chuyển màn hình theo role |
| `static/shared.js`, `static/orders.js`, `static/notifications.js` | Gọi API, hiển thị đơn và notification dùng chung |
| `static/customer.js` | Màn hình khách: tìm quán, chọn món, giỏ hàng, đơn hàng |
| `static/restaurant.js` | Màn hình nhà hàng: xử lý đơn và xem thực đơn |
| `static/driver.js` | Màn hình tài xế: trực tuyến và giao đơn |
| `static/admin.js` | Màn hình Admin: thống kê và xem đơn |
| `static/app.css` | Kiểu dáng giao diện cho các màn hình |
| `requirements.txt` | Khai báo thư viện Python cần cài |
| `.env.example` | Mẫu biến môi trường; cần sao chép thành `.env` và tự điền cấu hình |

Không có module mã nguồn API nào bị bỏ vì tất cả đều được import hoặc được
máy chủ sử dụng. Các thư mục `__pycache__` chỉ chứa bytecode Python tự sinh,
không phải tệp cần để chạy demo. Tệp kiểm thử cấu hình role đã được bỏ khỏi
thư mục demo vì không được API sử dụng khi chạy.

## Cài đặt và chạy demo

1. Cài MySQL 8 và tạo bảng bằng `mysql/schemasql.sql`.
2. Nạp `mysql/food_delivery_complete_5000_mysql.sql` ngay sau schema và trước
   `mysql/indexes/indexes.sql`, `mysql/triggers/triggers.sql` và
   `mysql/views/views.sql`.
3. API ghi notification trong transaction. Không chạy
   `mysql/migrations/004_driver_status_notifications.sql` cho cấu hình API này;
   nếu database còn trigger notification cũ, gỡ trigger theo hướng dẫn ở phần
   quyền notification bên dưới để tránh ghi trùng.
4. Có thể chạy `mysql/seed/sample_data.sql` một lần bằng tài khoản DBA để thêm
   dữ liệu demo sau khi seed, indexes, triggers và views đã sẵn sàng.
5. Chạy `mysql/security/roles.sql` sau khi cài schema, dữ liệu, indexes,
   triggers và views. Nếu cập nhật quyền, chạy lại bằng tài khoản quản trị DB.
6. Tạo một tài khoản MySQL cho mỗi role ứng dụng và cấp đúng role tương ứng.
   Host tài khoản phải khớp với `MYSQL_HOST` (mặc định `127.0.0.1`):

   ```sql
   CREATE USER 'food_delivery_customer'@'127.0.0.1' IDENTIFIED BY 'thay-mat-khau-customer';
   GRANT 'role_customer' TO 'food_delivery_customer'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_customer'@'127.0.0.1';

   CREATE USER 'food_delivery_restaurant'@'127.0.0.1' IDENTIFIED BY 'thay-mat-khau-restaurant';
   GRANT 'role_restaurant' TO 'food_delivery_restaurant'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_restaurant'@'127.0.0.1';

   CREATE USER 'food_delivery_driver'@'127.0.0.1' IDENTIFIED BY 'thay-mat-khau-driver';
   GRANT 'role_driver' TO 'food_delivery_driver'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_driver'@'127.0.0.1';

   CREATE USER 'food_delivery_admin'@'127.0.0.1' IDENTIFIED BY 'thay-mat-khau-admin';
   GRANT 'role_admin' TO 'food_delivery_admin'@'127.0.0.1';
   SET DEFAULT ROLE NONE TO 'food_delivery_admin'@'127.0.0.1';
   ```

   Nếu tài khoản đã tồn tại, không chạy lại `CREATE USER`; dùng
   `ALTER USER ... IDENTIFIED BY ...` để đổi mật khẩu.
7. Sao chép `api/.env.example` thành `api/.env`, rồi điền tài khoản và mật
   khẩu MySQL tương ứng. Chỉ lưu mật khẩu thật trong `.env`; không đưa vào Git.
8. Tại thư mục gốc dự án, cài connector:

   ```powershell
   python -m pip install -r api\requirements.txt
   ```

9. Chạy `python api\main.py` hoặc mở `api\main.py`. Giữ cửa sổ terminal mở
   trong lúc demo; nhấn Ctrl+C tại đó để dừng máy chủ.

Các tài khoản do `sample_data.sql` tạo dùng mật khẩu demo `demo123`. Bộ dữ liệu
5.000 có mật khẩu demo riêng của từng tài khoản; có thể tra cứu cục bộ trong
MySQL. API hiện so sánh mật khẩu dạng rõ; đây chỉ là dữ liệu học tập, không dùng
cho tài khoản thực tế.

Để tìm tài khoản phù hợp với luồng demo:

```sql
SELECT user_id, name, phone, password, role
FROM food_delivery_db.`user`
WHERE role = 'Customer'
ORDER BY user_id
LIMIT 5;

SELECT u.user_id, u.phone, r.restaurant_id, r.is_open
FROM food_delivery_db.restaurant AS r
JOIN food_delivery_db.`user` AS u ON u.user_id = r.user_id
WHERE r.is_approved = 1 AND r.is_open = 1
ORDER BY r.restaurant_id
LIMIT 10;

SELECT u.user_id, u.phone, d.driver_id, d.status
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

SELECT user_id, name, phone
FROM food_delivery_db.`user`
WHERE role = 'Admin'
ORDER BY user_id
LIMIT 5;
```

Chọn nhà hàng đang mở, món còn bán và tài xế đang ONLINE. Nếu không có tài xế
phù hợp, có thể chọn tài xế OFFLINE chưa có đơn đang hoạt động và cập nhật trạng
thái bằng MySQL cho mục đích demo.

## API và quyền truy cập

| Đường dẫn | Vai trò | Chức năng |
| --- | --- | --- |
| `GET /api/health` | Công khai | Kiểm tra API và kết nối MySQL |
| `POST /api/login` | Công khai | Đăng nhập bằng số điện thoại và mật khẩu |
| `GET /api/profile` | Đã đăng nhập | Đọc hồ sơ theo role |
| `GET /api/driver/shift` | Tài xế | Đọc ca làm gần nhất để hiển thị giờ bắt đầu, giờ kết thúc và thời lượng |
| `GET /api/restaurants` | Công khai | Đọc nhà hàng đã duyệt |
| `GET /api/restaurants/{id}/menu` | Công khai | Đọc thực đơn |
| `GET /api/restaurant/stats` | Nhà hàng | Thống kê toàn bộ đơn của nhà hàng |
| `POST /api/cart/items` | Khách hàng | Thêm món vào giỏ theo phiên |
| `POST /api/orders` | Khách hàng | Tạo đơn và chi tiết món trong một giao dịch |
| `GET /api/orders` | Đã đăng nhập | Liệt kê đơn theo phạm vi role |
| `GET /api/notifications` | Khách hàng, nhà hàng, tài xế | Đọc tối đa 50 thông báo của tài khoản |
| `POST /api/notifications/{id}/read` | Khách hàng, nhà hàng, tài xế | Đánh dấu thông báo đã đọc |
| `POST /api/orders/{id}/reviews` | Khách hàng | Đánh giá nhà hàng hoặc tài xế cho đơn hoàn tất |
| `POST /api/orders/{id}/confirm` | Chủ nhà hàng | Xác nhận đơn |
| `POST /api/orders/{id}/prepare` | Chủ nhà hàng | Bắt đầu chuẩn bị |
| `POST /api/orders/{id}/ready` | Chủ nhà hàng | Đánh dấu món đã sẵn sàng |
| `POST /api/orders/{id}/accept` | Tài xế | Tự nhận đơn đủ điều kiện |
| `POST /api/orders/{id}/pickup` | Tài xế được phân công | Chuyển READY → PICKED_UP |
| `POST /api/orders/{id}/start-delivery` | Tài xế được phân công | Chuyển PICKED_UP → DELIVERING |
| `POST /api/orders/{id}/complete` | Tài xế được phân công | Chuyển DELIVERING → COMPLETED |
| `POST /api/driver/status` | Tài xế | Bật/tắt trạng thái trực tuyến |
| `GET /api/admin/stats` | Admin | Đọc thống kê đơn hàng và doanh thu |

API đặt `@app_user_id` trong cùng giao dịch với các thao tác kích hoạt trigger.
Trigger MySQL chịu trách nhiệm tính tổng đơn, ghi audit, trạng thái tài xế và
kiểm tra chuyển trạng thái. Mỗi yêu cầu kết nối bằng tài khoản MySQL riêng của
role và chạy `SET ROLE`. Admin API chỉ đọc dashboard; thao tác quản trị DB phải
dùng tài khoản DBA riêng.

Khi nhà hàng xác nhận đơn, bắt đầu chuẩn bị hoặc đánh dấu món đã sẵn sàng,
API ghi notification loại `ORDER` cho khách sở hữu đơn trong cùng transaction
với cập nhật trạng thái. Khách nhận notification qua `GET /api/notifications`.

Khi tài xế đăng nhập, API chuyển trạng thái phù hợp với đơn đang hoạt động và
mở một ca mới nếu chưa có ca hiện tại. Chuyển sang ngoại tuyến kết thúc ca;
API ghi notification trong cùng transaction khi trạng thái tài xế thực sự thay
đổi. Với đơn có liên quan, notification được ghi cho tài xế, khách hàng và nhà
hàng của đơn; đổi ONLINE/OFFLINE không gắn với đơn chỉ thông báo cho tài xế.
Các quyền đọc, đánh dấu đã đọc và ghi notification đã được khai báo trong
`mysql/security/roles.sql`. Chạy lại script bằng tài khoản quản trị DB để cấp
các quyền này. 
```

Checkout khóa và kiểm tra các món trong giỏ, sau đó chèn giá và tên tạm vào
`order_item`. Trigger `trg_order_item_before_insert` lấy snapshot tên/giá từ
thực đơn, còn trigger sau INSERT tính lại tổng đơn; vì vậy cần cài và bật
`mysql/triggers/triggers.sql` trước khi dùng checkout. API đọc tổng đã tính từ
database để tạo thanh toán MoMo giả lập trong cùng transaction. Khách có thể
gửi đánh giá 1–5 sao cho nhà hàng và tài xế sau khi đơn ở trạng thái
`COMPLETED`; trigger kiểm tra chủ đơn và giới hạn đánh giá trùng.
