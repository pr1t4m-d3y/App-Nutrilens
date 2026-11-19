"""The label-review agent pipeline.

Four agents run in sequence and hand work to each other through session state:

1. ingredient_analyst    reads the label and lists ingredients and additive codes
2. regulation_researcher searches the regulations (a tool loop with a search budget)
3. profile_reviewer      ranks the findings against the user's coarse flags
4. citation_verifier     checks each finding against the full text of its sources

The framework runs the agents. What reaches the app is decided afterwards by
plain code in `assemble.py`, which drops anything the verifier rejected and
anything without a valid citation.
"""

from google.adk.agents import LlmAgent, SequentialAgent
from google.genai import types

from ..config import Settings
from ..rag.retriever import Retriever
from .instructions import (
    analyst_instruction,
    researcher_instruction,
    reviewer_instruction,
    verifier_instruction,
)
from .state import FINDINGS_KEY, INGREDIENTS_KEY, REVIEW_KEY, VERIFICATION_KEY
from .tools import make_tools


def build_pipeline(settings: Settings, retriever: Retriever) -> SequentialAgent:
    search_regulations, get_source = make_tools(retriever, settings.agent_max_searches)
    generation = types.GenerateContentConfig(temperature=0.1, max_output_tokens=4096)

    analyst = LlmAgent(
        name="ingredient_analyst",
        description="Lists the ingredients and additive codes on a label.",
        model=settings.agent_light_model,
        instruction=analyst_instruction,
        generate_content_config=generation,
        output_key=INGREDIENTS_KEY,
    )
    researcher = LlmAgent(
        name="regulation_researcher",
        description="Finds regulation passages for the ingredients that matter.",
        model=settings.generation_model,
        instruction=researcher_instruction,
        tools=[search_regulations],
        generate_content_config=generation,
        output_key=FINDINGS_KEY,
    )
    reviewer = LlmAgent(
        name="profile_reviewer",
        description="Ranks findings by relevance to the user's flags.",
        model=settings.agent_light_model,
        instruction=reviewer_instruction,
        generate_content_config=generation,
        output_key=REVIEW_KEY,
    )
    verifier = LlmAgent(
        name="citation_verifier",
        description="Checks each finding against the text of its cited sources.",
        model=settings.generation_model,
        instruction=verifier_instruction,
        tools=[get_source],
        generate_content_config=generation,
        output_key=VERIFICATION_KEY,
    )
    return SequentialAgent(
        name="label_review",
        description="Reviews a food label against regulations, with checked citations.",
        sub_agents=[analyst, researcher, reviewer, verifier],
    )
