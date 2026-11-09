const errorBox = document.getElementById("order-error");
const storeSelect = document.getElementById("store-select");
const itemRows = document.getElementById("item-rows");
const form = document.getElementById("order-form");
let skus = [];

async function fillStores() {
  const stores = await api("GET", "/api/stores");
  storeSelect.innerHTML = stores
    .map((s) => `<option value="${s.store_id}">${escapeHtml(s.store_name)}</option>`)
    .join("");
}

function skuOptions() {
  return skus
    .map((s) => `<option value="${s.sku_id}">${escapeHtml(s.product_name)} / ${escapeHtml(s.sku_name)} ￥${money(s.price)}（库存 ${s.stock}）</option>`)
    .join("");
}

async function loadSkus() {
  const storeId = storeSelect.value;
  skus = storeId ? await api("GET", `/api/skus?store_id=${encodeURIComponent(storeId)}`) : [];
  itemRows.querySelectorAll(".sku-select").forEach((select) => {
    select.innerHTML = skuOptions();
  });
}

function addRow() {
  const row = document.createElement("div");
  row.className = "item-row";
  row.innerHTML = `
    <select class="sku-select">${skuOptions()}</select>
    <input class="qty-input" type="number" min="1" max="99" value="1">
    <button type="button" class="link-btn remove-row">移除</button>`;
  itemRows.appendChild(row);
}

document.addEventListener("click", (event) => {
  if (event.target.classList.contains("remove-row")) {
    event.target.closest(".item-row").remove();
  }
});

document.getElementById("add-row").addEventListener("click", addRow);

storeSelect.addEventListener("change", () => {
  loadSkus().catch((err) => showError(errorBox, err.message));
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  errorBox.hidden = true;

  const storeId = Number(storeSelect.value);
  if (!storeId) {
    showError(errorBox, "请选择门店");
    return;
  }
  const items = [...itemRows.querySelectorAll(".item-row")]
    .map((row) => ({
      sku_id: Number(row.querySelector(".sku-select").value),
      quantity: Number(row.querySelector(".qty-input").value),
    }))
    .filter((item) => item.sku_id);
  if (!items.length) {
    showError(errorBox, "请至少选择一件商品");
    return;
  }

  try {
    const order = await api("POST", "/api/orders", {
      store_id: storeId,
      pickup_time: document.getElementById("pickup-time").value || null,
      remark: document.getElementById("remark").value.trim() || null,
      items,
    });
    window.location.href = `/orders/${order.order_id}`;
  } catch (err) {
    showError(errorBox, err.message);
  }
});

fillStores()
  .then(() => loadSkus())
  .then(addRow)
  .catch((err) => showError(errorBox, err.message));
