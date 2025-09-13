#!/usr/bin/env python3
import re, sys

text = sys.stdin.read()

# normalizzazioni base
text = text.replace('\r\n', '\n').replace('\r', '\n')
text = text.replace('\u00A0', ' ')  # nbsp
text = re.sub(r'[ \t]+$', '', text, flags=re.MULTILINE)

# 1) Sezioni tipo "🔹 1. Titolo" o "🔹 Titolo"
def sec_to_heading(m):
    n = (m.group(1) or '').strip()
    title = m.group(2).strip()
    if n:
        return f"### {n} {title}"
    return f"### {title}"
text = re.sub(r'^\s*🔹\s*((\d+[\.\)])\s*)?(.*)$', lambda m: sec_to_heading((m.group(2) or '', m.group(3)) if False else re.match(r'^\s*🔹\s*((\d+[\.\)])\s*)?(.*)$', m.group(0))), text, flags=re.MULTILINE)
# Il costrutto sopra è “trick” per permettere lambda; rifacciamo semplice:
text = re.sub(r'^\s*🔹\s*(\d+[\.\)])?\s*(.*)$', lambda m: f"### {(m.group(1)+' ' if m.group(1) else '')}{m.group(2).strip()}", text, flags=re.MULTILINE)

# 2) Note tipo "📌 testo" -> **Note:** testo
text = re.sub(r'^\s*📌\s*', '**Note:** ', text, flags=re.MULTILINE)

# 3) Punti elenco non-markdown all’inizio riga -> "- "
text = re.sub(r'^\s*[•‣▪–—]\s+', '- ', text, flags=re.MULTILINE)

# 4) URL nudi/domìni -> <https://…> (se non già parte di markdown)
def wrap_url(m):
    url = m.group(0)
    if url.startswith('http://') or url.startswith('https://'):
        return f'<{url}>'
    return f'<https://{url}>'
# evita di toccare dentro [testo](link)
def protect_md_links(s):
    return re.sub(r'\[.*?\]\(.*?\)', lambda m: m.group(0).replace('(', '⟮').replace(')', '⟯'), s)
def unprotect_md_links(s):
    return s.replace('⟮','(').replace('⟯',')')

protected = protect_md_links(text)
protected = re.sub(r'(?<![@\w/])(https?://[^\s)]+|[A-Za-z0-9.-]+\.[A-Za-z]{2,})(?![\w/])', wrap_url, protected)
text = unprotect_md_links(protected)

# 5) Riconoscimento blocchi comandi -> ```bash ... ```
cmd_prefixes = ('sudo ','git ','pip ','python','python3','npm ','yarn ','pnpm ','hugo ','django-admin','code ','curl ','apt ','apt-get ','conda ','brew ','ssh ','rsync ')
out, in_code = [], False
for line in text.split('\n'):
    is_cmd = line.strip().startswith(cmd_prefixes)
    if is_cmd and not in_code:
        out.append('```bash'); in_code = True
    if not is_cmd and in_code and line.strip()=='':
        # chiudi su riga bianca e riprendi fuori
        out.append('```'); in_code = False
    out.append(line)
# chiusura finale se necessario
if in_code: out.append('```'); in_code=False
text = '\n'.join(out)

# 6) Sostituzioni cosmetiche
text = text.replace(' → ', ' → ')  # lasciamo la freccia; opzionale: ': '
# comprimi tripli a capo
text = re.sub(r'\n{3,}', '\n\n', text)

sys.stdout.write(text.strip() + '\n')
