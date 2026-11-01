---
subject: biology
lesson_id: biology.what_is_life_and_its_origin
level: intermediate
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Что такое жизнь и как она могла возникнуть / What Is Life and How It Might Have Begun

## Русский

### Цель

Назвать, что отличает живую систему от неживой, связать это с идеей «мира РНК» и протоклетки и объяснить порог ошибок: почему ранняя жизнь не могла хранить длинную наследственную информацию, пока не научилась копировать её точно.

### Идея и механизм

Единого бесспорного определения жизни нет, но у всех известных живых систем есть три общие черты. Первая — граница: мембрана отделяет «себя» от среды. Вторая — обмен веществ: система использует энергию и вещества, чтобы поддерживать и строить себя. Третья — наследственность с изменчивостью: информация копируется, копии немного различаются, и потому возможен естественный отбор. Шостак, Бартел и Луизи описали простейшую такую систему — протоклетку: самокопирующаяся молекула внутри самовоспроизводящегося мембранного пузырька.

Как жизнь возникла, точно не известно — это открытый научный вопрос. Но часть шагов проверена опытом. В 1953 году Стэнли Миллер пропускал электрические разряды через смесь газов, которую тогда считали похожей на древнюю атмосферу, и получил аминокислоты — строительные блоки белков — без участия живых организмов. Состав древней атмосферы сейчас оценивают иначе, но опыт показал главное: такие молекулы могут возникать сами. Идею, что первой была РНК, обсуждают с 1960-х годов, а в 1986 году Уолтер Гилберт дал ей имя — «мир РНК»: РНК умеет и хранить информацию, как ДНК, и ускорять реакции, как белок, поэтому ранняя жизнь могла обходиться одной РНК. Самые древние надёжные следы жизни — слоистые постройки микробов, строматолиты, — найдены в породах возрастом около 3,4 млрд лет; более ранние находки пока спорны.

Здесь есть ловушка, которую в 1971 году описал Манфред Эйген, — порог ошибок. Пусть молекула из L «букв» копирует каждую букву с ошибкой e. Тогда вся копия получается точной с вероятностью (1 − e)ᴸ, и эта вероятность падает с длиной. Если правильная молекула размножается в σ раз быстрее испорченных копий, она удерживается в популяции, только пока σ · (1 − e)ᴸ > 1. Иначе ошибки накапливаются, и информация стирается. Значит, длина «генома» ограничена точностью копирования: чтобы хранить больше, жизнь должна была копировать точнее — так в клетках появились ферменты, которые проверяют и исправляют копии.

Сегодня люди уже умеют собирать часть живого с нуля. В 2010 году команда Гибсона химически синтезировала геном бактерии и пересадила его в клетку другого вида — клетка стала работать по синтетическому геному. В 2016 году команда Хатчисона создала бактерию с минимальным геномом из 473 генов. Но в обоих случаях готовая клетка была взята у живого организма. Ближе всего к сборке с нуля подошла SpudCell: в июле 2026 года группа Катажины Адамалы сообщила в препринте, ещё не прошедшем рецензирование, о липидном пузырьке с геномом около 90 тысяч букв и очищенными ферментами, который растёт, копирует ДНК и делится. Но рибосомы и пищу ему дают исследователи, ферменты получены в основном из кишечной палочки, а примерно через 5–10 делений он останавливается, потому что не умеет строить новые рибосомы. Собрать из неживых молекул клетку, которая живёт сама, пока не удалось никому.

### Исследуй и потренируйся

В тренажёре задай длину молекулы, частоту ошибки на одну букву и преимущество правильной молекулы σ. Начни с длины 100 букв, ошибки 1 % и σ = 10: выживает ли информация? Увеличивай длину и найди, где она начинает стираться. Затем уменьши ошибку до 0,1 % и проверь, во сколько раз выросла допустимая длина.

### Вопрос

Молекула из 300 букв копирует каждую букву с ошибкой 1 %, а правильная молекула размножается в 10 раз быстрее испорченных копий. Сохранится ли её информация в модели урока?

### Варианты

- Нет: точная копия выходит с вероятностью 0,99³⁰⁰ ≈ 0,049, а 10 · 0,049 ≈ 0,49 меньше 1.
- Да: 99 % букв копируются верно, этого достаточно.
- Да: длина молекулы не влияет на точность копии.

### Ответ

1

### Разбор

