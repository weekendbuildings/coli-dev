"""Regression checks for facts corrected by the course audit (project-plan/COURSE_AUDIT_RU_EN.md)."""
from __future__ import annotations

import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
L10N = (APP / "L10n.swift").read_text(encoding="utf-8")


def _lesson(subject: str, name: str) -> tuple[str, str, str]:
    text = (ROOT / "02_Areas" / subject / "lessons" / f"{name}.md").read_text(encoding="utf-8")
    russian, rest = text.split("## English", 1)
    english, sources = rest.split("## Sources", 1)
    return russian, english, sources


def _strings(key: str) -> tuple[str, str]:
    match = re.search(rf'"{re.escape(key)}": \("(.*?)", "(.*?)"\),', L10N)
    assert match, key
    return match.group(1), match.group(2)


def test_one_error_per_billion_belongs_to_the_whole_copying_system() -> None:
    russian, english, sources = _lesson("Biology", "dna_replication_fidelity_and_repair")
    assert "ДНК-полимераза ошибается примерно в одном" not in russian
    assert "вся система копирования вместе с починкой" in russian
    assert "DNA polymerase makes about one error per billion" not in english
    assert "whole copying system, repair included" in english
    assert "PMC3628614" in sources
    for key in ("lab.fidelity.pin9", "lab.fidelity.hint", "lab.replicator.challengeSolved"):
        ru, en = _strings(key)
        assert "ДНК-полимераз" not in ru and "DNA polymerase" not in en, key


def test_fidelity_lesson_sends_the_learner_to_a_lab_that_covers_its_values() -> None:
    russian, english, _ = _lesson("Biology", "dna_replication_fidelity_and_repair")
    assert "в тренажёре этого урока" in russian and "this lesson's lab" in english
    # The lab from the origin-of-life lesson cannot reach e = 10⁻⁴, so it must not be the target.
    replicator = (APP / "ReplicatorErrorThreshold.swift").read_text(encoding="utf-8")
    lowest = float(re.search(r"errorRateRange = ([\d.]+)\.\.\.", replicator).group(1))
    assert lowest > 1e-4
    sequence = (APP / "SequenceLabs.swift").read_text(encoding="utf-8")
    low, high = map(int, re.search(r"exponentRange = (\d+)\.\.\.(\d+)", sequence).groups())
    assert low <= 4 and 6 <= high


def test_plasticity_lab_does_not_say_networks_learn_by_joint_activity() -> None:
    ru, en = _strings("lab.plasticity.challengeSolved")
    assert "переняли" not in ru and "borrowed" not in en
    assert "градиент ошибки" in ru and "error gradient" in en


def test_ltp_needs_glutamate_and_depolarisation_together() -> None:
    russian, english, _ = _lesson("Biology", "synaptic_plasticity_and_learning")
    assert "на нём есть глутамат" in russian and "glutamate is bound" in english
    model = (APP / "LifeMechanismLabs.swift").read_text(encoding="utf-8")
    assert "glutamate && strongDepolarization" in model


def test_enzyme_lab_describes_saturation_correctly() -> None:
    share = lambda multiple: multiple / (1 + multiple)  # v / Vmax at [S] = multiple · Km
    assert math.isclose(share(9), 0.9) and math.isclose(share(99), 0.99)
    ru, en = _strings("lab.enzyme.challengeSolved")
    assert "последних 10" not in ru and "last 10%" not in en
    assert "99 · Km" in ru and "99 · Km" in en


def test_glass_of_water_molecule_count() -> None:
    molecules = 200 / 18.015 * 6.022e23
    assert 6.5e24 < molecules < 7e24
    ru, en = _strings("lab.entropy.challengeSolved")
    assert "7 · 10²⁴" in ru and "7 · 10²⁴" in en
    assert "сам собой порядок не возникает" not in ru
    assert "order never appears" not in en


def test_lessons_mention_spudcell_without_overclaiming() -> None:
    russian, english, sources = _lesson("Biology", "what_is_life_and_its_origin")
    assert "SpudCell" in russian and "SpudCell" in english
    assert "препринте" in russian and "not yet peer reviewed" in english
    assert "пока не удалось никому" in russian and "no one has yet built a living cell" in english
    assert "2026.07.01.735724" in sources
    russian, english, sources = _lesson("Biology", "biotechnology_and_bioethics")
    assert "SpudCell" in russian and "SpudCell" in english and "2026.07.01.735724" in sources


def test_rna_world_name_and_vesicle_division_are_attributed_exactly() -> None:
    russian, english, sources = _lesson("Biology", "what_is_life_and_its_origin")
    assert "предложил идею «мира РНК»" not in russian and "дал ей имя" in russian
    assert 'proposed the "RNA world"' not in english and "named it" in english
    assert "10.1089/ast.2012.0868" in sources
    russian, english, _ = _lesson("Chemistry", "prebiotic_chemistry_and_autocatalysis")
    assert "продавить через узкие поры" in russian and "pushed through small pores" in english


def test_atp_value_in_the_cell_is_stated() -> None:
    russian, english, sources = _lesson("Chemistry", "thermodynamics_of_living_systems")
    assert "−57 кДж/моль" in russian and "−57 kJ/mol" in english and "−57 kJ/mol" in sources
    ru, en = _strings("lab.coupling.limit")
    assert "−57" in ru and "−57" in en
    ru, en = _strings("lab.coupling.challengeSolved")
    assert "стандартных условиях" in ru and "standard conditions" in en


def test_lab_accessibility_text_describes_the_current_charts() -> None:
    ru, en = _strings("lab.gd.chart")
    assert "Столбцы" not in ru and "Bars" not in en
    ru, en = _strings("lab.replicator.scale")
    assert "от 0 до 2" not in ru and "from 0 to 2" not in en
