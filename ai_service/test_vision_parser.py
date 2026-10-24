import json, re

# Simulate what Vision AI model returns as structured JSON
raw_json = '{"observations": ["A golden retriever dog is visible in the center of the frame.", "The dog appears to be sitting on green grass.", "Natural outdoor lighting is present."], "inferences": ["The setting appears to be a park or garden given the open grass area.", "The dog looks calm and attentive."], "answer": "The image shows a golden retriever dog sitting on green grass, likely in a park or garden setting. The dog appears calm and well-groomed.", "confidence": "HIGH", "decision": "DIRECT_ANSWER", "claim_status": "SUPPORTED", "limitation": "", "needs_verification": false, "verification_reason": "", "suggested_followups": ["What breed characteristics confirm this is a golden retriever?", "Is the dog wearing a collar?", "How old does the dog appear to be?"]}'

def _parse_vision_json(raw):
    if not raw: return None
    cleaned = re.sub(r'^```(?:json)?\n?', '', raw.strip())
    cleaned = re.sub(r'\n?```$', '', cleaned.strip())
    try: return json.loads(cleaned)
    except json.JSONDecodeError:
        m = re.search(r'\{.*\}', cleaned, re.DOTALL)
        if m:
            try: return json.loads(m.group())
            except: pass
    return None

def _format_vision_response(parsed):
    lines = []
    answer = parsed.get("answer", "").strip()
    confidence = parsed.get("confidence", "").strip()
    observations = parsed.get("observations") or []
    inferences = parsed.get("inferences") or []
    limitation = parsed.get("limitation", "").strip()
    claim_status = parsed.get("claim_status", "").strip()
    suggested_followups = parsed.get("suggested_followups") or []
    confidence_emoji = {"HIGH": "🟢", "MEDIUM": "🟡", "LOW": "🟠", "INSUFFICIENT": "🔴"}.get(confidence, "⚪")
    lines.append("## 🎯 Answer\n" + answer)
    if observations:
        lines.append("\n## 🔍 Visual Observations & Evidence")
        for obs in observations:
            lines.append("- " + obs)
    if inferences:
        lines.append("\n## 🧠 Inferences")
        for inf in inferences:
            lines.append("- " + inf)
    if confidence:
        conf_line = "**Confidence:** " + confidence_emoji + " " + confidence
        if claim_status:
            conf_line += "  ·  **Evidence Status:** " + claim_status
        lines.append("\n" + conf_line)
    if limitation:
        lines.append("\n> ⚠️ **Limitation:** " + limitation)
    if suggested_followups:
        lines.append("\n## 💡 Suggested Follow-ups")
        for fup in suggested_followups:
            lines.append("- " + fup)
    return "\n".join(lines)

parsed = _parse_vision_json(raw_json)
assert parsed and "answer" in parsed, "JSON parse failed!"
result = _format_vision_response(parsed)
print("=== FORMATTED OUTPUT ===")
print(result)
print("\n=== TEST PASSED ===")
