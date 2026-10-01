import asyncio
import os
from google import genai
from google.genai import types

async def main():
    client = genai.Client()
    
    texts = [
        "What is the meaning of life?",
        "What is the purpose of existence?",
        "How do I bake a cake?",
    ]
    
    contents = [
        {"role": "user", "parts": [{"text": t}]} for t in texts
    ]
    
    result = await client.aio.models.embed_content(
        model="gemini-embedding-2",
        contents=contents,
        config=types.EmbedContentConfig(output_dimensionality=1536)
    )
    
    print(f"Number of embeddings: {len(result.embeddings)}")
    print(f"Dimension of first embedding: {len(result.embeddings[0].values)}")

if __name__ == "__main__":
    asyncio.run(main())
