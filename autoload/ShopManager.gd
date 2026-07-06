extends Node
## 상점/IAP 매니저 — Google Play Billing stub
signal purchase_completed(product_id: String)

const PRODUCTS := {
    "jelly_100": {"jelly": 100, "price_krw": 1300},
    "jelly_550": {"jelly": 550, "price_krw": 6500},
    "jelly_1200": {"jelly": 1200, "price_krw": 13000},
}

func purchase(product_id: String) -> bool:
    if not PRODUCTS.has(product_id):
        return false
    # TODO: 실제 Google Play Billing API 호출 (W3+)
    purchase_completed.emit(product_id)
    return true