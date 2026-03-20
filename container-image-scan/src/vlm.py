import litellm

_PROMPT_TEMPLATE = (
    'Does this image contain "{concept}"? '
    "Look carefully at the entire image including corners and edges. "
    "Reply with exactly one word: YES or NO."
)


def check_concept_vlm(
    image_b64: str,
    concept: str,
    api_base: str,
    api_key: str,
    model: str,
) -> bool:
    """Retorna True se o VLM detectar o conceito na imagem."""
    response = litellm.completion(
        model=model,
        api_base=api_base,
        api_key=api_key,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": _PROMPT_TEMPLATE.format(concept=concept)},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
            ],
        }],
        temperature=0,
        max_tokens=5,
    )
    return response.choices[0].message.content.strip().upper().startswith("YES")
