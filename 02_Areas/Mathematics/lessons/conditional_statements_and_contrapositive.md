---
subject: mathematics
lesson_id: mathematics.conditional_statements_and_contrapositive
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Логика: импликация, обратное и контрапозиция / Logic: Conditionals, Converses, and Contrapositives

## Русский

### Цель

Разбирать утверждения вида «если p, то q», строить к ним обратное, противоположное и контрапозицию, определять, какие из них равносильны исходному, и не попадаться на типичные ошибки рассуждения.

### Идея и механизм

Импликация «если p, то q» (p → q) похожа на обещание: она ложна только в одном случае — когда условие p выполнено, а следствие q нет, то есть обещание нарушено. Если p не выполнено, обещание не нарушено, и импликация считается истинной.

Из импликации можно получить три варианта. Обратное утверждение «если q, то p» меняет местами условие и следствие. Противоположное «если не p, то не q» отрицает оба. Контрапозиция «если не q, то не p» меняет их местами и отрицает. Важно: контрапозиция логически равносильна исходной импликации, а обратное равносильно противоположному — но не исходному.

Пример: «Если число делится на 4, то оно чётное» — истинно. Контрапозиция «если число нечётное, то оно не делится на 4» — тоже истинна. А обратное «если число чётное, то оно делится на 4» ложно: 6 чётное, но на 4 не делится. Путать импликацию с обратной — одна из самых частых ошибок в рассуждениях, в том числе в науке: из «если гипотеза верна, то мы увидим результат» не следует, что увиденный результат доказывает гипотезу.

### Исследуй и потренируйся

Для утверждения «если идёт дождь, то земля мокрая» запиши обратное, противоположное и контрапозицию. Какие из них могут быть ложными, даже если исходное истинно? Придумай пример, показывающий это. Затем составь таблицу истинности для p → q по всем четырём сочетаниям p и q.

### Вопрос

Какое утверждение логически равносильно утверждению «если число делится на 4, то оно чётное»?

### Варианты

- «Если число нечётное, то оно не делится на 4» — это контрапозиция.
- «Если число чётное, то оно делится на 4» — это обратное.
- «Если число не делится на 4, то оно нечётное» — это противоположное.

### Ответ

1

### Разбор

Контрапозиция «если не q, то не p» всегда равносильна исходной импликации. Обратное и противоположное между собой равносильны, но с исходным — нет: число 6 чётное и не делится на 4, а также не делится на 4 и при этом чётное, поэтому оба эти утверждения ложны.

### Границы модели

Урок описывает классическую логику высказываний, где каждое утверждение либо истинно, либо ложно. В жизни и науке утверждения часто вероятностные, а слова «если… то» в речи иногда означают причинность или ожидание, а не строгую импликацию. Логика проверяет, следует ли вывод из посылок, но не проверяет, верны ли сами посылки.

## English

### Goal

Analyse statements of the form "if p, then q", construct their converse, inverse, and contrapositive, determine which of them are equivalent to the original, and avoid typical reasoning errors.

### Idea and mechanism

A conditional "if p, then q" (p → q) is like a promise: it is false in only one case, when the condition p holds but the conclusion q does not, that is, when the promise is broken. If p does not hold, the promise is not broken, and the conditional counts as true.

Three variants can be formed from a conditional. The converse "if q, then p" swaps condition and conclusion. The inverse "if not p, then not q" negates both. The contrapositive "if not q, then not p" swaps and negates them. Crucially, the contrapositive is logically equivalent to the original conditional, and the converse is equivalent to the inverse, but not to the original.

Example: "If a number is divisible by 4, then it is even" is true. The contrapositive "if a number is odd, then it is not divisible by 4" is also true. But the converse "if a number is even, then it is divisible by 4" is false: 6 is even but not divisible by 4. Confusing a conditional with its converse is one of the most common reasoning errors, including in science: from "if the hypothesis is true, we will see the result" it does not follow that seeing the result proves the hypothesis.

### Explore and practise

For the statement "if it rains, the ground is wet", write the converse, inverse, and contrapositive. Which of them can be false even when the original is true? Find an example that shows this. Then build the truth table for p → q over all four combinations of p and q.

### Question

Which statement is logically equivalent to "if a number is divisible by 4, then it is even"?

### Options

- "If a number is odd, then it is not divisible by 4": the contrapositive.
- "If a number is even, then it is divisible by 4": the converse.
- "If a number is not divisible by 4, then it is odd": the inverse.

### Answer

1

### Explanation

The contrapositive "if not q, then not p" is always equivalent to the original conditional. The converse and inverse are equivalent to each other but not to the original: 6 is even and not divisible by 4, and also not divisible by 4 yet even, so both of those statements are false.

### Limits

The lesson covers classical propositional logic, where every statement is either true or false. In life and science statements are often probabilistic, and "if … then" in speech sometimes means causation or expectation rather than strict implication. Logic checks whether a conclusion follows from premises, but not whether the premises are true.

## Sources

- Donna Kirk et al., *Contemporary Mathematics*, OpenStax, 2023, section 2.4 “Truth Tables for the Conditional and Biconditional” (consulted 2026-10-31): the conditional as a promise that is false only when the promise is broken: [OpenStax Contemporary Mathematics, 2.4](https://openstax.org/books/contemporary-mathematics/pages/2-4-truth-tables-for-the-conditional-and-biconditional)
- *Contemporary Mathematics*, section 2.5 “Equivalent Statements” (consulted 2026-10-31): the converse, inverse, and contrapositive of a conditional; the contrapositive is logically equivalent to the conditional and the inverse to the converse: [OpenStax Contemporary Mathematics, 2.5](https://openstax.org/books/contemporary-mathematics/pages/2-5-equivalent-statements)
- The OpenStax pages state their own license terms; the lesson paraphrases the sections and does not copy their text: [OpenStax terms of use](https://openstax.org/terms-of-use)
