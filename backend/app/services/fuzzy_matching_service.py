from typing import Dict, List, Optional
from rapidfuzz import fuzz
from app.schemas.ai_intake import FuzzyMatchCandidate, FuzzyMatchResponse


class FuzzyMatchingService:
    """
    Implements weighted Trigram & Token-sort entity resolution to map
    OCR raw supplier strings to Chart of Accounts ledgers.
    """

    # Learned vendor aliases dictionary (empty by default, populated dynamically at runtime)
    _learned_aliases: Dict[str, str] = {}

    @classmethod
    def match_vendor_to_ledger(
        cls,
        query: str,
        business_id: str,
        threshold: float = 65.0,
        available_ledgers: Optional[List[dict]] = None,
    ) -> FuzzyMatchResponse:
        clean_query = query.strip().lower()

        # Check exact alias memory first
        if clean_query in cls._learned_aliases:
            target_name = cls._learned_aliases[clean_query]
            return FuzzyMatchResponse(
                query=query,
                best_match=FuzzyMatchCandidate(
                    ledger_id="led-alias-match",
                    ledger_name=target_name,
                    similarity_score=100.0,
                    is_exact_match=True,
                ),
                candidates=[
                    FuzzyMatchCandidate(
                        ledger_id="led-alias-match",
                        ledger_name=target_name,
                        similarity_score=100.0,
                        is_exact_match=True,
                    )
                ],
            )

        candidates: List[FuzzyMatchCandidate] = []
        ledgers = available_ledgers or []

        for ledger in ledgers:
            ledger_name = ledger.get("name", "")
            # Calculate composite score (Token Sort + Partial Ratio)
            token_sort = fuzz.token_sort_ratio(query, ledger_name)
            partial = fuzz.partial_ratio(query, ledger_name)
            composite_score = round(0.6 * token_sort + 0.4 * partial, 1)

            if composite_score >= threshold:
                candidates.append(
                    FuzzyMatchCandidate(
                        ledger_id=ledger.get("id", "led-01"),
                        ledger_name=ledger_name,
                        similarity_score=composite_score,
                        is_exact_match=(composite_score >= 99.0),
                    )
                )

        # Sort descending by similarity
        candidates.sort(key=lambda c: c.similarity_score, reverse=True)

        best = candidates[0] if candidates else None

        return FuzzyMatchResponse(
            query=query,
            best_match=best,
            candidates=candidates,
        )

    @classmethod
    def learn_vendor_alias(cls, raw_alias: str, ledger_name: str) -> None:
        """Stores verified mapping into neural alias dictionary."""
        cls._learned_aliases[raw_alias.strip().lower()] = ledger_name.strip()
