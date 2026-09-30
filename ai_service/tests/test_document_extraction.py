from io import BytesIO

import pytest
from pypdf import PdfWriter

from services.document_extraction import UnsupportedDocumentType, extract_document


def test_text_document_is_extracted_and_normalized() -> None:
    result = extract_document("notes.md", b"Cloud\r\n\r\nresources scale.")

    assert result.status == "READY"
    assert result.pages == [(None, "Cloud\n\nresources scale.")]


def test_scanned_or_empty_pdf_is_marked_for_ocr() -> None:
    writer = PdfWriter()
    writer.add_blank_page(width=300, height=300)
    output = BytesIO()
    writer.write(output)

    result = extract_document("scan.pdf", output.getvalue())

    assert result.status == "OCR_REQUIRED"
    assert result.pages == []


def test_pdf_page_numbers_are_preserved(monkeypatch: pytest.MonkeyPatch) -> None:
    class FakePage:
        def __init__(self, text: str) -> None:
            self._text = text

        def extract_text(self) -> str:
            return self._text

    class FakeReader:
        pages = [FakePage(""), FakePage("Budget details"), FakePage(""), FakePage("Forecast")]

    monkeypatch.setattr("services.document_extraction.PdfReader", lambda *_args, **_kwargs: FakeReader())

    result = extract_document("budget.pdf", b"fake pdf data")

    assert result.status == "READY"
    assert result.pages == [(2, "Budget details"), (4, "Forecast")]


def test_unsupported_documents_are_not_silently_indexed() -> None:
    with pytest.raises(UnsupportedDocumentType):
        extract_document("archive.zip", b"bytes")