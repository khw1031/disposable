#!/usr/bin/env node
// Moves imported tools (imported: yes) to the newest commit of their original when its skill folder changed.
//   node .github/scripts/update-imports.mjs [--body <file>] [registryDir]
// Reads sources through the GitHub API and raw files only; nothing from a source is run. A tool moves only when its
// folder changed, the index build check passes at the new commit with no risk signal, and its license is the same.
// Anything else is reported for a person, and the tool stays at its reviewed commit (MAINTAINING.md, Updating imports).
import { readFile, writeFile, appendFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readTools, defaultRegistry } from './build-index.mjs';
import { inspect, bounded } from './scan.mjs';
import { checkSkill, githubRepo, LICENSES } from '../../skills/disposable/scripts/check.mjs';

const BRANCH = /^[A-Za-z0-9._/-]{1,200}$/;
const segments = path => path.split('/').filter(Boolean).map(encodeURIComponent).join('/');

// A license file's terms, by the sentence each of the four licenses always carries.
export function licenseOfText(text) {
  if (/Apache License/.test(text) && /Version 2\.0/.test(text)) return 'Apache-2.0';
  if (/Permission is hereby granted, free of charge/.test(text)) return 'MIT';
  if (/CC0 1\.0 Universal/.test(text)) return 'CC0-1.0';
  if (/Attribution 4\.0 International/.test(text)) return 'CC-BY-4.0';
  return '';
}

export async function updateImports(registryDir = defaultRegistry, fetchImpl = globalThis.fetch) {
  const api = async path => JSON.parse(await bounded(fetchImpl, `https://api.github.com/${path}`));
  const raw = (repo, sha, path) => bounded(fetchImpl, `https://raw.githubusercontent.com/${repo.owner}/${repo.repo}/${sha}/${segments(path)}`, 'text/plain');
  const heads = new Map(), listings = new Map();
  // The newest commit of the default branch, once per repository.
  const head = repo => {
    const key = `${repo.owner}/${repo.repo}`;
    if (!heads.has(key)) heads.set(key, (async () => {
      const branch = (await api(`repos/${key}`)).default_branch;
      if (!BRANCH.test(branch || '')) throw new Error('no default branch');
      const sha = (await api(`repos/${key}/git/ref/heads/${branch}`)).object?.sha;
      if (!/^[0-9a-f]{40}$/.test(sha || '')) throw new Error('no commit on the default branch');
      return { branch, sha };
    })());
    return heads.get(key);
  };
  const listing = (repo, sha, path) => {
    const key = `${repo.owner}/${repo.repo}@${sha}:${path}`;
    if (!listings.has(key)) listings.set(key, api(`repos/${repo.owner}/${repo.repo}/contents/${segments(path)}?ref=${sha}`).then(v => Array.isArray(v) ? v : []));
    return listings.get(key);
  };
  // The folder's tree hash: equal hashes mean nothing in the folder changed, whatever else the repository did.
  const folder = async (repo, sha, path) => {
    if (!path) return (await api(`repos/${repo.owner}/${repo.repo}/git/commits/${sha}`)).tree?.sha || null;
    const parts = path.split('/').filter(Boolean), name = parts.pop();
    return (await listing(repo, sha, parts.join('/'))).find(e => e.name === name && e.type === 'dir')?.sha || null;
  };
  // Same order as importing (skills.md, step 5): the folder's own license file, then SKILL.md, then the repository.
  const license = async (repo, sha, path, skill) => {
    const file = (await listing(repo, sha, path)).find(e => e.type === 'file' && /^LICEN[CS]E/i.test(e.name));
    if (file) return licenseOfText(await raw(repo, sha, file.path)) || `unrecognized terms in ${file.name}`;
    const own = checkSkill(skill).skill.meta.license;
    if (typeof own === 'string' && own) return LICENSES.includes(own) ? own : `"${own}" in SKILL.md`;
    try { return (await api(`repos/${repo.owner}/${repo.repo}/license?ref=${sha}`)).license?.spdx_id || 'none'; }
    catch { return 'none'; }
  };

  const tools = (await readTools(registryDir)).filter(t => t.parsed.meta?.imported === 'yes' && t.parsed.meta.source);
  const moved = [], reports = [];
  for (const t of tools) {
    const m = t.parsed.meta, repo = githubRepo(m.source), path = m.source_path || '', old = m.source_commit;
    const report = reason => reports.push({ slug: t.slug, reason });
    try {
      const latest = await head(repo);
      if (latest.sha === old) continue;
      // The pinned side only decides whether to skip: if it cannot be read (its history was rewritten), check the new commit.
      const [before, after] = [await folder(repo, old, path).catch(() => null), await folder(repo, latest.sha, path)];
      if (!after) { report(`its folder ${path || '(root)'} is gone at ${latest.branch} ${latest.sha.slice(0, 7)}; the pinned version still installs. Remove the tool or point it at the new folder.`); continue; }
      if (before === after) continue;
      let skill = null;
      const skillPath = [...path.split('/').filter(Boolean), 'SKILL.md'].join('/');
      const scan = await inspect({ type: 'skill', sourceUrl: m.source, sourcePath: path, sourceRef: latest.sha, title: '', summary: '' }, fetchImpl, { onFile: (p, text) => { if (p === skillPath) skill = text; }, evidence: 'skill' });
      const problems = scan.sourceProblem ? [scan.sourceProblem] : skill == null ? ['no SKILL.md'] : checkSkill(skill).problems;
      if (problems.length) { report(`at ${latest.sha.slice(0, 7)} the index build would hold it: ${problems.join('; ')}`); continue; }
      if (scan.findings.length) { report(`at ${latest.sha.slice(0, 7)} it has risk signals (${scan.findings.join(', ')}); read the change and move it by hand with a reviewed.json entry.`); continue; }
      const now = await license(repo, latest.sha, path, skill);
      if (now !== m.license) { report(`at ${latest.sha.slice(0, 7)} its license is ${now}, not ${m.license}; it stays at the reviewed commit.`); continue; }
      const file = join(registryDir, 'tools', t.slug, 'DISPOSABLE.md'), text = await readFile(file, 'utf8');
      const next = text.replace(new RegExp(`^source_commit:[ \\t]*${old}[ \\t]*$`, 'm'), `source_commit: ${latest.sha}`);
      if (next === text) { report('its source_commit line could not be rewritten'); continue; }
      await writeFile(file, next);
      moved.push({ slug: t.slug, repo: `${repo.owner}/${repo.repo}`, url: repo.url, path, old, sha: latest.sha });
    } catch (error) {
      report(`its source could not be read (${error.message}); try again later.`);
    }
  }
  return { checked: tools.length, moved, reports };
}

