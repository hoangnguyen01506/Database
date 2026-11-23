// MÀN HÌNH NHÀ HÀNG
// Hiển thị các đơn thuộc nhà hàng đăng nhập, các nút chuyển trạng thái và menu.
import { byId, escapeHtml, money, request, state, statCard } from "./shared.js";
import { renderOrders } from "./orders.js";

export async function loadRestaurantDashboard() {
  await Promise.all([loadRestaurantStats(), loadRestaurantOrders()]);
}

async function loadRestaurantStats() {
  try {
    const data = await request("/restaurant/stats");
    const counts = data.statistics;
    byId("restaurant-stats").innerHTML = [
      statCard("Đơn chờ xác nhận", counts.pending, "Cần xử lý", true),
      statCard("Đang chuẩn bị", counts.preparation, "Đơn trong bếp"),
      statCard("Sẵn sàng giao", counts.ready, "Chờ tài xế"),
      statCard("Doanh thu hoàn tất", money(counts.revenue), "Từ các đơn hoàn tất")
    ].join("");
  } catch (error) {
    byId("restaurant-stats").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

async function loadRestaurantOrders() {
  // Danh sách gần đây vẫn được giới hạn; các chỉ số trên được tổng hợp riêng trong SQL.
  try {
    const data = await request("/orders");
    const orders = data.orders;
    renderOrders(byId("restaurant-orders"), orders, "restaurant", loadRestaurantDashboard);
  } catch (error) {
    byId("restaurant-orders").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

export async function loadRestaurantMenu() {
  // restaurant_id lấy từ hồ sơ API, không lấy từ dữ liệu do người dùng tự nhập.
  if (!state.profile.restaurant_id) {
    byId("restaurant-menu").innerHTML = '<div class="empty-state">Tài khoản chưa liên kết hồ sơ nhà hàng.</div>';
    return;
  }
  try {
    // Menu gồm cả món tạm hết để nhà hàng biết trạng thái bán của từng món.
    const data = await request(`/restaurants/${state.profile.restaurant_id}/menu`);
    if (!data.menu.length) {
      byId("restaurant-menu").innerHTML = '<div class="empty-state">Chưa có món trong thực đơn.</div>';
      return;
    }
    byId("restaurant-menu").innerHTML = data.menu.map((item) => `<article class="menu-card">
      <small>${escapeHtml(item.category || "Món ăn")} · #${item.menu_item_id}</small>
      <h3>${escapeHtml(item.name)}</h3>
      <p class="muted">${escapeHtml(item.description || "Món ngon của nhà hàng")}</p>
      <div class="menu-price">${money(item.price)} ${item.is_available ? "" : '<span class="unavailable">Tạm hết</span>'}</div>
    </article>`).join("");
  } catch (error) {
    byId("restaurant-menu").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}
