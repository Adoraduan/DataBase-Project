const form = document.getElementById("login-form");
const errorBox = document.getElementById("login-error");

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  errorBox.hidden = true;

  const username = document.getElementById("username").value.trim();
  const password = document.getElementById("password").value;
  if (!username || !password) {
    showError(errorBox, "请输入用户名和密码");
    return;
  }

  try {
    await api("POST", "/api/auth/login", { username, password });
    window.location.href = "/dashboard";
  } catch (err) {
    showError(errorBox, err.message || "登录失败");
  }
});
