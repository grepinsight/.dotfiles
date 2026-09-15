import {
  Action,
  ActionPanel,
  Clipboard,
  Icon,
  Keyboard,
  List,
  Toast,
  open,
  showToast,
} from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import { readFile } from "node:fs/promises";
import { useState } from "react";

import { EntryForm } from "./components/EntryForm.tsx";
import { settings } from "./lib/preferences.ts";
import { advancedUri } from "./lib/obsidian.ts";
import { obsidianTarget, scan } from "./lib/vault.ts";
import { contextAround, type Entry, type Note } from "./lib/parse.ts";

/** Lines of surrounding note shown on each side of the entry in the preview. */
const CONTEXT_RADIUS = 6;

/**
 * Tildes rather than backticks, because an entry can itself contain a fenced
 * block and a backtick fence would be closed early by its content.
 */
function fenced(body: string, language = ""): string {
  return `~~~${language}\n${body}\n~~~`;
}

/**
 * The entry as it sits in its note, so you can tell whether it is the line you
 * wanted before copying it.
 *
 * Raycast renders a row's detail only while that row is selected, so reading
 * the note here costs one file read per selection rather than one per row.
 */
function EntryDetail({
  entry,
  codeLanguage,
}: {
  entry: Entry;
  codeLanguage: string;
}) {
  const { data, isLoading } = useCachedPromise(
    async (file: string, line: number) =>
      contextAround(await readFile(file, "utf-8"), line, CONTEXT_RADIUS),
    [entry.file, entry.line],
  );

  const gutter = data
    ? data.lines
        .map((text, index) => {
          const number = data.firstLine + index;
          const marker = index === data.targetIndex ? "▸" : " ";
          return `${marker} ${String(number).padStart(4)} │ ${text}`;
        })
        .join("\n")
    : "";

  return (
    <List.Item.Detail
      isLoading={isLoading}
      markdown={[
        `**Copies**`,
        // A block's own fence wins, then the note's `language:` key, then the
        // preference. Prose gets no language, since tagging an English sentence
        // as SQL colours it as a broken query.
        fenced(
          entry.copyText,
          entry.isCode ? (entry.language ?? codeLanguage) : "",
        ),
        `**In the note**`,
        // Tagged markdown so the backticked commands in the surrounding lines
        // colour too. The gutter prefix stops each line reading as a list item,
        // which trades bullet colouring for keeping the line numbers.
        fenced(gutter, "markdown"),
      ].join("\n\n")}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label
            title="Topic"
            text={entry.topic}
            icon={Icon.Document}
          />
          {entry.section ? (
            <List.Item.Detail.Metadata.Label
              title="Section"
              text={entry.section}
            />
          ) : null}
          <List.Item.Detail.Metadata.Label
            title="Kind"
            text={
              entry.kind === "block"
                ? `code block, ${entry.lineCount} lines`
                : "single line"
            }
          />
          <List.Item.Detail.Metadata.Separator />
          <List.Item.Detail.Metadata.Label
            title="Line"
            text={String(entry.line)}
          />
          <List.Item.Detail.Metadata.Label title="File" text={entry.file} />
        </List.Item.Detail.Metadata>
      }
    />
  );
}

/**
 * Open the note at the entry's own line.
 *
 * Plain `obsidian://open` reaches the file but not the line, so this goes
 * through the Advanced URI plugin. When the note is not inside a vault, or the
 * plugin is not installed and the link does nothing visible, opening the file
 * with whatever owns `.md` is the honest fallback.
 */
async function openAtLine(entry: Entry) {
  const target = await obsidianTarget(entry.file);

  if (!target) {
    await open(entry.file);
    return;
  }
  await open(advancedUri({ ...target, line: entry.line }));
}

