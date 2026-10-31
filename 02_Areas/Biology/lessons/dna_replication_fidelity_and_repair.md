---
subject: biology
lesson_id: biology.dna_replication_fidelity_and_repair
level: advanced
languages: ru, en
source_checked: 2026-10-27
source_review_interval_days: 365
---

# Точность копирования ДНК и её починка / DNA Replication Fidelity and Repair

## Русский

### Цель

Объяснить, как клетка копирует ДНК почти без ошибок — за счёт корректуры и исправления неспаренных оснований — и по порогу ошибок Эйгена оценить, какой длины геном позволяет такая точность.

### Идея и механизм

В уроке «Что такое жизнь» был порог ошибок: если каждая буква копируется с ошибкой e, а правильная молекула размножается в σ раз быстрее испорченных, информация сохраняется, пока σ · (1 − e)ᴸ > 1. При ошибке 1 % и σ = 10 предел — всего 229 букв. Значит, чтобы хранить много генов, жизнь должна была научиться копировать намного точнее.

Клетка делает это в несколько ступеней. Первая — корректура: ДНК-полимераза проверяет только что добавленное основание, прежде чем присоединить следующее, и если оно неверное, вырезает его и ставит правильное. Большинство ошибок исправляется прямо во время копирования. Вторая — исправление неспаренных оснований (mismatch repair) после копирования: особые ферменты находят неправильно спаренный нуклеотид, вырезают участок цепи с ним и достраивают его заново. В итоге ДНК-полимераза ошибается примерно в одном основании на миллиард скопированных.

Подставим это в формулу Эйгена: при e = 10⁻⁹ и σ = 10 предельная длина L ≈ ln 10 / 10⁻⁹ ≈ 2,3 миллиарда букв. Точность копирования открыла дорогу большим геномам, а значит, и сложным организмам.

### Исследуй и потренируйся

Посчитай предельную длину по формуле L ≈ ln σ / e при σ = 10 для ошибки 10⁻⁴ и 10⁻⁶. Во сколько раз растёт предел, когда ошибка уменьшается в 100 раз? Проверь первое значение в тренажёре порога ошибок из урока «Что такое жизнь».

### Вопрос

ДНК-полимераза ошибается примерно в одном основании на миллиард (e = 10⁻⁹). Какую наибольшую длину генома допускает порог Эйгена при σ = 10?

### Варианты

- Около 2,3 миллиарда букв: L ≈ ln 10 / 10⁻⁹ ≈ 2,3 · 10⁹.
- Около 229 букв, как при ошибке 1 %.
- Любую: при такой точности ошибок не бывает вовсе.

### Ответ

1

### Разбор

Для маленькой ошибки ln(1 − e) ≈ −e, поэтому условие σ · (1 − e)ᴸ > 1 даёт L < ln σ / e. При σ = 10 и e = 10⁻⁹ получаем L ≈ 2,3 / 10⁻⁹ ≈ 2,3 миллиарда. Предел 229 букв относится к ошибке 1 %. А ошибки при такой точности всё же случаются — примерно одна на миллиард, — поэтому предел конечен.

### Границы модели

Порог Эйгена — упрощённая модель; реальные геномы содержат участки, где ошибки безвредны, а отбор и рекомбинация работают сложнее. Частота одна на миллиард — обобщённое значение; у разных организмов и полимераз она различается, а мутации вызывают ещё и внешние факторы. Урок не касается болезней, связанных с мутациями: об этом судят врачи и генетики.

## English

### Goal

Explain how a cell copies DNA with almost no errors, through proofreading and mismatch repair, and use Eigen's error threshold to estimate how long a genome such accuracy allows.

### Idea and mechanism

The lesson "What life is" introduced the error threshold: if each letter is copied with error e and the correct molecule multiplies σ times faster than faulty ones, the information survives while σ · (1 − e)ᴸ > 1. With a 1% error and σ = 10 the limit is only 229 letters. So to store many genes, life had to learn to copy far more accurately.

A cell does this in several stages. The first is proofreading: DNA polymerase checks the base it has just added before attaching the next one, and if it is wrong, it cuts it out and inserts the right one. Most errors are corrected during copying itself. The second is mismatch repair after copying: special enzymes find a mispaired nucleotide, cut out the stretch of strand containing it, and rebuild it. In the end DNA polymerase makes about one error per billion bases copied.

Put this into Eigen's formula: with e = 10⁻⁹ and σ = 10, the length limit is L ≈ ln 10 / 10⁻⁹ ≈ 2.3 billion letters. Copying accuracy opened the way to large genomes, and so to complex organisms.

### Explore and practise

Calculate the length limit with L ≈ ln σ / e at σ = 10 for errors of 10⁻⁴ and 10⁻⁶. By how much does the limit grow when the error falls 100-fold? Check the first value in the error threshold lab from the lesson "What life is".

### Question

DNA polymerase makes about one error per billion bases (e = 10⁻⁹). What is the largest genome length Eigen's threshold allows at σ = 10?

### Options

- About 2.3 billion letters: L ≈ ln 10 / 10⁻⁹ ≈ 2.3 · 10⁹.
- About 229 letters, as with a 1% error.
- Any length: with such accuracy there are no errors at all.

### Answer

1

### Explanation

For a small error ln(1 − e) ≈ −e, so the condition σ · (1 − e)ᴸ > 1 gives L < ln σ / e. With σ = 10 and e = 10⁻⁹ we get L ≈ 2.3 / 10⁻⁹ ≈ 2.3 billion. The 229-letter limit belongs to a 1% error. And errors still happen at this accuracy, about one per billion, so the limit is finite.

### Limits

Eigen's threshold is a simplified model; real genomes have regions where errors are harmless, and selection and recombination work in more complex ways. The rate of one per billion is a general figure; it differs between organisms and polymerases, and mutations are also caused by outside factors. The lesson does not deal with diseases linked to mutations: doctors and geneticists judge those.

## Sources

- Mary Ann Clark, Matthew Douglas, Jung Choi, *Biology 2e*, OpenStax, 2018, section 14.6 “DNA Repair” (consulted 2026-10-27): proofreading by DNA polymerase, which reads the newly added base before adding the next one and corrects most replication errors, and mismatch repair after replication by enzymes that excise the strand containing the mispaired nucleotide: [OpenStax Biology 2e, 14.6](https://openstax.org/books/biology-2e/pages/14-6-dna-repair)
- Nina Parker, Mark Schneegurt, Anh-Hue Thi Tu, Philip Lister, Brian M. Forster, *Microbiology*, OpenStax, 2016, section 11.5 “Mutations” (consulted 2026-10-27): the error rate of DNA polymerase as one incorrect base per billion base pairs replicated: [OpenStax Microbiology, 11.5](https://openstax.org/books/microbiology/pages/11-5-mutations)
- Manfred Eigen, “Selforganization of matter and the evolution of biological macromolecules”, *Die Naturwissenschaften* 58, 465–523 (1971), checked via Crossref 2026-10-26: the error threshold: [doi:10.1007/BF00623322](https://doi.org/10.1007/BF00623322)
- The lesson paraphrases these sources and does not copy their text; the OpenStax pages state their own license terms: [OpenStax terms of use](https://openstax.org/terms-of-use)