Важна точность копии целиком, а не отдельной буквы. Из 300 букв хотя бы одна почти наверняка скопируется с ошибкой: точная копия выходит лишь примерно в 4,9 % случаев. Даже десятикратное преимущество даёт 10 · 0,049 ≈ 0,49 точных потомков на одну молекулу — меньше одного, поэтому правильный вариант вытесняется ошибками. При ошибке 1 % и σ = 10 предельная длина — 229 букв. Чтобы хранить длинный геном, нужна более точная копировальная машина.

### Границы модели

Это упрощённая модель Эйгена с условными числами. Она считает, что все испорченные копии одинаково хуже правильной и никогда не превращаются обратно в правильную; не учитывает безвредные мутации, размер популяции, обмен участками между молекулами и среду. Реальная точность первых самокопирующихся молекул неизвестна. Модель объясняет, почему точность копирования ограничивает объём наследственной информации, но не показывает, как именно возникла жизнь, — это остаётся открытым вопросом, а сознание эта модель не описывает вовсе.

## English

### Goal

Name what sets a living system apart from a non-living one, connect it to the RNA-world and protocell ideas, and explain the error threshold: why early life could not keep long hereditary information until it learned to copy it accurately.

### Idea and mechanism

There is no single undisputed definition of life, but every known living system shares three features. First, a boundary: a membrane separates "self" from the surroundings. Second, metabolism: the system uses energy and matter to maintain and build itself. Third, heredity with variation: information is copied, the copies differ slightly, and so natural selection becomes possible. Szostak, Bartel, and Luisi described the simplest such system, a protocell: a self-replicating molecule inside a self-reproducing membrane vesicle.

How life began is not known for certain; it is an open scientific question. But some steps have been tested by experiment. In 1953 Stanley Miller passed electric sparks through a gas mixture then thought to resemble the early atmosphere and obtained amino acids, the building blocks of proteins, without any living organism. Estimates of the early atmosphere have since changed, but the experiment showed the key point: such molecules can form on their own. The idea that RNA came first has been discussed since the 1960s, and in 1986 Walter Gilbert named it the "RNA world": RNA can both store information, like DNA, and speed up reactions, like a protein, so early life might have run on RNA alone. The oldest reliable traces of life are layered microbial structures, stromatolites, in rocks about 3.4 billion years old; older finds are still debated.

There is a trap here, described by Manfred Eigen in 1971: the error threshold. Suppose a molecule of L "letters" copies each letter with error rate e. Then a whole copy is exact with probability (1 − e)ᴸ, and this probability falls with length. If the correct molecule multiplies σ times faster than faulty copies, it stays in the population only while σ · (1 − e)ᴸ > 1. Otherwise errors pile up and the information is erased. So the length of a "genome" is limited by copying accuracy: to store more, life had to copy more accurately, and cells came to have enzymes that check and correct copies.

Today people can already build part of a living thing from scratch. In 2010 Gibson's team chemically synthesized a bacterial genome and transplanted it into a cell of another species; the cell came to run on the synthetic genome. In 2016 Hutchison's team made a bacterium with a minimal genome of 473 genes. In both cases, though, the recipient cell came from a living organism. The closest to building from scratch is SpudCell: in July 2026 Katarzyna Adamala's group reported, in a preprint not yet peer reviewed, a lipid vesicle with a genome of about 90,000 letters and purified enzymes that grows, copies its DNA, and divides. But the researchers supply its ribosomes and food, the enzymes come mostly from E. coli, and after roughly 5–10 divisions it stops because it cannot build new ribosomes. So no one has yet built a living cell from non-living molecules that can keep itself going.

### Explore and practise

In the lab, set the molecule length, the error rate per letter, and the advantage σ of the correct molecule. Start with 100 letters, a 1% error rate, and σ = 10: does the information survive? Increase the length and find where it starts to be erased. Then lower the error rate to 0.1% and check how many times longer the molecule can now be.

### Question

A molecule of 300 letters copies each letter with a 1% error rate, and the correct molecule multiplies 10 times faster than faulty copies. Does its information survive in the lesson model?

### Options

- No: an exact copy comes out with probability 0.99³⁰⁰ ≈ 0.049, and 10 · 0.049 ≈ 0.49 is less than 1.
- Yes: 99% of letters are copied correctly, which is enough.
- Yes: the length of the molecule does not affect copy accuracy.

### Answer

1

### Explanation

