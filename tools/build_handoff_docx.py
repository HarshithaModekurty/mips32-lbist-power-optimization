"""Build a native Word handoff from Markdown without third-party dependencies."""
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


def build():
    paragraphs = []
    pending = []

    def emit(text, style='Normal'):
        paragraphs.append(
            '<w:p><w:pPr><w:pStyle w:val="' + style + '"/></w:pPr>'
            '<w:r><w:t xml:space="preserve">' + escape(text) + '</w:t></w:r></w:p>')

    def flush():
        if pending:
            emit(' '.join(pending))
            pending.clear()

    for line in (ROOT / 'docs/MEMBER1_HANDOFF.md').read_text(encoding='utf-8').splitlines():
        if not line.strip():
            flush()
        elif line.startswith('# '):
            flush(); emit(line[2:], 'Title')
        elif line.startswith('## '):
            flush(); emit(line[3:], 'Heading1')
        elif line.startswith('- ') or (len(line) > 2 and line[0].isdigit() and line[1:3] == '. '):
            flush(); pending.append(line)
        else:
            pending.append(line)
    flush()
    document = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
                '<w:body>' + ''.join(paragraphs) +
                '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
                '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>'
                '</w:sectPr></w:body></w:document>')
    styles = '''<?xml version="1.0" encoding="UTF-8"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/>
<w:pPr><w:spacing w:after="140"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
</w:styles>'''
    types = '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>'''
    relationships = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''
    doc_rels = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>'''
    target = ROOT / 'docs/MEMBER1_HANDOFF.docx'
    with ZipFile(target, 'w', ZIP_DEFLATED) as archive:
        for name, text in {'[Content_Types].xml': types, '_rels/.rels': relationships,
                           'word/document.xml': document, 'word/styles.xml': styles,
                           'word/_rels/document.xml.rels': doc_rels}.items():
            archive.writestr(name, text.encode('utf-8'))
    print('Wrote docs/MEMBER1_HANDOFF.docx')


if __name__ == '__main__':
    build()
