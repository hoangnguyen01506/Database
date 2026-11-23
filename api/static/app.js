// ĐIỀU PHỐI ỨNG DỤNG
// Đây là điểm vào của frontend: gắn sự kiện giao diện, đăng nhập/đăng xuất,
// sau đó chọn module màn hình dựa trên role do API trả về.
import { byId, request, showView, state, toast } from "./shared.js";
import { checkout, closeMenu, filterRestaurants, loadCart, loadCustomerHome, loadCustomerOrders, loadRestaurants, resetRestaurantFilters, showCustomerTab } from "./customer.js";
import { loadRestaurantDashboard, loadRestaurantMenu } from "./restaurant.js";
import { loadDriverOrders, renderDriverStatus, toggleDriverStatus } from "./driver.js";
import { loadAdminHome } from "./admin.js";
import { closeNotifications, openNotifications, refreshNotificationBadge } from "./notifications.js";

async function login(event) {
  // Ngăn form tải lại trang; trong lúc gọi API khóa nút để tránh gửi đăng nhập lặp.
  event.preventDefault();
  const button = byId("login-form").querySelector("button[type=submit]");
  button.disabled = true;
  try {
    // Gửi thông tin đăng nhập dạng JSON. API xác thực với MySQL và trả token cùng user.
    const data = await request("/login", {
      method: "POST",
      body: JSON.stringify({ email: byId("email").value.trim(), password: byId("password").value })
    });
    // Lưu token trong sessionStorage để các request tiếp theo gửi Bearer token.
    // sessionStorage chỉ giữ trong tab hiện tại, không phải nơi lưu thông tin lâu dài.
    state.token = data.token;
    state.user = data.user;
    sessionStorage.setItem("foodDeliveryToken", state.token);
    // Tải hồ sơ role-specific và mở đúng trang làm việc.
    await loadProfileAndHome();
    toast(`Đăng nhập thành công. Xin chào ${state.user.name}!`);
  } catch (error) {
    // Hiển thị lỗi API/kết nối cho người dùng; finally luôn mở lại nút đăng nhập.
    toast(error.message, true);
  } finally {
    button.disabled = false;
  }
}

async function loadProfileAndHome() {
  // Token được request() tự thêm vào header; hồ sơ trả về có thể chứa restaurant_id
  // hoặc driver_status cần cho các màn hình tương ứng.
  const data = await request("/profile");
  state.profile = data.user;
  state.user = { user_id: state.profile.user_id, name: state.profile.name, role: state.profile.role };
  document.querySelectorAll("[data-user-name]").forEach((element) => { element.textContent = state.user.name; });
  if (["Customer", "Restaurant", "Driver"].includes(state.user.role)) {
    void refreshNotificationBadge();
  }

  // Chỉ tải dữ liệu của vai trò hiện đăng nhập để tránh gọi các API không được phép.
  if (state.user.role === "Customer") {
    byId("customer-title").textContent = `Hôm nay mình ăn gì, ${state.user.name.split(" ")[0]}?`;
    showView("customer");
    await loadCustomerHome();
  } else if (state.user.role === "Restaurant") {
    showView("restaurant");
    await Promise.all([loadRestaurantDashboard(), loadRestaurantMenu()]);
  } else if (state.user.role === "Driver") {
    showView("driver");
    renderDriverStatus(state.profile.driver_status);
    await loadDriverOrders();
  } else if (state.user.role === "Admin") {
    showView("admin");
    await loadAdminHome();
  } else {
    throw new Error("Vai trò tài khoản chưa được hỗ trợ.");
  }
}

async function logout() {
  // Thử xóa phiên phía server; dù request lỗi vẫn xóa token phía trình duyệt,
  // tránh người dùng bị kẹt ở trạng thái đã đăng nhập.
  try {
    await request("/logout", { method: "POST" });
  } catch (error) {
    console.warn("Logout request failed:", error.message);
  }
  state.token = "";
  state.user = null;
  state.profile = null;
  sessionStorage.removeItem("foodDeliveryToken");
  closeNotifications();
  showView("login");
  byId("login-form").reset();
}

// Nối phần tử HTML với hàm xử lý. Các module riêng giữ nghiệp vụ của từng màn hình,
// còn file này chỉ làm nhiệm vụ điều phối sự kiện toàn ứng dụng.
byId("login-form").addEventListener("submit", login);
byId("logout-button").addEventListener("click", logout);
byId("notifications-button").addEventListener("click", openNotifications);
byId("close-notifications").addEventListener("click", closeNotifications);
document.addEventListener("click", (event) => {
  const panel = byId("notifications-modal");
  const button = byId("notifications-button");
  if (
    panel.classList.contains("show") &&
    !panel.contains(event.target) &&
    !button.contains(event.target)
  ) {
    closeNotifications();
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeNotifications();
});
byId("refresh-restaurants").addEventListener("click", loadRestaurants);
byId("restaurant-search").addEventListener("input", filterRestaurants);
byId("cuisine-filter").addEventListener("change", filterRestaurants);
byId("open-only-filter").addEventListener("change", filterRestaurants);
byId("reset-restaurant-filters").addEventListener("click", resetRestaurantFilters);
byId("refresh-customer-orders").addEventListener("click", loadCustomerOrders);
document.querySelectorAll("[data-customer-tab]").forEach((button) => {
  button.addEventListener("click", () => showCustomerTab(button.dataset.customerTab, button.dataset.scrollTo));
});
byId("checkout-button").addEventListener("click", () => checkout("CASH"));
byId("virtual-payment-button").addEventListener("click", () => checkout("MOMO"));
byId("close-modal").addEventListener("click", closeMenu);
byId("menu-modal").addEventListener("click", (event) => {
  if (event.target === byId("menu-modal")) closeMenu();
});
byId("refresh-restaurant").addEventListener("click", loadRestaurantDashboard);
byId("refresh-driver").addEventListener("click", loadDriverOrders);
byId("driver-toggle").addEventListener("click", toggleDriverStatus);
byId("refresh-admin").addEventListener("click", loadAdminHome);

if (state.token) {
  // Nếu tab còn token từ lần dùng trước, khôi phục hồ sơ và màn hình.
  // Phiên server lưu trong bộ nhớ nên nếu API đã khởi động lại, xóa token cũ
  // và yêu cầu người dùng đăng nhập lại.
  loadProfileAndHome().catch((error) => {
    state.token = "";
    sessionStorage.removeItem("foodDeliveryToken");
    showView("login");
    toast(error.message, true);
  });
}
