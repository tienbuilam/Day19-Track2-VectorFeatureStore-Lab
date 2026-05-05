"""Demo: 5 queries showing HybridMemoryAgent combining Vector + Feature Store.

Run: python bonus/demo.py
Exits 0 if all 5 queries complete successfully.
"""
import io
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from bonus.agent import HybridMemoryAgent

MEMORIES = [
    "Tôi vừa đọc về Kubernetes Pod lifecycle và cách quản lý container trong production",
    "Bài viết về auto-scaling trên AWS EKS, tự động mở rộng cluster theo CPU usage",
    "Ghi chú: cloud security best practices — mã hoá dữ liệu, xác thực hai yếu tố, zero-trust architecture",
    "Tìm hiểu CI/CD pipeline với GitOps và Terraform cho infrastructure as code",
    "Đọc paper về vector embedding và RAG architecture cho hệ thống AI tiếng Việt",
    "Cloud networking: cân bằng tải multi-region, CDN edge, giảm latency cho user Việt Nam",
    "Kubernetes horizontal pod autoscaler — tự động mở rộng hạ tầng theo lưu lượng người dùng",
    "Bảo mật cloud: encryption at rest, TLS mutual authentication, OAuth JWT, zero-trust policy",
]

QUERIES = [
    ("Simple vector",          "Tôi đã đọc gì về Kubernetes?"),
    ("Needs profile",          "Recommend đọc gì tiếp"),
    ("Needs fresh activity",   "Tôi đang quan tâm gì gần đây?"),
    ("Paraphrase (vector wins)", "Tài liệu về tự động mở rộng hạ tầng?"),
    ("Mixed (hybrid+profile)", "Cho tôi summary cloud security"),
]


def main() -> None:
    print("Initialising HybridMemoryAgent (loading fastembed model)...")
    agent = HybridMemoryAgent()

    print(f"Seeding {len(MEMORIES)} memories for user u_001...\n")
    for mem in MEMORIES:
        agent.remember(mem, user_id="u_001")

    for idx, (label, query) in enumerate(QUERIES, 1):
        print("=" * 60)
        print(f"Query {idx}/{len(QUERIES)} [{label}]: {query}")
        print("=" * 60)
        context = agent.recall(query, user_id="u_001")
        print(context)
        print()

    print("All 5 queries completed successfully.")


if __name__ == "__main__":
    main()
