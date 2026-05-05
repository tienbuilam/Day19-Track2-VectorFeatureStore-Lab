# Reflection — Lab 19

**Tên:** Bùi Lâm Tiến

**Path đã chạy:** Lite

---

## Câu hỏi (≤ 200 chữ)

> Trên golden set 50 queries, mode nào thắng ở loại query nào (`exact` /
> `paraphrase` / `mixed`), và tại sao? Khi nào bạn **không** dùng hybrid
> (i.e. khi nào pure BM25 hoặc pure vector là lựa chọn đúng)?

Trên golden set 50 queries với `bge-small-en-v1.5`:

- **`exact` (15 queries):** BM25 thắng rõ (96.7%) vì query chứa từ kỹ thuật verbatim trong corpus — BM25 khớp chính xác token, semantic không thêm được gì (88.7%). Hybrid ngang BM25 (96.7%) vì BM25 signal đã đủ mạnh.
- **`mixed` (20 queries):** Hybrid thắng tuyệt đối (100%) so với BM25 (97.0%) và semantic (98.5%). Đây là pattern thực tế nhất — user thật thường dùng cả từ exact lẫn ý paraphrase.
- **`paraphrase` (15 queries):** Cả ba mode đều yếu (~24–33%) vì model `bge-small-en` không hiểu tiếng Việt tốt. BM25 không khớp được từ đồng nghĩa; semantic thiếu multilingual context. Đổi sang `multilingual-e5-large` sẽ cải thiện rõ.

**Khi không dùng hybrid:** (1) Corpus toàn exact-match term (logs, mã lỗi, SKU) → BM25 đủ, hybrid thêm overhead vô ích. (2) Latency budget rất thấp (< 5ms) và corpus nhỏ → pure vector nhanh hơn. (3) Không có GPU/compute để embed query real-time → BM25 only.

---

## Điều ngạc nhiên nhất khi làm lab này

_(Optional, 1–2 câu)_

---

## Bonus challenge

- [x] Đã làm bonus (xem `bonus/`)
