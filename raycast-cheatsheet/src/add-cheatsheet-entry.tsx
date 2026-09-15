import { useCachedPromise } from "@raycast/utils";

import { EntryForm } from "./components/EntryForm.tsx";
import { settings } from "./lib/preferences.ts";
import { scan } from "./lib/vault.ts";

export default function Command() {
  const { notesPath, newNotePath, tag } = settings();

  // Only the note list is needed here, but scanning is cheap and reuses the
  // search command's cache, so the topic dropdown is populated on first paint.
  const { data, isLoading, revalidate } = useCachedPromise(
    scan,
    [notesPath, tag],
    {
      initialData: { entries: [], notes: [] },
      keepPreviousData: true,
    },
  );

  return (
    <EntryForm
      notes={data.notes}
      newNotePath={newNotePath}
      tag={tag}
      isLoading={isLoading}
      onSaved={revalidate}
    />
  );
}
