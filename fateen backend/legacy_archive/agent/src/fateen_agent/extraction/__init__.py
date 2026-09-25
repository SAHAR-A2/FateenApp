"""Extraction layer: raw source records -> evidence-backed facts."""

from .llm import LLMExtractor, NullExtractor, build_extractor
from .parser import ExtractedFacts, extract_facts

__all__ = [
    "ExtractedFacts",
    "extract_facts",
    "LLMExtractor",
    "NullExtractor",
    "build_extractor",
]
