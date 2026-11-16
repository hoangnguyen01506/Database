// MÀN HÌNH TÀI XẾ
// Hiển thị trạng thái trực tuyến, đơn có thể nhận và đơn đang được giao.
import { byId, escapeHtml, request, state, toast } from "./shared.js";
import { renderOrders } from "./orders.js";

export async function loadDriverOrders() {
  // Lấy hồ sơ (driver_id/status) và danh sách đơn song song. Dùng hồ sơ để
  // phân biệt đơn của tài xế hiện tại với đơn chưa có người nhận.
  try {
    const [profileData, data] = await Promise.all([request("/profile"), request("/orders")]);
    state.profile = profileData.user;
    renderDriverStatus(state.profile.driver_status);
    renderOrders(byId("driver-orders"), data.orders, "driver", loadDriverOrders);
  } catch (error) {
    byId("driver-orders").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

export function renderDriverStatus(status) {
  // Ánh xạ trạng thái database sang nhãn, màu và trạng thái nút điều khiển.
  // Khi BUSY, không cho tự chuyển OFFLINE trong lúc còn giao đơn.
  const label = status === "ONLINE" ? "ĐANG TRỰC TUYẾN" : status === "BUSY" ? "ĐANG GIAO ĐƠN" : "ĐANG NGOẠI TUYẾN";
  byId("driver-status").textContent = label;
  byId("driver-status").className = `driver-status ${status || "OFFLINE"}`;
  byId("driver-status-title").textContent = status === "BUSY"
    ? "Bạn đang có đơn giao"
    : status === "ONLINE" ? "Bạn đang sẵn sàng" : "Sẵn sàng nhận đơn?";
  const button = byId("driver-toggle");
  button.textContent = status === "ONLINE" ? "Tạm nghỉ" : status === "BUSY" ? "Đang giao hàng" : "Bật trực tuyến";
  button.disabled = status === "BUSY";
}

export async function toggleDriverStatus() {
  // Đổi ONLINE/OFFLINE qua API; server kiểm tra đơn đang hoạt động trước khi lưu.
  // Sau cập nhật, tải lại hồ sơ và danh sách để tránh giao diện dùng trạng thái cũ.
  const status = state.profile.driver_status === "ONLINE" ? "OFFLINE" : "ONLINE";
  try {
    await request("/driver/status", { method: "POST", body: JSON.stringify({ status }) });
    state.profile.driver_status = status;
    renderDriverStatus(status);
    await loadDriverOrders();
    toast(status === "ONLINE" ? "Bạn đã bật trạng thái trực tuyến." : "Bạn đã tạm nghỉ.");
  } catch (error) {
    toast(error.message, true);
  }
}
