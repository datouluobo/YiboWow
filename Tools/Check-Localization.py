"""Report localization debt in shipped Lua files; no third-party dependencies.

Development is report-only. --strict-core is available for focused verification.
This is a lexical audit, not proof of visual correctness or semantic translation.
"""
from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(
    r'--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|'
    r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', re.S)
CJK = re.compile(r'[\u3400-\u9fff\u3000-\u303f\uff00-\uffef\u201c\u201d]')
ENTRY = re.compile(r'\["([^"\n]+)"\]\s*=\s*("(?:\\.|[^"\\])*")')
REFERENCE = re.compile(r'Core:Text\(\s*"([^"\n]+)"|titleKey\s*=\s*"([^"\n]+)"')
OWNER_REFERENCE = re.compile(r'Core\.Locale:Get\(\s*"([^"\n]+)"\s*,\s*"([^"\n]+)"')
ADDON_REFERENCE = re.compile(r'Addon:T\(\s*"([^"\n]+)"')
REGISTER = re.compile(r'Core\.Locale:Register\(\s*"([^"\n]+)"\s*,\s*"(zh|en)"\s*,\s*\{')
FORMAT = re.compile(r'%(?:[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs]|%)')
EXCEPTIONS = {
    'YiboCore/Data/Domains/Professions.lua': 'Client-native profession aliases; stable skill-line IDs own identity.',
    'YiboMail/SendRules.lua': 'Native item-category markers used only to recognize obsolete client categories; never displayed.',
}
MEASUREMENT = {'"字"', '"字字字字"', '"字字字字字字"'}
INPUT_PUNCTUATION = {
    'YiboCore/UI/ItemPicker.lua': {'"；"', '"，"'},
    'YiboCore/Util/LevelFilter.lua': {'"，"'},
    'YiboTaskHub/BossTargets.lua': {'"："', '"·"', '"（"', '"）"'},
}


def shipped(addon: Path) -> list[Path]:
    result = set()
    for toc in addon.glob('*.toc'):
        for line in toc.read_text(encoding='utf-8-sig').splitlines():
            line = line.strip()
            if line and not line.startswith('#') and line.lower().endswith('.lua'):
                result.add(toc.parent / line.replace('\\', '/'))
    return sorted(result)


def catalog(path: Path) -> tuple[dict, list]:
    values, duplicates = {}, []
    for match in ENTRY.finditer(path.read_text(encoding='utf-8-sig')):
        key, literal = match.groups()
        if key in values:
            duplicates.append(key)
        values[key] = json.loads(literal)
    return values, duplicates


def registrations(code: str):
    for registration in REGISTER.finditer(code):
        owner, language = registration.groups()
        tail = code[registration.end():]
        structural = TOKEN.sub(lambda m: ' ' * len(m[0]), tail)
        depth, length = 1, 0
        while depth and length < len(structural):
            if structural[length] == '{': depth += 1
            elif structural[length] == '}': depth -= 1
            length += 1
        yield owner, language, tail[:length - 1], registration.start(), registration.end() + length


def audit(addons: list[str]) -> dict:
    zh, duplicate_zh = catalog(ROOT / 'YiboCore/Locales/zhCN.lua')
    en, duplicate_en = catalog(ROOT / 'YiboCore/Locales/enUS.lua')
    result = {'resources': len(zh), 'missingEnglish': sorted(set(zh) - set(en)),
              'extraEnglish': sorted(set(en) - set(zh)),
              'duplicateKeys': duplicate_zh + duplicate_en, 'formatMismatch': [],
              'unknownKeys': [], 'hardcoded': [], 'layoutReview': [], 'exceptions': [],
              'addons': {}, 'catalogReview': []}
    catalogs = {'YiboCore': {'zh': zh, 'en': en}}
    # Business catalogs use the same explicit registration contract. Dynamic
    # registrations remain covered by the runtime probe, not guessed here.
    for name in addons:
        if name == 'YiboCore':
            continue
        for file in shipped(ROOT / name):
            if not file.exists():
                continue
            source = file.read_text(encoding='utf-8-sig')
            masked = TOKEN.sub(lambda m: re.sub(r'[^\n]', ' ', m[0]) if m[0].startswith('--') else m[0], source)
            for owner, language, body, _, _ in registrations(masked):
                target = catalogs.setdefault(owner, {}).setdefault(language, {})
                for entry in ENTRY.finditer(body):
                    key, literal = entry.groups()
                    if key in target: result['duplicateKeys'].append(owner + ':' + key)
                    target[key] = json.loads(literal)
    for owner, resources in catalogs.items():
        if owner == 'YiboCore':
            continue
        for key in sorted(set(resources.get('zh', {})) - set(resources.get('en', {}))):
            result['missingEnglish'].append(owner + ':' + key)
        for key in sorted(set(resources.get('en', {})) - set(resources.get('zh', {}))):
            result['extraEnglish'].append(owner + ':' + key)
        for key in set(resources.get('zh', {})) & set(resources.get('en', {})):
            left = [x for x in FORMAT.findall(resources['zh'][key]) if x != '%%']
            right = [x for x in FORMAT.findall(resources['en'][key]) if x != '%%']
            if left != right: result['formatMismatch'].append(owner + ':' + key)
    for key in sorted(set(zh) & set(en)):
        left = [x for x in FORMAT.findall(zh[key]) if x != '%%']
        right = [x for x in FORMAT.findall(en[key]) if x != '%%']
        if left != right:
            result['formatMismatch'].append(key)
    for name in addons:
        files = shipped(ROOT / name)
        count, regions, localized = 0, collections.Counter(), 0
        for file in files:
            relative = file.relative_to(ROOT).as_posix()
            if not file.exists():
                result['unknownKeys'].append({'path': relative, 'line': 0, 'key': 'MISSING TOC FILE'})
                continue
            source = file.read_text(encoding='utf-8-sig')
            if '/Locales/' in relative:
                continue
            # Strip comments, preserving line offsets for diagnostics.
            def mask_comment(match):
                return re.sub(r'[^\n]', ' ', match[0]) if match[0].startswith('--') else match[0]
            code = TOKEN.sub(mask_comment, source)
            resource_ranges = [(start, end) for _, _, _, start, end in registrations(code)]
            for match in REFERENCE.finditer(code):
                key = match[1] or match[2]
                localized += 1
                if key not in zh:
                    result['unknownKeys'].append({'path': relative, 'line': code.count('\n', 0, match.start()) + 1, 'key': key})
            for match in OWNER_REFERENCE.finditer(code):
                owner, key = match.groups()
                localized += 1
                if key not in catalogs.get(owner, {}).get('zh', {}):
                    result['unknownKeys'].append({'path': relative, 'line': code.count('\n', 0, match.start()) + 1, 'key': owner + ':' + key})
            for match in ADDON_REFERENCE.finditer(code):
                key = match[1]
                localized += 1
                if key not in catalogs.get(name, {}).get('zh', {}):
                    result['unknownKeys'].append({'path': relative, 'line': code.count('\n', 0, match.start()) + 1, 'key': name + ':' + key})
            for token in TOKEN.finditer(source):
                literal = token[0]
                if literal.startswith('--') or not CJK.search(literal):
                    continue
                if any(start <= token.start() < end for start, end in resource_ranges):
                    continue
                line = source.count('\n', 0, token.start()) + 1
                if relative in EXCEPTIONS or (relative.endswith('/UI/Theme.lua') and literal in MEASUREMENT) or literal in INPUT_PUNCTUATION.get(relative, set()):
                    result['exceptions'].append({'path': relative, 'line': line, 'text': literal,
                                                 'reason': EXCEPTIONS.get(relative, 'Input normalization punctuation; not displayed.' if relative in INPUT_PUNCTUATION else 'Font measurement specimen; not displayed.')})
                    continue
                count += 1
                regions[relative] += 1
                result['hardcoded'].append({'path': relative, 'line': line, 'text': literal})
            for index, line in enumerate(code.splitlines(), 1):
                if re.search(r'(?:SetWidth|SetHeight|SetSize)\(\s*\d+|(?:width|maxWidth)\s*=\s*\d+', line):
                    result['layoutReview'].append({'path': relative, 'line': index})
            # Static collections with visible titles need human review for a
            # stable id/name and localized title; do not infer correctness.
            if re.search(r'Catalog|CATALOG|TARGETS|RECIPES', file.stem):
                result['catalogReview'].append(relative)
        result['addons'][name] = {'shippedFiles': len(files), 'hardcodedCandidates': count,
                                 'localizedReferences': localized, 'regions': dict(regions)}
    return result


def markdown(report: dict) -> str:
    lines = ['# Core 系列本地化静态检查', '',
             '范围：TOC 实际加载的 Lua；排除注释、非发布文件和语言资源。候选项需要人工判断，布局风险不代表已确认缺陷。', '',
             f"Core 中文资源 {report['resources']} 项；缺英文 {len(report['missingEnglish'])}；未知 key {len(report['unknownKeys'])}；格式参数不一致 {len(report['formatMismatch'])}；重复 key {len(report['duplicateKeys'])}。", '',
             '| 插件 | 发布 Lua | 硬编码候选 | Core 语言引用 |', '|---|---:|---:|---:|']
    for name, info in sorted(report['addons'].items()):
        lines.append(f"| {name} | {info['shippedFiles']} | {info['hardcodedCandidates']} | {info['localizedReferences']} |")
    lines += ['', '区域覆盖度须按验收清单加权评估；上表字符串数量不是覆盖百分比。', '', '## 资源问题', '']
    for category in ('missingEnglish', 'extraEnglish', 'duplicateKeys', 'formatMismatch', 'unknownKeys'):
        lines.append(f"- {category}: {json.dumps(report[category], ensure_ascii=False)}")
    lines += ['', '## 硬编码候选', '']
    lines += [f"- `{item['path']}:{item['line']}` {item['text']}" for item in report['hardcoded']]
    if not report['hardcoded']:
        lines.append('无中文硬编码候选。')
    lines += ['', '## 已审查例外', '']
    lines += [f"- `{item['path']}:{item['line']}` {item['reason']}" for item in report['exceptions']]
    lines += ['', '## 静态目录人工核对', '', '核对稳定 ID、显示名称资源及动态 API 名称边界：', '']
    lines += [f'- `{item}`' for item in report['catalogReview']]
    lines += ['', '## 固定尺寸布局人工复核', '', '逐项结合英文预览检查自然宽度、换行与高度；实际客户端才可确认通过。', '']
    lines += [f"- `{item['path']}:{item['line']}`" for item in report['layoutReview']]
    return '\n'.join(lines) + '\n'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--addon', nargs='+', help='Default: every root Yibo addon with a TOC')
    parser.add_argument('--output', type=Path, help='Write Markdown and adjacent JSON report')
    parser.add_argument('--strict-core', action='store_true', help='Fail on Core resource or hardcoded-text errors')
    args = parser.parse_args()
    names = args.addon or [p.name for p in sorted(ROOT.glob('Yibo*')) if p.is_dir() and list(p.glob('*.toc'))]
    for name in names:
        if not re.fullmatch(r'Yibo[A-Za-z0-9]+', name) or not list((ROOT / name).glob('*.toc')):
            parser.error('Unknown addon: ' + name)
    report = audit(names)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(markdown(report), encoding='utf-8')
        args.output.with_suffix('.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"Core keys={report['resources']}; missing English={len(report['missingEnglish'])}; unknown keys={len(report['unknownKeys'])}; format mismatches={len(report['formatMismatch'])}")
    for name, info in sorted(report['addons'].items()):
        print(f"{name}: {info['hardcodedCandidates']} hardcoded candidates, {info['localizedReferences']} localized references")
    errors = report['missingEnglish'] or report['duplicateKeys'] or report['formatMismatch'] or [x for x in report['unknownKeys'] if x['path'].startswith('YiboCore/')]
    errors = errors or [x for x in report['hardcoded'] if x['path'].startswith('YiboCore/')]
    return int(args.strict_core and bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
