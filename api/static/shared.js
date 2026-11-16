// TIỆN ÍCH DÙNG CHUNG
// Các module màn hình cùng dùng API/state/nhãn/định dạng ở đây để không phải
// lặp lại cách gửi token, hiển thị lỗi hoặc chuyển đổi dữ liệu.
export const API = "/api";

// Chuyển role và trạng thái từ database sang nhãn dễ đọc trên giao diện.
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

// Danh sách hình minh họa luân phiên cho thẻ nhà hàng.
export const restaurantEmojis = ["🍜", "🍔", "🍣", "🍛", "🍕", "🥗", "🍲", "🥟"];

// Trạng thái frontend dùng chung. Token được nạp từ tab hiện tại; hồ sơ,
// danh mục và bộ đếm toast được cập nhật trong lúc ứng dụng chạy.
export const state = {
  token: sessionStorage.getItem("foodDeliveryToken") || "",
  user: null,
  profile: null,
  restaurants: [],
  toastTimer: null
};

// Hàm rút gọn để truy cập phần tử HTML theo id.
export const byId = (id) => document.getElementById(id);

// Định dạng tiền theo quy ước Việt Nam; Number() xử lý cả giá trị dạng chuỗi
// mà JSON từ MySQL có thể trả về.
export const money = (value) => `${Number(value || 0).toLocaleString("vi-VN")} ₫`;

export async function request(path, options = {}) {
  // Mọi module gọi API qua hàm này. Tự đặt Content-Type khi có body và đính token
  // cho các route yêu cầu đăng nhập; lỗi mạng từ fetch được truyền về nơi gọi.
  const headers = { ...(options.body ? { "Content-Type": "application/json" } : {}), ...(options.headers || {}) };
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  const response = await fetch(`${API}${path}`, { ...options, headers });
  let data;
  try {
    // API luôn trả JSON, kể cả lỗi. Báo riêng trường hợp server trả nội dung sai định dạng.
    data = await response.json();
  } catch {
    throw new Error("Máy chủ trả về dữ liệu không hợp lệ.");
  }
  // Chuyển mã HTTP lỗi thành Error để màn hình gọi có thể hiện thông báo.
  if (!response.ok) throw new Error(data.error || "Không thể hoàn tất yêu cầu.");
  return data;
}

export function toast(message, error = false) {
  // Một vùng thông báo dùng chung; hủy timer cũ để thông báo mới không bị ẩn sớm.
  const element = byId("toast");
  element.textContent = message;
  element.classList.toggle("error", error);
  element.classList.add("show");
  clearTimeout(state.toastTimer);
  state.toastTimer = setTimeout(() => element.classList.remove("show"), 3000);
}

export function showView(name) {
  // Mỗi role có một section trong index.html. Ẩn tất cả rồi hiện duy nhất màn hình cần dùng.
  ["login", "customer", "restaurant", "driver", "admin"].forEach((view) => {
    byId(`${view}-view`).classList.toggle("hidden", view !== name);
  });
  byId("logout-button").classList.toggle("hidden", name === "login");
  byId("role-badge").classList.toggle("hidden", name === "login");
  byId("header-greeting").classList.toggle("hidden", name !== "login");
  if (name !== "login") byId("role-badge").textContent = roleLabels[state.user.role] || state.user.role;
}

export function statCard(label, value, note, accent = false) {
  // Tạo một thẻ thống kê đồng nhất; label/value/note do module role cung cấp.
  return `<article class="stat-card ${accent ? "accent" : ""}"><span>${label}</span><strong>${value}</strong><small>${note}</small></article>`;
}

export function escapeHtml(value) {
  // Mã hóa ký tự đặc biệt trước khi đưa dữ liệu database vào innerHTML,
  // tránh tên nhà hàng/món có thể được hiểu nhầm thành markup.
  return String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[character]);
}
