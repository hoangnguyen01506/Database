// MÀN HÌNH TÀI XẾ
// Hiển thị trạng thái trực tuyến, đơn có thể nhận và đơn đang được giao.
import { byId, escapeHtml, request, state, toast } from "./shared.js";
import { refreshNotificationBadge } from "./notifications.js";
import { renderOrders } from "./orders.js";

let shiftRefreshTimer = null;

export async function loadDriverOrders() {
  // Tải hồ sơ, ca gần nhất và danh sách đơn song song.
  try {
    const [profileData, ordersData, shiftData] = await Promise.all([
      request("/profile"),
      request("/orders"),
      request("/driver/shift")
    ]);
    state.profile = profileData.user;
    renderDriverStatus(state.profile.driver_status);
    renderDriverShift(shiftData.shift);
    renderOrders(byId("driver-orders"), ordersData.orders, "driver", loadDriverOrders);
  } catch (error) {
    byId("driver-orders").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
    byId("driver-shift-status").textContent = "Không tải được";
    byId("driver-shift-status").className = "shift-status shift-status-error";
    byId("driver-shift-details").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

function renderDriverShift(shift) {
  clearInterval(shiftRefreshTimer);
  const details = byId("driver-shift-details");
  const status = byId("driver-shift-status");
  if (!shift) {
    status.textContent = "Chưa có ca";
    status.className = "shift-status";
    details.innerHTML = '<div class="empty-state">Chưa có ca làm việc. Bật trực tuyến để bắt đầu ca.</div>';
    return;
  }

  const active = !shift.end_time;
  const startTime = new Date(shift.start_time);
  const endTime = shift.end_time ? new Date(shift.end_time) : null;
  status.textContent = active ? "ĐANG MỞ" : "ĐÃ KẾT THÚC";
  status.className = `shift-status ${active ? "shift-status-active" : "shift-status-closed"}`;
  details.innerHTML = `
    <article class="shift-detail">
      <span class="shift-detail-label">Bắt đầu ca</span>
      <strong>${formatShiftDate(startTime)}</strong>
    </article>
    <article class="shift-detail">
      <span class="shift-detail-label">Kết thúc ca</span>
      <strong>${endTime ? formatShiftDate(endTime) : "Đang trong ca"}</strong>
    </article>
    <article class="shift-detail">
      <span class="shift-detail-label">Thời gian làm</span>
      <strong id="driver-shift-duration">--</strong>
    </article>`;

  const updateDuration = () => {
    byId("driver-shift-duration").textContent =
      formatDuration(Math.max(0, (active ? Date.now() : endTime.getTime()) - startTime.getTime()));
  };
  updateDuration();
  if (active) shiftRefreshTimer = setInterval(updateDuration, 60000);
}

function formatShiftDate(value) {
  if (Number.isNaN(value.getTime())) return "Không xác định";
  return value.toLocaleString("vi-VN", { dateStyle: "medium", timeStyle: "short" });
}

function formatDuration(milliseconds) {
  const totalMinutes = Math.floor(milliseconds / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return `${hours} giờ ${minutes} phút`;
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
    void refreshNotificationBadge();
    state.profile.driver_status = status;
    renderDriverStatus(status);
    await loadDriverOrders();
    toast(status === "ONLINE" ? "Bạn đã bật trạng thái trực tuyến." : "Bạn đã tạm nghỉ.");
  } catch (error) {
    toast(error.message, true);
  }
}
