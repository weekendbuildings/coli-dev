from __future__ import annotations

import itertools
import math
from pathlib import Path


AREAS = Path(__file__).resolve().parents[1] / "02_Areas"


def _sections(subject: str, name: str) -> tuple[str, str]:
    markdown = (AREAS / subject / "lessons" / f"{name}.md").read_text(encoding="utf-8")
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def _answer(section: str, heading: str) -> str:
    return section.split(f"### {heading}", 1)[1].split("###", 1)[0].strip()


def _linked(subject: str, resource: str) -> bool:
    roadmap = (AREAS / subject / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("\n## ", 1)[0]
    return f"lesson:{resource}" in intermediate


def test_equilibrium_quotient_matches_the_source_example() -> None:
    quotient = (0.0040 * 0.0040) / (0.020 * 0.020)
    assert math.isclose(quotient, 0.040) and quotient < 0.64
    russian, english = _sections("Chemistry", "reaction_rate_and_equilibrium")
    assert "0,000016 / 0,0004 = 0,040" in russian and "0.000016 / 0.0004 = 0.040" in english
    # The catalyst point is stated as in Chemistry 2e 13.3: K is unchanged.
    assert "константа K не меняется" in russian and "the constant K does not change" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Chemistry", "reaction_rate_and_equilibrium")


def test_coin_microstates_match_the_entropy_lesson() -> None:
    five = list(itertools.product("HT", repeat=5))
    mixed = sum(1 for toss in five if toss.count("H") in (2, 3))
    assert (len(five), mixed) == (32, 20)
    four = list(itertools.product("HT", repeat=4))
    counts = {heads: sum(1 for toss in four if toss.count("H") == heads) for heads in range(5)}
    assert counts == {0: 1, 1: 4, 2: 6, 3: 4, 4: 1} and max(counts, key=counts.get) == 2
    russian, english = _sections("Physics", "entropy_and_the_second_law")
    assert "20 из 32" in russian and "6/16 = 37,5 %" in russian
    assert "20 of the 32" in english and "6/16 = 37.5%" in english
    assert "открытые системы" in russian and "open systems" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Physics", "entropy_and_the_second_law")


def test_hardy_weinberg_carrier_share() -> None:
    q = math.sqrt(0.16)
    p = 1 - q
    assert math.isclose(q, 0.4) and math.isclose(2 * p * q, 0.48) and math.isclose(p * p, 0.36)
    # Practice population: 49 YY, 42 Yy, 9 yy out of 100 gives p = 0.7 exactly in equilibrium.
    p_practice = (2 * 49 + 42) / 200
    assert math.isclose(p_practice, 0.7)
    assert [round(x * 100) for x in (p_practice ** 2, 2 * p_practice * (1 - p_practice), (1 - p_practice) ** 2)] == [49, 42, 9]
    russian, english = _sections("Biology", "population_genetics_hardy_weinberg")
    assert "2pq = 2 · 0,6 · 0,4 = 0,48" in russian and "2pq = 2 · 0.6 · 0.4 = 0.48" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Biology", "population_genetics_hardy_weinberg")


def test_matrix_vector_product_matches_the_lesson() -> None:
    weights = [[1, 2], [0, -1]]
    inputs = [3, 4]
    assert [sum(w * x for w, x in zip(row, inputs)) for row in weights] == [11, -4]
    assert sum(a * b for a, b in zip((1, 2, 3), (4, -5, 6))) == 12
    assert sum(a * b for a, b in zip((2, 1), (-1, 2))) == 0
    russian, english = _sections("Mathematics", "vectors_and_matrices")
    assert "h = g(Wx + b)" in russian and "h = g(Wx + b)" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Mathematics", "vectors_and_matrices")


def test_parallel_circuit_current() -> None:
    parallel = 1 / (1 / 2 + 1 / 6)
    assert math.isclose(parallel, 1.5) and math.isclose(12 / parallel, 8)
    assert math.isclose(12 / 2 + 12 / 6, 8) and math.isclose(12 / (2 + 6), 1.5)
    russian, english = _sections("Physics", "circuits_and_ohms_law")
    assert "I = 12 / 1,5 = 8 А" in russian and "I = 12 / 1.5 = 8 A" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Physics", "circuits_and_ohms_law")


def test_bacterial_doubling() -> None:
    assert 2 ** (180 // 30) == 64 and 24 * 60 // 30 == 48 and 2 ** (120 // 20) == 64
    russian, english = _sections("Biology", "microbial_growth_and_prokaryotes")
    assert "2⁶ = 64" in russian and "2⁶ = 64" in english
    assert "стационарной фазе" in russian and "stationary phase" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Biology", "microbial_growth_and_prokaryotes")


def test_counter_instances_keep_separate_state() -> None:
    russian, english = _sections("Programming", "python_classes_and_composition")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    question = russian.split("### Вопрос", 1)[1].split("```python", 1)[1].split("```", 1)[0]
    namespace: dict = {}
    exec(code + "\n" + question.replace("print(a.count)", "result = (a.count, b.count)"), namespace)
    assert namespace["result"] == (2, 1)
    assert "не проверяет" in russian and "does not check them at run time" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Programming", "python_classes_and_composition")


def test_http_status_classes() -> None:
    russian, english = _sections("Programming", "http_and_apis")
    for code in ("200 OK", "404 Not Found", "500 Internal Server Error"):
        assert code in russian and code in english
    # The lesson's example of ColiDev's own API must exist in the app source.
    models = (AREAS.parent / "macOS" / "ColiDev" / "App" / "AppModels.swift").read_text(encoding="utf-8")
    assert '"api/status"' in models and "GET /api/status" in russian and "GET /api/status" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Programming", "http_and_apis")


def test_seesaw_balance() -> None:
    assert math.isclose(30 * 2 / 40, 1.5) and math.isclose(20 * 0.8 / 0.2, 80)
    russian, english = _sections("Physics", "torque_and_rotational_equilibrium")
    assert "r = 60 / 40 = 1,5 м" in russian and "r = 60 / 40 = 1.5 m" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Physics", "torque_and_rotational_equilibrium")


def test_magnetic_force_on_wire() -> None:
    assert math.isclose(2 * 0.5 * 0.4 * math.sin(math.radians(90)), 0.4)
    # Practice task follows the source's worked example: 20.0 A, 0.0500 m, 1.50 T gives 1.50 N.
    assert math.isclose(20 * 0.05 * 1.5, 1.5) and math.isclose(1.5 * math.sin(math.radians(30)), 0.75)
    russian, english = _sections("Physics", "magnetic_force_on_current")
    assert "2 · 0,5 · 0,4 · 1 = 0,4 Н" in russian and "2 · 0.5 · 0.4 · 1 = 0.4 N" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Physics", "magnetic_force_on_current")


def test_speed_of_light_in_water() -> None:
    speed = 3.00e8 / 1.333
    assert round(speed / 1e8, 2) == 2.25
    refracted = math.degrees(math.asin(1.00 * math.sin(math.radians(30)) / 1.52))
    assert 19 < refracted < 20
    russian, english = _sections("Physics", "refraction_of_light")
    assert "2,25 · 10⁸ м/с" in russian and "2.25 · 10⁸ m/s" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Physics", "refraction_of_light")


def test_homeostasis_lesson_names_negative_feedback() -> None:
    russian, english = _sections("Biology", "homeostasis_and_feedback")
    assert "Отрицательная обратная связь" in _answer(russian, "Варианты").split("\n")[0]
    assert "точк" in russian and "set point" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Biology", "homeostasis_and_feedback")


def test_dependency_lesson_points_at_real_project_files() -> None:
    root = AREAS.parent
    assert (root / "requirements.txt").is_file() and (root / "requirements-test.txt").is_file()
    assert "COLIDEV_PARENT_PID" in (root / "01_Projects" / "parent_watchdog.py").read_text(encoding="utf-8")
    russian, english = _sections("Programming", "virtual_environments_and_dependencies")
    assert "pip install -r requirements.txt" in russian and "pip install -r requirements.txt" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Programming", "virtual_environments_and_dependencies")


def test_logistic_growth_rate() -> None:
    def rate(n: float) -> float:
        return 0.1 * n * (1000 - n) / 1000

    assert math.isclose(rate(500), 25) and rate(1000) == 0 and math.isclose(0.1 * 500, 50)
    assert max(range(0, 1001, 100), key=rate) == 500
    russian, english = _sections("Zoology", "logistic_population_growth")
    assert "0,1 · 500 · (1000 − 500)/1000 = 25" in russian and "0.1 · 500 · (1000 − 500)/1000 = 25" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("Zoology", "logistic_population_growth")


def test_zoology_concept_lessons_are_linked_and_answered() -> None:
    expectations = {
        "arthropods_and_molting": ("экдизис", "ecdysis"),
        "chordate_features": ("хорда", "notochord"),
        "innate_and_learned_behavior": ("Импринтинг", "Imprinting"),
        "symbiosis_mutualism_and_parasitism": ("бактерии-симбионты", "bacterial symbionts"),
    }
    for resource, (ru_term, en_term) in expectations.items():
        russian, english = _sections("Zoology", resource)
        assert ru_term in russian and en_term in english, resource
        assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1", resource
        assert _linked("Zoology", resource), resource


def test_english_argument_lessons() -> None:
    russian, english = _sections("English", "thesis_evidence_and_transitions")
    assert "therefore" in russian and "therefore" in english
    assert "Our town should build a traffic light" in _answer(english, "Options").split("\n")[0]
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("English", "thesis_evidence_and_transitions")
    russian, english = _sections("English", "counterclaims_and_respectful_argument")
    assert "concede" in russian and "concede" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked("English", "counterclaims_and_respectful_argument")


def _linked_advanced(subject: str, resource: str) -> bool:
    roadmap = (AREAS / subject / "curriculum.md").read_text(encoding="utf-8")
    advanced = roadmap.split("## Продвинутый уровень / Advanced", 1)[1].split("\n## ", 1)[0]
    return f"lesson:{resource}" in advanced


def test_autocatalytic_doubling_against_linear_growth() -> None:
    assert 2 ** 10 == 1024 and 1 + 10 == 11
    russian, english = _sections("Chemistry", "prebiotic_chemistry_and_autocatalysis")
    assert "2¹⁰ = 1024" in russian and "2¹⁰ = 1024" in english
    assert "никто не воспроизвёл" in russian and "no one has yet reproduced" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Chemistry", "prebiotic_chemistry_and_autocatalysis")


def test_atp_coupling_sum() -> None:
    assert math.isclose(20 - 30.5, -10.5) and math.ceil(45 / 30.5) == 2 and 12 - 30.5 < 0
    russian, english = _sections("Chemistry", "thermodynamics_of_living_systems")
    assert "−7,3 ккал/моль" in russian and "−30,5 кДж/моль" in russian
    assert "+20 − 30.5 = −10.5 kJ/mol" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Chemistry", "thermodynamics_of_living_systems")


def test_dna_fidelity_extends_the_error_threshold() -> None:
    limit = math.log(10) / -math.log1p(-1e-9)
    assert 2.30e9 < limit < 2.31e9
    assert math.floor(math.log(10) / -math.log(0.99)) == 229
    russian, english = _sections("Biology", "dna_replication_fidelity_and_repair")
    assert "2,3 миллиарда" in russian and "2.3 billion" in english and "229" in russian
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Biology", "dna_replication_fidelity_and_repair")


def test_synaptic_plasticity_lesson() -> None:
    russian, english = _sections("Biology", "synaptic_plasticity_and_learning")
    assert "AMPA" in russian and "NMDA" in english and "Wx + b" in english
    assert "аналогия" in russian and "analogy" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Biology", "synaptic_plasticity_and_learning")


def test_gradient_descent_step_in_two_variables() -> None:
    def f(x: float, y: float) -> float:
        return x * x + 3 * y * y

    gradient = (2 * 1, 6 * 1)
    point = (1 - 0.1 * gradient[0], 1 - 0.1 * gradient[1])
    assert all(math.isclose(a, b) for a, b in zip(point, (0.8, 0.4)))
    assert math.isclose(f(1, 1), 4) and math.isclose(f(*point), 1.12)
    russian, english = _sections("Mathematics", "gradient_and_partial_derivatives")
    assert "x′ = x − ε∇f(x)" in russian and "x′ = x − ε∇f(x)" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Mathematics", "gradient_and_partial_derivatives")


def test_michaelis_menten_rate() -> None:
    def rate(substrate: float) -> float:
        return 100 * substrate / (2 + substrate)

    assert math.isclose(rate(6), 75) and math.isclose(rate(2), 50) and rate(50) < 100
    assert math.isclose(rate(18), 90)
    russian, english = _sections("Chemistry", "enzyme_kinetics_michaelis_menten")
    assert "v = 100 · 6 / (2 + 6) = 75" in russian and "v = 100 · 6 / (2 + 6) = 75" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Chemistry", "enzyme_kinetics_michaelis_menten")


def test_bioethics_lesson_keeps_responsibility_questions() -> None:
    russian, english = _sections("Biology", "biotechnology_and_bioethics")
    for ru_question in ("Можно ли изменение отменить?", "Кто принимает решение"):
        assert ru_question in russian
    assert "Can the change be undone?" in english and "Who decides" in english
    assert "пока не удалось никому" in russian and "No one has yet built a living cell" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Biology", "biotechnology_and_bioethics")


def test_hydrogen_balmer_line_and_shell_capacity() -> None:
    energy = 13.6 * (1 / 4 - 1 / 9)
    assert round(energy, 2) == 1.89 and round(1240 / energy) == 656
    assert round(1240 / 3.4) == 365 and round(1240 / 13.6) == 91
    assert [2 * n * n for n in (1, 2, 3, 4)] == [2, 8, 18, 32]
    russian, english = _sections("Physics", "quantum_energy_levels_and_shells")
    assert "λ = 1240 / 1,89 ≈ 656 нм" in russian and "λ = 1240 / 1.89 ≈ 656 nm" in english
    assert "2n²" in russian and "2n²" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Physics", "quantum_energy_levels_and_shells")


def test_phylogeny_lesson() -> None:
    russian, english = _sections("Biology", "phylogenetic_trees_and_domains")
    assert "гипотеза" in russian and "hypothesis" in english
    assert "бактерии, археи и эукариоты" in russian and "Bacteria, Archaea, and Eukarya" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Biology", "phylogenetic_trees_and_domains")


def test_euler_steps_lag_the_exact_solution() -> None:
    def euler(step: float, steps: int) -> float:
        n = 100.0
        for _ in range(steps):
            n += step * 0.1 * n
        return n

    exact = 100 * math.exp(0.2)
    assert math.isclose(euler(1, 2), 121) and round(exact, 2) == 122.14
    assert abs(euler(0.5, 4) - exact) < abs(euler(1, 2) - exact)
    russian, english = _sections("Mathematics", "euler_method_numerical_modeling")
    assert "N₂ = 110 + 1 · 0,1 · 110 = 121" in russian and "N₂ = 110 + 1 · 0.1 · 110 = 121" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Mathematics", "euler_method_numerical_modeling")


def test_backpropagation_program_runs_as_described() -> None:
    import contextlib
    import io

    russian, english = _sections("Programming", "neural_network_backpropagation")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, {})
    lines = [line.split() for line in output.getvalue().strip().splitlines()]
    assert [float(line[1]) for line in lines] == [1.0, 0.25, 0.0625]
    assert lines[0][2] == "0.7" and lines[0][3] == "0.1"
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Programming", "neural_network_backpropagation")


def test_carbon_dating_age() -> None:
    half_life = 5730
    assert 2 * half_life == 11_460 and 3 * half_life == 17_190
    assert math.isclose(0.5 ** 2, 0.25) and math.isclose(math.exp(-0.693), 0.5, rel_tol=1e-3)
    assert 3e9 / half_life > 500_000  # far too many half-lives for carbon-14 to date ancient rocks
    russian, english = _sections("Physics", "radioactive_decay_and_dating")
    assert "2 · 5730 = 11 460 лет" in russian and "2 · 5730 = 11,460 years" in english
    assert "4,5 млрд лет" in russian and "4.5 billion years" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Physics", "radioactive_decay_and_dating")


def test_hamming_program_runs_as_described() -> None:
    import contextlib
    import io

    russian, english = _sections("Biology", "sequence_comparison_hamming_distance")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    output = io.StringIO()
    namespace: dict = {}
    with contextlib.redirect_stdout(output):
        exec(code, namespace)
    assert output.getvalue().split() == ["2", "75.0"]
    assert namespace["hamming"]("ATGACGTA", "ATGCCGTA") == 1
    try:
        namespace["hamming"]("ATG", "AT")
        raise AssertionError("different lengths must be rejected")
    except ValueError:
        pass
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Biology", "sequence_comparison_hamming_distance")


def test_contrapositive_is_equivalent_and_converse_is_not() -> None:
    numbers = range(-50, 51)

    def implies(p: bool, q: bool) -> bool:
        return (not p) or q

    original = all(implies(n % 4 == 0, n % 2 == 0) for n in numbers)
    contrapositive = all(implies(n % 2 != 0, n % 4 != 0) for n in numbers)
    converse = all(implies(n % 2 == 0, n % 4 == 0) for n in numbers)
    assert original and contrapositive and not converse
    assert [implies(p, q) for p in (True, False) for q in (True, False)] == [True, False, True, True]
    russian, english = _sections("Mathematics", "conditional_statements_and_contrapositive")
    assert "контрапозиция" in russian.lower() and "contrapositive" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Mathematics", "conditional_statements_and_contrapositive")


def test_radio_wavelength() -> None:
    assert math.isclose(3.00e8 / 1.00e8, 3.0) and math.isclose(3.00e8 / 500e-9, 6.0e14)
    assert math.isclose(1 / math.sqrt(4e-7 * math.pi * 8.85e-12), 3.00e8, rel_tol=2e-3)
    russian, english = _sections("Physics", "maxwell_and_electromagnetic_waves")
    assert "c = fλ" in russian and "c = fλ" in english and "Герц" in russian and "Hertz" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Physics", "maxwell_and_electromagnetic_waves")


def test_time_dilation_numbers() -> None:
    def gamma(beta: float) -> float:
        return 1 / math.sqrt(1 - beta * beta)

    assert math.isclose(gamma(0.6), 1.25) and math.isclose(gamma(0.6) * 10, 12.5)
    assert round(gamma(0.95), 2) == 3.20 and round(3.20 * 1.52, 2) == 4.86
    assert math.isclose(gamma(math.sqrt(3) / 2), 2)
    russian, english = _sections("Physics", "special_relativity_time_dilation")
    assert "Δt = 1,25 · 10 = 12,5 с" in russian and "Δt = 1.25 · 10 = 12.5 s" in english
    assert "4,87 мкс" in russian and "4.87 µs" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Physics", "special_relativity_time_dilation")


def test_neuron_lab_is_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "neural_network_backpropagation"' in views and "NeuronTrainingLab()" in views
    assert "NeuronTraining.swift in Sources" in project and "scripts/verify_neuron_training.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.neurontrain\.[A-Za-z]+)"', views))
    defined = re.findall(r'^\s*"(lab\.neurontrain\.[A-Za-z]+)":', strings, re.MULTILINE)
    assert used and used <= set(defined) and len(defined) == len(set(defined))


def test_l10n_dictionary_has_no_duplicate_keys() -> None:
    # A repeated key in the Swift dictionary literal crashes the app at launch, and the build does not catch it.
    import collections
    import re

    strings = (AREAS.parent / "macOS" / "ColiDev" / "App" / "L10n.swift").read_text(encoding="utf-8")
    keys = re.findall(r'^\s*"([A-Za-z0-9_.]+)": \(', strings, re.MULTILINE)
    duplicates = [key for key, count in collections.Counter(keys).items() if count > 1]
    assert keys and duplicates == []


def test_l10n_format_strings_escape_percent_signs() -> None:
    # In a String(format:) template a literal percent sign must be written %%; a lone % is read as a broken
    # conversion and the number after it is lost or garbled.
    import re

    strings = (AREAS.parent / "macOS" / "ColiDev" / "App" / "L10n.swift").read_text(encoding="utf-8")
    entries = re.findall(r'^\s*"([^"]+)": \("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)', strings, re.MULTILINE)
    assert entries
    lone = [(key, text) for key, *texts in entries for text in texts
            if re.search(r"%(?:\d+\$)?[@d]", text)
            and re.search(r"%(?![@dfisu]|\d+\$[@dfisu]|l{1,2}[du]|\d*\.\d+f)", text.replace("%%", ""))]
    assert lone == []


def test_statistical_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "entropy_and_the_second_law"' in views and "CoinEntropyLab()" in views
    assert 'moduleResource == "population_genetics_hardy_weinberg"' in views and "HardyWeinbergLab()" in views
    assert "StatisticalLabs.swift in Sources" in project and "scripts/verify_statistical_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:entropy|hardy)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:entropy|hardy)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    # Practice task: q with ten carriers per affected individual is 2p/q = 10, so q = 1/6.
    q = 1 / 6
    assert math.isclose(2 * (1 - q) / q, 10)


def test_security_lesson_code_shows_injection_and_defence() -> None:
    import contextlib
    import io

    russian, english = _sections("Programming", "application_security_injection_and_secrets")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, {})
    assert output.getvalue().split() == ["2", "0", "32"]
    root = AREAS.parent
    assert ".env" in (root / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert '_KEYCHAIN_SERVICE = "ColiDev"' in (root / "01_Projects" / "orchestrator.py").read_text(encoding="utf-8")
    assert "без разрешения нельзя" in russian and "without permission is not allowed" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Programming", "application_security_injection_and_secrets")


def test_mark_recapture_estimates() -> None:
    assert 80 * 100 / 20 == 400 and 50 * 60 / 15 == 200 and 120 * 90 / 30 == 360
    assert 120 * 90 / 15 > 120 * 90 / 30  # trap-shy marked animals inflate the estimate
    russian, english = _sections("Zoology", "mark_recapture_population_estimate")
    assert "N = 80 · 100 / 20 = 400" in russian and "N = 80 · 100 / 20 = 400" in english
    assert "благополучия" in russian and "welfare" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Zoology", "mark_recapture_population_estimate")


def test_preserve_design_lesson() -> None:
    russian, english = _sections("Zoology", "biodiversity_threats_and_preserves")
    for ru, en in (("потеря местообитаний", "habitat loss"), ("чрезмерный промысел", "overharvesting"), ("коридорами", "corridors")):
        assert ru in russian and en in english
    # One square of side 4 versus four squares of side 2, with an edge band of width 0.5.
    core_large = (4 - 1) ** 2
    core_small = 4 * (2 - 1) ** 2
    assert core_large > core_small
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Zoology", "biodiversity_threats_and_preserves")


def test_surface_to_volume_scaling() -> None:
    def sphere_ratio(r: float) -> float:
        return (4 * math.pi * r * r) / (4 / 3 * math.pi * r ** 3)

    assert math.isclose(sphere_ratio(1), 3) and math.isclose(sphere_ratio(2), 1.5)
    assert [6 * a * a / a ** 3 for a in (1, 2, 4)] == [6, 3, 1.5]
    russian, english = _sections("Zoology", "surface_volume_and_body_size")
    assert "3/r" in russian and "3/r" in english and "8 / 4 = 2" in russian and "8 / 4 = 2" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Zoology", "surface_volume_and_body_size")


def test_taxonomy_lesson_lists_ranks_in_order() -> None:
    russian, english = _sections("Zoology", "taxonomy_ranks_and_binomial_names")
    ranks = ["kingdom", "phylum", "class", "order", "family", "genus", "species"]
    idea = english.split("### Idea and mechanism", 1)[1]
    positions = [idea.index(rank) for rank in ranks]
    assert positions == sorted(positions)
    assert "Canis lupus" in russian and "Canis lupus" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Zoology", "taxonomy_ranks_and_binomial_names")


def test_async_lesson_program_overlaps_waits() -> None:
    import contextlib
    import io

    russian, english = _sections("Programming", "concurrency_async_await")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, {"__name__": "lesson"})
    printed = output.getvalue().strip()
    assert printed.startswith("['lesson', 'progress', 'sources']")
    assert float(printed.rsplit(" ", 1)[1]) < 0.5  # three 0.2 s waits overlap instead of adding up to 0.6 s
    assert "async def" in (AREAS.parent / "01_Projects" / "orchestrator.py").read_text(encoding="utf-8")
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Programming", "concurrency_async_await")