What matters is the accuracy of the whole copy, not of a single letter. Out of 300 letters at least one is almost certain to be copied wrongly: an exact copy comes out only about 4.9% of the time. Even a tenfold advantage gives 10 · 0.049 ≈ 0.49 exact offspring per molecule, fewer than one, so the correct version is pushed out by errors. With a 1% error rate and σ = 10 the length limit is 229 letters. Keeping a long genome requires a more accurate copying machine.

### Limits

This is a simplified version of Eigen's model with illustrative numbers. It assumes that all faulty copies are equally worse than the correct one and never turn back into it; it ignores harmless mutations, population size, exchange of segments between molecules, and the environment. The real accuracy of the first self-copying molecules is unknown. The model explains why copying accuracy limits the amount of hereditary information, but it does not show how life actually began, which remains an open question, and it says nothing about consciousness.

## Sources

- Jack W. Szostak, David P. Bartel, P. Luigi Luisi, “Synthesizing life”, *Nature* 409, 387–390 (2001), checked via Crossref 2026-10-26: a protocell as a self-replicating genome inside a self-reproducing membrane compartment: [doi:10.1038/35053176](https://doi.org/10.1038/35053176)
- Stanley L. Miller, “A Production of Amino Acids Under Possible Primitive Earth Conditions”, *Science* 117, 528–529 (1953), checked via Crossref 2026-10-26: amino acids formed by electric discharges in a gas mixture without living organisms: [doi:10.1126/science.117.3046.528](https://doi.org/10.1126/science.117.3046.528)
- Walter Gilbert, “Origin of life: The RNA world”, *Nature* 319, 618 (1986), checked via Crossref 2026-10-26: RNA as both information carrier and catalyst in early life: [doi:10.1038/319618a0](https://doi.org/10.1038/319618a0)
- Abigail C. Allwood et al., “Stromatolite reef from the Early Archaean era of Australia”, *Nature* 441, 714–718 (2006), checked via Crossref 2026-10-26: stromatolites about 3.4 billion years old as evidence of early life: [doi:10.1038/nature04764](https://doi.org/10.1038/nature04764)
- Manfred Eigen, “Selforganization of matter and the evolution of biological macromolecules”, *Die Naturwissenschaften* 58, 465–523 (1971), checked via Crossref 2026-10-26: the error threshold linking copying accuracy, selective advantage, and the maximum length of hereditary information: [doi:10.1007/BF00623322](https://doi.org/10.1007/BF00623322)
- Daniel G. Gibson et al., “Creation of a Bacterial Cell Controlled by a Chemically Synthesized Genome”, *Science* 329, 52–56 (2010), checked via Crossref 2026-10-26: a synthesized genome transplanted into a recipient cell of another species: [doi:10.1126/science.1190719](https://doi.org/10.1126/science.1190719)
- Clyde A. Hutchison III et al., “Design and synthesis of a minimal bacterial genome”, *Science* 351, aad6253 (2016), checked via Crossref 2026-10-26: a bacterium with a minimal synthetic genome of 473 genes: [doi:10.1126/science.aad6253](https://doi.org/10.1126/science.aad6253)
- Marc Neveu, Hyo-Joong Kim, Steven A. Benner, “The ‘strong’ RNA world hypothesis: fifty years old”, *Astrobiology* 13, 391–403 (2013), abstract read 2026-11-01: Alex Rich proposed about fifty years earlier that RNA might have served both genetics and catalysis: [doi:10.1089/ast.2012.0868](https://doi.org/10.1089/ast.2012.0868)
- Nathaniel J. Gaut, …, Katarzyna P. Adamala, “A Chemically Defined Synthetic Cell Capable Of Growth And Replication”, bioRxiv preprint, not peer reviewed (consulted 2026-11-01): a synthetic cell with a genome of about 90 kb and a cell cycle of DNA replication, growth, feeding, and division: [bioRxiv](https://www.biorxiv.org/content/10.64898/2026.07.01.735724v1)
- Singularity Hub, “This Synthetic Cell Grows, Copies Its DNA, and Produces Offspring — But It Isn't Alive” (2026-07-09, consulted 2026-11-01): 36 purified enzymes largely from *E. coli*, ribosomes and food supplied by the researchers, and a limit of five to ten divisions: [Singularity Hub](https://singularityhub.com/2026/07/09/this-synthetic-cell-grows-copies-its-dna-and-produces-offspring-but-it-isnt-alive/)
- The lesson paraphrases these publications and does not copy their text.
