const { productId, role } = window.PAGE;
const canManage = role === "manager";
const errorBox = document.getElementById("detail-error");

function renderView(product) {
  document.getElementById("product-view").innerHTML = `
    <h2>${escapeHtml(product.product_name)}</h2>
    <p>分类：${escapeHtml(product.category_name)}　状态：${escapeHtml(product.status)}</p>
    <p>${escapeHtml(product.description || "无描述")}</p>`;
}

function renderSkus(skus) {
  const tbody = document.getElementById("sku-rows");
  tbody.innerHTML = skus.map((s) => {
    if (!canManage) {
      return `<tr><td>${escapeHtml(s.sku_name)}</td><td>￥${money(s.price)}</td><td>${escapeHtml(s.status)}</td></tr>`;
    }
    return `<tr data-sku="${s.sku_id}">
      <td><input class="sku-name" maxlength="50" value="${escapeHtml(s.sku_name)}"></td>
      <td><input class="sku-price" type="number" step="0.01" min="0" value="${money(s.price)}"></td>
      <td>
        <select class="sku-status">
          <option value="上架" ${s.status === "上架" ? "selected" : ""}>上架</option>
          <option value="下架" ${s.status === "下架" ? "selected" : ""}>下架</option>
        </select>
      </td>
      <td><button type="button" class="link-btn" data-save-sku="${s.sku_id}">保存</button></td>
    </tr>`;
  }).join("");
}

function fillEditForm(product) {
  document.getElementById("edit-name").value = product.product_name;
  document.getElementById("edit-category").value = String(product.category_id);
  document.getElementById("edit-desc").value = product.description || "";
  document.getElementById("edit-status").value = product.status;
  document.getElementById("product-edit-form").hidden = false;
}

async function load() {
  const product = await api("GET", `/api/products/${productId}`);
  renderView(product);
  renderSkus(product.skus);
  if (canManage) {
    fillEditForm(product);
  }
}

async function fillCategories(select) {
  const categories = await api("GET", "/api/categories");
  select.innerHTML = categories
    .map((c) => `<option value="${c.category_id}">${escapeHtml(c.category_name)}</option>`)
    .join("");
}

document.addEventListener("click", async (event) => {
  const saveSku = event.target.closest("button[data-save-sku]");
  if (saveSku) {
    const row = saveSku.closest("tr");
    errorBox.hidden = true;
    try {
      await api("PUT", `/api/skus/${saveSku.dataset.saveSku}`, {
        sku_name: row.querySelector(".sku-name").value.trim(),
        price: row.querySelector(".sku-price").value,
        status: row.querySelector(".sku-status").value,
      });
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
    return;
  }

  if (event.target.id === "delete-product") {
    if (!confirm("删除这个商品？")) return;
    errorBox.hidden = true;
    try {
      await api("DELETE", `/api/products/${productId}`);
      window.location.href = "/products";
    } catch (err) {
      showError(errorBox, err.message);
    }
  }
});

if (canManage) {
  const editForm = document.getElementById("product-edit-form");
  const editCategory = document.getElementById("edit-category");
  const skuForm = document.getElementById("sku-create-form");

  editForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    errorBox.hidden = true;
    try {
      await api("PUT", `/api/products/${productId}`, {
        product_name: document.getElementById("edit-name").value.trim(),
        category_id: Number(editCategory.value),
        description: document.getElementById("edit-desc").value.trim() || null,
        status: document.getElementById("edit-status").value,
      });
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
  });

  skuForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    errorBox.hidden = true;
    try {
      await api("POST", `/api/products/${productId}/skus`, {
        sku_name: document.getElementById("sku-name").value.trim(),
        price: document.getElementById("sku-price").value,
        status: document.getElementById("sku-status").value,
      });
      skuForm.reset();
      await load();
    } catch (err) {
      showError(errorBox, err.message);
    }
  });
}

(async () => {
  if (canManage) {
    await fillCategories(document.getElementById("edit-category"));
  }
  await load();
})().catch((err) => showError(errorBox, err.message));
