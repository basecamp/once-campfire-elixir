"""Compare every search-result byte while allowing the documented insertion-ID order."""
from html.parser import HTMLParser


def canonical_message_order(body):
    offsets = [0]
    for line in body.splitlines(keepends=True):
        offsets.append(offsets[-1] + len(line))

    class Messages(HTMLParser):
        def __init__(self):
            super().__init__(convert_charrefs=False)
            self.depth = 0
            self.active = None
            self.blocks = []

        def source_position(self):
            line, column = self.getpos()
            return offsets[line - 1] + column

        def handle_starttag(self, tag, attrs):
            if tag == 'div':
                message_id = dict(attrs).get('data-message-id')
                if message_id is not None:
                    assert self.active is None, 'nested message results'
                    self.active = (int(message_id), self.source_position(), self.depth)
                self.depth += 1

        def handle_endtag(self, tag):
            if tag == 'div':
                self.depth -= 1
                if self.active and self.active[2] == self.depth:
                    message_id, start, _ = self.active
                    end = body.index('>', self.source_position()) + 1
                    self.blocks.append((message_id, start, end))
                    self.active = None

    parser = Messages()
    parser.feed(body)
    assert parser.active is None, 'incomplete message result'
    blocks = parser.blocks
    assert len({message_id for message_id, _, _ in blocks}) == len(blocks), 'duplicate message results'
    sorted_blocks = sorted(blocks)
    pieces = []
    previous = 0
    for (_, start, end), (_, sorted_start, sorted_end) in zip(blocks, sorted_blocks):
        pieces.extend([body[previous:start], body[sorted_start:sorted_end]])
        previous = end
    pieces.append(body[previous:])
    return ''.join(pieces)
