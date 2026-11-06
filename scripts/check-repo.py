#!/usr/bin/env python3
"""Check tracked paths, documentation links, and common sensitive-data patterns.

Use --history to scan text blobs reachable from all local Git refs as well.
Findings show locations and rule names, never matched credential values.
This focused check complements code review; it is not an exhaustive secret detector.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import unicodedata
from functools import cache
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
KEBAB = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
RESERVED_DIRECTORIES = {'.github'}
RESERVED_MARKDOWN = {'README.md'}
RULES = {
    'private-key': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    'github-token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b'),
    'aws-access-key': re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
    'slack-token': re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{20,}\b'),
    'openai-token': re.compile(r'\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}\b'),
    'google-api-key': re.compile(r'\bAIza[A-Za-z0-9_-]{35}\b'),
    'machine-home': re.compile(r'/(?:Users|home)/[A-Za-z0-9][A-Za-z0-9._-]*/'),
    'machine-temp': re.compile(r'/(?:private/)?var/folders/[A-Za-z0-9_-]{2}/[A-Za-z0-9_-]{8,}/'),
}
PRIVATE_FILES = {'.env', '.npmrc', '.netrc', 'credentials.json', 'host-config.json', 'activity.sqlite'}
PRIVATE_SUFFIXES = {'.sqlite', '.sqlite3', '.db', '.p12', '.pfx', '.key', '.pem', '.mobileprovision', '.provisionprofile'}


def git(*args: str, input: bytes | None = None) -> bytes:
    return subprocess.check_output(['git', *args], cwd=ROOT, input=input)


def files() -> list[Path]:
    paths = git('ls-files', '-z', '--cached', '--others', '--exclude-standard').decode().split('\0')
    return sorted({ROOT / value for value in paths if value and (ROOT / value).is_file()})


def decode(data: bytes) -> str | None:
    if b'\0' in data:
        return None
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return None


def scan(text: str, label: str, errors: set[str]) -> None:
    for name, pattern in RULES.items():
        for match in pattern.finditer(text):
            line = text.count('\n', 0, match.start()) + 1
            errors.add(f'{label}:{line}: {name}')


def headings(text: str) -> set[str]:
    result: set[str] = set()
    counts: dict[str, int] = {}
    fenced = False
    for line in text.splitlines():
        if line.lstrip().startswith(('```', '~~~')):
            fenced = not fenced
        if fenced:
            continue
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*$', line)
        if not match:
            continue
        title = re.sub(r'<[^>]+>', '', match[1]).lower()
        slug = ''.join(char for char in title if char in '-_' or not unicodedata.category(char).startswith(('P', 'S')))
        slug = re.sub(r'\s', '-', slug.strip())
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        result.add(slug if count == 0 else f'{slug}-{count}')
    result.update(re.findall(r'<a\s+(?:id|name)=[\"\']([^\"\']+)', text))
    return result


@cache
def directory_names(path: Path) -> frozenset[str]:
    return frozenset(child.name for child in path.iterdir())


def exact_case(path: Path) -> bool:
    parent = ROOT
    for component in path.relative_to(ROOT).parts:
        if component not in directory_names(parent):
            return False
        parent = parent / component
    return True


def check_link(source: Path, target: str, errors: set[str]) -> None:
    target = target.strip()
    if target.startswith('<') and '>' in target:
        target = target[1:target.index('>')]
    else:
        target = re.split(r'\s+[\"\']', target, maxsplit=1)[0]
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or not target:
        return
    path = (source.parent / unquote(parsed.path)).resolve() if parsed.path else source
    label = str(source.relative_to(ROOT))
    if not path.is_relative_to(ROOT):
        errors.add(f'{label}: link escapes repository: {target}')
    elif not path.exists():
        errors.add(f'{label}: missing link target: {target}')
    elif not exact_case(path):
        errors.add(f'{label}: incorrect path casing: {target}')
    elif parsed.fragment and path.suffix == '.md':
        if unquote(parsed.fragment) not in headings(path.read_text()):
            errors.add(f'{label}: missing heading: {target}')


def history(errors: set[str]) -> int:
    objects = git('rev-list', '--objects', '--all').decode().splitlines()
    names = dict(line.split(' ', 1) for line in objects if ' ' in line)
    inventory = git('cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)', input=('\n'.join(names)+'\n').encode()).decode().splitlines()
    reader = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    scanned = 0
    try:
        for entry in inventory:
            oid, kind, size = entry.split()
            if kind != 'blob':
                continue
            assert reader.stdin and reader.stdout
            reader.stdin.write((oid+'\n').encode()); reader.stdin.flush()
            header = reader.stdout.readline().split()
            data = reader.stdout.read(int(header[2])); reader.stdout.read(1)
            text = decode(data)
            if text is not None:
                scan(text, f'history/{oid[:12]}/{names[oid]}', errors)
                scanned += 1
    finally:
        if reader.stdin:
            reader.stdin.close()
        reader.wait(timeout=10)
    return scanned


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true', help='also scan reachable historical text blobs')
    args = parser.parse_args()
    errors: set[str] = set()
    paths = files()
    markdown = 0
    for path in paths:
        relative = path.relative_to(ROOT)
        for parent in relative.parents:
            if str(parent) != '.' and parent.name not in RESERVED_DIRECTORIES and not KEBAB.fullmatch(parent.name):
                errors.add(f'{parent}: directory must use kebab-case')
        private_environment = path.name.startswith('.env') and path.name != '.env.example'
        database_sidecar = re.search(r'\.(?:sqlite3?|db)-(?:shm|wal|journal)$', path.name) is not None
        if private_environment or database_sidecar or path.name in PRIVATE_FILES or path.suffix.lower() in PRIVATE_SUFFIXES:
            errors.add(f'{relative}: private/runtime file must not be tracked')
        text = decode(path.read_bytes())
        if text is None:
            continue
        scan(text, str(relative), errors)
        if path.suffix == '.md':
            markdown += 1
            if path.name not in RESERVED_MARKDOWN and not KEBAB.fullmatch(path.stem):
                errors.add(f'{relative}: Markdown name must use kebab-case')
            for target in re.findall(r'!?\[[^\]\n]*\]\(([^)\n]+)\)', text):
                check_link(path, target, errors)
            for target in re.findall(r'<(?:img|a)\b[^>]*(?:src|href)=[\"\']([^\"\']+)', text):
                check_link(path, target, errors)
    count = history(errors) if args.history else 0
    if errors:
        print('\n'.join(sorted(errors)))
        raise SystemExit(1)
    print(f'PASS: {len(paths)} project files; kebab-case directories and Markdown; links in {markdown} Markdown files; sensitive-data checks')
    if args.history:
        print(f'PASS: common credential and machine-path patterns absent from {count} reachable historical text blobs')


if __name__ == '__main__':
    main()
