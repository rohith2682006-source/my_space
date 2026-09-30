from dataclasses import dataclass
from io import BytesIO
from pathlib import PurePath

from pypdf import PdfReader

from services.chunking import normalize_text


class UnsupportedDocumentType(ValueError):
    pass


@dataclass(frozen=True)
class ExtractedDocument:
    status: str
    pages: list[tuple[int | None, str]]


def extract_document(file_name: str, content: bytes) -> ExtractedDocument:
    extension = PurePath(file_name).suffix.lower()
    if extension == ".pdf":
        try:
            reader = PdfReader(BytesIO(content), strict=True)
            pages = [
                (page_number, normalize_text(page.extract_text() or ""))
                for page_number, page in enumerate(reader.pages, start=1)
            ]
        except Exception as error:
            raise ValueError("The PDF could not be read") from error

        if not any(text for _, text in pages):
            return ExtractedDocument(status="OCR_REQUIRED", pages=[])
        return ExtractedDocument(
            status="READY",
            pages=[(page_number, text) for page_number, text in pages if text],
        )

    if extension in {".txt", ".md", ".markdown"}:
        text = normalize_text(content.decode("utf-8-sig", errors="replace"))
        if not text:
            return ExtractedDocument(status="FAILED", pages=[])
        return ExtractedDocument(status="READY", pages=[(None, text)])

    if extension == ".docx":
        try:
            import docx

            doc = docx.Document(BytesIO(content))
            paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
            for table in doc.tables:
                for row in table.rows:
                    row_text = " | ".join(cell.text.strip() for cell in row.cells if cell.text.strip())
                    if row_text:
                        paragraphs.append(row_text)

            full_text = normalize_text("\n\n".join(paragraphs))
            if not full_text:
                return ExtractedDocument(status="FAILED", pages=[])
            return ExtractedDocument(status="READY", pages=[(None, full_text)])
        except Exception as error:
            raise ValueError("The DOCX document could not be read") from error

    raise UnsupportedDocumentType("Supported document types are PDF, DOCX, TXT, and Markdown")