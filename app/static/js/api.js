async function api(method, url, body) {
  const options = {
    method,
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
  };
  if (body !== undefined) {
    options.body = JSON.stringify(body);
  }

  let response;
  try {
    response = await fetch(url, options);
  } catch (err) {
    throw { code: 5000, message: "网络异常，请稍后再试" };
  }

  let payload;
  try {
    payload = await response.json();
  } catch (err) {
    throw { code: 5000, message: "服务返回异常，请稍后再试" };
  }

  if (!response.ok) {
    if (response.status === 401) {
      window.location.href = "/login";
    }
    throw payload;
  }
  return payload.data;
}

function showError(element, message) {
  if (!element) return;
  element.textContent = message;
  element.hidden = false;
}

function money(value) {
  return Number(value || 0).toFixed(2);
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[ch]));
}
