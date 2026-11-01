---
subject: mathematics
lesson_id: mathematics.primes_gcd_and_clock_arithmetic
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Теория чисел: простые числа, НОД и арифметика остатков / Number Theory: Primes, GCD, and Clock Arithmetic

## Русский

### Цель

Отличать простые числа от составных, раскладывать число на простые множители, находить наибольший общий делитель по разложениям и считать время на циферблате через остаток от деления.

### Идея и механизм

Натуральное число больше 1 называют простым, если у него нет делителей, кроме 1 и самого себя, и составным, если такие делители есть. Например, 13 — простое, а 12 = 2·2·3 — составное. Основная теорема арифметики говорит, что каждое натуральное число, кроме 1, раскладывается в произведение простых, и это разложение единственно с точностью до порядка множителей. Простые числа — как атомы, из которых умножением собраны все остальные.

Наибольший общий делитель (НОД) двух чисел — самое большое число, на которое делятся оба. Его можно найти по разложениям: берём простые множители, которые есть в каждом числе, с наименьшей степенью и перемножаем. Для 12 = 2²·3 и 18 = 2·3² это 2·3 = 6.

Арифметика остатков устроена как циферблат на 12 часов. Чтобы прибавить к времени много часов, делим добавку на 12 и прибавляем только остаток: полные круги стрелку не сдвигают. В Python остаток даёт оператор %.

```python
import math

def factorize(n):
    factors = []
    divisor = 2
    while divisor * divisor <= n:
        while n % divisor == 0:
            factors.append(divisor)
            n //= divisor
        divisor += 1
    if n > 1:
        factors.append(n)
    return factors

print(factorize(12), factorize(18), math.gcd(12, 18))
print((9 + 30) % 12)
```

Программа печатает [2, 2, 3] [2, 3, 3] 6 и затем 3: НОД по разложениям совпал с math.gcd, а через 30 часов после 9 часов на циферблате будет 3 часа — 30 часов это два полных круга и ещё 6 часов.

### Исследуй и потренируйся

Разложи 24 и 36 на простые множители вручную, затем проверь функцией factorize. Найди их НОД по разложениям и сравни с math.gcd. После этого посчитай, сколько будет на циферблате через 100 часов после 7 часов, и подумай, что означает результат 0.

### Вопрос

Чему равен наибольший общий делитель чисел 24 и 36?

### Варианты

- 12: 24 = 2³·3 и 36 = 2²·3², общие множители с наименьшими степенями дают 2²·3.
- 6: это общий делитель, значит, он и наибольший.
- 72: это наименьшее число, которое делится на оба.

### Ответ

1

### Разбор

В обоих разложениях есть 2 и 3. Наименьшая степень двойки — 2², тройки — 3¹, поэтому НОД = 4·3 = 12. Шестёрка тоже общий делитель, но не наибольший, а 72 — наименьшее общее кратное, другое понятие.

### Границы вывода

Перебор делителей в factorize хорош для небольших чисел, но для очень больших становится непомерно долгим. На этом держится шифрование в интернете: оно использует составное число, равное произведению двух очень больших простых, и если простые достаточно велики, найти их почти невозможно. На 12-часовом циферблате остаток 0 означает 12 часов. Урок не доказывает основную теорему арифметики, а только применяет её.

## English

### Goal

Tell prime numbers from composite ones, factor a number into primes, find the greatest common divisor from the factorisations, and compute clock times with the remainder of a division.

### Idea and mechanism

A natural number greater than 1 is called prime if it has no divisors other than 1 and itself, and composite if it does. For example, 13 is prime, while 12 = 2·2·3 is composite. The Fundamental Theorem of Arithmetic says that every natural number other than 1 can be written as a product of primes, and that this factorisation is unique apart from the order of the factors. Primes are like atoms from which all other numbers are built by multiplication.

The greatest common divisor (GCD) of two numbers is the largest number that divides both. It can be found from the factorisations: take the prime factors that appear in every number, each with its smallest power, and multiply them. For 12 = 2²·3 and 18 = 2·3² this is 2·3 = 6.

Remainder arithmetic works like a 12-hour clock face. To add many hours to a time, divide the added hours by 12 and add only the remainder: full turns do not move the hand. In Python the remainder is given by the % operator.

```python
import math

def factorize(n):
    factors = []
    divisor = 2
    while divisor * divisor <= n:
        while n % divisor == 0:
            factors.append(divisor)
            n //= divisor
        divisor += 1
    if n > 1:
        factors.append(n)
    return factors

print(factorize(12), factorize(18), math.gcd(12, 18))
print((9 + 30) % 12)
```

The program prints [2, 2, 3] [2, 3, 3] 6 and then 3: the GCD from the factorisations matches math.gcd, and 30 hours after 9 o'clock the clock shows 3 o'clock, because 30 hours are two full turns plus 6 hours.

### Explore and practise

Factor 24 and 36 into primes by hand, then check with the factorize function. Find their GCD from the factorisations and compare it with math.gcd. Then work out what the clock shows 100 hours after 7 o'clock, and think about what a result of 0 means.

### Question

What is the greatest common divisor of 24 and 36?

### Options

- 12: 24 = 2³·3 and 36 = 2²·3², and the common factors with their smallest powers give 2²·3.
- 6: it is a common divisor, so it is the greatest one.
- 72: it is the smallest number divisible by both.

### Answer

1

### Explanation

Both factorisations contain 2 and 3. The smallest power of two is 2² and of three is 3¹, so the GCD is 4·3 = 12. Six is also a common divisor but not the greatest, and 72 is the least common multiple, a different idea.

### Limits of the inference

Trying divisors one by one, as factorize does, works for small numbers but becomes impossibly slow for very large ones. Internet encryption relies on this: it uses a composite number that is the product of two very large primes, and if the primes are large enough, finding them is practically impossible. On a 12-hour clock a remainder of 0 means 12 o'clock. The lesson applies the Fundamental Theorem of Arithmetic but does not prove it.

## Sources

- Donna Kirk et al., *Contemporary Mathematics*, OpenStax, 2023, section 3.1 “Prime and Composite Numbers” (consulted 2026-10-31): deciding whether a number is prime or composite by its divisors other than 1 and itself, the Fundamental Theorem of Arithmetic, the greatest common divisor with the example GCD(12, 18) = 6, finding the GCD from prime factorisations, and encryption built on the product of two very large primes: [OpenStax Contemporary Mathematics, 3.1](https://openstax.org/books/contemporary-mathematics/pages/3-1-prime-and-composite-numbers)
- *Contemporary Mathematics*, section 3.7 “Clock Arithmetic” (consulted 2026-10-31): adding hours on a 12-hour clock by dividing the added hours by 12 and using the remainder: [OpenStax Contemporary Mathematics, 3.7](https://openstax.org/books/contemporary-mathematics/pages/3-7-clock-arithmetic)
- Python Software Foundation, *The Python Standard Library*, “math — Mathematical functions” (consulted 2026-10-31): math.gcd returns the greatest common divisor of its integer arguments: [docs.python.org, math.gcd](https://docs.python.org/3/library/math.html#math.gcd)
- The OpenStax pages state their own license terms; the lesson paraphrases the sections and does not copy their text: [OpenStax terms of use](https://openstax.org/terms-of-use)
