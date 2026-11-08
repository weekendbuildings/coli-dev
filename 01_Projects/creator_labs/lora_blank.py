"""Собери и проверь сам: LoRA / Build and check it yourself: LoRA.

Урок: «Дообучение и LoRA» (finetuning_and_lora). Большая матрица W заморожена. Поверх неё
учатся две маленькие: A (r × n) и B (m × r). Допиши три функции. Проверка:
    python3 01_Projects/creator_labs/check_finetuning_and_lora.py
Lesson: finetuning_and_lora. The big matrix W is frozen; two small ones A (r × n) and
B (m × r) are trained on top of it. Fill in three functions.

Матрица это список строк. / A matrix is a list of rows.
"""


def matvec(matrix, vector):
    return [sum(w * v for w, v in zip(row, vector)) for row in matrix]


def lora_forward(W, A, B, x, scale):
    """y = W x + scale · B (A x). Не строй матрицу B A: умножай на вектор по шагам.
    Do not build the matrix B A; multiply step by step through the small rank r.
    """
    raise NotImplementedError("lora_forward")


def lora_grads(A, B, x, upstream, scale):
    """Градиенты потерь по A и по B, если upstream[i] = dL/dy[i]. W заморожена, её градиент не нужен.
    Верни (dA, dB) той же формы, что A и B.
    Gradients of the loss with respect to A and B, given upstream[i] = dL/dy[i]. Return (dA, dB).
    """
    raise NotImplementedError("lora_grads")


def merged_weights(W, A, B, scale):
    """Слить адаптер в одну матрицу: W + scale · B A. Новая матрица, W не менять.
    Merge the adapter into one matrix: W + scale · B A, without modifying W.
    """
    raise NotImplementedError("merged_weights")