export function summary({ checked, moved, reports }) {
  const tree = (u, sha, path) => `${u}/tree/${sha}${path ? '/' + segments(path) : ''}`;
  const lines = [`Checked ${checked} imported tools against the default branch of their original.`, ''];
  if (moved.length) lines.push(`**Moved to a newer commit (${moved.length}).** Each folder changed upstream, passes the index build check with no risk signal, and keeps its license. Read each change before merging, including subfolders such as \`scripts/\` and \`references/\`: the check reads only up to eight text files at the top of the folder. After merge the site shows and installs the new version.`, '',
    '| Tool | Original folder | Change |', '| --- | --- | --- |',
    ...moved.map(x => `| \`${x.slug}\` | [${x.repo}/${x.path}](${tree(x.url, x.sha, x.path)}) | [${x.old.slice(0, 7)}…${x.sha.slice(0, 7)}](${x.url}/compare/${x.old}...${x.sha}) |`), '');
  if (reports.length) lines.push(`**Needs a person (${reports.length}).** These stay at their reviewed commit.`, '', ...reports.map(r => `- \`${r.slug}\`: ${r.reason}`), '');
  if (!moved.length && !reports.length) lines.push('Every imported tool matches its original.', '');
  lines.push('Nothing from a source was run. Checks are limited static text checks, not a safety guarantee.');
  return lines.join('\n') + '\n';
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), at = args.indexOf('--body'), body = at >= 0 ? args.splice(at, 2)[1] : '';
  const result = await updateImports(args[0] ? resolve(args[0]) : defaultRegistry);
  const text = summary(result);
  process.stdout.write(text);
  if (body) await writeFile(body, text);
  // The workflow opens a pull request when something moved, and fails the run when only reports need a person.
  if (process.env.GITHUB_OUTPUT) await appendFile(process.env.GITHUB_OUTPUT, `moved=${result.moved.length}\nreported=${result.reports.length}\n`);
}
