# SPEC: Acquis

Cross-lingual regulatory intelligence over EU financial regulation. Ingests
EUR-Lex, EBA, and Central Bank of Ireland publications in English plus German
or French, deduplicates language versions, extracts obligations with span
citations, and serves a cited Q&A endpoint plus a weekly digest. The
engineering centerpiece is a measured bake-off between a parsed-text
retrieval pipeline and a visual late-interaction pipeline, sitting on a
validation-grade eval harness with CI regression gates, tracing, and drift
monitoring.

## Why this domain

Horizon scanning is done by hand at mid-size firms; enterprise tools charge
five to six figures. Outputs are auditable, so citation faithfulness is a
hard requirement. Dublin regtech (Corlytics, Fenergo), Big 4 regulatory AI,
and the validation framing pairs with the Grant Thornton capstone narrative.

## Pipeline

1. Ingest: Cellar SPARQL/REST for EUR-Lex, RSS pollers for EBA and CBI.
   Page rasterization alongside Docling parsing. Idempotent, scheduled.
2. Enrich: zero-shot topic classification (mDeBERTa NLI), cross-lingual
   dedup via CELEX alignment and embeddings, GLiNER entities and dates.
3. Index, two paths:
   - Text: Docling parse, chunking (H), BGE-M3 dense + sparse, BM25, RRF
     fusion (H), bge-reranker-v2-m3.
   - Visual: ColQwen2 page multivectors, MaxSim scoring. Reference MaxSim
     implemented by hand (H) before swapping to Qdrant's native scorer.
   Both live in Qdrant: named vectors for dense, multivectors for ColQwen.
   pgvector was rejected for lack of multivector MaxSim (ADR 0001).
4. Serve: retrieve and rerank, tiered LLM synthesis with span citations
   (small model for extraction, larger for synthesis), VLM answers from page
   images on the visual path (Qwen2.5-VL class, API-hosted to start).
5. Verify: LangGraph loop. Sufficiency node (retrieve, assess coverage,
   re-query once), then a citation checker confirming each claim's cited
   span supports it. Bounded retries, escalation path, fully traced.
6. Monitor: Langfuse traces with per-node cost, CI eval gates, weekly drift
   statistic (H) on incoming document embeddings, replay demo on the
   2022-2025 archive showing the DORA consultation wave firing the alert.

## Evaluation design

- Golden set ~300 queries: auto-generated, hand-verified. Cross-lingual
  retrieval labels come free from EUR-Lex official parallel translations
  keyed by CELEX number: a query against the English version must retrieve
  its German counterpart.
- Retrieval: recall@k, MRR, nDCG@5 per language pair, implemented from
  scratch (H), no metric libraries.
- Extraction: F1 on obligations and dates against hand labels, English only.
- Faithfulness: LLM judge calibrated against ~200 human labels, agreement
  reported as Cohen's kappa (H). Off-the-shelf RAGAS-style reference-free
  defaults rejected (ADR).
- External anchor: seed part of the QA set from ObliQA / RIRAG shared-task
  data over ADGM regulations if still available (verify week 1).
- CI: nightly full eval, PR-triggered subset, merges blocked on regression
  past thresholds (H decides thresholds).

## Bake-off protocol

Same golden set, both paths, results split by document type (clean text,
table-heavy, scanned). Report the delta with run ids. Include where visual
loses, plus index-size and cost-per-query math (H). The ablation table and
the tech report are the primary portfolio artifacts.

## Data sources

- EUR-Lex via Cellar: SPARQL at publications.europa.eu/webapi/rdf/sparql,
  REST for document retrieval. Parallel language versions via CELEX ids.
- EBA and ESMA publication feeds; Central Bank of Ireland publications.
- Verify all endpoints in week 1; CBI is first to cut if scope slips.

## Hardware and inference

Dev-scale embedding runs on Apple Silicon MPS or CPU; bulk page embedding
either on a short GPU rental or by falling back to ColModernVBERT (smaller
ColPali-family model) if rental is unwanted. VLM and synthesis via hosted
APIs, tiered for cost. Optional stretch after M10: serve a small open model
behind vLLM to show serving literacy.

## Scope guards

Three sources max. English plus one of German/French; add the third
language only if ahead. No auth, no product chrome. Streamlit page in the
final week only. Classifier distillation (LLM labels into a fine-tuned
small model) only if ahead of schedule.
