const errorBox = document.getElementById("inventory-error");

async function fillStores() {
  const stores = await api("GET", "/api/stores");
  const select = document.getElementById("store-filter");
  select.innerHTML =
    '<option value="">全部门店</option>' +
    stores.map((s) => `<option value="${s.store_id}">${escapeHtml(s.store_name)}</option>`).join("");
}

async function loadInventory() {
  const storeId = document.getElementById("store-filter").value;
  const url = storeId ? `/api/inventory?store_id=${encodeURIComponent(storeId)}` : "/api/inventory";
  const rows = await api("GET", url);
  document.getElementById("inventory-rows").innerHTML = rows.map((row) => `
    <tr data-row="${row.sku_id}-${row.store_id}">
      <td>${escapeHtml(row.store_name)}</td>
      <td>${escapeHtml(row.product_name)}</td>
      <td>${escapeHtml(row.sku_name)}</td>
      <td>￥${money(row.price)}</td>
      <td><input class="qty-input" type="number" min="0" max="9999" value="${row.quantity}"></td>
      <td><button type="button" class="link-btn" data-save="${row.sku_id}" data-store="${row.store_id}">保存</button></td>
    </tr>`).join("");
}

document.addEventListener("click", async (event) => {
  const btn = event.target.closest("button[data-save]");
  if (!btn) return;
  const row = btn.closest("tr");
  errorBox.hidden = true;
  try {
    await api("PUT", "/api/inventory", {
      sku_id: Number(btn.dataset.save),
      store_id: Number(btn.dataset.store),
      quantity: Number(row.querySelector(".qty-input").value),
    });
    await loadInventory();
  } catch (err) {
    showError(errorBox, err.message);
  }
});

document.getElementById("store-filter").addEventListener("change", () => {
  loadInventory().catch((err) => showError(errorBox, err.message));
});

fillStores()
  .then(loadInventory)
  .catch((err) => showError(errorBox, err.message));
