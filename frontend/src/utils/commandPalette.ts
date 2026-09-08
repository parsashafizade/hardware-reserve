export interface SearchablePaletteCommand {
  id: string;
  label: string;
  description?: string;
  keywords?: string[];
  priority?: number;
}

export function normalizeCommandQuery(value: string): string {
  return value
    .normalize("NFKC")
    .toLocaleLowerCase()
    .replace(/[يى]/g, "ی")
    .replace(/ك/g, "ک")
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function isSubsequence(query: string, value: string): boolean {
  let queryIndex = 0;
  for (const character of value) {
    if (character === query[queryIndex]) {
      queryIndex += 1;
      if (queryIndex === query.length) {
        return true;
      }
    }
  }
  return false;
}

function scoreCommand(command: SearchablePaletteCommand, query: string): number {
  const priority = command.priority ?? 0;
  if (!query) {
    return 100 + priority;
  }

  const label = normalizeCommandQuery(command.label);
  const description = normalizeCommandQuery(command.description ?? "");
  const keywords = (command.keywords ?? []).map(normalizeCommandQuery);
  const searchable = [label, description, ...keywords].join(" ");
  const words = searchable.split(" ").filter(Boolean);

  if (label === query) {
    return 1_000 + priority;
  }
  if (label.startsWith(query)) {
    return 850 + priority;
  }
  if (words.some((word) => word.startsWith(query))) {
    return 720 + priority;
  }
  if (searchable.includes(query)) {
    return 600 + priority;
  }

  const queryWords = query.split(" ").filter(Boolean);
  if (queryWords.length > 1 && queryWords.every((word) => searchable.includes(word))) {
    return 500 + priority;
  }
  if (query.length >= 3 && isSubsequence(query, label)) {
    return 300 + priority;
  }
  return -1;
}

export function rankPaletteCommands<T extends SearchablePaletteCommand>(
  commands: T[],
  query: string,
): T[] {
  const normalized = normalizeCommandQuery(query);
  return commands
    .map((command, index) => ({ command, index, score: scoreCommand(command, normalized) }))
    .filter((entry) => entry.score >= 0)
    .sort((left, right) => right.score - left.score || left.index - right.index)
    .map((entry) => entry.command);
}
