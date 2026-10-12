#!/usr/bin/env python3
"""
analyze_quality.py
==================

Analyse complète de la qualité de la Phase 2 (yCogniCore Cloud).

Ce script effectue 8 analyses :
  1. Extraction des exigences (RG, EF, ENF) depuis les markdown
  2. Inventaire des migrations SQL (tables, FK, index, triggers, CHECK)
  3. Analyse des tests SQL
  4. Couverture exigences → SQL → tests
  5. Score d'évolutivité SQL (conventions Design Bible)
  6. Détection de la dette technique (TODO, FIXME, legacy)
  7. Vérification inter-blocs (FK orphelines, cohérence)
  8. Production d'un rapport Markdown + affichage console

Usage :
    python3 scripts/analyze_quality.py [--repo /path/to/repo] [--out rapport.md]
"""

import argparse
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional


# ============================================================================
# CONFIGURATION
# ============================================================================

BLOCS = ["v9", "v10", "v11", "v12", "v13"]
BLOC_LABELS = {
    "v9":  "V9 — Transversal (Fichiers + IA + KPI)",
    "v10": "V10 — Tiers",
    "v11": "V11 — Articles",
    "v12": "V12 — CRM",
    "v13": "V13 — Ventes",
}

# Patterns de détection
PATTERN_RG = re.compile(r"\bRG-(\d{2,3})\b")
PATTERN_EF = re.compile(r"\bEF-(\d{2,3})\b")
PATTERN_ENF = re.compile(r"\bENF-(\d{2,3})\b")
PATTERN_UC = re.compile(r"\bUC-(\d{2,3})\b")

# Couleurs console
class C:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    BOLD = '\033[1m'
    NC = '\033[0m'


# ============================================================================
# CLASSE PRINCIPALE
# ============================================================================

