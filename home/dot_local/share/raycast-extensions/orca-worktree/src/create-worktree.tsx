import {
  Action,
  ActionPanel,
  Clipboard,
  Detail,
  Form,
  Icon,
  Toast,
  closeMainWindow,
  popToRoot,
  showToast,
  useNavigation,
} from "@raycast/api";
import { useEffect, useMemo, useState } from "react";
import {
  ORCA_DEFAULT_AGENT,
  buildOhcArgs,
  focusOrca,
  loadAgentIds,
  parseGitHubRepo,
  parseOrcaJson,
  resolveOhcHelperPath,
  resultMarkdown,
  summarizeResult,
  execCli,
} from "./orca.mjs";

type FormValues = {
  repo: string;
  worktreeName: string;
  agent: string;
  prompt: string;
  setup: string;
  baseBranch: string;
  issue: string;
  linearIssue: string;
  comment: string;
  parentWorktree: string;
  noParent: boolean;
  runHooks: boolean;
  focusOrca: boolean;
};

// Defaults applied to the advanced knobs so that hiding them keeps the same
// behavior as leaving the fields untouched. Values from rendered fields win.
const ADVANCED_DEFAULTS = {
  setup: "inherit",
  baseBranch: "",
  issue: "",
  linearIssue: "",
  comment: "",
  parentWorktree: "",
  noParent: false,
  runHooks: false,
  focusOrca: true,
} as const;

type ResultSummary = ReturnType<typeof summarizeResult>;

