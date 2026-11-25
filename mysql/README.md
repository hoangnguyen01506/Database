# Các tệp MySQL

Các script được viết cho MySQL 8.0.16 trở lên. Benchmark dùng `EXPLAIN ANALYZE`
nên yêu cầu MySQL 8.0.18 trở lên.

Dùng `food_delivery_complete_5000_mysql.sql` để nạp đúng 5.000 user cùng dữ liệu
đơn hàng và các trường hợp kiểm thử:

1. `schemasql.sql`
2. `food_delivery_complete_5000_mysql.sql`
3. `indexes/indexes.sql`
4. `triggers/triggers.sql`
5. `views/views.sql`
6. `security/roles.sql`

Full seed phải chạy ngay sau schema và **trước khi cài triggers**, vì seed nạp
đơn hàng và audit lịch sử. Không nạp cả hai bộ seed vào cùng database. Nếu seed lỗi,
không chạy lại trên database đã nạp dở hoặc có dữ liệu; rollback giao dịch lỗi
và bắt đầu trên database rỗng.
File full seed không thêm các batch tài khoản mở rộng; các trường hợp khách
không có đơn, tài xế rảnh và nhà hàng chưa duyệt được lấy từ 5.000 user hiện có.
Seed chuyển 51 customer không có đơn thành chủ nhà hàng để bổ sung ba nhà hàng
mỗi hub mà không tăng tổng số user.
`seed/sample_data.sql` là tùy chọn riêng và sẽ thêm ba user demo.

Sau khi đã nạp bộ dữ liệu 5.000 và cài indexes, triggers, views, có thể chạy
`seed/sample_data.sql` **một lần** bằng tài khoản DBA để thêm tài khoản, nhà
hàng, đơn hàng, thanh toán, đánh giá và thông báo mẫu. File dùng số điện thoại,
email và mã giao dịch cố định; không chạy lại trên cùng database vì sẽ trùng
dữ liệu. Sau khi COMMIT, file hiển thị các bản ghi demo vừa thêm và chạy ba
view `vw_order_summary`, `vw_restaurant_sales`, `vw_driver_performance` đã lọc
theo đơn, nhà hàng và tài xế mẫu.

Các cập nhật trong full seed tương thích MySQL Workbench Safe Update Mode. Nếu
gặp lỗi 1644, có thể trigger `trg_order_before_insert` đã được cài trước khi
nạp seed; trigger đang bảo vệ quy tắc đơn mới phải bắt đầu ở trạng thái
`PENDING` và chưa gán tài xế. Không tắt hoặc nới trigger để nạp seed.

Khi cài mới, `triggers/triggers.sql` tạo trigger ghi notification mỗi khi trạng
thái tài xế đổi. Nếu database đã cài triggers trước đó, chạy
`migrations/004_driver_status_notifications.sql` bằng tài khoản quản trị DB.
Sau khi cập nhật quyền cho thanh toán, đánh giá và ca tài xế, chạy lại
`security/roles.sql`.
Role `role_restaurant` cũng cần quyền đọc ánh xạ khách hàng và ghi notification
để API gửi cập nhật trạng thái đơn đến khách.


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
- `indexes/indexes.sql` tạo chín chỉ mục bổ sung. Hai chỉ mục
  `idx_order_item_order` và `idx_notification_order` nằm trực tiếp trong schema
  cùng khóa ngoại tương ứng.
- Để so sánh hiệu năng của chín chỉ mục bổ sung, giữ nguyên dữ liệu và chạy trong
  MySQL Workbench:
  1. Chạy `performance/benchmarks_without_indexes.sql`; các truy vấn dùng
     `IGNORE INDEX` để bỏ qua index tương ứng mà không xóa index hay ảnh hưởng
     khóa ngoại.
  2. Chạy toàn bộ `performance/benchmarks.sql` để đo khi optimizer được phép
     dùng index.
  3. So sánh `actual time` của cùng truy vấn P-01 đến P-09. Dùng cùng dữ liệu và
     điều kiện lọc; thời gian có thể dao động do cache và tải máy.
     `EXPLAIN ANALYZE` yêu cầu MySQL 8.0.18 trở lên.
- Các giá trị lọc trong hai file benchmark nhắm đến những bản ghi khớp gần cuối
  bộ seed 5.000. ID lớn tự nó không làm truy vấn chậm hơn; thời gian phụ thuộc
  kích thước bảng, số dòng khớp và kế hoạch thực thi. Với bộ dữ liệu 5.000 dòng,
  Workbench có thể làm tròn thời gian tổng thành `0.00s`; hãy so sánh `actual
  time` chi tiết trong kết quả `EXPLAIN ANALYZE`.
- Không xóa các index này để benchmark: MySQL có thể đang dùng chúng để hỗ trợ
  khóa ngoại. Nếu đã thử xóa, kiểm tra và khôi phục mọi index bị xóa trước khi
  chạy hai file benchmark.
- Loại notification chỉ gồm `ORDER` và `SYSTEM`; giảm giá/khuyến mãi không nằm
  trong phạm vi ứng dụng. Bộ dữ liệu 5.000 chỉ nạp notification ORDER.
- `seed/sample_data.sql` chạy một lần sau bộ seed 5.000 và cài đặt indexes,
  triggers, views; các câu `INSERT` và `UPDATE` được sắp theo thứ tự nghiệp vụ,
  chỉ dùng `@app_user_id` (bắt buộc cho trigger audit/phân quyền actor) và
  `@demo_order_id` (giữ ID đơn mới để cập nhật từng trạng thái). Thanh toán
  thất bại/thành công được ghi trước khi nhà hàng xử lý đơn; notification khách
  được thêm sau từng bước nhà hàng cập nhật trạng thái, giống luồng API. Seed
  cũng ghi notification cho tài xế, khách và nhà hàng khi tài xế chuyển BUSY
  lúc nhận đơn và ONLINE sau khi giao xong. Trigger cập nhật số đơn và tiền
  thưởng của ca khi đơn hoàn tất.
- Khi tạo đơn, trigger tăng `customer.total_orders`; điểm loyalty chỉ cộng khi
  đơn chuyển sang `COMPLETED`. Nếu tài xế hoàn tất đơn trong ca đang hoạt động,
  trigger tăng `shift.completed_orders` và `shift.bonus_earned`.
- `seed/sample_data.sql` dùng mật khẩu demo `demo123` cho ba tài khoản mẫu vì
  API coursework hiện so sánh mật khẩu dạng rõ. Đây chỉ là dữ liệu cục bộ phục
  vụ môn học; ứng dụng thực tế phải hash và xác minh mật khẩu ở tầng ứng dụng.
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

Các truy vấn trong `queries/` là nhóm truy vấn độc lập. Với bộ seed 5.000, chạy
từng câu INSERT/UPDATE trong `tests/negative_test_execution.sql` riêng lẻ bằng
tài khoản DBA trong MySQL Workbench. Một số câu chuẩn bị sẽ thành công; câu test
chính phải bị từ chối. Sau khi kiểm tra xong, chạy `ROLLBACK` để hủy mọi thay đổi.
