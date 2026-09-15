import {
  Action,
  ActionPanel,
  Clipboard,
  Detail,
  Icon,
  List,
  Toast,
  showToast,
  Keyboard,
} from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import { useState } from "react";

import { EntryForm } from "./components/EntryForm.tsx";
import { settings } from "./lib/preferences.ts";
import { scan } from "./lib/vault.ts";
import type { Entry, Note } from "./lib/parse.ts";

/** Full payload for a multi-line entry, so nothing is copied unseen. */
function FullEntry({ entry }: { entry: Entry }) {
  const fence =
    entry.kind === "block"
      ? `\`\`\`\n${entry.copyText}\n\`\`\``
      : entry.copyText;
  return (
    <Detail
      markdown={`${fence}\n\n---\n\n${entry.description ?? ""}`}
      navigationTitle={`${entry.topic}${entry.section ? ` › ${entry.section}` : ""}`}
      actions={
        <ActionPanel>
          <Action.CopyToClipboard title="Copy Entry" content={entry.copyText} />
          <Action.Open title="Open Source Note" target={entry.file} />
        </ActionPanel>
      }
    />
  );
}

export default function Command() {
  const { notesPath, newNotePath, tag, primaryAction } = settings();
  const [query, setQuery] = useState("");

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
          subtitle={entry.description}
          keywords={[entry.topic, entry.section, entry.text].filter(
            (value): value is string => Boolean(value),
          )}
          accessories={[
            {
              text: `${entry.topic}${entry.section ? ` › ${entry.section}` : ""}`,
            },
          ]}
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
                {entry.lineCount > 1 && (
                  <Action.Push
                    title="Show Full Entry"
                    icon={Icon.Eye}
                    shortcut={{ modifiers: ["cmd"], key: "d" }}
                    target={<FullEntry entry={entry} />}
                  />
                )}
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
                <Action.Open
                  title="Open Source Note"
                  target={entry.file}
                  shortcut={Keyboard.Shortcut.Common.Open}
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