export default function CreateWorktreeCommand() {
  const { push } = useNavigation();
  const [agentIds, setAgentIds] = useState<string[]>([]);
  const [agentLoadError, setAgentLoadError] = useState<string>();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [repoError, setRepoError] = useState<string>();
  const [nameError, setNameError] = useState<string>();
  const [showAdvanced, setShowAdvanced] = useState(false);

  useEffect(() => {
    loadAgentIds()
      .then((ids) => {
        setAgentIds(ids);
        setAgentLoadError(ids.length > 0 ? undefined : "Orca did not report any explicit agent IDs.");
      })
      .catch((error) => {
        setAgentIds([]);
        setAgentLoadError(error instanceof Error ? error.message : String(error));
      });
  }, []);

  async function submit(values: FormValues) {
    const repo = parseGitHubRepo(values.repo);
    if (!repo.ok) {
      setRepoError(repo.error);
      return;
    }

    const worktreeName = values.worktreeName.trim();
    if (worktreeName && !/^[A-Za-z0-9._/-]+$/.test(worktreeName)) {
      setNameError("Use letters, numbers, dots, underscores, hyphens, or slashes.");
      return;
    }

    // Advanced fields are unmounted when hidden, so they are absent from
    // `values`; fall back to the defaults to preserve behavior.
    const merged = { ...ADVANCED_DEFAULTS, ...values };

    setIsSubmitting(true);
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Creating Orca worktree",
      message: repo.slug,
    });

    try {
      const helperPath = await resolveOhcHelperPath();
      const stdout = await execCli("zsh", [helperPath, ...buildOhcArgs(merged, repo.slug)], {
        timeout: 1000 * 60 * 20,
      });
      const response = parseOrcaJson(stdout);
      const summary = summarizeResult(response);

      if (merged.focusOrca) {
        await focusOrca(summary);
      }

      toast.style = Toast.Style.Success;
      toast.title = "Created Orca worktree";
      toast.message = summary.name;
      push(<WorktreeResult summary={summary} rawJson={JSON.stringify(response, null, 2)} />);
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Could not create worktree";
      toast.message = error instanceof Error ? error.message : String(error);
    } finally {
      setIsSubmitting(false);
    }
  }

  const agentDropdownItems = useMemo(
    () => [
      <Form.Dropdown.Item key={ORCA_DEFAULT_AGENT} value={ORCA_DEFAULT_AGENT} title="Orca default" icon={Icon.Stars} />,
      ...agentIds.map((agent) => <Form.Dropdown.Item key={agent} value={agent} title={agent} icon={Icon.Terminal} />),
    ],
    [agentIds],
  );

  return (
    <Form
      enableDrafts
      isLoading={isSubmitting}
      navigationTitle="Create Orca Worktree"
      actions={
        <ActionPanel>
          <Action.SubmitForm icon={Icon.PlusCircle} title="Create Worktree" onSubmit={submit} />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="repo"
        title="GitHub Repo"
        placeholder="stablyai/orca or https://github.com/stablyai/orca"
        error={repoError}
        onBlur={(event) => {
          const result = parseGitHubRepo(event.target.value);
          setRepoError(result.ok ? undefined : result.error);
        }}
        onChange={() => setRepoError(undefined)}
        autoFocus
      />
      <Form.TextField
        id="worktreeName"
        title="Worktree Name"
        placeholder="Defaults to the repo name"
        error={nameError}
        onChange={(value) => {
          if (!value || /^[A-Za-z0-9._/-]+$/.test(value)) {
            setNameError(undefined);
          }
        }}
      />
      <Form.Dropdown id="agent" title="Agent" defaultValue={ORCA_DEFAULT_AGENT} info={agentLoadError}>
        {agentDropdownItems}
      </Form.Dropdown>
      <Form.TextArea
        id="prompt"
        title="Prompt"
        placeholder="Ask the agent what to do in the new worktree"
        info="Drafts are preserved if you leave Raycast before submitting."
      />
      <Form.Checkbox id="showAdvanced" label="Show advanced options" value={showAdvanced} onChange={setShowAdvanced} />
      {showAdvanced ? (
        <>
          <Form.Separator />
          <Form.Dropdown id="setup" title="Setup Hooks" defaultValue="inherit">
            <Form.Dropdown.Item value="inherit" title="Repo default" />
            <Form.Dropdown.Item value="run" title="Run" />
            <Form.Dropdown.Item value="skip" title="Skip" />
          </Form.Dropdown>
          <Form.TextField id="baseBranch" title="Base Branch" placeholder="origin/main" />
          <Form.TextField id="issue" title="GitHub Issue" placeholder="123" />
          <Form.TextField id="linearIssue" title="Linear Issue" placeholder="STA-335 or URL" />
          <Form.TextField id="comment" title="Comment" placeholder="Short Orca worktree note" />
          <Form.TextField id="parentWorktree" title="Parent" placeholder="active, current, id:..., branch:..." />
          <Form.Checkbox id="noParent" label="Create as an independent worktree" defaultValue={false} />
          <Form.Checkbox id="runHooks" label="Run setup hooks now" defaultValue={false} />
          <Form.Checkbox id="focusOrca" label="Open and focus Orca after creation" defaultValue={true} />
        </>
      ) : null}
    </Form>
  );
}

function WorktreeResult({ summary, rawJson }: { summary: ResultSummary; rawJson: string }) {
  return (
    <Detail
      navigationTitle="Orca Worktree Created"
      markdown={resultMarkdown(summary)}
      actions={
        <ActionPanel>
          <Action
            title="Open in Orca"
            icon={Icon.Window}
            onAction={async () => {
              await focusOrca(summary);
              await closeMainWindow();
            }}
          />
          {summary.path ? <Action.Open title="Open Folder" target={summary.path} icon={Icon.Folder} /> : null}
          {summary.path ? (
            <Action
              title="Copy Worktree Path"
              icon={Icon.Clipboard}
              onAction={async () => {
                await Clipboard.copy(summary.path);
                await showToast({ style: Toast.Style.Success, title: "Copied worktree path" });
              }}
            />
          ) : null}
          <Action.CopyToClipboard title="Copy Orca JSON" content={rawJson} />
          <Action title="Create Another" icon={Icon.Plus} onAction={popToRoot} />
        </ActionPanel>
      }
    />
  );
}
