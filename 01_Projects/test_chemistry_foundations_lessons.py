from __future__ import annotations

import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHEMISTRY = ROOT / "02_Areas" / "Chemistry"
APP_ROOT = ROOT / "macOS" / "ColiDev"


def _sections(name: str) -> tuple[str, str]:
    markdown = (CHEMISTRY / "lessons" / f"{name}.md").read_text(encoding="utf-8")
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def _answer(section: str, heading: str) -> str:
    return section.split(f"### {heading}", 1)[1].split("###", 1)[0].strip()


def test_chemistry_roadmap_links_both_foundations_lessons_in_order() -> None:
    roadmap = (CHEMISTRY / "curriculum.md").read_text(encoding="utf-8")
    foundations = roadmap.split("## База / Foundations", 1)[1].split("## Углубление", 1)[0]
    assert foundations.index("lesson:atoms_electrons_and_chemical_bonds") < foundations.index("lesson:water_hydrogen_bonds_and_ph")


def test_intro_element_shares_add_up_to_the_quoted_total() -> None:
    russian, english = _sections("intro")
    shares = {"oxygen": 65, "carbon": 18, "hydrogen": 10, "nitrogen": 3}
    assert sum(shares.values()) == 96
    assert "около 96 %" in russian and "65 %" in russian and "18 %" in russian
    assert "about 96%" in english and "65% oxygen" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"


def test_carbon_bond_count_follows_from_its_electron_shells() -> None:
    electrons = 6
    inner, outer = 2, electrons - 2
    assert (inner, outer) == (2, 4) and 8 - outer == 4
    russian, english = _sections("atoms_electrons_and_chemical_bonds")
    assert "2 на внутренней оболочке и 4 на внешней" in russian and "четыре ковалентные связи" in russian
    assert "2 in the inner shell and 4 in the outer one" in english and "four covalent bonds" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"


def test_ph_question_uses_the_logarithmic_scale() -> None:
    ratio = 10 ** (6 - 4)
    assert ratio == 100 and math.isclose(-math.log10(1e-4) - -math.log10(1e-6), -2)
    russian, english = _sections("water_hydrogen_bonds_and_ph")
    assert "10² = 100 раз" in russian and "10² = 100 times" in english
    # The neutral value is tied to 25 °C, because water's ionization depends on temperature.
    assert "25 °C" in russian and "меняется с температурой" in russian
    assert "25 °C" in english and "changes with temperature" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"


def test_intermediate_lessons_follow_the_roadmap_in_order() -> None:
    roadmap = (CHEMISTRY / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("## Продвинутый уровень", 1)[0]
    assert intermediate.index("lesson:carbon_and_organic_molecules") < intermediate.index("lesson:reaction_energy_and_catalysis")


def test_alkane_hydrogen_count_follows_from_bond_counting() -> None:
    def hydrogens(carbons: int) -> int:
        return 4 * carbons - 2 * (carbons - 1)

    assert [hydrogens(n) for n in (1, 2, 4, 5, 8)] == [4, 6, 10, 12, 18]
    assert all(hydrogens(n) == 2 * n + 2 for n in range(1, 20))
    russian, english = _sections("carbon_and_organic_molecules")
    assert "4n − 2(n − 1) = 2n + 2" in russian and "4n − 2(n − 1) = 2n + 2" in english
    assert "C₄H₁₀" in russian and "C₄H₁₀" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"


def test_arrhenius_figures_match_the_lesson() -> None:
    gas_constant, temperature = 8.314, 298
    per_tenfold = gas_constant * temperature * math.log(10) / 1000
    assert round(per_tenfold, 1) == 5.7
    assert round(math.exp(11_400 / (gas_constant * temperature))) == 100
    # Practice task: 17.1 kJ/mol is three steps of about 5.7 kJ/mol, about 1000 times faster.
    assert 900 < math.exp(17_100 / (gas_constant * temperature)) < 1100
    russian, english = _sections("reaction_energy_and_catalysis")
    assert "5,7 кДж/моль" in russian and "11,4 кДж/моль" in russian and "R = 8,314" in russian
    assert "5.7 kJ/mol" in english and "11.4 kJ/mol" in english and "R = 8.314" in english
    # The lesson must keep the catalyst from changing ΔG, as the sources state.
    assert "не меняет ΔG" in russian and "does not change a reaction's ΔG" in english
    assert _answer(russian, "Ответ") == "1" and _answer(english, "Answer") == "1"


def test_every_chemistry_lesson_cites_openstax_pages_or_papers() -> None:
    for lesson in sorted((CHEMISTRY / "lessons").glob("*.md")):
        sources = lesson.read_text(encoding="utf-8").split("## Sources", 1)[1]
        textbook = re.search(r"\(https://openstax\.org/books/(?:chemistry|biology)-2e/pages/[0-9a-z-]+\)", sources)
        papers = re.findall(r"\(https://doi\.org/10\.[^)]+\)", sources)
        assert textbook or len(papers) >= 2, lesson.name


def test_chemistry_labs_are_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "water_hydrogen_bonds_and_ph"' in views and "PHScaleLab()" in views
    assert 'moduleResource == "atoms_electrons_and_chemical_bonds"' in views and "MoleculeBuilderLab()" in views
    assert 'moduleResource == "reaction_energy_and_catalysis"' in views and "ReactionEnergyLab()" in views
    assert "ChemistryLabs.swift in Sources" in project
    assert "scripts/verify_chemistry_labs.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()"(lab\.(?:ph|molecule|energy)\.[A-Za-z]+)"', views))
    # Atom and molecule names are looked up by key from the model, e.g. "lab.molecule.name.C".
    used |= {f"lab.molecule.{group}.{atom}" for group in ("atom", "name") for atom in "HONC"}
    defined = re.findall(r'^\s*"(lab\.(?:ph|molecule|energy)\.[A-Za-z.]+)":', strings, re.MULTILINE)
    assert used and used <= set(defined) and len(defined) == len(set(defined))


def test_chemistry_is_registered_in_the_app_and_backend() -> None:
    routes = json.loads((ROOT / "02_Areas" / "intro_lesson_routes.json").read_text(encoding="utf-8"))["routes"]
    assert {"subject_id": "chemistry", "resource": "intro", "progress_lesson_id": "intro.chemistry"} in routes
    models = (APP_ROOT / "App" / "AppModels.swift").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    assert "    case chemistry\n" in models and 'case .chemistry: return "flask.fill"' in models
    assert '"subject.chemistry": ("Химия", "Chemistry")' in strings and '"subject.chemistry.subtitle"' in strings
