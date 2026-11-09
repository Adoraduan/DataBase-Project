const { orderId, role } = window.PAGE;
const NEXT = { "已支付": "制作中", "制作中": "待取餐", "待取餐": "已完成" };
const errorBox = document.getElementById("detail-error");
let order = null;

function summary(order) {
  return `
    <h2>${escapeHtml(order.order_no)}</h2>
    <p>状态：${escapeHtml(order.status)}　门店：${escapeHtml(order.store_name)}　顾客：${escapeHtml(order.username)}</p>
    <p>金额：￥${money(order.total_amount)}　创建：${escapeHtml(order.created_at || "")}　支付：${escapeHtml(order.paid_at || "—")}　完成：${escapeHtml(order.completed_at || "—")}</p>
    <p>取餐时间：${escapeHtml(order.pickup_time || "—")}　备注：${escapeHtml(order.remark || "—")}</p>`;
}

function items(order) {
  const editable = role === "customer" && order.status === "待支付";
  return order.items.map((item) => `
    <tr data-item="${item.order_item_id}">
      <td>${escapeHtml(item.product_name)}</td>
      <td>${escapeHtml(item.sku_name)}</td>
      <td>￥${money(item.unit_price)}</td>
      <td>${editable ? `<input class="qty-input" type="number" min="1" max="99" value="${item.quantity}">` : item.quantity}</td>
      <td>￥${money(item.subtotal)}</td>
      ${role === "customer" ? `<td>${editable ? `
        <button type="button" class="link-btn" data-save-item="${item.order_item_id}">保存</button>
        <button type="button" class="link-btn danger" data-delete-item="${item.order_item_id}">删除</button>` : ""}</td>` : ""}
    </tr>`).join("");
}

function actions(order) {
  if (role === "customer" && order.status === "待支付") {
    return `
      <button type="button" class="button" id="pay">支付（模拟）</button>
      <button type="button" class="danger-btn" id="cancel">取消订单</button>`;
  }
  if (role === "staff" && NEXT[order.status]) {
    return `<button type="button" class="button" id="advance" data-target="${NEXT[order.status]}">推进到${NEXT[order.status]}</button>`;
  }
  return "";
}

async function loadAddSkuOptions(storeId) {
  const select = document.getElementById("add-sku");
  if (!select) return;
  const skus = await api("GET", `/api/skus?store_id=${encodeURIComponent(storeId)}`);
  select.innerHTML = skus
    .map((s) => `<option value="${s.sku_id}">${escapeHtml(s.product_name)} / ${escapeHtml(s.sku_name)} ￥${money(s.price)}（库存 ${s.stock}）</option>`)
    .join("");
}

async function load() {
  order = await api("GET", `/api/orders/${orderId}`);
  document.getElementById("order-summary").innerHTML = summary(order);
  document.getElementById("order-actions").innerHTML = actions(order);
  document.getElementById("item-rows").innerHTML = items(order);

  if (role === "customer") {
    const addSection = document.getElementById("item-add");
    if (order.status === "待支付") {
      addSection.hidden = false;
      await loadAddSkuOptions(order.store_id);
    } else {
      addSection.hidden = true;
    }
  }
}

document.addEventListener("click", async (event) => {
  errorBox.hidden = true;

  const saveBtn = event.target.closest("button[data-save-item]");
  if (saveBtn) {
    const row = saveBtn.closest("tr");
    try {
      await api("PUT", `/api/orders/${orderId}/items/${saveBtn.dataset.saveItem}`, {
        quantity: Number(row.querySelector(".qty-input").value),
      });
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
    return;
  }

  const deleteBtn = event.target.closest("button[data-delete-item]");
  if (deleteBtn) {
    if (!confirm("移除这条明细？")) return;
    try {
      await api("DELETE", `/api/orders/${orderId}/items/${deleteBtn.dataset.deleteItem}`);
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
    return;
  }

  if (event.target.id === "pay") {
    try {
      await api("POST", `/api/orders/${orderId}/pay`);
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
    return;
  }

  if (event.target.id === "cancel") {
    if (!confirm("取消这张订单？库存会退回。")) return;
    try {
      await api("POST", `/api/orders/${orderId}/cancel`);
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
    return;
  }

  if (event.target.id === "advance") {
    try {
      await api("POST", `/api/orders/${orderId}/status`, { status: event.target.dataset.target });
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
    return;
  }

  if (event.target.id === "add-item") {
    const skuSelect = document.getElementById("add-sku");
    try {
      await api("POST", `/api/orders/${orderId}/items`, {
        sku_id: Number(skuSelect.value),
        quantity: Number(document.getElementById("add-qty").value),
      });
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
  }
});

load().catch((err) => showError(errorBox, err.message));