def test_idempotency_program_runs_as_described() -> None:
    import contextlib
    import io

    russian, english = _sections("Programming", "retries_and_idempotency")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, {})
    assert output.getvalue().strip().splitlines() == ["2 {'pH': 'done'}", "1"]
    assert "PUT" in russian and "DELETE" in english and "Idempotency-Key" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Programming", "retries_and_idempotency")


def _run_lesson_code(subject: str, name: str) -> tuple[str, str, str]:
    import contextlib
    import io

    russian, english = _sections(subject, name)
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, {"__name__": "lesson"})
    return russian, english, output.getvalue().strip()


def test_pendulum_fit_gives_g_from_the_slope() -> None:
    # The single-point example from College Physics 2e 16.4.
    assert math.isclose(4 * math.pi ** 2 * 0.75000 / 1.7357 ** 2, 9.8281, abs_tol=5e-5)
    assert math.isclose(4 * math.pi ** 2 / 4.00, math.pi ** 2)  # the quiz: slope 4.00 s²/m
    russian, english, printed = _run_lesson_code("Physics", "fitting_pendulum_data_least_squares")
    assert printed == "4.053 -0.012 9.74"
    assert "4.053 -0.012 9.74" in russian and "4.053 -0.012 9.74" in english
    # Shifting every length by the same offset leaves the slope unchanged, as the practice task claims.
    lengths, squares = [0.25, 0.50, 0.75, 1.00], [t * t for t in (1.00, 1.42, 1.74, 2.01)]

    def slope(xs: list[float]) -> float:
        mx, my = sum(xs) / len(xs), sum(squares) / len(squares)
        return sum((x - mx) * (y - my) for x, y in zip(xs, squares)) / sum((x - mx) ** 2 for x in xs)

    assert math.isclose(slope(lengths), slope([x + 0.02 for x in lengths]))
    assert "15°" in russian and "15°" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Physics", "fitting_pendulum_data_least_squares")


