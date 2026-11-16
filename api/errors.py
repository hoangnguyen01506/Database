"""Kiểu lỗi có mã HTTP để các route báo lỗi nghiệp vụ rõ ràng."""

class APIError(Exception):
    """Đóng gói trạng thái HTTP và thông điệp hiển thị cho client."""

    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message
