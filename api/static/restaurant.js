// Giao diện nhà hàng: bảng đơn cần xử lý, doanh thu và thực đơn.
import { byId, escapeHtml, money, request, state, statCard } from "./shared.js";
import { renderOrders } from "./orders.js";

export async function loadRestaurantDashboard() {
  try {
    const data = await request("/orders");
    const orders = data.orders;
    const counts = {
      pending: orders.filter((order) => order.status === "PENDING").length,
      preparation: orders.filter((order) => ["CONFIRMED", "PREPARING"].includes(order.status)).length,
      ready: orders.filter((order) => order.status === "READY").length,
      revenue: orders.filter((order) => order.status === "COMPLETED")
        .reduce((sum, order) => sum + Number(order.total_amount) - Number(order.delivery_fee || 0), 0)
    };
    byId("restaurant-stats").innerHTML = [
      statCard("Đơn chờ xác nhận", counts.pending, "Cần xử lý", true),
      statCard("Đang chuẩn bị", counts.preparation, "Đơn trong bếp"),
      statCard("Sẵn sàng giao", counts.ready, "Chờ tài xế"),
      statCard("Doanh thu hoàn tất", money(counts.revenue), "Từ các đơn hoàn tất")
    ].join("");
    renderOrders(byId("restaurant-orders"), orders, "restaurant", loadRestaurantDashboard);
  } catch (error) {
    byId("restaurant-orders").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

export async function loadRestaurantMenu() {
  if (!state.profile.restaurant_id) {
    byId("restaurant-menu").innerHTML = '<div class="empty-state">Tài khoản chưa liên kết hồ sơ nhà hàng.</div>';
    return;
  }
  try {
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
