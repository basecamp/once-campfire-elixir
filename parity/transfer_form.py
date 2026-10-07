"""Compare the one deliberate closing tag added to the frozen transfer template."""
import re


def canonical_transfer_form(body, native):
    forms = re.findall(r"<form\b[^>]*>", body)
    targets = [form for form in forms if 'data-controller="auto-submit"' in form and
               re.search(r'action="(?:https?://[^"/]+)?/session/transfers/[^"<>]+"', form)]
    assert len(targets) == 1, "transfer page must have exactly one auto-submit form"
    assert re.search(r'<input\b(?=[^>]*\bname="_method")(?=[^>]*\bvalue="put")[^>]*>', body)
    assert body.count("</form>") == len(forms) - (0 if native else 1)
    if native:
        start = body.index(targets[0]) + len(targets[0])
        fields = re.match(r'(?:\s*<input\b[^>]*>)*\s*</form>', body[start:])
        assert fields, "auto-submit form must close after its hidden fields"
        end = start + fields.end()
        return body[:end - len("</form>")] + body[end:]
    return body