def test_number_theory_lesson_program_and_quiz() -> None:
    russian, english, printed = _run_lesson_code("Mathematics", "primes_gcd_and_clock_arithmetic")
    assert printed.splitlines() == ["[2, 2, 3] [2, 3, 3] 6", "3"]
    assert math.gcd(24, 36) == 12 and math.lcm(24, 36) == 72  # the quiz and its distractor
    assert (7 + 100) % 12 == 11  # practice task: 100 hours after 7 o'clock
    assert "2²·3" in russian and "2²·3" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Mathematics", "primes_gcd_and_clock_arithmetic")


def test_insect_lesson_keeps_the_source_body_plan() -> None:
    russian, english = _sections("Zoology", "insect_body_plan_and_metamorphosis")
    assert "голова, грудь и брюшко" in russian and "head, thorax, and abdomen" in english
    assert "пара членистых ног" in russian and "pair of jointed legs" in english
    for insect in ("ants", "beetles", "flies", "butterflies", "cockroaches", "crickets"):
        assert insect in english
    assert "complete metamorphosis" in english and "incomplete, gradual metamorphosis" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Zoology", "insect_body_plan_and_metamorphosis")


def test_logging_lesson_program_drops_info_and_times_membership() -> None:
    import subprocess
    import sys

    russian, english = _sections("Programming", "logging_and_measuring_performance")
    code = russian.split("```python", 1)[1].split("```", 1)[0]
    assert code == english.split("```python", 1)[1].split("```", 1)[0]
    # A fresh interpreter, so pytest's own logging handlers do not change the default configuration.
    result = subprocess.run([sys.executable, "-I", "-c", code], capture_output=True, text=True, timeout=60)
    assert result.returncode == 0
    assert result.stderr.strip() == "WARNING source not checked for 400 days"
    assert result.stdout.strip() == "True"
    assert 'logging.getLogger("colidev")' in (AREAS.parent / "01_Projects" / "orchestrator.py").read_text(encoding="utf-8")
    assert "WARNING" in russian and "perf_counter" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Programming", "logging_and_measuring_performance")


