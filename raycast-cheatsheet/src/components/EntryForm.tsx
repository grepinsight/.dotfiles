import {
  Action,
  ActionPanel,
  Form,
  Icon,
  Toast,
  showToast,
  useNavigation,
} from "@raycast/api";
import { useState } from "react";

import { composeEntry } from "../lib/write.ts";
import { appendToNote, createNote, editEntry } from "../lib/vault.ts";
import type { Entry, Note } from "../lib/parse.ts";

const NEW_TOPIC = "__new_topic__";

export type EntryFormProps = {
  notes: Note[];
  /** Where a brand-new topic's note gets created. */
  newNotePath: string;
  tag: string;
  /** Present when editing rather than adding. */
  entry?: Entry;
  /** Seeded from the search query, so a failed lookup becomes the new entry. */
  initialText?: string;
  /** Seeded from the selected row, so adding files next to what you were reading. */
  initialFile?: string;
  isLoading?: boolean;
  /** Called after a successful write so the list can pick the change up. */
  onSaved?: () => void;
};

export function EntryForm({
  notes,
  newNotePath,
  tag,
  entry,
  initialText,
  initialFile,
  isLoading,
  onSaved,
}: EntryFormProps) {
  const { pop } = useNavigation();
  const editing = entry !== undefined;

  const [text, setText] = useState(initialText ?? entry?.copyText ?? "");
  const [description, setDescription] = useState(entry?.description ?? "");
  const [topic, setTopic] = useState(
    entry?.file ?? initialFile ?? notes[0]?.file ?? NEW_TOPIC,
  );
  const [newTopic, setNewTopic] = useState("");
  const [section, setSection] = useState(entry?.section ?? "");
  const [error, setError] = useState<string | undefined>();

  async function save() {
    let line;
    try {
      line = composeEntry({ text, description });
    } catch (problem) {
      setError(problem instanceof Error ? problem.message : String(problem));
      return;
    }
    setError(undefined);

    try {
      if (editing) {
        await editEntry(entry, line);
      } else {
        const file =
          topic === NEW_TOPIC
            ? await createNote(newNotePath, newTopic, tag)
            : topic;
        await appendToNote(file, {
          section: section.trim() || undefined,
          text: line,
        });
      }
      await showToast({
        style: Toast.Style.Success,
        title: editing ? "Entry updated" : "Entry added",
      });
      onSaved?.();
      pop();
    } catch (problem) {
      // A drifted note or an unwritable path is the user's to resolve, so the
      // message says which file and what to do rather than just "failed".
      await showToast({
        style: Toast.Style.Failure,
        title: editing
          ? "Could not update the entry"
          : "Could not add the entry",
        message: problem instanceof Error ? problem.message : String(problem),
      });
    }
  }

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title={editing ? "Update Entry" : "Add Entry"}
            icon={editing ? Icon.Pencil : Icon.Plus}
            onSubmit={save}
          />
        </ActionPanel>
      }
    >
      <Form.TextArea
        id="text"
        title="Text to Copy"
        placeholder="git rebase -i HEAD~3"
        info="Exactly what Return puts on the clipboard. Nothing is stripped or guessed."
        value={text}
        onChange={setText}
        error={error}
        autoFocus
      />
      <Form.TextField
        id="description"
        title="Description"
        placeholder="squash the last three commits"
        info="Optional. Shown under the entry in the list, never copied."
        value={description}
        onChange={setDescription}
      />
      <Form.Separator />

      {editing ? (
        <Form.Description
          title="Destination"
          text={`${entry.topic}${entry.section ? ` › ${entry.section}` : ""}\n${entry.file}`}
        />
      ) : (
        <>
          <Form.Dropdown
            id="topic"
            title="Topic"
            value={topic}
            onChange={setTopic}
          >
            {notes.map((note) => (
              <Form.Dropdown.Item
                key={note.file}
                value={note.file}
                title={note.topic}
                icon={Icon.Document}
              />
            ))}
            <Form.Dropdown.Item
              value={NEW_TOPIC}
              title="New topic…"
              icon={Icon.NewDocument}
            />
          </Form.Dropdown>
          {topic === NEW_TOPIC && (
            <Form.TextField
              id="newTopic"
              title="New Topic"
              placeholder="Kubernetes"
              info={`Creates ${newTopic.trim() || "<topic>"}.md tagged ${tag} in ${newNotePath}.`}
              value={newTopic}
              onChange={setNewTopic}
            />
          )}
          <Form.TextField
            id="section"
            title="Section"
            placeholder="Rebase"
            info="Optional. Files the entry under that heading, creating it if the note has none."
            value={section}
            onChange={setSection}
          />
        </>
      )}
    </Form>
  );
}
