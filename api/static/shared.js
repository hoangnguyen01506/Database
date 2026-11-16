// Chứa trạng thái giao diện, nhãn dùng chung, gọi API và tiện ích hiển thị.
export const API = "/api";
export const roleLabels = {
  Customer: "Khách hàng",
  Restaurant: "Nhà hàng",
  Driver: "Tài xế",
  Admin: "Quản trị viên"
};
export const statusLabels = {
  PENDING: "Chờ xác nhận",
  CONFIRMED: "Đã xác nhận",
  PREPARING: "Đang chuẩn bị",
  READY: "Sẵn sàng giao",
  PICKED_UP: "Đã lấy món",
  DELIVERING: "Đang giao",
  COMPLETED: "Hoàn tất",
  CANCELLED: "Đã hủy"
};
export const restaurantEmojis = ["🍜", "🍔", "🍣", "🍛", "🍕", "🥗", "🍲", "🥟"];
export const state = {
  token: sessionStorage.getItem("foodDeliveryToken") || "",
  user: null,
  profile: null,
  restaurants: [],
  toastTimer: null
};

export const byId = (id) => document.getElementById(id);
export const money = (value) => `${Number(value || 0).toLocaleString("vi-VN")} ₫`;

export async function request(path, options = {}) {
  const headers = { ...(options.body ? { "Content-Type": "application/json" } : {}), ...(options.headers || {}) };
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  const response = await fetch(`${API}${path}`, { ...options, headers });
  let data;
  try {
    data = await response.json();
  } catch {
    throw new Error("Máy chủ trả về dữ liệu không hợp lệ.");
  }
  if (!response.ok) throw new Error(data.error || "Không thể hoàn tất yêu cầu.");
  return data;
}

export function toast(message, error = false) {
  const element = byId("toast");
  element.textContent = message;
  element.classList.toggle("error", error);
  element.classList.add("show");
  clearTimeout(state.toastTimer);
  state.toastTimer = setTimeout(() => element.classList.remove("show"), 3000);
}

export function showView(name) {
  ["login", "customer", "restaurant", "driver", "admin"].forEach((view) => {
    byId(`${view}-view`).classList.toggle("hidden", view !== name);
  });
  byId("logout-button").classList.toggle("hidden", name === "login");
  byId("role-badge").classList.toggle("hidden", name === "login");
  byId("header-greeting").classList.toggle("hidden", name !== "login");
  if (name !== "login") byId("role-badge").textContent = roleLabels[state.user.role] || state.user.role;
}

export function statCard(label, value, note, accent = false) {
  return `<article class="stat-card ${accent ? "accent" : ""}"><span>${label}</span><strong>${value}</strong><small>${note}</small></article>`;
}

export function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[character]);
}
