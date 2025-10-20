"""
Heritage API 유틸리티 함수들
XML 파싱 및 데이터 추출 로직
"""

def pick(d, k, default=""):
    """딕셔너리에서 안전하게 값 추출"""
    return d.get(k, default) if isinstance(d, dict) else default


def first_non_empty(*vals):
    """첫 번째로 비어있지 않은 문자열 반환"""
    for v in vals:
        if isinstance(v, str) and v.strip():
            return v
    return ""


def extract_items(xml_dict):
    """XML 딕셔너리에서 items 리스트 추출"""
    if not isinstance(xml_dict, dict):
        return []

    roots_to_try = [
        ["result", "items", "item"],
        ["result", "list", "item"],
        ["items", "item"],
        ["list", "item"],
        ["result", "item"],
        ["item"],
    ]

    for path in roots_to_try:
        cur = xml_dict
        ok = True
        for k in path:
            if isinstance(cur, dict) and k in cur:
                cur = cur[k]
            else:
                ok = False
                break
        if ok:
            if isinstance(cur, list):
                return cur
            if isinstance(cur, dict):
                return [cur]
    return []
