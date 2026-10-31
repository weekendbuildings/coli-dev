---
subject: biology
lesson_id: biology.sequence_comparison_hamming_distance
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Биоинформатика: сравнение последовательностей ДНК / Bioinformatics: Comparing DNA Sequences

## Русский

### Цель

Сравнивать две выровненные последовательности ДНК программой на Python, считать расстояние Хэмминга и процент совпадения и понимать, как такие сравнения помогают строить древо жизни.

### Идея и механизм

Последовательность ДНК можно записать строкой из четырёх букв — A, T, G и C. Молекулярная систематика сравнивает такие строки, чтобы понять родство организмов: чем меньше различий в соответствующих участках, тем, как правило, недавнее общий предок.

Простейшая мера различия — расстояние Хэмминга: число позиций, в которых две строки одинаковой длины не совпадают. Эту меру ввёл Ричард Хэмминг в 1950 году для кодов, которые находят и исправляют ошибки при передаче данных, — тот же вопрос, что и точность копирования ДНК. Процент совпадения считают так: (длина − расстояние) / длина · 100 %.

```python
def hamming(a, b):
    if len(a) != len(b):
        raise ValueError("sequences must have the same length")
    return sum(1 for x, y in zip(a, b) if x != y)

first = "ATGCCGTA"
second = "ATGACGTT"
distance = hamming(first, second)
identity = (len(first) - distance) / len(first) * 100
print(distance, identity)
```

Программа печатает 2 и 75.0: строки расходятся в двух позициях из восьми.

### Исследуй и потренируйся

Добавь третью последовательность "ATGACGTA" и посчитай расстояния для всех трёх пар. Какие две последовательности ближе всего? Нарисуй по этим расстояниям простое дерево вида ((X, Y), Z). Затем проверь, что функция сообщает об ошибке для строк разной длины.

### Вопрос

Последовательности "ATGCCGTA" и "ATGACGTT" выровнены и имеют одинаковую длину. Каковы расстояние Хэмминга и процент совпадения?

### Варианты

- 2 и 75 %: отличаются позиции 4 (C/A) и 8 (A/T), (8 − 2) / 8 = 75 %.
- 6 и 25 %: расстояние — это число совпадающих позиций.
- 1 и 87,5 %: две замены считаются одной, потому что это одна пара строк.

### Ответ

1

### Разбор

Сравниваем позиции по очереди: A=A, T=T, G=G, C≠A, C=C, G=G, T=T, A≠T. Несовпадений два, значит расстояние Хэмминга 2, а совпадает (8 − 2) / 8 = 75 % позиций. Число совпадающих позиций (6) — это не расстояние, а его противоположность.

### Границы модели

Расстояние Хэмминга работает только для строк одинаковой длины, уже выровненных друг против друга. В настоящих геномах бывают вставки и удаления букв, поэтому сначала нужно выравнивание — отдельная задача со своими алгоритмами. Одно расстояние по короткому участку не доказывает родство: деревья строят по многим участкам и проверяют как гипотезы.

## English

### Goal

Compare two aligned DNA sequences with a Python program, compute the Hamming distance and percent identity, and understand how such comparisons help build the tree of life.

### Idea and mechanism

A DNA sequence can be written as a string of four letters: A, T, G, and C. Molecular systematics compares such strings to understand how organisms are related: the fewer differences in corresponding regions, the more recent, as a rule, the common ancestor.

The simplest measure of difference is the Hamming distance: the number of positions at which two strings of equal length differ. Richard Hamming introduced this measure in 1950 for codes that detect and correct errors in transmitted data, the same question as the accuracy of DNA copying. Percent identity is computed as (length − distance) / length · 100%.

```python
def hamming(a, b):
    if len(a) != len(b):
        raise ValueError("sequences must have the same length")
    return sum(1 for x, y in zip(a, b) if x != y)

first = "ATGCCGTA"
second = "ATGACGTT"
distance = hamming(first, second)
identity = (len(first) - distance) / len(first) * 100
print(distance, identity)
```

The program prints 2 and 75.0: the strings differ in two of eight positions.

### Explore and practise

Add a third sequence, "ATGACGTA", and compute the distances for all three pairs. Which two sequences are closest? Draw a simple tree of the form ((X, Y), Z) from these distances. Then check that the function reports an error for strings of different lengths.

### Question

The sequences "ATGCCGTA" and "ATGACGTT" are aligned and have the same length. What are the Hamming distance and percent identity?

### Options

- 2 and 75%: positions 4 (C/A) and 8 (A/T) differ, (8 − 2) / 8 = 75%.
- 6 and 25%: the distance is the number of matching positions.
- 1 and 87.5%: two substitutions count as one, because it is one pair of strings.

### Answer

1

### Explanation

Compare positions one by one: A=A, T=T, G=G, C≠A, C=C, G=G, T=T, A≠T. There are two mismatches, so the Hamming distance is 2, and (8 − 2) / 8 = 75% of positions match. The number of matching positions (6) is not the distance but its opposite.

### Limits

The Hamming distance works only for strings of equal length that are already aligned against each other. Real genomes contain insertions and deletions of letters, so alignment comes first, a separate problem with its own algorithms. A single distance over a short region does not prove relationship: trees are built from many regions and tested as hypotheses.

## Sources

- Mary Ann Clark, Matthew Douglas, Jung Choi, *Biology 2e*, OpenStax, 2018, section 20.2 “Determining Evolutionary Relationships” (consulted 2026-10-31): molecular systematics as the use of molecular data from DNA technology to determine evolutionary relationships: [OpenStax Biology 2e, 20.2](https://openstax.org/books/biology-2e/pages/20-2-determining-evolutionary-relationships)
- Richard W. Hamming, “Error Detecting and Error Correcting Codes”, *Bell System Technical Journal* 29, 147–160 (1950), checked via Crossref 2026-10-31: [doi:10.1002/j.1538-7305.1950.tb00463.x](https://doi.org/10.1002/j.1538-7305.1950.tb00463.x)
- Mary Ann Clark, Matthew Douglas, Jung Choi, *Biology 2e*, OpenStax, 2018, section 20.1 “Organizing Life on Earth” (consulted 2026-10-31): phylogenetic trees as hypotheses: [OpenStax Biology 2e, 20.1](https://openstax.org/books/biology-2e/pages/20-1-organizing-life-on-earth)
- The lesson paraphrases these sources and does not copy their text; the OpenStax pages state their own license terms: [OpenStax terms of use](https://openstax.org/terms-of-use)
