from datetime import datetime
from decimal import Decimal, InvalidOperation

from ..errors import bad_request


def require_text(value, field, max_len=100):
    if not isinstance(value, str) or not value.strip():
        raise bad_request(f"{field}不能为空")
    text = value.strip()
    if len(text) > max_len:
        raise bad_request(f"{field}不能超过 {max_len} 个字符")
    return text


def optional_text(value, field, max_len=200):
    if value is None:
        return None
    if not isinstance(value, str):
        raise bad_request(f"{field}格式不正确")
    text = value.strip()
    if len(text) > max_len:
        raise bad_request(f"{field}不能超过 {max_len} 个字符")
    return text or None


def require_int(value, field, minimum=1, maximum=10**9):
    if isinstance(value, bool):
        raise bad_request(f"{field}必须是整数")
    try:
        number = int(value)
    except (TypeError, ValueError):
        raise bad_request(f"{field}必须是整数")
    if number < minimum or number > maximum:
        raise bad_request(f"{field}必须在 {minimum} 到 {maximum} 之间")
    return number


def require_decimal(value, field, minimum=0, maximum=100000):
    try:
        number = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise bad_request(f"{field}必须是数字")
    if number < Decimal(str(minimum)) or number > Decimal(str(maximum)):
        raise bad_request(f"{field}超出允许范围")
    if number != number.quantize(Decimal("0.01")):
        raise bad_request(f"{field}最多保留两位小数")
    return number


def require_choice(value, field, choices):
    if value not in choices:
        raise bad_request(f"{field}只能是：{' / '.join(choices)}")
    return value


def optional_datetime(value, field):
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        raise bad_request(f"{field}格式不正确")
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        raise bad_request(f"{field}格式不正确")
