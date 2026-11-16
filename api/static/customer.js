// Giao diện khách: lọc nhà hàng, xem món, quản lý giỏ và đặt/theo dõi đơn.
import { byId, escapeHtml, money, request, restaurantEmojis, state, toast } from "./shared.js";
import { renderOrders } from "./orders.js";

export async function loadCustomerHome() {
  await loadRestaurants();
  await Promise.all([loadCart(), loadCustomerOrders()]);
}

export async function loadRestaurants() {
  try {
    const data = await request("/restaurants");
    state.restaurants = data.restaurants;
    renderRestaurants();
  } catch (error) {
    byId("restaurant-listing").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

export function filterRestaurants() {
  renderRestaurants();
}

export function resetRestaurantFilters() {
  byId("restaurant-search").value = "";
  byId("cuisine-filter").value = "";
  byId("open-only-filter").checked = false;
  renderRestaurants();
}

function normalizeSearch(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .toLocaleLowerCase("vi-VN");
}

function renderRestaurants() {
  const listing = byId("restaurant-listing");
  const cuisineFilter = byId("cuisine-filter");
  const selectedCuisine = cuisineFilter.value;
  const cuisines = [...new Set(state.restaurants.map((item) => item.cuisine_type).filter(Boolean))]
    .sort((left, right) => left.localeCompare(right, "vi"));
  cuisineFilter.innerHTML = '<option value="">Tất cả loại ẩm thực</option>' +
    cuisines.map((cuisine) => `<option value="${escapeHtml(cuisine)}">${escapeHtml(cuisine)}</option>`).join("");
  if (cuisines.includes(selectedCuisine)) cuisineFilter.value = selectedCuisine;

  if (!state.restaurants.length) {
    listing.innerHTML = '<div class="empty-state">Chưa có nhà hàng được duyệt trong cơ sở dữ liệu.</div>';
    byId("restaurant-results").textContent = "0 nhà hàng";
    return;
  }

  const search = normalizeSearch(byId("restaurant-search").value.trim());
  const cuisine = cuisineFilter.value;
  const openOnly = byId("open-only-filter").checked;
  const restaurants = state.restaurants.filter((restaurant) => {
    const matchesSearch = !search ||
      normalizeSearch(`${restaurant.restaurant_name} ${restaurant.cuisine_type || ""}`).includes(search);
    return matchesSearch &&
      (!cuisine || restaurant.cuisine_type === cuisine) &&
      (!openOnly || Boolean(restaurant.is_open));
  });
  byId("restaurant-results").textContent = `Hiển thị ${restaurants.length}/${state.restaurants.length} nhà hàng`;
  if (!restaurants.length) {
    listing.innerHTML = '<div class="empty-state">Không tìm thấy nhà hàng phù hợp. Hãy thử đổi từ khóa hoặc xóa bớt bộ lọc.</div>';
    return;
  }

  listing.innerHTML = restaurants.map((restaurant, index) => {
    const canOrder = Boolean(restaurant.is_open) && Boolean(restaurant.is_approved);
    return `<article class="restaurant-card">
      <div class="restaurant-art tone-${index % 5}">
        <span>${restaurantEmojis[index % restaurantEmojis.length]}</span>
        <span class="open-tag ${canOrder ? "" : "closed"}">${canOrder ? "● ĐANG MỞ" : "TẠM ĐÓNG"}</span>
      </div>
      <div class="restaurant-details">
        <h3>${escapeHtml(restaurant.restaurant_name)}</h3>
        <p>${escapeHtml(restaurant.cuisine_type || "Ẩm thực đa dạng")} · Đơn tối thiểu ${money(restaurant.min_order_amount)}</p>
        <div class="restaurant-meta"><span>${canOrder ? "Giao món mỗi ngày" : "Chưa nhận đơn lúc này"}</span>
          <button class="button ${canOrder ? "button-primary" : "button-outline"}" type="button" ${canOrder ? "" : "disabled"} data-restaurant-id="${restaurant.restaurant_id}">Xem thực đơn</button>
        </div>
      </div>
    </article>`;
  }).join("");
  listing.querySelectorAll("[data-restaurant-id]").forEach((button) => {
    button.addEventListener("click", () => openMenu(Number(button.dataset.restaurantId)));
  });
}

async function openMenu(restaurantId) {
  const restaurant = state.restaurants.find((item) => Number(item.restaurant_id) === restaurantId);
  if (!restaurant) return;
  byId("modal-title").textContent = restaurant.restaurant_name;
  byId("modal-menu").innerHTML = '<div class="empty-state">Đang tải thực đơn...</div>';
  byId("menu-modal").classList.add("show");
  byId("menu-modal").setAttribute("aria-hidden", "false");
  try {
    const data = await request(`/restaurants/${restaurantId}/menu`);
    const available = data.menu.filter((item) => Boolean(item.is_available));
    if (!available.length) {
      byId("modal-menu").innerHTML = '<div class="empty-state">Nhà hàng hiện chưa có món sẵn sàng.</div>';
      return;
    }
    byId("modal-menu").innerHTML = available.map((item) => `<article class="modal-item">
      <div><h3>${escapeHtml(item.name)}</h3><p>${escapeHtml(item.description || item.category || "Món ngon mỗi ngày")}</p><div class="menu-price">${money(item.price)}</div></div>
      <button class="button button-primary" type="button" data-item-id="${item.menu_item_id}">+ Thêm</button>
    </article>`).join("");
    byId("modal-menu").querySelectorAll("[data-item-id]").forEach((button) => {
      button.addEventListener("click", () => addToCart(Number(button.dataset.itemId)));
    });
  } catch (error) {
    byId("modal-menu").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}

export function closeMenu() {
  byId("menu-modal").classList.remove("show");
  byId("menu-modal").setAttribute("aria-hidden", "true");
}

async function addToCart(menuItemId) {
  try {
    await request("/cart/items", { method: "POST", body: JSON.stringify({ menu_item_id: menuItemId, quantity: 1 }) });
    closeMenu();
    await loadCart();
    toast("Đã thêm món vào giỏ hàng.");
  } catch (error) {
    toast(error.message, true);
  }
}

export async function loadCart() {
  try {
    const data = await request("/cart");
    const content = byId("cart-content");
    const items = data.items || [];
    if (!items.length) {
      content.innerHTML = '<div class="cart-empty">Giỏ hàng đang trống.<br>Chọn một món bạn yêu thích nhé!</div>';
      byId("cart-subtitle").textContent = "Món ngon bạn đã chọn";
    } else {
      const restaurant = state.restaurants.find((item) => Number(item.restaurant_id) === Number(data.restaurant_id));
      byId("cart-subtitle").textContent = restaurant ? restaurant.restaurant_name : "Món ngon bạn đã chọn";
      content.innerHTML = items.map((item) => `<div class="cart-row"><div><strong>${escapeHtml(item.name)}</strong><small>${item.quantity} × ${money(item.price)}</small></div><b>${money(item.line_total)}</b></div>`).join("");
    }
    byId("cart-item-count").textContent = String(items.reduce((sum, item) => sum + Number(item.quantity), 0));
    byId("cart-total").textContent = money(items.reduce((sum, item) => sum + Number(item.line_total), 0));
    byId("checkout-button").disabled = items.length === 0;
  } catch (error) {
    byId("cart-content").innerHTML = `<div class="cart-empty">${escapeHtml(error.message)}</div>`;
  }
}

export async function checkout() {
  try {
    const data = await request("/orders", { method: "POST", body: "{}" });
    closeMenu();
    toast(`Đặt hàng thành công! Mã đơn #${data.order.order_id}.`);
    await Promise.all([loadCart(), loadCustomerOrders()]);
    byId("customer-orders").scrollIntoView({ behavior: "smooth", block: "center" });
  } catch (error) {
    toast(error.message, true);
  }
}

export async function loadCustomerOrders() {
  try {
    const data = await request("/orders");
    renderOrders(byId("customer-orders"), data.orders, "customer", async () => {});
  } catch (error) {
    byId("customer-orders").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}</div>`;
  }
}
