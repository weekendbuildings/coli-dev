"""Строгая проверка: токенизатор BPE / Strict check: BPE tokenizer.

python3 01_Projects/creator_labs/check_tokenizer_bpe.py [твой_файл.py]
"""

from _checklib import Checker, Rand

checker = Checker("Токенизатор BPE", "BPE tokenizer")
lab = checker.load("tokenizer_blank.py")
rand = Rand(5)

TRAINING_TEXT = (
    "Модель читает токены, а не буквы. Модель учится по тексту. "
    "The model reads tokens, not letters. The model learns from text. "
) * 6


def pairs_basic():
    got = lab.count_pairs([1, 2, 1, 2])
    if got != {(1, 2): 2, (2, 1): 1}:
        return f"count_pairs([1, 2, 1, 2]) = {got}, ждали {{(1, 2): 2, (2, 1): 1}}"
    if list(lab.count_pairs([5, 6, 5, 6, 7])) != [(5, 6), (6, 5), (6, 7)]:
        return "пары должны идти в порядке первого появления: от этого зависит выбор при равенстве"
    return None


def pairs_short():
    if lab.count_pairs([]) != {} or lab.count_pairs([3]) != {}:
        return "в пустом списке и в списке из одного токена пар нет"
    return None


def merge_no_overlap():
    cases = [
        ([1, 1, 1], (1, 1), 9, [9, 1]),
        ([1, 1, 1, 1], (1, 1), 9, [9, 9]),
        ([1, 2, 3, 1, 2], (1, 2), 7, [7, 3, 7]),
        ([4, 5, 6], (6, 4), 8, [4, 5, 6]),
        ([], (1, 2), 3, []),
    ]
    for ids, pair, new, want in cases:
        original = list(ids)
        got = lab.merge(ids, pair, new)
        if got != want:
            return f"merge({original}, {pair}, {new}) = {got}, ждали {want}"
        if ids != original:
            return "merge изменил входной список"
    return None


def round_trip():
    merges, vocab, _ = lab.train(TRAINING_TEXT, 320)
    samples = ["Модель читает", "The model", "привет, мир 🙂", "", "ааааааа", "tokens tokens tokens"]
    alphabet = "абвгдеёжз ABCxyz.,!?🙂"
    samples += ["".join(alphabet[rand.below(len(alphabet))] for _ in range(rand.below(30))) for _ in range(30)]
    for text in samples:
        ids = lab.encode(text, merges)
        if lab.decode(ids, vocab) != text:
            return f"decode(encode({text!r})) вернул {lab.decode(ids, vocab)!r}"
    return None


def same_as_training():
    merges, _, trained_ids = lab.train(TRAINING_TEXT, 320)
    got = lab.encode(TRAINING_TEXT, merges)
    if got != trained_ids:
        return f"на тексте обучения encode дал {len(got)} токенов, а обучение {len(trained_ids)}: слияния применены не в том порядке"
    return None


def never_longer():
    merges, _, _ = lab.train(TRAINING_TEXT, 320)
    for text in ("Модель учится", "xyz", "The model reads tokens"):
        if len(lab.encode(text, merges)) > len(text.encode("utf-8")):
            return f"токенов для {text!r} больше, чем байтов"
    if lab.encode("abc", {}) != [97, 98, 99]:
        return "без слияний encode должен вернуть байты UTF-8"
    return None


def merges_compress():
    merges, _, ids = lab.train(TRAINING_TEXT, 320)
    raw = len(TRAINING_TEXT.encode("utf-8"))
    if len(merges) < 30:
        return f"выучено только {len(merges)} слияний: count_pairs или merge теряют пары"
    if not len(ids) < raw * 0.6:
        return f"после {len(merges)} слияний осталось {len(ids)} токенов из {raw} байтов: сжатие слишком слабое"
    return None


checker.check("count_pairs считает пары по порядку", "count_pairs counts pairs in order", pairs_basic)
checker.check("короткие списки без пар", "short lists have no pairs", pairs_short)
checker.check("merge без перекрытий и не портит вход", "merge without overlaps, input untouched", merge_no_overlap)
checker.check("encode → decode возвращает тот же текст", "encode → decode returns the same text", round_trip)
checker.check("encode повторяет обучение", "encode reproduces training", same_as_training)
checker.check("токенов не больше, чем байтов", "never more tokens than bytes", never_longer)
checker.check("слияния действительно сжимают текст", "merges really compress the text", merges_compress)
checker.finish()
