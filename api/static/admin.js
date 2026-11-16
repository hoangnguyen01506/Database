// Tải số liệu tổng quan và danh sách đơn cho bảng điều khiển Admin.
import { byId, escapeHtml, money, request, statCard } from "./shared.js";
import { renderOrders } from "./orders.js";

export async function loadAdminHome() {
  await Promise.all([loadAdminStats(), loadAdminOrders()]);
}

async function loadAdminStats() {
  try {
    const data = await request("/admin/stats");
    const stats = data.statistics;
    byId("admin-stats").innerHTML = [
      statCard("Tổng số đơn", Number(stats.total_orders || 0).toLocaleString("vi-VN"), "Tất cả trạng thái", true),
      statCard("Đơn hoàn tất", Number(stats.completed_orders || 0).toLocaleString("vi-VN"), "Giao thành công"),
      statCard("GMV hoàn tất", money(stats.completed_gmv), "Tổng giá trị đơn hoàn tất"),
      statCard("Doanh thu món ăn", money(stats.food_revenue), "Không gồm phí giao hàng")
    ].join("");
  } catch (error) {
    byId("admin-stats").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

async function loadAdminOrders() {
  try {
    const data = await request("/orders");
    renderOrders(byId("admin-orders"), data.orders, "admin", async () => {});
  } catch (error) {
    byId("admin-orders").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}
