---
subject: programming
lesson_id: programming.parsing_and_abstract_syntax_trees
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Компиляторы: разбор выражения в абстрактное синтаксическое дерево / Compilers: Parsing an Expression into an Abstract Syntax Tree

## Русский

### Цель

Понимать, что компилятор сначала превращает текст программы в дерево, видеть, как дерево хранит порядок операций, и безопасно читать данные из текста через ast.literal_eval вместо eval.

### Идея и механизм

Для компьютера программа сначала просто строка символов. Прежде чем её выполнить, интерпретатор или компилятор разбирает текст и строит абстрактное синтаксическое дерево (AST): каждый узел — операция, а её дети — то, над чем она выполняется. В Python это дерево можно увидеть: функция ast.parse разбирает текст, ast.dump показывает дерево, а встроенная функция compile превращает дерево в объект кода, который уже можно выполнить.

Дерево хранит порядок операций без скобок. В выражении 2 + 3 * 4 умножение связывает сильнее, поэтому 3 * 4 становится поддеревом, а в корне оказывается сложение. Чтобы вычислить корень, сначала нужно вычислить детей, так что умножение выполняется первым.

То же дерево помогает с безопасностью. Функция eval выполняет любой код из строки, и если строка пришла от пользователя или из сети, это опасно. Функция ast.literal_eval принимает только литералы: строки, байты, числа, кортежи, списки, словари, множества, логические значения, None и Ellipsis. Выражения с операторами она вычислять не умеет и отказывается.

```python
import ast

tree = ast.parse("2 + 3 * 4", mode="eval")
print(ast.dump(tree.body))
print(eval(compile(tree, "<lesson>", "eval")))
print(ast.literal_eval("[1, 2, 3]"))
try:
    ast.literal_eval("2 + 3 * 4")
except ValueError:
    print("literal_eval refuses operators")
```

Программа печатает дерево BinOp(left=Constant(value=2), op=Add(), right=BinOp(left=Constant(value=3), op=Mult(), right=Constant(value=4))), затем 14, затем [1, 2, 3] и, наконец, literal_eval refuses operators. В корне — сложение Add, а умножение Mult — его правый ребёнок.

### Исследуй и потренируйся

Разбери выражение (2 + 3) * 4 и сравни деревья: что теперь в корне и куда делись скобки? Потом нарисуй на бумаге дерево для 2 * 3 + 4 * 5 и проверь себя через ast.dump. Наконец, попробуй передать в ast.literal_eval строку "{'level': 3}" и строку "__import__('os')" и объясни разницу.

### Вопрос

Какая операция оказывается в корне абстрактного синтаксического дерева выражения 2 + 3 * 4?

### Варианты

- Сложение: умножение 3 * 4 — его поддерево, и оно вычисляется первым.
- Умножение: в корне стоит то, что выполняется первым.
- Никакая: дерево хранит выражение просто как строку.

### Ответ

1

### Разбор

Умножение связывает сильнее сложения, поэтому парсер делает 3 * 4 правым ребёнком узла сложения. Вычисление идёт от листьев к корню: сначала 3 * 4 = 12, потом 2 + 12 = 14. То, что выполняется первым, лежит глубже, а не в корне.

### Границы модели

Урок показывает только разбор и выполнение одного выражения; настоящий компилятор ещё проверяет программу, оптимизирует её и порождает машинный или байт-код. ast.literal_eval не выполняет код, но и не полностью защищён от атак: небольшая, но хитро составленная строка может исчерпать память или стек и уронить процесс, поэтому размер входных данных нужно ограничивать.

## English

### Goal

Understand that a compiler first turns the text of a program into a tree, see how the tree stores the order of operations, and read data from text safely with ast.literal_eval instead of eval.

### Idea and mechanism

To a computer a program is at first just a string of characters. Before running it, an interpreter or compiler parses the text and builds an abstract syntax tree (AST): each node is an operation and its children are what it operates on. In Python this tree can be seen: ast.parse parses the text, ast.dump shows the tree, and the built-in compile function turns the tree into a code object that can then be run.

The tree stores the order of operations without brackets. In the expression 2 + 3 * 4 multiplication binds more tightly, so 3 * 4 becomes a subtree and addition ends up at the root. To evaluate the root you must first evaluate its children, so the multiplication happens first.

The same tree helps with security. The eval function runs any code in a string, and if the string came from a user or from the network that is dangerous. The function ast.literal_eval accepts only literals: strings, bytes, numbers, tuples, lists, dicts, sets, booleans, None, and Ellipsis. It cannot evaluate expressions with operators and refuses them.

```python
import ast

tree = ast.parse("2 + 3 * 4", mode="eval")
print(ast.dump(tree.body))
print(eval(compile(tree, "<lesson>", "eval")))
print(ast.literal_eval("[1, 2, 3]"))
try:
    ast.literal_eval("2 + 3 * 4")
except ValueError:
    print("literal_eval refuses operators")
```

The program prints the tree BinOp(left=Constant(value=2), op=Add(), right=BinOp(left=Constant(value=3), op=Mult(), right=Constant(value=4))), then 14, then [1, 2, 3], and finally literal_eval refuses operators. Addition, Add, is at the root, and multiplication, Mult, is its right child.

### Explore and practise

Parse the expression (2 + 3) * 4 and compare the trees: what is at the root now, and where did the brackets go? Then draw the tree for 2 * 3 + 4 * 5 on paper and check yourself with ast.dump. Finally, pass the string "{'level': 3}" and the string "__import__('os')" to ast.literal_eval and explain the difference.

### Question

Which operation ends up at the root of the abstract syntax tree of the expression 2 + 3 * 4?

### Options

- Addition: the multiplication 3 * 4 is its subtree and is evaluated first.
- Multiplication: whatever runs first sits at the root.
- None: the tree stores the expression simply as a string.

### Answer

1

### Explanation

Multiplication binds more tightly than addition, so the parser makes 3 * 4 the right child of the addition node. Evaluation goes from the leaves to the root: first 3 * 4 = 12, then 2 + 12 = 14. Whatever runs first lies deeper, not at the root.

### Limits

The lesson shows only the parsing and evaluation of a single expression; a real compiler also checks the program, optimises it, and generates machine code or bytecode. ast.literal_eval does not run code, but it is not fully protected from attack either: a small but cleverly crafted string can exhaust memory or the stack and crash the process, so the size of the input must be limited.

## Sources

- Python Software Foundation, *The Python Standard Library*, “ast — Abstract syntax trees” (consulted 2026-10-31): ast.parse with mode="eval", ast.dump, compiling an AST into a code object with compile(), ast.literal_eval accepting only literal structures, its inability to evaluate expressions with operators, and its exposure to memory or C stack exhaustion despite not executing code, unlike eval(): [docs.python.org, ast](https://docs.python.org/3/library/ast.html)
- Python Software Foundation, *The Python Language Reference*, “Expressions”, section “Operator precedence” (consulted 2026-10-31): multiplication binds more tightly than addition: [docs.python.org, Operator precedence](https://docs.python.org/3/reference/expressions.html#operator-precedence)
- The lesson paraphrases the documentation and does not copy its text.
