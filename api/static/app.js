// Khởi tạo giao diện, điều phối đăng nhập và mở màn hình theo role.
import { byId, request, showView, state, toast } from "./shared.js";
import { checkout, closeMenu, filterRestaurants, loadCart, loadCustomerHome, loadCustomerOrders, loadRestaurants, resetRestaurantFilters } from "./customer.js";
import { loadRestaurantDashboard, loadRestaurantMenu } from "./restaurant.js";
import { loadDriverOrders, renderDriverStatus, toggleDriverStatus } from "./driver.js";
import { loadAdminHome } from "./admin.js";

async function login(event) {
  event.preventDefault();
  const button = byId("login-form").querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const data = await request("/login", {
      method: "POST",
      body: JSON.stringify({ email: byId("email").value.trim(), password: byId("password").value })
    });
    state.token = data.token;
    state.user = data.user;
    sessionStorage.setItem("foodDeliveryToken", state.token);
    await loadProfileAndHome();
    toast(`Đăng nhập thành công. Xin chào ${state.user.name}!`);
  } catch (error) {
    toast(error.message, true);
  } finally {
    button.disabled = false;
  }
}

async function loadProfileAndHome() {
  const data = await request("/profile");
  state.profile = data.user;
  state.user = { user_id: state.profile.user_id, name: state.profile.name, role: state.profile.role };
  document.querySelectorAll("[data-user-name]").forEach((element) => { element.textContent = state.user.name; });
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
  try {
    await request("/logout", { method: "POST" });
  } catch (error) {
    console.warn("Logout request failed:", error.message);
  }
  state.token = "";
  state.user = null;
  state.profile = null;
  sessionStorage.removeItem("foodDeliveryToken");
  showView("login");
  byId("login-form").reset();
}

byId("login-form").addEventListener("submit", login);
byId("logout-button").addEventListener("click", logout);
byId("refresh-restaurants").addEventListener("click", loadRestaurants);
byId("restaurant-search").addEventListener("input", filterRestaurants);
byId("cuisine-filter").addEventListener("change", filterRestaurants);
byId("open-only-filter").addEventListener("change", filterRestaurants);
byId("reset-restaurant-filters").addEventListener("click", resetRestaurantFilters);
byId("refresh-customer-orders").addEventListener("click", loadCustomerOrders);
byId("checkout-button").addEventListener("click", checkout);
byId("close-modal").addEventListener("click", closeMenu);
byId("menu-modal").addEventListener("click", (event) => {
  if (event.target === byId("menu-modal")) closeMenu();
});
byId("refresh-restaurant").addEventListener("click", loadRestaurantDashboard);
byId("refresh-driver").addEventListener("click", loadDriverOrders);
byId("driver-toggle").addEventListener("click", toggleDriverStatus);
byId("refresh-admin").addEventListener("click", loadAdminHome);

if (state.token) {
  loadProfileAndHome().catch((error) => {
    state.token = "";
    sessionStorage.removeItem("foodDeliveryToken");
    showView("login");
    toast(error.message, true);
  });
}
