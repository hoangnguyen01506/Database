// HIỂN THỊ VÀ THAO TÁC ĐƠN HÀNG DÙNG CHUNG
// Khách, Nhà hàng, Tài xế và Admin dùng chung thẻ đơn; tham số mode quyết định
// nút nào được hiện. Backend vẫn là nơi kiểm tra quyền và tính hợp lệ cuối cùng.
import { byId, escapeHtml, money, request, state, statusLabels, toast } from "./shared.js";

export function renderOrders(container, orders, mode, onUpdated) {
  // Trạng thái rỗng được xử lý tại đây để mọi màn hình có cùng cách hiển thị.
  if (!orders || !orders.length) {
    container.innerHTML = '<div class="empty-state">Chưa có đơn hàng để hiển thị.</div>';
    return;
  }
  container.innerHTML = orders.map((order) => {
    const status = order.status;
    const actions = [];
    // Nhà hàng chỉ được xác nhận và cập nhật khâu chuẩn bị.
    if (mode === "restaurant") {
      if (status === "PENDING") actions.push(orderActionButton(order.order_id, "confirm", "Xác nhận"));
      if (status === "CONFIRMED") actions.push(orderActionButton(order.order_id, "prepare", "Bắt đầu chuẩn bị"));
      if (status === "PREPARING") actions.push(orderActionButton(order.order_id, "ready", "Đã chuẩn bị xong"));
    }
    // Tài xế chỉ nhận đơn chưa gán ở trạng thái phù hợp; nút hoàn tất chỉ hiện
    // với đơn đang thuộc tài xế hiện đăng nhập.
    if (mode === "driver") {
      if (!order.driver_id && ["PREPARING", "READY"].includes(status)) actions.push(orderActionButton(order.order_id, "accept", "Nhận đơn"));
      if (Number(order.driver_id) === Number(state.profile.driver_id) && ["PREPARING", "READY", "PICKED_UP", "DELIVERING"].includes(status)) {
        actions.push(orderActionButton(order.order_id, "complete", "Hoàn tất giao"));
      }
    }
    // Thông tin chung của một thẻ đơn; các giá trị tiền và trạng thái được định dạng.
    const details = [
      `Nhà hàng #${order.restaurant_id}`,
      new Date(order.order_date).toLocaleString("vi-VN", { dateStyle: "medium", timeStyle: "short" }),
      `Tổng ${money(order.total_amount)}`
    ];
    if (mode === "driver" && order.driver_id) {
      details.push(Number(order.driver_id) === Number(state.profile.driver_id) ? "Đơn của bạn" : "Đã có tài xế");
    }
    return `<article class="order-card"><div class="order-main">
      <div class="order-head"><h3>Đơn hàng #${order.order_id}</h3><span class="status-pill status-${status}">${statusLabels[status] || escapeHtml(status)}</span></div>
      <div class="order-info">${details.map((item) => `<span>${escapeHtml(item)}</span>`).join("")}</div>
    </div>${actions.length ? `<div class="order-actions">${actions.join("")}</div>` : ""}</article>`;
  }).join("");
  container.querySelectorAll("[data-action]").forEach((button) => {
    // data-* nối đúng nút với order ID và action mà API định tuyến.
    button.addEventListener("click", () => runOrderAction(
      Number(button.dataset.orderId),
      button.dataset.action,
      onUpdated
    ));
  });
}

function orderActionButton(orderId, action, label) {
  // Tạo nút có metadata; runOrderAction đọc lại từ dataset khi người dùng bấm.
  return `<button class="button ${action === "accept" ? "button-primary" : "button-outline"}" type="button" data-order-id="${orderId}" data-action="${action}">${label}</button>`;
}

async function runOrderAction(orderId, action, onUpdated) {
  // Gửi thao tác đến route API tương ứng, thông báo kết quả rồi tải lại dữ liệu.
  // API/trigger sẽ từ chối nếu role hoặc trạng thái đơn không cho phép.
  try {
    const data = await request(`/orders/${orderId}/${action}`, { method: "POST", body: "{}" });
    const order = data.order;
    const finalStatus = order && order.status ? ` Trạng thái: ${statusLabels[order.status] || order.status}.` : "";
    toast(`${data.message || "Đã cập nhật đơn hàng."}${finalStatus}`);
    await onUpdated();
  } catch (error) {
    toast(error.message, true);
  }
}