export default function Command() {
  const { notesPath, newNotePath, tag, primaryAction, codeLanguage } =
    settings();
  const [query, setQuery] = useState("");
  const [showPreview, setShowPreview] = useState(true);

  const { data, isLoading, revalidate } = useCachedPromise(
    scan,
    [notesPath, tag],
    {
      initialData: { entries: [], notes: [] },
      keepPreviousData: true,
    },
  );

  const entries: Entry[] = data.entries;
  const notes: Note[] = data.notes;

  function addForm(entry?: Entry) {
    return (
      <EntryForm
        notes={notes}
        newNotePath={newNotePath}
        tag={tag}
        initialText={query}
        initialFile={entry?.file}
        onSaved={revalidate}
      />
    );
  }

  return (
    <List
      isLoading={isLoading}
      isShowingDetail={showPreview && entries.length > 0}
      filtering
      onSearchTextChange={setQuery}
      searchBarPlaceholder="Search every line of your cheatsheets"
    >
      <List.EmptyView
        icon={entries.length === 0 ? Icon.Document : Icon.MagnifyingGlass}
        title={
          entries.length === 0
            ? "No cheatsheet entries yet"
            : `No matches for “${query}”`
        }
        description={
          entries.length === 0
            ? `Searching ${notesPath} for notes tagged ${tag}. Press Return to write the first entry.`
            : "Press Return to add it as a new entry."
        }
        actions={
          <ActionPanel>
            <Action.Push
              title={entries.length === 0 ? "Add First Entry" : "Add Entry"}
              icon={Icon.Plus}
              target={addForm()}
            />
            <Action
              title="Rescan Notes"
              icon={Icon.ArrowClockwise}
              onAction={revalidate}
            />
          </ActionPanel>
        }
      />

      {entries.map((entry) => (
        <List.Item
          key={entry.id}
          id={entry.id}
          icon={entry.kind === "block" ? Icon.Code : Icon.Text}
          // The title IS the clipboard payload. A launcher that copies something
          // other than what it shows is a trap, so the two are one string.
          title={entry.copyText.split("\n")[0] ?? ""}
          subtitle={showPreview ? undefined : entry.description}
          keywords={[entry.topic, entry.section, entry.text].filter(
            (value): value is string => Boolean(value),
          )}
          accessories={
            showPreview
              ? undefined
              : [
                  {
                    text: `${entry.topic}${entry.section ? ` › ${entry.section}` : ""}`,
                  },
                ]
          }
          detail={<EntryDetail entry={entry} codeLanguage={codeLanguage} />}
          actions={
            <ActionPanel>
              <ActionPanel.Section>
                {primaryAction === "paste" ? (
                  <>
                    <Action.Paste
                      title="Paste Entry"
                      content={entry.copyText}
                    />
                    <Action.CopyToClipboard
                      title="Copy Entry"
                      content={entry.copyText}
                      shortcut={{ modifiers: ["cmd"], key: "return" }}
                    />
                  </>
                ) : (
                  <>
                    <Action.CopyToClipboard
                      title="Copy Entry"
                      content={entry.copyText}
                    />
                    <Action.Paste
                      title="Paste Entry"
                      content={entry.copyText}
                      shortcut={{ modifiers: ["cmd"], key: "return" }}
                    />
                  </>
                )}
                <Action
                  title="Copy and Keep Open"
                  icon={Icon.Clipboard}
                  shortcut={Keyboard.Shortcut.Common.Copy}
                  onAction={async () => {
                    await Clipboard.copy(entry.copyText);
                    await showToast({
                      style: Toast.Style.Success,
                      title: "Copied",
                      message: entry.copyText,
                    });
                  }}
                />
              </ActionPanel.Section>

              <ActionPanel.Section>
                <Action
                  title={showPreview ? "Hide Preview" : "Show Preview"}
                  icon={Icon.Sidebar}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "p" }}
                  onAction={() => setShowPreview((shown) => !shown)}
                />
                <Action
                  title="Open in Obsidian at This Line"
                  icon={Icon.Pencil}
                  shortcut={Keyboard.Shortcut.Common.Open}
                  onAction={() => openAtLine(entry)}
                />
                <Action.ShowInFinder
                  path={entry.file}
                  shortcut={Keyboard.Shortcut.Common.OpenWith}
                />
              </ActionPanel.Section>

              <ActionPanel.Section>
                {entry.kind === "line" ? (
                  <Action.Push
                    title="Edit Entry"
                    icon={Icon.Pencil}
                    shortcut={Keyboard.Shortcut.Common.Edit}
                    target={
                      <EntryForm
                        notes={notes}
                        newNotePath={newNotePath}
                        tag={tag}
                        entry={entry}
                        onSaved={revalidate}
                      />
                    }
                  />
                ) : null}
                <Action.Push
                  title="Add Entry"
                  icon={Icon.Plus}
                  shortcut={Keyboard.Shortcut.Common.New}
                  target={addForm(entry)}
                />
                <Action
                  title="Rescan Notes"
                  icon={Icon.ArrowClockwise}
                  shortcut={Keyboard.Shortcut.Common.Refresh}
                  onAction={revalidate}
                />
              </ActionPanel.Section>
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
