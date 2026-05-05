"""HybridMemoryAgent — episodic memory (Qdrant) + user profile (Feast).

Patterns reused from:
  - app/search.py: embed+upsert, BM25, RRF k=60, tokenizer, query_points
  - notebooks/04_feast_feature_store.py: FeatureStore init, get_online_features
"""
from __future__ import annotations

import time
from pathlib import Path

from fastembed import TextEmbedding
from feast import FeatureStore
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    MatchValue,
    PointStruct,
    VectorParams,
)
from rank_bm25 import BM25Okapi

EMBED_MODEL = "BAAI/bge-small-en-v1.5"
EMBED_DIM = 384
COLLECTION = "hybrid_memory"
RRF_K = 60

_DEFAULT_FEAST_REPO = (
    Path(__file__).resolve().parent.parent / "app" / "feast_repo"
)

REQUEST_FEATURES = [
    "user_profile_features:reading_speed_wpm",
    "user_profile_features:preferred_language",
    "user_profile_features:topic_affinity",
    "query_velocity_features:queries_last_hour",
    "query_velocity_features:distinct_topics_24h",
]


class HybridMemoryAgent:
    def __init__(self, feast_repo_path: str | None = None) -> None:
        self._embedder = TextEmbedding(model_name=EMBED_MODEL)
        self._client = QdrantClient(":memory:")
        self._client.create_collection(
            collection_name=COLLECTION,
            vectors_config=VectorParams(size=EMBED_DIM, distance=Distance.COSINE),
        )
        self._docs: list[dict] = []
        self._bm25: BM25Okapi | None = None
        self._point_id: int = 0

        repo = Path(feast_repo_path) if feast_repo_path else _DEFAULT_FEAST_REPO
        self._feast = FeatureStore(repo_path=str(repo))

    # ── write path ──────────────────────────────────────────────────────

    def remember(self, text: str, user_id: str = "u_001") -> None:
        """Add a new piece of episodic memory (per-message chunk strategy)."""
        vec = next(self._embedder.embed([text])).tolist()
        self._client.upsert(
            collection_name=COLLECTION,
            points=[
                PointStruct(
                    id=self._point_id,
                    vector=vec,
                    payload={"user_id": user_id, "text": text, "ts": time.time()},
                )
            ],
        )
        self._docs.append({"user_id": user_id, "text": text})
        self._bm25 = BM25Okapi([self._tokenize(d["text"]) for d in self._docs])
        self._point_id += 1

    # ── read path ────────────────────────────────────────────────────────

    def recall(self, query: str, user_id: str = "u_001", top_k: int = 3) -> str:
        """Retrieve top-K memories + user profile → assembled context string."""
        # Step 1: user profile from Feast online store
        profile = self._get_profile(user_id)

        # Step 2: hybrid search filtered by user_id
        memories = self._search_hybrid(query, user_id, top_k)

        # Step 3: assemble context string
        lines = [
            f"[User Profile] "
            f"preferred_language={profile.get('preferred_language', 'N/A')}, "
            f"reading_speed={profile.get('reading_speed_wpm', 'N/A')}wpm, "
            f"topic_affinity={profile.get('topic_affinity', 'N/A')}",
            f"[Recent Activity] "
            f"queries_last_hour={profile.get('queries_last_hour', 'N/A')}, "
            f"distinct_topics_24h={profile.get('distinct_topics_24h', 'N/A')}",
            "[Top Memories]",
        ]
        if memories:
            for i, text in enumerate(memories, 1):
                lines.append(f"  {i}. {text}")
        else:
            lines.append("  (no memories stored yet)")
        return "\n".join(lines)

    # ── internals ────────────────────────────────────────────────────────

    def _get_profile(self, user_id: str) -> dict:
        try:
            raw = self._feast.get_online_features(
                features=REQUEST_FEATURES,
                entity_rows=[{"user_id": user_id}],
            ).to_dict()
            return {k: v[0] for k, v in raw.items()}
        except Exception:
            return {}

    def _search_hybrid(self, query: str, user_id: str, top_k: int) -> list[str]:
        if not self._docs:
            return []
        depth = max(top_k * 5, 50)

        # Semantic search — Qdrant payload filter by user_id
        q_vec = next(self._embedder.embed([query])).tolist()
        sem_res = self._client.query_points(
            collection_name=COLLECTION,
            query=q_vec,
            query_filter=Filter(
                must=[FieldCondition(key="user_id", match=MatchValue(value=user_id))]
            ),
            limit=depth,
        )
        sem_ids = [str(p.id) for p in sem_res.points]

        # Keyword search — BM25 + post-filter by user_id
        user_doc_indices = [i for i, d in enumerate(self._docs) if d["user_id"] == user_id]
        if self._bm25 is not None and user_doc_indices:
            scores = self._bm25.get_scores(self._tokenize(query))
            ranked = sorted(user_doc_indices, key=lambda i: -scores[i])[:depth]
            kw_ids = [str(i) for i in ranked]
        else:
            kw_ids = []

        # RRF fusion — rank 1-based, same formula as app/search.py lines 174-179
        rrf: dict[str, float] = {}
        for rank, doc_id in enumerate(kw_ids, start=1):
            rrf[doc_id] = rrf.get(doc_id, 0.0) + 1.0 / (RRF_K + rank)
        for rank, doc_id in enumerate(sem_ids, start=1):
            rrf[doc_id] = rrf.get(doc_id, 0.0) + 1.0 / (RRF_K + rank)

        top_ids = [doc_id for doc_id, _ in sorted(rrf.items(), key=lambda kv: -kv[1])[:top_k]]
        return [self._docs[int(i)]["text"] for i in top_ids if int(i) < len(self._docs)]

    @staticmethod
    def _tokenize(text: str) -> list[str]:
        return text.lower().split()
