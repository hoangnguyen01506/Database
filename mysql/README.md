# Các tệp MySQL

Các script được viết cho MySQL 8.0.16 trở lên. Benchmark dùng `EXPLAIN ANALYZE`
nên yêu cầu MySQL 8.0.18 trở lên.

## Cài mới với fixture nhỏ

Chạy các file theo thứ tự:

1. `schemasql.sql`
2. `indexes/indexes.sql`
3. `triggers/triggers.sql`
4. `views/views.sql`
5. `seed/sample_data.sql` (tùy chọn, chỉ nạp một lần)
6. Chạy từng file cần thiết trong `queries/`; chạy toàn bộ
   `performance/benchmarks.sql` một lần để thực thi cả chín benchmark
7. Chạy `tests/negative_test_execution.sql` (chỉ dành cho fixture nhỏ, cần tài
   khoản quản trị DB; các thay đổi kiểm thử được rollback)
8. `security/roles.sql` (cần có views và tài khoản được phép quản lý role)

## Cài mới với bộ dữ liệu 5.000

Dùng `food_delivery_complete_5000_mysql.sql` thay cho `seed/sample_data.sql`:

1. `schemasql.sql`
2. `food_delivery_complete_5000_mysql.sql`
3. `indexes/indexes.sql`
4. `triggers/triggers.sql`
5. `views/views.sql`
6. `security/roles.sql`

Full seed phải chạy ngay sau schema và **trước khi cài triggers**, vì seed nạp
đơn hàng và audit lịch sử. Không nạp cả hai bộ seed vào cùng database và không
chạy `tests/negative_test_execution.sql` trên bộ dữ liệu 5.000. Nếu seed lỗi,
không chạy lại trên database đã nạp dở hoặc có dữ liệu; rollback giao dịch lỗi
và bắt đầu trên database rỗng.

Các cập nhật trong full seed tương thích MySQL Workbench Safe Update Mode. Nếu
gặp lỗi 1644, có thể trigger `trg_order_before_insert` đã được cài trước khi
nạp seed; trigger đang bảo vệ quy tắc đơn mới phải bắt đầu ở trạng thái
`PENDING` và chưa gán tài xế. Không tắt hoặc nới trigger để nạp seed.

## Nâng cấp database cũ

Chỉ với database đã tồn tại từ schema cũ, chạy các migration theo thứ tự:

1. `migrations/001_add_restaurant_name.sql`
2. `migrations/002_order_notifications_and_metrics.sql`
3. `migrations/003_remove_promotion_notification_type.sql`

Sau đó chạy lại `triggers/triggers.sql`, `views/views.sql` và
`security/roles.sql`. Migration 002 liên kết notification ORDER cũ với đơn,
xóa notification không có đơn và đồng bộ counters. Do đơn lịch sử không lưu
thời điểm hoàn tất, migration dùng `order_date` làm mốc ước lượng cho thống kê
ca. Migration 003 xóa notification PROMOTION cũ và giới hạn loại thông báo
thành ORDER hoặc SYSTEM. Database tạo mới đã có các thay đổi này trong schema;
không chạy migration trên database mới.

## Tài khoản và phân quyền cho API

Chạy `security/roles.sql` bằng tài khoản MySQL được phép quản lý role. Script
tạo/cập nhật quyền cho các role ứng dụng và thu hồi quyền cũ trước khi áp dụng
bộ quyền mới. Tạo bốn tài khoản MySQL riêng cho
`role_customer`, `role_restaurant`, `role_driver` và `role_admin`, rồi cấu hình
chúng trong `api/.env`. Host của tài khoản phải khớp với `MYSQL_HOST`. Không
dùng MySQL `root` để chạy API; role `role_admin` chỉ phục vụ dashboard, không
phải tài khoản quản trị database.

## Ghi chú cấu trúc và nghiệp vụ

- `schemasql.sql` tạo và chọn database `food_delivery_db`.
- `indexes/indexes.sql` tạo chín chỉ mục bổ sung; chỉ chạy một lần sau schema.
  Hai chỉ mục `idx_order_item_order` và `idx_notification_order` nằm trực tiếp
  trong schema cùng khóa ngoại tương ứng.
- `performance/benchmarks.sql` có một câu `EXPLAIN ANALYZE` cho mỗi chỉ mục
  trong `indexes/indexes.sql`; có thể chạy toàn bộ file thành một batch sau khi
  cài index và nạp dữ liệu đại diện.
- Loại notification chỉ gồm `ORDER` và `SYSTEM`; giảm giá/khuyến mãi không nằm
  trong phạm vi ứng dụng. Bộ dữ liệu 5.000 chỉ nạp notification ORDER.
- Khi tạo đơn, trigger tăng `customer.total_orders`; điểm loyalty chỉ cộng khi
  đơn chuyển sang `COMPLETED`. Nếu tài xế hoàn tất đơn trong ca đang hoạt động,
  trigger tăng `shift.completed_orders` và `shift.bonus_earned`.
- Bộ seed nhỏ dùng mật khẩu demo `demo123` cho năm tài khoản vì API coursework
  hiện so sánh mật khẩu dạng rõ. Đây chỉ là dữ liệu cục bộ phục vụ môn học;
  ứng dụng thực tế phải hash và xác minh mật khẩu ở tầng ứng dụng.
- API cart lưu trong phiên chạy và mất khi khởi động lại. Giỏ hàng bền vững và
  coupon chưa được triển khai.
- Phần lớn quyền được cấp theo cột. Ứng dụng vẫn phải kiểm tra quyền sở hữu
  dòng dữ liệu của Khách hàng, Nhà hàng và Tài xế.
- View `vw_order_summary` chứa tên khách hàng; chỉ cấp cho người dùng được phép
  xem dữ liệu báo cáo đó.

Trước khi tạo đơn, API đặt `@app_user_id` bằng `user_id` của khách; trigger
kiểm tra quyền tạo đơn và ghi người thực hiện vào audit. Khi đổi trạng thái
hoặc phân công tài xế, API đặt biến này bằng tài khoản nhân viên tương ứng.
`seed/sample_data.sql` là fixture và kịch bản demo đầy đủ, vì vậy phải chạy bằng
tài khoản quản trị DB thay vì tài khoản role giới hạn của API. Biến
`@app_user_id` mô phỏng actor cho trigger/audit, không tự kích hoạt MySQL role.

Các truy vấn trong `queries/` là nhóm truy vấn độc lập. Bộ test negative duy
nhất chỉ chạy với fixture nhỏ sau khi đã cài triggers và dữ liệu mẫu; không
chạy trên bộ dữ liệu 5.000.
