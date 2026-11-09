const canManage = document.getElementById("product-create-form") !== null;
const listError = document.getElementById("list-error");

function renderProducts(products) {
  const tbody = document.getElementById("product-rows");
  tbody.innerHTML = products.map((p) => {
    const skuLines = p.skus.length
      ? p.skus.map((s) => `${escapeHtml(s.sku_name)} ￥${money(s.price)}（${escapeHtml(s.status)}）`).join("<br>")
      : "—";
    const actions = [`<a href="/products/${p.product_id}">详情</a>`];
    if (canManage) {
      actions.push(
        `<button type="button" class="link-btn danger" data-delete="${p.product_id}" data-name="${escapeHtml(p.product_name)}">删除</button>`
      );
    }
    return `<tr>
      <td>${p.product_id}</td>
      <td>${escapeHtml(p.product_name)}</td>
      <td>${escapeHtml(p.category_name)}</td>
      <td>${escapeHtml(p.status)}</td>
      <td>${skuLines}</td>
      <td>${actions.join(" ")}</td>
    </tr>`;
  }).join("");
}

async function fillCategories(select) {
  const categories = await api("GET", "/api/categories");
  select.innerHTML = categories
    .map((c) => `<option value="${c.category_id}">${escapeHtml(c.category_name)}</option>`)
    .join("");
}

async function loadProducts() {
  renderProducts(await api("GET", "/api/products"));
}

document.addEventListener("click", async (event) => {
  const btn = event.target.closest("button[data-delete]");
  if (!btn) return;
  if (!confirm(`删除商品「${btn.dataset.name}」？`)) return;
  listError.hidden = true;
  try {
    await api("DELETE", `/api/products/${btn.dataset.delete}`);
    await loadProducts();
  } catch (err) {
    showError(listError, err.message);
  }
});

if (canManage) {
  const form = document.getElementById("product-create-form");
  const categorySelect = document.getElementById("p-category");
  const formError = document.getElementById("product-error");

  fillCategories(categorySelect).catch((err) => showError(formError, err.message));

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    formError.hidden = true;
    const name = document.getElementById("p-name").value.trim();
    if (!name) {
      showError(formError, "请填写商品名称");
      return;
    }
    if (!categorySelect.value) {
      showError(formError, "请选择分类");
      return;
    }
    try {
      await api("POST", "/api/products", {
        product_name: name,
        category_id: Number(categorySelect.value),
        description: document.getElementById("p-desc").value.trim() || null,
        status: document.getElementById("p-status").value,
      });
      form.reset();
      await loadProducts();
    } catch (err) {
      showError(formError, err.message);
    }
  });
}

loadProducts().catch((err) => showError(listError, err.message));