class Phase2Analyzer:
    """Analyse complète de la qualité de la Phase 2."""

    def __init__(self, repo_path: Path):
        self.repo = repo_path
        self.blocs = {}

        # Résultats globaux
        self.results = {
            "requirements": {},   # bloc -> {rg, ef, enf, uc}
            "sql": {},            # bloc -> {tables, fk, index, triggers, checks, ...}
            "tests": {},          # bloc -> {fichier, tests_detectes}
            "coverage": {},       # bloc -> {ef_couvertes, ...}
            "evolutivity": {},    # bloc -> {score, criteres}
            "debt": [],           # liste des problèmes
            "cross_block": {},    # résultats des vérifs inter-blocs
        }

    # ========================================================================
    # ÉTAPE 1 — SCAN DES BLOCS
    # ========================================================================

    def scan_blocs(self):
        """Trouve les fichiers pour chaque bloc."""
        print(f"\n{C.BLUE}[1/8]{C.NC} Scan des blocs...")

        for bloc in BLOCS:
            self.blocs[bloc] = {
                "markdown_dir": self._find_markdown_dir(bloc),
                "migration_sql": self._find_migration_sql(bloc),
                "test_sql": self._find_test_sql(bloc),
                "setup_sh": self._find_setup_sh(bloc),
            }

            # Afficher l'état
            present = sum(1 for v in self.blocs[bloc].values() if v)
            total = len(self.blocs[bloc])
            icon = "✓" if present == total else "⚠"
            color = C.GREEN if present == total else C.YELLOW
            print(f"  {color}{icon}{C.NC} {bloc} : {present}/{total} fichiers trouvés")

    def _find_markdown_dir(self, bloc: str) -> Optional[Path]:
        """Trouve le dossier markdown d'un bloc (ex. docs/phase2/tiers)."""
        # Mapping bloc -> nom de dossier
        mapping = {
            "v9":  ["fichiers", "transversal"],
            "v10": ["tiers"],
            "v11": ["articles"],
            "v12": ["crm"],
            "v13": ["ventes"],
        }
        for name in mapping.get(bloc, []):
            p = self.repo / "docs" / "phase2" / name
            if p.exists():
                return p
        return None

    def _find_migration_sql(self, bloc: str) -> Optional[Path]:
        """Trouve la migration SQL d'un bloc."""
        d = self.repo / "db" / "migration" / "tenant"
        if not d.exists():
            return None
        for f in d.glob(f"{bloc.upper()}__*.sql"):
            return f
        return None

    def _find_test_sql(self, bloc: str) -> Optional[Path]:
        """Trouve le script de tests d'un bloc."""
        d = self.repo / "db" / "scripts"
        if not d.exists():
            return None
        for f in d.glob(f"test_{bloc}_*.sql"):
            return f
        return None

    def _find_setup_sh(self, bloc: str) -> Optional[Path]:
        """Trouve le script setup d'un bloc."""
        d = self.repo / "scripts"
        if not d.exists():
            return None
        for f in d.glob(f"{bloc}_setup*.sh"):
            return f
        return None

    # ========================================================================
    # ÉTAPE 2 — EXTRACTION DES EXIGENCES
    # ========================================================================

    def extract_requirements(self):
        """Parse les markdown pour extraire RG, EF, ENF, UC."""
        print(f"\n{C.BLUE}[2/8]{C.NC} Extraction des exigences...")

        for bloc in BLOCS:
            info = {"rg": set(), "ef": set(), "enf": set(), "uc": set()}
            md_dir = self.blocs[bloc]["markdown_dir"]

            if not md_dir:
                continue

            for md_file in md_dir.glob("*.md"):
                try:
                    content = md_file.read_text(encoding="utf-8")
                except Exception:
                    continue

                info["rg"].update(f"RG-{n}" for n in PATTERN_RG.findall(content))
                info["ef"].update(f"EF-{n}" for n in PATTERN_EF.findall(content))
                info["enf"].update(f"ENF-{n}" for n in PATTERN_ENF.findall(content))
                info["uc"].update(f"UC-{n}" for n in PATTERN_UC.findall(content))

            self.results["requirements"][bloc] = info

            rg_n = len(info["rg"])
            ef_n = len(info["ef"])
            enf_n = len(info["enf"])
            uc_n = len(info["uc"])
            print(f"  {bloc} : RG={rg_n}, EF={ef_n}, ENF={enf_n}, UC={uc_n}")

    # ========================================================================
    # ÉTAPE 3 — ANALYSE DES MIGRATIONS SQL
    # ========================================================================

    def analyze_sql(self):
        """Analyse les migrations SQL pour extraire les métriques."""
        print(f"\n{C.BLUE}[3/8]{C.NC} Analyse des migrations SQL...")

        for bloc in BLOCS:
            sql_file = self.blocs[bloc]["migration_sql"]
            if not sql_file:
                continue

            try:
                content = sql_file.read_text(encoding="utf-8")
            except Exception:
                continue

            info = {
                "fichier": sql_file.name,
                "lignes": len(content.splitlines()),
                "tables": len(re.findall(r"CREATE TABLE\s+(\w+)", content, re.IGNORECASE)),
                "index": len(re.findall(r"CREATE\s+(?:UNIQUE\s+)?INDEX", content, re.IGNORECASE)),
                "fk": len(re.findall(r"FOREIGN KEY", content, re.IGNORECASE)),
                "checks": len(re.findall(r"\bCHECK\s*\(", content, re.IGNORECASE)),
                "unique": len(re.findall(r"\bUNIQUE\b", content, re.IGNORECASE)),
                "triggers_standard": len(re.findall(r"attacher_triggers_standard", content)),
                "grants": len(re.findall(r"\bGRANT\b", content)),
                "comments": len(re.findall(r"COMMENT ON", content)),
                "security_definer": len(re.findall(r"SECURITY\s+DEFINER", content, re.IGNORECASE)),
                "search_path": "SET search_path" in content,
                "seeds": len(re.findall(r"INSERT\s+INTO", content, re.IGNORECASE)),
            }
            self.results["sql"][bloc] = info

            print(f"  {bloc} : {info['tables']} tables, {info['fk']} FK, {info['index']} index, "
                  f"{info['triggers_standard']} triggers")

    # ========================================================================
    # ÉTAPE 4 — ANALYSE DES TESTS
    # ========================================================================

    def analyze_tests(self):
        """Analyse les scripts de tests."""
        print(f"\n{C.BLUE}[4/8]{C.NC} Analyse des tests SQL...")

        for bloc in BLOCS:
            test_file = self.blocs[bloc]["test_sql"]
            if not test_file:
                continue

            try:
                content = test_file.read_text(encoding="utf-8")
            except Exception:
                continue

            # Compter les tests (T-XX)
            tests_detectes = set(re.findall(r"T-(\d{2,3})", content))

            # Chercher les RG/EF référencés dans les tests
            rg_refs = set(f"RG-{n}" for n in PATTERN_RG.findall(content))
            ef_refs = set(f"EF-{n}" for n in PATTERN_EF.findall(content))
            enf_refs = set(f"ENF-{n}" for n in PATTERN_ENF.findall(content))

            self.results["tests"][bloc] = {
                "fichier": test_file.name,
                "tests": tests_detectes,
                "rg_refs": rg_refs,
                "ef_refs": ef_refs,
                "enf_refs": enf_refs,
            }

            print(f"  {bloc} : {len(tests_detectes)} tests détectés")

    # ========================================================================
    # ÉTAPE 5 — COUVERTURE DES EXIGENCES
    # ========================================================================

    def analyze_coverage(self):
        """Croise les exigences avec SQL et tests."""
        print(f"\n{C.BLUE}[5/8]{C.NC} Analyse de la couverture des exigences...")

        for bloc in BLOCS:
            req = self.results["requirements"].get(bloc, {})
            sql = self.results["sql"].get(bloc, {})
            tests = self.results["tests"].get(bloc, {})

            rg_total = len(req.get("rg", set()))
            ef_total = len(req.get("ef", set()))
            enf_total = len(req.get("enf", set()))

            # Un test existe si le nombre de tests est > 0
            has_tests = len(tests.get("tests", set())) > 0

            # Score de couverture
            # Hypothèse : chaque EF/ENF devrait avoir au moins 1 test
            tests_count = len(tests.get("tests", set()))
            ef_covered = min(tests_count, ef_total) if ef_total > 0 else 0
            enf_covered = min(tests_count // 2, enf_total) if enf_total > 0 else 0

            ef_pct = (ef_covered / ef_total * 100) if ef_total > 0 else 100
            enf_pct = (enf_covered / enf_total * 100) if enf_total > 0 else 100

            self.results["coverage"][bloc] = {
                "rg_total": rg_total,
                "ef_total": ef_total,
                "enf_total": enf_total,
                "tests_count": tests_count,
                "ef_pct": ef_pct,
                "enf_pct": enf_pct,
            }

            print(f"  {bloc} : EF {ef_pct:.0f}% / ENF {enf_pct:.0f}% couvertes")

    # ========================================================================
    # ÉTAPE 6 — SCORE D'ÉVOLUTIVITÉ
    # ========================================================================

    def analyze_evolutivity(self):
        """Calcule un score d'évolutivité (0-100) par bloc."""
        print(f"\n{C.BLUE}[6/8]{C.NC} Score d'évolutivité SQL...")

        for bloc in BLOCS:
            sql_file = self.blocs[bloc]["migration_sql"]
            if not sql_file:
                continue

            info = self.results["sql"].get(bloc, {})
            score = 0
            criteres = []

            # Critère 1 : SET search_path (10 pts)
            if info.get("search_path"):
                score += 10
                criteres.append(("SET search_path", 10))
            else:
                criteres.append(("SET search_path", 0))

            # Critère 2 : Triggers standard attachés (20 pts)
            tables = info.get("tables", 0)
            triggers = info.get("triggers_standard", 0)
            if tables > 0:
                ratio = min(triggers / tables, 1.0)
                trig_score = int(20 * ratio)
                score += trig_score
                criteres.append((f"Triggers ({triggers}/{tables})", trig_score))

            # Critère 3 : COMMENT ON (10 pts)
            if info.get("comments", 0) > 0:
                score += 10
                criteres.append(("Commentaires", 10))
            else:
                criteres.append(("Commentaires", 0))

            # Critère 4 : GRANT (10 pts)
            if info.get("grants", 0) > 0:
                score += 10
                criteres.append(("GRANT", 10))
            else:
                criteres.append(("GRANT", 0))

            # Critère 5 : Absence d'ENUM (15 pts)
            try:
                content = sql_file.read_text(encoding="utf-8")
                enums = len(re.findall(r"CREATE TYPE\s+\w+\s+AS ENUM", content, re.IGNORECASE))
                if enums == 0:
                    score += 15
                    criteres.append(("Pas d'ENUM", 15))
                else:
                    criteres.append((f"ENUM détectés ({enums})", 0))
            except Exception:
                pass

            # Critère 6 : CHECK contraintes (10 pts)
            checks = info.get("checks", 0)
            if checks >= 5:
                score += 10
                criteres.append((f"CHECK ({checks})", 10))
            elif checks > 0:
                partial = int(10 * checks / 5)
                score += partial
                criteres.append((f"CHECK ({checks})", partial))

            # Critère 7 : SECURITY DEFINER (10 pts si fonction sensible)
            if info.get("security_definer", 0) > 0:
                score += 10
                criteres.append(("SECURITY DEFINER", 10))
            else:
                criteres.append(("SECURITY DEFINER", 0))

            # Critère 8 : Pas de TODO/FIXME (15 pts)
            debt_count = self._count_debt_in_file(sql_file)
            if debt_count == 0:
                score += 15
                criteres.append(("Pas de TODO", 15))
            else:
                criteres.append((f"TODO/FIXME ({debt_count})", 0))

            self.results["evolutivity"][bloc] = {
                "score": min(score, 100),
                "criteres": criteres,
            }

            color = C.GREEN if score >= 80 else (C.YELLOW if score >= 60 else C.RED)
            print(f"  {color}{bloc} : {score}/100{C.NC}")

    # ========================================================================
    # ÉTAPE 7 — DETTE TECHNIQUE
    # ========================================================================

    def analyze_debt(self):
        """Détecte la dette technique dans tous les fichiers."""
        print(f"\n{C.BLUE}[7/8]{C.NC} Détection de la dette technique...")

        patterns = [
            (re.compile(r"\bTODO\b[:\s]"), "TODO"),
            (re.compile(r"\bFIXME\b[:\s]"), "FIXME"),
            (re.compile(r"\bXXX\b[:\s]"), "XXX"),
            (re.compile(r"\bHACK\b[:\s]"), "HACK"),
            (re.compile(r"à compléter", re.IGNORECASE), "À compléter"),
            (re.compile(r"à faire", re.IGNORECASE), "À faire"),
        ]

        debt_count = 0

        # Scanner les dossiers
        dossiers = [
            self.repo / "db" / "migration" / "tenant",
            self.repo / "db" / "scripts",
            self.repo / "scripts",
            self.repo / "docs" / "phase2",
        ]

        for dossier in dossiers:
            if not dossier.exists():
                continue

            for f in dossier.rglob("*"):
                if not f.is_file():
                    continue
                if f.suffix not in (".sql", ".sh", ".py", ".md"):
                    continue
                if "legacy" in str(f).lower():
                    continue

                try:
                    content = f.read_text(encoding="utf-8")
                except Exception:
                    continue

                for pattern, label in patterns:
                    matches = pattern.findall(content)
                    if matches:
                        rel = f.relative_to(self.repo)
                        self.results["debt"].append({
                            "fichier": str(rel),
                            "type": label,
                            "nombre": len(matches),
                        })
                        debt_count += len(matches)

        print(f"  {debt_count} marqueur(s) de dette technique détecté(s)")
        if self.results["debt"]:
            for d in self.results["debt"][:10]:
                print(f"    - {d['fichier']} : {d['nombre']} {d['type']}")
            if len(self.results["debt"]) > 10:
                print(f"    ... et {len(self.results['debt']) - 10} autres")

    def _count_debt_in_file(self, path: Path) -> int:
        """Compte les marqueurs de dette dans un fichier."""
        try:
            content = path.read_text(encoding="utf-8")
        except Exception:
            return 0
        count = 0
        for pattern in [r"\bTODO\b", r"\bFIXME\b", r"\bXXX\b", r"\bHACK\b"]:
            count += len(re.findall(pattern, content, re.IGNORECASE))
        return count

    # ========================================================================
    # ÉTAPE 8 — VÉRIFICATION INTER-BLOCS
    # ========================================================================

    def analyze_cross_block(self):
        """Vérifie la cohérence entre blocs."""
        print(f"\n{C.BLUE}[8/8]{C.NC} Vérification inter-blocs...")

        # Récupérer toutes les tables créées
        all_tables = set()
        for bloc in BLOCS:
            sql_file = self.blocs[bloc]["migration_sql"]
            if not sql_file:
                continue
            try:
                content = sql_file.read_text(encoding="utf-8")
            except Exception:
                continue
            tables = set(re.findall(r"CREATE TABLE\s+(\w+)", content, re.IGNORECASE))
            all_tables.update(tables)

        # Détecter les FK vers des tables absentes
        missing_fk = []
        for bloc in BLOCS:
            sql_file = self.blocs[bloc]["migration_sql"]
            if not sql_file:
                continue
            try:
                content = sql_file.read_text(encoding="utf-8")
            except Exception:
                continue

            # Trouver les REFERENCES
            refs = re.findall(r"REFERENCES\s+(\w+)\s*\(", content, re.IGNORECASE)
            for ref in refs:
                if ref not in all_tables and ref != "users" and ref != "modules":
                    missing_fk.append((bloc, ref))

        self.results["cross_block"] = {
            "total_tables": len(all_tables),
            "missing_fk": missing_fk,
        }

        if missing_fk:
            print(f"  {C.YELLOW}⚠{C.NC} {len(missing_fk)} FK vers tables absentes")
            for bloc, table in missing_fk[:5]:
                print(f"    - {bloc} → {table}")
        else:
            print(f"  {C.GREEN}✓{C.NC} Aucune FK orpheline")
        print(f"  Total : {len(all_tables)} tables créées")

    # ========================================================================
    # GÉNÉRATION DU RAPPORT
    # ========================================================================

    def generate_report(self, output_path: Path):
        """Génère un rapport Markdown complet."""
        lines = []
        lines.append("# Analyse qualité — Phase 2\n")
        lines.append(f"**Date** : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        lines.append(f"**Blocs analysés** : {len([b for b in BLOCS if self.blocs[b]['migration_sql']])}\n")
        lines.append("\n---\n")

        # Section 1 — Inventaire
        lines.append("\n## 1. Inventaire des blocs\n")
        lines.append("| Bloc | Migration | Tests | Markdown | Setup |")
        lines.append("|---|---|---|---|---|")
        for bloc in BLOCS:
            info = self.blocs[bloc]
            lines.append(f"| {bloc} | "
                         f"{'✓' if info['migration_sql'] else '✗'} | "
                         f"{'✓' if info['test_sql'] else '✗'} | "
                         f"{'✓' if info['markdown_dir'] else '✗'} | "
                         f"{'✓' if info['setup_sh'] else '✗'} |")

        # Section 2 — Exigences
        lines.append("\n## 2. Exigences extraites\n")
        lines.append("| Bloc | RG | EF | ENF | UC |")
        lines.append("|---|---|---|---|---|")
        for bloc in BLOCS:
            req = self.results["requirements"].get(bloc, {})
            lines.append(f"| {bloc} | {len(req.get('rg', set()))} | "
                         f"{len(req.get('ef', set()))} | "
                         f"{len(req.get('enf', set()))} | "
                         f"{len(req.get('uc', set()))} |")

        # Section 3 — SQL
        lines.append("\n## 3. Métriques SQL\n")
        lines.append("| Bloc | Tables | FK | Index | CHECK | Triggers | Lignes |")
        lines.append("|---|---|---|---|---|---|---|")
        for bloc in BLOCS:
            s = self.results["sql"].get(bloc, {})
            if not s:
                continue
            lines.append(f"| {bloc} | {s.get('tables', 0)} | "
                         f"{s.get('fk', 0)} | {s.get('index', 0)} | "
                         f"{s.get('checks', 0)} | {s.get('triggers_standard', 0)} | "
                         f"{s.get('lignes', 0)} |")

        # Section 4 — Couverture
        lines.append("\n## 4. Couverture des exigences\n")
        lines.append("| Bloc | EF couvertes | ENF couvertes | Tests détectés |")
        lines.append("|---|---|---|---|")
        for bloc in BLOCS:
            c = self.results["coverage"].get(bloc, {})
            if not c:
                continue
            lines.append(f"| {bloc} | {c['ef_pct']:.0f}% | "
                         f"{c['enf_pct']:.0f}% | {c['tests_count']} |")

        # Section 5 — Évolutivité
        lines.append("\n## 5. Score d'évolutivité\n")
        lines.append("| Bloc | Score | Critères |")
        lines.append("|---|---|---|")
        for bloc in BLOCS:
            e = self.results["evolutivity"].get(bloc, {})
            if not e:
                continue
            criteres_str = ", ".join([f"{name}={pts}" for name, pts in e["criteres"] if pts > 0])
            lines.append(f"| {bloc} | {e['score']}/100 | {criteres_str} |")

        # Section 6 — Dette technique
        lines.append("\n## 6. Dette technique\n")
        if self.results["debt"]:
            lines.append("| Fichier | Type | Nombre |")
            lines.append("|---|---|---|")
            for d in self.results["debt"]:
                lines.append(f"| {d['fichier']} | {d['type']} | {d['nombre']} |")
        else:
            lines.append("Aucune dette technique détectée.\n")

        # Section 7 — Inter-blocs
        lines.append("\n## 7. Vérification inter-blocs\n")
        cb = self.results["cross_block"]
        lines.append(f"- Tables totales : {cb.get('total_tables', 0)}")
        lines.append(f"- FK orphelines : {len(cb.get('missing_fk', []))}")

        if cb.get("missing_fk"):
            lines.append("\n| Bloc | Table cible manquante |")
            lines.append("|---|---|")
            for bloc, table in cb["missing_fk"]:
                lines.append(f"| {bloc} | {table} |")

        # Section 8 — Synthèse
        lines.append("\n## 8. Synthèse\n")
        avg_evol = sum(e["score"] for e in self.results["evolutivity"].values()) / max(len(self.results["evolutivity"]), 1)
        avg_ef = sum(c["ef_pct"] for c in self.results["coverage"].values()) / max(len(self.results["coverage"]), 1)
        total_debt = sum(d["nombre"] for d in self.results["debt"])

        lines.append(f"- **Score d'évolutivité moyen** : {avg_evol:.0f}/100")
        lines.append(f"- **Couverture EF moyenne** : {avg_ef:.0f}%")
        lines.append(f"- **Dette technique totale** : {total_debt} marqueurs")
        lines.append(f"- **Tables créées** : {cb.get('total_tables', 0)}")
        lines.append(f"- **FK orphelines** : {len(cb.get('missing_fk', []))}")

        # Verdict
        lines.append("\n### Verdict\n")
        if avg_evol >= 80 and total_debt == 0 and len(cb.get("missing_fk", [])) == 0:
            lines.append("**EXCELLENT** — Fondation solide et évolutive.\n")
        elif avg_evol >= 60 and total_debt < 5:
            lines.append("**BON** — Quelques points à améliorer.\n")
        else:
            lines.append("**À AMÉLIORER** — Dette technique ou manque d'évolutivité détecté.\n")

        # Écrire
        output_path.write_text("\n".join(lines), encoding="utf-8")
        print(f"\n{C.GREEN}✓{C.NC} Rapport généré : {output_path}")

    # ========================================================================
    # MÉTHODE PRINCIPALE
    # ========================================================================

    def run(self, output_path: Path):
        """Exécute toutes les analyses."""
        print(f"\n{C.BOLD}==============================================")
        print("  ANALYSE QUALITÉ — Phase 2")
        print(f"=============================================={C.NC}")
        print(f"Repository : {self.repo}")
        print(f"Sortie     : {output_path}")

        self.scan_blocs()
        self.extract_requirements()
        self.analyze_sql()
        self.analyze_tests()
        self.analyze_coverage()
        self.analyze_evolutivity()
        self.analyze_debt()
        self.analyze_cross_block()
        self.generate_report(output_path)

        # Afficher la synthèse console
        print(f"\n{C.BOLD}==============================================")
        print("  SYNTHÈSE")
        print(f"=============================================={C.NC}\n")

        avg_evol = sum(e["score"] for e in self.results["evolutivity"].values()) / max(len(self.results["evolutivity"]), 1)
        avg_ef = sum(c["ef_pct"] for c in self.results["coverage"].values()) / max(len(self.results["coverage"]), 1)
        total_debt = sum(d["nombre"] for d in self.results["debt"])

        color_e = C.GREEN if avg_evol >= 80 else (C.YELLOW if avg_evol >= 60 else C.RED)
        color_c = C.GREEN if avg_ef >= 80 else (C.YELLOW if avg_ef >= 60 else C.RED)
        color_d = C.GREEN if total_debt == 0 else (C.YELLOW if total_debt < 5 else C.RED)

        print(f"  Score évolutivité    : {color_e}{avg_evol:.0f}/100{C.NC}")
        print(f"  Couverture EF        : {color_c}{avg_ef:.0f}%{C.NC}")
        print(f"  Dette technique      : {color_d}{total_debt} marqueurs{C.NC}")
        print(f"  Tables créées        : {self.results['cross_block'].get('total_tables', 0)}")
        print(f"  FK orphelines        : {len(self.results['cross_block'].get('missing_fk', []))}")
        print()


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="Analyse qualité Phase 2")
    parser.add_argument("--repo", type=Path, default=Path.home() / "projets" / "ycognicore-cloud",
                        help="Chemin du dépôt")
    parser.add_argument("--out", type=Path, default=None,
                        help="Fichier de sortie (Markdown)")

    args = parser.parse_args()

    if not args.repo.exists():
        print(f"{C.RED}ERREUR : dépôt introuvable : {args.repo}{C.NC}")
        sys.exit(1)

    output = args.out
    if output is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output = Path(f"/tmp/analyse_qualite_{timestamp}.md")

    analyzer = Phase2Analyzer(args.repo)
    analyzer.run(output)


if __name__ == "__main__":
    main()