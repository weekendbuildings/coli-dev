"""Собери и проверь сам: токенизатор BPE / Build and check it yourself: a BPE tokenizer.

Урок: «Свой токенизатор BPE» (tokenizer_bpe). Обучение и декодирование готовы, они
опираются на твои функции. Допиши count_pairs, merge и encode. Проверка:
    python3 01_Projects/creator_labs/check_tokenizer_bpe.py
Lesson: tokenizer_bpe. Training and decoding are done and rely on your functions.
Fill in count_pairs, merge and encode.

Токены это целые числа: 0–255 это байты UTF-8, дальше новые токены из слияний.
Tokens are integers: 0–255 are UTF-8 bytes, higher ids come from merges.
"""


def count_pairs(ids):
    """Сколько раз каждая соседняя пара встречается в списке: {(a, b): число}.
    Пары считаются по порядку их первого появления. / Count each adjacent pair, in order of first appearance.
    """
    raise NotImplementedError("count_pairs")


def merge(ids, pair, new):
    """Заменить каждое вхождение пары на new, слева направо, без перекрытий.
    Например merge([1, 1, 1], (1, 1), 9) == [9, 1]. Входной список не менять.
    Replace every occurrence left to right without overlaps; do not modify the input list.
    """
    raise NotImplementedError("merge")


def train(text, vocab_size):
    """Готово. Учит слияния, пока словарь не дорастёт до vocab_size. / Done."""
    ids = list(text.encode("utf-8"))
    merges, vocab = {}, {i: bytes([i]) for i in range(256)}
    while len(vocab) < vocab_size:
        counts = count_pairs(ids)
        if not counts:
            break
        pair = max(counts, key=counts.get)
        if counts[pair] < 2:
            break
        new = len(vocab)
        ids = merge(ids, pair, new)
        merges[pair] = new
        vocab[new] = vocab[pair[0]] + vocab[pair[1]]
    return merges, vocab, ids


def encode(text, merges):
    """Текст → токены: байты UTF-8, затем выученные слияния в том порядке, в каком они выучены
    (у раннего слияния номер меньше). Text → tokens: UTF-8 bytes, then learned merges in learned order.
    """
    raise NotImplementedError("encode")


def decode(ids, vocab):
    """Готово. / Done."""
    return b"".join(vocab[i] for i in ids).decode("utf-8", "replace")
