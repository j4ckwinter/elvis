struct ShellLine {
    struct Piece {
        var words: [String]
        var joiner: String
    }

    var pieces: [Piece]

    init(_ command: String) {
        var pieces: [Piece] = []
        var current = ""
        var quote: Character?
        let chars = Array(command)
        var i = 0
        func flush(_ joiner: String) {
            let words = current.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).map(String.init)
            if !words.isEmpty || !joiner.isEmpty { pieces.append(Piece(words: words, joiner: joiner)) }
            current = ""
        }
        while i < chars.count {
            let c = chars[i]
            if let q = quote {
                if c == q { quote = nil }
                current.append(c)
            } else if c == "\"" || c == "'" {
                quote = c
                current.append(c)
            } else if c == "\\", i + 1 < chars.count {
                current.append(chars[i + 1])
                i += 1
            } else if c == "&" || c == "|" {
                let isPartOfRedirect = c == "&" && (current.hasSuffix(">") || (i + 1 < chars.count && chars[i + 1] == ">"))
                if i + 1 < chars.count, chars[i + 1] == c {
                    flush(String([c, c]))
                    i += 1
                } else if isPartOfRedirect {
                    current.append(c)
                } else {
                    flush(String(c))
                }
            } else if c == ";" || c == "\n" {
                flush(";")
            } else {
                current.append(c)
            }
            i += 1
        }
        flush("")
        self.pieces = pieces.filter { !$0.words.isEmpty }
    }

    func hidesStatus(ofPieceAt index: Int) -> Bool {
        pieces[index...].dropLast().contains { $0.joiner != "&&" } || pieces.last?.joiner == "&"
    }
}