def test_ast_lesson_program_shows_precedence_and_safe_literals() -> None:
    import ast

    russian, english, printed = _run_lesson_code("Programming", "parsing_and_abstract_syntax_trees")
    tree = "BinOp(left=Constant(value=2), op=Add(), right=BinOp(left=Constant(value=3), op=Mult(), right=Constant(value=4)))"
    assert printed.splitlines() == [tree, "14", "[1, 2, 3]", "literal_eval refuses operators"]
    assert tree in russian and tree in english
    assert isinstance(ast.parse("(2 + 3) * 4", mode="eval").body.op, ast.Mult)  # practice task: brackets move the root
    assert ast.literal_eval("{'level': 3}") == {"level": 3}
    try:
        ast.literal_eval("__import__('os')")
    except ValueError:
        pass
    else:
        raise AssertionError("literal_eval must refuse function calls")
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"
    assert _linked_advanced("Programming", "parsing_and_abstract_syntax_trees")


def test_least_squares_lab_is_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    model = (app / "App" / "LeastSquaresFit.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "fitting_pendulum_data_least_squares"' in views and "LeastSquaresFitLab()" in views
    assert "LeastSquaresFit.swift in Sources" in project and "scripts/verify_least_squares_fit.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.lsq\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.lsq\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    # The lab uses the same measurements as the lesson program.
    russian, _ = _sections("Physics", "fitting_pendulum_data_least_squares")
    assert "[0.25, 0.50, 0.75, 1.00]" in russian and "[0.25, 0.50, 0.75, 1.00]" in model
    assert "[1.00, 1.42, 1.74, 2.01]" in russian and "[1.00, 1.42, 1.74, 2.01]" in model


def test_plasticity_and_enzyme_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "synaptic_plasticity_and_learning"' in views and "SynapticPlasticityLab()" in views
    assert 'moduleResource == "enzyme_kinetics_michaelis_menten"' in views and "MichaelisMentenLab()" in views
    assert "LifeMechanismLabs.swift in Sources" in project and "scripts/verify_life_mechanism_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:plasticity|enzyme)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:plasticity|enzyme)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    # The lab follows the lesson: NMDA needs glutamate and strong depolarisation, and AMPA insertion strengthens the synapse.
    _, synapse = _sections("Biology", "synaptic_plasticity_and_learning")
    assert "magnesium" in synapse and "calcium" in synapse and "AMPA receptors are inserted" in synapse
    # The enzyme lab starts at the lesson quiz: Vmax 100, Km 2 mM, [S] 6 mM gives 75.
    _, enzyme = _sections("Chemistry", "enzyme_kinetics_michaelis_menten")
    assert "v = 100 · 6 / (2 + 6) = 75" in enzyme
    assert math.isclose(100 * 6 / (2 + 6), 75)


def test_euler_and_autocatalysis_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "euler_method_numerical_modeling"' in views and "EulerMethodLab()" in views
    assert 'moduleResource == "prebiotic_chemistry_and_autocatalysis"' in views and "AutocatalysisLab()" in views
    assert "GrowthModelLabs.swift in Sources" in project and "scripts/verify_growth_model_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:euler|autocatalysis)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:euler|autocatalysis)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    # Both labs start at their lesson quizzes: Euler with h = 1 gives 121, and ten doublings give 1024.
    _, euler = _sections("Mathematics", "euler_method_numerical_modeling")
    assert "N₂ = 110 + 1 · 0.1 · 110 = 121" in euler and "122.14" in euler
    assert math.isclose(100 * 1.1 * 1.1, 121) and math.isclose(100 * math.exp(0.2), 122.14, abs_tol=5e-3)
    _, autocatalysis = _sections("Chemistry", "prebiotic_chemistry_and_autocatalysis")
    assert "2¹⁰ = 1024" in autocatalysis and 2 ** 10 == 1024


def test_neural_layer_and_descent_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "vectors_and_matrices"' in views and "NeuralLayerLab()" in views
    assert 'moduleResource == "gradient_and_partial_derivatives"' in views and "GradientDescent2DLab()" in views
    assert "NeuralMathLabs.swift in Sources" in project and "scripts/verify_neural_math_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:layer|descent2d)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:layer|descent2d)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    # Both labs start at their lesson quizzes.
    _, matrices = _sections("Mathematics", "vectors_and_matrices")
    assert "W = [[1, 2], [0, −1]]" in matrices and "(11, −4)" in matrices
    _, gradient = _sections("Mathematics", "gradient_and_partial_derivatives")
    assert "(1, 1) − 0.1 · (2, 6) = (0.8, 0.4)" in gradient


def test_fidelity_and_hamming_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "dna_replication_fidelity_and_repair"' in views and "GenomeFidelityLab()" in views
    assert 'moduleResource == "sequence_comparison_hamming_distance"' in views and "HammingDistanceLab()" in views
    assert "SequenceLabs.swift in Sources" in project and "scripts/verify_sequence_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:fidelity|hamming)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:fidelity|hamming)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    # Both labs start at their lesson examples: 2.3 billion letters at e = 10⁻⁹, and distance 2 with 75% identity.
    _, fidelity = _sections("Biology", "dna_replication_fidelity_and_repair")
    assert "ln 10 / 10⁻⁹ ≈ 2.3" in fidelity and "229 letters" in fidelity
    assert math.isclose(math.log(10) / 1e-9 / 1e9, 2.3026, abs_tol=1e-4)
    _, hamming = _sections("Biology", "sequence_comparison_hamming_distance")
    assert '"ATGCCGTA"' in hamming and '"ATGACGTT"' in hamming and "2 and 75.0" in hamming


def test_dating_and_feedback_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "radioactive_decay_and_dating"' in views and "RadioactiveDatingLab()" in views
    assert 'moduleResource == "homeostasis_and_feedback"' in views and "FeedbackLoopLab()" in views
    assert "RegulationLabs.swift in Sources" in project and "scripts/verify_regulation_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:dating|feedback)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:dating|feedback)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    _, dating = _sections("Physics", "radioactive_decay_and_dating")
    assert "5730 years" in dating and "4.5 billion years" in dating and "two half-lives" in dating
    assert math.isclose(5730 * math.log2(100 / 25), 11_460)
    assert math.isclose(2 * 0.7 ** 15, 0.0095, abs_tol=5e-4)  # the UI test's 0.01 °C after 15 steps
    _, homeostasis = _sections("Biology", "homeostasis_and_feedback")
    assert "negative feedback" in homeostasis.lower() and "positive feedback" in homeostasis.lower()


def test_coupling_and_quotient_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert 'moduleResource == "thermodynamics_of_living_systems"' in views and "EnergyCouplingLab()" in views
    assert 'moduleResource == "reaction_rate_and_equilibrium"' in views and "ReactionQuotientLab()" in views
    assert "ChemicalEnergyLabs.swift in Sources" in project and "scripts/verify_chemical_energy_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:coupling|quotient)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:coupling|quotient)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    _, coupling = _sections("Chemistry", "thermodynamics_of_living_systems")
    assert "+20 − 30.5 = −10.5" in coupling and "−30.5 kJ/mol" in coupling
    _, equilibrium = _sections("Chemistry", "reaction_rate_and_equilibrium")
    assert "K = 0.64" in equilibrium and "Q = 0.040" in equilibrium


def test_modern_physics_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for resource, view in [("special_relativity_time_dilation", "TimeDilationLab"), ("quantum_energy_levels_and_shells", "HydrogenSpectrumLab"),
                           ("maxwell_and_electromagnetic_waves", "ElectromagneticWaveLab")]:
        assert f'moduleResource == "{resource}"' in views and f"{view}()" in views
    assert "ModernPhysicsLabs.swift in Sources" in project and "scripts/verify_modern_physics_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:relativity|hydrogen|emwave)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:relativity|hydrogen|emwave)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    _, relativity = _sections("Physics", "special_relativity_time_dilation")
    assert "1.25" in relativity and "12.5 s" in relativity and "1.52 µs" in relativity
    _, quantum = _sections("Physics", "quantum_energy_levels_and_shells")
    assert "656 nm" in quantum and "1240" in quantum and "2n²" in quantum
    _, maxwell = _sections("Physics", "maxwell_and_electromagnetic_waves")
    assert "3.00 m" in maxwell and "100 MHz" in maxwell


def test_classical_physics_labs_are_wired_into_the_app_project_and_ci() -> None:
    import re

    app = AREAS.parent / "macOS" / "ColiDev"
    views = (app / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (app / "App" / "L10n.swift").read_text(encoding="utf-8")
    project = (app / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (AREAS.parent / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for resource, view in [("circuits_and_ohms_law", "CircuitLab"), ("refraction_of_light", "RefractionLab"), ("torque_and_rotational_equilibrium", "SeesawLab")]:
        assert f'moduleResource == "{resource}"' in views and f"{view}()" in views
    assert "ClassicalPhysicsLabs.swift in Sources" in project and "scripts/verify_classical_physics_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:circuit|refraction|seesaw)\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.(?:circuit|refraction|seesaw)\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    _, circuits = _sections("Physics", "circuits_and_ohms_law")
    assert "R = 1.5 Ω" in circuits and "8 A" in circuits
    _, refraction = _sections("Physics", "refraction_of_light")
    assert "1.333" in refraction and "1.52" in refraction and "30°" in refraction
    assert math.isclose(math.degrees(math.asin(math.sin(math.radians(30)) / 1.52)), 19.2, abs_tol=0.05)
    _, torque = _sections("Physics", "torque_and_rotational_equilibrium")
    assert "30 · 2 = 40 · r" in torque and "1.5 m" in torque
