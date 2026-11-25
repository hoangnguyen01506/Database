// HỘP THƯ THÔNG BÁO
import { byId, escapeHtml, request, toast } from "./shared.js";

let lastLoadError = null;

export async function refreshNotificationBadge() {
  try {
    const data = await request("/notifications");
    lastLoadError = null;
    renderNotifications(data.notifications);
    const unreadCount = Number(data.unread_count);
    const badge = byId("notification-count");
    badge.textContent = unreadCount > 99 ? "99+" : String(unreadCount);
    badge.classList.toggle("hidden", unreadCount === 0);
    return true;
  } catch (error) {
    lastLoadError = error;
    if (byId("notifications-modal").classList.contains("show")) {
      renderLoadError(error);
    }
    return false;
  }
}

export async function openNotifications() {
  const modal = byId("notifications-modal");
  if (modal.classList.contains("show")) {
    closeNotifications();
    return;
  }
  modal.classList.add("show");
  modal.setAttribute("aria-hidden", "false");
  byId("notifications-button").setAttribute("aria-expanded", "true");
  if (lastLoadError) renderLoadError(lastLoadError);
  await refreshNotificationBadge();
}

export function closeNotifications() {
  const modal = byId("notifications-modal");
  modal.classList.remove("show");
  modal.setAttribute("aria-hidden", "true");
  byId("notifications-button").setAttribute("aria-expanded", "false");
}

function renderNotifications(notifications) {
  const container = byId("notifications-list");
  if (!notifications.length) {
    container.innerHTML = '<div class="empty-state">Bạn chưa có thông báo nào.</div>';
    return;
  }
  container.innerHTML = notifications.map((item) => {
    const unread = Number(item.is_read) !== 1;
    const date = new Date(item.created_at);
    const createdAt = Number.isNaN(date.getTime())
      ? String(item.created_at || "")
      : date.toLocaleString("vi-VN");
    return `<article class="notification-card${unread ? " unread" : ""}">
      <div class="notification-copy">
        <div class="notification-title">${escapeHtml(item.title)}</div>
        <p>${escapeHtml(item.message)}</p>
        <small>${escapeHtml(createdAt)}${item.order_id ? ` · Đơn #${Number(item.order_id)}` : ""}</small>
      </div>
      ${unread ? `<button class="button button-outline" type="button" data-read-notification="${Number(item.notification_id)}">Đánh dấu đã đọc</button>` : ""}
    </article>`;
  }).join("");
  container.querySelectorAll("[data-read-notification]").forEach((button) => {
    button.addEventListener("click", () => markNotificationRead(button));
  });
}

function renderLoadError(error) {
  byId("notifications-list").innerHTML =
    `<div class="empty-state notification-error">${escapeHtml(error.message)}</div>`;
}

async function markNotificationRead(button) {
  const notificationId = Number(button.dataset.readNotification);
  button.disabled = true;
  try {
    await request(`/notifications/${notificationId}/read`, { method: "POST", body: "{}" });
    await refreshNotificationBadge();
  } catch (error) {
    toast(error.message, true);
    button.disabled = false;
  }
}
