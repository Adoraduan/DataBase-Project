const { role } = window.PAGE;
const NEXT = { "已支付": "制作中", "制作中": "待取餐", "待取餐": "已完成" };
const errorBox = document.getElementById("orders-error");

function actionCell(order) {
  const parts = [`<a href="/orders/${order.order_id}">详情</a>`];
  if (role === "staff" && NEXT[order.status]) {
    parts.push(
      `<button type="button" class="link-btn" data-advance="${order.order_id}" data-target="${NEXT[order.status]}">推进到${NEXT[order.status]}</button>`
    );
  }
  return parts.join(" ");
}

async function load() {
  const orders = await api("GET", "/api/orders");
  document.getElementById("order-rows").innerHTML = orders.map((order) => `
    <tr>
      <td>${escapeHtml(order.order_no)}</td>
      <td>${escapeHtml(order.store_name)}</td>
      <td>${escapeHtml(order.status)}</td>
      <td>￥${money(order.total_amount)}</td>
      <td>${order.item_count}</td>
      <td>${escapeHtml(order.created_at || "")}</td>
      <td>${actionCell(order)}</td>
    </tr>`).join("");
}

document.addEventListener("click", async (event) => {
  const btn = event.target.closest("button[data-advance]");
  if (!btn) return;
  errorBox.hidden = true;
  try {
    await api("POST", `/api/orders/${btn.dataset.advance}/status`, { status: btn.dataset.target });
    await load();
  } catch (err) {
    showError(errorBox, err.message);
  }
});

load().catch((err) => showError(errorBox, err.message));
